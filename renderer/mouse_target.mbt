///|
/// What part of the editor surface a mouse position resolves to, mirroring
/// Monaco's `MouseTargetType` for the readonly viewer's needs.
pub(all) enum MouseTargetKind {
  GutterLineNumbers
  ContentText
  ContentEmpty
  BelowContent
  Outside
} derive(Eq, Debug)

///|
/// A resolved hit-test result. `line_number` is one-based; `column` is a
/// zero-based character column inside the line; `offset` is the document
/// offset for the position; `span_index` indexes the hit line's spans.
/// Fields that do not apply to the kind are `0`/`-1`.
pub(all) struct MouseTarget {
  kind : MouseTargetKind
  line_number : Int
  column : Int
  offset : Int
  span_index : Int
} derive(Eq, Debug)

///|
/// Geometry needed to hit-test viewer coordinates against a `RenderFrame`.
/// `origin_x`/`origin_y` locate the viewer's top-left in the same coordinate
/// space as the `x`/`y` passed to `hit_test`. All values are pixels.
pub(all) struct ViewMetrics {
  origin_x : Double
  origin_y : Double
  scroll_top : Double
  viewport_height : Double
  line_height : Int
  char_width : Double
  gutter_width : Double
  view_zones : Array[@view_layout.ViewZone]
} derive(Debug)

///|
fn outside_target() -> MouseTarget {
  { kind: Outside, line_number: 0, column: 0, offset: -1, span_index: -1 }
}

///|
/// Resolves a mouse position to a typed editor target using only render
/// data and metrics; no DOM access. View zones consume their own vertical
/// band (widgets over them stop event propagation, so a zone hit resolves
/// to `Outside`) and shift every line below their anchor.
pub fn hit_test(
  frame : RenderFrame,
  metrics : ViewMetrics,
  x : Double,
  y : Double,
) -> MouseTarget {
  let viewer_x = x - metrics.origin_x
  let viewer_y = y - metrics.origin_y
  if viewer_x < 0.0 ||
    viewer_y < 0.0 ||
    (metrics.viewport_height > 0.0 && viewer_y > metrics.viewport_height) {
    return outside_target()
  }
  let content_y = viewer_y + metrics.scroll_top
  let mut zone_offset = 0
  for zone in metrics.view_zones {
    let zone_top = zone.anchor_line * metrics.line_height + zone_offset
    if content_y < zone_top.to_double() {
      break
    }
    if content_y < (zone_top + zone.height_px).to_double() {
      return outside_target()
    }
    zone_offset = zone_offset + zone.height_px
  }
  let line_index = ((content_y - zone_offset.to_double()) /
  metrics.line_height.to_double()).to_int()
  if line_index >= frame.line_count {
    return {
      kind: BelowContent,
      line_number: frame.line_count,
      column: 0,
      offset: -1,
      span_index: -1,
    }
  }
  let line_number = line_index + 1
  let line = match rendered_line(frame, line_number) {
    Some(line) => line
    None =>
      // The line exists in the document but is outside the rendered window.
      return {
        kind: ContentEmpty,
        line_number,
        column: 0,
        offset: -1,
        span_index: -1,
      }
  }
  if viewer_x < metrics.gutter_width {
    return {
      kind: GutterLineNumbers,
      line_number,
      column: 0,
      offset: line.offset,
      span_index: -1,
    }
  }
  let column = if metrics.char_width > 0.0 {
    ((viewer_x - metrics.gutter_width) / metrics.char_width).to_int()
  } else {
    0
  }
  if column < line.text.length() {
    {
      kind: ContentText,
      line_number,
      column,
      offset: line.offset + column,
      span_index: span_index_at_column(line, column),
    }
  } else {
    {
      kind: ContentEmpty,
      line_number,
      column,
      offset: line.offset + line.text.length(),
      span_index: -1,
    }
  }
}

///|
fn rendered_line(frame : RenderFrame, line_number : Int) -> RenderLine? {
  let index = line_number - 1 - frame.viewport.start_line
  if index >= 0 && index < frame.lines.length() {
    Some(frame.lines[index])
  } else {
    None
  }
}

///|
fn span_index_at_column(line : RenderLine, column : Int) -> Int {
  for index in 0..<line.spans.length() {
    let span = line.spans[index]
    if column >= span.start && column < span.end {
      return index
    }
  }
  -1
}
