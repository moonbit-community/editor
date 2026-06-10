///|
pub fn protocol_version() -> Int {
  1
}

///|
pub(all) enum ProtocolErrorCode {
  ProtocolInvalidJson
  ProtocolUnsupportedVersion
  ProtocolUnknownPacket
  ProtocolInvalidPacket
  ProtocolInvalidUri
  ProtocolProviderError
} derive(Eq, Debug)

///|
pub(all) struct ProtocolError {
  code : ProtocolErrorCode
  message : String
  request_id : String
  provider_code : String
} derive(Debug)

///|
pub(all) struct DocumentRequest {
  id : String
  uri : @workspace.DocumentUri
} derive(Debug)

///|
pub(all) struct WorkspaceListRequest {
  id : String
} derive(Debug)

///|
pub(all) struct WorkspaceEntry {
  path : String
  name : String
  kind : String
  depth : Int
} derive(Debug)

///|
pub(all) struct DocumentPositionRequest {
  id : String
  uri : @workspace.DocumentUri
  document_version : Int
  offset : Int
} derive(Debug)

///|
pub(all) struct DocumentVersionRequest {
  id : String
  uri : @workspace.DocumentUri
  document_version : Int
} derive(Debug)

///|
pub(all) enum ClientPacket {
  ListWorkspace(WorkspaceListRequest)
  OpenDocument(DocumentRequest)
  WatchDocument(DocumentRequest)
  CloseDocument(DocumentRequest)
  Diagnostics(DocumentVersionRequest)
  Hover(DocumentPositionRequest)
  Definition(DocumentPositionRequest)
  DocumentSymbols(DocumentVersionRequest)
  SemanticTokens(DocumentVersionRequest)
} derive(Debug)

///|
pub(all) struct DocumentPayload {
  id : String
  document : @workspace.SourceDocument
} derive(Debug)

///|
pub(all) struct WorkspaceListedPayload {
  id : String
  entries : Array[WorkspaceEntry]
} derive(Debug)

///|
pub(all) struct DiagnosticsPayload {
  id : String
  uri : @workspace.DocumentUri
  version : Int
  diagnostics : Array[@language.Diagnostic]
} derive(Debug)

///|
pub(all) struct HoverResultPayload {
  id : String
  uri : @workspace.DocumentUri
  version : Int
  hover : @language.Hover?
} derive(Debug)

///|
pub(all) struct DefinitionResultPayload {
  id : String
  uri : @workspace.DocumentUri
  version : Int
  location : @language.Location?
} derive(Debug)

///|
pub(all) struct DocumentSymbolsResultPayload {
  id : String
  uri : @workspace.DocumentUri
  version : Int
  symbols : Array[@language.DocumentSymbol]
} derive(Debug)

///|
pub(all) struct SemanticTokensResultPayload {
  id : String
  uri : @workspace.DocumentUri
  version : Int
  semantic_tokens : Array[@language.SemanticToken]
} derive(Debug)

///|
pub(all) enum ServerPacket {
  WorkspaceListed(WorkspaceListedPayload)
  DocumentLoaded(DocumentPayload)
  DocumentChanged(DocumentPayload)
  Diagnostics(DiagnosticsPayload)
  HoverResult(HoverResultPayload)
  DefinitionResult(DefinitionResultPayload)
  DocumentSymbolsResult(DocumentSymbolsResultPayload)
  SemanticTokensResult(SemanticTokensResultPayload)
  RemoteError(ProtocolError)
} derive(Debug)

///|
pub(all) enum ClientPacketDecodeResult {
  DecodedClientPacket(ClientPacket)
  ClientPacketDecodeError(ProtocolError)
} derive(Debug)

///|
pub(all) enum ServerPacketDecodeResult {
  DecodedServerPacket(ServerPacket)
  ServerPacketDecodeError(ProtocolError)
} derive(Debug)

///|
pub(all) enum ProtocolNegotiation {
  ProtocolAccepted(Int)
  ProtocolRejected(ProtocolError)
} derive(Debug)

