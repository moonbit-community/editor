///|
async test "native host reads root-relative text files" {
  let root = "_build/native_host_read_test"
  reset_dir(root)
  @async.with_task_group() <| group => {
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    @fs.mkdir(root + "/src", recursive=true)
    @fs.write_file(
      root + "/src/main.mbt",
      "pub fn main {}\n",
      create_mode=CreateOrTruncate,
    )
    let host = @server_host_native.native_server_host()
    match host.read_text_file(root, expect_path("src/main.mbt")) {
      ServerHostReadOk(content) => {
        assert_eq(content.text, "pub fn main {}\n")
        assert_eq(content.display_name, "src/main.mbt")
        assert_eq(content.language_id, "moonbit")
      }
      ServerHostReadError(_code, message) => fail(message)
    }

    match host.read_text_file(root, expect_path("src")) {
      ServerHostReadError(code, _) => assert_true(code == IsDirectory)
      ServerHostReadOk(_) => fail("expected directory read rejection")
    }
  }
}

///|
async test "native host resolves one directory level with minted uris" {
  let root = "_build/native_host_resolve_test"
  reset_dir(root)
  @async.with_task_group() <| group => {
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    @fs.mkdir(root + "/src/lib", recursive=true)
    @fs.mkdir(root + "/_build", recursive=true)
    @fs.write_file(
      root + "/moon.mod",
      "name = \"fixture\"\n",
      create_mode=CreateOrTruncate,
    )
    @fs.write_file(
      root + "/src/main.mbt",
      "pub fn main {}\n",
      create_mode=CreateOrTruncate,
    )
    @fs.write_file(
      root + "/src/lib/util.mbt",
      "pub fn util {}\n",
      create_mode=CreateOrTruncate,
    )

    let host = @server_host_native.native_server_host()
    match host.read_directory(root, "") {
      ServerHostResolveOk(children) => {
        // One level only, with generated trees filtered out and every
        // child carrying a minted URI and unresolved children.
        assert_eq(
          stat_kind(children, "readonly-remote://workspace/moon.mod"),
          "file",
        )
        assert_eq(
          stat_kind(children, "readonly-remote://workspace/src"),
          "directory",
        )
        assert_eq(children.length(), 2)
        for child in children {
          assert_true(child.children is None)
        }
      }
      ServerHostResolveError(_code, message) => fail(message)
    }

    match host.read_directory(root, "src") {
      ServerHostResolveOk(children) => {
        assert_eq(
          stat_kind(children, "readonly-remote://workspace/src/lib"),
          "directory",
        )
        assert_eq(
          stat_kind(children, "readonly-remote://workspace/src/main.mbt"),
          "file",
        )
        assert_eq(children.length(), 2)
      }
      ServerHostResolveError(_code, message) => fail(message)
    }

    match host.read_directory(root, "missing") {
      ServerHostResolveError(code, _) => assert_true(code == FileNotFound)
      ServerHostResolveOk(_) => fail("expected missing directory error")
    }

    match host.read_directory(root, "moon.mod") {
      ServerHostResolveError(code, _) => assert_true(code == FileNotADirectory)
      ServerHostResolveOk(_) => fail("expected non-directory error")
    }
  }
}

///|
fn stat_kind(stats : Array[@workspace.WorkspaceStat], uri : String) -> String {
  for stat in stats {
    if stat.uri.to_string() == uri {
      return stat.kind.to_string()
    }
  }
  ""
}

