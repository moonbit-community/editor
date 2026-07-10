///|
/// The Monaco `ViewLayout` role: combines the scroll truth (`Scrollable`)
/// with the line layout (`LinesLayout`) and derives the render viewport
/// from them via `get_lines_viewport_data`. Pure model state — input
/// capture and DOM application stay backend-side.
///
/// Like Monaco, the entire view layer is 1-based, so `ViewLayout` and the
/// `LinesLayout` it holds share one coordinate space — line-number arguments
/// pass straight through with no translation. View zones carry Monaco's
/// `afterLineNumber` directly (`ViewZone.anchor_line`). The `LinesLayout` held
/// here is exactly the type the conformance suite validates.
pub struct ViewLayout {
  scrollable : EditorScrollable
  priv mut lines : LinesLayout
  priv mut line_height : Int
  priv mut line_count : Int
  priv mut view_zones_arr : Array[ViewZone]
  priv mut content_width : Double
}

///|
pub(all) struct Viewport {
  top : Double
  left : Double
  width : Double
  height : Double
} derive(Eq, Debug)

///|
pub(all) struct SavedScrollState {
  scroll_top : Double
  scroll_top_without_view_zones : Double
  scroll_left : Double
} derive(Eq, Debug)

///|
let smooth_scrolling_time : Double = 125.0

///|
/// Builds a faithful `LinesLayout` from the view-zone array: each zone becomes
/// a whitespace with `afterLineNumber = anchor_line` (Monaco's
/// `IViewZone.afterLineNumber`, passed straight through), inserted in the
/// array's (already normalized) order via `ordinal`.
fn build_lines(
  line_count : Int,
  line_height : Int,
  zones : Array[ViewZone],
) -> LinesLayout {
  let lines = LinesLayout::new(line_count, line_height, 0, 0)
  lines.change_whitespace(fn(accessor) {
    for i, zone in zones {
      accessor.insert_whitespace(zone.anchor_line, i, zone.height_px, 0)
      |> ignore
    }
  })
  |> ignore
  lines
}

///|
/// Creates a view layout with a fixed line height and optional line count.
pub fn ViewLayout::new(
  line_height~ : Int,
  line_count? : Int = 0,
  smooth_scrolling? : Bool = false,
  schedule_at_next_animation_frame? : (() -> Unit) -> @base_common.Disposable = no_animation_scheduler,
  now? : () -> Double = zero_clock,
) -> ViewLayout {
  let line_count = line_count.max(0)
  let layout : ViewLayout = {
    // `forceIntegerValues: true` (viewLayout.ts): the editor's scroll truth is
    // whole pixels, so fractional trackpad deltas never render at a subpixel
    // transform offset.
    scrollable: EditorScrollable::new(
      if smooth_scrolling {
        smooth_scrolling_time
      } else {
        0.0
      },
      schedule_at_next_animation_frame,
      now,
    ),
    lines: build_lines(line_count, line_height, []),
    line_height,
    line_count,
    view_zones_arr: [],
    content_width: 0.0,
  }
  layout.sync_dimensions() |> ignore
  layout
}

///|
/// Replaces the document extent (line count) and re-derives the scroll
/// dimensions; the position re-clamps when the document shrank.
pub fn ViewLayout::set_line_count(
  self : ViewLayout,
  line_count : Int,
) -> ScrollChange? {
  self.line_count = line_count.max(0)
  self.view_zones_arr = normalized_view_zones(
    self.view_zones_arr,
    self.line_count,
  )
  self.lines = build_lines(
    self.line_count,
    self.line_height,
    self.view_zones_arr,
  )
  self.sync_dimensions()
}

///|
/// The document was replaced — Monaco's `ViewLayout.onFlushed(lineCount)`:
/// `this._linesLayout.onFlushed(lineCount)`. Whitespaces (view zones)
/// survive a flush like the source's; their owner re-normalizes at the
/// Viewer layer (`set_line_count`). The scroll dimensions re-derive in
/// `on_height_maybe_changed`, exactly the source's split.
pub fn ViewLayout::on_flushed(self : ViewLayout, line_count : Int) -> Unit {
  self.line_count = line_count.max(0)
  self.lines.on_flushed(self.line_count)
}

///|
/// Re-derives the scroll dimensions after the content height may have
/// changed — Monaco's `ViewLayout.onHeightMaybeChanged` (`_updateHeight`);
/// a shrunken document clamps the scroll position here.
pub fn ViewLayout::on_height_maybe_changed(self : ViewLayout) -> ScrollChange? {
  self.sync_dimensions()
}

