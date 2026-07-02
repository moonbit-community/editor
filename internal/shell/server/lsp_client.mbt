///|
/// Disposable subscription to server-initiated LSP messages.
pub struct LspSubscription {
  priv dispose : () -> Unit
}

///|
/// Builds an LSP message subscription from a transport disposer.
pub fn LspSubscription::LspSubscription(
  dispose : () -> Unit,
) -> LspSubscription {
  { dispose, }
}

///|
/// Unsubscribes from server-initiated LSP messages.
pub fn LspSubscription::dispose(self : LspSubscription) -> Unit {
  (self.dispose)()
}

///|
/// JSON-RPC transport used by `LspClient`; native code owns stdio/process
/// details while the client owns request shape and response parsing.
pub(open) trait LspTransport {
  async fn request(Self, String) -> String
  async fn notify(Self, String) -> Unit
  fn subscribe(Self, (String) -> Unit) -> LspSubscription
}

///|
/// Lifecycle state for the LSP client connection.
pub(all) enum LspClientState {
  Idle
  Initializing
  Ready
  Failed
  Stopping
  Stopped
} derive(Eq, Debug)

///|
priv struct LspServerCapabilities {
  hover_provider : Bool
  definition_provider : Bool
  references_provider : Bool
  document_symbol_provider : Bool
  publish_diagnostics : Bool
}

///|
priv struct LspPendingRequest {
  method_name : String
  uri : String
  revision : String
}

///|
fn LspPendingRequest::is_document_request(self : LspPendingRequest) -> Bool {
  self.method_name != "" && self.uri != "" && self.revision != ""
}

///|
/// Stateful LSP client with cached capabilities, active document identity, and
/// pending request freshness tracking.
pub struct LspClient {
  priv transport : &LspTransport
  priv root_uri : String
  priv next_id : Ref[Int]
  priv state : Ref[LspClientState]
  priv subscribed : Ref[Bool]
  priv subscription : Ref[LspSubscription?]
  priv active_uri : Ref[String]
  priv active_revision : Ref[String]
  priv active_version : Ref[Int]
  priv active_snapshot : Ref[@workspace.DocumentSnapshot?]
  priv capabilities : Ref[LspServerCapabilities]
  priv pending_requests : Map[Int, LspPendingRequest]
  priv diagnostics : Map[String, LspCachedDiagnostics]
  priv diagnostics_listener : Ref[((String, Int) -> Unit)?]
  priv last_error : Ref[String]
}

///|
/// Adapter that exposes one `LspClient` through the language provider traits.
pub(all) struct LspLanguageProvider {
  priv client : LspClient
}

///|
priv struct LspCachedDiagnostics {
  version : Int
  diagnostics : Array[@language.Diagnostic]
}

///|
fn default_lsp_capabilities() -> LspServerCapabilities {
  {
    hover_provider: false,
    definition_provider: false,
    references_provider: false,
    document_symbol_provider: false,
    publish_diagnostics: true,
  }
}

///|
/// Creates an LSP client without a root URI.
pub fn LspClient::LspClient(transport : &LspTransport) -> LspClient {
  LspClient::with_root_uri(transport, "")
}

///|
/// Creates an LSP client with an explicit root URI for initialization.
pub fn LspClient::with_root_uri(
  transport : &LspTransport,
  root_uri : String,
) -> LspClient {
  {
    transport,
    root_uri,
    next_id: Ref(0),
    state: Ref(Idle),
    subscribed: Ref(false),
    subscription: Ref(None),
    active_uri: Ref(""),
    active_revision: Ref(""),
    active_version: Ref(0),
    active_snapshot: Ref(None),
    capabilities: Ref(default_lsp_capabilities()),
    pending_requests: Map::default(),
    diagnostics: Map::default(),
    diagnostics_listener: Ref(None),
    last_error: Ref(""),
  }
}

///|
/// Returns the language-provider adapter for this client.
pub fn LspClient::language_provider(self : LspClient) -> LspLanguageProvider {
  { client: self }
}

///|
/// Views the adapter as a hover provider.
pub fn LspLanguageProvider::as_hover_provider(
  self : LspLanguageProvider,
) -> &@language.HoverProvider {
  self
}

///|
/// Views the adapter as a definition provider.
pub fn LspLanguageProvider::as_definition_provider(
  self : LspLanguageProvider,
) -> &@language.DefinitionProvider {
  self
}