///|
pub fn ProtocolError::ProtocolError(
  code : ProtocolErrorCode,
  message : String,
  request_id? : String = "",
  provider_code? : String = "",
) -> ProtocolError {
  let message = if message == "" { code.to_string() } else { message }
  { code, message, request_id, provider_code }
}

///|
pub fn ProtocolError::from_file_system_error(
  error : @workspace.FileSystemProviderError,
  request_id? : String = "",
) -> ProtocolError {
  ProtocolError(
    ProtocolProviderError,
    error.message,
    request_id~,
    provider_code=error.code.to_string(),
  )
}

///|
pub fn ProtocolErrorCode::to_string(self : ProtocolErrorCode) -> String {
  match self {
    ProtocolInvalidJson => "InvalidJson"
    ProtocolUnsupportedVersion => "UnsupportedVersion"
    ProtocolUnknownPacket => "UnknownPacket"
    ProtocolInvalidPacket => "InvalidPacket"
    ProtocolInvalidUri => "InvalidUri"
    ProtocolProviderError => "ProviderError"
  }
}

///|
pub fn ProtocolErrorCode::from_string(code : String) -> ProtocolErrorCode {
  match code {
    "InvalidJson" => ProtocolInvalidJson
    "UnsupportedVersion" => ProtocolUnsupportedVersion
    "UnknownPacket" => ProtocolUnknownPacket
    "InvalidPacket" => ProtocolInvalidPacket
    "InvalidUri" => ProtocolInvalidUri
    "ProviderError" => ProtocolProviderError
    _ => ProtocolInvalidPacket
  }
}

///|
pub fn negotiate_protocol_version(version : Int) -> ProtocolNegotiation {
  if version == protocol_version() {
    ProtocolAccepted(version)
  } else {
    ProtocolRejected(
      ProtocolError(
        ProtocolUnsupportedVersion,
        "Unsupported remote protocol version " + version.to_string(),
      ),
    )
  }
}

///|
pub fn ClientPacket::to_json(self : ClientPacket) -> String {
  match self {
    ListWorkspace(request) => workspace_list_request_json(request)
    OpenDocument(request) => document_request_json("OpenDocument", request)
    WatchDocument(request) => document_request_json("WatchDocument", request)
    CloseDocument(request) => document_request_json("CloseDocument", request)
    Diagnostics(request) => version_request_json("Diagnostics", request)
    Hover(request) => position_request_json("Hover", request)
    Definition(request) => position_request_json("Definition", request)
    DocumentSymbols(request) => version_request_json("DocumentSymbols", request)
    SemanticTokens(request) => version_request_json("SemanticTokens", request)
  }
}

///|
pub fn ServerPacket::to_json(self : ServerPacket) -> String {
  match self {
    WorkspaceListed(payload) => workspace_listed_json(payload)
    DocumentLoaded(payload) => document_payload_json("DocumentLoaded", payload)
    DocumentChanged(payload) =>
      document_payload_json("DocumentChanged", payload)
    Diagnostics(payload) => diagnostics_payload_json(payload)
    HoverResult(payload) => hover_result_json(payload)
    DefinitionResult(payload) => definition_result_json(payload)
    DocumentSymbolsResult(payload) => document_symbols_result_json(payload)
    SemanticTokensResult(payload) => semantic_tokens_result_json(payload)
    RemoteError(error) => error_packet_json(error)
  }
}

