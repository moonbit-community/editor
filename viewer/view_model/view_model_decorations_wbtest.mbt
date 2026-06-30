///|
/// Builds a single-line view decoration for the collapse tests.
fn collapse_decoration(
  start_column : Int,
  end_column : Int,
  show_if_collapsed : Bool,
) -> ViewModelDecoration {
  {
    range: {
      start_line_number: 1,
      start_column,
      end_line_number: 1,
      end_column,
    },
    kind: Diagnostic,
    class_name: "squiggly-error",
    inline_class_name: None,
    show_if_collapsed,
  }
}

///|
test "columns_on_view_line forces a 1ch span when show_if_collapsed" {
  // collapsed range, show_if_collapsed → one column wide
  let collapsed = collapse_decoration(3, 3, true)
  assert_true(collapsed.columns_on_view_line(1, 10) == Some((3, 4)))
  // collapsed range without the flag → nothing
  let plain = collapse_decoration(3, 3, false)
  assert_true(plain.columns_on_view_line(1, 10) is None)
  // collapsed at EOL (column == max_column) still renders 1ch
  let at_eol = collapse_decoration(10, 10, true)
  assert_true(at_eol.columns_on_view_line(1, 10) == Some((10, 11)))
  // a non-collapsed span is unchanged
  let span = collapse_decoration(2, 5, true)
  assert_true(span.columns_on_view_line(1, 10) == Some((2, 5)))
}
