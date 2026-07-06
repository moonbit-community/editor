///|
/// Warms the model's memoized tokenization part and builds the view model
/// for the current options. Only a model's first render pays the tokenize
/// sweep; later renders hit the part's memo. Synchronous CPU work; the
/// paint happens in the next render flush.
fn Viewer::render_current_model(
  self : Viewer,
  model : @model.TextModel,
  fresh~ : Bool,
  request_language~ : Bool,
) -> Unit {
  let tokenize_started = now_ms()
  model.tokenization.force_tokenization()
  let tokenize_finished = now_ms()
  // Decorations live in the model's interval-tree storage; the view
  // model queries them lazily per viewport (no per-frame bake). The render
  // pass pulls its viewport data from the view model at flush time.
  let view_model = self.build_view_model(model)
  self.apply_view_model_layout(view_model, model.snapshot)
  let build_finished = now_ms()
  self.view_model = Some(view_model)
  self.rendered_window = None
  self.text_model = Some(model)
  self.refresh_cursor_context()
  self.content_generation += 1
  self.did_build_view_model.fire({
    model,
    line_count: view_model.line_count(),
    token_count: model.tokenization.token_count(),
    diagnostic_count: self.services.markers
    .diagnostics_for_resource(model.uri)
    .length(),
    tokenize_ms: tokenize_finished - tokenize_started,
    build_ms: build_finished - tokenize_finished,
  })
  // Several renders can coalesce into one flush (feature data often
  // resolves before the next animation frame); a pending fresh paint
  // stays fresh so the host still sees the document switch.
  let fresh = fresh ||
    (match self.pending_rendered {
      Some(pending) => pending.fresh
      None => false
    })
  self.pending_rendered = Some({ model, fresh })
  self.measure_requested = true
  self.schedule_render()
  if request_language {
    self.request_model_features(model)
  }
}

///|
fn Viewer::build_view_model(
  self : Viewer,
  model : @model.TextModel,
) -> @view_model.ViewModel {
  let options = self.options.view_model_options(
    self.soft_wrap_column,
    editor_id=self.editor_id,
  )
  // Injected text (inlay hints) reaches the projection through the model's
  // decoration storage (Track F), not through construction arguments.
  @view_model.ViewModel::with_options(model, options)
}

///|
fn Viewer::rebuild_current_view_model_for_options(self : Viewer) -> Unit {
  match self.text_model {
    Some(model) => {
      let view_model = self.build_view_model(model)
      self.apply_view_model_layout(view_model, model.snapshot)
      self.view_model = Some(view_model)
      self.rendered_window = None
      self.refresh_cursor_context()
      self.content_generation += 1
      let fresh = match self.pending_rendered {
        Some(pending) => pending.fresh
        None => false
      }
      self.pending_rendered = Some({ model, fresh })
    }
    None => self.sync_content_width()
  }
}

///|
fn Viewer::apply_view_model_layout(
  self : Viewer,
  view_model : @view_model.ViewModel,
  snapshot : @model.TextSnapshot,
) -> Unit {
  self.view_layout.set_line_count(view_model.line_count()) |> ignore
  self.normalize_browser_view_zones()
  self.sync_view_zones_with_layout()
  self.max_line_length = if self.options.soft_wrap && self.soft_wrap_column > 0 {
    max_view_line_length(view_model.lines())
  } else {
    max_line_length(snapshot)
  }
  self.sync_content_width()
}

///|
/// The widest line in UTF-16 code units, the horizontal scroll extent
/// driver (uniform-advance monospace metrics).
fn max_line_length(snapshot : @model.TextSnapshot) -> Int {
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
fn max_view_line_length(lines : @view_model.ViewModelLines) -> Int {
  let mut widest = 0
  for line_number in 1..<=lines.line_count() {
    let length = lines.get_view_line_content(line_number).length()
    if length > widest {
      widest = length
    }
  }
  widest
}

///|
