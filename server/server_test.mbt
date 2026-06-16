///|
test "validates readonly remote workspace uris" {
  let uri = expect_uri(
    "readonly-remote://workspace/docs/fixtures/project/src/main.mbt",
  )
  match @server.resolve_remote_document_uri(uri) {
    ParsedRemotePath(path) =>
      assert_eq(path.to_string(), "docs/fixtures/project/src/main.mbt")
    RemotePathError(error) => fail(error.message)
  }

  let absolute = expect_uri("readonly-remote://workspace//tmp/main.mbt")
  match @server.resolve_remote_document_uri(absolute) {
    RemotePathError(error) => assert_true(error.code == ProtocolInvalidUri)
    ParsedRemotePath(path) => fail("unexpected path " + path.to_string())
  }

  let wrong_scheme = expect_uri(
    "file://local/docs/fixtures/project/src/main.mbt",
  )
  match @server.resolve_remote_document_uri(wrong_scheme) {
    RemotePathError(error) => assert_true(error.code == ProtocolInvalidUri)
    ParsedRemotePath(path) => fail("unexpected path " + path.to_string())
  }
}

///|
async test "resolves one directory level through the host" {
  let host = FakeServerHost::new()
  host.directories.set("", [
    {
      uri: expect_remote_uri("moon.mod"),
      name: "moon.mod",
      kind: File,
      children: None,
    },
    {
      uri: expect_remote_uri("src"),
      name: "src",
      kind: Directory,
      children: None,
    },
  ])
  host.directories.set("src", [
    {
      uri: expect_remote_uri("src/main.mbt"),
      name: "main.mbt",
      kind: File,
      children: None,
    },
  ])
  let server = test_remote_server("/workspace", host)

  let root_uri = expect_uri("readonly-remote://workspace")
  match server.resolve_directory({ id: "resolve-1", uri: root_uri }) {
    DirectoryResolved(payload) => {
      assert_eq(payload.id, "resolve-1")
      assert_eq(payload.stat.uri.to_string(), "readonly-remote://workspace")
      assert_eq(payload.stat.name, "workspace")
      assert_true(payload.stat.kind == Directory)
      match payload.stat.children {
        Some(children) => {
          assert_eq(children.length(), 2)
          assert_eq(children[1].name, "src")
          assert_true(children[1].children is None)
        }
        None => fail("expected resolved root children")
      }
    }
    _ => fail("expected directory resolved")
  }

  match
    server.resolve_directory({ id: "resolve-2", uri: expect_remote_uri("src") }) {
    DirectoryResolved(payload) => {
      assert_eq(payload.stat.name, "src")
      match payload.stat.children {
        Some(children) => assert_eq(children[0].name, "main.mbt")
        None => fail("expected resolved src children")
      }
    }
    _ => fail("expected directory resolved")
  }

  match
    server.resolve_directory({
      id: "resolve-3",
      uri: expect_remote_uri("missing"),
    }) {
    RemoteError(error) => {
      assert_eq(error.provider_code, "FileNotFound")
      assert_eq(error.request_id, "resolve-3")
    }
    _ => fail("expected provider error")
  }
}

///|
async test "maps host read errors to protocol provider errors" {
  let host = FakeServerHost::new()
  host.errors.set("missing.mbt", (FileNotFound, "missing file"))
  let server = test_remote_server("/workspace", host)
  let uri = expect_remote_uri("missing.mbt")

  match server.open_document({ id: "open-1", uri }) {
    RemoteError(error) => {
      assert_true(error.code == ProtocolProviderError)
      assert_eq(error.provider_code, "FileNotFound")
      assert_eq(error.request_id, "open-1")
    }
    _ => fail("expected provider error")
  }
}

///|
async test "routes watch events to document changed packets" {
  let host = FakeServerHost::new()
  host.files.set("main.mbt", "pub fn main {}\n")
  let server = test_remote_server("/workspace/", host)
  let uri = expect_remote_uri("main.mbt")
  let emitted = []

  match
    server.watch_document(
      { id: "watch-1", uri },
      packet => emitted.push(packet),
      noop_watch_spawner,
    ) {
    DocumentLoaded(payload) =>
      assert_eq(payload.document.text, "pub fn main {}\n")
    _ => fail("expected initial document load")
  }

  host.files.set("main.mbt", "pub fn main { 1 }\n")
  host.emit("main.mbt", Changed)
  assert_eq(emitted.length(), 1)
  match emitted[0] {
    DocumentChanged(payload) =>
      assert_eq(payload.document.text, "pub fn main { 1 }\n")
    _ => fail("expected document changed")
  }

  host.emit("main.mbt", Deleted)
  match emitted[1] {
    RemoteError(error) => assert_eq(error.provider_code, "FileNotFound")
    _ => fail("expected deletion error")
  }
}