///|
/// Views the adapter as a references provider.
pub fn LspLanguageProvider::as_references_provider(
  self : LspLanguageProvider,
) -> &@language.ReferencesProvider {
  self
}

///|
/// Views the adapter as a diagnostics provider.
pub fn LspLanguageProvider::as_diagnostics_provider(
  self : LspLanguageProvider,
) -> &@language.DiagnosticsProvider {
  self
}

///|
/// Views the adapter as a document-symbol provider.
pub fn LspLanguageProvider::as_document_symbol_provider(
  self : LspLanguageProvider,
) -> &@language.DocumentSymbolProvider {
  self
}

///|
/// Whether initialization completed successfully.
pub fn LspClient::is_initialized(self : LspClient) -> Bool {
  self.state.val == Ready
}

///|
/// Current lifecycle state.
pub fn LspClient::state(self : LspClient) -> LspClientState {
  self.state.val
}

///|
/// Number of outstanding JSON-RPC requests tracked for freshness cleanup.
pub fn LspClient::pending_request_count(self : LspClient) -> Int {
  self.pending_requests.length()
}

///|
/// Last parse, transport, or response error observed by the client.
pub fn LspClient::last_error(self : LspClient) -> String {
  self.last_error.val
}

///|
/// Clears the recorded last error.
pub fn LspClient::clear_last_error(self : LspClient) -> Unit {
  self.last_error.val = ""
}

///|
/// Installs a listener notified when diagnostics arrive for a URI/version.
pub fn LspClient::set_diagnostics_listener(
  self : LspClient,
  listener : ((String, Int) -> Unit)?,
) -> Unit {
  self.diagnostics_listener.val = listener
}

///|
/// Ensures the LSP server is initialized and synchronized to `document`, then
/// returns cached document-level feature data available without extra requests.
pub async fn LspClient::sync_document(
  self : LspClient,
  document : @workspace.DocumentSnapshot,
) -> @language.ProviderResult {
  self.ensure_subscribed()
  if !self.ensure_initialized(document) {
    return @language.ProviderResult::empty()
  }
  self.sync_active_document(document)
  {
    hovers: [],
    diagnostics: self.cached_diagnostics_for_document(document),
    definitions: [],
    symbols: [],
  }
}

///|
/// Requests hover data at a UTF-16 document offset when the server advertises
/// hover support.
pub async fn LspClient::hover_at(
  self : LspClient,
  document : @workspace.DocumentSnapshot,
  offset : Int,
) -> @language.Hover? {
  ignore(self.sync_document(document))
  if self.state.val != Ready || !self.capabilities.val.hover_provider {
    return None
  }
  let uri = document.uri.to_string()
  let id = self.next_request_id()
  self.register_request(id, "textDocument/hover", document)
  let response = self.transport.request(lsp_hover_request(id, document, offset))
  self.complete_request(id)
  if self.active_uri.val != uri || self.active_revision.val != document.revision {
    return None
  }
  match parse_response_result(response) {
    ParsedLspResult(result) => parse_hover_result(result, document, offset)
    LspResponseError(message) => {
      self.last_error.val = message
      None
    }
  }
}

///|
/// Requests definition data at a UTF-16 document offset when supported.
pub async fn LspClient::definition_at(
  self : LspClient,
  document : @workspace.DocumentSnapshot,
  offset : Int,
) -> @language.Location? {
  ignore(self.sync_document(document))
  if self.state.val != Ready || !self.capabilities.val.definition_provider {
    return None
  }
  let uri = document.uri.to_string()
  let id = self.next_request_id()
  self.register_request(id, "textDocument/definition", document)
  let response = self.transport.request(
    lsp_definition_request(id, document, offset),
  )
  self.complete_request(id)
  if self.active_uri.val != uri || self.active_revision.val != document.revision {
    return None
  }
  match parse_response_result(response) {
    ParsedLspResult(result) => parse_definition_result(result, document)
    LspResponseError(message) => {
      self.last_error.val = message
      None
    }
  }
}

///|
/// Requests references at a UTF-16 document offset when supported.
pub async fn LspClient::references_at(
  self : LspClient,
  document : @workspace.DocumentSnapshot,
  offset : Int,
) -> Array[@language.Location] {
  ignore(self.sync_document(document))
  if self.state.val != Ready || !self.capabilities.val.references_provider {
    return []
  }
  let uri = document.uri.to_string()
  let id = self.next_request_id()
  self.register_request(id, "textDocument/references", document)
  let response = self.transport.request(
    lsp_references_request(id, document, offset),
  )
  self.complete_request(id)
  if self.active_uri.val != uri || self.active_revision.val != document.revision {
    return []
  }
  match parse_response_result(response) {
    ParsedLspResult(result) => parse_references_result(result, document)
    LspResponseError(message) => {
      self.last_error.val = message
      []
    }
  }
}

