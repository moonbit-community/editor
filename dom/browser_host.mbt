///|
pub extern "js" fn install_host_capabilities() -> Unit =
  #| () => {
  #|   if (typeof globalThis.__readonlyEditorEvent !== "function") {
  #|     globalThis.__readonlyEditorEvent = (name, payload) => {
  #|       // Log the raw JSON string: console object previews truncate
  #|       // after a handful of properties, which silently drops payload
  #|       // keys from harness transcripts.
  #|       console.info("[readonly-editor]", name, payload);
  #|     };
  #|   }
  #| }

///|
pub extern "js" fn set_current_document(payload : String) -> Unit =
  #| (payload) => {
  #|   try {
  #|     const document = JSON.parse(payload);
  #|     globalThis.__readonlyEditorDocument = document;
  #|     globalThis.__readonlyEditorSource = typeof document.text === "string" ? document.text : "";
  #|   } catch (error) {
  #|     console.error("[readonly-editor]", "document:state-error", error);
  #|   }
  #| }

///|
pub extern "js" fn protocol_websocket_url() -> String =
  #| () => {
  #|   const location = globalThis.location;
  #|   const protocol = location?.protocol === "https:" ? "wss:" : "ws:";
  #|   const host = location?.host || "127.0.0.1:5173";
  #|   return `${protocol}//${host}/protocol`;
  #| }

///|
/// Monotonic high-resolution timestamp in milliseconds, for render timing
/// instrumentation.
pub extern "js" fn now_ms() -> Double =
  #| () => globalThis.performance?.now() ?? Date.now()

///|
pub extern "js" fn emit_event(name : String, payload : String) -> Unit =
  #| (name, payload) => {
  #|   if (typeof globalThis.__readonlyEditorEvent === "function") {
  #|     globalThis.__readonlyEditorEvent(name, payload);
  #|   }
  #| }

///|
pub extern "js" fn storage_get_item(key : String) -> String =
  #| (key) => {
  #|   try {
  #|     return globalThis.localStorage?.getItem(key) ?? "";
  #|   } catch {
  #|     return "";
  #|   }
  #| }

///|
pub extern "js" fn storage_set_item(key : String, value : String) -> Unit =
  #| (key, value) => {
  #|   try {
  #|     globalThis.localStorage?.setItem(key, value);
  #|   } catch {
  #|     // Persistence is best-effort; private browsing may deny storage.
  #|   }
  #| }
