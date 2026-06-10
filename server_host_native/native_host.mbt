///|
pub struct NativeServerHost {
  priv poll_interval_ms : Int
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
  { poll_interval_ms: 500 }
}

///|
pub fn NativeServerHost::with_poll_interval(
  poll_interval_ms : Int,
) -> NativeServerHost {
  {
    poll_interval_ms: if poll_interval_ms < 10 {
      10
    } else {
      poll_interval_ms
    },
  }
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
pub impl @server.ServerHost for NativeServerHost with fn read_text_file(
  self,
  root,
  path,
) {
  ignore(self)
  read_native_text_file(root, path)
}

///|
pub impl @server.ServerHost for NativeServerHost with fn list_workspace(
  self,
  root,
) {
  ignore(self)
  list_native_workspace(root)
}

///|
pub impl @server.ServerHost for NativeServerHost with fn watch_text_file(
  self,
  root,
  path,
  listener,
  spawn_watch,
) {
  let disposed = Ref(false)
  spawn_watch(async fn() {
    poll_native_file_watch(
      root,
      path,
      self.poll_interval_ms,
      disposed,
      listener,
    )
  })
  ServerWatch(() => disposed.val = true)
}

///|
async fn read_native_text_file(
  root : String,
  path : @workspace.SourcePath,
) -> @server.ServerHostReadResult {
  let target = workspace_file_path(root, path)
  match validate_native_file(root, target) {
    Some(error) => ServerHostReadError(error.0, error.1)
    None =>
      match try_read_text_file(target, path.display_name()) {
        Some(content) => ServerHostReadOk(content)
        None => ServerHostReadError(Unavailable, "Unable to read source file.")
      }
  }
}

///|
async fn list_native_workspace(root : String) -> @server.ServerHostListResult {
  let normalized_root = normalize_host_path(root)
  if !@fs.exists(normalized_root) {
    return ServerHostListError(FileNotFound, "Workspace root does not exist.")
  }
  match @fs.kind(normalized_root) {
    Directory => {
      let entries : Array[@remote_protocol.WorkspaceEntry] = []
      list_native_workspace_dir(normalized_root, "", 0, entries)
      ServerHostListOk(entries)
    }
    _ =>
      ServerHostListError(
        FileNotADirectory,
        "Workspace root is not a directory.",
      )
  }
}

///|
async fn list_native_workspace_dir(
  root : String,
  relative : String,
  depth : Int,
  entries : Array[@remote_protocol.WorkspaceEntry],
) -> Unit {
  let dir_path = if relative == "" { root } else { root + "/" + relative }
  let names = Some(@fs.readdir(dir_path, include_hidden=true, sort=true)) catch {
    _ => None
  }
  match names {
    Some(names) =>
      for name in names {
        let path = if relative == "" { name } else { relative + "/" + name }
        if !skip_workspace_entry(path~, name~) {
          let full_path = root + "/" + path
          match (Some(@fs.kind(full_path)) catch { _ => None }) {
            Some(Directory) => {
              entries.push({ path, name, kind: "directory", depth })
              list_native_workspace_dir(root, path, depth + 1, entries)
            }
            Some(Regular) => entries.push({ path, name, kind: "file", depth })
            _ => ()
          }
        }
      }
    None => ()
  }
}

///|
async fn poll_native_file_watch(
  root : String,
  path : @workspace.SourcePath,
  poll_interval_ms : Int,
  disposed : Ref[Bool],
  listener : async (@workspace.FileChangeType) -> Unit,
) -> Unit {
  let target = workspace_file_path(root, path)
  let mut previous = native_file_signature(target)
  while !disposed.val {
    @async.sleep(poll_interval_ms)
    let next = native_file_signature(target)
    if next != previous {
      let change_type : @workspace.FileChangeType = if next == "missing" {
        Deleted
      } else {
        Changed
      }
      listener(change_type) catch {
        _ => ()
      }
      previous = next
    }
  }
}

///|
async fn native_file_signature(path : String) -> String {
  if !@fs.exists(path) {
    return "missing"
  }
  match (Some(@fs.mtime(path)) catch { _ => None }) {
    Some((seconds, nanos)) => "exists:\{seconds}:\{nanos}"
    None => "missing"
  }
}

///|
async fn validate_native_file(
  root : String,
  target : String,
) -> (@workspace.FileSystemProviderErrorCode, String)? {
  let root_real = realpath_or_normalized(root)
  if !@fs.exists(target) {
    return Some((FileNotFound, "Source file does not exist."))
  }
  let target_real = realpath_or_normalized(target)
  if !is_under_root(root_real, target_real) {
    return Some((InvalidUri, "Source path escapes the workspace root."))
  }
  match @fs.kind(target_real) {
    Directory => Some((IsDirectory, "Source path is a directory."))
    Regular => None
    _ => Some((InvalidData, "Source path is not a regular text file."))
  }
}

///|
async fn try_read_text_file(
  target : String,
  display_name : String,
) -> @workspace.FileContent? {
  let data = Some(@fs.read_file(target)) catch { _ => None }
  match data {
    Some(data) => {
      let text = data.text()
      if text.contains("\u{0}") {
        None
      } else {
        Some(
          FileContent(
            text,
            display_name~,
            language_id=@workspace.infer_language_id(display_name),
            revision=native_file_signature(target),
          ),
        )
      }
    }
    None => None
  }
}

///|
async fn realpath_or_normalized(path : String) -> String {
  match (Some(@fs.realpath(path)) catch { _ => None }) {
    Some(real) => normalize_host_path(real)
    None => normalize_host_path(path)
  }
}

///|
fn workspace_file_path(root : String, path : @workspace.SourcePath) -> String {
  normalize_host_path(root) + "/" + path.to_string()
}

///|
fn normalize_host_path(path : String) -> String {
  let normalized = path.replace_all(old="\\", new="/")
  if normalized.has_suffix("/") && normalized.length() > 1 {
    normalized[0:normalized.length() - 1].to_owned()
  } else {
    normalized
  }
}

///|
fn is_under_root(root : String, target : String) -> Bool {
  target == root || target.has_prefix(root + "/")
}

///|
fn skip_workspace_entry(path~ : String, name~ : String) -> Bool {
  name == ".git" ||
  name == "_build" ||
  name == ".mooncakes" ||
  name == "node_modules" ||
  path == "web/generated" ||
  path == "web/dist"
}

///|
pub async fn run_native_editor_server(
  root : String,
  port? : Int = 5173,
  asset_dir? : String = "web/dist",
  lsp_command? : String = "moon-lsp",
  log? : (String) -> Unit = println,
) -> Unit {
  let host = NativeServerHost::NativeServerHost()
  let root = realpath_or_normalized(root)
  let remote_server = native_lsp_remote_server(root, host, lsp_command)
  let addr = @socket.Addr::parse("127.0.0.1:\{port}")
  let http_server = @http.Server(addr, reuse_addr=true)
  log("Readonly editor native server listening on http://127.0.0.1:\{port}/")
  http_server.run_forever() <| ((request, _body, conn) => {
    handle_native_editor_request(remote_server, asset_dir, request, conn)
  })
}

///|
fn native_lsp_remote_server(
  root : String,
  host : &@server.ServerHost,
  lsp_command : String,
) -> @server.RemoteServer {
  let transport = NativeLspTransport::configured(
    lsp_command,
    ["--stdio"],
    cwd=root,
  )
  let client = @server.LspClient::with_root_uri(
    transport,
    file_uri_for_host_path(root),
  )
  let provider = NativeWorkspaceLanguageProvider(
    root,
    client.language_provider(),
  )
  @server.RemoteServer::with_language_providers(
    root, host, provider, provider, provider, provider, provider,
  )
}

///|
async fn handle_native_editor_request(
  remote_server : @server.RemoteServer,
  asset_dir : String,
  request : @http.Request,
  conn : @http.ServerConnection,
) -> Unit {
  if request.path == "/protocol" {
    handle_protocol_connection(remote_server, request, conn)
  } else {
    serve_static_route(asset_dir, request, conn)
  }
}

///|
async fn handle_protocol_connection(
  remote_server : @server.RemoteServer,
  request : @http.Request,
  conn : @http.ServerConnection,
) -> Unit {
  let ws = @websocket.from_http_server(request, conn)
  defer ws.close()
  @async.with_task_group() <| group => {
    let spawn_watch = task => {
      group.spawn_bg(task, no_wait=true, allow_failure=true)
    }
    try {
      for ;; {
        let message = ws.recv()
        match message.kind {
          Text => {
            let raw = message.read_all().text()
            handle_protocol_message(remote_server, ws, raw, spawn_watch)
          }
          Binary => ignore(message.read_all().binary())
        }
      }
    } catch {
      @websocket.ConnectionClosed(_, _) => ()
      _ => ()
    }
    remote_server.dispose_watches()
  }
}

///|
async fn handle_protocol_message(
  remote_server : @server.RemoteServer,
  ws : @websocket.Conn,
  raw : String,
  spawn_watch : (async () -> Unit) -> Unit,
) -> Unit {
  match @remote_protocol.decode_client_packet(raw) {
    DecodedClientPacket(packet) => {
      let responses = remote_server.handle_client_packet(
        packet,
        packet => ws.send_text(packet.to_json()),
        spawn_watch,
      )
      for packet in responses {
        ws.send_text(packet.to_json())
      }
    }
    ClientPacketDecodeError(error) =>
      ws.send_text(@remote_protocol.RemoteError(error).to_json())
  }
}

///|
async fn serve_static_route(
  asset_dir : String,
  request : @http.Request,
  conn : @http.ServerConnection,
) -> Unit {
  guard request.meth is Get else {
    serve_not_found(conn)
    return
  }
  match static_route(request.path) {
    Some((file_name, content_type)) =>
      serve_static_file(conn, asset_dir + "/" + file_name, content_type)
    None => serve_not_found(conn)
  }
}

///|
async fn serve_static_file(
  conn : @http.ServerConnection,
  file_path : String,
  content_type : String,
) -> Unit {
  if !@fs.exists(file_path) {
    serve_not_found(conn)
    return
  }
  let content = Some(@fs.read_file(file_path).text()) catch { _ => None }
  match content {
    Some(content) =>
      conn
      ..send_response(200, "OK", extra_headers={
        "Content-Type": content_type,
        "Content-Length": content.length().to_string(),
      })
      ..write_string(content)
      .end_response()
    None => serve_not_found(conn)
  }
}

///|
async fn serve_not_found(conn : @http.ServerConnection) -> Unit {
  let body = "Not found"
  conn
  ..send_response(404, "Not Found", extra_headers={
    "Content-Type": "text/plain; charset=utf-8",
    "Content-Length": body.length().to_string(),
  })
  ..write_string(body)
  .end_response()
}

///|
fn static_route(path : String) -> (String, String)? {
  match strip_query(path) {
    "/" | "/index.html" => Some(("index.html", "text/html; charset=utf-8"))
    "/style.css" => Some(("style.css", "text/css; charset=utf-8"))
    "/editor.mjs" => Some(("editor.mjs", "text/javascript; charset=utf-8"))
    _ => None
  }
}

///|
fn strip_query(path : String) -> String {
  match path.find("?") {
    Some(index) => path[0:index].to_owned()
    None => path
  }
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
