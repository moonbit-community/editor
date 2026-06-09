///|
pub struct LspSubscription {
  priv dispose : () -> Unit
}

///|
pub fn LspSubscription::LspSubscription(
  dispose : () -> Unit,
) -> LspSubscription {
  { dispose, }
}

///|
pub fn LspSubscription::dispose(self : LspSubscription) -> Unit {
  (self.dispose)()
}

///|
pub(open) trait LspTransport {
  async fn request(Self, String) -> String
  async fn notify(Self, String) -> Unit
  fn subscribe(Self, (String) -> Unit) -> LspSubscription
}

///|
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
  document_symbol_provider : Bool
  semantic_tokens_provider : Bool
  semantic_token_types : Array[String]
  publish_diagnostics : Bool
}

///|
priv struct LspPendingRequest {
  method_name : String
  uri : String
  version : Int
}

///|
fn LspPendingRequest::is_document_request(self : LspPendingRequest) -> Bool {
  self.method_name != "" && self.uri != "" && self.version > 0
}

///|
pub struct LspClient {
  priv transport : &LspTransport
  priv next_id : Ref[Int]
  priv state : Ref[LspClientState]
  priv subscribed : Ref[Bool]
  priv subscription : Ref[LspSubscription?]
  priv active_uri : Ref[String]
  priv active_version : Ref[Int]
  priv active_snapshot : Ref[@core.DocumentSnapshot?]
  priv capabilities : Ref[LspServerCapabilities]
  priv pending_requests : Map[Int, LspPendingRequest]
  priv diagnostics : Map[String, LspCachedDiagnostics]
  priv diagnostics_listener : Ref[((String, Int) -> Unit)?]
  priv last_error : Ref[String]
}

///|
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
    document_symbol_provider: false,
    semantic_tokens_provider: false,
    semantic_token_types: [],
    publish_diagnostics: true,
  }
}

