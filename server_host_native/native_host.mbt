///|
pub struct NativeServerHost {
  priv lsp_unavailable_message : String
}

///|
pub fn NativeServerHost::NativeServerHost() -> NativeServerHost {
  { lsp_unavailable_message: "Native LSP process host is not attached." }
}

///|
pub fn native_server_host() -> &@server.ServerHost {
  NativeServerHost()
}

///|
impl @server.ServerHost for NativeServerHost with fn read_text_file(
  _self,
  root,
  path,
) {
  ServerHostReadError(
    Unavailable,
    "Native file host is not attached for " + root + "/" + path.to_string(),
  )
}

///|
impl @server.ServerHost for NativeServerHost with fn watch_text_file(
  _self,
  _root,
  _path,
  _listener,
) {
  ServerWatch(() => ())
}

///|
impl @server.ServerHost for NativeServerHost with fn request_lsp(self, _message) {
  "{\"jsonrpc\":\"2.0\",\"id\":null,\"error\":{\"code\":-32099,\"message\":\"" +
  self.lsp_unavailable_message +
  "\"}}"
}

///|
impl @server.ServerHost for NativeServerHost with fn notify_lsp(_self, _message) {
  ()
}