///|
async test "native host polling watch emits changed and deleted" {
  let root = "_build/native_host_watch_test"
  reset_dir(root)
  @async.with_task_group() <| group => {
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    @fs.mkdir(root, recursive=true)
    @fs.write_file(
      root + "/watched.mbt",
      "pub fn watched { 1 }\n",
      create_mode=CreateOrTruncate,
    )

    let events : Array[@workspace.FileChangeType] = []
    let host : &@server.ServerHost = @server_host_native.NativeServerHost::with_poll_interval(
      20,
    )
    let watch = host.watch_text_file(
      root,
      expect_path("watched.mbt"),
      change => events.push(change),
      task => group.spawn_bg(task, no_wait=true, allow_failure=true),
    )
    @async.sleep(30)
    @fs.write_file(
      root + "/watched.mbt",
      "pub fn watched { 2 }\n",
      create_mode=CreateOrTruncate,
    )
    wait_for_events(events, 1)
    @fs.remove(root + "/watched.mbt")
    wait_for_events(events, 2)
    watch.dispose()
    assert_true(events[0] == Changed)
    assert_true(events[1] == Deleted)
  }
}

///|
async fn reset_dir(path : String) -> Unit {
  if @fs.exists(path) {
    @fs.rmdir(path, recursive=true)
  }
}

///|
async fn wait_for_events(
  events : Array[@workspace.FileChangeType],
  count : Int,
) -> Unit {
  let mut remaining = 50
  while events.length() < count && remaining > 0 {
    @async.sleep(20)
    remaining = remaining - 1
  }
  if events.length() < count {
    fail("timed out waiting for native watch event")
  }
}

///|
async test "native lsp transport reports unavailable process host" {
  let transport = @server_host_native.native_lsp_transport()
  let response = transport.request("{\"jsonrpc\":\"2.0\",\"id\":1}")
  assert_true(response.contains("Native LSP process host is not attached"))
  transport.notify("{\"jsonrpc\":\"2.0\",\"method\":\"exit\"}")
  let subscription = transport.subscribe(_message => ())
  subscription.dispose()
}

///|
async test "configured native lsp transport exchanges stdio frames" {
  let script = "dd bs=1 count=62 of=/dev/null 2>/dev/null; printf 'Content-Length: 38\\r\\n\\r\\n{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":null}'"
  let transport = @server_host_native.native_lsp_transport_for_command(
    "/bin/sh",
    ["-c", script],
  )
  let response = transport.request(
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"test\"}",
  )
  assert_true(response.contains("\"result\":null"))
}

///|
async test "configured native lsp transport reports mid-frame process exit" {
  let script = "printf 'Content-Length: 38\\r\\n\\r\\n{\"jsonrpc\"'"
  let transport = @server_host_native.native_lsp_transport_for_command(
    "/bin/sh",
    ["-c", script],
  )
  let response = transport.request(
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"test\"}",
  )
  assert_true(response.contains("Native LSP process response failed."))
}

///|
test "native lsp stdio framing uses content length headers" {
  let message = "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":null}"
  let frame = @server_host_native.lsp_stdio_frame(message)
  assert_true(frame.has_prefix("Content-Length: 38\r\n\r\n"))
  assert_true(frame.has_suffix(message))
  match
    @server_host_native.lsp_content_length_header("Content-Length: 38\r\n") {
    Some(length) => assert_eq(length, 38)
    None => fail("expected content length")
  }
  match @server_host_native.lsp_content_length_header("content-length: 38\n") {
    Some(length) => assert_eq(length, 38)
    None => fail("expected lower-case content length")
  }
  assert_true(
    @server_host_native.lsp_content_length_header("X-Header: 38\r\n") is None,
  )
}

///|
test "native lsp stdio framing counts utf8 bytes" {
  let message = "{\"jsonrpc\":\"2.0\",\"id\":1,\"params\":{\"text\":\"汉\"}}"
  let byte_length = @utf8.encode(message).length()
  assert_true(byte_length > message.length())
  let frame = @server_host_native.lsp_stdio_frame(message)
  assert_true(
    frame.has_prefix("Content-Length: " + byte_length.to_string() + "\r\n\r\n"),
  )
  assert_true(frame.has_suffix(message))
}

