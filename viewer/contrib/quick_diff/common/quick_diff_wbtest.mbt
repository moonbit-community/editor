///|
fn test_change(
  original_start : Int,
  original_end : Int,
  modified_start : Int,
  modified_end : Int,
) -> @diff.Change {
  {
    original_start_line_number: original_start,
    original_end_line_number: original_end,
    modified_start_line_number: modified_start,
    modified_end_line_number: modified_end,
  }
}

///|
test "get_change_type mirrors quickDiff.ts:121" {
  // originalEndLineNumber === 0 → Add
  assert_eq(get_change_type(test_change(1, 0, 2, 3)), ChangeType::Add)
  // modifiedEndLineNumber === 0 → Delete
  assert_eq(get_change_type(test_change(2, 4, 1, 0)), ChangeType::Delete)
  assert_eq(get_change_type(test_change(2, 2, 2, 2)), ChangeType::Modify)
}

///|
test "quick diff service stores, clears, and reports originals per resource" {
  let service = QuickDiffService::new()
  let a = try! @base_common.Uri::from(
    scheme="inmemory",
    authority="model",
    path="/a.txt",
  )
  let b = try! @base_common.Uri::from(
    scheme="inmemory",
    authority="model",
    path="/b.txt",
  )
  let fired : Array[String] = []
  let listener = service.on_did_change_original(resource => {
    fired.push(resource.to_string())
  })
  assert_true(service.get_original_content(a) is None)
  service.set_original_content(a, Some("one\ntwo"))
  assert_eq(service.get_original_content(a).unwrap(), "one\ntwo")
  assert_true(service.get_original_content(b) is None)
  service.set_original_content(a, Some("three"))
  assert_eq(service.get_original_content(a).unwrap(), "three")
  service.set_original_content(a, None)
  assert_true(service.get_original_content(a) is None)
  assert_eq(fired.length(), 3)
  assert_eq(fired[0], a.to_string())
  listener.dispose()
  service.set_original_content(b, Some("x"))
  assert_eq(fired.length(), 3)
}
