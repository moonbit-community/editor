///|
pub extern "js" fn get_source() -> String =
  #| () => globalThis.__readonlyEditorSource || ""

///|
pub extern "js" fn emit_event(name : String, payload : String) -> Unit =
  #| (name, payload) => {
  #|   if (typeof globalThis.__readonlyEditorEvent === "function") {
  #|     globalThis.__readonlyEditorEvent(name, payload);
  #|   }
  #| }

///|
pub extern "js" fn mount_render_model(payload : String) -> Unit =
  #| (payload) => {
  #|   if (typeof globalThis.__readonlyEditorMount === "function") {
  #|     globalThis.__readonlyEditorMount(payload);
  #|   }
  #| }
