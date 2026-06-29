# Headless Viewer Test Harness — `withTestCodeEditor` for MoonBit

Status: proposed — Date: 2026-06-29. Follows `browser-test-harness-split.md` and
the conformance suite in `tests/browser/conformance/`.

Oracle: `vscode` submodule, `src/vs/editor/test/browser/testCodeEditor.ts`
(`withTestCodeEditor` / `TestCodeEditor` / `createTestCodeEditor`).

## Problem

The browser e2e suite is caught in the broad-vs-specific trap: assert on
rendered DOM/geometry and a spec is either too loose to catch a real bug or too
brittle to survive an unrelated render change. That tension is intrinsic to
*driving a real browser*. Monaco's answer is not a cleverer Playwright
assertion — it is **to barely test at that layer at all**. The vscode editor
core ships ~70 DOM-free unit tests (`editor/test/common`) and ~25 harness tests
(`editor/test/browser`) that drive a real editor with **no view**, against only
~29 full-app Playwright smoke files for the entire product.

We have the two ends — `moon test` unit tests and Playwright specs — but we are
**missing the middle**: a harness that drives the real `Viewer` + `ViewModel` +
`CursorsController` headlessly and asserts on *semantic* state (positions,
ranges, projected view lines, render frames). So behaviors vscode tests at its
stable browser-harness layer — cursor motion, soft-wrap view↔model mapping,
scroll-window math, hover anchoring — are forced up into Playwright here, where
they must be broad or brittle. The memory note that *"view-axis frame-index
regressions [were] caught only by `just test-browser`"* is exactly this gap:
those are model/viewmodel bugs that should fail a fast, precise harness test.

## Why this is cheap: the seam already exists

`TestCodeEditor` works by overriding `_createView` to return `null` — it keeps
the whole model/viewmodel/cursor/command pipeline and throws away only the DOM
view. Our `Viewer` already has that exact seam:

| vscode | viewer (MoonBit) |
|---|---|
| `CodeEditorWidget` | `Viewer` (`viewer/viewer.mbt:13`) |
| `_createView()` → `null` | **skip `attach()`** — construct via `Viewer::Viewer()` (`viewer.mbt:133`); `create()` is the attaching variant (`viewer.mbt:181`) |
| `instantiateTextModel(text)` | `@model.TextModel` from text |
| `editor.getViewModel()` | `self.view_model : @view_model.ViewModel?` (priv) |
| `viewModel.getCursorStates()` | `@cursor.CursorsController` (priv; `ensure_cursor()` at `viewer/selection.mbt:29`) |
| `CoreNavigationCommands.MoveTo` | `@cursor.move_to` (`cursor/core_navigation_commands.mbt:13`) |
| `assertCursor(viewModel, sel)` | assert on `CursorsController::get_model_selection()` (`cursors_controller.mbt:62`) |
| coordinatesConverter | `ViewModel::coordinates_converter()` / `ModelLineProjection::model_position_to_view_position` (`view_model/model_line_projection.mbt:86`) |

The decisive fact: `Viewer::render_current_model` (`viewer/render.mbt:7`) builds
the tokenized document, `view_model`, `frame`, and cursor context and stores
them **synchronously** (`render.mbt`: `self.view_model = Some(...)`,
`self.frame = Some(...)`, `self.refresh_cursor_context()`) *before* it calls
`schedule_render`. Only the DOM flush is deferred. So an **unattached** viewer
still has fully-populated semantic state after `set_model` — no DOM, no
`requestAnimationFrame`, no measurement needed. The harness reads that state.

## The harness (sketch)

Lives as a whitebox file in the viewer package so it can touch private fields
without widening the public API — the additive, production-neutral analog of
vscode's separate `testCodeEditor.ts`. Other `*_wbtest.mbt` files in `viewer/`
call it. **Exact constructor/field names below are placeholders to confirm in
Step 0** (`TextModel::new`, `Uri::parse`, `Position::new`, the `ViewerOptions`
wrapping field); the shape is what matters.

```moonbit
// viewer/test_viewer_wbtest.mbt
//
// Headless behavior-test harness — the MoonBit analog of vscode's
// editor/test/browser/testCodeEditor.ts. Drives a real Viewer + ViewModel +
// CursorsController over an in-memory model WITHOUT attaching a DOM view
// (mirrors TestCodeEditor._createView returning null), so tests assert on
// semantic state — positions, ranges, projected view lines, frames — instead
// of rendered pixels.

///|
/// Builds a TextModel from raw text. The analog of `instantiateTextModel`.
fn test_model(
  text : String,
  language_id~ : String = "plaintext",
) -> @model.TextModel {
  @model.TextModel::new(
    uri=@base_common.Uri::parse("inmemory://test/model"),
    text~,
    language_id~,
  )
}

///|
/// `withTestCodeEditor`: spin up a headless viewer over `text`, run `body`,
/// dispose. No `attach()` — no DOM view — but `set_model` still builds the
/// tokenized doc, view model, render frame, and cursor context synchronously.
fn with_test_viewer(
  text : String,
  body : (Viewer) -> Unit,
  options~ : ViewerOptions = ViewerOptions::default(),
) -> Unit {
  let viewer = Viewer::Viewer(options~) // NOTE: deliberately no attach()
  viewer.set_model(test_model(text))
  body(viewer)
  viewer.dispose()
}

///|
/// `ITestCodeEditor.getViewModel()` — whitebox read of the private field.
fn Viewer::test_view_model(self : Viewer) -> @view_model.ViewModel {
  self.view_model.unwrap()
}

///|
/// vscode keeps one cursor controller live per editor; here it is lazy
/// (created on first interaction), so force it for tests.
fn Viewer::test_cursor(self : Viewer) -> @cursor.CursorsController {
  self.ensure_cursor().unwrap()
}

///|
/// The frame the viewer last built for its visible window.
fn Viewer::test_frame(self : Viewer) -> @view_model.RenderFrame {
  self.frame.unwrap()
}

///|
/// `assertCursor`: compare the controller's model selection to an expected one.
fn assert_cursor(viewer : Viewer, expected : @view_model.Selection) -> Unit {
  assert_eq(viewer.test_cursor().get_model_selection(), expected)
}
```

