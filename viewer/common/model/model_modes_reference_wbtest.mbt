///| Conformance port from
/// `vscode/src/vs/editor/test/common/model/model.modes.test.ts` at
/// `b18492a288de038fbc7643aae6de8247029d11bd`.

///|
fn model_modes_part(calls : Array[String]) -> TokenizationTextModelPart {
  let lines = ["1", "2", "3", "4", "5"]
  let model_state = test_tokenization_model_state(
    lines,
    "modelModeTest1",
    Ref(0),
    false,
    Ref(false),
    Ref(None),
    _ => (),
  )
  TokenizationTextModelPart::new_with_support_resolver(
    model_state,
    AttachedViews(),
    _ => Some(logging_support(calls, Ref(0))),
  )
}

///|
test "model calls syntax highlighter 1" {
  let calls : Array[String] = []
  let part = model_modes_part(calls)
  part.force_tokenization(1)
  assert_eq(calls.length(), 1)
  assert_true(calls[0].has_prefix("1:true:"))
}

///|
test "model calls syntax highlighter 2" {
  let calls : Array[String] = []
  let part = model_modes_part(calls)
  part.force_tokenization(2)
  assert_eq(calls.length(), 2)
  assert_true(calls[0].has_prefix("1:true:"))
  assert_true(calls[1].has_prefix("2:true:"))
  calls.clear()
  part.force_tokenization(2)
  assert_true(calls.is_empty())
}

///|
test "model caches states" {
  let calls : Array[String] = []
  let part = model_modes_part(calls)
  for line_number in 1..<=5 {
    calls.clear()
    part.force_tokenization(line_number)
    assert_eq(calls.length(), 1)
    assert_true(calls[0].has_prefix("\{line_number}:true:"))
  }
  calls.clear()
  part.force_tokenization(5)
  assert_true(calls.is_empty())
}

// SKIPPED: model invalidates states for one line insert — readonly Viewer has no incremental edit API.
// SKIPPED: model invalidates states for many lines insert — readonly Viewer has no incremental edit API.
// SKIPPED: model invalidates states for one new line — readonly Viewer has no incremental edit API.
// SKIPPED: model invalidates states for one line delete — readonly Viewer has no incremental edit API.
// SKIPPED: model invalidates states for many lines delete — readonly Viewer has no incremental edit API.
// SKIPPED: getTokensForInvalidLines one text insert — readonly Viewer has no incremental edit API.
// SKIPPED: getTokensForInvalidLines two text insert — readonly Viewer has no incremental edit API.
// SKIPPED: getTokensForInvalidLines one multi-line text insert, one small text insert — readonly Viewer has no incremental edit API.
// SKIPPED: getTokensForInvalidLines one delete text — readonly Viewer has no incremental edit API.
// SKIPPED: getTokensForInvalidLines one line delete text — readonly Viewer has no incremental edit API.
// SKIPPED: getTokensForInvalidLines multiple lines delete text — readonly Viewer has no incremental edit API.
