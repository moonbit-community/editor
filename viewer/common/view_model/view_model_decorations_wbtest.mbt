///|
/// The TRANSITIONAL `className`-span clip (`class_name_columns_on_view_line`,
/// see `view_line_data.mbt`): Monaco's `showIfCollapsed` forces a collapsed
/// span one column wide (the squiggle on an empty range / at EOL).
test "class_name_columns_on_view_line forces a 1ch span when show_if_collapsed" {
  fn clip(
    start_column : Int,
    end_column : Int,
    show_if_collapsed : Bool,
  ) -> (Int, Int)? {
    class_name_columns_on_view_line(
      Range(1, start_column, 1, end_column),
      show_if_collapsed,
      1,
      10,
    )
  }

  // collapsed range, show_if_collapsed → one column wide
  assert_true(clip(3, 3, true) == Some((3, 4)))
  // collapsed range without the flag → nothing
  assert_true(clip(3, 3, false) is None)
  // collapsed at EOL (column == max_column) still renders 1ch
  assert_true(clip(10, 10, true) == Some((10, 11)))
  // a non-collapsed span is unchanged
  assert_true(clip(2, 5, true) == Some((2, 5)))
}