///|
pub fn decode_client_packet(raw : String) -> ClientPacketDecodeResult {
  match parse_packet_object(raw) {
    Some(packet) =>
      match validate_packet_version(packet) {
        Some(error) => ClientPacketDecodeError(error)
        None =>
          match json_string_field(packet, "type") {
            Some("ListWorkspace") =>
              DecodedClientPacket(ListWorkspace({ id: request_id(packet) }))
            Some("OpenDocument") =>
              decode_document_client(packet, request_id(packet), request => {
                OpenDocument(request)
              })
            Some("WatchDocument") =>
              decode_document_client(packet, request_id(packet), request => {
                WatchDocument(request)
              })
            Some("CloseDocument") =>
              decode_document_client(packet, request_id(packet), request => {
                CloseDocument(request)
              })
            Some("Diagnostics") =>
              decode_version_client(packet, request_id(packet), request => {
                Diagnostics(request)
              })
            Some("Hover") =>
              decode_position_client(packet, request_id(packet), request => {
                Hover(request)
              })
            Some("Definition") =>
              decode_position_client(packet, request_id(packet), request => {
                Definition(request)
              })
            Some("DocumentSymbols") =>
              decode_version_client(packet, request_id(packet), request => {
                DocumentSymbols(request)
              })
            Some("SemanticTokens") =>
              decode_version_client(packet, request_id(packet), request => {
                SemanticTokens(request)
              })
            Some(kind) =>
              ClientPacketDecodeError(
                ProtocolError(
                  ProtocolUnknownPacket,
                  "Unknown client packet type " + kind,
                  request_id=request_id(packet),
                ),
              )
            None =>
              ClientPacketDecodeError(
                ProtocolError(
                  ProtocolInvalidPacket,
                  "Remote protocol packet is missing a type.",
                  request_id=request_id(packet),
                ),
              )
          }
      }
    None =>
      ClientPacketDecodeError(
        ProtocolError(ProtocolInvalidJson, "Invalid remote protocol JSON."),
      )
  }
}

///|
pub fn decode_server_packet(raw : String) -> ServerPacketDecodeResult {
  match parse_packet_object(raw) {
    Some(packet) =>
      match validate_packet_version(packet) {
        Some(error) => ServerPacketDecodeError(error)
        None =>
          match json_string_field(packet, "type") {
            Some("WorkspaceListed") =>
              decode_workspace_listed_payload(packet, request_id(packet))
            Some("DocumentLoaded") =>
              decode_document_server(packet, request_id(packet), payload => {
                DocumentLoaded(payload)
              })
            Some("DocumentChanged") =>
              decode_document_server(packet, request_id(packet), payload => {
                DocumentChanged(payload)
              })
            Some("Diagnostics") => decode_diagnostics_payload(packet)
            Some("HoverResult") =>
              decode_hover_result_payload(packet, request_id(packet))
            Some("DefinitionResult") =>
              decode_definition_result_payload(packet, request_id(packet))
            Some("DocumentSymbolsResult") =>
              decode_document_symbols_result_payload(packet, request_id(packet))
            Some("SemanticTokensResult") =>
              decode_semantic_tokens_result_payload(packet, request_id(packet))
            Some("Error") => decode_error_payload(packet, request_id(packet))
            Some(kind) =>
              ServerPacketDecodeError(
                ProtocolError(
                  ProtocolUnknownPacket,
                  "Unknown server packet type " + kind,
                  request_id=request_id(packet),
                ),
              )
            None =>
              ServerPacketDecodeError(
                ProtocolError(
                  ProtocolInvalidPacket,
                  "Remote protocol packet is missing a type.",
                  request_id=request_id(packet),
                ),
              )
          }
      }
    None =>
      ServerPacketDecodeError(
        ProtocolError(ProtocolInvalidJson, "Invalid remote protocol JSON."),
      )
  }
}

///|
fn decode_document_client(
  packet : Json,
  id : String,
  build : (DocumentRequest) -> ClientPacket,
) -> ClientPacketDecodeResult {
  match parse_uri_field(packet, "uri", id) {
    ParsedProtocolUri(uri) => DecodedClientPacket(build({ id, uri }))
    ProtocolUriError(error) => ClientPacketDecodeError(error)
  }
}

///|
fn decode_position_client(
  packet : Json,
  id : String,
  build : (DocumentPositionRequest) -> ClientPacket,
) -> ClientPacketDecodeResult {
  match parse_uri_field(packet, "uri", id) {
    ParsedProtocolUri(uri) =>
      DecodedClientPacket(
        build({
          id,
          uri,
          document_version: json_int_field(packet, "documentVersion").unwrap_or(
            0,
          ),
          offset: json_int_field(packet, "offset").unwrap_or(0),
        }),
      )
    ProtocolUriError(error) => ClientPacketDecodeError(error)
  }
}

