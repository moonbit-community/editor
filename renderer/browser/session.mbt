///|
priv struct RenderedDocument {
  frame : @renderer.RenderFrame
  document : @workspace.SourceDocument
}

///|
priv enum DocumentRenderResult {
  DocumentRendered(RenderedDocument)
  DocumentRenderFailed(String, String, String)
}

///|
priv struct HoverResolution {
  ok : Bool
  version : Int
  start : Int
  end : Int
  contents : String
}

///|
priv struct DefinitionResolution {
  ok : Bool
  version : Int
  uri : String
  start : Int
  end : Int
}

///|
let active_language_provider : BrowserRemoteLanguageProvider = browser_remote_language_provider()

///|
let active_watch : Ref[@workspace.FileWatch?] = Ref(None)

///|
pub fn start_app() -> Unit {
  @dom.install_host_capabilities()
  mount_app()
}

///|
fn default_document_cmd() -> @rabbita.Cmd {
  @cmd.custom_cmd(_ => {
    ignore(
      @js_async.Promise::from_async(async fn() {
        let result = render_document(demo_source_document(), None) catch {
          error => DocumentRenderFailed("", "error", error.to_string())
        }
        dispatch_browser_msg(DocumentRenderResolved(result, false))
      }),
    )
  })
}

///|
fn load_workspace_document_cmd(
  emit : @rabbita.Emit[BrowserMsg],
  id : String,
  previous : @workspace.SourceDocument?,
) -> @rabbita.Cmd {
  match workspace_document_uri(id) {
    Some(uri) => load_document_uri_cmd(uri, previous, true)
    None =>
      emit(
        DocumentRenderResolved(
          DocumentRenderFailed("", "error", "Invalid workspace file selection."),
          false,
        ),
      )
  }
}

///|
fn load_document_uri_cmd(
  uri : @workspace.DocumentUri,
  previous : @workspace.SourceDocument?,
  watch : Bool,
) -> @rabbita.Cmd {
  @cmd.custom_cmd(_ => {
    ignore(
      @js_async.Promise::from_async(async fn() {
        let result = load_and_render_document(uri, previous) catch {
          error =>
            DocumentRenderFailed(uri.to_string(), "error", error.to_string())
        }
        dispatch_browser_msg(DocumentRenderResolved(result, watch))
      }),
    )
  })
}

///|
fn watch_document_cmd(
  emit : @rabbita.Emit[BrowserMsg],
  document : @workspace.SourceDocument,
) -> @rabbita.Cmd {
  @cmd.custom_cmd(scheduler => {
    replace_active_watch(None)
    let uri = document.uri
    let watch = @workspace.watch_file(provider_for_uri(uri), uri, changes => {
      scheduler.add(
        emit(
          DocumentWatchChanged(uri.to_string(), changes_include_delete(changes)),
        ),
      )
    })
    replace_active_watch(Some(watch))
  })
}

///|
fn stop_document_watch_cmd() -> @rabbita.Cmd {
  @cmd.custom_cmd(_ => replace_active_watch(None))
}

///|
fn hover_resolution_cmd(
  emit : @rabbita.Emit[BrowserMsg],
  document : @workspace.SourceDocument?,
  start : Int,
  end : Int,
  offset : Int,
  version : Int,
) -> @rabbita.Cmd {
  match document {
    Some(source_document) =>
      @cmd.custom_cmd(_ => {
        ignore(
          @js_async.Promise::from_async(async fn() {
            let result = resolve_hover(source_document, offset, version) catch {
              _ => { ok: false, version, start: 0, end: 0, contents: "" }
            }
            dispatch_browser_msg(HoverResolved(start, end, result))
          }),
        )
      })
    None =>
      emit(
        HoverResolved(start, end, {
          ok: false,
          version,
          start: 0,
          end: 0,
          contents: "",
        }),
      )
  }
}

///|
fn definition_resolution_cmd(
  emit : @rabbita.Emit[BrowserMsg],
  document : @workspace.SourceDocument?,
  offset : Int,
  version : Int,
) -> @rabbita.Cmd {
  match document {
    Some(source_document) =>
      @cmd.custom_cmd(_ => {
        ignore(
          @js_async.Promise::from_async(async fn() {
            let result = resolve_definition(source_document, offset, version) catch {
              _ => { ok: false, version, uri: "", start: 0, end: 0 }
            }
            dispatch_browser_msg(DefinitionResolved(result))
          }),
        )
      })
    None =>
      emit(
        DefinitionResolved({ ok: false, version, uri: "", start: 0, end: 0 }),
      )
  }
}

///|
async fn load_and_render_document(
  uri : @workspace.DocumentUri,
  previous : @workspace.SourceDocument?,
) -> DocumentRenderResult {
  match @workspace.read_source_document(provider_for_uri(uri), uri) {
    SourceDocumentLoaded(document) => render_document(document, previous)
    SourceDocumentLoadError(error) =>
      DocumentRenderFailed(
        uri.to_string(),
        status_from_error(error),
        error.message,
      )
  }
}

