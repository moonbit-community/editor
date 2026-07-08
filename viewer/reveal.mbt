///|
/// Content-coordinate scroll surface, Monaco's `CodeEditorWidget.reveal*`
/// family (`vs/editor/browser/widget/codeEditor/codeEditorWidget.ts:705`–
/// `:946`). These take a model `Position` / `Range` ("line 10, column 15") and
/// compute the minimal scroll to bring it into view, complementing the
/// pixel- and delta-based `scroll_*` entry points above. Every reveal is
/// immediate — the viewer has no smooth-scroll concept, so Monaco's `scrollType`
/// argument is dropped.

///|
/// Reveals a 1-based model line, aligning its top into view (`Simple`).
pub fn Viewer::reveal_line(self : Viewer, line_number : Int) -> Unit {
  self.reveal_line_with(line_number, Simple)
}

///|
/// Reveals a 1-based model line, centering it (`Center`).
pub fn Viewer::reveal_line_in_center(self : Viewer, line_number : Int) -> Unit {
  self.reveal_line_with(line_number, Center)
}

///|
/// Reveals a 1-based model line near the top of the viewport (`NearTop`).
pub fn Viewer::reveal_line_near_top(self : Viewer, line_number : Int) -> Unit {
  self.reveal_line_with(line_number, NearTop)
}

///|
/// Reveals a 1-based model line centered only if it is currently outside the
/// viewport (`CenterIfOutsideViewport`).
pub fn Viewer::reveal_line_in_center_if_outside_viewport(
  self : Viewer,
  line_number : Int,
) -> Unit {
  self.reveal_line_with(line_number, CenterIfOutsideViewport)
}

///|
/// Reveals a model line span `[start, end]` (1-based), aligning its top
/// (`Simple`). Like Monaco's `revealLines`, this is a line-only reveal:
/// horizontal scroll is not adjusted.
pub fn Viewer::reveal_lines(
  self : Viewer,
  start_line_number : Int,
  end_line_number : Int,
) -> Unit {
  self.reveal_lines_with(start_line_number, end_line_number, Simple)
}

///|
/// Reveals a model line span `[start, end]` (1-based), centering it (`Center`).
pub fn Viewer::reveal_lines_in_center(
  self : Viewer,
  start_line_number : Int,
  end_line_number : Int,
) -> Unit {
  self.reveal_lines_with(start_line_number, end_line_number, Center)
}

///|
/// Reveals a model line span `[start, end]` (1-based) near the top (`NearTop`).
pub fn Viewer::reveal_lines_near_top(
  self : Viewer,
  start_line_number : Int,
  end_line_number : Int,
) -> Unit {
  self.reveal_lines_with(start_line_number, end_line_number, NearTop)
}

///|
/// Reveals a model line span `[start, end]` (1-based) centered only if it is
/// currently outside the viewport (`CenterIfOutsideViewport`).
pub fn Viewer::reveal_lines_in_center_if_outside_viewport(
  self : Viewer,
  start_line_number : Int,
  end_line_number : Int,
) -> Unit {
  self.reveal_lines_with(
    start_line_number,
    end_line_number,
    CenterIfOutsideViewport,
  )
}

///|
/// Reveals a 1-based model position, aligning its top (`Simple`) and revealing
/// it horizontally.
pub fn Viewer::reveal_position(
  self : Viewer,
  position : @base_common.Position,
) -> Unit {
  self.reveal_position_with(position, Simple)
}

///|
/// Reveals a 1-based model position centered (`Center`), horizontally too.
pub fn Viewer::reveal_position_in_center(
  self : Viewer,
  position : @base_common.Position,
) -> Unit {
  self.reveal_position_with(position, Center)
}

///|
/// Reveals a 1-based model position near the top (`NearTop`), horizontally too.
pub fn Viewer::reveal_position_near_top(
  self : Viewer,
  position : @base_common.Position,
) -> Unit {
  self.reveal_position_with(position, NearTop)
}

///|
/// Reveals a 1-based model position centered only if it is currently outside
/// the viewport (`CenterIfOutsideViewport`), horizontally too.
pub fn Viewer::reveal_position_in_center_if_outside_viewport(
  self : Viewer,
  position : @base_common.Position,
) -> Unit {
  self.reveal_position_with(position, CenterIfOutsideViewport)
}