///|
fn decode_version_client(
  packet : Json,
  id : String,
  build : (DocumentVersionRequest) -> ClientPacket,
) -> ClientPacketDecodeResult {
  match parse_uri_field(packet, "uri", id) {
    ParsedProtocolUri(uri) =>
      DecodedClientPacket(
        build({
          id,
          uri,
          document_version: json_int_field(packet, "documentVersion").unwrap_or(
            0,
          ),
        }),
      )
    ProtocolUriError(error) => ClientPacketDecodeError(error)
  }
}

///|
fn decode_document_server(
  packet : Json,
  id : String,
  build : (DocumentPayload) -> ServerPacket,
) -> ServerPacketDecodeResult {
  match json_field(packet, "document") {
    Some(document_json) =>
      match parse_source_document(document_json, id) {
        ParsedProtocolDocument(document) =>
          DecodedServerPacket(build({ id, document }))
        ProtocolDocumentError(error) => ServerPacketDecodeError(error)
      }
    None =>
      ServerPacketDecodeError(
        ProtocolError(
          ProtocolInvalidPacket,
          "Document packet is missing a document.",
          request_id=id,
        ),
      )
  }
}

///|
fn decode_workspace_listed_payload(
  packet : Json,
  id : String,
) -> ServerPacketDecodeResult {
  let entries = []
  match json_field(packet, "entries") {
    Some(Array(items)) =>
      for item in items {
        match parse_workspace_entry(item) {
          Some(entry) => entries.push(entry)
          None => ()
        }
      }
    _ => ()
  }
  DecodedServerPacket(WorkspaceListed({ id, entries }))
}

///|
fn decode_diagnostics_payload(packet : Json) -> ServerPacketDecodeResult {
  let id = request_id(packet)
  match parse_uri_field(packet, "uri", id) {
    ParsedProtocolUri(uri) => {
      let diagnostics = []
      match json_field(packet, "diagnostics") {
        Some(Array(items)) =>
          for item in items {
            match parse_diagnostic(item) {
              Some(diagnostic) => diagnostics.push(diagnostic)
              None => ()
            }
          }
        _ => ()
      }
      DecodedServerPacket(
        Diagnostics({
          id,
          uri,
          version: json_int_field(packet, "documentVersion").unwrap_or(0),
          diagnostics,
        }),
      )
    }
    ProtocolUriError(error) => ServerPacketDecodeError(error)
  }
}

///|
fn decode_hover_result_payload(
  packet : Json,
  id : String,
) -> ServerPacketDecodeResult {
  match parse_uri_field(packet, "uri", id) {
    ParsedProtocolUri(uri) => {
      let hover = match json_field(packet, "hover") {
        Some(value) => parse_hover(value)
        None => None
      }
      DecodedServerPacket(
        HoverResult({
          id,
          uri,
          version: json_int_field(packet, "documentVersion").unwrap_or(0),
          hover,
        }),
      )
    }
    ProtocolUriError(error) => ServerPacketDecodeError(error)
  }
}

///|
fn decode_definition_result_payload(
  packet : Json,
  id : String,
) -> ServerPacketDecodeResult {
  match parse_uri_field(packet, "uri", id) {
    ParsedProtocolUri(uri) => {
      let location = match json_field(packet, "location") {
        Some(value) => parse_location(value)
        None => None
      }
      DecodedServerPacket(
        DefinitionResult({
          id,
          uri,
          version: json_int_field(packet, "documentVersion").unwrap_or(0),
          location,
        }),
      )
    }
    ProtocolUriError(error) => ServerPacketDecodeError(error)
  }
}

