///|
/// Monaco's `_attachModel` (`codeEditorWidget.ts:1745-1913`): hook the
/// swap-scoped listeners, build the per-model `ViewModel`, create the per-model `View` inside the
/// container, and bundle everything into `ModelData`. Later option and
/// decoration changes update the view model in place
/// (`ViewModel::on_configuration_changed`,
/// `on_did_change_content_or_injected_text`). Token reads are passive;
/// explicit/visible/background demand owns lexer work. The paint happens in
/// the next render flush.
fn Viewer::attach_model(self : Viewer, model : @model.TextModel) -> Unit {
  self.model_data_generation += 1
  let model_data_generation = self.model_data_generation
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
      let event_batch = self.begin_view_event_batch()
      // Monaco: `onDidChangeDecorations` → `viewModel.decorations
      // .onModelDecorationsChanged()` (`viewModelImpl.ts`) — drop the
      // computer + viewport caches before the re-render reads them.
      match self.get_view_model() {
        Some(view_model) => {
          view_model.decorations().on_model_decorations_changed()
          // Cache first, typed View event second. The direct model
          // subscription remains the approved outgoing-event seam.
          self.emit_view_event(
            ViewDecorationsChanged(view_decorations_changed_event(event)),
          )
          // Injected-text deltas re-run the line-breaks computer per line in
          // Monaco (`onDidChangeContentOrInjectedText`); the viewer's
          // granularity is the whole-document reproject
          // (`_lines.on_injected_text_changed()`), applied to the live view
          // model. Content flushes take the event-carrying form of the same
          // member through the model's registered-view-model seam instead.
          if event.affects_injected_text {
            // The registered local reduction folds the injected structural
            // pass into this callback. The outer collector preserves: exact
            // Decorations → Flushed → LineMapping → all-Decorations →
            // optional Cursor reprojection.
            let previous_view_selection = view_model.cursor.get_view_selection()
            view_model.on_did_change_content_or_injected_text()
            self.on_line_mapping_changed(
              view_model,
              model,
              previous_view_selection~,
            )
          }
        }
        None => ()
      }
      end_view_event_batch(event_batch)
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
      let event_batch = self.begin_view_event_batch()
      if event.is_flush {
        self.emit_view_event(ViewFlushed)
      }
      match self.get_view_model() {
        Some(view_model) =>
          self.on_line_mapping_changed(view_model, model, notify_view=false)
        None => ()
      }
      end_view_event_batch(event_batch)
      // Monaco cancels the pending mouse reaction on content change. The
      // Viewer also retires hover provider/timer ownership and rotates the operation
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
      self.schedule_render()
      self.did_change_model_content.fire(event)
      self.complete_model_content_delivery(model, event.version_id)
    }),
  )
  // A disposed model detaches itself
  // (`codeEditorWidget.ts:1787` `model.onWillDispose(() => this.setModel(null))`).
  listeners_to_remove.push(model.on_will_dispose(() => self.set_model(None)))
  // Decorations live in the model's interval-tree storage; the view
  // model queries them lazily per viewport (no per-frame bake). The render
  // pass pulls its viewport data from the view model at flush time.
  let attached_view = match self.container {
    Some(_) =>
      model.on_before_attached(scheduler=browser_tokenization_scheduler)
    None => model.on_before_attached()
  }
  let build_started = now_ms()
  let view_model = self.build_view_model(model, attached_view)
  self.layout_model_line_count = model.snapshot.line_count()
  self.layout_line_count = view_model.line_count()
  // The cursor outgoing alias is model-scoped. The ViewModel has already
  // committed both cursor coordinate states before this fires; the Viewer
  // adds the public content barrier and position-before-selection relay.
  listeners_to_remove.push(
    view_model.on_cursor_state_changed(event => {
      if self.is_current_model_data_generation(model_data_generation) {
        // A real content flush waits behind the public content barrier so
        // `ViewFlushed` remains before the cursor event. Ordinary cursor
        // transitions notify ViewParts before the public outgoing pair.
        if !is_model_flush_cursor_event(event) {
          self.emit_view_cursor_state_changed(
            view_model,
            event.selections,
            event.reason,
          )
        }
        self.enqueue_cursor_state_change(event)
      }
    }),
  )
  // The ViewZones outgoing arm is model-scoped. The root transaction emits
  // the internal ViewEvent first, then asks the ViewModel dispatcher to reach
  // this public alias.
  listeners_to_remove.push(
    view_model.on_view_zones_changed(_event => {
      if self.is_current_model_data_generation(model_data_generation) {
        self.did_change_view_zones.fire(())
      }
    }),
  )
  // `viewModelImpl.ts:522` reaches the root only after the ViewModel's
  // browser callback has synchronously delivered `ViewTokensChanged`. This
  // replaces the old direct TextModel listener and never invokes the lexer.
  listeners_to_remove.push(
    view_model.on_model_tokens_changed(event => {
      if self.is_current_model_data_generation(model_data_generation) {
        self.handle_model_tokens_changed(model, event.event)
      }
    }),
  )
  // Monaco's `ViewLayout.onDidScroll` is the single scroll-to-render seam.
  // Immediate calls and rAF animation ticks both arrive here, avoiding a
  // separate browser-only animation path.
  listeners_to_remove.push(
    view_model.view_layout.on_did_scroll(change => {
      self.apply_scroll_change(Some(change))
    }),
  )
  let view = self.create_view(model, view_model)
  self.model_data = Some({
    model,
    view_model,
    view,
    attached_view,
    listeners_to_remove,
  })
  self.emit_view_event(ViewFlushed)
  self.rendered_window = None
  self.apply_view_model_layout(view_model)
  // `CodeEditorWidget.handleInitialized` owns the ordinary one-time stable
  // visible-range publication; generic renders never repeat it.
  view_model.visible_lines_stabilized()
  let build_finished = now_ms()
  self.did_build_view_model.fire({
    model,
    line_count: view_model.line_count(),
    token_count: model.tokenization.token_count(),
    diagnostic_count: self.services.markers
    .diagnostics_for_resource(model.uri)
    .length(),
    tokenize_ms: 0.0,
    build_ms: build_finished - build_started,
  })
  self.pending_rendered = Some({ model, fresh: true })
  self.measure_requested = true
  self.schedule_render()
}

