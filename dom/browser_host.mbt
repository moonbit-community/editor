///|
pub extern "js" fn get_source() -> String =
  #| () => {
  #|   const document = globalThis.__readonlyEditorDocument;
  #|   return document && typeof document.text === "string"
  #|     ? document.text
  #|     : globalThis.__readonlyEditorSource || "";
  #| }

///|
pub extern "js" fn get_uri() -> String =
  #| () => {
  #|   const document = globalThis.__readonlyEditorDocument;
  #|   return document && typeof document.uri === "string" ? document.uri : "";
  #| }

///|
pub extern "js" fn get_display_name() -> String =
  #| () => {
  #|   const document = globalThis.__readonlyEditorDocument;
  #|   return document && typeof document.displayName === "string"
  #|     ? document.displayName
  #|     : "";
  #| }

///|
pub extern "js" fn get_language_id_hint() -> String =
  #| () => {
  #|   const document = globalThis.__readonlyEditorDocument;
  #|   return document && typeof document.languageId === "string"
  #|     ? document.languageId
  #|     : "";
  #| }

///|
pub extern "js" fn get_version() -> Int =
  #| () => {
  #|   const document = globalThis.__readonlyEditorDocument;
  #|   const version = document && Number.isFinite(document.version)
  #|     ? document.version
  #|     : 0;
  #|   return Math.trunc(version);
  #| }

///|
pub extern "js" fn get_revision() -> String =
  #| () => {
  #|   const document = globalThis.__readonlyEditorDocument;
  #|   return document && typeof document.revision === "string"
  #|     ? document.revision
  #|     : "";
  #| }

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

///|
pub extern "js" fn register_render_callback(callback : () -> Unit) -> Unit =
  #| (callback) => {
  #|   globalThis.__readonlyEditorRender = callback;
  #| }
