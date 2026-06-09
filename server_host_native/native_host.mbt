///|
pub struct NativeServerHost {
  priv unavailable_message : String
}

///|
pub struct NativeLspTransport {
  priv unavailable_message : String
  priv command : String
  priv args : Array[String]
  priv cwd : String
  priv pid : Ref[Int]
  priv writer : Ref[@process.WriteToProcess?]
  priv reader : Ref[@process.ReadFromProcess?]
  priv listener : Ref[((String) -> Unit)?]
}

///|
pub fn NativeServerHost::NativeServerHost() -> NativeServerHost {
  { unavailable_message: "Native file host is not attached." }
}

///|
pub fn NativeLspTransport::NativeLspTransport() -> NativeLspTransport {
  {
    unavailable_message: "Native LSP process host is not attached.",
    command: "",
    args: [],
    cwd: "",
    pid: Ref(0),
    writer: Ref(None),
    reader: Ref(None),
    listener: Ref(None),
  }
}

///|
pub fn NativeLspTransport::configured(
  command : String,
  args : Array[String],
  cwd? : String = "",
) -> NativeLspTransport {
  {
    unavailable_message: "Native LSP process host is not attached.",
    command,
    args,
    cwd,
    pid: Ref(0),
    writer: Ref(None),
    reader: Ref(None),
    listener: Ref(None),
  }
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
pub fn native_lsp_transport_for_command(
  command : String,
  args : Array[String],
  cwd? : String = "",
) -> &@server.LspTransport {
  NativeLspTransport::configured(command, args, cwd~)
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
impl @server.LspTransport for NativeLspTransport with fn request(self, message) {
  if !self.ensure_process() {
    return lsp_error_response(self.unavailable_message)
  }
  if !self.write_message(message) {
    return lsp_error_response("Native LSP process write failed.")
  }
  match self.read_response_message() {
    Some(response) => response
    None => lsp_error_response("Native LSP process response failed.")
  }
}

///|
impl @server.LspTransport for NativeLspTransport with fn notify(self, message) {
  if self.ensure_process() {
    ignore(self.write_message(message))
  }
}

///|
impl @server.LspTransport for NativeLspTransport with fn subscribe(
  self,
  listener,
) {
  self.listener.val = Some(listener)
  LspSubscription(() => self.listener.val = None)
}

///|
pub fn lsp_stdio_frame(message : String) -> String {
  "Content-Length: " + message.length().to_string() + "\r\n\r\n" + message
}

///|
pub fn lsp_content_length_header(line : String) -> Int? {
  let trimmed = line.trim(char_set="\r\n ")
  let prefix = "content-length:"
  if !trimmed.to_lower().has_prefix(prefix) {
    return None
  }
  Some(@string.parse_int(trimmed[prefix.length():].trim(), base=10)) catch {
    _ => None
  }
}

///|
async fn NativeLspTransport::ensure_process(self : NativeLspTransport) -> Bool {
  if self.command == "" {
    return false
  }
  if self.writer.val is Some(_) && self.reader.val is Some(_) {
    return true
  }
  let started = Some(
    {
      let (stdin_input, stdin_writer) = @process.write_to_process()
      let (stdout_reader, stdout_output) = @process.read_from_process()
      let pid = if self.cwd == "" {
        @process.spawn_orphan(
          self.command,
          self.args,
          stdin=stdin_input,
          stdout=stdout_output,
        )
      } else {
        @process.spawn_orphan(
          self.command,
          self.args,
          stdin=stdin_input,
          stdout=stdout_output,
          cwd=self.cwd,
        )
      }
      self.pid.val = pid
      self.writer.val = Some(stdin_writer)
      self.reader.val = Some(stdout_reader)
      true
    },
  ) catch {
    _ => None
  }
  started.unwrap_or(false)
}

///|
async fn NativeLspTransport::write_message(
  self : NativeLspTransport,
  message : String,
) -> Bool {
  match self.writer.val {
    Some(writer) =>
      (Some(
        {
          writer.write(lsp_stdio_frame(message))
          true
        },
      ) catch {
        _ => None
      }).unwrap_or(false)
    None => false
  }
}

///|
async fn NativeLspTransport::read_response_message(
  self : NativeLspTransport,
) -> String? {
  let mut remaining = 64
  while remaining > 0 {
    match self.read_message() {
      Some(message) =>
        if lsp_message_has_id(message) {
          return Some(message)
        } else {
          self.emit_message(message)
        }
      None => return None
    }
    remaining = remaining - 1
  }
  None
}

///|
async fn NativeLspTransport::read_message(self : NativeLspTransport) -> String? {
  match self.reader.val {
    Some(reader) => read_lsp_stdio_frame(reader)
    None => None
  }
}

///|
async fn read_lsp_stdio_frame(reader : @process.ReadFromProcess) -> String? {
  let mut content_length = -1
  let mut header_done = false
  while !header_done {
    match reader.read_until("\n") {
      Some(line) =>
        if line.trim(char_set="\r\n") == "" {
          header_done = true
        } else {
          match lsp_content_length_header(line) {
            Some(length) => content_length = length
            None => ()
          }
        }
      None => return None
    }
  }
  if content_length < 0 {
    return None
  }
  let body = Some(reader.read_exactly(content_length)) catch { _ => None }
  match body {
    Some(bytes) => Some(@utf8.decode(bytes)) catch { _ => None }
    None => None
  }
}

///|
fn NativeLspTransport::emit_message(
  self : NativeLspTransport,
  message : String,
) -> Unit {
  match self.listener.val {
    Some(listener) => listener(message)
    None => ()
  }
}

///|
fn lsp_message_has_id(message : String) -> Bool {
  message.contains("\"id\"")
}

///|
fn lsp_error_response(message : String) -> String {
  "{\"jsonrpc\":\"2.0\",\"id\":null,\"error\":{\"code\":-32099,\"message\":\"" +
  json_escape(message) +
  "\"}}"
}

///|
fn json_escape(value : String) -> String {
  value.replace_all(old="\\", new="\\\\").replace_all(old="\"", new="\\\"")
}
