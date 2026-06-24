///|
/// Controllers resolve features through the registry with async runs;
/// each result is tagged with the requesting model (URI plus version)
/// and the hover anchor token so stale responses are dropped at handling.
fn Viewer::request_hover(
  self : Viewer,
  anchor : HoverAnchor,
  token : Int,
) -> Unit {
  match self.text_model {
    Some(model) => {
      let hover_services : @hover.HoverParticipantServices = {
        languages: self.services.languages,
        marker_decorations: self.services.marker_decorations,
        log_service: self.services.log_service,
      }
      let computer = @hover.ContentHoverComputer::new(hover_services)
      let anchor_range = @base_common.Range(anchor.start, anchor.end)
      match
        computer.compute_sync(
          model,
          anchor_range,
          anchor.offset,
          injected_text_index=anchor.injected_text_index,
          inlay_hints=self.inlay_hints,
        ) {
        Some(hover) => self.hover_resolved(model, token, Some(hover))
        None => ()
      }
      @js.async_run(() => {
        let hover = computer.compute_async(
          model,
          anchor_range,
          anchor.offset,
          injected_text_index=anchor.injected_text_index,
          inlay_hints=self.inlay_hints,
        )
        self.hover_resolved(model, token, hover)
      })
    }
    None => ()
  }
}

///|
/// Model-level features requested after a fresh render: diagnostics,
/// symbols, semantic tokens, folding ranges, and inlay hints, each resolving
/// independently.
fn Viewer::request_model_features(
  self : Viewer,
  model : @model.TextModel,
) -> Unit {
  @js.async_run(() => {
    self.services.languages.diagnostics_for_model(
      model,
      (owner, diagnostics) => {
        self.services.markers.set_diagnostics(owner, model.uri, diagnostics)
      },
      self.services.log_service,
    )
    if self.is_current_model(model) {
      self.render_feature_update()
    }
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
    let semantic_tokens = self.services.languages.semantic_tokens_for_model(
      model,
      self.services.log_service,
    )
    if self.is_current_model(model) {
      self.provider_result = { ..self.provider_result, semantic_tokens, }
      self.render_feature_update()
    }
  })
  @js.async_run(() => {
    let folding_ranges = self.services.languages.folding_ranges_for_model(
      model,
      self.services.log_service,
    )
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
      self.inlay_hints = inlay_hints
      self.render_feature_update()
    }
  })
}
