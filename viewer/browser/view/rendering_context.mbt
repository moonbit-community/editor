///|
/// Inputs `Viewer` provides to `View` for one readonly browser render.
/// `pub(all)`: `Viewer::flush_render` (`view_host.mbt`, root `viewer`
/// package) builds this via a struct literal passed straight into
/// `View::render` — the foreign-method rule keeps that call out of this
/// package, so the literal construction crosses the package boundary.
pub(all) struct ViewRenderInput {
  frame : @view_model.RenderFrame
  view_model : @view_model.ViewModel?
  layout : @view_layout.ViewLayout
  browser_view_zones : Array[@view_zones.BrowserViewZone]
  decorations : Array[@model.Decoration]
  selection_view_range : @view_layout.ViewRange?
  folding_ranges : Array[@language.FoldingRange]
  folded_ranges : Array[@language.FoldingRange]
  hover_state : @hover.HoverController
  on_toggle_fold : (Int) -> Unit
  on_hover_measured : (Bool, Double, Double) -> Unit
  generation : Int
  gutter_width : Double
  space_width : Double
  render_whitespace : @view_layout.RenderWhitespace
  render_control_characters : Bool
}

///|
/// Read/prepare context for view parts. It owns measured viewport data and
/// derived geometry so parts can prepare without recomputing shared inputs.
priv struct RenderingContext {
  view_context : ViewContext
  input : ViewRenderInput
  snapshot : ViewRenderSnapshot
  viewport : @view_layout.ViewportData
  gutter_width : Double
  position : @view_layout.ScrollPosition
  dimensions : @view_layout.ScrollDimensions
  translate_y : Double
}

///|
/// Write-only render context for view parts.
priv struct RestrictedRenderingContext {
  view_context : ViewContext
  viewport : @view_layout.ViewportData
  gutter_width : Double
  position : @view_layout.ScrollPosition
  dimensions : @view_layout.ScrollDimensions
  translate_y : Double
  content_transform : String
  margin_transform : String
  line_height : Int
}

///|
fn RenderingContext::from_input(
  view_context : ViewContext,
  input : ViewRenderInput,
) -> RenderingContext {
  let viewport = match input.view_model {
    Some(model) =>
      @view_model.viewport_data_from_view_model(
        model,
        frame_window(input.frame),
        line_height=@core.editor_line_height,
        decorations=input.decorations,
        layout=input.layout,
      )
    None =>
      @view_model.viewport_data_from_render_frame(
        input.frame,
        line_height=@core.editor_line_height,
      )
  }
  let position = input.layout.position()
  let dimensions = input.layout.dimensions()
  let origin = input.layout.window_origin(frame_window(input.frame))
  let snapshot = ViewRenderSnapshot::from_input(input, position, dimensions)
  {
    view_context,
    input,
    snapshot,
    viewport,
    gutter_width: input.gutter_width,
    position,
    dimensions,
    translate_y: origin - position.scroll_top,
  }
}

///|
fn RenderingContext::restricted(
  self : RenderingContext,
) -> RestrictedRenderingContext {
  {
    view_context: self.view_context,
    viewport: self.viewport,
    gutter_width: self.gutter_width,
    position: self.position,
    dimensions: self.dimensions,
    translate_y: self.translate_y,
    content_transform: self.content_transform(),
    margin_transform: self.margin_transform(),
    line_height: @core.editor_line_height,
  }
}

///|
fn RenderingContext::content_transform(self : RenderingContext) -> String {
  "transform:translate(" +
  (-self.position.scroll_left).to_string() +
  "px," +
  self.translate_y.to_string() +
  "px)"
}

///|
fn RenderingContext::margin_transform(self : RenderingContext) -> String {
  "transform:translateY(" + self.translate_y.to_string() + "px)"
}

///|
priv struct ViewRenderSnapshot {
  window : @view_layout.LineWindow
  generation : Int
  position : @view_layout.ScrollPosition
  dimensions : @view_layout.ScrollDimensions
  gutter_width : Double
  space_width : Double
  selection_view_range : @view_layout.ViewRange?
  folding_ranges : Array[@language.FoldingRange]
  folded_ranges : Array[@language.FoldingRange]
  browser_view_zones : Array[@view_zones.BrowserViewZone]
  hover_state : @hover.HoverController
}

///|
fn ViewRenderSnapshot::from_input(
  input : ViewRenderInput,
  position : @view_layout.ScrollPosition,
  dimensions : @view_layout.ScrollDimensions,
) -> ViewRenderSnapshot {
  {
    window: frame_window(input.frame),
    generation: input.generation,
    position,
    dimensions,
    gutter_width: input.gutter_width,
    space_width: input.space_width,
    selection_view_range: input.selection_view_range,
    folding_ranges: input.folding_ranges.copy(),
    folded_ranges: input.folded_ranges.copy(),
    browser_view_zones: input.browser_view_zones.copy(),
    hover_state: input.hover_state,
  }
}

///|
fn same_browser_view_zones(
  left : Array[@view_zones.BrowserViewZone],
  right : Array[@view_zones.BrowserViewZone],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for index in 0..<left.length() {
    let left_zone = left[index]
    let right_zone = right[index]
    if left_zone.id != right_zone.id ||
      left_zone.anchor_line != right_zone.anchor_line ||
      left_zone.height_px != right_zone.height_px {
      return false
    }
  }
  true
}