///|
async test "native workspace language provider bridges remote documents to file uri lsp" {
  let root = "_build/native_host_lsp_provider_test"
  reset_dir(root)
  @async.with_task_group() <| group => {
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    @fs.mkdir(root, recursive=true)
    @fs.write_file(
      root + "/simple.mbt",
      "pub fn startup_event() -> Unit {}\n",
      create_mode=CreateOrTruncate,
    )
    let root_real = @fs.realpath(root)
    let root_uri = @server_host_native.file_uri_for_host_path(root_real)
    let file_uri = root_uri + "/simple.mbt"
    let transport = RecordingLanguageTransport::new(file_uri)
    let client = @server.LspClient::with_root_uri(transport, root_uri)
    let provider = @server_host_native.NativeWorkspaceLanguageProvider(
      root_real,
      client.language_provider(),
    )
    let remote_uri = expect_remote_uri("simple.mbt")
    let document = @workspace.SourceDocument(
      remote_uri, "simple.mbt", "moonbit", 1, "rev-1", "pub fn startup_event() -> Unit {}\n",
    )

    match provider.hover_at(document, 7) {
      Some(hover) => {
        match hover.contents {
          [PlainText(text)] => assert_eq(text, "LSP hover for startup_event")
          _ => fail("expected plaintext hover")
        }
        assert_true(hover.range == Range(7, 20))
      }
      None => fail("expected lsp hover")
    }
    match provider.definition_at(document, 7) {
      Some(location) => {
        assert_eq(location.uri.to_string(), remote_uri.to_string())
        assert_true(location.range == Range(7, 20))
      }
      None => fail("expected lsp definition")
    }
    assert_true(
      transport.requests.any(message => {
        message.contains("\"rootUri\":\"" + root_uri + "\"")
      }),
    )
    assert_true(
      transport.requests.any(message => {
        message.contains("\"uri\":\"" + file_uri + "\"") &&
        message.contains("\"method\":\"textDocument/hover\"")
      }),
    )
    assert_true(
      transport.notifications.any(message => {
        message.contains("\"method\":\"textDocument/didOpen\"") &&
        message.contains("\"uri\":\"" + file_uri + "\"")
      }),
    )
  }
}

///|
fn expect_path(raw : String) -> @workspace.SourcePath raise {
  match @workspace.SourcePath::normalize_root_relative_path(raw) {
    ParsedSourcePath(path) => path
    SourcePathError(error) => fail("unexpected path error " + error.to_string())
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
struct RecordingLanguageTransport {
  file_uri : String
  requests : Array[String]
  notifications : Array[String]
  listener : Ref[((String) -> Unit)?]
}

///|
fn RecordingLanguageTransport::new(
  file_uri : String,
) -> RecordingLanguageTransport {
  { file_uri, requests: [], notifications: [], listener: Ref(None) }
}

///|
impl @server.LspTransport for RecordingLanguageTransport with fn request(
  self,
  message,
) {
  self.requests.push(message)
  if message.contains("\"method\":\"initialize\"") {
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"capabilities\":{\"hoverProvider\":true,\"definitionProvider\":true}}}"
  } else if message.contains("\"method\":\"textDocument/hover\"") {
    "{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":{\"contents\":\"LSP hover for startup_event\",\"range\":{\"start\":{\"line\":0,\"character\":7},\"end\":{\"line\":0,\"character\":20}}}}"
  } else if message.contains("\"method\":\"textDocument/definition\"") {
    "{\"jsonrpc\":\"2.0\",\"id\":3,\"result\":{\"uri\":\"" +
    self.file_uri +
    "\",\"range\":{\"start\":{\"line\":0,\"character\":7},\"end\":{\"line\":0,\"character\":20}}}}"
  } else {
    "{\"jsonrpc\":\"2.0\",\"id\":4,\"result\":null}"
  }
}

///|
impl @server.LspTransport for RecordingLanguageTransport with fn notify(
  self,
  message,
) {
  self.notifications.push(message)
}

///|
impl @server.LspTransport for RecordingLanguageTransport with fn subscribe(
  self,
  listener,
) {
  self.listener.val = Some(listener)
  LspSubscription(() => self.listener.val = None)
}
