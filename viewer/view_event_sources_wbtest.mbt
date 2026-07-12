///|
fn estimated_font_info(options : ViewerOptions) -> @config.FontInfo {
  @config.FontInfo::estimated(options.bare_font_info(pixel_ratio=1.0))
}

///|
test "view configuration source preserves independent paint axes and no-op" {
  let previous = ViewerOptions::default()
  let font_info = estimated_font_info(previous)
  assert_true(
    view_configuration_changed_event(
      previous,
      previous,
      font_info,
      font_info,
      0,
      0,
      layout_info_changed=false,
    )
    is None,
  )
  let current = {
    ..previous,
    render_whitespace: All,
    render_control_characters: false,
    render_line_highlight: Gutter,
    render_line_highlight_only_when_focus: true,
    render_validation_decorations: Off,
  }
  let event = view_configuration_changed_event(
    previous,
    current,
    font_info,
    font_info,
    0,
    0,
    layout_info_changed=false,
  ).unwrap()
  assert_eq(event.changed_options.length(), 5)
  assert_true(event.has_changed(RenderWhitespace))
  assert_true(event.has_changed(RenderControlCharacters))
  assert_true(event.has_changed(RenderLineHighlight))
  assert_true(event.has_changed(RenderLineHighlightOnlyWhenFocus))
  assert_true(event.has_changed(RenderValidationDecorations))
  assert_false(event.has_changed(LayoutInfo))
  assert_false(event.has_changed(FontInfo))
  assert_false(event.has_changed(WrappingInfo))
  let reversed = view_configuration_changed_event(
    current,
    previous,
    font_info,
    font_info,
    0,
    0,
    layout_info_changed=false,
  ).unwrap()
  assert_eq(reversed.changed_options.length(), 5)
  assert_true(reversed.has_changed(RenderWhitespace))
}

///|
test "update_options complete-snapshot no-op skips layout invalidation" {
  let viewer = Viewer::Viewer()
  assert_false(viewer.measure_requested)
  viewer.update_options(viewer.get_options())
  assert_false(viewer.measure_requested)
  viewer.dispose()
}

///|
test "view configuration source separates layout font line-height and wrapping" {
  let previous = ViewerOptions::default()
  let font_info = estimated_font_info(previous)
  let letter_spaced = {
    ..font_info,
    letter_spacing: font_info.letter_spacing + 1.0,
  }
  let font_event = view_configuration_changed_event(
    previous,
    previous,
    font_info,
    letter_spaced,
    0,
    0,
    layout_info_changed=false,
  ).unwrap()
  assert_eq(font_event.changed_options.length(), 1)
  assert_true(font_event.has_changed(FontInfo))
  assert_false(font_event.has_changed(LineHeight))

  let taller = { ..font_info, line_height: font_info.line_height + 1 }
  let height_event = view_configuration_changed_event(
    previous,
    previous,
    font_info,
    taller,
    0,
    0,
    layout_info_changed=true,
  ).unwrap()
  assert_true(height_event.has_changed(LayoutInfo))
  assert_true(height_event.has_changed(FontInfo))
  assert_true(height_event.has_changed(LineHeight))

  let tabbed = { ..previous, tab_size: previous.tab_size + 1 }
  let wrapping_event = view_configuration_changed_event(
    previous,
    tabbed,
    font_info,
    font_info,
    0,
    0,
    layout_info_changed=false,
  ).unwrap()
  assert_eq(wrapping_event.changed_options.length(), 1)
  assert_true(wrapping_event.has_changed(WrappingInfo))
}

///|
test "decimal digit bands and compensated layout lanes stay independently visible" {
  assert_eq(digit_count(0), 1)
  assert_eq(digit_count(1), 1)
  assert_eq(digit_count(9), 1)
  assert_eq(digit_count(10), 2)
  assert_eq(digit_count(99), 2)
  assert_eq(digit_count(100), 3)

  let viewer = Viewer::Viewer()
  viewer.font_info = { ..viewer.font_info, max_digit_width: 10.0 }
  viewer.options = ViewerOptions(
    line_numbers_min_chars=5,
    line_decorations_width=10,
    folding=false,
  )
  let before = viewer.layout_identity(3, 3)
  viewer.options = ViewerOptions(
    line_numbers_min_chars=4,
    line_decorations_width=20,
    folding=false,
  )
  let after = viewer.layout_identity(3, 3)
  assert_eq(before.content_left, after.content_left)
  assert_true(before.line_numbers_width != after.line_numbers_width)
  assert_true(before.decorations_width != after.decorations_width)
  assert_true(before != after)
  viewer.dispose()
}

///|
test "set_value synchronizes a decimal line-count band into layout identity" {
  let viewer = Viewer::Viewer(
    options=ViewerOptions(line_numbers_min_chars=1, folding=false),
  )
  let nine = @model.TextModel(
    try! @base_common.Uri::from(
      scheme="inmemory",
      authority="model",
      path="/nine-lines.txt",
    ),
    "nine-lines.txt",
    "plaintext",
    1,
    "nine",
    ["1", "2", "3", "4", "5", "6", "7", "8", "9"].join("\n"),
  )
  viewer.set_model(Some(nine))
  assert_eq(viewer.layout_model_line_count, 9)
  assert_eq(viewer.layout_line_count, 9)
  let before = viewer.layout_identity(
    viewer.layout_model_line_count,
    viewer.layout_line_count,
  )
  viewer.set_value(
    ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"].join("\n"),
  )
  assert_eq(viewer.layout_model_line_count, 10)
  assert_eq(viewer.layout_line_count, 10)
  let after = viewer.layout_identity(
    viewer.layout_model_line_count,
    viewer.layout_line_count,
  )
  assert_true(after.line_numbers_width > before.line_numbers_width)
  assert_true(after != before)
  viewer.dispose()
  nine.dispose()
}

