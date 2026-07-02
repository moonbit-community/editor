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
  }
}

///|
/// Monaco `ContentHoverWidget`'s keydown handling, dispatched from the hover
/// widget's own DOM listener via the `ViewContext.handle_hover_keydown`
/// closure `build_view_context` wires up.
fn Viewer::handle_hover_keydown(
  self : Viewer,
  widget : @content_widgets.HoverWidgetDom,
  event : @rdom.Event,
  keyboard : @rdom.KeyboardEvent,
) -> Unit {
  event.stop_propagation()
  // Monaco registers these as editor commands gated on `hoverFocused`
  // (`hoverActions.ts`); until a viewer command registry lands, the focused
  // widget's keydown dispatches them inline with the same key map. The
  // arrow-key secondaries match Monaco: `Alt+Arrow` pages and `CtrlCmd+Arrow`
  // jumps to an edge.
  let alt = keyboard.alt_key()
  // `KeyMod.CtrlCmd` is Ctrl on Windows/Linux and Cmd on macOS.
  let ctrl_cmd = keyboard.ctrl_key() || keyboard.meta_key()
  match keyboard.key() {
    "Escape" => {
      event.prevent_default()
      self.dismiss_hover()
      self.schedule_render()
    }
    "ArrowUp" => {
      event.prevent_default()
      if alt {
        widget.page_up()
      } else if ctrl_cmd {
        widget.go_to_top()
      } else {
        widget.scroll_up()
      }
    }
    "ArrowDown" => {
      event.prevent_default()
      if alt {
        widget.page_down()
      } else if ctrl_cmd {
        widget.go_to_bottom()
      } else {
        widget.scroll_down()
      }
    }
    "ArrowLeft" => {
      event.prevent_default()
      widget.scroll_left()
    }
    "ArrowRight" => {
      event.prevent_default()
      widget.scroll_right()
    }
    "PageUp" => {
      event.prevent_default()
      widget.page_up()
    }
    "PageDown" => {
      event.prevent_default()
      widget.page_down()
    }
    "Home" => {
      event.prevent_default()
      widget.go_to_top()
    }
    "End" => {
      event.prevent_default()
      widget.go_to_bottom()
    }
    _ => ()
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
  let write_started = now_ms()
  match self.frame {
    None => view.render_empty(self.placeholder)
    Some(frame) => {
      let frame = self.synced_window_frame(frame)
      let view_context = self.build_view_context(view)
      view.render(view_context, {
        frame,
        view_model: self.view_model,
        layout: self.layout,
        browser_view_zones: self.view_zones,
        decorations: self.controller_decorations(),
        selection_view_range: self.selection_view_range(),
        folding_ranges: self.folding_ranges,
        folded_ranges: self.folded_ranges,
        hover_state: self.hover,
        on_toggle_fold: line => self.toggle_fold(line),
        on_hover_measured: (below, shift_left, max_height) => {
          self.hover = self.hover.measured(below, shift_left, max_height)
        },
        generation: self.content_generation,
        gutter_width: self.gutter_width(frame),
        space_width: self.measured_char_width(),
        render_whitespace: self.options.render_whitespace,
        render_control_characters: self.options.render_control_characters,
        editor_has_focus: self.editor_has_focus,
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
    let position = self.layout.position()
    self.did_scroll.fire({
      scroll_top: position.scroll_top,
      scroll_left: position.scroll_left,
    })
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
  let desired = self.layout.visible_window(overscan=@core.line_overscan)
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
