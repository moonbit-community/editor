// Tests for the hidden-areas (folding) machinery: the projected line
// collection's `setHiddenAreas` (`viewModelLines.ts:174`) and the view
// model's per-source merge (`viewModelImpl.ts:592`).

///|
fn hidden_test_model() -> @view_model.ViewModel {
  ViewModel(
    // 8 lines, distinct content so view-line assertions read clearly.
    plain_text_model("line1\nline2\nline3\nline4\nline5\nline6\nline7\nline8"),
  )
}

///|
test "set_hidden_areas removes lines from the view axis" {
  let view_model = hidden_test_model()
  assert_eq(view_model.line_count(), 8)
  let changed = view_model.set_hidden_areas([Range(3, 1, 5, 1)])
  assert_true(changed)
  assert_eq(view_model.line_count(), 5)
  let lines = view_model.lines()
  assert_eq(lines.get_view_line_content(2), "line2")
  assert_eq(lines.get_view_line_content(3), "line6")
  assert_eq(lines.get_view_line_content(5), "line8")
  debug_inspect(
    view_model.get_hidden_areas(),
    content=(
      #|[
      #|  {
      #|    start_line_number: 3,
      #|    start_column: 1,
      #|    end_line_number: 5,
      #|    end_column: 1,
      #|  },
      #|]
    ),
  )
}

///|
test "set_hidden_areas is idempotent and unhides on empty" {
  let view_model = hidden_test_model()
  assert_true(view_model.set_hidden_areas([Range(2, 1, 3, 1)]))
  // Same ranges again: no change.
  assert_false(view_model.set_hidden_areas([Range(2, 1, 3, 1)]))
  assert_eq(view_model.line_count(), 6)
  // Clearing restores every line.
  assert_true(view_model.set_hidden_areas([]))
  assert_eq(view_model.line_count(), 8)
  assert_eq(view_model.get_hidden_areas().length(), 0)
}

///|
test "overlapping and touching ranges normalize into one hidden area" {
  let view_model = hidden_test_model()
  // [2..3] and [4..5] touch; [5..6] overlaps — all merge to [2..6].
  assert_true(
    view_model.set_hidden_areas([
      Range(4, 1, 5, 1),
      Range(2, 1, 3, 1),
      Range(5, 1, 6, 1),
    ]),
  )
  debug_inspect(
    view_model.get_hidden_areas(),
    content=(
      #|[
      #|  {
      #|    start_line_number: 2,
      #|    start_column: 1,
      #|    end_line_number: 6,
      #|    end_column: 1,
      #|  },
      #|]
    ),
  )
  assert_eq(view_model.line_count(), 3)
}

///|
test "sources merge independently and clear independently" {
  let view_model = hidden_test_model()
  assert_true(
    view_model.set_hidden_areas([Range(2, 1, 3, 1)], source="folding"),
  )
  assert_true(view_model.set_hidden_areas([Range(6, 1, 7, 1)], source="other"))
  assert_eq(view_model.line_count(), 4)
  debug_inspect(
    view_model.get_hidden_areas(),
    content=(
      #|[
      #|  {
      #|    start_line_number: 2,
      #|    start_column: 1,
      #|    end_line_number: 3,
      #|    end_column: 1,
      #|  },
      #|  {
      #|    start_line_number: 6,
      #|    start_column: 1,
      #|    end_line_number: 7,
      #|    end_column: 1,
      #|  },
      #|]
    ),
  )
  // Clearing one source keeps the other's lines hidden.
  assert_true(view_model.set_hidden_areas([], source="folding"))
  assert_eq(view_model.line_count(), 6)
  debug_inspect(
    view_model.get_hidden_areas(),
    content=(
      #|[
      #|  {
      #|    start_line_number: 6,
      #|    start_column: 1,
      #|    end_line_number: 7,
      #|    end_column: 1,
      #|  },
      #|]
    ),
  )
}

///|
test "hiding every line reveals everything" {
  let view_model = hidden_test_model()
  assert_true(view_model.set_hidden_areas([Range(1, 1, 8, 1)]))
  // Cannot have everything be hidden => reveal everything!
  assert_eq(view_model.line_count(), 8)
  assert_eq(view_model.get_hidden_areas().length(), 0)
}

///|
test "model positions inside a hidden area convert to the nearest visible view line" {
  let view_model = hidden_test_model()
  assert_true(view_model.set_hidden_areas([Range(3, 1, 5, 1)]))
  let lines = view_model.lines()
  // A position on hidden line 4 walks up to visible line 2's end.
  let up = lines.convert_model_position_to_view_position(4, 1)
  debug_inspect(
    up,
    content=(
      #|{ line_number: 2, column: 6 }
    ),
  )
  // ... or down to line 6's start with `below_hidden_ranges`.
  let down = lines.convert_model_position_to_view_position(
    4,
    1,
    below_hidden_ranges=true,
  )
  debug_inspect(
    down,
    content=(
      #|{ line_number: 3, column: 1 }
    ),
  )
  // Visible lines stay bijective: model line 6 is view line 3.
  let visible = lines.convert_model_position_to_view_position(6, 2)
  debug_inspect(
    visible,
    content=(
      #|{ line_number: 3, column: 2 }
    ),
  )
  assert_eq(lines.convert_view_position_to_model_position(3, 2).line_number, 6)
  // Visibility probes.
  assert_false(lines.model_position_is_visible(4))
  assert_true(lines.model_position_is_visible(6))
  assert_false(view_model.model_position_is_visible(Position(4, 1)))
}

///|
test "to_model_visible_ranges splits the viewport around hidden areas" {
  let view_model = hidden_test_model()
  assert_true(view_model.set_hidden_areas([Range(3, 1, 5, 1)]))
  // All 5 remaining view lines: model lines 1-2 and 6-8.
  let ranges = view_model.to_model_visible_ranges(Range(1, 1, 5, 6))
  debug_inspect(
    ranges,
    content=(
      #|[
      #|  {
      #|    start_line_number: 1,
      #|    start_column: 1,
      #|    end_line_number: 2,
      #|    end_column: 6,
      #|  },
      #|  {
      #|    start_line_number: 6,
      #|    start_column: 1,
      #|    end_line_number: 8,
      #|    end_column: 6,
      #|  },
      #|]
    ),
  )
}

///|
test "hidden areas survive a wrapping reflow" {
  let model = plain_text_model(
    "line1\nline2\nline3 is much longer than the wrap column\nline4",
  )
  let view_model = @view_model.ViewModel::with_options(
    model,
    @view_model.ViewModelOptions::no_wrap(),
  )
  assert_true(view_model.set_hidden_areas([Range(2, 1, 2, 1)]))
  assert_eq(view_model.line_count(), 3)
  // Reflow to a narrow wrap column: line 3 wraps, line 2 stays hidden.
  assert_true(
    view_model.on_configuration_changed(
      @view_model.ViewModelOptions::soft_wrap(10),
    ),
  )
  debug_inspect(
    view_model.get_hidden_areas(),
    content=(
      #|[
      #|  {
      #|    start_line_number: 2,
      #|    start_column: 1,
      #|    end_line_number: 2,
      #|    end_column: 1,
      #|  },
      #|]
    ),
  )
  let lines = view_model.lines()
  assert_eq(lines.get_view_line_content(1), "line1")
  // View line 2 is the first segment of wrapped model line 3.
  assert_eq(lines.convert_view_position_to_model_position(2, 1).line_number, 3)
  assert_false(lines.model_position_is_visible(2))
}
