///|
test "validates readonly remote workspace uris" {
  let uri = expect_uri("readonly-remote://workspace/docs/fixtures/demo.mbt")
  match @server.resolve_remote_document_uri(uri) {
    ParsedRemotePath(path) =>
      assert_eq(path.to_string(), "docs/fixtures/demo.mbt")
    RemotePathError(error) => fail(error.message)
  }

  let absolute = expect_uri("readonly-remote://workspace//tmp/demo.mbt")
  match @server.resolve_remote_document_uri(absolute) {
    RemotePathError(error) => assert_true(error.code == ProtocolInvalidUri)
    ParsedRemotePath(path) => fail("unexpected path " + path.to_string())
  }

  let wrong_scheme = expect_uri("file://local/docs/fixtures/demo.mbt")
  match @server.resolve_remote_document_uri(wrong_scheme) {
    RemotePathError(error) => assert_true(error.code == ProtocolInvalidUri)
    ParsedRemotePath(path) => fail("unexpected path " + path.to_string())
  }
}

///|
test "maps host read errors to protocol provider errors" {
  let host = FakeServerHost::new()
  host.errors.set("missing.mbt", (FileNotFound, "missing file"))
  let server = @server.RemoteServer("/workspace", host)
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
test "routes watch events to document changed packets" {
  let host = FakeServerHost::new()
  host.files.set("demo.mbt", "pub fn main {}\n")
  let server = @server.RemoteServer("/workspace/", host)
  let uri = expect_remote_uri("demo.mbt")
  let emitted = []

  match
    server.watch_document({ id: "watch-1", uri }, packet => emitted.push(packet)) {
    DocumentLoaded(payload) =>
      assert_eq(payload.document.text, "pub fn main {}\n")
    _ => fail("expected initial document load")
  }

  host.files.set("demo.mbt", "pub fn main { 1 }\n")
  host.emit("demo.mbt", Changed)
  assert_eq(emitted.length(), 1)
  match emitted[0] {
    DocumentChanged(payload) =>
      assert_eq(payload.document.text, "pub fn main { 1 }\n")
    _ => fail("expected document changed")
  }

  host.emit("demo.mbt", Deleted)
  match emitted[1] {
    RemoteError(error) => assert_eq(error.provider_code, "FileNotFound")
    _ => fail("expected deletion error")
  }
}

///|
async test "answers hover and definition from cached provider state" {
  let host = FakeServerHost::new()
  host.files.set("demo.mbt", "pub fn main {}\n")
  let server = @server.RemoteServer("/workspace", host)
  let uri = expect_remote_uri("demo.mbt")
  ignore(server.open_document({ id: "open-1", uri }))

  match server.hover({ id: "hover-1", uri, document_version: 1, offset: 7 }) {
    HoverResult(payload) =>
      match payload.hover {
        Some(hover) =>
          assert_eq(hover.contents, "Demo hover: entry point symbol")
        None => fail("expected hover")
      }
    _ => fail("expected hover result")
  }

  match
    server.definition({ id: "def-1", uri, document_version: 1, offset: 7 }) {
    DefinitionResult(payload) =>
      match payload.location {
        Some(location) =>
          assert_eq(location.uri.to_string(), "memory://fixture.mbt")
        None => fail("expected definition")
      }
    _ => fail("expected definition result")
  }
}

///|
async test "answers diagnostics symbols and semantic tokens from cached provider state" {
  let host = FakeServerHost::new()
  host.files.set("demo.mbt", "pub fn main { // TODO }\n")
  let server = @server.RemoteServer("/workspace", host)
  let uri = expect_remote_uri("demo.mbt")
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
      assert_eq(payload.symbols[0].name, "main")
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
}

///|
async test "dispatches language requests through configured providers" {
  let host = FakeServerHost::new()
  host.files.set("configured.mbt", "pub fn configured {}\n")
  let provider = FakeLanguageProvider::{  }
  let server = @server.RemoteServer::with_language_providers(
    "/workspace", host, provider, provider, provider, provider, provider,
  )
  let uri = expect_remote_uri("configured.mbt")
  ignore(server.open_document({ id: "open-1", uri }))

  match server.hover({ id: "hover-1", uri, document_version: 1, offset: 7 }) {
    HoverResult(payload) =>
      match payload.hover {
        Some(hover) => assert_eq(hover.contents, "Configured hover")
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
struct FakeServerHost {
  files : Map[String, String]
  errors : Map[String, (@workspace.FileSystemProviderErrorCode, String)]
  listeners : Map[String, (@workspace.FileChangeType) -> Unit]
}

///|
fn FakeServerHost::new() -> FakeServerHost {
  { files: Map::default(), errors: Map::default(), listeners: Map::default() }
}

///|
fn FakeServerHost::emit(
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
) {
  let key = path.to_string()
  self.listeners.set(key, listener)
  ServerWatch(() => self.listeners.remove(key))
}

///|
struct FakeLanguageProvider {}

///|
impl @language.HoverProvider for FakeLanguageProvider with fn hover_at(
  _self,
  _document,
  offset,
) {
  Some({ range: Range(offset, offset + 4), contents: "Configured hover" })
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
