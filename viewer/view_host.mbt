// The viewer core's side of the `viewer/browser/view` seam: builds the
// `ViewContext` capability struct `View::render` needs (the local analog of
// Monaco's `View` reading its owning `CodeEditorWidget`) and owns the render
// loop entry points. Kept out of `view.mbt` because `View::render` cannot
// reference `Viewer` directly (the foreign-method rule keeps every `Viewer::`
// method in `Viewer`'s own package) without creating a
// `browser/view ↔ browser/widget/code_editor` cross-package cycle.

///|
fn Viewer::build_view_context(
  self : Viewer,
  view : @view.View,
) -> @view.ViewContext {
  {
    measure_line_selection: (line_number, start_column, end_column) => {
      view.measure_line_selection(line_number, start_column, end_column)
    },
    measure_line_decorations: (line_number, start_column, end_column) => {
      view.measure_line_selection(
        line_number,
        start_column,
        end_column,
        keep_empty=true,
      )
    },
    offset_for_column: (line_number, column) => {
      view.offset_for_column(line_number, column)
    },
    model_position_to_view_position: position => {
      match self.model_to_view_position(position.line_number, position.column) {
        Some(view_position) => view_position
        None => position
      }
    },
  }
}

///|
/// Monaco `ContentHoverWidget`'s keydown handling, dispatched from the hover
/// widget's own DOM listener via the `ContentHoverWidgetHost.handle_keydown`
/// closure. The keys resolve through the command registry
/// (`hoverActions.ts`'s scroll cluster registered in
/// `hover_contribution.mbt`, gated on `hoverFocused`/`hoverVisible`).
fn Viewer::handle_hover_keydown(
  self : Viewer,
  event : @rdom.Event,
  keyboard : @rdom.KeyboardEvent,
) -> Unit {
  event.stop_propagation()
  // `KeyMod.CtrlCmd` is Ctrl on Windows/Linux and Cmd on macOS.
  if editor_registry().dispatch_keybinding(
      self,
      keyboard.key(),
      alt=keyboard.alt_key(),
      ctrl_cmd=keyboard.ctrl_key() || keyboard.meta_key(),
      shift=keyboard.shift_key(),
    ) {
    event.prevent_default()
  }
}

///|
/// The rAF-coalesced render loop entry: reads (measurement) before
/// writes, delegates browser DOM work to `View`, then reports the paint
/// facts that were waiting on this flush.
fn Viewer::flush_render(self : Viewer) -> Unit {
  if self.disposed {
    return
  }
  guard self.model_data is Some(model_data) else {
    // No model → no view; the Viewer-owned placeholder is the whole paint.
    self.render_placeholder()
    return
  }
  guard model_data.view is Some(view) else { return }
  let view_model = model_data.view_model
  // Read phase: measure only when a re-measure was requested.
  if self.configuration.consume_measure_request() {
    self.measure(view)
  }
  // Write phase.
  self.sync_hover_decorations()
  let write_started = @base_browser.monotonic_now_ms()
  let window = self.synced_window(view_model)
  let view_context = self.build_view_context(view)
  let configuration = self.configuration.snapshot()
  view.render(view_context, {
    window,
    view_model,
    layout: view_model.view_layout,
    selection_view_range: self.selection_view_range(),
    view_selection: self.view_selection(),
    gutter_width: configuration.gutter_width(
      model_data.model.snapshot.line_count(),
    ),
    line_decorations_width: configuration.layout_decorations_width(),
    space_width: configuration.font_info.space_width,
    typical_fullwidth_character_width: configuration.font_info.typical_fullwidth_character_width,
    editor_has_focus: self.editor_has_focus,
    word_wrap: configuration.word_wrap(),
    render_line_highlight: configuration.options.render_line_highlight,
    render_line_highlight_only_when_focus: configuration.options.render_line_highlight_only_when_focus,
    show_unused: configuration.options.show_unused,
    show_deprecated: configuration.options.show_deprecated,
  })
  // The lines are now in the DOM: a deferred horizontal reveal can measure its
  // target line's client rects and apply the horizontal scroll.
  self.flush_horizontal_reveal(view)
  let patch_ms = @base_browser.monotonic_now_ms() - write_started
  match (self.pending_rendered, self.rendered_window) {
    (Some(pending), Some(window)) => {
      self.pending_rendered = None
      self.emit_model_rendered({
        model: pending.model,
        line_count: view_model.line_count(),
        rendered_lines: window.end - window.start,
        patch_ms,
        fresh: pending.fresh,
      })
    }
    _ => ()
  }
  if self.scroll_dirty {
    self.scroll_dirty = false
    let position = view_model.view_layout.position()
    let event : @editor_api.ScrollEvent = {
      scroll_top: position.scroll_top,
      scroll_left: position.scroll_left,
      scroll_width: view_model.view_layout.get_scroll_width(),
      scroll_height: view_model.view_layout.get_scroll_height(),
      // Change flags diff against the last fired event; the first event
      // reports every axis as changed.
      scroll_top_changed: true,
      scroll_left_changed: true,
      scroll_width_changed: true,
      scroll_height_changed: true,
    }
    let event = match self.last_scroll_event {
      Some(previous) =>
        {
          ..event,
          scroll_top_changed: event.scroll_top != previous.scroll_top,
          scroll_left_changed: event.scroll_left != previous.scroll_left,
          scroll_width_changed: event.scroll_width != previous.scroll_width,
          scroll_height_changed: event.scroll_height != previous.scroll_height,
        }
      None => event
    }
    self.last_scroll_event = Some(event)
    self.did_scroll.fire(event)
  }
}

///|
/// Repaints the Viewer-owned no-model placeholder (the `flush_render`
/// no-model arm): the empty-state classes plus the `placeholder` option's
/// message text.
fn Viewer::render_placeholder(self : Viewer) -> Unit {
  let options = self.configuration.snapshot().options
  match (self.placeholder_element, self.placeholder_text) {
    (Some(placeholder), Some(text)) => {
      placeholder.set_attribute(
        "class",
        @view.empty_editor_class_name(
          show_unused=options.show_unused,
          show_deprecated=options.show_deprecated,
        ),
      )
      text.set_node_value(@js.Nullable::from_option(Some(options.placeholder)))
    }
    _ => ()
  }
}

///|
fn Viewer::schedule_render(self : Viewer) -> Unit {
  // Headless (never attached) → no rAF loop; with a container the flush
  // paints either the per-model view or the no-model placeholder.
  if self.disposed || self.render_frame is Some(_) || self.container is None {
    return
  }
  self.render_frame = Some(
    run_at_this_or_schedule_at_next_animation_frame(() => {
      self.render_frame = None
      if !self.disposed {
        self.flush_render()
      }
    }),
  )
}

///|
/// The view-line window this flush renders: exactly the lines intersecting
/// the viewport (Monaco's `ViewLayout.getLinesViewportData()` band,
/// partially visible edge lines included), recomputed every flush and
/// clamped to the document so every consumer (viewport build, DOM recycler,
/// hit tests) agrees on the rendered range.
fn Viewer::synced_window(
  self : Viewer,
  view_model : @view_model.ViewModel,
) -> @view_layout.LineWindow {
  let window = view_model.clamp_window(view_model.view_layout.visible_window())
  self.rendered_window = Some(window)
  window
}
