///|
test "encodes and decodes document client packets" {
  let uri = expect_uri("readonly-remote://workspace/docs/fixtures/demo.mbt")
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
test "encodes and decodes hover and definition packets" {
  let uri = expect_uri("readonly-remote://workspace/src/main.mbt")
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
}

///|
test "encodes and decodes server document and language packets" {
  let uri = expect_uri("readonly-remote://workspace/docs/fixtures/demo.mbt")
  let document = @workspace.SourceDocument(
    uri, "demo.mbt", "moonbit", 2, "rev-2", "pub fn main {}\n",
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
