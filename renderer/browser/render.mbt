///|
/// Builds (or reuses) the per-version tokenized document, buckets the
/// feature data into a frame source, and emits the frame for the current
/// layout window. Only the tokenize step depends on document size; cache
/// hits skip it entirely. Synchronous CPU work; the paint happens in the
/// next render flush.
fn Viewer::render_current_document(
  self : Viewer,
  document : @workspace.SourceDocument,
  fresh~ : Bool,
  request_language~ : Bool,
) -> Unit {
  let marker_diagnostics = self.services.markers.diagnostics_for_resource(
    document.uri,
  )
  let providers = { ..self.provider_result, diagnostics: marker_diagnostics }
  let tokenize_started = @dom.now_ms()
  let tokenized = match self.cached_tokenized(document) {
    Some(tokenized) => tokenized
    None => {
      let doc = document.snapshot()
      let tokens = match tokenizer_registry.lookup(doc.language_id) {
        Some(tokenizer) => @syntax.tokenize_document(doc, tokenizer)
        None => @syntax.highlight(doc)
      }
      @renderer.TokenizedDocument::build(doc, tokens)
    }
  }
  let tokenize_finished = @dom.now_ms()
  (self.notify_host)(
    ViewerDiagnosticsStatus(
      count=marker_diagnostics.length(),
      version=tokenized.snapshot.version,
    ),
  )
  let decorations = self.services.marker_decorations.decorations_for_resource(
    document.uri,
  )
  let source = @renderer.FrameSource(tokenized, decorations, providers)
  // Only a rotated document identity or version renders from the top;
  // watch backends may re-push the same version (the old cell key kept
  // those re-renders at their scroll position too).
  let rotated = match self.source_document {
    Some(current) =>
      current.uri.to_string() != document.uri.to_string() ||
      current.version != document.version
    None => true
  }
  if fresh && rotated {
    self.apply_scroll_change(
      self.layout.scroll_to(scroll_top=0.0, scroll_left=0.0),
    )
  }
  self.layout.set_line_count(tokenized.snapshot.line_count()) |> ignore
  self.max_line_length = max_line_length(tokenized.snapshot)
  self.sync_content_width()
  let window = self.layout.visible_window(overscan=line_overscan)
  let frame = @renderer.build_frame(source, {
    start_line: window.start,
    end_line: window.end,
  })
  let build_finished = @dom.now_ms()
  self.frame_source = Some(source)
  self.frame = Some(frame)
  self.source_document = Some(document)
  self.content_generation += 1
  (self.notify_host)(
    ViewerFrameBuilt(
      document,
      line_count=frame.line_count,
      token_count=tokenized.token_count,
      diagnostic_count=marker_diagnostics.length(),
      tokenize_ms=tokenize_finished - tokenize_started,
      build_ms=build_finished - tokenize_finished,
    ),
  )
  // Several renders can coalesce into one flush (feature data often
  // resolves before the next animation frame); a pending fresh paint
  // stays fresh so the host still sees the document switch.
  let fresh = fresh ||
    (match self.pending_rendered {
      Some(pending) => pending.fresh
      None => false
    })
  self.pending_rendered = Some({ document, fresh })
  self.measure_requested = true
  self.schedule_render()
  if request_language {
    self.request_document_features(document)
  }
}

///|
/// The cached tokenized document, valid only for the same document
/// identity and version (the Monaco model-version guard).
fn Viewer::cached_tokenized(
  self : Viewer,
  document : @workspace.SourceDocument,
) -> @renderer.TokenizedDocument? {
  match (self.frame_source, self.source_document) {
    (Some(source), Some(current)) =>
      if current.uri.to_string() == document.uri.to_string() &&
        source.tokenized.snapshot.version == document.version {
        Some(source.tokenized)
      } else {
        None
      }
    _ => None
  }
}

///|
/// The widest line in UTF-16 code units, the horizontal scroll extent
/// driver (uniform-advance monospace metrics).
fn max_line_length(snapshot : @core.DocumentSnapshot) -> Int {
  let mut widest = 0
  for line in 0..<snapshot.line_count() {
    let length = snapshot.line_end_offset(line) -
      snapshot.line_start_offset(line)
    if length > widest {
      widest = length
    }
  }
  widest
}

///|
