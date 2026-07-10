///|
/// Monaco's `_attachModel` (`codeEditorWidget.ts:1745-1913`): hook the
/// swap-scoped listeners, warm the model's memoized tokenization part,
/// build the per-model `ViewModel`, create the per-model `View` inside the
/// container, and bundle everything into `ModelData`. Later option and
/// decoration changes update the view model in place
/// (`ViewModel::on_configuration_changed`,
/// `on_did_change_content_or_injected_text`) and tokenizer changes only
/// re-warm the token memo (`retokenize_current_model`). Synchronous CPU
/// work; the paint happens in the next render flush.
fn Viewer::attach_model(self : Viewer, model : @model.TextModel) -> Unit {
  let listeners_to_remove : Array[@base_common.Disposable] = []
  // `data-mode-id` on the container (`cew:1758`), removed at detach.
  match self.container {
    Some(host) => host.set_attribute("data-mode-id", model.language_id)
    None => ()
  }
  // The decoration-change subscription attaches before the marker service
  // seeds the model so the seeding delta is observed too.
  listeners_to_remove.push(
    model.on_did_change_decorations(event => {
      // Monaco: `onDidChangeDecorations` → `viewModel.decorations
      // .onModelDecorationsChanged()` (`viewModelImpl.ts`) — drop the
      // computer + viewport caches before the re-render reads them.
      match self.get_view_model() {
        Some(view_model) => {
          view_model.decorations().on_model_decorations_changed()
          // Injected-text deltas re-run the line-breaks computer per line in
          // Monaco (`onDidChangeContentOrInjectedText`); the viewer's
          // granularity is the whole-document reproject
          // (`_lines.on_injected_text_changed()`), applied to the live view
          // model. Content flushes take the event-carrying form of the same
          // member through the model's registered-view-model seam instead.
          if event.affects_injected_text {
            view_model.on_did_change_content_or_injected_text()
            self.on_line_mapping_changed(view_model, model)
          }
        }
        None => ()
      }
      self.decorations_generation += 1
      self.schedule_render()
    }),
  )
  // One service registration owns marker seeding plus the model-content and
  // model-dispose watches. It is acquired before the Viewer content/will/token
  // listeners so marker refresh and ModelDisposed handling run first; the
  // returned idempotent lease is released with this ModelData.
  listeners_to_remove.push(
    self.services.marker_decorations.acquire_model(model),
  )
  // The `set_value` flush lane (`model.onDidChangeContent`). By the time
  // this fires, the registered view models already re-projected (the
  // model's two-loop dispatch runs before its public emitter), so the
  // service registration already re-seeded marker decorations. The Viewer
  // side re-flushes layout facts, re-fires the public event for contribs, and
  // schedules the repaint without acquiring another marker lease.
  listeners_to_remove.push(
    model.on_did_change_content(event => {
      match self.get_view_model() {
        Some(view_model) => self.on_line_mapping_changed(view_model, model)
        None => ()
      }
      // Monaco cancels the pending mouse reaction on content change. The
      // Viewer also retires provider/timer ownership and rotates the operation
      // generation while preserving only an already settled hover until a new
      // pointer request replaces it. Incomplete/loading state is retired.
      match self.content_hover_controller() {
        Some(hc) => {
          hc.cancel_react()
          hc.cancel_operation_timers()
          hc.cancel_request()
          hc.hover = hc.hover.cancel_operation_preserving_view()
          // `set_value` just destroyed every model decoration. Retire the
          // matching hover bookkeeping. If a settled result stays visible, a
          // later accepted result still must not falsely dedupe against
          // decoration IDs/range that no longer exist.
          hc.reset_model_state()
          // The operation transition can remove an incomplete/loading-only
          // view. Reconcile the logical widget cache immediately; render
          // flushing only owns model decorations and cannot retire stale hover
          // DOM or headless visibility state for us.
          self.sync_content_hover_widget()
        }
        None => ()
      }
      // Inlay hints: re-request from the providers and re-apply as
      // injected-text decorations against the new content.
      self.request_model_features(model)
      self.did_change_model_content.fire(event)
      self.schedule_render()
    }),
  )
  // A disposed model detaches itself
  // (`codeEditorWidget.ts:1787` `model.onWillDispose(() => this.setModel(null))`).
  listeners_to_remove.push(model.on_will_dispose(() => self.set_model(None)))
  // Token changes (the part's registry subscription fires them on tokenizer
  // (re)registration) re-warm the memo and repaint — Monaco's
  // `ModelTokensChangedEvent` handling. The viewer's granularity is the whole
  // document, so the event's ranges are not consulted.
  listeners_to_remove.push(
    model.on_did_change_tokens(_ => self.retokenize_current_model(model)),
  )
  let tokenize_started = now_ms()
  model.tokenization.force_tokenization()
  let tokenize_finished = now_ms()
  // Decorations live in the model's interval-tree storage; the view
  // model queries them lazily per viewport (no per-frame bake). The render
  // pass pulls its viewport data from the view model at flush time.
  let view_model = self.build_view_model(model)
  // Monaco's `ViewLayout.onDidScroll` is the single scroll-to-render seam.
  // Immediate calls and rAF animation ticks both arrive here, avoiding a
  // separate browser-only animation path.
  listeners_to_remove.push(
    view_model.view_layout.on_did_scroll(change => {
      self.apply_scroll_change(Some(change))
    }),
  )
  let view = self.create_view(model)
  self.model_data = Some({ model, view_model, view, listeners_to_remove })
  self.rendered_window = None
  self.apply_view_model_layout(view_model, model.snapshot)
  let build_finished = now_ms()
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
  self.pending_rendered = Some({ model, fresh: true })
  self.measure_requested = true
  self.schedule_render()
  self.request_model_features(model)
}