///|
/// Requests document symbols when supported.
pub async fn LspClient::document_symbols(
  self : LspClient,
  document : @workspace.DocumentSnapshot,
) -> Array[@language.DocumentSymbol] {
  ignore(self.sync_document(document))
  if self.state.val != Ready || !self.capabilities.val.document_symbol_provider {
    return []
  }
  let uri = document.uri.to_string()
  let id = self.next_request_id()
  self.register_request(id, "textDocument/documentSymbol", document)
  let response = self.transport.request(
    lsp_document_symbol_request(id, document),
  )
  self.complete_request(id)
  if self.active_uri.val != uri || self.active_revision.val != document.revision {
    return []
  }
  match parse_response_result(response) {
    ParsedLspResult(result) => parse_document_symbols_result(result, document)
    LspResponseError(message) => {
      self.last_error.val = message
      []
    }
  }
}

///|
/// Sends shutdown/exit and clears the server-message subscription.
pub async fn LspClient::shutdown(self : LspClient) -> Unit {
  if self.state.val == Stopped || self.state.val == Stopping {
    return
  }
  self.state.val = Stopping
  if self.subscribed.val {
    match self.subscription.val {
      Some(subscription) => subscription.dispose()
      None => ()
    }
    self.subscription.val = None
    self.subscribed.val = false
  }
  let id = self.next_request_id()
  self.pending_requests.set(id, {
    method_name: "shutdown",
    uri: "",
    revision: "",
  })
  ignore(self.transport.request(request_message(id, "shutdown", Json::null())))
  self.complete_request(id)
  self.transport.notify(notification_message("exit", Json::null()))
  self.state.val = Stopped
}

///|
/// Builds an initialize JSON-RPC request without a root URI.
pub fn lsp_initialize_request(id : Int) -> String {
  lsp_initialize_request_with_root(id, Json::null())
}

