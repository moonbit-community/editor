///|
/// Reads the element's unscaled layout width. This intentionally remains
/// distinct from `get_bounding_client_rect`, whose dimensions include CSS
/// transforms.
pub extern "js" fn element_offset_width(element : @rdom.Element) -> Double =
  #| (element) => element?.offsetWidth ?? 0

///|
/// Reads the element's unscaled layout height.
pub extern "js" fn element_offset_height(element : @rdom.Element) -> Double =
  #| (element) => element?.offsetHeight ?? 0

///|
/// Writes one inline CSS property without replacing sibling properties.
pub extern "js" fn set_style_property(
  element : @rdom.Element,
  name : String,
  value : String,
) -> Unit =
  #| (element, name, value) => { element.style.setProperty(name, value); }

///|
/// Removes an element if attached. `HTMLElement.remove()` is idempotent; the
/// parent-node fallback preserves that behavior for narrow test DOMs.
pub extern "js" fn remove_element(element : @rdom.Element) -> Unit =
  #| (element) => {
  #|   if (typeof element?.remove === "function") element.remove();
  #|   else element?.parentNode?.removeChild(element);
  #| }

///|
/// Focuses an element without allowing the browser to scroll it into view.
pub extern "js" fn focus_prevent_scroll(element : @rdom.Element) -> Unit =
  #| (element) => element?.focus?.({ preventScroll: true })

///|
/// Whether `child` is the container itself or one of its descendants.
pub extern "js" fn element_contains(
  container : @rdom.Element,
  child : @rdom.Element,
) -> Bool =
  #| (container, child) => Boolean(container?.contains?.(child))

///|
/// Whether the element's owner document currently focuses the element.
pub extern "js" fn element_has_focus(element : @rdom.Element) -> Bool =
  #| (element) => Boolean(element?.ownerDocument?.activeElement === element)

///|
/// Whether the active element from this element's owner document is contained
/// by the element. Using the owner document preserves iframe/document seams.
pub extern "js" fn element_contains_active_element(
  element : @rdom.Element,
) -> Bool =
  #| (element) => {
  #|   const active = element?.ownerDocument?.activeElement;
  #|   return Boolean(active && element.contains(active));
  #| }