### Usage — the three regressions that today only Playwright catches

```moonbit
///|
test "MoveTo positions the cursor in model coordinates" {
  with_test_viewer("line one\nline two\nline three", viewer => {
    @cursor.move_to(viewer.test_cursor(), @base_common.Position::new(2, 5))
    assert_cursor(
      viewer,
      @view_model.Selection::new(
        @base_common.Position::new(2, 5),
        @base_common.Position::new(2, 5),
      ),
    )
  })
}

///|
test "soft wrap maps a model column to the correct view position" {
  let options = ViewerOptions::default() // ..with wrapping_column = 6
  with_test_viewer("abcdefghij", options~, viewer => {
    let converter = viewer.test_view_model().coordinates_converter()
    // model col 9 ('i') wraps onto view line 2 — the exact view-axis mapping
    // the memory note says previously regressed undetected.
    let view_pos = converter.model_position_to_view_position(
      @base_common.Position::new(1, 9),
    )
    assert_eq(view_pos, @base_common.Position::new(2, 3))
  })
}

///|
test "render frame windows to the visible range, not the whole document" {
  with_test_viewer(long_document(), viewer => {
    viewer.scroll_to(400.0)
    let frame = viewer.test_frame()
    // assert the frame's viewport window, not pixels or DOM node counts
    assert_eq(frame.viewport.start_line, 24)
    assert_true(frame.lines.length() < 60)
  })
}
```

`RenderFrame` is `pub(all)` with a `ToJson` impl (`view_model/render_frame.mbt:30`),
so frames can also be asserted as golden JSON — the precise-DOM check from
`dom_structure.spec.js`, but deterministic and DOM-free.

## Plan

**Step 0 — Spike (de-risk before writing the harness).** In a throwaway
`_wbtest.mbt`, construct `Viewer::Viewer()` *without* `attach()`, call
`set_model` with a 3-line model, and confirm `self.view_model`, `self.frame`,
and `ensure_cursor()` are populated and that no path dereferences `self.view`
(`schedule_render` / flush must no-op when `view is None`). Expected to pass
given `viewer.mbt:133`'s own doc note that `attach` precedes documents only so
the *first render can measure*. If a flush path panics on a null view, the fix
is a single `guard self.view is Some(...)` — note it and proceed.

**Step 1 — Land the harness file** `viewer/test_viewer_wbtest.mbt` exactly as
sketched, with real constructor/field names confirmed in Step 0. No production
code changes if Step 0 is clean. Net new public surface: zero.

**Step 2 — Port the first behavior spec down.** Move the view-axis /
soft-wrap-projection assertions (the regression class the memory flags) out of
`tests/browser/conformance/scroll_windowing.spec.js` into whitebox tests using
`with_test_viewer`. Keep the Playwright spec only as a thin "the wired-up app
scrolls at all" smoke check. This is the worked example that proves the layer.

**Step 3 — Add the cursor/selection suite.** Mirror a slice of vscode's
`cursor.test.ts`: `move_to` / `move_to_select` → `get_model_selection` /
`get_view_selection`, empty-vs-ranged selection, multi-line. These are pure
semantic assertions that never belonged in a browser.

**Step 4 — Document the layer.** Add a "Headless harness" section to
`tests/browser/README.md` (or `docs/harness.md`) stating the rule: *a behavior
expressible as a position, range, line string, token array, or frame is tested
with `with_test_viewer`; Playwright is reserved for wiring + the
oracle/differential conformance specs.* Update the conformance README's
boundary note to point at the harness.

## Verification

- `just test-moon` (js target — viewer is js-only per project memory) stays
  green and gains the new whitebox tests.
- The ported behavior assertions fail when the view-axis projection is
  deliberately off-by-one, and pass when correct — the precision the
  broad/specific Playwright spec could not give without brittleness.
- Browser suite shrinks (or specs demote to smoke) without losing coverage,
  because coverage moved down a layer, not away.

## Non-goals

- Not replacing the oracle/differential conformance specs — comparing our
  computed CSS/geometry against a real Monaco page is precise *and* stable
  because the oracle moves with us; that stays in Playwright.
- Not testing the DOM flush, measurement, or pointer hit-testing here — those
  genuinely need a browser and stay in `conformance/` + `smoke/`.
- Not a general DI/service-mock framework. `ViewerServices::new()` defaults are
  sufficient; only override a service when a specific test needs to.
