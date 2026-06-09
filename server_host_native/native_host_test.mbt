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
  assert_true(
    host.request_lsp("{}").contains("Native LSP process host is not attached"),
  )
}

///|
fn expect_path(raw : String) -> @workspace.SourcePath raise {
  match @workspace.SourcePath::normalize_root_relative_path(raw) {
    ParsedSourcePath(path) => path
    SourcePathError(error) => fail("unexpected path error " + error.to_string())
  }
}
