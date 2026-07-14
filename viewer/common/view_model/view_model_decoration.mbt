///|
/// Faithful 1:1 port of Monaco's
/// `viewModel/viewModelDecoration.ts` declarations used by the viewer, from
/// vscode submodule commit b18492a288de038fbc7643aae6de8247029d11bd.
///
/// A model decoration resolved into view coordinates (Monaco
/// `ViewModelDecoration`).
pub(all) struct RelocatedViewModelDecoration[O] {
  range : @base_common.Range
  options : O
}

///|
/// Builds a view-model decoration.
pub fn[O] RelocatedViewModelDecoration::new(
  range : @base_common.Range,
  options : O,
) -> RelocatedViewModelDecoration[O] {
  { range, options }
}

///|
/// Whether a model decoration is visible. See the inline-decoration file
/// deviation: the comment/string-token hiding paths are not ported (no
/// tokenization seam, and unused by the suite), so this is always `true`.
pub fn[O, M] is_model_decoration_visible(
  _model : M,
  _decoration : ModelDecoration[O],
) -> Bool {
  true
}
