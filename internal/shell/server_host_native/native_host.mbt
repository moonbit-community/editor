///|
/// Native filesystem host for the reference remote server.
pub struct NativeServerHost {
  priv poll_interval_ms : Int
}

///|
/// Native stdio transport for a spawned LSP process.
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
/// Creates the native host with the default file-watch polling interval.
pub fn NativeServerHost::NativeServerHost() -> NativeServerHost {
  { poll_interval_ms: 500 }
}

///|
/// Creates the native host with a clamped polling interval.
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
/// Creates an unattached LSP transport that reports unavailable until
/// configured.
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
/// Creates an LSP transport that lazily spawns `command` with `args`.
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
/// Returns the default native filesystem host as a server host trait object.
pub fn native_server_host() -> &@server.ServerHost {
  NativeServerHost()
}

///|
/// Returns an unattached native LSP transport.
pub fn native_lsp_transport() -> &@server.LspTransport {
  NativeLspTransport()
}

///|
/// Returns a configured native LSP transport for a command and working
/// directory.
pub fn native_lsp_transport_for_command(
  command : String,
  args : Array[String],
  cwd? : String = "",
) -> &@server.LspTransport {
  NativeLspTransport::configured(command, args, cwd~)
}

///|
/// Reads one validated text file under the workspace root.
pub impl @server.ServerHost for NativeServerHost with fn read_text_file(
  self,
  root,
  path,
) {
  ignore(self)
  read_native_text_file(root, path)
}

///|
/// Reads one validated directory level under the workspace root.
pub impl @server.ServerHost for NativeServerHost with fn read_directory(
  self,
  root,
  relative,
) {
  ignore(self)
  read_native_directory(root, relative)
}

