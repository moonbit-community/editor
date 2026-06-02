///|
extern "js" fn get_source() -> String =
  #| () => globalThis.__readonlyEditorSource || ""

///|
extern "js" fn emit_event(name : String, payload : String) -> Unit =
  #| (name, payload) => {
  #|   if (typeof globalThis.__readonlyEditorEvent === "function") {
  #|     globalThis.__readonlyEditorEvent(name, payload);
  #|   }
  #| }

///|
extern "js" fn mount_render_model(payload : String) -> Unit =
  #| (payload) => {
  #|   if (typeof globalThis.__readonlyEditorMount === "function") {
  #|     globalThis.__readonlyEditorMount(payload);
  #|   }
  #| }

///|
fn main {
  let source = get_source()
  let doc = @core.DocumentSnapshot::new(source, language_id="moonbit")
  let tokens = @syntax.highlight(doc)
  let providers = @language.demo_providers(doc)
  let decorations = decorations_from_diagnostics(providers.diagnostics)
  let model = @view.render(
    doc,
    { start_line: 0, end_line: doc.line_count() },
    tokens,
    decorations,
    providers,
  )
  let mut event_payload = "{"
  event_payload = event_payload +
    "\"lineCount\":" +
    doc.line_count().to_string()
  event_payload = event_payload +
    ",\"tokenCount\":" +
    tokens.length().to_string()
  event_payload = event_payload + ",\"diagnosticCount\":"
  event_payload = event_payload + providers.diagnostics.length().to_string()
  event_payload = event_payload + "}"
  emit_event("moonbit:render", event_payload)
  mount_render_model(model.to_json())
}

///|
fn decorations_from_diagnostics(
  diagnostics : Array[@language.Diagnostic],
) -> @decorations.DecorationSet {
  let items = []
  for diagnostic in diagnostics {
    items.push(
      @decorations.Decoration::new(
        diagnostic.range,
        Diagnostic,
        "diag-warning",
        message=diagnostic.message,
      ),
    )
  }
  @decorations.DecorationSet::from_array(items)
}