///|
/// Monaco's `_createView` + the widget re-add loop (`cew:1889-1912`): build
/// the browser `View` inside the container, hook its per-view input, re-add
/// every registered content/overlay widget, and stamp `data-uri`. `None`
/// while unattached (the headless harness).
fn Viewer::create_view(self : Viewer, model : @model.TextModel) -> @view.View? {
  guard self.container is Some(host) else { return None }
  let view = @view.View::new()
  view.root.set_attribute("data-theme", self.options.theme)
  host.append_child(view.root.as_node())
  view.apply_squiggly_theme()
  // The editor root carries the configured font — Monaco's
  // `applyFontInfo(this.domNode, fontInfo)` in `view.ts`.
  self.apply_font_info_to_view(view)
  // The pointer handler is view-owned (Monaco's `PointerHandler` lives in
  // the `View`), so a fresh `MouseHandler` hooks each new view.
  self.hook_view_input(view)
  // Re-add every registered widget to the new view (`cew:1893-1909`).
  match self.content_hover_widget {
    Some(widget) => {
      // The widget survives model swaps, but its scrollbar listeners belong
      // to the per-View MouseHandler. The outgoing handler removed its hooks,
      // so bind the persistent scrollable to the freshly created handler
      // before remounting the widget.
      match self.mouse_handler {
        Some(handler) =>
          handler.hook_scrollable_scrollbar_input(
            widget.scrollable,
            HoverScrollableElement,
          )
        None => ()
      }
      view.content_widgets.add_widget(widget)
    }
    None => ()
  }
  for widget_id, node in self.overlay_widgets {
    view.overlay_widgets.add_widget(widget_id, node)
  }
  // `data-uri` (`cew:1912`).
  view.root.set_attribute("data-uri", model.uri.to_string())
  // The no-model placeholder yields to the per-model view.
  match self.placeholder_element {
    Some(placeholder) => remove_element_if_contained(host, placeholder)
    None => ()
  }
  Some(view)
}

