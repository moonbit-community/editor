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
    root: view.root,
    languages: self.services.languages,
    handle_hover_mousedown: (event, mouse) => {
      match self.mouse_handler {
        Some(handler) => handler.handle_mouse_down(event, mouse)
        None => ()
      }
    },
    handle_hover_keydown: (widget, event, keyboard) => {
      self.handle_hover_keydown(widget, event, keyboard)
    },
    keep_hover_open: () => self.keep_hover_open(),
    hook_scrollable_scrollbar_input: (scrollable, owner) => {
      match self.mouse_handler {
        Some(handler) =>
          handler.hook_scrollable_scrollbar_input(scrollable, owner)
        None => ()
      }
    },
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
  }
}

///|
/// Monaco `ContentHoverWidget`'s keydown handling, dispatched from the hover
/// widget's own DOM listener via the `ViewContext.handle_hover_keydown`
/// closure `build_view_context` wires up. The keys resolve through the
/// command registry (`hoverActions.ts`'s scroll cluster registered in
/// `hover_contribution.mbt`, gated on `hoverFocused`/`hoverVisible`) —
/// deviations-closeout Track D closed the inline-key-map caveat (hover plan
/// Deviation 13). The `widget` parameter stays for the seam's shape; the
/// commands reach the same singleton widget through the viewer.
fn Viewer::handle_hover_keydown(
  self : Viewer,
  widget : @content_widgets.HoverWidgetDom,
  event : @rdom.Event,
  keyboard : @rdom.KeyboardEvent,
) -> Unit {
  ignore(widget)
  event.stop_propagation()
  // `KeyMod.CtrlCmd` is Ctrl on Windows/Linux and Cmd on macOS.
  if editor_registry().dispatch_keybinding(
      self,
      keyboard.key(),
      alt=keyboard.alt_key(),
      ctrl_cmd=keyboard.ctrl_key() || keyboard.meta_key(),
    ) {
    event.prevent_default()
  }
}

///|
/// The rAF-coalesced render loop entry: reads (measurement) before
/// writes, delegates browser DOM work to `View`, then reports the paint
/// facts that were waiting on this flush.
fn Viewer::flush_render(self : Viewer) -> Unit {
  self.render_pending = false
  guard self.view is Some(view) else { return }
  // Read phase: measure only when a re-measure was requested.
  if self.measure_requested {
    self.measure_requested = false
    self.measure(view)
  }
  // Write phase.
  self.sync_hover_decorations()
  let write_started = now_ms()
  match self.frame {
    None =>
      view.render_empty(
        self.options.placeholder,
        show_unused=self.options.show_unused,
        show_deprecated=self.options.show_deprecated,
      )
    Some(frame) => {
      let frame = self.synced_window_frame(frame)
      let view_context = self.build_view_context(view)
      view.render(view_context, {
        frame,
        view_model: self.view_model,
        layout: self.view_layout,
        browser_view_zones: self.view_zones,
        selection_view_range: self.selection_view_range(),
        view_selection: self.view_selection(),
        folding_ranges: self.folding_ranges,
        folded_ranges: self.folded_ranges,
        hover_state: self.hover,
        on_toggle_fold: line => self.toggle_fold(line),
        on_hover_measured: (below, shift_left, max_height) => {
          self.hover = self.hover.measured(below, shift_left, max_height)
        },
        generation: self.content_generation,
        decorations_generation: self.decorations_generation,
        gutter_width: self.gutter_width(frame),
        line_decorations_width: self.options.line_decorations_width.to_double(),
        space_width: self.measured_char_width(),
        render_whitespace: self.options.render_whitespace,
        render_control_characters: self.options.render_control_characters,
        editor_has_focus: self.editor_has_focus,
        word_wrap: self.options.soft_wrap && self.soft_wrap_column > 0,
        render_line_highlight: self.options.render_line_highlight,
        render_line_highlight_only_when_focus: self.options.render_line_highlight_only_when_focus,
        show_unused: self.options.show_unused,
        show_deprecated: self.options.show_deprecated,
      })
    }
  }
  // The lines are now in the DOM: a deferred horizontal reveal can measure its
  // target line's client rects and apply the horizontal scroll.
  self.flush_horizontal_reveal(view)
  let patch_ms = now_ms() - write_started
  match (self.pending_rendered, self.frame) {
    (Some(pending), Some(frame)) => {
      self.pending_rendered = None
      self.did_render_model.fire({
        model: pending.model,
        line_count: frame.line_count,
        rendered_lines: frame.lines.length(),
        diagnostics: frame.diagnostics,
        patch_ms,
        fresh: pending.fresh,
      })
    }
    _ => ()
  }
  if self.scroll_dirty {
    self.scroll_dirty = false
    let position = self.view_layout.position()
    let event : ScrollEvent = {
      scroll_top: position.scroll_top,
      scroll_left: position.scroll_left,
      scroll_width: self.view_layout.get_scroll_width(),
      scroll_height: self.view_layout.get_scroll_height(),
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
fn Viewer::schedule_render(self : Viewer) -> Unit {
  if self.render_pending || self.view is None {
    return
  }
  self.render_pending = true
  @rdom.window().request_animation_frame(_ => self.flush_render()) |> ignore
}

///|
/// When scroll or viewport changes moved the desired window past the
/// hysteresis band, rebuilds the window frame from the cached source (an
/// O(window) build) so hit tests and the recycler stay aligned.
fn Viewer::synced_window_frame(
  self : Viewer,
  frame : @view_model.RenderFrame,
) -> @view_model.RenderFrame {
  guard self.view_model is Some(view_model) else { return frame }
  let rendered = @view.frame_window(frame)
  let desired = self.view_layout.visible_window(overscan=@core.line_overscan)
  if desired != rendered &&
    @view_layout.window_needs_update(rendered, desired, @core.line_overscan) {
    let rebuilt = view_model.render_frame({
      start_line: desired.start,
      end_line: desired.end,
    })
    self.frame = Some(rebuilt)
    rebuilt
  } else {
    frame
  }
}
