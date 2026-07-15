///|
#external
type DomPrimitiveFixture

///|
extern "js" fn new_dom_primitive_fixture() -> DomPrimitiveFixture =
  #| () => {
  #|   const child = {};
  #|   const style = new Map();
  #|   const ownerDocument = { activeElement: child };
  #|   const element = {
  #|     offsetWidth: 37,
  #|     offsetHeight: 19,
  #|     ownerDocument,
  #|     style: { setProperty: (name, value) => style.set(name, value) },
  #|     contains: candidate => candidate === element || candidate === child,
  #|     focus: options => { element.focusOptions = options; },
  #|     remove: () => { element.removed = true; },
  #|   };
  #|   return { element, child, ownerDocument, style };
  #| }

///|
extern "js" fn dom_primitive_fixture_element(
  fixture : DomPrimitiveFixture,
) -> @rdom.Element = "(fixture) => fixture.element"

///|
extern "js" fn dom_primitive_fixture_child(
  fixture : DomPrimitiveFixture,
) -> @rdom.Element = "(fixture) => fixture.child"

///|
extern "js" fn dom_primitive_fixture_style(
  fixture : DomPrimitiveFixture,
  name : String,
) -> String = "(fixture, name) => fixture.style.get(name) ?? ''"

///|
extern "js" fn dom_primitive_fixture_prevented_scroll(
  fixture : DomPrimitiveFixture,
) -> Bool = "(fixture) => fixture.element.focusOptions?.preventScroll === true"

///|
extern "js" fn dom_primitive_fixture_removed(
  fixture : DomPrimitiveFixture,
) -> Bool = "(fixture) => fixture.element.removed === true"

///|
extern "js" fn dom_primitive_fixture_focus_element(
  fixture : DomPrimitiveFixture,
) -> Unit = "(fixture) => { fixture.ownerDocument.activeElement = fixture.element; }"

///|
test "canonical DOM primitives preserve layout style lifecycle and focus semantics" {
  let fixture = new_dom_primitive_fixture()
  let element = dom_primitive_fixture_element(fixture)
  let child = dom_primitive_fixture_child(fixture)
  assert_eq(element_offset_width(element), 37.0)
  assert_eq(element_offset_height(element), 19.0)
  set_style_property(element, "width", "12px")
  assert_eq(dom_primitive_fixture_style(fixture, "width"), "12px")
  assert_true(element_contains(element, child))
  assert_true(element_contains_active_element(element))
  assert_false(element_has_focus(element))
  focus_prevent_scroll(element)
  assert_true(dom_primitive_fixture_prevented_scroll(fixture))
  dom_primitive_fixture_focus_element(fixture)
  assert_true(element_has_focus(element))
  remove_element(element)
  remove_element(element)
  assert_true(dom_primitive_fixture_removed(fixture))
}