///|
fn Viewer::build_view_model(
  self : Viewer,
  model : @model.TextModel,
) -> @view_model.ViewModel {
  let options = self.options.view_model_options(
    self.soft_wrap_column,
    font_info=self.font_info,
    editor_id=self.editor_id,
  )
  // Injected text (inlay hints) reaches the projection through the model's
  // decoration storage (Track F), not through construction arguments.
  let view_model = @view_model.ViewModel::with_options(
    model,
    options,
    smooth_scrolling=self.options.smooth_scrolling,
    schedule_at_next_animation_frame~,
    now=date_now_ms,
  )
  // Seed the fresh layout's viewport box from the widget's measured
  // dimensions — Monaco's `ViewLayout` reads `EditorOption.layoutInfo` from
  // the configuration at construction.
  view_model.view_layout.set_viewport_size(
    width=self.measured_content_width,
    height=self.measured_height,
  )
  |> ignore
  view_model
}

///|
/// The viewer's `model.onDidChangeTokens` handler: re-warms the reset token
/// memo and schedules a repaint — Monaco's `ModelTokensChangedEvent` →
/// `ViewTokensChangedEvent` round trip. The long-lived view model survives;
/// only the token memo and the paint are redone.
fn Viewer::retokenize_current_model(
  self : Viewer,
  model : @model.TextModel,
) -> Unit {
  let tokenize_started = now_ms()
  model.tokenization.force_tokenization()
  let tokenize_finished = now_ms()
  guard self.get_view_model() is Some(view_model) else { return }
  self.content_generation += 1
  self.did_build_view_model.fire({
    model,
    line_count: view_model.line_count(),
    token_count: model.tokenization.token_count(),
    diagnostic_count: self.services.markers
    .diagnostics_for_resource(model.uri)
    .length(),
    tokenize_ms: tokenize_finished - tokenize_started,
    build_ms: 0.0,
  })
  let fresh = match self.pending_rendered {
    Some(pending) => pending.fresh
    None => false
  }
  self.pending_rendered = Some({ model, fresh })
  self.schedule_render()
}

///|
/// Routes a layout-affecting option change into the live view model —
/// Monaco's `_configuration.onDidChangeFast` → `_onConfigurationChanged`
/// subscription. A changed view-line mapping re-flushes the layout; anything
/// else only re-syncs the content width.
fn Viewer::on_configuration_changed(self : Viewer) -> Unit {
  match (self.get_view_model(), self.get_model()) {
    (Some(view_model), Some(model)) => {
      let options = self.options.view_model_options(
        self.soft_wrap_column,
        font_info=self.font_info,
        editor_id=self.editor_id,
      )
      if view_model.on_configuration_changed(options) {
        self.on_line_mapping_changed(view_model, model)
      } else {
        self.sync_content_width()
      }
    }
    _ => self.sync_content_width()
  }
}

///|
/// The viewer's side of a changed view-line mapping (wrapping reflow,
/// injected text): re-flush the layout, drop the rendered window, and mark
/// the content stale — Monaco's `ViewFlushedEvent`/
/// `ViewLineMappingChangedEvent` handling (`viewLayout.onFlushed`; the view
/// model already re-pointed its own cursor).
fn Viewer::on_line_mapping_changed(
  self : Viewer,
  view_model : @view_model.ViewModel,
  model : @model.TextModel,
) -> Unit {
  self.apply_view_model_layout(view_model, model.snapshot)
  self.rendered_window = None
  self.content_generation += 1
  let fresh = match self.pending_rendered {
    Some(pending) => pending.fresh
    None => false
  }
  self.pending_rendered = Some({ model, fresh })
}

///|
fn Viewer::apply_view_model_layout(
  self : Viewer,
  view_model : @view_model.ViewModel,
  snapshot : @model.TextSnapshot,
) -> Unit {
  view_model.view_layout.set_line_count(view_model.line_count()) |> ignore
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
fn max_view_line_length(
  lines : @view_model.ViewModelLinesFromProjectedModel,
) -> Int {
  let mut widest = 0
  for line_number in 1..<=lines.get_view_line_count() {
    let length = lines.get_view_line_content(line_number).length()
    if length > widest {
      widest = length
    }
  }
  widest
}

///|