///|
/// The uniform line height in pixels (`fontInfo.lineHeight`).
pub fn ViewLayout::line_height(self : ViewLayout) -> Int {
  self.line_height
}

///|
/// Applies a changed line height and re-derives the scroll dimensions —
/// Monaco's `ViewLayout.onConfigurationChanged` `lineHeight` branch
/// (`this._linesLayout.setLineHeight(...)`).
pub fn ViewLayout::set_line_height(
  self : ViewLayout,
  line_height : Int,
) -> ScrollChange? {
  if line_height == self.line_height {
    return None
  }
  self.line_height = line_height
  self.lines.set_default_line_height(line_height)
  self.sync_dimensions()
}

///|
/// Sets the viewport box measured by the backend.
pub fn ViewLayout::set_viewport_size(
  self : ViewLayout,
  width~ : Double,
  height~ : Double,
) -> ScrollChange? {
  let dimensions = self.scrollable.editor_dimensions()
  self.scrollable.set_editor_dimensions(
    EditorScrollDimensions::new(
      width,
      dimensions.content_width,
      height,
      self.get_content_height(),
    ),
  )
}

///|
/// Sets the widest measured content width (horizontal scrolling extent).
pub fn ViewLayout::set_content_width(
  self : ViewLayout,
  content_width : Double,
) -> ScrollChange? {
  self.content_width = max_double(content_width, 0.0)
  self.sync_dimensions()
}

///|
/// Replaces view zones and re-derives scroll dimensions.
pub fn ViewLayout::set_view_zones(
  self : ViewLayout,
  view_zones : Array[ViewZone],
) -> ScrollChange? {
  self.view_zones_arr = normalized_view_zones(view_zones, self.line_count)
  self.lines = build_lines(
    self.line_count,
    self.line_height,
    self.view_zones_arr,
  )
  self.sync_dimensions()
}

///|
/// Current view-zone slots.
pub fn ViewLayout::view_zones(self : ViewLayout) -> Array[ViewZone] {
  self.view_zones_arr
}

///|
/// Current number of lines.
pub fn ViewLayout::line_count(self : ViewLayout) -> Int {
  self.line_count
}

///|
/// Total scrollable content height, including view zones.
pub fn ViewLayout::get_content_height(self : ViewLayout) -> Double {
  self.lines.get_lines_total_height().to_double()
}

///|
/// The widest measured content (the horizontal scroll extent before clamping to
/// the viewport), Monaco's `ViewLayout.getContentWidth` / scroll-dimensions
/// `contentWidth`. Read by `CodeEditorWidget.getContentWidth`.
pub fn ViewLayout::get_content_width(self : ViewLayout) -> Double {
  self.scrollable.editor_dimensions().content_width
}

///|
/// Scrollable content width = `max(viewport width, content width)`, Monaco's
/// `ViewLayout.getScrollWidth`. Backed by `sync_dimensions`' `scroll_width`.
pub fn ViewLayout::get_scroll_width(self : ViewLayout) -> Double {
  self.scrollable.dimensions().scroll_width
}

///|
/// Scrollable content height = `max(viewport height, content height)`, Monaco's
/// `ViewLayout.getScrollHeight`.
pub fn ViewLayout::get_scroll_height(self : ViewLayout) -> Double {
  self.scrollable.dimensions().scroll_height
}

///|
/// Current horizontal scroll offset, Monaco's `ViewLayout.getCurrentScrollLeft`.
pub fn ViewLayout::get_current_scroll_left(self : ViewLayout) -> Double {
  self.scrollable.position().scroll_left
}

///|
/// Current vertical scroll offset, Monaco's `ViewLayout.getCurrentScrollTop`.
pub fn ViewLayout::get_current_scroll_top(self : ViewLayout) -> Double {
  self.scrollable.position().scroll_top
}

///|
/// Content-space top of a 1-based view line, Monaco's
/// `ViewLayout.getVerticalOffsetForLineNumber` (delegates straight to
/// `LinesLayout`). `include_view_zones` controls whether the whitespace
/// immediately above the line counts toward the offset.
pub fn ViewLayout::get_vertical_offset_for_line_number(
  self : ViewLayout,
  line_number : Int,
  include_view_zones? : Bool = false,
) -> Double {
  self.lines
  .get_vertical_offset_for_line_number(line_number, include_view_zones~)
  .to_double()
}

