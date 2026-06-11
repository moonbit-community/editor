///|
fn test_uri() -> @workspace.DocumentUri {
  match
    @workspace.DocumentUri::parse("readonly-remote://workspace/src/main.mbt") {
    ParsedDocumentUri(uri) => uri
    DocumentUriError(_) => panic()
  }
}

///|
test "crossing in-flight responses resolve their own requests" {
  let first = next_request_id("hover")
  let second = next_request_id("hover")
  let resolved : Array[String] = []
  pending_requests[first] = packet => resolved.push(
    "first<-" + server_packet_request_id(packet),
  )
  pending_requests[second] = packet => resolved.push(
    "second<-" + server_packet_request_id(packet),
  )
  // The second request answers before the first: ids keep them apart.
  assert_true(
    resolve_pending_response(
      HoverResult({ id: second, uri: test_uri(), version: 2, hover: None }),
    ),
  )
  assert_true(
    resolve_pending_response(
      HoverResult({ id: first, uri: test_uri(), version: 1, hover: None }),
    ),
  )
  debug_inspect(
    resolved,
    content=(
      #|["second<-hover-2", "first<-hover-1"]
    ),
  )
  // Each entry resolves exactly once.
  assert_false(
    resolve_pending_response(
      HoverResult({ id: first, uri: test_uri(), version: 1, hover: None }),
    ),
  )
  assert_eq(pending_requests.length(), 0)
}

///|
test "push packets without a pending id fall through" {
  assert_false(
    resolve_pending_response(
      DocumentChanged({
        id: "watch:readonly-remote://workspace/src/main.mbt",
        document: SourceDocument(
          test_uri(),
          "main.mbt",
          "moonbit",
          1,
          "rev",
          "fn main {}",
        ),
      }),
    ),
  )
  assert_false(resolve_pending_response(RemoteError(
    ProtocolError(ProtocolProviderError, "boom"),
  )))
}

///|
test "stale hover results are dropped by version and token guards" {
  let controller = HoverController::empty()
  let hover : @language.Hover? = Some({
    range: Range(3, 7),
    contents: "fn main",
  })
  // Version moved on: result dropped.
  let (_, stale_version) = controller.resolved_hover(1, 0, hover, 2)
  assert_true(stale_version.view is None && stale_version.pending_view is None)
  // Anchor token moved on: result dropped.
  let rescheduled = { ..controller, token: 5 }
  let (_, stale_token) = rescheduled.resolved_hover(2, 4, hover, 2)
  assert_true(stale_token.view is None && stale_token.pending_view is None)
  // Current version and token: result lands behind the display gate.
  let (_, fresh) = rescheduled.resolved_hover(2, 5, hover, 2)
  assert_true(fresh.pending_view is Some(_))
  let opened = { ..rescheduled, display_open: true }
  let (_, shown) = opened.resolved_hover(2, 5, hover, 2)
  assert_true(shown.view is Some(_))
}
