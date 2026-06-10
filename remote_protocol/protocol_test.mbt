///|
test "encodes and decodes document client packets" {
  let uri = expect_uri(
    "readonly-remote://workspace/docs/fixtures/project/src/main.mbt",
  )
  let list = @remote_protocol.ListWorkspace({ id: "list-1" })
  match @remote_protocol.decode_client_packet(list.to_json()) {
    DecodedClientPacket(ListWorkspace(request)) =>
      assert_eq(request.id, "list-1")
    DecodedClientPacket(_) => fail("unexpected workspace list packet")
    ClientPacketDecodeError(error) => fail(error.message)
  }

  let packet = @remote_protocol.OpenDocument({ id: "open-1", uri })
  let encoded = packet.to_json()
  assert_true(encoded.contains("\"type\":\"OpenDocument\""))
  assert_true(encoded.contains("\"version\":1"))

  match @remote_protocol.decode_client_packet(encoded) {
    DecodedClientPacket(OpenDocument(request)) => {
      assert_eq(request.id, "open-1")
      assert_eq(request.uri.to_string(), uri.to_string())
    }
    DecodedClientPacket(_) => fail("unexpected client packet")
    ClientPacketDecodeError(error) => fail(error.message)
  }
}

///|
test "encodes and decodes semantic client packets" {
  let uri = expect_uri("readonly-remote://workspace/src/main.mbt")
  let diagnostics = @remote_protocol.ClientPacket::Diagnostics({
    id: "diag-1",
    uri,
    document_version: 4,
  })
  match @remote_protocol.decode_client_packet(diagnostics.to_json()) {
    DecodedClientPacket(Diagnostics(request)) => {
      assert_eq(request.id, "diag-1")
      assert_eq(request.document_version, 4)
    }
    DecodedClientPacket(_) => fail("unexpected diagnostics packet")
    ClientPacketDecodeError(error) => fail(error.message)
  }

  let hover = @remote_protocol.Hover({
    id: "hover-1",
    uri,
    document_version: 4,
    offset: 17,
  })
  match @remote_protocol.decode_client_packet(hover.to_json()) {
    DecodedClientPacket(Hover(request)) => {
      assert_eq(request.id, "hover-1")
      assert_eq(request.document_version, 4)
      assert_eq(request.offset, 17)
    }
    DecodedClientPacket(_) => fail("unexpected hover packet")
    ClientPacketDecodeError(error) => fail(error.message)
  }

  let definition = @remote_protocol.Definition({
    id: "def-1",
    uri,
    document_version: 4,
    offset: 18,
  })
  match @remote_protocol.decode_client_packet(definition.to_json()) {
    DecodedClientPacket(Definition(request)) => {
      assert_eq(request.id, "def-1")
      assert_eq(request.offset, 18)
    }
    DecodedClientPacket(_) => fail("unexpected definition packet")
    ClientPacketDecodeError(error) => fail(error.message)
  }

  let symbols = @remote_protocol.DocumentSymbols({
    id: "symbols-1",
    uri,
    document_version: 5,
  })
  match @remote_protocol.decode_client_packet(symbols.to_json()) {
    DecodedClientPacket(DocumentSymbols(request)) => {
      assert_eq(request.id, "symbols-1")
      assert_eq(request.document_version, 5)
    }
    DecodedClientPacket(_) => fail("unexpected document symbols packet")
    ClientPacketDecodeError(error) => fail(error.message)
  }

  let tokens = @remote_protocol.SemanticTokens({
    id: "tokens-1",
    uri,
    document_version: 6,
  })
  match @remote_protocol.decode_client_packet(tokens.to_json()) {
    DecodedClientPacket(SemanticTokens(request)) => {
      assert_eq(request.id, "tokens-1")
      assert_eq(request.document_version, 6)
    }
    DecodedClientPacket(_) => fail("unexpected semantic tokens packet")
    ClientPacketDecodeError(error) => fail(error.message)
  }
}

