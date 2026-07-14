///|
fn estimated_font_info(options : ViewerOptions) -> @config.FontInfo {
  @config.FontInfo::estimated(options.bare_font_info(pixel_ratio=1.0))
}

///|
/// These white-box adapters keep source-fact assertions precise without
/// widening the consolidated view package's production API. The event payload
/// fields remain private; JS white-box tests inspect their emitted runtime
/// representation directly.
extern "js" fn test_view_configuration_changed_options_length(
  event : @view.ViewConfigurationChangedEvent,
) -> Int = "(event) => event.changed_options.length"

///|
extern "js" fn test_view_configuration_has_changed(
  event : @view.ViewConfigurationChangedEvent,
  option : @view.ViewConfigurationOption,
) -> Bool = "(event, option) => event.changed_options.includes(option)"

///|
extern "js" fn test_view_decorations_flags(
  event : @view.ViewDecorationsChangedEvent,
) -> Array[Bool] =
  #| (event) => [
  #|   event.affects_minimap,
  #|   event.affects_overview_ruler,
  #|   event.affects_glyph_margin,
  #|   event.affects_line_number,
  #| ]

///|
extern "js" fn test_view_tokens_range_count(
  event : @view.ViewTokensChangedEvent,
) -> Int = "(event) => event.ranges.length"

///|
extern "js" fn test_view_tokens_range_from(
  event : @view.ViewTokensChangedEvent,
  index : Int,
) -> Int = "(event, index) => event.ranges[index].from_line_number"

///|
extern "js" fn test_view_tokens_range_to(
  event : @view.ViewTokensChangedEvent,
  index : Int,
) -> Int = "(event, index) => event.ranges[index].to_line_number"

///|
extern "js" fn test_view_scroll_values(
  event : @view.ViewScrollChangedEvent,
) -> Array[Double] =
  #| (event) => [
  #|   event.scroll_width,
  #|   event.scroll_left,
  #|   event.scroll_height,
  #|   event.scroll_top,
  #| ]

///|
extern "js" fn test_view_scroll_flags(
  event : @view.ViewScrollChangedEvent,
) -> Array[Bool] =
  #| (event) => [
  #|   event.scroll_width_changed,
  #|   event.scroll_left_changed,
  #|   event.scroll_height_changed,
  #|   event.scroll_top_changed,
  #| ]

///|
extern "js" fn test_view_cursor_selections(
  event : @view.ViewCursorStateChangedEvent,
) -> Array[@core.Selection] = "(event) => event.selections"

///|
extern "js" fn test_view_cursor_model_selections(
  event : @view.ViewCursorStateChangedEvent,
) -> Array[@core.Selection] = "(event) => event.model_selections"

///|
extern "js" fn test_view_cursor_reason(
  event : @view.ViewCursorStateChangedEvent,
) -> @editor_api.CursorChangeReason = "(event) => event.reason"

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
  assert_eq(test_view_configuration_changed_options_length(event), 5)
  assert_true(test_view_configuration_has_changed(event, RenderWhitespace))
  assert_true(
    test_view_configuration_has_changed(event, RenderControlCharacters),
  )
  assert_true(test_view_configuration_has_changed(event, RenderLineHighlight))
  assert_true(
    test_view_configuration_has_changed(event, RenderLineHighlightOnlyWhenFocus),
  )
  assert_true(
    test_view_configuration_has_changed(event, RenderValidationDecorations),
  )
  assert_false(test_view_configuration_has_changed(event, LayoutInfo))
  assert_false(test_view_configuration_has_changed(event, FontInfo))
  assert_false(test_view_configuration_has_changed(event, WrappingInfo))
  let reversed = view_configuration_changed_event(
    current,
    previous,
    font_info,
    font_info,
    0,
    0,
    layout_info_changed=false,
  ).unwrap()
  assert_eq(test_view_configuration_changed_options_length(reversed), 5)
  assert_true(test_view_configuration_has_changed(reversed, RenderWhitespace))
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
  assert_eq(test_view_configuration_changed_options_length(font_event), 1)
  assert_true(test_view_configuration_has_changed(font_event, FontInfo))
  assert_false(test_view_configuration_has_changed(font_event, LineHeight))

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
  assert_true(test_view_configuration_has_changed(height_event, LayoutInfo))
  assert_true(test_view_configuration_has_changed(height_event, FontInfo))
  assert_true(test_view_configuration_has_changed(height_event, LineHeight))

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
  assert_eq(test_view_configuration_changed_options_length(wrapping_event), 1)
  assert_true(test_view_configuration_has_changed(wrapping_event, WrappingInfo))
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
  let event_flags = test_view_decorations_flags(event)
  assert_false(event_flags[0])
  assert_true(event_flags[1])
  assert_false(event_flags[2])
  assert_true(event_flags[3])
  let all = @view.ViewDecorationsChangedEvent::all()
  let all_flags = test_view_decorations_flags(all)
  assert_true(all_flags[0])
  assert_true(all_flags[1])
  assert_true(all_flags[2])
  assert_true(all_flags[3])
}

///|
test "token source preserves inclusive ranges in producer order" {
  let event = view_tokens_changed_event([(2, 4), (9, 9)])
  assert_eq(test_view_tokens_range_count(event), 2)
  assert_eq(test_view_tokens_range_from(event, 0), 2)
  assert_eq(test_view_tokens_range_to(event, 0), 4)
  assert_eq(test_view_tokens_range_from(event, 1), 9)
  assert_eq(test_view_tokens_range_to(event, 1), 9)
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
  let event_values = test_view_scroll_values(event)
  assert_eq(event_values[0], 550.0)
  assert_eq(event_values[1], 30.0)
  assert_eq(event_values[2], 900.0)
  assert_eq(event_values[3], 40.0)
  let event_flags = test_view_scroll_flags(event)
  assert_true(event_flags[0])
  assert_true(event_flags[1])
  assert_true(event_flags[2])
  assert_true(event_flags[3])

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
  let left_flags = test_view_scroll_flags(left_event)
  assert_true(left_flags[1])
  assert_false(left_flags[0])
  assert_false(left_flags[2])
  assert_false(left_flags[3])
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
    let selections = test_view_cursor_selections(event)
    let model_selections = test_view_cursor_model_selections(event)
    assert_eq(selections.length(), 1)
    assert_eq(model_selections.length(), 1)
    assert_true(selections[0] == view_model.cursor.get_view_selection())
    assert_true(model_selections[0] == model_selection)
    assert_true(test_view_cursor_reason(event) == Explicit)
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