///|
fn decode_document_symbols_result_payload(
  packet : Json,
  id : String,
) -> ServerPacketDecodeResult {
  match parse_uri_field(packet, "uri", id) {
    ParsedProtocolUri(uri) => {
      let symbols = []
      match json_field(packet, "symbols") {
        Some(Array(items)) =>
          for item in items {
            match parse_document_symbol(item) {
              Some(symbol) => symbols.push(symbol)
              None => ()
            }
          }
        _ => ()
      }
      DecodedServerPacket(
        DocumentSymbolsResult({
          id,
          uri,
          version: json_int_field(packet, "documentVersion").unwrap_or(0),
          symbols,
        }),
      )
    }
    ProtocolUriError(error) => ServerPacketDecodeError(error)
  }
}

///|
fn decode_semantic_tokens_result_payload(
  packet : Json,
  id : String,
) -> ServerPacketDecodeResult {
  match parse_uri_field(packet, "uri", id) {
    ParsedProtocolUri(uri) => {
      let semantic_tokens = []
      match json_field(packet, "semanticTokens") {
        Some(Array(items)) =>
          for item in items {
            match parse_semantic_token(item) {
              Some(token) => semantic_tokens.push(token)
              None => ()
            }
          }
        _ => ()
      }
      DecodedServerPacket(
        SemanticTokensResult({
          id,
          uri,
          version: json_int_field(packet, "documentVersion").unwrap_or(0),
          semantic_tokens,
        }),
      )
    }
    ProtocolUriError(error) => ServerPacketDecodeError(error)
  }
}

///|
fn decode_error_payload(packet : Json, id : String) -> ServerPacketDecodeResult {
  match json_field(packet, "error") {
    Some(error) =>
      DecodedServerPacket(
        RemoteError(
          ProtocolError(
            ProtocolErrorCode::from_string(
              json_string_field(error, "code").unwrap_or("InvalidPacket"),
            ),
            json_string_field(error, "message").unwrap_or("Remote error."),
            request_id=json_string_field(error, "requestId").unwrap_or(id),
            provider_code=json_string_field(error, "providerCode").unwrap_or(""),
          ),
        ),
      )
    None =>
      ServerPacketDecodeError(
        ProtocolError(
          ProtocolInvalidPacket,
          "Error packet is missing an error object.",
          request_id=id,
        ),
      )
  }
}

///|
fn parse_packet_object(raw : String) -> Json? {
  match parse_json(raw) {
    Some(Object(_)) as parsed => parsed
    _ => None
  }
}

///|
fn validate_packet_version(packet : Json) -> ProtocolError? {
  let version = json_int_field(packet, "version").unwrap_or(0)
  if version == protocol_version() {
    None
  } else {
    Some(
      ProtocolError(
        ProtocolUnsupportedVersion,
        "Unsupported remote protocol version " + version.to_string(),
        request_id=request_id(packet),
      ),
    )
  }
}

///|
fn request_id(packet : Json) -> String {
  json_string_field(packet, "id").unwrap_or("")
}

///|
priv enum ProtocolUriResult {
  ParsedProtocolUri(@workspace.DocumentUri)
  ProtocolUriError(ProtocolError)
}

///|
fn parse_uri_field(
  packet : Json,
  key : String,
  id : String,
) -> ProtocolUriResult {
  match json_string_field(packet, key) {
    Some(raw) =>
      match @workspace.DocumentUri::parse(raw) {
        ParsedDocumentUri(uri) => ParsedProtocolUri(uri)
        DocumentUriError(_) =>
          ProtocolUriError(
            ProtocolError(
              ProtocolInvalidUri,
              "Invalid document URI " + raw,
              request_id=id,
            ),
          )
      }
    None =>
      ProtocolUriError(
        ProtocolError(
          ProtocolInvalidPacket,
          "Remote protocol packet is missing " + key + ".",
          request_id=id,
        ),
      )
  }
}

///|
priv enum ProtocolDocumentResult {
  ParsedProtocolDocument(@workspace.SourceDocument)
  ProtocolDocumentError(ProtocolError)
}

