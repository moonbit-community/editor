///|
pub fn emit_event(name : String, payload : String) -> Unit {
  @dom.emit_event(name, payload)
}

///|
pub fn emit_render_event(
  frame : @renderer.RenderFrame,
  token_count : Int,
  diagnostic_count : Int,
) -> Unit {
  let mut payload = "{"
  payload = payload + "\"lineCount\":" + frame.line_count.to_string()
  payload = payload + ",\"tokenCount\":" + token_count.to_string()
  payload = payload + ",\"diagnosticCount\":"
  payload = payload + diagnostic_count.to_string()
  payload = payload + ",\"version\":" + frame.version.to_string()
  payload = payload + "}"
  emit_event("moonbit:render", payload)
}

///|
fn request_id(prefix : String, uri : @workspace.DocumentUri) -> String {
  prefix + ":" + uri.to_string()
}
