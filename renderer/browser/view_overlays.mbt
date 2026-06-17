///|
priv struct ContentViewOverlaysPrepared {
  frame : @view_model.RenderFrame
  viewport : @view_layout.ViewportData
  selection_range : @core.Range?
}

///|
priv struct ContentViewOverlays {
  view_overlays : @rdom.Element
  mut should_render : Bool
  mut prepared : ContentViewOverlaysPrepared?
}

///|
fn ContentViewOverlays::new(document : @rdom.Document) -> ContentViewOverlays {
  let view_overlays = document.create_element("div")
  view_overlays.set_attribute("class", "view-overlays")
  view_overlays.set_attribute("data-view-part", "view-overlays")
  { view_overlays, should_render: true, prepared: None }
}

///|
fn ContentViewOverlays::dom(self : ContentViewOverlays) -> @rdom.Element {
  self.view_overlays
}

///|
impl ViewPart for ContentViewOverlays with fn should_render(self, context) {
  self.should_render ||
  context.change.first_render ||
  context.change.frame_generation_changed ||
  context.change.viewport_window_changed ||
  context.change.scroll_position_changed ||
  context.change.selection_changed ||
  context.change.view_zones_changed
}

///|
impl ViewPart for ContentViewOverlays with fn set_should_render(self, value) {
  self.should_render = value
}

///|
impl ViewPart for ContentViewOverlays with fn on_before_render(_self, _viewport) {
  ()
}

///|
impl ViewPart for ContentViewOverlays with fn prepare_render(self, context) {
  self.prepared = Some({
    frame: context.input.frame,
    viewport: context.viewport,
    selection_range: context.input.selection_range,
  })
}

///|
impl ViewPart for ContentViewOverlays with fn render(self, context) {
  match self.prepared {
    Some(prepared) => {
      self.render_selection_overlays(
        prepared.frame,
        prepared.viewport,
        prepared.selection_range,
      )
      self.view_overlays.set_attribute("style", context.content_transform)
    }
    None => ()
  }
}

///|
impl ViewPart for ContentViewOverlays with fn on_did_render(self) {
  self.should_render = false
  self.prepared = None
}

///|
fn ContentViewOverlays::render_selection_overlays(
  self : ContentViewOverlays,
  frame : @view_model.RenderFrame,
  viewport : @view_layout.ViewportData,
  selection_range : @core.Range?,
) -> Unit {
  self.view_overlays.set_inner_html("")
  let range = match selection_range {
    Some(range) => range
    None => return
  }
  let document = @rdom.document()
  for index in 0..<frame.lines.length() {
    let line = frame.lines[index]
    append_line_selection_segments(
      self.view_overlays,
      document,
      line,
      range,
      viewport.relative_vertical_offset[index],
    )
  }
}
