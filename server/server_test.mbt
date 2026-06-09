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
test "routes raw lsp packets through host" {
  let host = FakeServerHost::new()
  host.lsp_response = "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{}}"
  let server = @server.RemoteServer("/workspace", host)

  match server.route_lsp({ id: "lsp-1", message: "{\"id\":1}" }) {
    LspResult(packet) => {
      assert_eq(packet.id, "lsp-1")
      assert_eq(packet.message, host.lsp_response)
      assert_eq(host.lsp_requests.length(), 1)
    }
    _ => fail("expected lsp result")
  }
}

///|
test "answers hover and definition from cached provider state" {
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
  lsp_requests : Array[String]
  mut lsp_response : String
}

///|
fn FakeServerHost::new() -> FakeServerHost {
  {
    files: Map::default(),
    errors: Map::default(),
    listeners: Map::default(),
    lsp_requests: [],
    lsp_response: "",
  }
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
impl @server.ServerHost for FakeServerHost with fn request_lsp(self, message) {
  self.lsp_requests.push(message)
  self.lsp_response
}

///|
impl @server.ServerHost for FakeServerHost with fn notify_lsp(self, message) {
  self.lsp_requests.push(message)
}