///|
/// Reveals a model `Range`, aligning its top (`Simple`) and revealing it
/// horizontally.
pub fn Viewer::reveal_range(self : Viewer, range : @base_common.Range) -> Unit {
  self.send_reveal_range(range, Simple, reveal_horizontal=true)
}

///|
/// Reveals a model `Range` centered (`Center`), horizontally too.
pub fn Viewer::reveal_range_in_center(
  self : Viewer,
  range : @base_common.Range,
) -> Unit {
  self.send_reveal_range(range, Center, reveal_horizontal=true)
}

///|
/// Reveals a model `Range` centered only if it is currently outside the
/// viewport (`CenterIfOutsideViewport`), horizontally too.
pub fn Viewer::reveal_range_in_center_if_outside_viewport(
  self : Viewer,
  range : @base_common.Range,
) -> Unit {
  self.send_reveal_range(range, CenterIfOutsideViewport, reveal_horizontal=true)
}

///|
/// Reveals a model `Range` near the top (`NearTop`), horizontally too.
pub fn Viewer::reveal_range_near_top(
  self : Viewer,
  range : @base_common.Range,
) -> Unit {
  self.send_reveal_range(range, NearTop, reveal_horizontal=true)
}

///|
/// Reveals a model `Range` near the top only if it is currently outside the
/// viewport (`NearTopIfOutsideViewport`), horizontally too.
pub fn Viewer::reveal_range_near_top_if_outside_viewport(
  self : Viewer,
  range : @base_common.Range,
) -> Unit {
  self.send_reveal_range(
    range,
    NearTopIfOutsideViewport,
    reveal_horizontal=true,
  )
}

///|
/// Reveals a model `Range` at the very top of the viewport (`Top`),
/// horizontally too.
pub fn Viewer::reveal_range_at_top(
  self : Viewer,
  range : @base_common.Range,
) -> Unit {
  self.send_reveal_range(range, Top, reveal_horizontal=true)
}

///|
fn Viewer::reveal_line_with(
  self : Viewer,
  line_number : Int,
  vertical_type : @view_layout.VerticalRevealType,
) -> Unit {
  // Monaco's `_revealLine`: a single-line collapsed range, no horizontal reveal.
  let range = @base_common.Range::Range(line_number, 1, line_number, 1)
  self.send_reveal_range(range, vertical_type, reveal_horizontal=false)
}

///|
fn Viewer::reveal_lines_with(
  self : Viewer,
  start_line_number : Int,
  end_line_number : Int,
  vertical_type : @view_layout.VerticalRevealType,
) -> Unit {
  // Monaco's `_revealLines`: a multi-line range, no horizontal reveal.
  let range = @base_common.Range::Range(
    start_line_number, 1, end_line_number, 1,
  )
  self.send_reveal_range(range, vertical_type, reveal_horizontal=false)
}

///|
fn Viewer::reveal_position_with(
  self : Viewer,
  position : @base_common.Position,
  vertical_type : @view_layout.VerticalRevealType,
) -> Unit {
  // Monaco's `_revealPosition`: a collapsed range at the position, with
  // horizontal reveal.
  let range = @base_common.Range::Range(
    position.line_number,
    position.column,
    position.line_number,
    position.column,
  )
  self.send_reveal_range(range, vertical_type, reveal_horizontal=true)
}

