///|
/// The available-space arithmetic ported from Monaco
/// `resizableContentWidget.ts` (`_availableVerticalSpaceAbove`/`Below`,
/// page-space because the hover is an overflowing content widget).
test "hover available space is measured against the page minus Monaco margins" {
  // Editor top 100px into the page; anchor line 200px below the editor top;
  // 800px-tall page body; 18px lines.
  let editor_box_top = 100.0
  let mouse_box_top = 200.0
  let body_height = 800.0
  let line_height = 18.0
  // Above: editorBox.top + mouseBox.top - TOP_HEIGHT(30).
  assert_eq(hover_available_space_above(editor_box_top, mouse_box_top), 270.0)
  // Below: bodyBox.height - (editorBox.top + mouseBox.top + height) -
  // BOTTOM_HEIGHT(24).
  assert_eq(
    hover_available_space_below(
      body_height, editor_box_top, mouse_box_top, line_height,
    ),
    458.0,
  )
}

///|
/// Monaco `_updateMaxDimensions` (`contentHoverWidget.ts:307-312`): the max
/// dimensions scale with the editor but never drop below 750×250 — the floor
/// that keeps the hover readable in a narrow editor window.
test "hover max dimensions keep the 750x250 floor in a narrow editor" {
  // A wide editor: two thirds of the width wins over the floor.
  assert_eq(hover_max_width(1500.0), 990.0)
  // A narrow editor: the 750px floor wins (the narrow-viewer readability fix).
  assert_eq(hover_max_width(600.0), 750.0)
  // A tall editor: a quarter of the height wins over the floor.
  assert_eq(hover_max_height(1200.0), 300.0)
  // A short editor: the 250px floor wins.
  assert_eq(hover_max_height(600.0), 250.0)
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
test "a tall hover near the page bottom flips above" {
  // Anchor near the page bottom: little room below, lots above.
  let editor_box_top = 100.0
  let mouse_box_top = 460.0
  let body_height = 600.0
  let line_height = 18.0
  let content_height = 400.0
  let space_above = hover_available_space_above(editor_box_top, mouse_box_top)
  let space_below = hover_available_space_below(
    body_height, editor_box_top, mouse_box_top, line_height,
  )
  // space_above = 100 + 460 - 30 = 530; space_below = 600 - 578 - 24 = -2.
  assert_eq(space_above, 530.0)
  assert_eq(space_below, -2.0)
  assert_eq(
    hover_prefer_above(
      content_height, space_above, space_below, hover_prefer_above_default,
    ),
    true,
  )
}
