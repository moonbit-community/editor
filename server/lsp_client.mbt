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
pub struct LspClient {
  priv transport : &LspTransport
  priv next_id : Ref[Int]
  priv initialized : Ref[Bool]
  priv subscribed : Ref[Bool]
  priv subscription : Ref[LspSubscription?]
  priv active_uri : Ref[String]
  priv active_version : Ref[Int]
  priv active_snapshot : Ref[@core.DocumentSnapshot?]
  priv diagnostics : Map[String, LspCachedDiagnostics]
  priv diagnostics_listener : Ref[((String, Int) -> Unit)?]
  priv last_error : Ref[String]
}

///|
priv struct LspCachedDiagnostics {
  version : Int
  diagnostics : Array[@language.Diagnostic]
}

///|
pub fn LspClient::LspClient(transport : &LspTransport) -> LspClient {
  {
    transport,
    next_id: Ref(0),
    initialized: Ref(false),
    subscribed: Ref(false),
    subscription: Ref(None),
    active_uri: Ref(""),
    active_version: Ref(0),
    active_snapshot: Ref(None),
    diagnostics: Map::default(),
    diagnostics_listener: Ref(None),
    last_error: Ref(""),
  }
}

///|
pub fn LspClient::is_initialized(self : LspClient) -> Bool {
  self.initialized.val
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
    diagnostics: self.diagnostics_for_document(document),
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
  if !self.initialized.val {
    return None
  }
  let uri = document.uri.to_string()
  let id = self.next_request_id()
  let response = self.transport.request(lsp_hover_request(id, document, offset))
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
  if !self.initialized.val {
    return None
  }
  let uri = document.uri.to_string()
  let id = self.next_request_id()
  let response = self.transport.request(
    lsp_definition_request(id, document, offset),
  )
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
            ]),
          ),
        ]),
      ),
    ]),
  )
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
  if self.initialized.val {
    return true
  }
  let id = self.next_request_id()
  let response = self.transport.request(
    lsp_initialize_request_with_root(id, lsp_root_uri(document.uri)),
  )
  match parse_response_result(response) {
    ParsedLspResult(_) => {
      self.initialized.val = true
      self.last_error.val = ""
      self.transport.notify(
        notification_message("initialized", json_object([])),
      )
      true
    }
    LspResponseError(message) => {
      self.last_error.val = message
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
fn LspClient::diagnostics_for_document(
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
fn LspClient::next_request_id(self : LspClient) -> Int {
  self.next_id.val = self.next_id.val + 1
  self.next_id.val
}

///|
fn LspClient::handle_message(self : LspClient, raw : String) -> Unit {
  match parse_json(raw) {
    Some(message) =>
      match json_string_field(message, "method") {
        Some("textDocument/publishDiagnostics") =>
          self.handle_publish_diagnostics(message)
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
    Some(Number(number, repr=_)) => Some(number.to_int())
    _ => None
  }
}