///|
/// Content-space bottom of a 1-based view line (its top plus its height),
/// Monaco's `ViewLayout.getVerticalOffsetAfterLineNumber`.
pub fn ViewLayout::get_vertical_offset_after_line_number(
  self : ViewLayout,
  line_number : Int,
  include_view_zones? : Bool = false,
) -> Double {
  self.lines
  .get_vertical_offset_after_line_number(line_number, include_view_zones~)
  .to_double()
}

///|
/// The (uniform) height of a 1-based view line, Monaco's
/// `ViewLayout.getLineHeightForLineNumber`.
pub fn ViewLayout::get_line_height_for_line_number(
  self : ViewLayout,
  line_number : Int,
) -> Int {
  self.lines.get_line_height_for_line_number(line_number)
}

///|
/// All lines (and their relative vertical offsets) inside the current
/// viewport, Monaco's `ViewLayout.getLinesViewportData` (delegates to
/// `LinesLayout` with the viewport `[scrollTop, scrollTop + height]`).
pub fn ViewLayout::get_lines_viewport_data(
  self : ViewLayout,
) -> PartialViewLinesViewportData {
  let scroll_top = self.scrollable.position().scroll_top
  let viewport_height = self.scrollable.dimensions().height
  self.lines.get_lines_viewport_data(
    scroll_top.to_int(),
    (scroll_top + viewport_height).to_int(),
  )
}

///|
/// The 1-based view line range fully on screen at the current scroll, Monaco's
/// `ViewLayout.getLinesViewportData().completelyVisible{Start,End}LineNumber`.
/// Returns `(1, 1)` for an empty document so callers never index a missing
/// line.
pub fn ViewLayout::completely_visible_line_range(
  self : ViewLayout,
) -> (Int, Int) {
  if self.line_count <= 0 {
    return (1, 1)
  }
  let data = self.get_lines_viewport_data()
  (
    data.completely_visible_start_line_number,
    data.completely_visible_end_line_number,
  )
}

///|
/// The top of a 1-based `line` in content space. Line numbers clamp to the
/// document so callers can probe one-past-the-end (`line_count + 1`) for a
/// bottom edge.
pub fn ViewLayout::vertical_offset_for_line(
  self : ViewLayout,
  line : Int,
) -> Double {
  let line = @base_common.clamp_int(line, 1, self.line_count + 1)
  self.lines.get_vertical_offset_for_line_number(line).to_double()
}

///|
/// The 1-based line whose band contains a content-space vertical offset,
/// clamped to the document (`1` for an empty one).
pub fn ViewLayout::line_at_vertical_offset(
  self : ViewLayout,
  offset : Double,
) -> Int {
  if self.line_count <= 0 {
    return 1
  }
  self.lines.get_line_number_at_or_after_vertical_offset(offset.to_int())
}

///|
/// Monaco `IViewLayout.getWhitespaceAtVerticalOffset` (viewLayout.ts): the
/// whitespace (view zone) whose band contains a content-space vertical
/// offset, forwarded to `LinesLayout`.
pub fn ViewLayout::get_whitespace_at_vertical_offset(
  self : ViewLayout,
  vertical_offset : Double,
) -> ViewWhitespaceViewportData? {
  self.lines.get_whitespace_at_vertical_offset(vertical_offset.to_int())
}

///|
/// Content-space top offset of a view zone by index.
pub fn ViewLayout::view_zone_vertical_offset(
  self : ViewLayout,
  index : Int,
) -> Double {
  if index < 0 || index >= self.view_zones_arr.length() {
    return 0.0
  }
  self.lines.get_vertical_offset_for_whitespace_index(index).to_double()
}

///|
/// View-zone geometry relative to a rendered line window.
pub fn ViewLayout::view_zone_viewport_data(
  self : ViewLayout,
  window : LineWindow,
) -> Array[ViewZoneViewportData] {
  let out : Array[ViewZoneViewportData] = []
  let window_top = self.vertical_offset_for_line(window.start)
  let window_bottom = self.vertical_offset_for_line(window.end)
  let big_numbers_delta = self.big_numbers_delta_for_window(window).to_double()
  for index in 0..<self.view_zones_arr.length() {
    let zone = self.view_zones_arr[index]
    let zone_top = self.view_zone_vertical_offset(index)
    let zone_bottom = zone_top + zone.height_px.to_double()
    if zone_bottom >= window_top && zone_top <= window_bottom {
      out.push({
        zone_index: index,
        anchor_line: zone.anchor_line,
        height_px: zone.height_px,
        relative_vertical_offset: (zone_top - big_numbers_delta).to_int(),
      })
    }
  }
  out
}