///|
async test "answers hover and definition from cached provider state" {
  let host = FakeServerHost::new()
  host.files.set("main.mbt", "pub fn main {}\n")
  let server = test_remote_server("/workspace", host)
  let uri = expect_remote_uri("main.mbt")
  ignore(server.open_document({ id: "open-1", uri }))

  match server.hover({ id: "hover-1", uri, document_version: 1, offset: 7 }) {
    HoverResult(payload) =>
      match payload.hover {
        Some(hover) => assert_plaintext_hover(hover, "Configured hover")
        None => fail("expected hover")
      }
    _ => fail("expected hover result")
  }

  match
    server.definition({ id: "def-1", uri, document_version: 1, offset: 7 }) {
    DefinitionResult(payload) =>
      match payload.location {
        Some(location) => assert_eq(location.uri.to_string(), uri.to_string())
        None => fail("expected definition")
      }
    _ => fail("expected definition result")
  }

  match
    server.references({ id: "refs-1", uri, document_version: 1, offset: 7 }) {
    ReferencesResult(payload) => {
      assert_eq(payload.id, "refs-1")
      assert_eq(payload.references.length(), 2)
      // Offset 7 of "pub fn main {}\n" sits on line 1, column 8.
      assert_eq(payload.references[0].uri.to_string(), uri.to_string())
      assert_eq(payload.references[0].line, 1)
      assert_eq(payload.references[0].column, 8)
      assert_eq(payload.references[0].line_text, "pub fn main {}")
      assert_eq(payload.references[1].line, 1)
      assert_eq(payload.references[1].column, 1)
    }
    _ => fail("expected references result")
  }
}

///|
async test "answers diagnostics symbols semantic tokens and folding ranges from cached provider state" {
  let host = FakeServerHost::new()
  host.files.set("main.mbt", "pub fn main { // TODO }\n")
  let server = test_remote_server("/workspace", host)
  let uri = expect_remote_uri("main.mbt")
  ignore(server.open_document({ id: "open-1", uri }))

  match server.diagnostics({ id: "diag-1", uri, document_version: 1 }) {
    Diagnostics(payload) => {
      assert_eq(payload.id, "diag-1")
      assert_eq(payload.diagnostics.length(), 1)
    }
    _ => fail("expected diagnostics result")
  }

  match server.document_symbols({ id: "symbols-1", uri, document_version: 1 }) {
    DocumentSymbolsResult(payload) => {
      assert_eq(payload.symbols.length(), 1)
      assert_eq(payload.symbols[0].name, "configured")
    }
    _ => fail("expected document symbols result")
  }

  match server.semantic_tokens({ id: "tokens-1", uri, document_version: 1 }) {
    SemanticTokensResult(payload) => {
      assert_eq(payload.semantic_tokens.length(), 1)
      assert_eq(payload.semantic_tokens[0].token_type, "function")
    }
    _ => fail("expected semantic tokens result")
  }

  match server.folding_ranges({ id: "fold-1", uri, document_version: 1 }) {
    FoldingRangesResult(payload) => {
      assert_eq(payload.folding_ranges.length(), 1)
      assert_eq(payload.folding_ranges[0].start_line_number, 1)
      assert_eq(payload.folding_ranges[0].end_line_number, 3)
    }
    _ => fail("expected folding ranges result")
  }
}

///|
async test "dispatches language requests through configured providers" {
  let host = FakeServerHost::new()
  host.files.set("configured.mbt", "pub fn configured {}\n")
  let server = test_remote_server("/workspace", host)
  let uri = expect_remote_uri("configured.mbt")
  ignore(server.open_document({ id: "open-1", uri }))

  match server.hover({ id: "hover-1", uri, document_version: 1, offset: 7 }) {
    HoverResult(payload) =>
      match payload.hover {
        Some(hover) => assert_plaintext_hover(hover, "Configured hover")
        None => fail("expected configured hover")
      }
    _ => fail("expected hover result")
  }

  match
    server.definition({ id: "def-1", uri, document_version: 1, offset: 7 }) {
    DefinitionResult(payload) =>
      match payload.location {
        Some(location) => assert_eq(location.uri.to_string(), uri.to_string())
        None => fail("expected configured definition")
      }
    _ => fail("expected definition result")
  }

  match server.diagnostics({ id: "diag-1", uri, document_version: 1 }) {
    Diagnostics(payload) =>
      assert_eq(payload.diagnostics[0].message, "Configured diagnostic")
    _ => fail("expected diagnostics result")
  }

  match server.document_symbols({ id: "symbols-1", uri, document_version: 1 }) {
    DocumentSymbolsResult(payload) =>
      assert_eq(payload.symbols[0].name, "configured")
    _ => fail("expected document symbols result")
  }

  match server.semantic_tokens({ id: "tokens-1", uri, document_version: 1 }) {
    SemanticTokensResult(payload) =>
      assert_eq(payload.semantic_tokens[0].token_type, "function")
    _ => fail("expected semantic tokens result")
  }

  match server.folding_ranges({ id: "fold-1", uri, document_version: 1 }) {
    FoldingRangesResult(payload) =>
      assert_eq(payload.folding_ranges[0].start_line_number, 1)
    _ => fail("expected folding ranges result")
  }
}