///|
fn parse_source_document(value : Json, id : String) -> ProtocolDocumentResult {
  match value {
    Object(_) =>
      match json_string_field(value, "uri") {
        Some(raw_uri) =>
          match @workspace.DocumentUri::parse(raw_uri) {
            ParsedDocumentUri(uri) =>
              ParsedProtocolDocument(
                SourceDocument(
                  uri,
                  json_string_field(value, "displayName").unwrap_or(""),
                  json_string_field(value, "languageId").unwrap_or(""),
                  json_int_field(value, "version").unwrap_or(1),
                  json_string_field(value, "revision").unwrap_or(""),
                  json_string_field(value, "text").unwrap_or(""),
                ),
              )
            DocumentUriError(_) =>
              ProtocolDocumentError(
                ProtocolError(
                  ProtocolInvalidUri,
                  "Invalid document URI " + raw_uri,
                  request_id=id,
                ),
              )
          }
        None =>
          ProtocolDocumentError(
            ProtocolError(
              ProtocolInvalidPacket,
              "Source document is missing uri.",
              request_id=id,
            ),
          )
      }
    _ =>
      ProtocolDocumentError(
        ProtocolError(
          ProtocolInvalidPacket,
          "Document payload must be an object.",
          request_id=id,
        ),
      )
  }
}

///|
fn workspace_list_request_json(request : WorkspaceListRequest) -> String {
  packet_head("ListWorkspace", request.id) + "}"
}

///|
fn document_request_json(kind : String, request : DocumentRequest) -> String {
  let mut out = packet_head(kind, request.id)
  out = out + ",\"uri\":" + json_string(request.uri.to_string())
  out + "}"
}

///|
fn position_request_json(
  kind : String,
  request : DocumentPositionRequest,
) -> String {
  let mut out = packet_head(kind, request.id)
  out = out + ",\"uri\":" + json_string(request.uri.to_string())
  out = out + ",\"documentVersion\":" + request.document_version.to_string()
  out = out + ",\"offset\":" + request.offset.to_string()
  out + "}"
}

///|
fn version_request_json(
  kind : String,
  request : DocumentVersionRequest,
) -> String {
  let mut out = packet_head(kind, request.id)
  out = out + ",\"uri\":" + json_string(request.uri.to_string())
  out = out + ",\"documentVersion\":" + request.document_version.to_string()
  out + "}"
}

///|
fn document_payload_json(kind : String, payload : DocumentPayload) -> String {
  let mut out = packet_head(kind, payload.id)
  out = out + ",\"document\":" + payload.document.to_json()
  out + "}"
}

///|
fn workspace_listed_json(payload : WorkspaceListedPayload) -> String {
  let mut out = packet_head("WorkspaceListed", payload.id)
  out = out + ",\"entries\":" + workspace_entries_json(payload.entries)
  out + "}"
}

///|
fn diagnostics_payload_json(payload : DiagnosticsPayload) -> String {
  let mut out = packet_head("Diagnostics", payload.id)
  out = out + ",\"uri\":" + json_string(payload.uri.to_string())
  out = out + ",\"documentVersion\":" + payload.version.to_string()
  out = out + ",\"diagnostics\":" + diagnostics_json(payload.diagnostics)
  out + "}"
}

///|
fn hover_result_json(payload : HoverResultPayload) -> String {
  let mut out = packet_head("HoverResult", payload.id)
  out = out + ",\"uri\":" + json_string(payload.uri.to_string())
  out = out + ",\"documentVersion\":" + payload.version.to_string()
  out = out + ",\"hover\":" + optional_hover_json(payload.hover)
  out + "}"
}

///|
fn definition_result_json(payload : DefinitionResultPayload) -> String {
  let mut out = packet_head("DefinitionResult", payload.id)
  out = out + ",\"uri\":" + json_string(payload.uri.to_string())
  out = out + ",\"documentVersion\":" + payload.version.to_string()
  out = out + ",\"location\":" + optional_location_json(payload.location)
  out + "}"
}

///|
fn document_symbols_result_json(
  payload : DocumentSymbolsResultPayload,
) -> String {
  let mut out = packet_head("DocumentSymbolsResult", payload.id)
  out = out + ",\"uri\":" + json_string(payload.uri.to_string())
  out = out + ",\"documentVersion\":" + payload.version.to_string()
  out = out + ",\"symbols\":" + document_symbols_json(payload.symbols)
  out + "}"
}

