///|
/// Builds error marker input matching Monaco's `randomMarkerData` shape
/// (line/col all 1), with a deterministic message.
fn marker_data(severity : MarkerSeverity, message : String) -> MarkerData {
  MarkerData::new(
    severity~,
    message~,
    start_line_number=1,
    start_column=1,
    end_line_number=1,
    end_column=1,
  )
}

///|
test "marker decorations expose squiggles and marker hover lookup" {
  let markers = MarkerService::new()
  let uri = @base_common.Uri::memory("decorations.mbt")
  let model = @model.TextModel(uri, "", "moonbit", 1, "rev", "diagnostic text here")
  markers.set_diagnostics("owner", uri, [
    { range: Range(1, 3, 1, 9), severity: Warning, message: "diagnostic" },
  ])
  let decorations = MarkerDecorationsService::new(markers)
  decorations.on_model_added(model)
  let set = decorations.decorations_for_resource(model)
  assert_eq(set.items.length(), 1)
  assert_true(set.items[0].class_name == "squiggly-warning")
  assert_true(set.items[0].range == Range(1, 3, 1, 9))
  // get_live_markers exposes the transformed range + marker for hover lookup.
  let live = decorations.get_live_markers(uri)
  assert_eq(live.length(), 1)
  let (range, marker) = live[0]
  assert_true(range == Range(1, 3, 1, 9))
  assert_true(marker.message == "diagnostic")
}

///|
test "marker service replaces owner resource and supports limits" {
  let service = MarkerService::new()
  let uri = @base_common.Uri::memory("markers.mbt")
  service.set_diagnostics("owner-a", uri, [
    { range: Range(1, 1, 1, 2), severity: Warning, message: "first" },
    { range: Range(1, 3, 1, 4), severity: Error, message: "second" },
  ])
  service.set_diagnostics("owner-b", uri, [
    { range: Range(1, 5, 1, 6), severity: Info, message: "third" },
  ])
  assert_eq(service.markers_for_resource(uri).length(), 3)
  service.set_diagnostics("owner-a", uri, [
    { range: Range(1, 7, 1, 8), severity: Warning, message: "replacement" },
  ])
  let markers = service.markers_for_resource(uri)
  assert_eq(markers.length(), 2)
  assert_eq(service.markers_for_resource(uri, limit=1).length(), 1)
}

///|
test "MarkerSeverity bit values and bridge" {
  // markers.ts:56 — load-bearing bit values.
  assert_eq(MarkerSeverity::Hint.value(), 1)
  assert_eq(MarkerSeverity::Info.value(), 2)
  assert_eq(MarkerSeverity::Warning.value(), 4)
  assert_eq(MarkerSeverity::Error.value(), 8)
  // compare = b - a (markers.ts:65)
  assert_eq(MarkerSeverity::compare(Error, Warning), 4 - 8)
  assert_true(
    MarkerSeverity::from_diagnostic_severity(Warning) ==
    Warning,
  )
}

///|
test "MarkerData sanitize clamps line/column and drops empty message" {
  let uri = @base_common.Uri::memory("sanitize.mbt")
  // empty message dropped (markerService.ts:238)
  assert_true(marker_data(Error, "").to_marker("o", uri) is None)
  // start/end clamping (markerService.ts:243-246)
  let raw = MarkerData::new(
    severity=Error,
    message="m",
    start_line_number=0,
    start_column=0,
    end_line_number=-3,
    end_column=0,
  )
  let marker = raw.to_marker("o", uri).unwrap()
  assert_eq(marker.start_line_number, 1)
  assert_eq(marker.start_column, 1)
  assert_eq(marker.end_line_number, 1)
  assert_eq(marker.end_column, 1)
}
