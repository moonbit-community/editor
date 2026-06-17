///|
/// Inputs `Viewer` provides to `View` for one readonly browser render.
priv struct ViewRenderInput {
  frame : @view_model.RenderFrame
  view_model : @view_model.ViewModel?
  layout : @view_layout.ViewLayout
  browser_view_zones : Array[BrowserViewZone]
  decorations : Array[@decorations.Decoration]
  selection_range : @core.Range?
  folding_ranges : Array[@language.FoldingRange]
  folded_ranges : Array[@language.FoldingRange]
  on_toggle_fold : (Int) -> Unit
  generation : Int
  space_width : Double
}

///|
/// Read/prepare context for view parts. It owns measured viewport data and
/// derived geometry so parts can prepare without recomputing shared inputs.
priv struct RenderingContext {
  view_context : ViewContext
  input : ViewRenderInput
  viewport : @view_layout.ViewportData
  gutter_width : Double
  position : @view_layout.ScrollPosition
  translate_y : Double
}

///|
/// Write-only render context for view parts.
priv struct RestrictedRenderingContext {
  rendering : RenderingContext
}

///|
fn RenderingContext::from_input(
  view_context : ViewContext,
  input : ViewRenderInput,
) -> RenderingContext {
  let viewport = match input.view_model {
    Some(model) =>
      @view_layout.ViewportData::from_view_model(
        model,
        frame_window(input.frame),
        line_height=editor_line_height,
        decorations=input.decorations,
        layout=input.layout,
      )
    None =>
      @view_layout.ViewportData::from_render_frame(
        input.frame,
        line_height=editor_line_height,
        decorations=input.decorations,
      )
  }
  let gutter_width = view_context.viewer.gutter_width(input.frame)
  let position = input.layout.position()
  let origin = input.layout.window_origin(frame_window(input.frame))
  {
    view_context,
    input,
    viewport,
    gutter_width,
    position,
    translate_y: origin - position.scroll_top,
  }
}

///|
fn RenderingContext::restricted(
  self : RenderingContext,
) -> RestrictedRenderingContext {
  { rendering: self }
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