///|
pub fn LspClient::LspClient(transport : &LspTransport) -> LspClient {
  {
    transport,
    next_id: Ref(0),
    state: Ref(Idle),
    subscribed: Ref(false),
    subscription: Ref(None),
    active_uri: Ref(""),
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
pub fn LspClient::language_provider(self : LspClient) -> LspLanguageProvider {
  { client: self }
}

///|
pub fn LspLanguageProvider::as_hover_provider(
  self : LspLanguageProvider,
) -> &@language.HoverProvider {
  self
}

///|
pub fn LspLanguageProvider::as_definition_provider(
  self : LspLanguageProvider,
) -> &@language.DefinitionProvider {
  self
}

///|
pub fn LspLanguageProvider::as_diagnostics_provider(
  self : LspLanguageProvider,
) -> &@language.DiagnosticsProvider {
  self
}

///|
pub fn LspLanguageProvider::as_document_symbol_provider(
  self : LspLanguageProvider,
) -> &@language.DocumentSymbolProvider {
  self
}

///|
pub fn LspLanguageProvider::as_semantic_tokens_provider(
  self : LspLanguageProvider,
) -> &@language.SemanticTokensProvider {
  self
}

///|
pub fn LspClient::is_initialized(self : LspClient) -> Bool {
  self.state.val == Ready
}

///|
pub fn LspClient::state(self : LspClient) -> LspClientState {
  self.state.val
}

///|
pub fn LspClient::pending_request_count(self : LspClient) -> Int {
  self.pending_requests.length()
}

///|
pub fn LspClient::last_error(self : LspClient) -> String {
  self.last_error.val
}

///|
pub fn LspClient::clear_last_error(self : LspClient) -> Unit {
  self.last_error.val = ""
}

///|
pub fn LspClient::set_diagnostics_listener(
  self : LspClient,
  listener : ((String, Int) -> Unit)?,
) -> Unit {
  self.diagnostics_listener.val = listener
}

///|
pub async fn LspClient::sync_document(
  self : LspClient,
  document : @workspace.SourceDocument,
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
    semantic_tokens: [],
  }
}

///|
pub async fn LspClient::hover_at(
  self : LspClient,
  document : @workspace.SourceDocument,
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
  if self.active_uri.val != uri || self.active_version.val != document.version {
    return None
  }
  match parse_response_result(response) {
    ParsedLspResult(result) =>
      parse_hover_result(result, document.snapshot(), offset)
    LspResponseError(message) => {
      self.last_error.val = message
      None
    }
  }
}

///|
pub async fn LspClient::definition_at(
  self : LspClient,
  document : @workspace.SourceDocument,
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
  if self.active_uri.val != uri || self.active_version.val != document.version {
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
pub async fn LspClient::document_symbols(
  self : LspClient,
  document : @workspace.SourceDocument,
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
  if self.active_uri.val != uri || self.active_version.val != document.version {
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
pub async fn LspClient::semantic_tokens_for_document(
  self : LspClient,
  document : @workspace.SourceDocument,
) -> Array[@language.SemanticToken] {
  ignore(self.sync_document(document))
  if self.state.val != Ready || !self.capabilities.val.semantic_tokens_provider {
    return []
  }
  let uri = document.uri.to_string()
  let id = self.next_request_id()
  self.register_request(id, "textDocument/semanticTokens/full", document)
  let response = self.transport.request(
    lsp_semantic_tokens_full_request(id, document),
  )
  self.complete_request(id)
  if self.active_uri.val != uri || self.active_version.val != document.version {
    return []
  }
  match parse_response_result(response) {
    ParsedLspResult(result) =>
      parse_semantic_tokens_result(
        result,
        document.snapshot(),
        self.capabilities.val.semantic_token_types,
      )
    LspResponseError(message) => {
      self.last_error.val = message
      []
    }
  }
}

///|
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
  self.pending_requests.set(id, { method_name: "shutdown", uri: "", version: 0 })
  ignore(self.transport.request(request_message(id, "shutdown", Json::null())))
  self.complete_request(id)
  self.transport.notify(notification_message("exit", Json::null()))
  self.state.val = Stopped
}

///|
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
              (
                "semanticTokens",
                json_object([
                  ("dynamicRegistration", Json::boolean(false)),
                  (
                    "requests",
                    json_object([
                      ("range", Json::boolean(false)),
                      ("full", Json::boolean(true)),
                    ]),
                  ),
                  ("tokenTypes", semantic_token_type_capability()),
                  ("tokenModifiers", Json::array([])),
                  ("formats", Json::array([Json::string("relative")])),
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
fn semantic_token_type_capability() -> Json {
  Json::array([
    Json::string("namespace"),
    Json::string("type"),
    Json::string("class"),
    Json::string("enum"),
    Json::string("interface"),
    Json::string("struct"),
    Json::string("typeParameter"),
    Json::string("parameter"),
    Json::string("variable"),
    Json::string("property"),
    Json::string("enumMember"),
    Json::string("event"),
    Json::string("function"),
    Json::string("method"),
    Json::string("macro"),
    Json::string("keyword"),
    Json::string("modifier"),
    Json::string("comment"),
    Json::string("string"),
    Json::string("number"),
    Json::string("regexp"),
    Json::string("operator"),
  ])
}

///|
pub fn lsp_hover_request(
  id : Int,
  document : @workspace.SourceDocument,
  offset : Int,
) -> String {
  let snapshot = document.snapshot()
  let position = snapshot.position_at_offset(offset)
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
pub fn lsp_definition_request(
  id : Int,
  document : @workspace.SourceDocument,
  offset : Int,
) -> String {
  let snapshot = document.snapshot()
  let position = snapshot.position_at_offset(offset)
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
pub fn lsp_document_symbol_request(
  id : Int,
  document : @workspace.SourceDocument,
) -> String {
  request_message(
    id,
    "textDocument/documentSymbol",
    json_object([("textDocument", text_document_identifier(document.uri))]),
  )
}

///|
pub fn lsp_semantic_tokens_full_request(
  id : Int,
  document : @workspace.SourceDocument,
) -> String {
  request_message(
    id,
    "textDocument/semanticTokens/full",
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
  document : @workspace.SourceDocument,
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
  let response = self.transport.request(
    lsp_initialize_request_with_root(id, lsp_root_uri(document.uri)),
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
fn lsp_root_uri(uri : @workspace.DocumentUri) -> Json {
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
  document : @workspace.SourceDocument,
) -> Unit {
  let uri = document.uri.to_string()
  let previous_uri = self.active_uri.val
  let previous_version = self.active_version.val
  self.active_snapshot.val = Some(document.snapshot())
  self.active_uri.val = uri
  self.active_version.val = document.version
  if previous_uri == "" {
    self.transport.notify(did_open_notification(document))
  } else if previous_uri != uri {
    self.transport.notify(did_close_notification(previous_uri))
    self.transport.notify(did_open_notification(document))
  } else if previous_version != document.version {
    self.transport.notify(did_change_notification(document))
  }
}

///|
fn LspClient::cached_diagnostics_for_document(
  self : LspClient,
  document : @workspace.SourceDocument,
) -> Array[@language.Diagnostic] {
  match self.diagnostics.get(document.uri.to_string()) {
    Some(cached) =>
      if cached.version == -1 || cached.version == document.version {
        cached.diagnostics
      } else {
        []
      }
    None => []
  }
}

///|
impl @language.DiagnosticsProvider for LspLanguageProvider with fn diagnostics_for_document(
  self,
  document,
) {
  self.client.sync_document(document).diagnostics
}

///|
impl @language.HoverProvider for LspLanguageProvider with fn hover_at(
  self,
  document,
  offset,
) {
  self.client.hover_at(document, offset)
}

///|
impl @language.DefinitionProvider for LspLanguageProvider with fn definition_at(
  self,
  document,
  offset,
) {
  self.client.definition_at(document, offset)
}

///|
impl @language.DocumentSymbolProvider for LspLanguageProvider with fn document_symbols(
  self,
  document,
) {
  self.client.document_symbols(document)
}

///|
impl @language.SemanticTokensProvider for LspLanguageProvider with fn semantic_tokens_for_document(
  self,
  document,
) {
  self.client.semantic_tokens_for_document(document)
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
  document : @workspace.SourceDocument,
) -> Unit {
  self.pending_requests.set(id, {
    method_name,
    uri: document.uri.to_string(),
    version: document.version,
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
  snapshot : @core.DocumentSnapshot?,
) -> ParsedDiagnostics? {
  match snapshot {
    Some(doc) => {
      let uri = json_string_field(params, "uri").unwrap_or("")
      if uri == "" {
        return None
      }
      let version = json_int_field(params, "version").unwrap_or(-1)
      let diagnostics = []
      match json_field(params, "diagnostics") {
        Some(Array(items)) =>
          for item in items {
            match parse_diagnostic(item, doc) {
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
fn parse_diagnostic(
  item : Json,
  doc : @core.DocumentSnapshot,
) -> @language.Diagnostic? {
  match json_field(item, "range") {
    Some(range_json) =>
      match parse_lsp_range(range_json, doc) {
        Some(range) =>
          Some({
            range,
            severity: diagnostic_severity(json_int_field(item, "severity")),
            message: json_string_field(item, "message").unwrap_or(""),
          })
        None => None
      }
    None => None
  }
}

///|
fn diagnostic_severity(value : Int?) -> @language.DiagnosticSeverity {
  match value {
    Some(1) => Error
    Some(2) => Warning
    _ => Info
  }
}

///|
fn parse_hover_result(
  result : Json,
  doc : @core.DocumentSnapshot,
  offset : Int,
) -> @language.Hover? {
  match result {
    Null => None
    Object(_) =>
      match json_field(result, "contents") {
        Some(contents_json) => {
          let contents = hover_contents_text(contents_json)
          if contents == "" {
            None
          } else {
            let range = match json_field(result, "range") {
              Some(range_json) =>
                match parse_lsp_range(range_json, doc) {
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
fn hover_contents_text(value : Json) -> String {
  match value {
    String(text) => text
    Object(_) =>
      match json_string_field(value, "value") {
        Some(text) => text
        None => ""
      }
    Array(items) => {
      let mut out = ""
      for item in items {
        let text = hover_contents_text(item)
        if text != "" {
          if out != "" {
            out = out + "\n"
          }
          out = out + text
        }
      }
      out
    }
    _ => ""
  }
}

///|
fn fallback_hover_range(
  doc : @core.DocumentSnapshot,
  offset : Int,
) -> @core.Range {
  let start = @core.clamp_int(offset, 0, doc.length())
  let end = @core.clamp_int(start + 1, start, doc.length())
  Range(start, end)
}

///|
fn parse_definition_result(
  result : Json,
  document : @workspace.SourceDocument,
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
fn parse_document_symbols_result(
  result : Json,
  document : @workspace.SourceDocument,
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
  document : @workspace.SourceDocument,
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
  document : @workspace.SourceDocument,
) -> @core.Range {
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
    Some(range) =>
      parse_lsp_range(range, document.snapshot()).unwrap_or(Range(0, 0))
    None => Range(0, 0)
  }
}

///|
fn location_uri_matches_document(
  location : Json,
  document : @workspace.SourceDocument,
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
fn parse_semantic_tokens_result(
  result : Json,
  doc : @core.DocumentSnapshot,
  legend : Array[String],
) -> Array[@language.SemanticToken] {
  let tokens : Array[@language.SemanticToken] = []
  match json_field(result, "data") {
    Some(Array(data)) => {
      let mut line = 0
      let mut start_character = 0
      let mut index = 0
      while index + 4 < data.length() {
        match
          (
            json_int_value(data[index]),
            json_int_value(data[index + 1]),
            json_int_value(data[index + 2]),
            json_int_value(data[index + 3]),
          ) {
          (Some(delta_line), Some(delta_start), Some(length), Some(token_type)) => {
            if delta_line == 0 {
              start_character = start_character + delta_start
            } else {
              line = line + delta_line
              start_character = delta_start
            }
            if length > 0 {
              let start = doc.offset_at_position(
                Position(line, start_character),
              )
              let end = doc.offset_at_position(
                Position(line, start_character + length),
              )
              tokens.push({
                range: Range(start, end),
                token_type: semantic_token_type_name(legend, token_type),
              })
            }
          }
          _ => ()
        }
        index = index + 5
      }
    }
    _ => ()
  }
  tokens
}

///|
fn semantic_token_type_name(legend : Array[String], index : Int) -> String {
  if index >= 0 && index < legend.length() {
    legend[index]
  } else {
    "unknown"
  }
}

///|
fn parse_location_result(
  value : Json,
  document : @workspace.SourceDocument,
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
      let parsed_uri = match @workspace.DocumentUri::parse(uri) {
        ParsedDocumentUri(parsed) => parsed
        DocumentUriError(_) => return None
      }
      let range = if uri == document.uri.to_string() {
        match range_json {
          Some(raw_range) =>
            parse_lsp_range(raw_range, document.snapshot()).unwrap_or(
              Range(0, 0),
            )
          None => Range(0, 0)
        }
      } else {
        Range(0, 0)
      }
      Some({ uri: parsed_uri, range })
    }
    _ => None
  }
}

///|
fn parse_lsp_range(value : Json, doc : @core.DocumentSnapshot) -> @core.Range? {
  match (json_field(value, "start"), json_field(value, "end")) {
    (Some(start), Some(end)) =>
      match (parse_lsp_position(start), parse_lsp_position(end)) {
        (Some(start_position), Some(end_position)) =>
          Some(
            Range(
              doc.offset_at_position(start_position),
              doc.offset_at_position(end_position),
            ),
          )
        _ => None
      }
    _ => None
  }
}

///|
fn parse_lsp_position(value : Json) -> @core.Position? {
  match (json_int_field(value, "line"), json_int_field(value, "character")) {
    (Some(line), Some(column)) => Some(Position(line, column))
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
        document_symbol_provider: capability_enabled(
          capabilities, "documentSymbolProvider",
        ),
        semantic_tokens_provider: capability_enabled(
          capabilities, "semanticTokensProvider",
        ),
        semantic_token_types: semantic_token_legend(capabilities),
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
fn semantic_token_legend(capabilities : Json) -> Array[String] {
  let token_types = []
  match json_field(capabilities, "semanticTokensProvider") {
    Some(provider) =>
      match json_field(provider, "legend") {
        Some(legend) =>
          match json_field(legend, "tokenTypes") {
            Some(Array(items)) =>
              for item in items {
                match item {
                  String(token_type) => token_types.push(token_type)
                  _ => ()
                }
              }
            _ => ()
          }
        None => ()
      }
    None => ()
  }
  token_types
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
fn did_open_notification(document : @workspace.SourceDocument) -> String {
  notification_message(
    "textDocument/didOpen",
    json_object([("textDocument", text_document_item(document))]),
  )
}

///|
fn did_change_notification(document : @workspace.SourceDocument) -> String {
  notification_message(
    "textDocument/didChange",
    json_object([
      (
        "textDocument",
        versioned_text_document_identifier(document.uri, document.version),
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
fn text_document_item(document : @workspace.SourceDocument) -> Json {
  json_object([
    ("uri", Json::string(document.uri.to_string())),
    ("languageId", Json::string(document.language_id)),
    ("version", json_int(document.version)),
    ("text", Json::string(document.text)),
  ])
}

///|
fn text_document_identifier(uri : @workspace.DocumentUri) -> Json {
  json_object([("uri", Json::string(uri.to_string()))])
}

///|
fn versioned_text_document_identifier(
  uri : @workspace.DocumentUri,
  version : Int,
) -> Json {
  json_object([
    ("uri", Json::string(uri.to_string())),
    ("version", json_int(version)),
  ])
}

///|
fn lsp_position_json(position : @core.Position) -> Json {
  json_object([
    ("line", json_int(position.line)),
    ("character", json_int(position.column)),
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