///|
/// Watches one validated text file by polling and reporting changed/deleted
/// events.
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
/// Resolves exactly one directory level: a non-recursive `readdir` that
/// reuses `skip_workspace_entry` filtering and mints each child's
/// `readonly-remote://workspace/<path>` URI with unresolved children.
async fn read_native_directory(
  root : String,
  relative : String,
) -> @server.ServerHostResolveResult {
  let normalized_root = normalize_host_path(root)
  let dir_path = if relative == "" {
    normalized_root
  } else {
    normalized_root + "/" + relative
  }
  if !@fs.exists(dir_path) {
    return ServerHostResolveError(FileNotFound, "Directory does not exist.")
  }
  let root_real = realpath_or_normalized(normalized_root)
  let dir_real = realpath_or_normalized(dir_path)
  if !is_under_root(root_real, dir_real) {
    return ServerHostResolveError(
      InvalidUri,
      "Directory path escapes the workspace root.",
    )
  }
  match (Some(@fs.kind(dir_real)) catch { _ => None }) {
    Some(Directory) => ()
    _ =>
      return ServerHostResolveError(
        FileNotADirectory,
        "Path is not a directory.",
      )
  }
  let names = Some(@fs.readdir(dir_path, include_hidden=true, sort=true)) catch {
    _ => None
  }
  guard names is Some(names) else {
    return ServerHostResolveError(Unavailable, "Unable to read directory.")
  }
  let children : Array[@workspace.WorkspaceStat] = []
  for name in names {
    let path = if relative == "" { name } else { relative + "/" + name }
    if !skip_workspace_entry(path~, name~) {
      let kind : @workspace.WorkspaceEntryKind? = match
        (Some(@fs.kind(dir_path + "/" + name)) catch { _ => None }) {
        Some(Directory) => Some(Directory)
        Some(Regular) => Some(File)
        _ => None
      }
      match (kind, @server.remote_document_uri(path)) {
        (Some(kind), Some(uri)) =>
          children.push({ uri, name, kind, children: None })
        _ => ()
      }
    }
  }
  ServerHostResolveOk(children)
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
) -> @workspace.DocumentContent? {
  let data = Some(@fs.read_file(target)) catch { _ => None }
  match data {
    Some(data) => {
      let text = data.text()
      if text.contains("\u{0}") {
        None
      } else {
        Some(
          DocumentContent(
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
/// Starts the native reference server: static assets over HTTP and the remote
/// workspace protocol over WebSocket.
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
    root, host, provider, provider, provider, provider, provider, provider, provider,
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
  // Watch tasks emit packets concurrently with request handling, and the
  // websocket connection rejects interleaved sends; one writer task owns
  // the socket and everything else enqueues outbound frames.
  let outbox : @aqueue.Queue[String] = Queue(kind=Unbounded)
  @async.with_task_group() <| group => {
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      for ;; {
        ws.send_text(outbox.get())
      }
    })
    let spawn_watch = task => {
      group.spawn_bg(task, no_wait=true, allow_failure=true)
    }
    try {
      for ;; {
        let message = ws.recv()
        match message.kind {
          Text => {
            let raw = message.read_all().text()
            handle_protocol_message(remote_server, outbox, raw, spawn_watch)
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
  outbox : @aqueue.Queue[String],
  raw : String,
  spawn_watch : (async () -> Unit) -> Unit,
) -> Unit {
  match @remote_protocol.decode_client_packet(raw) {
    DecodedClientPacket(packet) => {
      let responses = remote_server.handle_client_packet(
        packet,
        packet => outbox.put(packet.to_json().stringify()),
        spawn_watch,
      )
      for packet in responses {
        outbox.put(packet.to_json().stringify())
      }
    }
    ClientPacketDecodeError(error) =>
      outbox.put(@remote_protocol.RemoteError(error).to_json().stringify())
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
  let content = Some(@fs.read_file(file_path).binary()) catch { _ => None }
  match content {
    Some(content) => {
      conn.send_response(200, "OK", extra_headers={
        "Content-Type": content_type,
        "Content-Length": content.length().to_string(),
      })
      write_static_response_body(conn, content)
      conn.end_response()
    }
    None => serve_not_found(conn)
  }
}

///|
async fn write_static_response_body(
  conn : @http.ServerConnection,
  content : Bytes,
) -> Unit {
  let chunk_size = 16384
  let mut start = 0
  while start < content.length() {
    let end = if start + chunk_size < content.length() {
      start + chunk_size
    } else {
      content.length()
    }
    conn.write(content[start:end])
    start = end
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
    "/embed.html" => Some(("embed.html", "text/html; charset=utf-8"))
    "/style.css" => Some(("style.css", "text/css; charset=utf-8"))
    "/editor.mjs" => Some(("editor.mjs", "text/javascript; charset=utf-8"))
    "/embed.mjs" => Some(("embed.mjs", "text/javascript; charset=utf-8"))
    "/browser-tests/component.html" =>
      Some(("browser-tests/component.html", "text/html; charset=utf-8"))
    "/browser-tests/component.mjs" =>
      Some(("browser-tests/component.mjs", "text/javascript; charset=utf-8"))
    "/browser-tests/component.mjs.map" =>
      Some(
        ("browser-tests/component.mjs.map", "application/json; charset=utf-8"),
      )
    "/browser-tests/perf.html" =>
      Some(("browser-tests/perf.html", "text/html; charset=utf-8"))
    "/browser-tests/perf.mjs" =>
      Some(("browser-tests/perf.mjs", "text/javascript; charset=utf-8"))
    "/browser-tests/perf.mjs.map" =>
      Some(("browser-tests/perf.mjs.map", "application/json; charset=utf-8"))
    "/browser-tests/reveal.html" =>
      Some(("browser-tests/reveal.html", "text/html; charset=utf-8"))
    "/browser-tests/reveal.mjs" =>
      Some(("browser-tests/reveal.mjs", "text/javascript; charset=utf-8"))
    "/browser-tests/reveal.mjs.map" =>
      Some(("browser-tests/reveal.mjs.map", "application/json; charset=utf-8"))
    "/browser-tests/read_api.html" =>
      Some(("browser-tests/read_api.html", "text/html; charset=utf-8"))
    "/browser-tests/read_api.mjs" =>
      Some(("browser-tests/read_api.mjs", "text/javascript; charset=utf-8"))
    "/browser-tests/read_api.mjs.map" =>
      Some(
        ("browser-tests/read_api.mjs.map", "application/json; charset=utf-8"),
      )
    "/browser-tests/whitespace.html" =>
      Some(("browser-tests/whitespace.html", "text/html; charset=utf-8"))
    "/browser-tests/whitespace.mjs" =>
      Some(("browser-tests/whitespace.mjs", "text/javascript; charset=utf-8"))
    "/browser-tests/whitespace.mjs.map" =>
      Some(
        ("browser-tests/whitespace.mjs.map", "application/json; charset=utf-8"),
      )
    "/browser-tests/whitespace_selection.html" =>
      Some(
        ("browser-tests/whitespace_selection.html", "text/html; charset=utf-8"),
      )
    "/browser-tests/whitespace_selection.mjs" =>
      Some(
        (
          "browser-tests/whitespace_selection.mjs", "text/javascript; charset=utf-8",
        ),
      )
    "/browser-tests/whitespace_selection.mjs.map" =>
      Some(
        (
          "browser-tests/whitespace_selection.mjs.map", "application/json; charset=utf-8",
        ),
      )
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
/// Frames a JSON-RPC message for LSP stdio. Content length is measured in UTF-8
/// bytes, not MoonBit string code units.
pub fn lsp_stdio_frame(message : String) -> String {
  "Content-Length: " +
  @utf8.encode(message).length().to_string() +
  "\r\n\r\n" +
  message
}

///|
/// Parses a case-insensitive LSP `Content-Length` header.
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
    match (reader.read_until("\n") catch { _ => None }) {
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
