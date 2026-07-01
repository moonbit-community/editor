// Stage-1 white-box for the viewport render path of the `renderWhitespace` /
// `renderControlCharacters` options (plan:
// monaco-render-whitespace-control-options-port.md). Proves the private
// `render_line_input_for_viewport` seam carries the values sourced from
// `ViewerOptions` into the per-line `RenderLineInput`, the same wiring
// `flush_render` performs (`render_whitespace: self.options.render_whitespace`).

///|
/// Builds the viewport a headless viewer projects for its first frame, the
/// input `render_line_input_for_viewport` consumes during `render_text`.
fn viewport_of(viewer : Viewer) -> @view_layout.ViewportData {
  @view_model.viewport_data_from_render_frame(
    viewer.test_frame(),
    line_height=@core.editor_line_height,
  )
}

///|
test "viewer options default to Selection whitespace and control characters on" {
  let options = ViewerOptions::default()
  assert_true(options.render_whitespace == Selection)
  assert_true(options.render_control_characters)
}

///|
test "viewport line input carries each content-only whitespace mode from options" {
  let modes : Array[@view_layout.RenderWhitespace] = [
    None,
    Boundary,
    Trailing,
    All,
  ]
  for mode in modes {
    let options = ViewerOptions(render_whitespace=mode)
    with_test_viewer(
      "  abc  ",
      viewer => {
        let input = render_line_input_for_viewport(
          viewport_of(viewer),
          0,
          viewer.measured_char_width(),
          render_whitespace=viewer.options.render_whitespace,
          render_control_characters=viewer.options.render_control_characters,
          selection_view_range=None,
        )
        assert_true(input.render_whitespace == mode)
      },
      options~,
    )
  }
}

///|
test "viewport line input carries render_control_characters on a non-ascii line" {
  let options = ViewerOptions(render_control_characters=true)
  with_test_viewer(
    "café\u{202E}",
    viewer => {
      let input = render_line_input_for_viewport(
        viewport_of(viewer),
        0,
        viewer.measured_char_width(),
        render_whitespace=viewer.options.render_whitespace,
        render_control_characters=viewer.options.render_control_characters,
        selection_view_range=None,
      )
      assert_true(input.render_control_characters)
      assert_false(input.is_basic_ascii)
    },
    options~,
  )
}

///|
test "viewport line input leaves Selection mode inert without a threaded selection" {
  let options = ViewerOptions(render_whitespace=Selection)
  with_test_viewer(
    "  abc  ",
    viewer => {
      let input = render_line_input_for_viewport(
        viewport_of(viewer),
        0,
        viewer.measured_char_width(),
        render_whitespace=viewer.options.render_whitespace,
        render_control_characters=viewer.options.render_control_characters,
        selection_view_range=None,
      )
      assert_true(input.render_whitespace == Selection)
      // With no selection threaded, Selection mode resolves to an empty range
      // set and the renderer's Selection branch renders nothing.
      assert_eq(input.selections_on_line.length(), 0)
    },
    options~,
  )
}
