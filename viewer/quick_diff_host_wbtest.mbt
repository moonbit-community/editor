// Headless end-to-end tests for the quick-diff contribution: service
// original → piediff-backed computer → gutter decorations on the model,
// through the registered `quickDiff.decorator` contribution.

///|
/// The gutter decorations the quick-diff contribution currently maintains on
/// the viewer's model, rendered `"<range> <linesDecorationsClassName>"`.
fn quick_diff_gutter_decorations(viewer : Viewer) -> Array[String] {
  guard viewer.get_model() is Some(model) else { return [] }
  let rendered : Array[String] = []
  for decoration in model.get_all_decorations() {
    match decoration.options.lines_decorations_class_name {
      Some(class_name) =>
        if class_name.contains("dirty-diff") {
          rendered.push(decoration.range.to_string() + " " + class_name)
        }
      None => ()
    }
  }
  rendered
}

///|
test "quick diff: stored original decorates the gutter on model attach" {
  let services = ViewerServices::new()
  let viewer = Viewer::Viewer(services~)
  let resource = try! @base_common.Uri::from(
    scheme="inmemory",
    authority="model",
    path="/test-model",
  )
  services.quick_diff.set_original_content(
    resource,
    Some(["a", "old", "b", "tail"].join("\n")),
  )
  // test_model builds its TextModel on the same inmemory://model/test-model
  // resource the service was primed with.
  viewer.set_model(Some(test_model("a\nnew\nb\ninserted\ntail")))
  assert_eq(
    quick_diff_gutter_decorations(viewer).join("; "),
    "[2,1 -> 2,1] dirty-diff-glyph dirty-diff-modified primary; " +
    "[4,1 -> 4,1] dirty-diff-glyph dirty-diff-added primary",
  )
  viewer.dispose()
}

///|
test "quick diff: original arriving after attach updates, clearing removes" {
  let services = ViewerServices::new()
  let viewer = Viewer::Viewer(services~)
  let resource = try! @base_common.Uri::from(
    scheme="inmemory",
    authority="model",
    path="/test-model",
  )
  viewer.set_model(Some(test_model("a\nb")))
  assert_eq(quick_diff_gutter_decorations(viewer).length(), 0)
  // The service event re-decorates the already-attached model. The
  // decorator requests the MAX_VALUE column and the model validates it down
  // to the end of line 1 ("a" → column 2), as Monaco's deltaDecorations
  // does.
  services.quick_diff.set_original_content(resource, Some("a\nx\nb"))
  assert_eq(
    quick_diff_gutter_decorations(viewer).join("; "),
    "[1,2 -> 1,2] dirty-diff-glyph dirty-diff-deleted primary",
  )
  // Clearing the original clears the gutter.
  services.quick_diff.set_original_content(resource, None)
  assert_eq(quick_diff_gutter_decorations(viewer).length(), 0)
  viewer.dispose()
}

///|
test "quick diff: an original for another resource does not decorate" {
  let services = ViewerServices::new()
  let viewer = Viewer::Viewer(services~)
  let other = try! @base_common.Uri::from(
    scheme="inmemory",
    authority="model",
    path="/other-model",
  )
  viewer.set_model(Some(test_model("a\nb")))
  services.quick_diff.set_original_content(other, Some("a\nx\nb"))
  assert_eq(quick_diff_gutter_decorations(viewer).length(), 0)
  viewer.dispose()
}

///|
test "quick diff: identical original decorates nothing" {
  let services = ViewerServices::new()
  let viewer = Viewer::Viewer(services~)
  let resource = try! @base_common.Uri::from(
    scheme="inmemory",
    authority="model",
    path="/test-model",
  )
  services.quick_diff.set_original_content(resource, Some("a\nb"))
  viewer.set_model(Some(test_model("a\nb")))
  assert_eq(quick_diff_gutter_decorations(viewer).length(), 0)
  viewer.dispose()
}
