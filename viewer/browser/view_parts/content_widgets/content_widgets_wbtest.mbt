///|
extern "js" fn install_content_widgets_test_browser() -> Unit =
  #| () => {
  #|   class TestElement extends EventTarget {
  #|     constructor(tag = "div", ownerDocument = null) {
  #|       super();
  #|       this.nodeType = 1;
  #|       this.nodeName = tag.toUpperCase();
  #|       this.ownerDocument = ownerDocument;
  #|       this.parentNode = null;
  #|       this.childNodes = [];
  #|       this.children = this.childNodes;
  #|       this.attributes = new Map();
  #|       this.style = {
  #|         setProperty(name, value) { this[name] = String(value); },
  #|       };
  #|     }
  #|     setAttribute(name, value) { this.attributes.set(name, String(value)); }
  #|     getAttribute(name) { return this.attributes.get(name) ?? ""; }
  #|     removeAttribute(name) { this.attributes.delete(name); }
  #|     appendChild(child) {
  #|       this.childNodes.push(child);
  #|       child.parentNode = this;
  #|       return child;
  #|     }
  #|     removeChild(child) {
  #|       this.childNodes = this.childNodes.filter(item => item !== child);
  #|       this.children = this.childNodes;
  #|       child.parentNode = null;
  #|       return child;
  #|     }
  #|     getBoundingClientRect() {
  #|       return {
  #|         x: 0, y: 0, left: 0, top: 0,
  #|         right: 10, bottom: 10, width: 10, height: 10,
  #|       };
  #|     }
  #|   }
  #|   const ownerDocument = new EventTarget();
  #|   ownerDocument.nodeType = 9;
  #|   ownerDocument.createElement = tag => new TestElement(tag, ownerDocument);
  #|   ownerDocument.body = new TestElement("body", ownerDocument);
  #|   ownerDocument.documentElement = new TestElement("html", ownerDocument);
  #|   ownerDocument.activeElement = null;
  #|   globalThis.document = ownerDocument;
  #|   globalThis.Element = TestElement;
  #| }

///|
extern "js" fn content_widgets_test_style_property(
  element : @rdom.Element,
  name : String,
) -> String =
  #| (element, name) => String(element.style[name] || "")

///|
priv struct TestContentWidget {
  id : String
  dom_node : @rdom.Element
  position : ContentWidgetPosition?
}

///|
impl ContentWidget for TestContentWidget with fn get_id(self) {
  self.id
}

///|
impl ContentWidget for TestContentWidget with fn get_dom_node(self) {
  self.dom_node
}

///|
impl ContentWidget for TestContentWidget with fn get_position(self) {
  self.position
}

///|
impl ContentWidget for TestContentWidget with fn allow_editor_overflow(_self) {
  false
}

///|
fn new_test_content_widget(
  document : @rdom.Document,
  id : String,
  primary : @base_common.Position?,
  secondary : @base_common.Position?,
) -> TestContentWidget {
  {
    id,
    dom_node: document.create_element("div"),
    position: Some({
      position: primary,
      secondary_position: secondary,
      preference: [Below],
    }),
  }
}

