# Monaco-Shaped DOM Rendering

Status: implemented (2026-06-14).
Date: 2026-06-14

## Summary

Refactor the browser viewer DOM from the current flattened local structure into a
Monaco-shaped view tree with explicit view-part containers. This is not a goal to
import Monaco code or promise Monaco DOM compatibility. The goal is to make our
readonly viewer use the same broad rendering architecture: a root editor node,
an overflow guard, lines content, view lines, margin overlays, content widgets,
overlay widgets, and overflowing widget containers.

This plan intentionally allows harness selector changes. The old class names in
`docs/harness.md` are not compatibility constraints; update the docs and browser
specs together with the DOM migration.

## Why This Direction

The current implementation is already close to Monaco in spirit:

- `renderer` owns backend-neutral view state, line layout, scroll state, hit
  testing, and HTML generation.
- `renderer/browser` owns the imperative browser island, DOM creation, CSS,
  input capture, render flushing, and widget placement.
- The island already has a root, a margin layer, a lines layer, a hover layer,
  synthetic scrollbars, line recycling, and a read/write render phase.

The gap is that these parts are still organized around local one-off names and
special cases. Hover is a dedicated layer instead of a content widget. Margin
content is a parallel recycler instead of a margin overlay. There is no stable
slot for future content widgets, overlay widgets, view zones, or view overlays.
That makes the next Monaco-like features harder to add without repeatedly
reshaping the DOM.

The proposed migration keeps the good parts we already have, especially the
readonly model and synthetic scroll ownership, while making the DOM shape match
the architecture we want to grow into.

## Current State

This is the state verified before writing the plan:

- `renderer/browser/island.mbt` builds `section.code-viewer`, `span.char-probe`,
  `div.source-message`, `div.code-lines`, `div.hover-layer`, `div.margin`, and
  custom scrollbar nodes. It owns line/gutter recycling and hover widget DOM.
- `renderer/line_html.mbt` renders each visual line as a `code-line` node whose
  inner HTML is a `<pre class="code">` containing token spans.
- `renderer/browser/input.mbt` captures pointer, wheel, and scrollbar input at
  the island root and maps DOM events through backend-neutral hit testing.
- `renderer/browser/editor_events.mbt` currently routes hover-oriented events;
  hover is the only controller-level widget behavior.
- `app/src/style.css` styles the current root, line, gutter, hover, and scrollbar
  classes directly.
- `docs/harness.md` and browser specs still describe and assert the old class
  names: `.code-viewer`, `.code-line`, `.gutter`, `.code`, and `.hover-widget`.
- `docs/architecture.md` and `renderer/browser/README.md` already describe the
  intended split: backend-neutral renderer state plus a browser-only imperative
  view island.
- `scripts/check-architecture.mbtx` keeps `vscode/` and `codemirror/`
  reference-only and prevents product packages from importing reference code.

Relevant Monaco reference points:

- `vscode/src/vs/editor/browser/view.ts` builds a root editor node, an
  `overflow-guard`, `lines-content`, view parts, scrollbars, content widgets,
  overlay widgets, and overflowing widget containers.
- `vscode/src/vs/editor/browser/view/viewPart.ts` defines the view-part lifecycle
  shape: prepare render data, then apply DOM writes.
- `vscode/src/vs/editor/browser/view/viewLayer.ts` and
  `viewParts/viewLines/viewLines.ts` provide the view line recycler model.
- `viewParts/contentWidgets/contentWidgets.ts` and
  `viewParts/overlayWidgets/overlayWidgets.ts` provide the widget slot model.
- `viewOverlays.ts` and `viewParts/margin/margin.ts` separate text, margin, and
  overlay rendering.

## Target DOM Shape

The target tree should look like this conceptually:

```html
<section class="moonbit-viewer readonly-editor" data-theme="...">
  <div class="overflow-guard">
    <div class="margin">
      <div class="margin-view-overlays">
        <div class="view-layer line-numbers"></div>
        <div class="view-layer margin-decorations"></div>
      </div>
    </div>

    <div class="lines-content moonbit-viewer-background">
      <div class="view-overlays"></div>
      <div class="view-zones"></div>
      <div class="view-lines"></div>
      <div class="contentWidgets"></div>
      <div class="overlayWidgets"></div>
    </div>

    <div class="scrollbar vertical"></div>
    <div class="scrollbar horizontal"></div>
  </div>

  <div class="overflowingContentWidgets"></div>
  <div class="overflowingOverlayWidgets"></div>
</section>
```

