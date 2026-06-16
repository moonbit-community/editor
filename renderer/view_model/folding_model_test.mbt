///|
test "folding model normalizes folded ranges into hidden line spans" {
  let model = @view_model.FoldingModel::from_folded_ranges(
    [FoldingRange(5, 5), FoldingRange(0, 3), FoldingRange(8, 99)],
    10,
  )
  let ranges = model.folding_ranges()
  assert_eq(ranges.length(), 2)
  assert_eq(ranges[0].start_line_number, 1)
  assert_eq(ranges[0].end_line_number, 3)
  assert_eq(ranges[1].start_line_number, 8)
  assert_eq(ranges[1].end_line_number, 10)
  let hidden = model.hidden_ranges()
  assert_eq(hidden.length(), 2)
  assert_true(hidden[0] == HiddenRange(2, 3))
  assert_true(hidden[1] == HiddenRange(9, 10))
  assert_true(model.is_line_hidden(2))
  assert_true(!model.is_line_hidden(4))
  assert_eq(model.visible_line_count(10), 6)
}

///|
test "folding model merges nested and overlapping hidden ranges" {
  let model = @view_model.FoldingModel::from_folded_ranges(
    [
      FoldingRange(3, 5, kind=Region),
      FoldingRange(1, 10),
      FoldingRange(8, 12, kind=Comment),
    ],
    12,
  )
  let ranges = model.folding_ranges()
  assert_eq(ranges.length(), 3)
  assert_eq(ranges[0].start_line_number, 1)
  assert_eq(ranges[0].end_line_number, 10)
  let hidden = model.hidden_ranges()
  assert_eq(hidden.length(), 1)
  assert_true(hidden[0] == HiddenRange(2, 12))
  assert_true(model.is_line_hidden(8))
  assert_true(!model.is_line_hidden(1))
  assert_eq(model.visible_line_count(12), 1)
}
