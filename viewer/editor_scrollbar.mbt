///|
priv struct EditorScrollbar {
  editor_scrollable : ScrollableElementDom
  mut should_render : Bool
}

///|
fn EditorScrollbar::new() -> EditorScrollbar {
  let editor_scrollable = ScrollableElementDom::new(
    "lines-content moonbit-viewer-background",
    vertical_size=editor_vertical_scrollbar_size,
    horizontal_size=editor_horizontal_scrollbar_size,
  )
  editor_scrollable.set_wrapper_class(
    "monaco-scrollable-element editor-scrollable",
  )
  editor_scrollable.wrapper.set_attribute("data-view-part", "editor-scrollable")
  editor_scrollable.content.set_attribute("data-view-part", "lines-content")
  editor_scrollable.update_from_model(
    { width: 0.0, scroll_width: 0.0, height: 0.0, scroll_height: 0.0 },
    { scroll_left: 0.0, scroll_top: 0.0 },
  )
  { editor_scrollable, should_render: true }
}

///|
fn EditorScrollbar::wrapper(self : EditorScrollbar) -> @rdom.Element {
  self.editor_scrollable.wrapper
}

///|
fn EditorScrollbar::content(self : EditorScrollbar) -> @rdom.Element {
  self.editor_scrollable.content
}

///|
fn EditorScrollbar::scrollable(self : EditorScrollbar) -> ScrollableElementDom {
  self.editor_scrollable
}

///|
impl ViewPart for EditorScrollbar with fn should_render(self, context) {
  self.should_render ||
  context.change.first_render ||
  context.change.scroll_position_changed ||
  context.change.layout_dimensions_changed ||
  context.change.gutter_width_changed
}

///|
impl ViewPart for EditorScrollbar with fn set_should_render(self, value) {
  self.should_render = value
}

///|
impl ViewPart for EditorScrollbar with fn on_before_render(_self, _viewport) {
  ()
}

///|
impl ViewPart for EditorScrollbar with fn prepare_render(_self, _context) {
  ()
}

///|
impl ViewPart for EditorScrollbar with fn render(self, context) {
  self.editor_scrollable.content.set_attribute(
    "style",
    "left:" + context.gutter_width.to_string() + "px",
  )
  self.editor_scrollable.update_from_model(
    context.dimensions,
    context.position,
    horizontal_left=context.gutter_width,
  )
}

///|
impl ViewPart for EditorScrollbar with fn on_did_render(self) {
  self.should_render = false
}
