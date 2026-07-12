///|
fn eol_boundary_uri() -> @base_common.Uri {
  try! @base_common.Uri::parse(
    "readonly-remote://workspace/src/eol-boundary.mbt",
  )
}

///|
/// Remote DocumentSnapshot is the raw provider boundary. Conversion into the
/// viewer model starts normalized LF storage, and the browser harness exports
/// that same normalized value.
test "workbench keeps documents raw and exposes normalized model text" {
  let cases : Array[(String, String)] = [
    ("a\r\nb", "a\nb"),
    ("a\rb", "a\nb"),
    ("a\r\nb\rc\nd", "a\nb\nc\nd"),
    ("tail\r\n", "tail\n"),
    ("🙂\r\nβ\r中\n", "🙂\nβ\n中\n"),
    ("\u{FEFF}head\r\ntail", "\u{FEFF}head\ntail"),
  ]
  for index, sample in cases {
    let raw = sample.0
    let normalized = sample.1
    let document = @workspace.DocumentSnapshot(
      eol_boundary_uri(),
      "eol-boundary.mbt",
      "moonbit",
      "revision-" + index.to_string(),
      raw,
    )
    assert_eq(document.text, raw)
    assert_eq(document.length(), raw.length())
    let model = document_to_text_model(document)
    assert_eq(model.get_value(), normalized)
    assert_eq(model.get_value_length(), normalized.length())
    assert_eq(model.snapshot.text, normalized)
    let parsed = try! @json.parse(text_model_harness_json(model))
    guard parsed is { "text": String(harness_text), .. } else {
      fail("expected harness text field")
    }
    assert_eq(harness_text, normalized)
    model.dispose()
  }
}

///|
/// The browser-side provider receives a viewport-local range, but the remote
/// protocol deliberately asks the server for document-wide hints by URI and
/// revision. Exercise that seam with constructor input containing both CRLF
/// and lone CR so the request is issued from an LF-normalized model.
async test "remote inlay hints request is model-wide after EOL normalization" {
  assert_eq(pending_requests.length(), 0)
  let previous_send = protocol_send.val
  defer {
    protocol_send.val = previous_send
    fail_pending_requests("remote inlay hints test cleanup")
  }
  let uri = eol_boundary_uri()
  let model = @model.TextModel(
    uri, "eol-boundary.mbt", "moonbit", 7, "revision-eol-7", "first\r\nsecond\rtail",
  )
  defer model.dispose()
  assert_eq(model.get_value(), "first\nsecond\ntail")
  let observed : Array[@remote_protocol.DocumentRevisionRequest] = []
  let sent : @aqueue.Queue[@remote_protocol.ClientPacket] = Queue(
    kind=Unbounded,
  )
  protocol_send.val = Some(packet => ignore(try! sent.try_put(packet)))
  let client = RemoteLanguageClient::{ log_service: @log.LogService::new() }
  let local_range = @base_common.OffsetRange(1, 3)
  assert_true(local_range.start > 0)
  assert_true(local_range.end_exclusive < model.get_value_length())
  let hints = @async.with_task_group() <| group => {
    let request_task = group.spawn(() => {
      client.provide_inlay_hints(
        model,
        // This intentionally excludes most of the normalized model. The
        // protocol packet has no range field: the server owns whole-document
        // hint discovery.
        local_range,
        @language.CancellationToken::new(),
      )
    })
    match sent.get() {
      InlayHints(request) => {
        observed.push(request)
        assert_true(pending_requests.contains(request.id))
        assert_true(
          resolve_pending_response(
            InlayHintsResult({
              id: request.id,
              uri: request.uri,
              revision: request.document_revision,
              inlay_hints: [],
            }),
          ),
        )
        assert_false(pending_requests.contains(request.id))
      }
      _ => fail("expected an InlayHints request")
    }
    request_task.wait()
  }
  assert_true(hints.is_empty())
  assert_eq(observed.length(), 1)
  assert_eq(observed[0].uri.to_string(), uri.to_string())
  assert_eq(observed[0].document_revision, "revision-eol-7")
  assert_true(observed[0].id.has_prefix("inlay-hints-"))
  assert_eq(pending_requests.length(), 0)
}
