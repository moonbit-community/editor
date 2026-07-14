// The hidden-areas slice of Monaco's `codeEditorWidget.ts` (vscode submodule
// commit b18492a288de038fbc7643aae6de8247029d11bd): `setHiddenAreas` (:637).
// The folding contrib is the producer; hidden lines fold out of the view
// axis entirely.

///|
/// `setHiddenAreas` (`codeEditorWidget.ts:637-639`): hides the given model
/// line ranges from the view, keyed by `source` so independent features
/// merge rather than clobber each other. A changed view-line mapping
/// re-flushes the layout and emits Monaco's typed `ViewFlushedEvent`/
/// `ViewLineMappingChangedEvent` fan-out at the source.
fn Viewer::set_hidden_areas(
  self : Viewer,
  ranges : Array[@base_common.Range],
  source? : String = "",
  force_update? : Bool = false,
) -> Unit {
  guard self.get_view_model() is Some(view_model) else { return }
  guard self.get_model() is Some(model) else { return }
  let previous_view_selection : Ref[@core.Selection?] = Ref(None)
  if view_model.set_hidden_areas(
      ranges,
      source~,
      force_update~,
      with_event_batch=mutation => {
        // The unchanged gate runs before this source-shaped owner seam. Once
        // entered, cleanup-safe collection covers mutation, mapping/cursor
        // events, layout flush, recovery Scroll, and root bookkeeping.
        let event_batch = self.begin_view_event_batch()
        defer end_view_event_batch(event_batch)
        previous_view_selection.val = Some(
          view_model.cursor.get_view_selection(),
        )
        let changed = mutation()
        if changed {
          self.on_line_mapping_changed(
            view_model,
            model,
            notify_view=false,
            layout_already_applied=true,
          )
        }
        changed
      },
      on_line_mapping_changed=reproject_cursor => {
        // Pinned order inside one collector: Flushed → Mapping → Decorations →
        // cursor reprojection/event → layout flush/recovery Scroll.
        self.emit_view_event(ViewFlushed)
        self.emit_view_event(ViewLineMappingChanged)
        self.emit_view_event(
          ViewDecorationsChanged(@view.ViewDecorationsChangedEvent::all()),
        )
        reproject_cursor()
        match previous_view_selection.val {
          Some(previous) =>
            self.emit_view_cursor_reprojection(view_model, previous)
          None => ()
        }
      },
    ) {
    self.schedule_render()
  }
}
