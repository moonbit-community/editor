// Headless behavior-test harness — the MoonBit analog of vscode's
// editor/test/browser/testCodeEditor.ts. Drives a real Viewer + ViewModel +
// CursorsController over an in-memory model WITHOUT attaching a DOM view
// (mirrors TestCodeEditor._createView returning null), so tests assert on
// semantic state — positions, ranges, projected view lines, frames — instead
// of rendered pixels.
//
// The seam is `Viewer::attach_model` (attach_model.mbt): it builds the
// tokenized document, view model, and cursor context and stores
// them synchronously before `schedule_render`. Only the DOM flush is deferred,
// and `schedule_render`/`flush_render` already no-op while `view is None`
// (view.mbt). So an unattached viewer has fully-populated semantic state after
// `set_model` — no DOM, no requestAnimationFrame, no measurement needed.

///|
/// Builds a TextModel from raw text. The analog of `instantiateTextModel`.
fn test_model(
  text : String,
  language_id? : String = "plaintext",
) -> @model.TextModel {
  TextModel(
    @base_common.Uri::memory("test-model"),
    "test-model",
    language_id,
    1,
    "",
    text,
  )
}

///|
/// `withTestCodeEditor`: spin up a headless viewer over `text`, run `body`,
/// dispose. No `attach()` — no DOM view — but `set_model` still builds the
/// tokenized doc, view model, render frame, and cursor context synchronously.
fn with_test_viewer(
  text : String,
  body : (Viewer) -> Unit raise,
  options? : ViewerOptions = ViewerOptions::default(),
) -> Unit raise {
  let viewer = Viewer::Viewer(options~) // NOTE: deliberately no attach()
  viewer.set_model(Some(test_model(text)))
  body(viewer)
  viewer.dispose()
}

///|
/// `ITestCodeEditor.getViewModel()` — whitebox read of the private field.
fn Viewer::test_view_model(self : Viewer) -> @view_model.ViewModel {
  self.view_model.unwrap()
}

///|
/// `ITestCodeEditor`'s cursor read — the view model's always-present
/// controller (`viewModelImpl.ts:124`).
fn Viewer::test_cursor(self : Viewer) -> @cursor.CursorsController {
  self.test_view_model().cursor
}

///|
/// The clamped view-line window the viewer would render for the layout's
/// current visible window — the headless analog of `synced_window`, which
/// only runs inside a DOM flush.
fn Viewer::test_window(self : Viewer) -> @view_layout.LineWindow {
  let view_model = self.test_view_model()
  view_model.clamp_window(view_model.view_layout.visible_window())
}

///|
/// Forces a soft-wrap column and reflows the view model, the headless analog
/// of the wrap width an attached viewer derives from its measured content box.
/// `ViewerOptions` carries no wrap-column field (the real column is measured
/// from the DOM via `soft_wrap_column_for_content_width`), so a headless wrap
/// test sets the private column directly. Requires `options.soft_wrap`.
fn Viewer::test_set_soft_wrap_column(self : Viewer, column : Int) -> Unit {
  self.soft_wrap_column = column
  self.on_configuration_changed()
}

///|
/// Sets the viewport box the layout windows against, the headless analog of the
/// measured content box, so frame-windowing can be tested without a DOM.
fn Viewer::test_set_viewport(
  self : Viewer,
  width~ : Double,
  height~ : Double,
) -> Unit {
  self.measured_content_width = width
  self.measured_height = height
  match self.view_model {
    Some(view_model) =>
      view_model.view_layout.set_viewport_size(width~, height~) |> ignore
    None => ()
  }
}

///|
/// A document of `line_count` distinct one-line entries, for windowing tests.
fn long_document(line_count : Int) -> String {
  let out = StringBuilder()
  for i in 0..<line_count {
    if i > 0 {
      out.write_char('\n')
    }
    out.write_string("line ")
    out.write_string(i.to_string())
  }
  out.to_string()
}

///|
/// Component-wise position equality. `@base_common.Position` derives `Eq`/`Debug`
/// but not `Show`, so `assert_eq` on it cannot format a failure message; the
/// rest of this package's tests compare `line_number`/`column` (both `Int`,
/// which has `Show`) the same way.
fn assert_position(
  actual : @base_common.Position,
  expected : @base_common.Position,
) -> Unit raise {
  assert_eq(actual.line_number, expected.line_number)
  assert_eq(actual.column, expected.column)
}

///|
/// Selection equality by endpoints (anchor + active), for the same `Show` reason
/// as `assert_position`.
fn assert_selection_eq(
  actual : @core.Selection,
  expected : @core.Selection,
) -> Unit raise {
  assert_position(actual.get_selection_start(), expected.get_selection_start())
  assert_position(actual.get_position(), expected.get_position())
}

