///|
/// Phase 1 of `monaco-hover-logic-chain-port.md`: the available-space arithmetic
/// ported from Monaco `resizableContentWidget.ts` / `contentHoverWidget.ts`.
test "hover available space is measured to the editor edges minus Monaco margins" {
  // Anchor line 200px below the editor top, in a 600px-tall editor, 18px lines.
  let line_top = 200.0
  let editor_height = 600.0
  let line_height = 18.0
  // Above: line_top - TOP_HEIGHT(30).
  assert_eq(hover_available_space_above(line_top), 170.0)
  // Below: editor_height - (line_top + line_height) - BOTTOM_HEIGHT(24).
  assert_eq(
    hover_available_space_below(line_top, line_height, editor_height),
    358.0,
  )
}

///|
test "maximum rendering height is the lesser of available space and content" {
  // Content shorter than the room: render at content height (no scrollbar).
  assert_eq(hover_maximum_rendering_height(170.0, 90.0), 90.0)
  // Content taller than the room: cap to the room (scrollbar engages).
  assert_eq(hover_maximum_rendering_height(170.0, 400.0), 170.0)
}

///|
test "position preference honors editor.hover.above and the side that fits" {
  // Plenty of room above: prefer above.
  assert_eq(hover_prefer_above(100.0, 300.0, 300.0, true), true)
  // Above too small, below fits: flip below even though above is preferred.
  assert_eq(hover_prefer_above(200.0, 50.0, 400.0, true), false)
  // Prefer-below default with room below: render below (not above).
  assert_eq(hover_prefer_above(100.0, 300.0, 300.0, false), false)
  // Prefer-below but below too small: fall back above.
  assert_eq(hover_prefer_above(200.0, 400.0, 50.0, false), true)
}

///|
test "a tall hover near the editor bottom caps to the room above" {
  // Anchor near the bottom: little room below, lots above -> render above and
  // cap the height to the room above so the scrollbar engages within bounds.
  let line_top = 560.0
  let editor_height = 600.0
  let line_height = 18.0
  let content_height = 500.0
  let space_above = hover_available_space_above(line_top)
  let space_below = hover_available_space_below(
    line_top, line_height, editor_height,
  )
  // space_above = 530, space_below = 600 - 578 - 24 = -2.
  assert_eq(space_above, 530.0)
  assert_eq(space_below, -2.0)
  let above = hover_prefer_above(
    content_height, space_above, space_below, hover_prefer_above_default,
  )
  assert_eq(above, true)
  let available = if above { space_above } else { space_below }
  // Content (500) fits within the room above (530): no clipping needed.
  assert_eq(hover_maximum_rendering_height(available, content_height), 500.0)
}
