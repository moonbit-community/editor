///|
pub struct NativeServerHost {
  priv unavailable_message : String
}

///|
pub struct NativeLspTransport {
  priv unavailable_message : String
}

///|
pub fn NativeServerHost::NativeServerHost() -> NativeServerHost {
  { unavailable_message: "Native file host is not attached." }
}

///|
pub fn NativeLspTransport::NativeLspTransport() -> NativeLspTransport {
  { unavailable_message: "Native LSP process host is not attached." }
}

///|
pub fn native_server_host() -> &@server.ServerHost {
  NativeServerHost()
}

///|
pub fn native_lsp_transport() -> &@server.LspTransport {
  NativeLspTransport()
}

///|
impl @server.ServerHost for NativeServerHost with fn read_text_file(
  self,
  root,
  path,
) {
  ServerHostReadError(
    Unavailable,
    self.unavailable_message + " for " + root + "/" + path.to_string(),
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
impl @server.LspTransport for NativeLspTransport with fn request(self, _message) {
  "{\"jsonrpc\":\"2.0\",\"id\":null,\"error\":{\"code\":-32099,\"message\":\"" +
  self.unavailable_message +
  "\"}}"
}

///|
impl @server.LspTransport for NativeLspTransport with fn notify(_self, _message) {
  ()
}

///|
impl @server.LspTransport for NativeLspTransport with fn subscribe(
  _self,
  _listener,
) {
  LspSubscription(() => ())
}