This is a local DOM contract inspired by Monaco. We can use Monaco's structural
vocabulary where it helps, but root and theme-facing class names should be
MoonBit-owned. We should not depend on Monaco CSS, Monaco services, or exact
class-by-class compatibility.

## Current-to-Target Mapping

| Current | Target | Notes |
| --- | --- | --- |
| `.code-viewer` | `.moonbit-viewer.readonly-editor` | Root remains the browser island root. |
| `.code-lines` | `.lines-content .view-lines` | Keep the existing line recycler, but retarget it. |
| `.code-line` | `.view-line` | Line nodes keep `data-line` and absolute positioning. |
| `<pre class="code">` | token content inside `.view-line` | Prefer direct token content or a small `.view-line-content` wrapper with `white-space: pre`. |
| `.margin .margin-lines` | `.margin .margin-view-overlays .line-numbers` | Treat line numbers as a margin view layer. |
| `.gutter` | `.line-numbers .view-line` or `.line-number` | Keep semantic line-number targeting but not the old class. |
| `.hover-layer .hover-widget` | `.contentWidgets .hover-widget` or `.overflowingContentWidgets .hover-widget` | Hover becomes the first content widget. |
| current-line classes on line nodes | `.view-overlays` entry, phased | Start by preserving behavior, then move overlay-only visuals out of text lines. |
| existing custom scrollbars | `.overflow-guard .scrollbar.*` | Keep synthetic scrollbars and renderer-owned scroll state. |

## Non-Goals

- Do not import product code, CSS, or runtime services from `vscode/` or
  `codemirror/`.
- Do not add Monaco's dependency injection, command service, extension host,
  editor contributions, edit context, text area, cursor, selection, minimap, or
  overview ruler as part of this plan.
- Do not switch to native DOM scroll as the source of truth. `ViewLayout` remains
  the scroll authority.
- Do not preserve old harness class names unless a short-lived compatibility
  shim is useful during a single commit.
- Do not make the viewer editable.

## Constraints

- `renderer` must stay backend-neutral.
- DOM node construction, measurement, event wiring, and CSS remain in
  `renderer/browser` and the browser app surface.
- The view tree may use Monaco structural naming, but root and theme-facing class
  names should use MoonBit-owned names and the behavior must stay locally owned.
- Browser tests and `docs/harness.md` must move with the DOM. A passing test that
  still depends on old selectors is not enough.
- The DOM node count must remain proportional to the visible window, not the
  document length.
- Render flushing should keep the current read-before-write discipline.

## Phase 1: Introduce View-Part Containers

Add the target container structure in `renderer/browser/island.mbt` while keeping
current behavior.

Work items:

- Replace root class construction with `.moonbit-viewer.readonly-editor`, keeping
  existing source-loaded/source-empty state under a local state class.
- Add island fields for `overflow_guard`, `lines_content`, `view_lines`,
  `view_overlays`, `view_zones`, `margin_view_overlays`, `content_widgets`,
  `overlay_widgets`, `overflowing_content_widgets`, and
  `overflowing_overlay_widgets`.
- Move current line nodes under `.view-lines`.
- Move current margin line nodes under `.margin-view-overlays .line-numbers`.
- Keep custom scrollbars under `.overflow-guard`.
- Update CSS so layout, transforms, clipping, and empty-source behavior are
  attached to the new containers.

Expected result:

- The viewer looks and scrolls the same.
- Browser tests are updated to locate the new root and line containers.
- Old classes are removed from docs unless still used by code in this phase.

## Phase 2: Rename Lines and Margin Rendering

Make line and margin node rendering match the new tree instead of carrying old
class names inside new containers.

Work items:

- Change line node class generation from `code-line` to `view-line`.
- Change gutter node creation to render line-number nodes inside the margin view
  layer.
- Replace `<pre class="code">` with either direct token spans in `.view-line` or
  a narrow `.view-line-content` wrapper. The wrapper should exist only if it
  makes whitespace, hit testing, or CSS clearer.
- Update token-related browser assertions to search inside `.view-line`.
- Update `docs/harness.md` to document the new stable observability selectors.

Expected result:

- No browser spec depends on `.code-line`, `.gutter`, or `.code`.
- Syntax and semantic token rendering remain unchanged from a user perspective.
- Line recycling still reuses existing DOM nodes across scrolls.

## Phase 3: Turn Hover Into a Content Widget

Generalize the current hover layer into a small local content-widget mechanism.

Work items:

- Introduce a browser-local content widget representation with an id, DOM node,
  anchor position, preferred placement, and overflow policy.
