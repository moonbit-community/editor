///|
test "native host reports unavailable effects until runtime is attached" {
  let host = @server_host_native.native_server_host()
  match host.read_text_file("/workspace", expect_path("demo.mbt")) {
    ServerHostReadError(code, message) => {
      assert_true(code == Unavailable)
      assert_true(message.contains("Native file host is not attached"))
    }
    ServerHostReadOk(_) => fail("expected unavailable native file host")
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
