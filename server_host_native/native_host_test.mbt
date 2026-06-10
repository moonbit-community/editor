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
async test "native host lists workspace entries in preorder and skips generated directories" {
  let root = "_build/native_host_list_test"
  reset_dir(root)
  @async.with_task_group() <| group => {
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    @fs.mkdir(root + "/src/lib", recursive=true)
    @fs.mkdir(root + "/web/dist", recursive=true)
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
    @fs.write_file(
      root + "/web/dist/editor.mjs",
      "ignored",
      create_mode=CreateOrTruncate,
    )
    @fs.write_file(
      root + "/_build/ignored.mbt",
      "ignored",
      create_mode=CreateOrTruncate,
    )

    let host = @server_host_native.native_server_host()
    match host.list_workspace(root) {
      ServerHostListOk(entries) => {
        assert_eq(entry_kind(entries, "moon.mod"), "file")
        assert_eq(entry_kind(entries, "src"), "directory")
        assert_eq(entry_kind(entries, "src/lib"), "directory")
        assert_eq(entry_kind(entries, "src/lib/util.mbt"), "file")
        assert_eq(entry_kind(entries, "web/dist/editor.mjs"), "")
        assert_eq(entry_kind(entries, "_build/ignored.mbt"), "")
      }
      ServerHostListError(_code, message) => fail(message)
    }
  }
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
fn entry_kind(
  entries : Array[@remote_protocol.WorkspaceEntry],
  path : String,
) -> String {
  for entry in entries {
    if entry.path == path {
      return entry.kind
    }
  }
  ""
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
fn expect_path(raw : String) -> @workspace.SourcePath raise {
  match @workspace.SourcePath::normalize_root_relative_path(raw) {
    ParsedSourcePath(path) => path
    SourcePathError(error) => fail("unexpected path error " + error.to_string())
  }
}