///|
/// The shared reveal pipeline, Monaco's `CodeEditorWidget._sendRevealRange`
/// (`codeEditorWidget.ts:685`) folded together with
/// `ViewLines.onRevealRangeRequest` (`viewLines.ts:269`). Converts the model
/// range to a view range, computes the minimal vertical scroll, applies the
/// horizontal rule, and commits the scroll (clamping is free via `Scrollable`).
fn Viewer::send_reveal_range(
  self : Viewer,
  model_range : @base_common.Range,
  vertical_type : @view_layout.VerticalRevealType,
  reveal_horizontal~ : Bool,
) -> Unit {
  guard self.get_view_model() is Some(view_model) else { return }
  // (1) Model range → view range: the wrapping-aware step (with word-wrap on,
  // model line ≠ view line). The conversion belongs at this boundary, never in
  // the pure core.
  let view_range = view_model
    .coordinates_converter()
    .model_range_to_view_range(model_range)
  // (2) Minimal vertical scroll for the view range.
  let scroll_top = view_model.view_layout.compute_scroll_top_to_reveal_range(
    view_range.start_line_number,
    view_range.end_line_number,
    vertical_type,
  )
  // Monaco's `-1` abort sentinel (oversized multi-cursor reveal); the viewer
  // only reveals single ranges, so this never fires today but is preserved so a
  // sentinel is never mistaken for a real offset.
  if scroll_top == -1.0 {
    return
  }
  let multi_line = view_range.start_line_number != view_range.end_line_number
  let start_scroll_top = view_model.view_layout.position().scroll_top
  // (3) Commit the vertical scroll. A multi-line range under horizontal reveal
  // also resets `scroll_left` to 0 so most of both lines show
  // (`viewLines.ts:282`–`:289`). Clamping is free via `Scrollable`.
  let change = if reveal_horizontal && multi_line {
    view_model.view_layout.scroll_to(scroll_top~, scroll_left=0.0)
  } else {
    view_model.view_layout.scroll_to(scroll_top~)
  }
  self.apply_scroll_change(change)
  // (4) Horizontal request bookkeeping, after the vertical scroll so the
  // reveal's own scroll change cannot cancel the request it registers. A
  // single-line horizontal reveal is deferred — the target line's client rects
  // are unknown until it renders — and flushed in `flush_render`. Every other
  // case clears any stale request.
  if reveal_horizontal && !multi_line {
    self.horizontal_reveal_request = Some({
      view_line_number: view_range.start_line_number,
      start_column: view_range.start_column,
      end_column: view_range.end_column,
      start_scroll_top,
      stop_scroll_top: view_model.view_layout.position().scroll_top,
    })
    // The vertical scroll may have been a no-op (line already visible); still
    // schedule a render so the deferred horizontal reveal gets a chance to flush.
    self.schedule_render()
  } else {
    self.horizontal_reveal_request = None
  }
}

///|
/// Flushes a deferred horizontal reveal once its target line has rendered, the
/// Monaco `ViewLines.renderText` horizontal step (`viewLines.ts:623`–`:648`).
/// Called from `flush_render` after the lines are in the DOM. Keeps the request
/// pending if the line is not yet rendered, so a later frame can flush it.
fn Viewer::flush_horizontal_reveal(self : Viewer, view : @view.View) -> Unit {
  guard self.horizontal_reveal_request is Some(request) else { return }
  guard self.get_view_model() is Some(view_model) else { return }
  // The line is not in the rendered window yet — keep waiting.
  guard view.is_line_rendered(request.view_line_number) else { return }
  // The line is rendered: consume the request (Monaco nulls it here) and apply
  // the horizontal scroll, if any was measurable.
  self.horizontal_reveal_request = None
  // `keep_empty=true`: a collapsed range (a `reveal_position` caret) measures to
  // a single zero-width rect at the caret x, which Monaco keeps and reveals.
  let ranges = view.measure_line_selection(
    request.view_line_number,
    request.start_column - 1,
    request.end_column - 1,
    keep_empty=true,
  )
  match
    view_model.view_layout.compute_scroll_left_to_reveal(
      ranges,
      vertical_scrollbar_width=@core.editor_vertical_scrollbar_size,
    ) {
    Some(scroll_left) => {
      // Set only `scroll_left`; the vertical reveal already settled `scroll_top`.
      let scroll_top = view_model.view_layout.position().scroll_top
      self.apply_scroll_change(
        view_model.view_layout.scroll_to(scroll_top~, scroll_left~),
      )
    }
    None => ()
  }
}

///|
/// Monaco's `ViewLines.onScrollChanged` horizontal-cancel (`viewLines.ts:305`–
/// `:317`): drop a pending horizontal reveal when an unrelated scroll moves the
/// horizontal position, or moves the vertical position outside the reveal's
/// `[start_scroll_top, stop_scroll_top]` band. The reveal's own vertical scroll
/// lands inside that band and does not change `scroll_left`, so it never
/// cancels itself.
fn Viewer::cancel_horizontal_reveal_on_scroll(
  self : Viewer,
  change : @view_layout.ScrollChange,
) -> Unit {
  guard self.horizontal_reveal_request is Some(request) else { return }
  if change.left_changed {
    self.horizontal_reveal_request = None
    return
  }
  if change.top_changed {
    let scroll_top = change.position.scroll_top
    let a = request.start_scroll_top
    let b = request.stop_scroll_top
    let low = if a < b { a } else { b }
    let high = if a > b { a } else { b }
    if scroll_top < low || scroll_top > high {
      self.horizontal_reveal_request = None
    }
  }
}
