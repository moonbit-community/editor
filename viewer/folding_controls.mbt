// Browser-side folding controls: the gutter toggle and the folded-state the
// viewer owns. The pure folded-range model lives in `viewer/folding`.

///|
/// `registerEditorContribution(FoldingController.ID, …, Eager)`
/// (`folding.ts:1246`, id `'editor.contrib.folding'`, `:70`). The folding
/// state lives inline on `Viewer` (`folding_ranges`/`folded_ranges`, the
/// closure-seam pattern) and the gutter toggle rides the render input's
/// `on_toggle_fold`, so the ctor wires nothing extra.
fn register_folding_contribution(registry : EditorContributionRegistry) -> Unit {
  registry.register_editor_contribution("editor.contrib.folding", Eager, _viewer => {
    id: "editor.contrib.folding",
    dispose: () => (),
  })
}

///|
fn Viewer::set_folding_ranges(
  self : Viewer,
  ranges : Array[@language.FoldingRange],
) -> Unit {
  self.folding_ranges = ranges
  self.folded_ranges = @folding.preserved_folded_ranges(
    self.folded_ranges,
    ranges,
  )
  self.render_feature_update()
}

///|
fn Viewer::toggle_fold(self : Viewer, model_line_number : Int) -> Unit {
  match
    @folding.folding_range_for_start_line(
      self.folding_ranges,
      model_line_number,
    ) {
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
