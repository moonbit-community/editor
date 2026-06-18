///|
fn test_document() -> @workspace.DocumentSnapshot {
  DocumentSnapshot(
    @base_common.Uri::memory("service-test.mbt"),
    "service-test.mbt",
    "moonbit",
    "rev-7",
    "fn main {\n  value\n}\n",
  )
}

///|
test "marker service replaces owner resource and supports limits" {
  let service = MarkerService::new()
  let uri = @base_common.Uri::memory("markers.mbt")
  service.set_diagnostics("owner-a", uri, [
    { range: Range(0, 1), severity: Warning, message: "first" },
    { range: Range(2, 3), severity: Error, message: "second" },
  ])
  service.set_diagnostics("owner-b", uri, [
    { range: Range(4, 5), severity: Info, message: "third" },
  ])
  assert_eq(service.markers_for_resource(uri).length(), 3)
  service.set_diagnostics("owner-a", uri, [
    { range: Range(6, 7), severity: Warning, message: "replacement" },
  ])
  let markers = service.markers_for_resource(uri)
  assert_eq(markers.length(), 2)
  assert_eq(service.markers_for_resource(uri, limit=1).length(), 1)
  assert_true(markers[0].owner == "owner-b")
  assert_true(markers[1].message == "replacement")
}

///|
test "marker decorations expose squiggles and marker hover lookup" {
  let markers = MarkerService::new()
  let uri = @base_common.Uri::memory("decorations.mbt")
  markers.set_diagnostics("owner", uri, [
    { range: Range(2, 8), severity: Warning, message: "diagnostic" },
  ])
  let decorations = MarkerDecorationsService::new(markers)
  let set = decorations.decorations_for_resource(uri)
  assert_eq(set.items.length(), 1)
  assert_true(set.items[0].class_name == "diag-warning")
  let hovered = decorations.markers_at(uri, Range(4, 5))
  assert_eq(hovered.length(), 1)
  assert_true(hovered[0].message == "diagnostic")
}

///|
async test "content hover computer separates sync markers from async markdown" {
  let services = ViewerServices::new()
  let document = test_document()
  services.markers.set_diagnostics("diagnostics:0", document.uri, [
    { range: Range(12, 17), severity: Warning, message: "marker hover" },
  ])
  services.language_features.register_hover_provider(LanguageId("moonbit"), TestHoverProvider::{

  })
  |> ignore
  let computer = ContentHoverComputer::new(services)
  let sync_hover = computer.compute_sync(document, Range(12, 17), 14)
  match sync_hover {
    Some(hover) => {
      assert_eq(hover.parts.length(), 1)
      assert_true(hover.parts[0] is MarkerHover(_))
    }
    None => fail("expected marker hover")
  }
  let async_hover = computer.compute_async(document, Range(12, 17), 14)
  match async_hover {
    Some(hover) => {
      assert_eq(hover.parts.length(), 1)
      assert_true(hover.parts[0] is MarkdownHover(_))
    }
    None => fail("expected markdown hover")
  }
}

///|
async test "provider failures are logged and isolated" {
  let memory = @log.MemoryLogger::new()
  let services = ViewerServices::new(
    log_service=@log.LogService::new(logger=memory),
  )
  services.language_features.register_hover_provider(LanguageId("moonbit"), FailingHoverProvider::{

  })
  |> ignore
  services.language_features.register_hover_provider(LanguageId("moonbit"), TestHoverProvider::{

  })
  |> ignore
  let document = test_document()
  let hover = services.language_features.hover_at(document, 3)
  assert_true(hover is Some(_))
  let entries = memory.entries()
  assert_eq(entries.length(), 1)
  assert_true(entries[0].category == "language.hover")
  assert_true(entries[0].details[2] == ("providerIndex", "0"))
}

///|
priv struct TestHoverProvider {}

///|
impl @language.HoverProvider for TestHoverProvider with fn provide_hover(
  _self,
  document,
  position,
  _token,
) {
  let offset = document.offset_at_position(position)
  Some({
    range: Range(offset, offset + 1),
    contents: [PlainText("provider hover")],
  })
}

///|
priv suberror TestProviderError {
  TestProviderError
}

///|
priv struct FailingHoverProvider {}

///|
impl @language.HoverProvider for FailingHoverProvider with fn provide_hover(
  _self,
  _document,
  _position,
  _token,
) {
  raise TestProviderError
}