///|
/// `assertCursor`: compare the controller's model selection to an expected one.
fn assert_cursor(viewer : Viewer, expected : @core.Selection) -> Unit raise {
  assert_selection_eq(viewer.test_cursor().get_model_selection(), expected)
}

///|
/// The seam this harness rests on: an unattached viewer (no `attach()`, no DOM
/// view) still has a fully-populated view model synchronously after
/// `set_model`. With a measured viewport the whole short document is the
/// window.
test "set_model populates the view model without attaching" {
  with_test_viewer("alpha\nbeta\ngamma", viewer => {
    viewer.test_set_viewport(width=800.0, height=400.0)
    let window = viewer.test_window()
    assert_eq(window.start, 1)
    assert_eq(window.end, 4)
    assert_eq(viewer.test_view_model().line_count(), 3)
  })
}

///|
/// Step 2 (worked example): the view-axis / soft-wrap projection the memory
/// note flags as previously regressing undetected, now a fast precise harness
/// test instead of a broad/brittle Playwright assertion. Routes a model column
/// through the full Viewer -> ViewModel -> CoordinatesConverter stack.
test "soft wrap maps a model column to the correct view position" {
  let options = ViewerOptions(soft_wrap=true)
  with_test_viewer(
    "abcdefghij",
    viewer => {
      viewer.test_set_soft_wrap_column(6)
      let converter = viewer.test_view_model().coordinates_converter()
      // wrap col 6: view line 1 = "abcdef" (model cols 1-6), view line 2 = "ghij"
      // (model cols 7-10). Model col 9 ('i') projects onto view line 2, col 3.
      let view_pos = converter.model_position_to_view_position(Position(1, 9))
      assert_position(view_pos, Position(2, 3))
      // The wrap boundary itself: model col 7 ('g') starts the continuation line.
      let boundary = converter.model_position_to_view_position(Position(1, 7))
      assert_position(boundary, Position(2, 1))
    },
    options~,
  )
}

///|
/// Step 2 (worked example): the render frame windows to the scrolled viewport
/// while the document height is retained — the semantic core of the
/// "windows the rendered lines while keeping the document height" Playwright
/// spec, now deterministic and DOM-free.
test "render frame windows to the visible range, not the whole document" {
  with_test_viewer(long_document(200), viewer => {
    viewer.test_set_viewport(width=800.0, height=400.0)
    viewer.set_scroll_top(720.0)
    let window = viewer.test_window()
    // Document height is retained...
    assert_eq(viewer.test_view_model().line_count(), 200)
    // ...but only the lines intersecting the viewport are rendered.
    // scroll_top 720 = 40 lines * 18px line height: line 41 is the first
    // visible line.
    assert_eq(window.start, 41)
    assert_true(
      window.end - window.start < viewer.test_view_model().line_count(),
    )
  })
}

///|
/// ModelDecorationOptions plan Phase 5 headless proof: `delta_decorations` from a host
/// makes decorations queryable through the public API and carries them into
/// the render inputs (the viewport's line-span chain and the
/// DecorationsOverlay's viewport collection), including the
/// `ViewModelDecorations` cache invalidation on decoration change.
test "host delta_decorations flows through query API and render inputs" {
  let viewer = Viewer::Viewer()
  viewer.set_model(Some(test_model("alpha beta\ngamma")))
  let view_model = viewer.view_model.unwrap()
  // Prime the viewport cache before the host adds decorations, so the second
  // query proves onDidChangeDecorations invalidates it.
  let viewport_range : @base_common.Range = Range(1, 1, 2, 6)
  let before = view_model
    .decorations()
    .get_decorations_viewport_data(viewport_range)
  assert_eq(before.decorations.length(), 0)
  let ids = viewer.delta_decorations([], [
    {
      range: Range(1, 1, 1, 6),
      options: ModelDecorationOptions("myHighlight", description="host"),
    },
    {
      range: Range(2, 1, 2, 3),
      options: ModelDecorationOptions(
        "",
        inline_class_name="host-inline",
        description="host",
      ),
    },
  ])
  assert_eq(ids.length(), 2)
  // Queryable back through the public API (ownerId-scoped).
  assert_eq(viewer.get_line_decorations(1).length(), 1)
  assert_eq(viewer.get_line_decorations(1)[0].options.class_name, "myHighlight")
  assert_eq(viewer.get_decorations_in_range(Range(1, 1, 2, 6)).length(), 2)
  // The same viewport range now resolves the new decorations (cache dropped).
  let after = view_model
    .decorations()
    .get_decorations_viewport_data(viewport_range)
  assert_eq(after.decorations.length(), 2)
  assert_true(after.decorations.any(d => d.options.class_name == "myHighlight"))
  // Render inputs: the inline chain produces the line span; the className
  // decoration is the DecorationsOverlay's input, never a line span.
  let viewport = @view_model.viewport_data_from_view_model(
    view_model,
    { start: 1, end: 3 },
    line_height=18,
  )
  assert_true(
    viewport.line_decorations[1].any(d => d.class_name == "host-inline"),
  )
  assert_false(
    viewport.line_decorations[0].any(d => d.class_name == "myHighlight"),
  )
  // The decorations-changed signal reached the view event source.
  assert_true(viewer.decorations_generation > 0)
  // removeDecorations drops them everywhere.
  viewer.remove_decorations(ids)
  assert_eq(viewer.get_line_decorations(1).length(), 0)
  assert_eq(viewer.get_decorations_in_range(Range(1, 1, 2, 6)).length(), 0)
}

