///|
/// Model-level features requested after a fresh render: diagnostics,
/// symbols, semantic tokens, folding ranges, and inlay hints, each resolving
/// independently.
fn Viewer::request_model_features(
  self : Viewer,
  model : @model.TextModel,
) -> Unit {
  @js.async_run(() => {
    // `set_diagnostics` fires the marker-change event, which the viewer turns
    // into a render refresh via `on_did_change_marker_decorations` (plan E); no
    // explicit re-render is needed here.
    self.services.languages.diagnostics_for_model(
      model,
      (owner, diagnostics) => {
        self.services.markers.set_diagnostics(owner, model.uri, diagnostics)
      },
      self.services.log_service,
    )
  })
  @js.async_run(() => {
    let symbols = self.services.languages.document_symbols(
      model,
      self.services.log_service,
    )
    if self.is_current_model(model) {
      self.provider_result = { ..self.provider_result, symbols, }
      self.render_feature_update()
    }
  })
  @js.async_run(() => {
    let provider_ranges = self.services.languages.folding_ranges_for_model(
      model,
      self.services.log_service,
    )
    // Apply the indent-based fallback here (the folding controller), mirroring
    // Monaco's FoldingController falling back to `indentRangeProvider` when no
    // language provider yields ranges.
    let folding_ranges = if provider_ranges.length() > 0 {
      provider_ranges
    } else {
      @folding.fallback_folding_ranges(model)
    }
    if self.is_current_model(model) {
      self.set_folding_ranges(folding_ranges)
    }
  })
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