///|
fn expect_remote_uri(path : String) -> @workspace.DocumentUri raise {
  match @server.remote_document_uri(path) {
    Some(uri) => uri
    None => fail("invalid remote path " + path)
  }
}

///|
fn expect_uri(raw : String) -> @workspace.DocumentUri raise {
  match @workspace.DocumentUri::parse(raw) {
    ParsedDocumentUri(uri) => uri
    DocumentUriError(error) => fail("unexpected URI error " + error.to_string())
  }
}

///|
fn test_remote_server(
  root : String,
  host : &@server.ServerHost,
) -> @server.RemoteServer {
  let provider = FakeLanguageProvider::{  }
  @server.RemoteServer::with_language_providers(
    root, host, provider, provider, provider, provider, provider, provider, provider,
  )
}

///|
struct FakeServerHost {
  files : Map[String, String]
  errors : Map[String, (@workspace.FileSystemProviderErrorCode, String)]
  directories : Map[String, Array[@workspace.WorkspaceStat]]
  listeners : Map[String, async (@workspace.FileChangeType) -> Unit]
}

///|
fn FakeServerHost::new() -> FakeServerHost {
  {
    files: Map::default(),
    errors: Map::default(),
    directories: Map::default(),
    listeners: Map::default(),
  }
}

///|
async fn FakeServerHost::emit(
  self : FakeServerHost,
  path : String,
  change_type : @workspace.FileChangeType,
) -> Unit {
  match self.listeners.get(path) {
    Some(listener) => listener(change_type)
    None => ()
  }
}

///|
impl @server.ServerHost for FakeServerHost with fn read_directory(
  self,
  _root,
  relative,
) {
  match self.directories.get(relative) {
    Some(children) => ServerHostResolveOk(children)
    None => ServerHostResolveError(FileNotFound, "Directory does not exist.")
  }
}

///|
impl @server.ServerHost for FakeServerHost with fn read_text_file(
  self,
  _root,
  path,
) {
  let key = path.to_string()
  match self.errors.get(key) {
    Some((code, message)) => ServerHostReadError(code, message)
    None =>
      match self.files.get(key) {
        Some(text) =>
          ServerHostReadOk(
            FileContent(
              text,
              display_name=path.display_name(),
              revision="rev-" + text.length().to_string(),
            ),
          )
        None => ServerHostReadError(FileNotFound, "missing file")
      }
  }
}

///|
impl @server.ServerHost for FakeServerHost with fn watch_text_file(
  self,
  _root,
  path,
  listener,
  _spawn_watch,
) {
  let key = path.to_string()
  self.listeners.set(key, listener)
  ServerWatch(() => self.listeners.remove(key))
}

///|
fn noop_watch_spawner(_task : async () -> Unit) -> Unit {
  ()
}

///|
struct FakeLanguageProvider {}

///|
impl @language.HoverProvider for FakeLanguageProvider with fn hover_at(
  _self,
  _document,
  offset,
) {
  Some({
    range: Range(offset, offset + 4),
    contents: [PlainText("Configured hover")],
  })
}

///|
fn assert_plaintext_hover(
  hover : @language.Hover,
  expected : String,
) -> Unit raise {
  match hover.contents {
    [PlainText(text)] => assert_eq(text, expected)
    _ => fail("expected plaintext hover")
  }
}

///|
impl @language.DefinitionProvider for FakeLanguageProvider with fn definition_at(
  _self,
  document,
  offset,
) {
  Some({ uri: document.uri, range: Range(offset, offset + 4) })
}

///|
impl @language.ReferencesProvider for FakeLanguageProvider with fn references_at(
  _self,
  document,
  offset,
) {
  [
    { uri: document.uri, range: Range(offset, offset + 4) },
    { uri: document.uri, range: Range(0, 4) },
  ]
}

///|
impl @language.DiagnosticsProvider for FakeLanguageProvider with fn diagnostics_for_document(
  _self,
  _document,
) {
  [{ range: Range(0, 4), severity: Warning, message: "Configured diagnostic" }]
}

///|
impl @language.DocumentSymbolProvider for FakeLanguageProvider with fn document_symbols(
  _self,
  _document,
) {
  [{ name: "configured", kind: "function", range: Range(7, 17) }]
}

///|
impl @language.SemanticTokensProvider for FakeLanguageProvider with fn semantic_tokens_for_document(
  _self,
  _document,
) {
  [{ range: Range(7, 17), token_type: "function" }]
}

///|
impl @language.FoldingRangeProvider for FakeLanguageProvider with fn folding_ranges(
  _self,
  _document,
) {
  [FoldingRange(1, 3, kind=Region)]
}
