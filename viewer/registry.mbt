///|
/// Tokenization support by language id, the Monaco
/// `TokenizationRegistry` singleton: starts empty, and the host
/// registers the language packages it composed in at startup (the
/// workbench and embedders register `syntax/lang_*` lexers; this
/// package itself imports none). Unregistered languages render through
/// the plain fallback.
let tokenizer_registry : @syntax.TokenizerRegistry = @syntax.TokenizerRegistry::new()

///|
/// Registers a tokenizer with the browser viewer's process-wide tokenization
/// registry.
pub fn register_tokenizer(
  language_id : String,
  tokenizer : &@syntax.LineTokenizer,
) -> Unit {
  tokenizer_registry.register(language_id, tokenizer)
}

///|
/// Controllers resolve features through the registry with async runs;
/// each result is tagged with the requesting document snapshot (URI plus
/// revision)
/// and the hover anchor token so stale responses are dropped at handling.
fn Viewer::request_hover(
  self : Viewer,
  anchor : HoverAnchor,
  token : Int,
) -> Unit {
  match self.source_document {
    Some(document) => {
      let computer = ContentHoverComputer::new(self.services)
      let anchor_range = @base_common.Range(anchor.start, anchor.end)
      match
        computer.compute_sync(
          document,
          anchor_range,
          anchor.offset,
          injected_text_index=anchor.injected_text_index,
          inlay_hints=self.inlay_hints,
        ) {
        Some(hover) => self.hover_resolved(document, token, Some(hover))
        None => ()
      }
      @js.async_run(() => {
        let hover = computer.compute_async(
          document,
          anchor_range,
          anchor.offset,
          injected_text_index=anchor.injected_text_index,
          inlay_hints=self.inlay_hints,
        )
        self.hover_resolved(document, token, hover)
      })
    }
    None => ()
  }
}

///|
/// Document-level features requested after a fresh render: diagnostics,
/// symbols, semantic tokens, folding ranges, and inlay hints, each resolving
/// independently.
fn Viewer::request_document_features(
  self : Viewer,
  document : @workspace.DocumentSnapshot,
) -> Unit {
  @js.async_run(() => {
    self.services.language_features.diagnostics_for_document(document, (
      owner,
      diagnostics,
    ) => self.services.markers.set_diagnostics(owner, document.uri, diagnostics))
    if self.is_current_document(document) {
      self.render_feature_update()
    }
  })
  @js.async_run(() => {
    let symbols = self.services.language_features.document_symbols(document)
    if self.is_current_document(document) {
      self.provider_result = { ..self.provider_result, symbols, }
      self.render_feature_update()
    }
  })
  @js.async_run(() => {
    let semantic_tokens = self.services.language_features.semantic_tokens_for_document(
      document,
    )
    if self.is_current_document(document) {
      self.provider_result = { ..self.provider_result, semantic_tokens, }
      self.render_feature_update()
    }
  })
  @js.async_run(() => {
    let folding_ranges = self.services.language_features.folding_ranges_for_document(
      document,
    )
    if self.is_current_document(document) {
      self.set_folding_ranges(folding_ranges)
    }
  })
  @js.async_run(() => {
    let inlay_hints = self.services.language_features.inlay_hints_for_document(
      document,
    )
    if self.is_current_document(document) {
      self.inlay_hints = inlay_hints
      self.render_feature_update()
    }
  })
}
