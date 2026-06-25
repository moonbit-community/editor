// Browser-side folding controls: the gutter toggle and the folded-state the
// viewer owns. The pure folded-range model lives in `viewer/folding`.

///|
fn Viewer::set_folding_ranges(
  self : Viewer,
  ranges : Array[@language.FoldingRange],
) -> Unit {
  self.folding_ranges = ranges
  self.folded_ranges = @folding.preserved_folded_ranges(self.folded_ranges, ranges)
  self.render_feature_update()
}

///|
fn Viewer::toggle_fold(self : Viewer, model_line_number : Int) -> Unit {
  match
    @folding.folding_range_for_start_line(self.folding_ranges, model_line_number) {
    Some(range) => {
      let (folded_ranges, changed) = @folding.toggled_folded_ranges(
        self.folded_ranges,
        range,
      )
      if changed {
        self.folded_ranges = folded_ranges
        self.dismiss_hover()
        self.render_feature_update()
      }
    }
    None => ()
  }
}
