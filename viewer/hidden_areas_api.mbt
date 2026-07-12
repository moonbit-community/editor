// The hidden-areas slice of Monaco's `codeEditorWidget.ts` (vscode submodule
// commit 294fb350837dbaee37b949533fead4df4e0e8971): `setHiddenAreas` (:637).
// The folding contrib is the producer; hidden lines fold out of the view
// axis entirely.

///|
/// `setHiddenAreas` (`codeEditorWidget.ts:637-639`): hides the given model
/// line ranges from the view, keyed by `source` so independent features
/// merge rather than clobber each other. A changed view-line mapping
/// re-flushes the layout and emits Monaco's typed `ViewFlushedEvent`/
/// `ViewLineMappingChangedEvent` fan-out at the source.
pub fn Viewer::set_hidden_areas(
  self : Viewer,
  ranges : Array[@base_common.Range],
  source? : String = "",
  force_update? : Bool = false,
) -> Unit {
  guard self.get_view_model() is Some(view_model) else { return }
  guard self.get_model() is Some(model) else { return }
  let previous_view_selection = view_model.cursor.get_view_selection()
  if view_model.set_hidden_areas(ranges, source~, force_update~) {
    self.on_line_mapping_changed(view_model, model, previous_view_selection~)
    self.schedule_render()
  }
}
