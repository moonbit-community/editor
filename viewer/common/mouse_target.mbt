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
/// A resolved hit-test result as a view position: `line_number` is a one-based
/// view line; `column` is a zero-based view column inside the line; `token_index`
/// indexes the hit line's `IViewLineTokens`. Mirrors Monaco's `MouseTarget`
/// carrying a view `Position` — consumers convert to a model position through the
/// `CoordinatesConverter`, rather than this layer baking in a document offset.
/// Fields that do not apply to the kind are `0`/`-1`.
pub(all) struct MouseTarget {
  kind : MouseTargetKind
  line_number : Int
  column : Int
  token_index : Int
  injected_text_index : Int
} derive(Eq, Debug)

///|
/// Geometry needed to hit-test viewer coordinates against a `RenderFrame`.
/// `origin_x`/`origin_y` locate the viewer's top-left in the same coordinate
/// space as the `x`/`y` passed to `hit_test`. All values are pixels.
pub(all) struct ViewMetrics {
  origin_x : Double
  origin_y : Double
  scroll_top : Double
  scroll_left : Double
  viewport_height : Double
  line_height : Int
  char_width : Double
  gutter_width : Double
  view_zones : Array[@view_layout.ViewZone]
} derive(Debug)

///|
fn outside_target() -> MouseTarget {
  {
    kind: Outside,
    line_number: 0,
    column: 0,
    token_index: -1,
    injected_text_index: -1,
  }
}

///|
/// Resolves a mouse position to a typed editor target using only render
/// data and metrics; no DOM access. View zones consume their own vertical
/// band (widgets over them stop event propagation, so a zone hit resolves
/// to `Outside`) and shift every line below their anchor.
pub fn hit_test(
  frame : @view_model.RenderFrame,
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
      token_index: -1,
      injected_text_index: -1,
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
        token_index: -1,
        injected_text_index: -1,
      }
  }
  if viewer_x < metrics.gutter_width {
    return {
      kind: GutterLineNumbers,
      line_number,
      column: 0,
      token_index: -1,
      injected_text_index: -1,
    }
  }
  // Horizontal scroll moves content left under the sticky gutter, so the
  // content column at a viewer x adds the scrolled-away width back in. Round to
  // the nearest character boundary (the browser's caret APIs round; this
  // monospace path is only the caret-API-miss fallback) instead of truncating,
  // which would bias every hit to the left edge of the glyph under the pointer.
  let column = if metrics.char_width > 0.0 {
    let content_x = viewer_x - metrics.gutter_width + metrics.scroll_left
    (content_x / metrics.char_width + 0.5).to_int()
  } else {
    0
  }
  if column < line.text.length() {
    {
      kind: ContentText,
      line_number,
      column,
      token_index: token_index_at_column(line, column),
      injected_text_index: line.injected_text_index_at_column(column),
    }
  } else {
    {
      kind: ContentEmpty,
      line_number,
      column,
      token_index: -1,
      injected_text_index: -1,
    }
  }
}

///|
fn rendered_line(
  frame : @view_model.RenderFrame,
  line_number : Int,
) -> @view_model.RenderLine? {
  let index = line_number - frame.viewport.start_line
  if index >= 0 && index < frame.lines.length() {
    Some(frame.lines[index])
  } else {
    None
  }
}

///|
/// Index of the token covering a zero-based view column, Monaco's
/// `LineTokens.findTokenIndexAtOffset`. Only called for an in-text column, so
/// the offset always lands inside a token.
fn token_index_at_column(line : @view_model.RenderLine, column : Int) -> Int {
  line.tokens.find_token_index_at_offset(column)
}