///|
test "configuration visits every retained widget and gates layout cache reads" {
  install_content_widgets_test_browser()
  let document = @rdom.document()
  let content_left = Ref(12.0)
  let content_width = Ref(240.0)
  let layout_reads = Ref(0)
  let widgets = ContentWidgets::new(
    document,
    document.create_element("section"),
  )
  widgets.install_live_view_context(
    () => {
      layout_reads.val += 1
      (content_left.val, content_width.val)
    },
    position => Some(position),
  )
  let first = new_test_content_widget(document, "first", None, None)
  let second = new_test_content_widget(document, "second", None, None)
  widgets.add_widget(first)
  widgets.add_widget(second)
  assert_eq(layout_reads.val, 2)
  let first_state = widgets.widgets["first"]
  let second_state = widgets.widgets["second"]
  assert_eq(first_state.content_left, 12.0)
  assert_eq(first_state.content_width, 240.0)
  assert_eq(first_state.max_width, 240.0)
  assert_eq(second_state.content_left, 12.0)
  assert_eq(second_state.content_width, 240.0)
  assert_eq(second_state.max_width, 240.0)

  // A non-layout configuration still delegates to both widgets, but their
  // source branch does not reread or mutate the layout caches.
  content_left.val = 30.0
  content_width.val = 500.0
  widgets.on_configuration_changed(false)
  assert_eq(layout_reads.val, 2)
  assert_eq(first_state.content_left, 12.0)
  assert_eq(first_state.content_width, 240.0)
  assert_eq(first_state.max_width, 240.0)
  assert_eq(second_state.content_left, 12.0)
  assert_eq(second_state.content_width, 240.0)
  assert_eq(second_state.max_width, 240.0)

  // The render read phase only reapplies the retained maxWidth. It cannot
  // substitute for the source-time configuration branch by rereading layout.
  widgets.prepare_render_widgets({
    vertical_offset_for_line: _ => 0.0,
    window_start: 1,
    window_end: 2,
    line_height: 20.0,
    char_width: 8.0,
    typical_fullwidth_character_width: 16.0,
    scroll_top: 0.0,
    scroll_left: 0.0,
    viewport_width: 500.0,
    viewport_height: 200.0,
  })
  assert_eq(layout_reads.val, 2)
  assert_eq(first_state.max_width, 240.0)
  assert_eq(second_state.max_width, 240.0)

  // `layoutInfo` true visits every retained widget in key order; each reads
  // the live context and refreshes contentLeft/contentWidth/maxWidth.
  widgets.on_configuration_changed(true)
  assert_eq(layout_reads.val, 4)
  assert_eq(first_state.content_left, 30.0)
  assert_eq(first_state.content_width, 500.0)
  assert_eq(first_state.max_width, 500.0)
  assert_eq(second_state.content_left, 30.0)
  assert_eq(second_state.content_width, 500.0)
  assert_eq(second_state.max_width, 500.0)
  // Configuration refreshes the retained value; the source's following
  // onBeforeRender write applies that exact cache to the mounted node.
  assert_eq(
    content_widgets_test_style_property(first.dom_node, "max-width"),
    "240px",
  )
  widgets.prepare_render_widgets({
    vertical_offset_for_line: _ => 0.0,
    window_start: 1,
    window_end: 2,
    line_height: 20.0,
    char_width: 8.0,
    typical_fullwidth_character_width: 16.0,
    scroll_top: 0.0,
    scroll_left: 0.0,
    viewport_width: 500.0,
    viewport_height: 200.0,
  })
  assert_eq(
    content_widgets_test_style_property(first.dom_node, "max-width"),
    "500px",
  )
  assert_eq(
    content_widgets_test_style_property(second.dom_node, "max-width"),
    "500px",
  )
}

///|
test "mapping reprojection retains model anchors and visits widgets in key order" {
  install_content_widgets_test_browser()
  let document = @rdom.document()
  let projection_delta = Ref(10)
  let projected_model_positions : Array[@base_common.Position] = []
  let widgets = ContentWidgets::new(
    document,
    document.create_element("section"),
  )
  widgets.install_live_view_context(() => (8.0, 300.0), position => {
    projected_model_positions.push(position)
    Some(
      Position(
        position.line_number + projection_delta.val,
        position.column + projection_delta.val,
      ),
    )
  })
  let first = new_test_content_widget(
    document,
    "first",
    Some(Position(1, 2)),
    Some(Position(1, 4)),
  )
  let second = new_test_content_widget(
    document,
    "second",
    Some(Position(3, 1)),
    None,
  )
  widgets.add_widget(first)
  widgets.set_widget_position(first)
  widgets.add_widget(second)
  widgets.set_widget_position(second)
  projected_model_positions.clear()
  projection_delta.val = 20

  widgets.update_anchors_view_positions()
  assert_eq(projected_model_positions.length(), 3)
  assert_true(projected_model_positions[0] == Position(1, 2))
  assert_true(projected_model_positions[1] == Position(1, 4))
  assert_true(projected_model_positions[2] == Position(3, 1))
  let first_state = widgets.widgets["first"]
  let second_state = widgets.widgets["second"]
  assert_true(first_state.primary_anchor.model_position == Some(Position(1, 2)))
  assert_true(
    first_state.primary_anchor.view_position == Some(Position(21, 22)),
  )
  assert_true(
    first_state.secondary_anchor.model_position == Some(Position(1, 4)),
  )
  assert_true(
    first_state.secondary_anchor.view_position == Some(Position(21, 24)),
  )
  assert_true(
    second_state.primary_anchor.model_position == Some(Position(3, 1)),
  )
  assert_true(
    second_state.primary_anchor.view_position == Some(Position(23, 21)),
  )
}
