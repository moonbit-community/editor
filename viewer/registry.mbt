///|
/// Model-level features requested after a fresh render. Only inlay hints
/// resolve here: diagnostics are push-only — whoever owns them feeds
/// `services.markers` (Monaco's `setModelMarkers`), and the marker-change
/// event drives the render refresh.
fn Viewer::request_model_features(
  self : Viewer,
  model : @model.TextModel,
) -> Unit {
  @js.async_run(() => {
    let inlay_hints = self.services.languages.inlay_hints_for_model(
      model,
      self.services.log_service,
    )
    if self.is_current_model(model) {
      // The hints render as `after` injected-text decorations (Track F);
      // the decoration-change event carries `affects_injected_text`, which
      // rebuilds the projection — no explicit feature re-render here. The
      // raw hints stay on the viewer for hover tooltip lookup.
      self.inlay_hints = inlay_hints
      self.sync_inlay_hint_decorations()
    }
  })
}