///|
async fn render_document(
  loaded_document : @workspace.SourceDocument,
  previous : @workspace.SourceDocument?,
) -> DocumentRenderResult {
  let source_document = document_with_session_version(loaded_document, previous)
  @dom.set_current_document(source_document.to_json())
  let doc = source_document.snapshot()
  let tokens = @syntax.highlight(doc)
  let provider = language_provider()
  let diagnostics_provider = provider.as_diagnostics_provider()
  let symbols_provider = provider.as_document_symbol_provider()
  let semantic_tokens_provider = provider.as_semantic_tokens_provider()
  let providers : @language.ProviderResult = {
    hovers: [],
    diagnostics: diagnostics_provider.diagnostics_for_document(source_document),
    definitions: [],
    symbols: symbols_provider.document_symbols(source_document),
    semantic_tokens: semantic_tokens_provider.semantic_tokens_for_document(
      source_document,
    ),
  }
  emit_language_status(provider, providers.diagnostics.length(), doc.version)
  let decorations = decorations_from_diagnostics(providers.diagnostics)
  let frame = @renderer.build_frame(
    doc,
    { start_line: 0, end_line: doc.line_count() },
    tokens,
    decorations,
    providers,
  )
  emit_render_event(frame, tokens.length(), providers.diagnostics.length())
  DocumentRendered({ frame, document: source_document })
}

///|
async fn resolve_hover(
  source_document : @workspace.SourceDocument,
  offset : Int,
  expected_version : Int,
) -> HoverResolution {
  if source_document.version != expected_version {
    return {
      ok: false,
      version: source_document.version,
      start: 0,
      end: 0,
      contents: "",
    }
  }
  let provider = language_provider()
  let hover_provider = provider.as_hover_provider()
  match hover_provider.hover_at(source_document, offset) {
    Some(hover) => {
      emit_event(
        "language:hover",
        "{\"ok\":true,\"version\":" + source_document.version.to_string() + "}",
      )
      {
        ok: true,
        version: source_document.version,
        start: hover.range.start,
        end: hover.range.end,
        contents: hover.contents,
      }
    }
    None => {
      emit_provider_error(provider)
      {
        ok: false,
        version: source_document.version,
        start: 0,
        end: 0,
        contents: "",
      }
    }
  }
}

///|
async fn resolve_definition(
  source_document : @workspace.SourceDocument,
  offset : Int,
  expected_version : Int,
) -> DefinitionResolution {
  if source_document.version != expected_version {
    return {
      ok: false,
      version: source_document.version,
      uri: "",
      start: 0,
      end: 0,
    }
  }
  let provider = language_provider()
  let definition_provider = provider.as_definition_provider()
  match definition_provider.definition_at(source_document, offset) {
    Some(location) => {
      emit_event(
        "language:definition",
        "{\"ok\":true,\"version\":" + source_document.version.to_string() + "}",
      )
      {
        ok: true,
        version: source_document.version,
        uri: location.uri.to_string(),
        start: location.range.start,
        end: location.range.end,
      }
    }
    None => {
      emit_provider_error(provider)
      { ok: false, version: source_document.version, uri: "", start: 0, end: 0 }
    }
  }
}

///|
fn provider_for_uri(
  uri : @workspace.DocumentUri,
) -> &@workspace.FileSystemProvider {
  if uri.scheme() == "readonly-remote" {
    browser_remote_file_system_provider()
  } else {
    browser_file_system_provider()
  }
}

///|
fn workspace_document_uri(id : String) -> @workspace.DocumentUri? {
  match @workspace.SourcePath::normalize_root_relative_path(id) {
    ParsedSourcePath(path) =>
      match
        @workspace.DocumentUri::parse(
          "readonly-remote://workspace/" + path.to_string(),
        ) {
        ParsedDocumentUri(uri) => Some(uri)
        DocumentUriError(_) => None
      }
    SourcePathError(_) => None
  }
}

///|
fn demo_source_document() -> @workspace.SourceDocument {
  SourceDocument(
    @workspace.DocumentUri::memory("demo.mbt"),
    "Demo",
    "moonbit",
    1,
    "demo",
    "pub fn main {\n  let greeting = \"hello\"\n  // TODO: replace demo provider with server-backed provider\n  println(greeting)\n}\n",
  )
}

///|
fn document_with_session_version(
  document : @workspace.SourceDocument,
  previous : @workspace.SourceDocument?,
) -> @workspace.SourceDocument {
  let version = match previous {
    Some(item) =>
      if item.uri.to_string() == document.uri.to_string() {
        if item.revision == document.revision {
          item.version
        } else {
          item.version + 1
        }
      } else {
        document.version
      }
    None => document.version
  }
  SourceDocument(
    document.uri,
    document.display_name,
    document.language_id,
    version,
    document.revision,
    document.text,
  )
}

///|
fn language_provider() -> BrowserRemoteLanguageProvider {
  active_language_provider
}

///|
fn emit_language_status(
  provider : BrowserRemoteLanguageProvider,
  diagnostic_count : Int,
  version : Int,
) -> Unit {
  emit_provider_error(provider)
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
fn emit_provider_error(provider : BrowserRemoteLanguageProvider) -> Unit {
  let error = provider.last_error_message()
  if error != "" {
    emit_event("language:error", "{\"message\":" + json_string(error) + "}")
    provider.clear_last_error()
  }
}

///|
fn decorations_from_diagnostics(
  diagnostics : Array[@language.Diagnostic],
) -> @decorations.DecorationSet {
  let items = []
  for diagnostic in diagnostics {
    items.push(
      @decorations.Decoration(
        diagnostic.range,
        Diagnostic,
        "diag-warning",
        message=diagnostic.message,
      ),
    )
  }
  @decorations.DecorationSet::from_array(items)
}

///|
fn changes_include_delete(changes : Array[@workspace.FileChange]) -> Bool {
  for change in changes {
    if change.change_type == Deleted {
      return true
    }
  }
  false
}

///|
fn replace_active_watch(next : @workspace.FileWatch?) -> Unit {
  match active_watch.val {
    Some(watch) => watch.dispose()
    None => ()
  }
  active_watch.val = next
}

///|
fn status_from_error(error : @workspace.FileSystemProviderError) -> String {
  match error.code {
    FileNotFound => "missing"
    _ => "error"
  }
}
