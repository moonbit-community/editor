// Phase 4 of `monaco-hover-logic-chain-port.md`: whitebox coverage for
// `compute_hover_positions`. One case per behavior-switching branch.

///|
fn pos_part(
  start_line : Int,
  start_column : Int,
  end_line : Int,
  end_column : Int,
  force~ : Bool = false,
) -> HoverPositionPart {
  {
    range: Range(start_line, start_column, end_line, end_column),
    force_show_at_range: force,
  }
}

///|
test "computeHoverPositions: secondary column is the leftmost part start on the anchor line" {
  let anchor = @base_common.Range::Range(2, 10, 2, 14)
  let (show_at, show_at_secondary) = compute_hover_positions(
    anchor,
    [
      // On the anchor line, starting left of the anchor: pulls the secondary left.
      pos_part(2, 6, 2, 9),
      // Starts on the anchor line but spans onto the next line: not "on the
      // anchor line", so it is ignored even though it starts further left.
      pos_part(2, 3, 3, 1),
      // Entirely on a different line: ignored.
      pos_part(5, 1, 5, 4),
    ],
    1,
  )
  // The primary anchor is the anchor range start.
  assert_eq(show_at.line_number, 2)
  assert_eq(show_at.column, 10)
  // The secondary anchor moved left to the leftmost on-anchor-line part.
  assert_eq(show_at_secondary.line_number, 2)
  assert_eq(show_at_secondary.column, 6)
}

///|
test "computeHoverPositions: secondary column is clamped up to the start-column boundary" {
  let anchor = @base_common.Range::Range(2, 10, 2, 14)
  // The part starts at column 3, but the view line's minimum model column is 8.
  let (_, show_at_secondary) = compute_hover_positions(
    anchor,
    [pos_part(2, 3, 2, 5)],
    8,
  )
  assert_eq(show_at_secondary.column, 8)
}

///|
test "computeHoverPositions: no on-anchor-line parts leaves the secondary at the anchor start" {
  let anchor = @base_common.Range::Range(4, 7, 4, 9)
  // Empty parts, and a part off the anchor line: secondary stays the anchor start column.
  let (_, empty_secondary) = compute_hover_positions(anchor, [], 1)
  assert_eq(empty_secondary.line_number, 4)
  assert_eq(empty_secondary.column, 7)
  let (_, off_line_secondary) = compute_hover_positions(
    anchor,
    [pos_part(9, 1, 9, 2)],
    1,
  )
  assert_eq(off_line_secondary.column, 7)
}

///|
test "computeHoverPositions: forceShowAtRange overrides both positions, last one wins" {
  let anchor = @base_common.Range::Range(2, 10, 2, 14)
  let (show_at, show_at_secondary) = compute_hover_positions(
    anchor,
    [pos_part(6, 3, 6, 8, force=true), pos_part(7, 2, 7, 5, force=true)],
    1,
  )
  // Both the primary and secondary collapse to the last forced part's start.
  assert_eq(show_at.line_number, 7)
  assert_eq(show_at.column, 2)
  assert_eq(show_at_secondary.line_number, 7)
  assert_eq(show_at_secondary.column, 2)
}