///|
/// Whether a swap-scoped callback still belongs to the installed ModelData.
fn Viewer::is_current_model_data_generation(
  self : Viewer,
  generation : Int,
) -> Bool {
  self.model_data is Some(_) && self.model_data_generation == generation
}

///|
/// Monaco's `_createView` + the widget re-add loop (`cew:1889-1912`): build
/// the browser `View` inside the container, hook its per-view input, re-add
/// every registered content/overlay widget, and stamp `data-uri`. `None`
/// while unattached (the headless harness).
fn Viewer::create_view(
  self : Viewer,
  model : @model.TextModel,
  view_model : @view_model.ViewModel,
) -> @view.View? {
  guard self.container is Some(host) else { return None }
  let read_view_zones_configuration = () => {
    (
      self.font_info.line_height,
      self.measured_content_width,
      self.gutter_width(model.snapshot.line_count()),
    )
  }
  let view = @view.View::View(
    view_zones_configuration_reader=read_view_zones_configuration,
  )
  view.install_view_zones_context(
    view_model,
    self.services.log_service,
    read_view_zones_configuration,
    () => {
      // Common ViewModel cannot import browser ViewEvent. Complete the source
      // `changeWhitespace` order at this model-scoped seam for both public API
      // transactions and configuration/line-mapping recomputations.
      view.emit_view_zones_changed_then(() => {
        view_model.emit_view_zones_changed()
      })
    },
  )
  // ViewLines rereads the same live configuration snapshot in its
  // `onConfigurationChanged` handler, and its one retained-line factory
  // dynamically captures the equality-gated `ViewLineOptions` identity.
  view.view_lines.install_live_configuration_reader(() => {
    @view.ViewLinesConfiguration::ViewLinesConfiguration(
      line_height=self.font_info.line_height,
      typical_halfwidth_character_width=self.font_info.typical_halfwidth_character_width,
      is_viewport_wrapping=self.options.soft_wrap && self.soft_wrap_column > 0,
      can_use_layer_hinting=true,
      space_width=self.font_info.space_width,
      middot_width=self.font_info.middot_width,
      wsmiddot_width=self.font_info.wsmiddot_width,
      use_monospace_optimizations=self.font_info.is_monospace,
      can_use_halfwidth_rightwards_arrow=self.font_info.can_use_halfwidth_rightwards_arrow,
      stop_rendering_line_after=-1,
      render_whitespace=self.options.render_whitespace,
      render_control_characters=self.options.render_control_characters,
      font_ligatures=self.font_info.font_feature_settings !=
        @config.editor_font_ligatures_off,
      vertical_scrollbar_size=@core.editor_vertical_scrollbar_size,
    )
  })
  view.view_lines.install_geometry_readers(
    view_line_number => {
      view_model
      .coordinates_converter()
      .view_position_to_model_position(Position(view_line_number, 1)).line_number
    },
    // The local ViewModel currently emits only LTR ViewLineRenderingData; the
    // reader remains explicit so model-direction ownership can replace this
    // fixed product seam without changing ViewLines aggregation again.
    _model_line_number => LTR,
  )
  // ContentWidgets retains Monaco's ViewContext for source-time layout-cache
  // refreshes and anchor reprojection. Install the model-scoped live readers
  // before any persistent widget is re-added to this fresh View.
  view.content_widgets.install_live_view_context_with_affinity(
    () => {
      (
        self.gutter_width(model.snapshot.line_count()),
        self.measured_content_width,
      )
    },
    (position, affinity) => {
      let valid_position = model.validate_position(position)
      if view_model.model_position_is_visible(valid_position) {
        Some(
          view_model
          .coordinates_converter()
          .model_position_to_view_position(valid_position, affinity?),
        )
      } else {
        None
      }
    },
  )
  view.install_current_line_configuration_reader(() => {
    (
      self.options.render_line_highlight,
      self.options.render_line_highlight_only_when_focus,
      self.options.soft_wrap && self.soft_wrap_column > 0,
      self.gutter_width(model.snapshot.line_count()),
      self.measured_content_width,
    )
  })
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
      view.content_widgets.add_widget(widget.content_widget_handle())
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
  attached_view : @model.AttachedViewImpl,
) -> @view_model.ViewModel {
  let options = self.options.view_model_options(
    self.soft_wrap_column,
    font_info=self.font_info,
    editor_id=self.editor_id,
  )
  // Injected text reaches the projection through the model's decoration
  // storage, not through construction arguments.
  let view_model = @view_model.ViewModel::with_options(
    model,
    options,
    smooth_scrolling=self.options.smooth_scrolling,
    schedule_at_next_animation_frame~,
    now=date_now_ms,
    attached_view~,
    emit_view_tokens_changed=ranges => {
      let changed_ranges : Array[(Int, Int)] = []
      for range in ranges {
        changed_ranges.push((range.from_line_number, range.to_line_number))
      }
      self.emit_view_event(
        ViewTokensChanged(view_tokens_changed_event(changed_ranges)),
      )
    },
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
/// The root half of the ViewModel's outgoing model-token event. The internal
/// browser ViewEvent has already completed; telemetry reads stored counts
/// passively and the next frame repaints without re-warming the lexer.
fn Viewer::handle_model_tokens_changed(
  self : Viewer,
  model : @model.TextModel,
  _event : @model.ModelTokensChangedEvent,
) -> Unit {
  guard self.get_view_model() is Some(view_model) else { return }
  self.did_build_view_model.fire({
    model,
    line_count: view_model.line_count(),
    token_count: model.tokenization.token_count(),
    diagnostic_count: self.services.markers
    .diagnostics_for_resource(model.uri)
    .length(),
    tokenize_ms: 0.0,
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
fn Viewer::on_configuration_changed(
  self : Viewer,
  previous_options? : ViewerOptions = self.options,
) -> Unit {
  let event_batch = self.begin_view_event_batch()
  match (self.get_view_model(), self.get_model()) {
    (Some(view_model), Some(model)) => {
      let previous_view_selection = view_model.cursor.get_view_selection()
      let options = self.options.view_model_options(
        self.soft_wrap_column,
        font_info=self.font_info,
        editor_id=self.editor_id,
      )
      if view_model.on_configuration_changed(options) {
        // Source order: Flushed → LineMapping → Decorations(null) →
        // cursor reprojection, followed by the layout flush.
        self.emit_view_event(ViewFlushed)
        self.emit_view_event(ViewLineMappingChanged)
        self.emit_view_event(
          ViewDecorationsChanged(@view.ViewDecorationsChangedEvent::all()),
        )
        self.emit_view_cursor_reprojection(view_model, previous_view_selection)
        self.on_line_mapping_changed(
          view_model,
          model,
          notify_view=false,
          notify_configuration=false,
        )
      } else {
        self.sync_content_width()
      }
      if previous_options.render_validation_decorations !=
        self.options.render_validation_decorations {
        // `ViewModel::on_configuration_changed` has already rotated the
        // filtered decoration provider; invalidate every decorations
        // consumer before the final Configuration event.
        self.emit_view_event(
          ViewDecorationsChanged(@view.ViewDecorationsChangedEvent::all()),
        )
      }
    }
    _ => self.sync_content_width()
  }
  end_view_event_batch(event_batch)
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
  notify_view? : Bool = true,
  notify_configuration? : Bool = true,
  layout_already_applied? : Bool = false,
  previous_view_selection? : @core.Selection,
) -> Unit {
  let previous_layout_identity = self.layout_identity(
    self.layout_model_line_count,
    self.layout_line_count,
  )
  let event_batch = if notify_view || notify_configuration {
    self.begin_view_event_batch()
  } else {
    None
  }
  if notify_view {
    self.emit_view_event(ViewFlushed)
    self.emit_view_event(ViewLineMappingChanged)
    self.emit_view_event(
      ViewDecorationsChanged(@view.ViewDecorationsChangedEvent::all()),
    )
    match previous_view_selection {
      Some(previous) => self.emit_view_cursor_reprojection(view_model, previous)
      None => ()
    }
  }
  if layout_already_applied {
    self.sync_content_width()
  } else {
    self.apply_view_model_layout(view_model)
  }
  self.rendered_window = None
  let current_model_line_count = model.snapshot.line_count()
  let current_view_line_count = view_model.line_count()
  self.sync_content_box_for_model_line_count(
    view_model,
    self.layout_model_line_count,
    current_model_line_count,
  )
  |> ignore
  self.layout_model_line_count = current_model_line_count
  self.layout_line_count = current_view_line_count
  if notify_configuration &&
    previous_layout_identity !=
    self.layout_identity(current_model_line_count, current_view_line_count) {
    self.emit_view_event(
      ViewConfigurationChanged(
        @view.ViewConfigurationChangedEvent::from_changed_options([LayoutInfo]),
      ),
    )
  }
  end_view_event_batch(event_batch)
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
) -> Unit {
  view_model.view_layout.set_line_count(view_model.line_count()) |> ignore
  self.sync_content_width()
}

///|
