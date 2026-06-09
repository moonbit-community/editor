///|
test "builds initialize, hover, and definition requests" {
  let document = test_document(1, "pub fn main {}\n")
  let initialize = lsp_initialize_request(7)
  assert_true(initialize.contains("\"method\":\"initialize\""))
  assert_true(initialize.contains("\"id\":7"))
  assert_true(initialize.contains("\"publishDiagnostics\""))
  assert_true(initialize.contains("\"definition\""))
  assert_true(initialize.contains("\"documentSymbol\""))
  assert_true(initialize.contains("\"semanticTokens\""))

  let file_document = file_document(1, "pub fn main {}\n")
  let file_initialize = lsp_initialize_request_with_root(
    10,
    lsp_root_uri(file_document.uri),
  )
  assert_true(
    file_initialize.contains("\"rootUri\":\"file:///Users/example/project\""),
  )

  let hover = lsp_hover_request(8, document, 7)
  assert_true(hover.contains("\"method\":\"textDocument/hover\""))
  assert_true(hover.contains("\"uri\":\"memory://demo.mbt\""))
  assert_true(hover.contains("\"line\":0"))
  assert_true(hover.contains("\"character\":7"))

  let definition = lsp_definition_request(9, document, 8)
  assert_true(definition.contains("\"method\":\"textDocument/definition\""))
  assert_true(definition.contains("\"uri\":\"memory://demo.mbt\""))
  assert_true(definition.contains("\"line\":0"))
  assert_true(definition.contains("\"character\":8"))

  let symbols = lsp_document_symbol_request(10, document)
  assert_true(symbols.contains("\"method\":\"textDocument/documentSymbol\""))
  assert_true(symbols.contains("\"uri\":\"memory://demo.mbt\""))

  let semantic_tokens = lsp_semantic_tokens_full_request(11, document)
  assert_true(
    semantic_tokens.contains("\"method\":\"textDocument/semanticTokens/full\""),
  )
  assert_true(semantic_tokens.contains("\"uri\":\"memory://demo.mbt\""))
}

///|
test "normalizes hover result shapes" {
  let doc = @core.DocumentSnapshot("pub fn main {}\n")
  let marked = hover_response(
    "{\"contents\":{\"language\":\"moonbit\",\"value\":\"fn main\"},\"range\":{\"start\":{\"line\":0,\"character\":7},\"end\":{\"line\":0,\"character\":11}}}",
  )
  match parse_hover_for_test(marked, doc, 0) {
    Some(hover) => {
      assert_eq(hover.contents, "fn main")
      assert_true(hover.range == Range(7, 11))
    }
    None => fail("expected marked hover")
  }

  let fallback = hover_response(
    "{\"contents\":[\"one\",{\"kind\":\"markdown\",\"value\":\"two\"}]}",
  )
  match parse_hover_for_test(fallback, doc, 4) {
    Some(hover) => {
      assert_eq(hover.contents, "one\ntwo")
      assert_true(hover.range == Range(4, 5))
    }
    None => fail("expected fallback hover")
  }

  let empty = hover_response("{\"contents\":\"\"}")
  assert_true(parse_hover_for_test(empty, doc, 0) is None)
}

///|
test "normalizes definition result shapes" {
  let document = test_document(1, "pub fn main {}\n")
  let location = definition_response(
    "{\"uri\":\"memory://demo.mbt\",\"range\":{\"start\":{\"line\":0,\"character\":7},\"end\":{\"line\":0,\"character\":11}}}",
  )
  match parse_definition_for_test(location, document) {
    Some(found) => {
      assert_eq(found.uri.to_string(), "memory://demo.mbt")
      assert_true(found.range == Range(7, 11))
    }
    None => fail("expected location")
  }

  let link = definition_response(
    "[{\"targetUri\":\"memory://demo.mbt\",\"targetSelectionRange\":{\"start\":{\"line\":0,\"character\":7},\"end\":{\"line\":0,\"character\":11}}}]",
  )
  match parse_definition_for_test(link, document) {
    Some(found) => {
      assert_eq(found.uri.to_string(), "memory://demo.mbt")
      assert_true(found.range == Range(7, 11))
    }
    None => fail("expected location link")
  }

  let external = definition_response(
    "{\"uri\":\"memory://other.mbt\",\"range\":{\"start\":{\"line\":4,\"character\":2},\"end\":{\"line\":4,\"character\":8}}}",
  )
  match parse_definition_for_test(external, document) {
    Some(found) => {
      assert_eq(found.uri.to_string(), "memory://other.mbt")
      assert_true(found.range == Range(0, 0))
    }
    None => fail("expected external location")
  }

  assert_true(
    parse_definition_for_test(definition_response("null"), document) is None,
  )
}