///|
fn semantic_tokens_result_json(payload : SemanticTokensResultPayload) -> String {
  let mut out = packet_head("SemanticTokensResult", payload.id)
  out = out + ",\"uri\":" + json_string(payload.uri.to_string())
  out = out + ",\"documentVersion\":" + payload.version.to_string()
  out = out + ",\"semanticTokens\":"
  out = out + semantic_tokens_json(payload.semantic_tokens)
  out + "}"
}

///|
fn error_packet_json(error : ProtocolError) -> String {
  let mut out = packet_head("Error", error.request_id)
  out = out + ",\"error\":" + error.to_json()
  out + "}"
}

///|
pub fn ProtocolError::to_json(self : ProtocolError) -> String {
  let mut out = "{"
  out = out + "\"code\":" + json_string(self.code.to_string())
  out = out + ",\"message\":" + json_string(self.message)
  out = out + ",\"requestId\":" + json_string(self.request_id)
  if self.provider_code != "" {
    out = out + ",\"providerCode\":" + json_string(self.provider_code)
  }
  out + "}"
}

///|
fn packet_head(kind : String, id : String) -> String {
  let mut out = "{"
  out = out + "\"version\":" + protocol_version().to_string()
  out = out + ",\"type\":" + json_string(kind)
  if id != "" {
    out = out + ",\"id\":" + json_string(id)
  }
  out
}

///|
fn diagnostics_json(diagnostics : Array[@language.Diagnostic]) -> String {
  let mut out = "["
  for i in 0..<diagnostics.length() {
    if i > 0 {
      out = out + ","
    }
    out = out + diagnostic_json(diagnostics[i])
  }
  out + "]"
}

///|
fn workspace_entries_json(entries : Array[WorkspaceEntry]) -> String {
  let mut out = "["
  for i in 0..<entries.length() {
    if i > 0 {
      out = out + ","
    }
    out = out + workspace_entry_json(entries[i])
  }
  out + "]"
}

///|
fn workspace_entry_json(entry : WorkspaceEntry) -> String {
  let mut out = "{"
  out = out + "\"path\":" + json_string(entry.path)
  out = out + ",\"name\":" + json_string(entry.name)
  out = out + ",\"kind\":" + json_string(entry.kind)
  out = out + ",\"depth\":" + entry.depth.to_string()
  out + "}"
}

///|
fn document_symbols_json(symbols : Array[@language.DocumentSymbol]) -> String {
  let mut out = "["
  for i in 0..<symbols.length() {
    if i > 0 {
      out = out + ","
    }
    out = out + document_symbol_json(symbols[i])
  }
  out + "]"
}

///|
fn semantic_tokens_json(tokens : Array[@language.SemanticToken]) -> String {
  let mut out = "["
  for i in 0..<tokens.length() {
    if i > 0 {
      out = out + ","
    }
    out = out + semantic_token_json(tokens[i])
  }
  out + "]"
}

///|
fn diagnostic_json(diagnostic : @language.Diagnostic) -> String {
  let mut out = "{"
  out = out + "\"range\":" + range_json(diagnostic.range)
  out = out + ",\"severity\":" + json_string(diagnostic.severity.label())
  out = out + ",\"message\":" + json_string(diagnostic.message)
  out + "}"
}

///|
fn document_symbol_json(symbol : @language.DocumentSymbol) -> String {
  let mut out = "{"
  out = out + "\"name\":" + json_string(symbol.name)
  out = out + ",\"kind\":" + json_string(symbol.kind)
  out = out + ",\"range\":" + range_json(symbol.range)
  out + "}"
}

///|
fn semantic_token_json(token : @language.SemanticToken) -> String {
  let mut out = "{"
  out = out + "\"range\":" + range_json(token.range)
  out = out + ",\"tokenType\":" + json_string(token.token_type)
  out + "}"
}

