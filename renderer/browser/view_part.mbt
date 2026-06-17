///|
/// Private Monaco-shaped render lifecycle for browser view concerns.
priv trait ViewPart {
  fn should_render(Self, RenderingContext) -> Bool
  fn on_before_render(Self, @view_layout.ViewportData) -> Unit
  fn prepare_render(Self, RenderingContext) -> Unit
  fn render(Self, RestrictedRenderingContext) -> Unit
  fn on_did_render(Self) -> Unit
}

///|
priv enum ViewPartRole {
  ViewLinesPart
  ViewZonesPart
  ContentViewOverlaysPart
  MarginViewOverlaysPart
  ContentWidgetsPart
  OverlayWidgetsPart
  EditorScrollbarPart
}

///|
fn default_view_parts() -> Array[ViewPartRole] {
  [
    ViewLinesPart,
    ViewZonesPart,
    ContentViewOverlaysPart,
    MarginViewOverlaysPart,
    ContentWidgetsPart,
    OverlayWidgetsPart,
    EditorScrollbarPart,
  ]
}

///|
impl ViewPart for ViewPartRole with fn should_render(_self, _context) {
  true
}

///|
impl ViewPart for ViewPartRole with fn on_before_render(_self, _viewport) {
  ()
}

///|
impl ViewPart for ViewPartRole with fn prepare_render(_self, _context) {
  ()
}

///|
impl ViewPart for ViewPartRole with fn render(self, context) {
  let rendering = context.rendering
  let view = rendering.view_context.view
  let input = rendering.input
  match self {
    ViewLinesPart => {
      view.render_lines(
        input.frame,
        rendering.viewport,
        input.decorations,
        input.generation,
        input.space_width,
      )
      view.lines_content.set_attribute(
        "style",
        "left:" + rendering.gutter_width.to_string() + "px",
      )
      view.view_lines.set_attribute("style", rendering.content_transform())
    }
    ViewZonesPart => {
      view.render_view_zones(input.browser_view_zones, rendering.viewport)
      view.view_zones.set_attribute("style", rendering.content_transform())
    }
    ContentViewOverlaysPart => {
      view.render_selection_overlays(
        input.frame,
        rendering.viewport,
        input.selection_range,
      )
      view.view_overlays.set_attribute("style", rendering.content_transform())
    }
    MarginViewOverlaysPart => {
      view.render_folding_markers(
        rendering.viewport,
        input.view_model,
        input.folding_ranges,
        input.folded_ranges,
        on_toggle_fold=input.on_toggle_fold,
      )
      view.margin.set_attribute(
        "style",
        "width:" + rendering.gutter_width.to_string() + "px",
      )
      view.line_numbers.set_attribute("style", rendering.margin_transform())
      view.folding.set_attribute("style", rendering.margin_transform())
    }
    ContentWidgetsPart => {
      view.content_widgets.set_attribute("style", rendering.content_transform())
      rendering.view_context.viewer.render_hover_widget(view, input.frame)
    }
    OverlayWidgetsPart => ()
    EditorScrollbarPart =>
      view.update_scrollbars(
        input.layout.dimensions(),
        rendering.position,
        rendering.gutter_width,
      )
  }
}

///|
impl ViewPart for ViewPartRole with fn on_did_render(_self) {
  ()
}