///|
test "encodes and decodes server document and language packets" {
  let uri = expect_uri(
    "readonly-remote://workspace/docs/fixtures/project/src/main.mbt",
  )
  let workspace = @remote_protocol.WorkspaceListed({
    id: "list-1",
    entries: [
      { path: "src", name: "src", kind: "directory", depth: 0 },
      { path: "src/main.mbt", name: "main.mbt", kind: "file", depth: 1 },
    ],
  })
  match @remote_protocol.decode_server_packet(workspace.to_json()) {
    DecodedServerPacket(WorkspaceListed(payload)) => {
      assert_eq(payload.id, "list-1")
      assert_eq(payload.entries.length(), 2)
      assert_eq(payload.entries[1].path, "src/main.mbt")
      assert_eq(payload.entries[1].kind, "file")
      assert_eq(payload.entries[1].depth, 1)
    }
    DecodedServerPacket(_) => fail("unexpected workspace listed packet")
    ServerPacketDecodeError(error) => fail(error.message)
  }

  let document = @workspace.SourceDocument(
    uri, "main.mbt", "moonbit", 2, "rev-2", "pub fn main {}\n",
  )
  let loaded = @remote_protocol.DocumentLoaded({ id: "open-1", document })
  match @remote_protocol.decode_server_packet(loaded.to_json()) {
    DecodedServerPacket(DocumentLoaded(payload)) => {
      assert_eq(payload.id, "open-1")
      assert_eq(payload.document.uri.to_string(), uri.to_string())
      assert_eq(payload.document.version, 2)
    }
    DecodedServerPacket(_) => fail("unexpected server packet")
    ServerPacketDecodeError(error) => fail(error.message)
  }

  let hover = @remote_protocol.HoverResult({
    id: "hover-1",
    uri,
    version: 2,
    hover: Some({ range: Range(7, 11), contents: "fn main" }),
  })
  match @remote_protocol.decode_server_packet(hover.to_json()) {
    DecodedServerPacket(HoverResult(payload)) =>
      match payload.hover {
        Some(item) => {
          assert_eq(payload.version, 2)
          assert_eq(item.contents, "fn main")
          assert_true(item.range == Range(7, 11))
        }
        None => fail("missing hover")
      }
    DecodedServerPacket(_) => fail("unexpected hover result packet")
    ServerPacketDecodeError(error) => fail(error.message)
  }

  let diagnostics = @remote_protocol.ServerPacket::Diagnostics({
    id: "diag-1",
    uri,
    version: 2,
    diagnostics: [
      { range: Range(0, 3), severity: Warning, message: "check me" },
    ],
  })
  match @remote_protocol.decode_server_packet(diagnostics.to_json()) {
    DecodedServerPacket(Diagnostics(payload)) => {
      assert_eq(payload.id, "diag-1")
      assert_eq(payload.diagnostics.length(), 1)
      assert_eq(payload.diagnostics[0].message, "check me")
    }
    DecodedServerPacket(_) => fail("unexpected diagnostics packet")
    ServerPacketDecodeError(error) => fail(error.message)
  }

  let symbols = @remote_protocol.DocumentSymbolsResult({
    id: "symbols-1",
    uri,
    version: 2,
    symbols: [{ name: "main", kind: "function", range: Range(7, 11) }],
  })
  match @remote_protocol.decode_server_packet(symbols.to_json()) {
    DecodedServerPacket(DocumentSymbolsResult(payload)) => {
      assert_eq(payload.symbols.length(), 1)
      assert_eq(payload.symbols[0].name, "main")
    }
    DecodedServerPacket(_) => fail("unexpected document symbols result packet")
    ServerPacketDecodeError(error) => fail(error.message)
  }

  let semantic_tokens = @remote_protocol.SemanticTokensResult({
    id: "tokens-1",
    uri,
    version: 2,
    semantic_tokens: [{ range: Range(7, 11), token_type: "function" }],
  })
  match @remote_protocol.decode_server_packet(semantic_tokens.to_json()) {
    DecodedServerPacket(SemanticTokensResult(payload)) => {
      assert_eq(payload.semantic_tokens.length(), 1)
      assert_eq(payload.semantic_tokens[0].token_type, "function")
    }
    DecodedServerPacket(_) => fail("unexpected semantic tokens result packet")
    ServerPacketDecodeError(error) => fail(error.message)
  }
}

///|
test "reports protocol decode errors" {
  match @remote_protocol.decode_client_packet("{") {
    ClientPacketDecodeError(error) =>
      assert_true(error.code == ProtocolInvalidJson)
    DecodedClientPacket(_) => fail("expected invalid JSON error")
  }

  match
    @remote_protocol.decode_client_packet(
      "{\"version\":99,\"type\":\"OpenDocument\",\"id\":\"x\",\"uri\":\"readonly-remote://workspace/a.mbt\"}",
    ) {
    ClientPacketDecodeError(error) =>
      assert_true(error.code == ProtocolUnsupportedVersion)
    DecodedClientPacket(_) => fail("expected unsupported version error")
  }

  match
    @remote_protocol.decode_client_packet(
      "{\"version\":1,\"type\":\"OpenDocument\",\"id\":\"x\",\"uri\":\"bad\"}",
    ) {
    ClientPacketDecodeError(error) =>
      assert_true(error.code == ProtocolInvalidUri)
    DecodedClientPacket(_) => fail("expected invalid URI error")
  }
}

///|
test "negotiates protocol versions" {
  match @remote_protocol.negotiate_protocol_version(1) {
    ProtocolAccepted(version) => assert_eq(version, 1)
    ProtocolRejected(error) => fail(error.message)
  }

  match @remote_protocol.negotiate_protocol_version(2) {
    ProtocolRejected(error) =>
      assert_true(error.code == ProtocolUnsupportedVersion)
    ProtocolAccepted(_) => fail("expected rejected protocol")
  }
}

///|
fn expect_uri(raw : String) -> @workspace.DocumentUri raise {
  match @workspace.DocumentUri::parse(raw) {
    ParsedDocumentUri(uri) => uri
    DocumentUriError(error) => fail("unexpected URI error " + error.to_string())
  }
}