- Mount normal content widgets in `.contentWidgets`.
- Mount overflowing content widgets in `.overflowingContentWidgets` when they are
  allowed to escape the editor clip.
- Move hover widget creation and placement through this content widget path.
- Preserve the current hover controller ownership in `renderer/browser`; do not
  create a Monaco contribution system.
- Keep event propagation guards for hover DOM so pointer movement inside the
  widget does not collapse hover state accidentally.

Expected result:

- Hover is no longer a special root-level layer.
- The same mechanism can later support inline tooltips, peek-like readonly
  panels, and language-feature popovers.
- The hover UI can move closer to Monaco's UX without another DOM restructure.

## Phase 4: Add Overlay Widget Slots

Add the overlay widget path even if the first implementation has only limited
users.

Work items:

- Add a browser-local overlay widget representation for viewport-positioned UI.
- Mount clipped overlay widgets in `.overlayWidgets`.
- Mount overflowing overlay widgets in `.overflowingOverlayWidgets`.
- Keep sizing and placement in the island render flush so reads and writes stay
  ordered.
- Document the distinction between content widgets and overlay widgets in
  `renderer/browser/README.md`.

Expected result:

- Future UI that is not anchored to a text position has a stable DOM slot.
- The viewer no longer needs ad hoc root children for every new floating UI.

## Phase 5: Move Visual Overlays Incrementally

Introduce Monaco-like view overlays without forcing all decorations to move at
once.

Work items:

- Keep syntax and semantic token spans in text content.
- Keep diagnostics or current-line styling inline only where moving them would
  create unnecessary risk.
- Add `.view-overlays` as the destination for visuals that should not rewrite
  text content.
- Move one overlay class at a time, starting with low-risk visuals such as the
  current line or line-level highlights.
- Preserve backend-neutral decoration data in `renderer`; only the DOM placement
  changes in `renderer/browser`.

Expected result:

- Text content rendering becomes less responsible for unrelated visual layers.
- Future overlays can be added without changing token HTML.

## Phase 6: Realign Input and Hit Testing

Update browser input plumbing for the new tree.

Work items:

- Ensure mousemove, mouseleave, wheel, and scrollbar listeners still attach to
  the correct root or guard nodes.
- Verify hit testing still uses backend-neutral geometry rather than DOM class
  checks.
- Add explicit event handling rules for widgets and overlays.
- Keep the existing `MouseTargetKind` model unless a concrete new target is
  needed.
- Consider adding local `data-view-part` attributes for debugging and tests if
  they are more stable than class names.

Expected result:

- DOM restructuring does not leak into renderer hit-test logic.
- Widget interactions do not disturb scroll, hover, or line targeting.

## Phase 7: Update Docs, Specs, and Architecture Notes

Make the new DOM contract official.

Work items:

- Rewrite the browser observability section in `docs/harness.md`.
- Update browser specs to target the new tree and remove assumptions about old
  selectors.
- Update `renderer/browser/README.md` with the view-part container contract.
- Add a short note in `docs/architecture.md` if the browser backend description
  needs to mention the Monaco-shaped DOM tree.
- Leave previously implemented exec plans unchanged; this plan is the follow-up
  to the implemented imperative island work.

Expected result:

- Documentation and tests describe the same DOM the product actually emits.
- Future contributors see one intended layering model, not old selector fossils.

## Validation

For the implementation PR, run:

```sh
just check
just test
just build
just test-browser
```

Additional manual validation:

- Start the dev server against the simple project fixture or another small
  workspace:

  ```sh
  just dev ROOT=/Users/baozhiyuan/Workspace/moonbit-project/simple PORT=<free-port>
  ```

- Inspect the DOM and confirm the root, overflow guard, lines content, view
  lines, margin overlays, content widgets, overlay widgets, and scrollbar slots
  are present.
- Scroll a large file and confirm only visible line nodes are recycled.
- Hover a symbol and confirm the widget appears in the content widget layer and
  remains positioned correctly near viewport edges.
- Confirm browser performance events do not show a meaningful patch-time
  regression.

If port `5173` is already occupied by a dev server, use another port or stop the
old server before running browser checks that assume a fresh server.

## Acceptance Criteria

- The browser viewer emits the documented Monaco-shaped DOM tree.
- Old harness selectors are removed from docs and browser specs.
- Hover is implemented as a content widget, not a dedicated hover layer.
- Lines and margin line numbers are rendered through explicit view layers.
- Synthetic scroll and backend-neutral hit testing remain intact.
- No product package imports from `vscode/` or `codemirror/`.
- The required checks pass.