///|
async test "lsp client syncs documents and discards stale diagnostics" {
  let transport = TestLspTransport::new()
  let client = LspClient::LspClient(transport)
  let first = test_document(1, "pub fn main {\n  // TODO\n}\n")

  assert_true(client.state() == Idle)
  let first_result = client.sync_document(first)
  assert_true(client.is_initialized())
  assert_true(client.state() == Ready)
  assert_eq(client.pending_request_count(), 0)
  assert_eq(first_result.diagnostics.length(), 1)
  assert_true(first_result.diagnostics[0].severity == Warning)
  assert_true(first_result.diagnostics[0].range == Range(19, 23))

  transport.publish_diagnostics(first, 0, 3, 0, 6, version=0)
  let stale_result = client.sync_document(first)
  assert_eq(stale_result.diagnostics.length(), 1)
  assert_true(stale_result.diagnostics[0].range == Range(19, 23))

  let second = test_document(2, "pub fn main {\n  // DONE\n}\n")
  let second_result = client.sync_document(second)
  assert_eq(second_result.diagnostics.length(), 0)
  assert_true(
    transport.notifications.any(message => {
      message.contains("\"method\":\"textDocument/didChange\"")
    }),
  )
}

///|
async test "lsp client requests hover through transport" {
  let transport = TestLspTransport::new()
  let client = LspClient::LspClient(transport)
  let document = test_document(1, "pub fn main {}\n")

  match client.hover_at(document, 7) {
    Some(hover) => {
      assert_eq(hover.contents, "LSP hover for main")
      assert_true(hover.range == Range(7, 11))
    }
    None => fail("expected hover")
  }
}

///|
async test "lsp client requests definition through transport" {
  let transport = TestLspTransport::new()
  let client = LspClient::LspClient(transport)
  let document = test_document(1, "pub fn main {}\n")

  match client.definition_at(document, 7) {
    Some(location) => {
      assert_eq(location.uri.to_string(), "memory://demo.mbt")
      assert_true(location.range == Range(7, 11))
    }
    None => fail("expected definition")
  }
}

///|
async test "lsp client requests symbols and semantic tokens through provider adapter" {
  let transport = TestLspTransport::new()
  let client = LspClient::LspClient(transport)
  let provider = client.language_provider()
  let document = test_document(1, "pub fn main {}\n")

  let symbols = provider.document_symbols(document)
  assert_eq(symbols.length(), 2)
  assert_eq(symbols[0].name, "main")
  assert_eq(symbols[0].kind, "function")
  assert_true(symbols[0].range == Range(7, 11))
  assert_eq(symbols[1].name, "nested")
  assert_eq(symbols[1].kind, "variable")

  let tokens = provider.semantic_tokens_for_document(document)
  assert_eq(tokens.length(), 1)
  assert_true(tokens[0].range == Range(7, 11))
  assert_eq(tokens[0].token_type, "function")

  assert_true(
    transport.requests.any(message => {
      message.contains("\"method\":\"textDocument/documentSymbol\"")
    }),
  )
  assert_true(
    transport.requests.any(message => {
      message.contains("\"method\":\"textDocument/semanticTokens/full\"")
    }),
  )
}

///|
async test "lsp client gates unsupported capabilities" {
  let transport = TestLspTransport::new()
  transport.initialize_response = "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"capabilities\":{\"definitionProvider\":true}}}"
  let client = LspClient::LspClient(transport)
  let document = test_document(1, "pub fn main {}\n")

  assert_true(client.hover_at(document, 7) is None)
  assert_true(client.state() == Ready)
  assert_false(
    transport.requests.any(message => {
      message.contains("\"method\":\"textDocument/hover\"")
    }),
  )
}

///|
async test "lsp client sends shutdown and exit" {
  let transport = TestLspTransport::new()
  let client = LspClient::LspClient(transport)
  ignore(client.sync_document(test_document(1, "pub fn main {}\n")))

  client.shutdown()
  assert_true(client.state() == Stopped)
  assert_eq(client.pending_request_count(), 0)
  assert_true(
    transport.requests.any(message => {
      message.contains("\"method\":\"shutdown\"")
    }),
  )
  assert_true(
    transport.notifications.any(message => {
      message.contains("\"method\":\"exit\"")
    }),
  )
}

///|
fn hover_response(result : String) -> String {
  "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":" + result + "}"
}

///|
fn definition_response(result : String) -> String {
  "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":" + result + "}"
}

///|
fn parse_hover_for_test(
  raw : String,
  doc : @core.DocumentSnapshot,
  offset : Int,
) -> @language.Hover? {
  match parse_response_result(raw) {
    ParsedLspResult(result) => parse_hover_result(result, doc, offset)
    LspResponseError(_) => None
  }
}

///|
fn parse_definition_for_test(
  raw : String,
  document : @workspace.SourceDocument,
) -> @language.Location? {
  match parse_response_result(raw) {
    ParsedLspResult(result) => parse_definition_result(result, document)
    LspResponseError(_) => None
  }
}

///|
fn test_document(version : Int, text : String) -> @workspace.SourceDocument {
  SourceDocument(
    @workspace.DocumentUri::memory("demo.mbt"),
    "demo.mbt",
    "moonbit",
    version,
    "rev-" + version.to_string(),
    text,
  )
}

