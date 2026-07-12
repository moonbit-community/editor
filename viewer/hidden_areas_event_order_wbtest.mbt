///|
extern "js" fn install_hidden_areas_test_browser() -> Unit =
  #| () => {
  #|   class HiddenAreasTestElement extends EventTarget {
  #|     constructor(tag = "div") {
  #|       super();
  #|       this.nodeType = 1;
  #|       this.nodeName = tag.toUpperCase();
  #|       this.attributes = new Map();
  #|       this.childNodes = [];
  #|       this.children = this.childNodes;
  #|       this.parentNode = null;
  #|       this.style = {
  #|         setProperty(name, value) { this[name] = value; },
  #|       };
  #|       this.scrollTop = 0;
  #|       this.scrollLeft = 0;
  #|       this.scrollWidth = 1000;
  #|       this.scrollHeight = 1000;
  #|     }
  #|     setAttribute(name, value) { this.attributes.set(name, String(value)); }
  #|     getAttribute(name) { return this.attributes.get(name) ?? ""; }
  #|     removeAttribute(name) { this.attributes.delete(name); }
  #|     appendChild(child) {
  #|       if (child.parentNode) child.parentNode.removeChild(child);
  #|       this.childNodes.push(child);
  #|       child.parentNode = this;
  #|       return child;
  #|     }
  #|     removeChild(child) {
  #|       this.childNodes = this.childNodes.filter((item) => item !== child);
  #|       this.children = this.childNodes;
  #|       child.parentNode = null;
  #|       return child;
  #|     }
  #|     getBoundingClientRect() {
  #|       return {
  #|         x: 0, y: 0, left: 0, top: 0,
  #|         right: 100, bottom: 100, width: 100, height: 100,
  #|       };
  #|     }
  #|   }
  #|   globalThis.__hiddenAreasOriginalDocument = globalThis.document;
  #|   globalThis.__hiddenAreasOriginalElement = globalThis.Element;
  #|   const ownerDocument = new EventTarget();
  #|   ownerDocument.nodeType = 9;
  #|   ownerDocument.createElement = (tag) => new HiddenAreasTestElement(tag);
  #|   globalThis.document = ownerDocument;
  #|   globalThis.Element = HiddenAreasTestElement;
  #| }

///|
extern "js" fn restore_hidden_areas_test_browser() -> Unit =
  #| () => {
  #|   if (globalThis.__hiddenAreasOriginalDocument === undefined) {
  #|     delete globalThis.document;
  #|   } else {
  #|     globalThis.document = globalThis.__hiddenAreasOriginalDocument;
  #|   }
  #|   if (globalThis.__hiddenAreasOriginalElement === undefined) {
  #|     delete globalThis.Element;
  #|   } else {
  #|     globalThis.Element = globalThis.__hiddenAreasOriginalElement;
  #|   }
  #|   delete globalThis.__hiddenAreasOriginalDocument;
  #|   delete globalThis.__hiddenAreasOriginalElement;
  #| }

///|
test "hidden areas collect recovery scroll before mapping delivery" {
  install_hidden_areas_test_browser()
  defer restore_hidden_areas_test_browser()
  let viewer = Viewer::Viewer(
    options=ViewerOptions(font_size=12, line_height=18),
  )
  defer viewer.dispose()
  let model = test_model("one\ntwo\nthree\nfour\nfive\nsix\nseven\neight")
  viewer.set_model(Some(model))
  guard viewer.model_data is Some(headless) else {
    fail("headless model data missing")
  }
  let read_configuration = () => (18, 400.0, 0.0)
  let view = @view.View::new(view_zones_configuration_reader=read_configuration)
  view.install_view_zones_context(
    headless.view_model,
    viewer.services.log_service,
    read_configuration,
    () => {
      view.emit_view_zones_changed_then(() => {
        headless.view_model.emit_view_zones_changed()
      })
    },
  )
  viewer.model_data = Some({
    model: headless.model,
    view_model: headless.view_model,
    view: Some(view),
    attached_view: headless.attached_view,
    listeners_to_remove: headless.listeners_to_remove,
  })

  let layout = headless.view_model.view_layout
  layout.set_viewport_size(width=400.0, height=18.0) |> ignore
  let old_top = layout.get_vertical_offset_for_line_number(4) + 7.0
  layout.scroll_to(scroll_top=old_top) |> ignore
  view.view_zones.did_render()

  // The Viewer scroll listener was registered during model construction.
  // This later observer therefore sees whether that listener delivered the
  // recovery Scroll event immediately or merely appended it to the outer
  // hidden-area collector. Every observation must remain clean until the
  // projected-line mutation and its Mapping events have completed.
  let dirty_during_recovery : Array[Bool] = []
  let observer = layout.on_did_scroll(_change => {
    dirty_during_recovery.push(view.view_zones.should_render())
  })
  defer observer.dispose()

  viewer.set_hidden_areas([Range(2, 1, 3, 1)])
  assert_true(dirty_during_recovery.length() > 0)
  for dirty in dirty_during_recovery {
    assert_false(dirty)
  }
  assert_true(view.view_zones.should_render())
}