///|
/// Top offset of 1-based `line` relative to Monaco's `bigNumbersDelta` for the
/// rendered window (`linesLayout.ts:738-750`). Below 500000px this is the
/// absolute content offset; above it the large aligned delta is subtracted.
pub fn ViewLayout::relative_vertical_offset_for_line(
  self : ViewLayout,
  window : LineWindow,
  line : Int,
) -> Int {
  self.vertical_offset_for_line(line).to_int() -
  self.big_numbers_delta_for_window(window)
}

///|
/// Monaco `LinesLayout.getLinesViewportData`'s large-number rail origin. The
/// second alignment keeps the delta divisible by the default line height.
pub fn ViewLayout::big_numbers_delta_for_window(
  self : ViewLayout,
  window : LineWindow,
) -> Int {
  let start_vertical_offset = self
    .vertical_offset_for_line(window.start)
    .to_int()
  let step_size = 500000
  if start_vertical_offset < step_size || self.line_height <= 0 {
    return 0
  }
  let delta = start_vertical_offset / step_size * step_size
  delta / self.line_height * self.line_height
}

///|
/// Sets the synthetic scroll position, preserving horizontal position unless
/// `scroll_left` is supplied.
pub fn ViewLayout::scroll_to(
  self : ViewLayout,
  scroll_top~ : Double,
  scroll_left? : Double,
) -> ScrollChange? {
  let position = self.scrollable.position()
  let scroll_left = match scroll_left {
    Some(value) => value
    None => position.scroll_left
  }
  self.scrollable.set_position_now({
    scroll_left: Some(scroll_left),
    scroll_top: Some(scroll_top),
  })
}

///|
/// Applies a relative synthetic scroll delta.
pub fn ViewLayout::scroll_by(
  self : ViewLayout,
  delta_left? : Double = 0.0,
  delta_top? : Double = 0.0,
) -> ScrollChange? {
  self.scrollable.scroll_by(delta_left~, delta_top~)
}

///|
/// Current synthetic scroll position.
pub fn ViewLayout::position(self : ViewLayout) -> ScrollPosition {
  self.scrollable.position()
}

///|
/// Current viewport and content dimensions.
pub fn ViewLayout::dimensions(self : ViewLayout) -> ScrollDimensions {
  self.scrollable.dimensions()
}

///|
pub fn ViewLayout::get_scrollable(self : ViewLayout) -> Scrollable {
  self.scrollable.get_scrollable()
}

///|
pub fn ViewLayout::on_did_scroll(
  self : ViewLayout,
  listener : (ScrollChange) -> Unit,
) -> @base_common.Disposable {
  self.scrollable.on_did_scroll(listener)
}

///|
pub fn ViewLayout::on_did_content_size_change(
  self : ViewLayout,
  listener : (ContentSizeChange) -> Unit,
) -> @base_common.Disposable {
  self.scrollable.on_did_content_size_change(listener)
}

///|
pub fn ViewLayout::set_smooth_scrolling(
  self : ViewLayout,
  enabled : Bool,
) -> Unit {
  self.scrollable.set_smooth_scroll_duration(
    if enabled {
      smooth_scrolling_time
    } else {
      0.0
    },
  )
}

///|
pub fn ViewLayout::validate_scroll_position(
  self : ViewLayout,
  position : ScrollPositionUpdate,
) -> ScrollPosition {
  self.scrollable.validate_scroll_position(position)
}

///|
pub fn ViewLayout::future_position(self : ViewLayout) -> ScrollPosition {
  self.scrollable.future_position()
}

///|
pub fn ViewLayout::get_current_viewport(self : ViewLayout) -> Viewport {
  let dimensions = self.scrollable.dimensions()
  let position = self.scrollable.position()
  {
    top: truncate_double(position.scroll_top),
    left: truncate_double(position.scroll_left),
    width: truncate_double(dimensions.width),
    height: truncate_double(dimensions.height),
  }
}

///|
pub fn ViewLayout::get_future_viewport(self : ViewLayout) -> Viewport {
  let dimensions = self.scrollable.dimensions()
  let position = self.scrollable.future_position()
  {
    top: truncate_double(position.scroll_top),
    left: truncate_double(position.scroll_left),
    width: truncate_double(dimensions.width),
    height: truncate_double(dimensions.height),
  }
}

