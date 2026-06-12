///|
pub fn emit_event(name : String, payload : String) -> Unit {
  @dom.emit_event(name, payload)
}

///|
pub fn emit_render_event(
  frame : @renderer.RenderFrame,
  token_count : Int,
  diagnostic_count : Int,
  build_ms : Double,
) -> Unit {
  let mut payload = "{"
  payload = payload + "\"lineCount\":" + frame.line_count.to_string()
  payload = payload + ",\"tokenCount\":" + token_count.to_string()
  payload = payload + ",\"diagnosticCount\":"
  payload = payload + diagnostic_count.to_string()
  payload = payload + ",\"version\":" + frame.version.to_string()
  payload = payload + ",\"buildMs\":" + build_ms.to_string()
  payload = payload + "}"
  emit_event("moonbit:render", payload)
}
