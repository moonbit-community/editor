// Phase 4 of `monaco-hover-logic-chain-port.md` — pure geometry/placement
// helpers ported from the content-hover widget cluster
// (`contentHoverRendered.ts`, `contentHoverWidget.ts`). Side-effect-free and
// whitebox-tested; ported ahead of the per-part DOM-structure rework.

///|
/// One hover part as it matters to placement: its (model line/column) range and
/// whether it forces the widget to anchor at that range. Mirrors the
/// `range` / `forceShowAtRange` members `computeHoverPositions` reads off each
/// `IHoverPart`; no viewer participant sets `force_show_at_range` yet.
priv struct HoverPositionPart {
  range : @base_common.Range
  force_show_at_range : Bool
}

///|
/// Monaco `RenderedContentHover.computeHoverPositions` (`contentHoverRendered.ts`
/// :116-164). Computes where the content hover widget anchors. The primary
/// `show_at` is the anchor range start; the secondary `show_at_secondary` is the
/// leftmost start column among the parts that sit entirely on the anchor's start
/// line, clamped down to `secondary_position_column` and back up to
/// `start_column_boundary`. A part with `force_show_at_range` overrides both with
/// its own start position.
///
/// `start_column_boundary` is the model column of the anchor view line's minimum
/// column — Monaco computes it through the coordinates converter; the viewer
/// passes it in (1 when there is no wrapping / model, matching Monaco's
/// `startColumnBoundary = 1` default).
///
/// Returns `(show_at, show_at_secondary)`, Monaco's
/// `{ showAtPosition, showAtSecondaryPosition }`.
fn compute_hover_positions(
  anchor_range : @base_common.Range,
  hover_parts : Array[HoverPositionPart],
  start_column_boundary : Int,
) -> (@base_common.Position, @base_common.Position) {
  // The anchor range is always on a single line.
  let anchor_start_line_number = anchor_range.start_line_number
  let mut secondary_position_column = anchor_range.start_column
  let mut force_show_at_range : @base_common.Range? = None
  for hover_part in hover_parts {
    let hover_part_range = hover_part.range
    let on_anchor_start_line = hover_part_range.start_line_number ==
      anchor_start_line_number
    let on_anchor_end_line = hover_part_range.end_line_number ==
      anchor_start_line_number
    let is_on_anchor_line = on_anchor_start_line && on_anchor_end_line
    if is_on_anchor_line {
      // This message has a range that is completely sitting on the anchor line.
      let hover_part_start_column = hover_part_range.start_column
      let min_secondary_position_column = secondary_position_column.min(
        hover_part_start_column,
      )
      secondary_position_column = min_secondary_position_column.max(
        start_column_boundary,
      )
    }
    if hover_part.force_show_at_range {
      force_show_at_range = Some(hover_part_range)
    }
  }
  match force_show_at_range {
    Some(range) => {
      let force_show_at_position = range.get_start_position()
      (force_show_at_position, force_show_at_position)
    }
    None =>
      (
        anchor_range.get_start_position(),
        Position(anchor_start_line_number, secondary_position_column),
      )
  }
}
