///|
pub struct NativeServerHost {
  priv unavailable_message : String
}

///|
pub fn NativeServerHost::NativeServerHost() -> NativeServerHost {
  { unavailable_message: "Native file host is not attached." }
}

///|
pub fn native_server_host() -> &@server.ServerHost {
  NativeServerHost()
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