///|
fn optional_hover_json(hover : @language.Hover?) -> String {
  match hover {
    Some(value) => hover_json(value)
    None => "null"
  }
}

///|
fn hover_json(hover : @language.Hover) -> String {
  let mut out = "{"
  out = out + "\"range\":" + range_json(hover.range)
  out = out + ",\"contents\":" + json_string(hover.contents)
  out + "}"
}

///|
fn optional_location_json(location : @language.Location?) -> String {
  match location {
    Some(value) => location_json(value)
    None => "null"
  }
}

///|
fn location_json(location : @language.Location) -> String {
  let mut out = "{"
  out = out + "\"uri\":" + json_string(location.uri.to_string())
  out = out + ",\"range\":" + range_json(location.range)
  out + "}"
}

///|
fn range_json(range : @core.Range) -> String {
  let mut out = "{"
  out = out + "\"start\":" + range.start.to_string()
  out = out + ",\"end\":" + range.end.to_string()
  out + "}"
}

///|
fn parse_workspace_entry(value : Json) -> WorkspaceEntry? {
  match value {
    Object(_) =>
      match
        (
          json_string_field(value, "path"),
          json_string_field(value, "name"),
          json_string_field(value, "kind"),
          json_int_field(value, "depth"),
        ) {
        (Some(path), Some(name), Some(kind), Some(depth)) =>
          Some({ path, name, kind, depth })
        _ => None
      }
    _ => None
  }
}

///|
fn parse_diagnostic(value : Json) -> @language.Diagnostic? {
  match value {
    Object(_) =>
      match json_field(value, "range") {
        Some(range_json) =>
          match parse_range(range_json) {
            Some(range) =>
              Some({
                range,
                severity: diagnostic_severity(
                  json_string_field(value, "severity").unwrap_or("Info"),
                ),
                message: json_string_field(value, "message").unwrap_or(""),
              })
            None => None
          }
        None => None
      }
    _ => None
  }
}

///|
fn parse_hover(value : Json) -> @language.Hover? {
  match value {
    Null => None
    Object(_) =>
      match (json_field(value, "range"), json_string_field(value, "contents")) {
        (Some(range_json), Some(contents)) =>
          match parse_range(range_json) {
            Some(range) => Some({ range, contents })
            None => None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn parse_location(value : Json) -> @language.Location? {
  match value {
    Null => None
    Object(_) =>
      match (json_string_field(value, "uri"), json_field(value, "range")) {
        (Some(raw_uri), Some(range_json)) =>
          match
            (@workspace.DocumentUri::parse(raw_uri), parse_range(range_json)) {
            (ParsedDocumentUri(uri), Some(range)) => Some({ uri, range })
            _ => None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn parse_document_symbol(value : Json) -> @language.DocumentSymbol? {
  match value {
    Object(_) =>
      match json_field(value, "range") {
        Some(range_json) =>
          match parse_range(range_json) {
            Some(range) =>
              Some({
                name: json_string_field(value, "name").unwrap_or(""),
                kind: json_string_field(value, "kind").unwrap_or(""),
                range,
              })
            None => None
          }
        None => None
      }
    _ => None
  }
}

///|
fn parse_semantic_token(value : Json) -> @language.SemanticToken? {
  match value {
    Object(_) =>
      match json_field(value, "range") {
        Some(range_json) =>
          match parse_range(range_json) {
            Some(range) =>
              Some({
                range,
                token_type: json_string_field(value, "tokenType").unwrap_or(""),
              })
            None => None
          }
        None => None
      }
    _ => None
  }
}

///|
fn parse_range(value : Json) -> @core.Range? {
  match value {
    Object(_) =>
      match (json_int_field(value, "start"), json_int_field(value, "end")) {
        (Some(start), Some(end)) => Some(Range(start, end))
        _ => None
      }
    _ => None
  }
}

///|
fn diagnostic_severity(label : String) -> @language.DiagnosticSeverity {
  match label {
    "Error" => Error
    "Warning" => Warning
    _ => Info
  }
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

///|
fn json_string(value : String) -> String {
  value.escape(quote=true)
}
