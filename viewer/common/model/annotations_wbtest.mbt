///| Branch evidence for the model-owned syntactic font carrier.

///|
test "AnnotationsUpdate.create retains absent empty and nonempty font updates" {
  let option : FontTokenOption = {
    font_family: Some("Mono"),
    font_size_multiplier: Some(1.25),
    line_height_multiplier: Some(1.5),
  }
  let updates : Array[AnnotationUpdate[FontTokenOption]] = [
    { range: OffsetRange(1, 4), annotation: Some(option) },
    { range: OffsetRange(7, 9), annotation: None },
  ]
  let absent : FontTokensUpdate = AnnotationsUpdate::create([])
  assert_true(absent.annotations().is_empty())
  let wrapped : FontTokensUpdate = AnnotationsUpdate::create(updates)
  let actual = wrapped.annotations()
  assert_eq(actual.length(), 2)
  assert_eq(actual[0].range.start, 1)
  assert_eq(actual[0].range.end_exclusive, 4)
  guard actual[0].annotation is Some(actual_option) else {
    fail("expected a nonempty font option")
  }
  assert_true(actual_option.font_family == Some("Mono"))
  assert_true(actual_option.font_size_multiplier == Some(1.25))
  assert_true(actual_option.line_height_multiplier == Some(1.5))
  assert_eq(actual[1].range.start, 7)
  assert_eq(actual[1].range.end_exclusive, 9)
  assert_true(actual[1].annotation is None)
}

///|
test "ModelFontTokensChangedEvent preserves the exact update value" {
  let changes : FontTokensUpdate = AnnotationsUpdate::create([])
  let event : ModelFontTokensChangedEvent = { changes, }
  assert_true(event.changes.annotations().is_empty())
}
