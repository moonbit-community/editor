// Stabilized-visible-range producer/oracle closure (STB-001..005).
//
// Pinned sources from docs/exec-plans/viewer-tokenization-parity.md:
// - browser/widget/codeEditor/codeEditorWidget.ts:1074-1076
//   sha256 18dd294ed185a29c590df75656f18f27d0cefc8d4d778559db946d447130e5d8
// - browser/view.ts:673-679
//   sha256 22edb04795705b7fc8675ba40d89c448a62141201f1a16b1f20d8b26e82771e2

///|
priv struct RestoreStateCountingTokenizer {
  calls : Ref[Int]
}

///|
impl @syntax.LineTokenizer for RestoreStateCountingTokenizer with fn initial_state(
  _self,
) {
  TokenizerState("restore-view-state")
}

///|
impl @syntax.LineTokenizer for RestoreStateCountingTokenizer with fn tokenize_line(
  self,
  _line_text,
  state,
) {
  self.calls.val += 1
  ([], state)
}

///|
fn Viewer::attached_tokenization_state_for_restore_test(
  self : Viewer,
) -> @model_tokens.AttachedViewState raise {
  guard self.model_data is Some(model_data) else {
    fail("expected attached model data")
  }
  guard model_data.attached_view.state() is Some(state) else {
    fail("expected attached-view visible-line state")
  }
  state
}

///|
/// STB-003..005: `View.restoreState` commits both immediate-scroll axes first,
/// the ViewModel-owned scroll listener publishes unstable ranges, and only
/// then the restore producer publishes one stabilized update for the restored
/// viewport. The headless attachment has no scheduler, so the false arm cannot
/// lex; the true arm's synchronous lexer work is an additional ordering oracle.
test "restore view state commits scroll before stabilized visible lines" {
  let calls = Ref(0)
  let registration = @syntax.tokenization_registry.register(
    "restore-view-state-test",
    RestoreStateCountingTokenizer::{ calls, },
  )
  defer registration.dispose()
  let viewer = Viewer::Viewer(
    options=ViewerOptions(font_size=12, line_height=18),
  )
  defer viewer.dispose()
  let model = test_model(
    long_document(200),
    language_id="restore-view-state-test",
  )
  defer model.dispose()
  viewer.set_model(Some(model))

  // STB-001: model initialization is the ordinary one-time true producer.
  assert_true(viewer.attached_tokenization_state_for_restore_test().stabilized)
  let layout = viewer.test_view_model().view_layout
  layout.set_viewport_size(width=90.0, height=36.0) |> ignore
  layout.set_content_width(2000.0) |> ignore
  calls.val = 0

  let scroll_positions : Array[(Double, Double)] = []
  let scroll_states : Array[@model_tokens.AttachedViewState] = []
  let lexer_calls_during_scroll : Array[Int] = []
  let listener = layout.on_did_scroll(_change => {
    let position = layout.position()
    scroll_positions.push((position.scroll_top, position.scroll_left))
    match viewer.model_data {
      Some(model_data) =>
        match model_data.attached_view.state() {
          Some(state) => scroll_states.push(state)
          None => ()
        }
      None => ()
    }
    lexer_calls_during_scroll.push(calls.val)
  })
  defer listener.dispose()

  viewer.restore_view_state(Some({ scroll_top: 180.0, scroll_left: 120.0 }))

  assert_eq(scroll_positions.length(), 1)
  assert_eq(scroll_positions[0].0, 180.0)
  assert_eq(scroll_positions[0].1, 120.0)
  assert_eq(scroll_states.length(), 1)
  assert_false(scroll_states[0].stabilized)
  assert_true(lexer_calls_during_scroll == [0])
  let stabilized = viewer.attached_tokenization_state_for_restore_test()
  assert_true(
    [scroll_states[0].stabilized, stabilized.stabilized] == [false, true],
  )
  assert_true(calls.val > 0)
  let viewport = layout.get_lines_viewport_data()
  assert_eq(stabilized.visible_line_ranges.length(), 1)
  assert_eq(
    stabilized.visible_line_ranges[0].start_line_number,
    viewport.start_line_number,
  )
  assert_eq(
    stabilized.visible_line_ranges[0].end_line_number_exclusive,
    viewport.end_line_number + 1,
  )
}

///|
/// The `None` restore arm is a no-op. Starting from an unstable state makes a
/// stray stabilized call observable; repeated generic render flushes must also
/// leave the same false state untouched instead of becoming a third producer.
test "None restore and repeated render do not publish stabilized visible lines" {
  let viewer = Viewer::Viewer(
    options=ViewerOptions(font_size=12, line_height=18),
  )
  defer viewer.dispose()
  let model = test_model(long_document(80))
  defer model.dispose()
  viewer.set_model(Some(model))
  viewer.test_set_viewport(width=90.0, height=36.0)
  viewer.set_scroll_top(180.0)
  let unstable = viewer.attached_tokenization_state_for_restore_test()
  assert_false(unstable.stabilized)

  viewer.restore_view_state(None)
  assert_true(
    viewer.attached_tokenization_state_for_restore_test().equals(unstable),
  )
  assert_eq(viewer.get_scroll_top(), 180.0)

  viewer.flush_render()
  viewer.flush_render()
  let after_renders = viewer.attached_tokenization_state_for_restore_test()
  assert_true(after_renders.equals(unstable))
  assert_false(after_renders.stabilized)
}

///|
/// STB-002: once the model is absent, even a concrete restore state is a no-op.
/// Retaining the exact detached handle gives the no-model branch an observable
/// false baseline: neither restore nor repeated no-model flushes may change it.
test "restore view state is a no-op without a model" {
  let viewer = Viewer::Viewer(
    options=ViewerOptions(font_size=12, line_height=18),
  )
  defer viewer.dispose()
  let model = test_model(long_document(80))
  defer model.dispose()
  viewer.set_model(Some(model))
  viewer.test_set_viewport(width=90.0, height=36.0)
  viewer.set_scroll_top(180.0)
  guard viewer.model_data is Some(model_data) else {
    fail("expected attached model data")
  }
  let detached_handle = model_data.attached_view
  let before_detach = detached_handle.state().unwrap()
  assert_false(before_detach.stabilized)

  viewer.set_model(None)
  assert_eq(model.get_attached_editor_count(), 0)
  viewer.restore_view_state(Some({ scroll_top: 360.0, scroll_left: 70.0 }))
  viewer.flush_render()
  viewer.flush_render()

  let after_no_model_work = detached_handle.state().unwrap()
  assert_true(after_no_model_work.equals(before_detach))
  assert_false(after_no_model_work.stabilized)
  assert_eq(viewer.get_scroll_top(), -1.0)
  assert_eq(viewer.get_scroll_left(), -1.0)
}
