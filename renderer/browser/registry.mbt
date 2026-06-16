///|
/// Tokenization support by language id, the Monaco
/// `TokenizationRegistry` singleton: starts empty, and the host
/// registers the language packages it composed in at startup (the
/// workbench and embedders register `syntax/lang_*` lexers; this
/// package itself imports none). Unregistered languages render through
/// the plain fallback.
let tokenizer_registry : @syntax.TokenizerRegistry = @syntax.TokenizerRegistry::new()

///|
pub fn register_tokenizer(
  language_id : String,
  tokenizer : &@syntax.LineTokenizer,
) -> Unit {
  tokenizer_registry.register(language_id, tokenizer)
}

///|
/// Controllers resolve features through the registry with async runs;
/// each result is tagged with the requesting document version (and the
/// hover anchor token) so stale responses are dropped at handling.
fn Viewer::request_hover(
  self : Viewer,
  anchor : HoverAnchor,
  token : Int,
) -> Unit {
  match self.source_document {
    Some(document) => {
      let version = document.version
      let computer = ContentHoverComputer::new(self.services)
      let anchor_range = @core.Range(anchor.start, anchor.end)
      match
        computer.compute_sync(
          document,
          anchor_range,
          anchor.offset,
          injected_text_index=anchor.injected_text_index,
          inlay_hints=self.inlay_hints,
        ) {
        Some(hover) => self.hover_resolved(version, token, Some(hover))
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
        self.hover_resolved(version, token, hover)
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
  document : @workspace.SourceDocument,
) -> Unit {
  let version = document.version
  @js.async_run(() => {
    self.services.language_features.diagnostics_for_document(document, (
      owner,
      diagnostics,
    ) => self.services.markers.set_diagnostics(owner, document.uri, diagnostics))
    if document_version(self.source_document) == version {
      self.render_feature_update()
    }
  })
  @js.async_run(() => {
    let symbols = self.services.language_features.document_symbols(document)
    if document_version(self.source_document) == version {
      self.provider_result = { ..self.provider_result, symbols, }
      self.render_feature_update()
    }
  })
  @js.async_run(() => {
    let semantic_tokens = self.services.language_features.semantic_tokens_for_document(
      document,
    )
    if document_version(self.source_document) == version {
      self.provider_result = { ..self.provider_result, semantic_tokens, }
      self.render_feature_update()
    }
  })
  @js.async_run(() => {
    let folding_ranges = self.services.language_features.folding_ranges_for_document(
      document,
    )
    if document_version(self.source_document) == version {
      self.set_folding_ranges(folding_ranges)
    }
  })
  @js.async_run(() => {
    let inlay_hints = self.services.language_features.inlay_hints_for_document(
      document,
    )
    if document_version(self.source_document) == version {
      self.inlay_hints = inlay_hints
      self.render_feature_update()
    }
  })
}
