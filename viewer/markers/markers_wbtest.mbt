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
