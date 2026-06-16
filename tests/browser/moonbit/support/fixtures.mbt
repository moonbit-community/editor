///|
pub extern "js" fn query_text(selector : String) -> String =
  #| (selector) => document.querySelector(selector)?.textContent ?? ""

///|
pub extern "js" fn query_count(selector : String) -> Int =
  #| (selector) => document.querySelectorAll(selector).length

///|
pub extern "js" fn query_attribute(selector : String, name : String) -> String =
  #| (selector, name) => document.querySelector(selector)?.getAttribute(name) ?? ""

///|
pub extern "js" fn set_timeout(callback : () -> Unit, ms : Int) -> Unit =
  #| (callback, ms) => {
  #|   globalThis.setTimeout(callback, Number(ms) || 0);
  #| }

///|
pub extern "js" fn now_ms() -> Double =
  #| () => globalThis.performance?.now() ?? Date.now()