///|
test "wrapped view-line growth does not widen the model line-number band" {
  let text = [
    "abcdefghij", "abcdefghij", "abcdefghij", "abcdefghij", "abcdefghij", "abcdefghij",
    "abcdefghij", "abcdefghij", "abcdefghij",
  ].join("\n")
  with_test_viewer(
    text,
    viewer => {
      let before = viewer.gutter_width(viewer.layout_model_line_count)
      assert_eq(viewer.layout_model_line_count, 9)
      assert_eq(viewer.layout_line_count, 9)
      viewer.test_set_soft_wrap_column(4)
      assert_eq(viewer.layout_model_line_count, 9)
      assert_true(viewer.layout_line_count >= 18)
      assert_true(viewer.gutter_width(viewer.layout_model_line_count) == before)
      assert_true(
        viewer.line_numbers_width(viewer.layout_line_count) >
        viewer.line_numbers_width(viewer.layout_model_line_count),
      )
    },
    options=ViewerOptions(
      soft_wrap=true,
      line_numbers_min_chars=1,
      folding=false,
      font_size=12,
      line_height=18,
    ),
  )
}

///|
test "decoration source copies four flags and null-reset uses all" {
  let event = view_decorations_changed_event({
    affects_minimap: false,
    affects_overview_ruler: true,
    affects_glyph_margin: false,
    affects_injected_text: true,
    affects_line_number: true,
  })
  assert_false(event.affects_minimap)
  assert_true(event.affects_overview_ruler)
  assert_false(event.affects_glyph_margin)
  assert_true(event.affects_line_number)
  let all = @view.ViewDecorationsChangedEvent::all()
  assert_true(all.affects_minimap)
  assert_true(all.affects_overview_ruler)
  assert_true(all.affects_glyph_margin)
  assert_true(all.affects_line_number)
}

///|
test "token source preserves inclusive ranges in producer order" {
  let event = view_tokens_changed_event([(2, 4), (9, 9)])
  assert_eq(event.ranges.length(), 2)
  assert_eq(event.ranges[0].from_line_number, 2)
  assert_eq(event.ranges[0].to_line_number, 4)
  assert_eq(event.ranges[1].from_line_number, 9)
  assert_eq(event.ranges[1].to_line_number, 9)
}

///|
test "scroll source copies four values and independent flags" {
  let previous = @view_layout.ScrollState::new(
    force_integer_values=false,
    100.0,
    500.0,
    10.0,
    200.0,
    800.0,
    20.0,
  )
  let current = @view_layout.ScrollState::new(
    force_integer_values=false,
    100.0,
    550.0,
    30.0,
    200.0,
    900.0,
    40.0,
  )
  let event = view_scroll_changed_event(
    current.create_scroll_event(previous, false),
  )
  assert_eq(event.scroll_width, 550.0)
  assert_eq(event.scroll_left, 30.0)
  assert_eq(event.scroll_height, 900.0)
  assert_eq(event.scroll_top, 40.0)
  assert_true(event.scroll_width_changed)
  assert_true(event.scroll_left_changed)
  assert_true(event.scroll_height_changed)
  assert_true(event.scroll_top_changed)

  let left_only = @view_layout.ScrollState::new(
    force_integer_values=false,
    100.0,
    500.0,
    30.0,
    200.0,
    800.0,
    20.0,
  )
  let left_event = view_scroll_changed_event(
    left_only.create_scroll_event(previous, false),
  )
  assert_true(left_event.scroll_left_changed)
  assert_false(left_event.scroll_width_changed)
  assert_false(left_event.scroll_height_changed)
  assert_false(left_event.scroll_top_changed)
}

///|
test "cursor source carries committed view and model selections with reason" {
  with_test_viewer("alpha", viewer => {
    let position = @base_common.Position::Position(1, 3)
    viewer.set_position(position, source="source-fact-test")
    let view_model = viewer.test_view_model()
    let model_selection = view_model.cursor.get_model_selection()
    let event = view_cursor_state_changed_event(
      view_model,
      [model_selection],
      Explicit,
    )
    assert_eq(event.selections.length(), 1)
    assert_eq(event.model_selections.length(), 1)
    assert_true(event.selections[0] == view_model.cursor.get_view_selection())
    assert_true(event.model_selections[0] == model_selection)
    assert_true(event.reason == Explicit)
  })
}

///|
test "validation option rotates the headless decoration provider" {
  with_test_viewer("alpha", viewer => {
    let model = viewer.get_model().unwrap()
    let _ = model.delta_decorations([], [
      {
        range: Range(1, 1, 1, 3),
        options: ModelDecorationOptions("squiggly-error"),
      },
    ])
    let view_model = viewer.test_view_model()
    let view_range = @base_common.Range::Range(1, 1, 1, 6)
    assert_eq(
      view_model.decorations().get_decorations_viewport_data(view_range).decorations.length(),
      1,
    )
    viewer.update_options({
      ..viewer.get_options(),
      render_validation_decorations: Off,
    })
    assert_eq(
      view_model.decorations().get_decorations_viewport_data(view_range).decorations.length(),
      0,
    )
  })
}

///|
test "view-zone callback is skipped without a real model view" {
  let viewer = Viewer::Viewer()
  let called = Ref(false)
  viewer.change_view_zones(_ => called.val = true)
  assert_false(viewer.measure_requested)
  assert_false(called.val)
  viewer.dispose()
  with_test_viewer("alpha", headless => {
    let measure_requested_before = headless.measure_requested
    headless.change_view_zones(_ => called.val = true)
    assert_false(called.val)
    assert_eq(headless.measure_requested, measure_requested_before)
  })
}
