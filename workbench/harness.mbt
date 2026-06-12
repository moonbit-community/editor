///|
/// Harness observability: the workbench formats viewer lifecycle facts and
/// protocol errors into the structured events the browser harness reads.
pub fn emit_event(name : String, payload : String) -> Unit {
  @dom.emit_event(name, payload)
}

///|
fn emit_render_event(
  line_count : Int,
  token_count : Int,
  diagnostic_count : Int,
  version : Int,
  tokenize_ms : Double,
  build_ms : Double,
) -> Unit {
  let mut payload = "{"
  payload = payload + "\"lineCount\":" + line_count.to_string()
  payload = payload + ",\"tokenCount\":" + token_count.to_string()
  payload = payload + ",\"diagnosticCount\":"
  payload = payload + diagnostic_count.to_string()
  payload = payload + ",\"version\":" + version.to_string()
  payload = payload + ",\"tokenizeMs\":" + tokenize_ms.to_string()
  payload = payload + ",\"buildMs\":" + build_ms.to_string()
  payload = payload + "}"
  emit_event("moonbit:render", payload)
}

///|
fn emit_language_status(diagnostic_count : Int, version : Int) -> Unit {
  emit_event(
    "language:diagnostics",
    "{\"count\":" +
    diagnostic_count.to_string() +
    ",\"version\":" +
    version.to_string() +
    "}",
  )
}

///|
/// The settled synthetic scroll position after a paint, the browser
/// harness's `view:scroll` signal.
fn emit_scroll_event(scroll_top : Double, scroll_left : Double) -> Unit {
  emit_event(
    "view:scroll",
    "{\"scrollTop\":" +
    scroll_top.to_string() +
    ",\"scrollLeft\":" +
    scroll_left.to_string() +
    "}",
  )
}

///|
fn emit_hover_status(ok : Bool, version : Int) -> Unit {
  emit_event(
    "language:hover",
    "{\"ok\":" + ok.to_string() + ",\"version\":" + version.to_string() + "}",
  )
}

///|
fn emit_dom_mounted(
  rendered_lines : Int,
  diagnostics : Int,
  status : String,
  patch_ms~ : Double?,
) -> Unit {
  let mut payload = "{"
  payload = payload + "\"renderedLines\":" + rendered_lines.to_string()
  payload = payload + ",\"diagnostics\":" + diagnostics.to_string()
  payload = payload + ",\"status\":" + json_string(status)
  match patch_ms {
    Some(patch_ms) => payload = payload + ",\"patchMs\":" + patch_ms.to_string()
    None => ()
  }
  payload = payload + "}"
  emit_event("dom:mounted", payload)
}

///|
/// Status-only mount event for states the shell reaches without a frame
/// paint (error, stale, missing); emitted after the status rendered.
fn dom_mounted_status_cmd(status : String) -> @rabbita.Cmd {
  @cmd.custom_cmd(
    _ => emit_dom_mounted(0, 0, status, patch_ms=None),
    kind=@cmd.after_render,
  )
}

///|
fn json_string(value : String) -> String {
  value.escape(quote=true)
}