///|
/// The editor-id ownership filter: another editor's decorations (a different
/// ownerId) stay invisible to this viewer's scoped queries, while ownerId-0
/// (model-level, e.g. markers) decorations are included.
test "decoration queries are scoped by editor id like Monaco" {
  let viewer = Viewer::Viewer()
  let model = test_model("alpha beta")
  viewer.set_model(Some(model))
  // Model-level decoration (ownerId 0): visible to the scoped query.
  let _ = model.delta_decorations([], [
    { range: Range(1, 1, 1, 3), options: ModelDecorationOptions("model-level") },
  ])
  // Foreign editor's decoration: filtered out.
  let _ = model.delta_decorations(
    [],
    [{ range: Range(1, 4, 1, 6), options: ModelDecorationOptions("foreign") }],
    owner_id=viewer.editor_id + 1000,
  )
  let names = viewer.get_line_decorations(1).map(d => d.options.class_name)
  if names != ["model-level"] {
    fail("got \{to_repr(names)}")
  }
}

///|
/// Single-state toy tokenizer tagging the first character as a keyword — the
/// encoder's gap fill makes every non-empty line exactly two tokens, so the
/// token count discriminates a registry hit (2) from the null fallback (1).
priv struct FirstCharKeywordToy {}

///|
let first_char_toy_state : @syntax.TokenizerState = TokenizerState("s")

///|
impl @syntax.LineTokenizer for FirstCharKeywordToy with fn initial_state(_self) {
  first_char_toy_state
}

///|
impl @syntax.LineTokenizer for FirstCharKeywordToy with fn tokenize_line(
  _self,
  line_text,
  state,
) {
  ignore(line_text)
  let tokens : Array[@syntax.LineToken] = [{ start: 0, end: 1, tag: Keyword }]
  (tokens, state)
}

///|
/// Tokenizer (re)registration reaches the viewer through the model's own
/// registry subscription: part reset → `model.onDidChangeTokens` →
/// `retokenize_current_model` — the Monaco fan-out (no viewer-level relay).
test "tokenizer registration recolors the current model" {
  let viewer = Viewer::Viewer()
  viewer.set_model(Some(test_model("alpha beta", language_id="recolor-toy")))
  let model = viewer.get_model().unwrap()
  // Warmed by attach; registry miss → one default token on the line.
  assert_eq(model.tokenization.token_count(), 1)
  let registration = @syntax.tokenization_registry.register("recolor-toy", FirstCharKeywordToy::{

  })
  // The viewer re-warmed the reset memo synchronously.
  assert_true(model.tokenization.has_tokens())
  assert_eq(model.tokenization.token_count(), 2)
  // Deregistration walks the same path back to the null fallback.
  registration.dispose()
  assert_true(model.tokenization.has_tokens())
  assert_eq(model.tokenization.token_count(), 1)
  viewer.dispose()
  model.dispose()
}

///|
/// A disposed model detaches itself from the viewer —
/// `model.onWillDispose(() => this.setModel(null))` (`codeEditorWidget.ts:1787`).
test "disposing the installed model detaches it from the viewer" {
  let viewer = Viewer::Viewer()
  let model = test_model("alpha")
  viewer.set_model(Some(model))
  let mut model_change_events = 0
  viewer.on_did_change_model(_ => model_change_events += 1) |> ignore
  model.dispose()
  assert_true(viewer.get_model() is None)
  assert_eq(model_change_events, 1)
  assert_true(model.is_disposed())
  viewer.dispose()
}

///|
/// Swapping models rotates the will-dispose subscription: disposing the
/// replaced model must not detach the current one.
test "disposing a replaced model leaves the current model attached" {
  let viewer = Viewer::Viewer()
  let first = test_model("one")
  viewer.set_model(Some(first))
  let second = test_model("two")
  viewer.set_model(Some(second))
  first.dispose()
  assert_eq(viewer.get_model().unwrap().get_value(), "two")
  viewer.dispose()
  second.dispose()
}