///|
pub fn ViewLayout::save_state(self : ViewLayout) -> SavedScrollState {
  let position = self.scrollable.future_position()
  let first_line = self.lines.get_line_number_at_or_after_vertical_offset(
    position.scroll_top.to_int(),
  )
  let whitespace_above = self.lines
    .get_whitespace_accumulated_height_before_line_number(first_line)
    .to_double()
  {
    scroll_top: position.scroll_top,
    scroll_top_without_view_zones: position.scroll_top - whitespace_above,
    scroll_left: position.scroll_left,
  }
}

///|
pub fn ViewLayout::scroll_to_smooth(
  self : ViewLayout,
  scroll_top~ : Double,
  scroll_left? : Double,
) -> Unit {
  self.scrollable.set_position_smooth({
    scroll_left,
    scroll_top: Some(scroll_top),
  })
}

///|
pub fn ViewLayout::has_pending_scroll_animation(self : ViewLayout) -> Bool {
  self.scrollable.has_pending_scroll_animation()
}

///|
pub fn ViewLayout::delta_scroll_now(
  self : ViewLayout,
  delta_scroll_left : Double,
  delta_scroll_top : Double,
) -> Unit {
  let position = self.scrollable.position()
  self.scrollable.set_position_now({
    scroll_left: Some(position.scroll_left + delta_scroll_left),
    scroll_top: Some(position.scroll_top + delta_scroll_top),
  })
  |> ignore
}

///|
pub fn ViewLayout::dispose(self : ViewLayout) -> Unit {
  self.scrollable.dispose()
}

///|
/// The half-open window of view lines intersecting the current viewport —
/// the `[startLineNumber, endLineNumber]` band of Monaco's
/// `ViewLayout.getLinesViewportData()`, partially visible edge lines
/// included. Recomputed every frame; the view renders exactly these lines.
pub fn ViewLayout::visible_window(self : ViewLayout) -> LineWindow {
  if self.line_count <= 0 {
    return { start: 1, end: 1 }
  }
  let data = self.get_lines_viewport_data()
  { start: data.start_line_number, end: data.end_line_number + 1 }
}

///|
/// The content-space top of a window's first line: the translation the
/// view applies to the lines layer (`window_origin - scroll_top`).
pub fn ViewLayout::window_origin(
  self : ViewLayout,
  window : LineWindow,
) -> Double {
  self.vertical_offset_for_line(window.start)
}

///|
fn ViewLayout::sync_dimensions(self : ViewLayout) -> ScrollChange? {
  let dimensions = self.scrollable.editor_dimensions()
  self.scrollable.set_editor_dimensions(
    EditorScrollDimensions::new(
      dimensions.width,
      self.content_width,
      dimensions.height,
      self.get_content_height(),
    ),
  )
}

///|
/// Clamps view-zone anchors into `[0, line_count]` (Monaco's `afterLineNumber`
/// range), floors heights at zero, and sorts by `(anchor_line, height_px)`
/// before the zones become faithful whitespaces.
fn normalized_view_zones(
  view_zones : Array[ViewZone],
  line_count : Int,
) -> Array[ViewZone] {
  let normalized : Array[ViewZone] = []
  for zone in view_zones {
    normalized.push({
      anchor_line: @base_common.clamp_int(
        zone.anchor_line,
        0,
        line_count.max(0),
      ),
      height_px: zone.height_px.max(0),
    })
  }
  normalized.sort_by(compare_view_zones)
  normalized
}

///|
fn compare_view_zones(left : ViewZone, right : ViewZone) -> Int {
  let anchor = left.anchor_line - right.anchor_line
  if anchor != 0 {
    anchor
  } else {
    left.height_px - right.height_px
  }
}

///|
/// Monaco `IViewLayout.isAfterLines`: whether a content-space vertical offset
/// sits below every line (and every trailing view zone), forwarded to
/// `LinesLayout`.
pub fn ViewLayout::is_after_lines(
  self : ViewLayout,
  vertical_offset : Double,
) -> Bool {
  self.lines.is_after_lines(vertical_offset.to_int())
}

///|
/// Monaco `IViewLayout.isInTopPadding`, forwarded to `LinesLayout` (the
/// viewer carries no padding options, so its paddings are 0).
pub fn ViewLayout::is_in_top_padding(
  self : ViewLayout,
  vertical_offset : Double,
) -> Bool {
  self.lines.is_in_top_padding(vertical_offset.to_int())
}

///|
/// Monaco `IViewLayout.isInBottomPadding`, forwarded to `LinesLayout`.
pub fn ViewLayout::is_in_bottom_padding(
  self : ViewLayout,
  vertical_offset : Double,
) -> Bool {
  self.lines.is_in_bottom_padding(vertical_offset.to_int())
}