///|
fn lsp_initialize_request_with_root(id : Int, root_uri : Json) -> String {
  request_message(
    id,
    "initialize",
    json_object([
      ("processId", Json::null()),
      ("clientInfo", json_object([("name", Json::string("readonly-editor"))])),
      ("rootUri", root_uri),
      (
        "capabilities",
        json_object([
          (
            "textDocument",
            json_object([
              (
                "publishDiagnostics",
                json_object([("versionSupport", Json::boolean(true))]),
              ),
              (
                "hover",
                json_object([("dynamicRegistration", Json::boolean(false))]),
              ),
              (
                "definition",
                json_object([("dynamicRegistration", Json::boolean(false))]),
              ),
              (
                "documentSymbol",
                json_object([
                  ("dynamicRegistration", Json::boolean(false)),
                  ("hierarchicalDocumentSymbolSupport", Json::boolean(true)),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ]),
  )
}

///|
/// Builds a hover JSON-RPC request at a core UTF-16 offset.
pub fn lsp_hover_request(
  id : Int,
  document : @workspace.DocumentSnapshot,
  offset : Int,
) -> String {
  let position = document.position_at_offset(offset)
  request_message(
    id,
    "textDocument/hover",
    json_object([
      ("textDocument", text_document_identifier(document.uri)),
      ("position", lsp_position_json(position)),
    ]),
  )
}

///|
/// Builds a definition JSON-RPC request at a core UTF-16 offset.
pub fn lsp_definition_request(
  id : Int,
  document : @workspace.DocumentSnapshot,
  offset : Int,
) -> String {
  let position = document.position_at_offset(offset)
  request_message(
    id,
    "textDocument/definition",
    json_object([
      ("textDocument", text_document_identifier(document.uri)),
      ("position", lsp_position_json(position)),
    ]),
  )
}

///|
/// Builds a references JSON-RPC request at a core UTF-16 offset.
pub fn lsp_references_request(
  id : Int,
  document : @workspace.DocumentSnapshot,
  offset : Int,
) -> String {
  let position = document.position_at_offset(offset)
  request_message(
    id,
    "textDocument/references",
    json_object([
      ("textDocument", text_document_identifier(document.uri)),
      ("position", lsp_position_json(position)),
      ("context", json_object([("includeDeclaration", Json::boolean(true))])),
    ]),
  )
}

///|
/// Builds a document-symbol JSON-RPC request.
pub fn lsp_document_symbol_request(
  id : Int,
  document : @workspace.DocumentSnapshot,
) -> String {
  request_message(
    id,
    "textDocument/documentSymbol",
    json_object([("textDocument", text_document_identifier(document.uri))]),
  )
}

///|
fn LspClient::ensure_subscribed(self : LspClient) -> Unit {
  if !self.subscribed.val {
    let subscription = self.transport.subscribe(message => {
      self.handle_message(message)
    })
    self.subscription.val = Some(subscription)
    self.subscribed.val = true
  }
}

///|
async fn LspClient::ensure_initialized(
  self : LspClient,
  document : @workspace.DocumentSnapshot,
) -> Bool {
  if self.state.val == Ready {
    return true
  }
  if self.state.val == Initializing ||
    self.state.val == Stopping ||
    self.state.val == Stopped {
    return false
  }
  self.state.val = Initializing
  let id = self.next_request_id()
  self.register_request(id, "initialize", document)
  let root_uri = if self.root_uri == "" {
    lsp_root_uri(document.uri)
  } else {
    Json::string(self.root_uri)
  }
  let response = self.transport.request(
    lsp_initialize_request_with_root(id, root_uri),
  )
  self.complete_request(id)
  match parse_response_result(response) {
    ParsedLspResult(result) => {
      self.capabilities.val = parse_server_capabilities(result)
      self.state.val = Ready
      self.last_error.val = ""
      self.transport.notify(
        notification_message("initialized", json_object([])),
      )
      true
    }
    LspResponseError(message) => {
      self.last_error.val = message
      self.state.val = Failed
      false
    }
  }
}

///|
fn lsp_root_uri(uri : @base_common.Uri) -> Json {
  let raw = uri.to_string()
  if raw.has_prefix("file:///") {
    let mut last_slash = -1
    for i in 0..<raw.length() {
      if raw[i].to_int() == 47 {
        last_slash = i
      }
    }
    if last_slash > "file://".length() {
      return Json::string(raw[0:last_slash].to_owned())
    }
  }
  Json::null()
}

///|
async fn LspClient::sync_active_document(
  self : LspClient,
  document : @workspace.DocumentSnapshot,
) -> Unit {
  let uri = document.uri.to_string()
  let previous_uri = self.active_uri.val
  let previous_revision = self.active_revision.val
  let lsp_version = if previous_uri == "" || previous_uri != uri {
    1
  } else if previous_revision != document.revision {
    self.active_version.val + 1
  } else {
    self.active_version.val
  }
  self.active_snapshot.val = Some(document)
  self.active_uri.val = uri
  self.active_revision.val = document.revision
  self.active_version.val = lsp_version
  if previous_uri == "" {
    self.transport.notify(did_open_notification(document, lsp_version))
  } else if previous_uri != uri {
    self.transport.notify(did_close_notification(previous_uri))
    self.transport.notify(did_open_notification(document, lsp_version))
  } else if previous_revision != document.revision {
    self.transport.notify(did_change_notification(document, lsp_version))
  }
}

///|
fn LspClient::cached_diagnostics_for_document(
  self : LspClient,
  document : @workspace.DocumentSnapshot,
) -> Array[@language.Diagnostic] {
  if self.active_uri.val != document.uri.to_string() ||
    self.active_revision.val != document.revision {
    return []
  }
  match self.diagnostics.get(document.uri.to_string()) {
    Some(cached) =>
      if cached.version == -1 || cached.version == self.active_version.val {
        cached.diagnostics
      } else {
        []
      }
    None => []
  }
}

///|
impl @language.DiagnosticsProvider for LspLanguageProvider with fn provide_diagnostics(
  self,
  model,
  _token,
) {
  let document = document_from_text_model(model)
  self.client.sync_document(document).diagnostics
}

///|
impl @language.HoverProvider for LspLanguageProvider with fn provide_hover(
  self,
  model,
  position,
  _token,
) {
  let document = document_from_text_model(model)
  let offset = model.snapshot.offset_at_position(position)
  self.client.hover_at(document, offset)
}

///|
impl @language.DefinitionProvider for LspLanguageProvider with fn provide_definition(
  self,
  model,
  position,
  _token,
) {
  let document = document_from_text_model(model)
  let offset = model.snapshot.offset_at_position(position)
  self.client.definition_at(document, offset)
}

///|
impl @language.ReferencesProvider for LspLanguageProvider with fn provide_references(
  self,
  model,
  position,
  _token,
) {
  let document = document_from_text_model(model)
  let offset = model.snapshot.offset_at_position(position)
  self.client.references_at(document, offset)
}

///|
impl @language.DocumentSymbolProvider for LspLanguageProvider with fn provide_document_symbols(
  self,
  model,
  _token,
) {
  let document = document_from_text_model(model)
  self.client.document_symbols(document)
}

///|
fn LspClient::next_request_id(self : LspClient) -> Int {
  self.next_id.val = self.next_id.val + 1
  self.next_id.val
}

///|
fn LspClient::register_request(
  self : LspClient,
  id : Int,
  method_name : String,
  document : @workspace.DocumentSnapshot,
) -> Unit {
  self.pending_requests.set(id, {
    method_name,
    uri: document.uri.to_string(),
    revision: document.revision,
  })
}

///|
fn LspClient::complete_request(self : LspClient, id : Int) -> Unit {
  match self.pending_requests.get(id) {
    Some(request) => ignore(request.is_document_request())
    None => ()
  }
  self.pending_requests.remove(id)
}

///|
fn LspClient::handle_message(self : LspClient, raw : String) -> Unit {
  match parse_json(raw) {
    Some(message) =>
      match json_string_field(message, "method") {
        Some("textDocument/publishDiagnostics") =>
          if self.capabilities.val.publish_diagnostics {
            self.handle_publish_diagnostics(message)
          }
        _ => ()
      }
    None => self.last_error.val = "Invalid LSP message"
  }
}

///|
fn LspClient::handle_publish_diagnostics(
  self : LspClient,
  message : Json,
) -> Unit {
  match json_field(message, "params") {
    Some(params) =>
      match parse_publish_diagnostics(params, self.active_snapshot.val) {
        Some(parsed) =>
          if parsed.uri == self.active_uri.val {
            if parsed.version == -1 || parsed.version == self.active_version.val {
              self.diagnostics.set(parsed.uri, {
                version: parsed.version,
                diagnostics: parsed.diagnostics,
              })
              match self.diagnostics_listener.val {
                Some(listener) => listener(parsed.uri, parsed.version)
                None => ()
              }
            }
          }
        None => ()
      }
    None => ()
  }
}

///|
priv struct ParsedDiagnostics {
  uri : String
  version : Int
  diagnostics : Array[@language.Diagnostic]
}

///|
fn parse_publish_diagnostics(
  params : Json,
  snapshot : @workspace.DocumentSnapshot?,
) -> ParsedDiagnostics? {
  match snapshot {
    Some(_) => {
      let uri = json_string_field(params, "uri").unwrap_or("")
      if uri == "" {
        return None
      }
      let version = json_int_field(params, "version").unwrap_or(-1)
      let diagnostics = []
      match json_field(params, "diagnostics") {
        Some(Array(items)) =>
          for item in items {
            match parse_diagnostic(item) {
              Some(diagnostic) => diagnostics.push(diagnostic)
              None => ()
            }
          }
        _ => ()
      }
      Some({ uri, version, diagnostics })
    }
    None => None
  }
}

///|
fn parse_diagnostic(item : Json) -> @language.Diagnostic? {
  match json_field(item, "range") {
    Some(range_json) =>
      match parse_lsp_range(range_json) {
        Some(range) =>
          Some({
            range,
            severity: diagnostic_severity(json_int_field(item, "severity")),
            message: json_string_field(item, "message").unwrap_or(""),
            tags: parse_diagnostic_tags(item),
          })
        None => None
      }
    None => None
  }
}

///|
/// LSP `DiagnosticSeverity`: `1=Error, 2=Warning, 3=Information, 4=Hint`.
/// Missing/unrecognized values default to `Info`, matching prior behavior.
fn diagnostic_severity(value : Int?) -> @language.DiagnosticSeverity {
  match value {
    Some(1) => Error
    Some(2) => Warning
    Some(4) => Hint
    _ => Info
  }
}

///|
/// LSP `DiagnosticTag`: `1=Unnecessary, 2=Deprecated` (`item.tags: int[]`).
fn parse_diagnostic_tags(item : Json) -> Array[@language.DiagnosticTag]? {
  match json_field(item, "tags") {
    Some(Array(items)) => {
      let tags : Array[@language.DiagnosticTag] = []
      for tag in items {
        match json_int_value(tag) {
          Some(1) => tags.push(Unnecessary)
          Some(2) => tags.push(Deprecated)
          _ => ()
        }
      }
      if tags.is_empty() {
        None
      } else {
        Some(tags)
      }
    }
    _ => None
  }
}

///|
fn parse_hover_result(
  result : Json,
  doc : @workspace.DocumentSnapshot,
  offset : Int,
) -> @language.Hover? {
  match result {
    Null => None
    Object(_) =>
      match json_field(result, "contents") {
        Some(contents_json) => {
          let contents = hover_contents(contents_json)
          if contents.length() == 0 {
            None
          } else {
            let range = match json_field(result, "range") {
              Some(range_json) =>
                match parse_lsp_range(range_json) {
                  Some(range) => range
                  None => fallback_hover_range(doc, offset)
                }
              None => fallback_hover_range(doc, offset)
            }
            Some({ range, contents })
          }
        }
        None => None
      }
    _ => None
  }
}

///|
fn hover_contents(value : Json) -> Array[@language.HoverContent] {
  match value {
    String(text) => hover_plaintext(text)
    Object(_) => hover_object_contents(value)
    Array(items) => {
      let out : Array[@language.HoverContent] = []
      for item in items {
        for content in hover_contents(item) {
          out.push(content)
        }
      }
      out
    }
    _ => []
  }
}

///|
fn hover_object_contents(value : Json) -> Array[@language.HoverContent] {
  let text = match json_string_field(value, "value") {
    Some(text) => text
    None => return []
  }
  match json_string_field(value, "kind") {
    Some("markdown") => hover_markdown(text)
    Some("plaintext") => hover_plaintext(text)
    _ =>
      match json_string_field(value, "language") {
        Some(language) => hover_markdown(fenced_marked_string(language, text))
        None => hover_plaintext(text)
      }
  }
}

///|
fn hover_plaintext(text : String) -> Array[@language.HoverContent] {
  if text == "" {
    []
  } else {
    [PlainText(text)]
  }
}

///|
fn hover_markdown(text : String) -> Array[@language.HoverContent] {
  if text == "" {
    []
  } else {
    [Markdown(text)]
  }
}

///|
fn fenced_marked_string(language : String, value : String) -> String {
  "```" + language + "\n" + value + "\n```"
}

///|
fn fallback_hover_range(
  doc : @workspace.DocumentSnapshot,
  offset : Int,
) -> @base_common.Range {
  let start = @base_common.clamp_int(offset, 0, doc.length())
  let end = @base_common.clamp_int(start + 1, start, doc.length())
  @base_common.Range::from_positions(
    doc.position_at_offset(start),
    doc.position_at_offset(end),
  )
}

///|
fn parse_definition_result(
  result : Json,
  document : @workspace.DocumentSnapshot,
) -> @language.Location? {
  match result {
    Null => None
    Object(_) => parse_location_result(result, document)
    Array(items) => {
      let mut found : @language.Location? = None
      for item in items {
        if found is None {
          found = parse_location_result(item, document)
        }
      }
      found
    }
    _ => None
  }
}

///|
fn parse_references_result(
  result : Json,
  document : @workspace.DocumentSnapshot,
) -> Array[@language.Location] {
  let locations : Array[@language.Location] = []
  match result {
    Array(items) =>
      for item in items {
        match parse_location_result(item, document) {
          Some(location) => locations.push(location)
          None => ()
        }
      }
    _ => ()
  }
  locations
}

///|
fn parse_document_symbols_result(
  result : Json,
  document : @workspace.DocumentSnapshot,
) -> Array[@language.DocumentSymbol] {
  let symbols : Array[@language.DocumentSymbol] = []
  match result {
    Array(items) =>
      for item in items {
        append_document_symbol(item, document, symbols)
      }
    _ => ()
  }
  symbols
}

///|
fn append_document_symbol(
  value : Json,
  document : @workspace.DocumentSnapshot,
  out : Array[@language.DocumentSymbol],
) -> Unit {
  match value {
    Object(_) => {
      let name = json_string_field(value, "name").unwrap_or("")
      let kind = document_symbol_kind(json_int_field(value, "kind"))
      let range = document_symbol_range(value, document)
      if name != "" {
        out.push({ name, kind, range })
      }
      match json_field(value, "children") {
        Some(Array(children)) =>
          for child in children {
            append_document_symbol(child, document, out)
          }
        _ => ()
      }
    }
    _ => ()
  }
}

///|
fn document_symbol_range(
  value : Json,
  document : @workspace.DocumentSnapshot,
) -> @base_common.Range {
  let range_json = match json_field(value, "range") {
    Some(range) => Some(range)
    None =>
      match json_field(value, "selectionRange") {
        Some(range) => Some(range)
        None =>
          match json_field(value, "location") {
            Some(location) =>
              if location_uri_matches_document(location, document) {
                json_field(location, "range")
              } else {
                None
              }
            None => None
          }
      }
  }
  match range_json {
    Some(range) => parse_lsp_range(range).unwrap_or(Range(1, 1, 1, 1))
    None => Range(1, 1, 1, 1)
  }
}

///|
fn location_uri_matches_document(
  location : Json,
  document : @workspace.DocumentSnapshot,
) -> Bool {
  json_string_field(location, "uri").unwrap_or(document.uri.to_string()) ==
  document.uri.to_string()
}

///|
fn document_symbol_kind(kind : Int?) -> String {
  match kind {
    Some(2) => "module"
    Some(3) => "namespace"
    Some(4) => "package"
    Some(5) => "class"
    Some(6) => "method"
    Some(7) => "property"
    Some(8) => "field"
    Some(9) => "constructor"
    Some(10) => "enum"
    Some(11) => "interface"
    Some(12) => "function"
    Some(13) => "variable"
    Some(14) => "constant"
    Some(15) => "string"
    Some(16) => "number"
    Some(17) => "boolean"
    Some(18) => "array"
    Some(19) => "object"
    Some(20) => "key"
    Some(21) => "null"
    Some(22) => "enumMember"
    Some(23) => "struct"
    Some(24) => "event"
    Some(25) => "operator"
    Some(26) => "typeParameter"
    _ => "unknown"
  }
}

///|
fn parse_location_result(
  value : Json,
  document : @workspace.DocumentSnapshot,
) -> @language.Location? {
  match value {
    Object(_) => {
      let uri = match json_string_field(value, "uri") {
        Some(raw) => raw
        None => json_string_field(value, "targetUri").unwrap_or("")
      }
      if uri == "" {
        return None
      }
      let range_json = match json_field(value, "range") {
        Some(range) => Some(range)
        None =>
          match json_field(value, "targetSelectionRange") {
            Some(range) => Some(range)
            None => json_field(value, "targetRange")
          }
      }
      let parsed_uri = match @base_common.Uri::parse(uri) {
        ParsedUri(parsed) => parsed
        UriError(_) => return None
      }
      let range = if uri == document.uri.to_string() {
        match range_json {
          Some(raw_range) =>
            parse_lsp_range(raw_range).unwrap_or(Range(1, 1, 1, 1))
          None => Range(1, 1, 1, 1)
        }
      } else {
        Range(1, 1, 1, 1)
      }
      Some({ uri: parsed_uri, range })
    }
    _ => None
  }
}

///|
/// Parses an LSP range into a line/column `Range`, keeping Monaco's coordinate
/// space (no offset round-trip): `parse_lsp_position` already returns a 1-based
/// `Position`.
fn parse_lsp_range(value : Json) -> @base_common.Range? {
  match (json_field(value, "start"), json_field(value, "end")) {
    (Some(start), Some(end)) =>
      match (parse_lsp_position(start), parse_lsp_position(end)) {
        (Some(start_position), Some(end_position)) =>
          Some(@base_common.Range::from_positions(start_position, end_position))
        _ => None
      }
    _ => None
  }
}

///|
fn parse_lsp_position(value : Json) -> @base_common.Position? {
  // LSP positions are 0-based (line/character); `Position` is 1-based, so this
  // wire boundary adds +1 on both axes.
  match (json_int_field(value, "line"), json_int_field(value, "character")) {
    (Some(line), Some(column)) => Some(Position(line + 1, column + 1))
    _ => None
  }
}

///|
priv enum LspParsedResult {
  ParsedLspResult(Json)
  LspResponseError(String)
}

///|
fn parse_response_result(raw : String) -> LspParsedResult {
  match parse_json(raw) {
    Some(message) =>
      match json_field(message, "error") {
        Some(error) =>
          LspResponseError(
            json_string_field(error, "message").unwrap_or("LSP request failed"),
          )
        None =>
          match json_field(message, "result") {
            Some(result) => ParsedLspResult(result)
            None => LspResponseError("LSP response missing result")
          }
      }
    None => LspResponseError("Invalid LSP response")
  }
}

///|
fn parse_server_capabilities(result : Json) -> LspServerCapabilities {
  match json_field(result, "capabilities") {
    Some(capabilities) =>
      {
        hover_provider: capability_enabled(capabilities, "hoverProvider"),
        definition_provider: capability_enabled(
          capabilities, "definitionProvider",
        ),
        references_provider: capability_enabled(
          capabilities, "referencesProvider",
        ),
        document_symbol_provider: capability_enabled(
          capabilities, "documentSymbolProvider",
        ),
        publish_diagnostics: true,
      }
    None => default_lsp_capabilities()
  }
}

///|
fn capability_enabled(capabilities : Json, name : String) -> Bool {
  match json_field(capabilities, name) {
    Some(True) => true
    Some(False) => false
    Some(Object(_)) => true
    _ => false
  }
}

///|
fn request_message(id : Int, method_name : String, params : Json) -> String {
  json_object([
    ("jsonrpc", Json::string("2.0")),
    ("id", json_int(id)),
    ("method", Json::string(method_name)),
    ("params", params),
  ]).stringify()
}

///|
fn notification_message(method_name : String, params : Json) -> String {
  json_object([
    ("jsonrpc", Json::string("2.0")),
    ("method", Json::string(method_name)),
    ("params", params),
  ]).stringify()
}

///|
fn did_open_notification(
  document : @workspace.DocumentSnapshot,
  version : Int,
) -> String {
  notification_message(
    "textDocument/didOpen",
    json_object([("textDocument", text_document_item(document, version))]),
  )
}

///|
fn did_change_notification(
  document : @workspace.DocumentSnapshot,
  version : Int,
) -> String {
  notification_message(
    "textDocument/didChange",
    json_object([
      (
        "textDocument",
        versioned_text_document_identifier(document.uri, version),
      ),
      (
        "contentChanges",
        Json::array([json_object([("text", Json::string(document.text))])]),
      ),
    ]),
  )
}

///|
fn did_close_notification(uri : String) -> String {
  notification_message(
    "textDocument/didClose",
    json_object([("textDocument", json_object([("uri", Json::string(uri))]))]),
  )
}

///|
fn text_document_item(
  document : @workspace.DocumentSnapshot,
  version : Int,
) -> Json {
  json_object([
    ("uri", Json::string(document.uri.to_string())),
    ("languageId", Json::string(document.language_id)),
    ("version", json_int(version)),
    ("text", Json::string(document.text)),
  ])
}

///|
fn text_document_identifier(uri : @base_common.Uri) -> Json {
  json_object([("uri", Json::string(uri.to_string()))])
}

///|
fn versioned_text_document_identifier(
  uri : @base_common.Uri,
  version : Int,
) -> Json {
  json_object([
    ("uri", Json::string(uri.to_string())),
    ("version", json_int(version)),
  ])
}

///|
fn lsp_position_json(position : @base_common.Position) -> Json {
  // `Position` is 1-based; LSP positions are 0-based, so undo the +1.
  json_object([
    ("line", json_int(position.line_number - 1)),
    ("character", json_int(position.column - 1)),
  ])
}

///|
fn json_object(entries : Array[(String, Json)]) -> Json {
  Json::object(Map(entries))
}

///|
fn json_int(value : Int) -> Json {
  Json::number(Double::from_int(value), repr=value.to_string())
}

///|
fn parse_json(raw : String) -> Json? {
  Some(@json.parse(raw)) catch {
    _ => None
  }
}

///|
fn json_field(value : Json, key : String) -> Json? {
  match value {
    Object(fields) => fields.get(key)
    _ => None
  }
}

///|
fn json_string_field(value : Json, key : String) -> String? {
  match json_field(value, key) {
    Some(String(text)) => Some(text)
    _ => None
  }
}

///|
fn json_int_field(value : Json, key : String) -> Int? {
  match json_field(value, key) {
    Some(raw) => json_int_value(raw)
    _ => None
  }
}

///|
fn json_int_value(value : Json) -> Int? {
  match value {
    Number(number, repr=_) => Some(number.to_int())
    _ => None
  }
}