///|
fn file_document(version : Int, text : String) -> @workspace.SourceDocument {
  let uri = match
    @workspace.DocumentUri::parse("file:///Users/example/project/main.mbt") {
    ParsedDocumentUri(parsed) => parsed
    DocumentUriError(_) => @workspace.DocumentUri::memory("main.mbt")
  }
  SourceDocument(
    uri,
    "main.mbt",
    "moonbit",
    version,
    "rev-" + version.to_string(),
    text,
  )
}

///|
struct TestLspTransport {
  requests : Array[String]
  notifications : Array[String]
  listener : Ref[((String) -> Unit)?]
  mut initialize_response : String
}

///|
fn TestLspTransport::new() -> TestLspTransport {
  {
    requests: [],
    notifications: [],
    listener: Ref(None),
    initialize_response: "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"capabilities\":{\"hoverProvider\":true,\"definitionProvider\":true,\"documentSymbolProvider\":true,\"semanticTokensProvider\":{\"legend\":{\"tokenTypes\":[\"function\",\"variable\"]},\"full\":true}}}}",
  }
}

///|
impl LspTransport for TestLspTransport with fn request(self, message) {
  self.requests.push(message)
  if message.contains("\"method\":\"initialize\"") {
    self.initialize_response
  } else if message.contains("\"method\":\"textDocument/hover\"") {
    hover_response(
      "{\"contents\":\"LSP hover for main\",\"range\":{\"start\":{\"line\":0,\"character\":7},\"end\":{\"line\":0,\"character\":11}}}",
    )
  } else if message.contains("\"method\":\"textDocument/definition\"") {
    definition_response(
      "{\"uri\":\"memory://demo.mbt\",\"range\":{\"start\":{\"line\":0,\"character\":7},\"end\":{\"line\":0,\"character\":11}}}",
    )
  } else if message.contains("\"method\":\"textDocument/documentSymbol\"") {
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":[{\"name\":\"main\",\"kind\":12,\"range\":{\"start\":{\"line\":0,\"character\":7},\"end\":{\"line\":0,\"character\":11}},\"selectionRange\":{\"start\":{\"line\":0,\"character\":7},\"end\":{\"line\":0,\"character\":11}},\"children\":[{\"name\":\"nested\",\"kind\":13,\"range\":{\"start\":{\"line\":0,\"character\":7},\"end\":{\"line\":0,\"character\":11}},\"selectionRange\":{\"start\":{\"line\":0,\"character\":7},\"end\":{\"line\":0,\"character\":11}}}]}]}"
  } else if message.contains("\"method\":\"textDocument/semanticTokens/full\"") {
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"data\":[0,7,4,0,0]}}"
  } else if message.contains("\"method\":\"shutdown\"") {
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":null}"
  } else {
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":-32601,\"message\":\"unsupported\"}}"
  }
}

///|
impl LspTransport for TestLspTransport with fn notify(self, message) {
  self.notifications.push(message)
  if message.contains("\"method\":\"textDocument/didOpen\"") {
    self.publish_diagnostics(
      test_document(1, "pub fn main {\n  // TODO\n}\n"),
      1,
      5,
      1,
      9,
      version=1,
    )
  } else if message.contains("\"method\":\"textDocument/didChange\"") {
    self.publish_empty("memory://demo.mbt", 2)
  }
}

///|
impl LspTransport for TestLspTransport with fn subscribe(self, listener) {
  self.listener.val = Some(listener)
  LspSubscription(() => self.listener.val = None)
}

///|
fn TestLspTransport::publish_diagnostics(
  self : TestLspTransport,
  document : @workspace.SourceDocument,
  start_line : Int,
  start_character : Int,
  end_line : Int,
  end_character : Int,
  version~ : Int,
) -> Unit {
  self.publish(
    "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/publishDiagnostics\",\"params\":{\"uri\":\"" +
    document.uri.to_string() +
    "\",\"version\":" +
    version.to_string() +
    ",\"diagnostics\":[{\"range\":{\"start\":{\"line\":" +
    start_line.to_string() +
    ",\"character\":" +
    start_character.to_string() +
    "},\"end\":{\"line\":" +
    end_line.to_string() +
    ",\"character\":" +
    end_character.to_string() +
    "}},\"severity\":2,\"message\":\"Fake LSP diagnostic\"}]}}",
  )
}

///|
fn TestLspTransport::publish_empty(
  self : TestLspTransport,
  uri : String,
  version : Int,
) -> Unit {
  self.publish(
    "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/publishDiagnostics\",\"params\":{\"uri\":\"" +
    uri +
    "\",\"version\":" +
    version.to_string() +
    ",\"diagnostics\":[]}}",
  )
}

///|
fn TestLspTransport::publish(self : TestLspTransport, message : String) -> Unit {
  match self.listener.val {
    Some(listener) => listener(message)
    None => ()
  }
}
