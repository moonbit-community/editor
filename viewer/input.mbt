///|
/// Hooks the view's native pointer listeners. Copy and hover-relevant
/// mouseleave stay on the viewer; all pointer input (mouse-select, scrollbar,
/// wheel, drag-autoscroll, browser-reveal) is delegated to the
/// `viewer/browser/controller` `MouseHandler`, which the viewer builds here with a
/// `PointerHandlerHelper` closing over the view — the local analog of Monaco's
/// `View._createPointerHandlerHelper`.
fn Viewer::hook_view_input(self : Viewer, view : @view.View) -> Unit {
  let handler = @controller.MouseHandler::new(self.pointer_handler_helper(view))
  self.mouse_handler = Some(handler)
  view.root.add_event_listener("mousemove", event => {
    match event.to_mouse_event() {
      Some(mouse) => {
        // Record the pointer position + modifiers for the hover controller before
        // the hit test, then drive selection (which notifies the hover move).
        self.record_hover_pointer(
          mouse.get_client_x().to_double(),
          mouse.get_client_y().to_double(),
          mouse_modifiers(mouse),
        )
        self.last_mouse_buttons = mouse.get_buttons()
        handler.handle_mouse_move(mouse)
      }
      None => ()
    }
  })
  view.root.add_event_listener("mousedown", event => {
    match event.to_mouse_event() {
      Some(mouse) => {
        // The mouse handler `preventDefault`s selection mousedowns, which
        // suppresses the browser's native focusing of the `tabindex` root, so
        // focus explicitly — Monaco equally focuses its hidden textarea
        // explicitly on editor mouse down (`focusTextArea()`).
        focus_element(view.root)
        self.on_editor_mouse_down(
          mouse.get_client_x().to_double(),
          mouse.get_client_y().to_double(),
        )
        handler.handle_mouse_down(event, mouse)
      }
      None => ()
    }
  })
  // Monaco tracks focus on the hidden textarea / edit context and fans it out
  // as `ViewFocusChangedEvent`; the viewer's focusable surface is the root
  // itself. `focus`/`blur` do not bubble, so these observe only the root's own
  // focus. The next scheduled render diffs the flag into `ViewFocusChanged`.
  view.root.add_event_listener("focus", _ => {
    if !self.editor_has_focus {
      self.editor_has_focus = true
      self.schedule_render()
    }
  })
  view.root.add_event_listener("blur", _ => {
    if self.editor_has_focus {
      self.editor_has_focus = false
      self.schedule_render()
    }
  })
  view.view_lines
  .get_dom_node()
  .add_event_listener("mousedown", event => {
    match event.to_mouse_event() {
      Some(mouse) => {
        self.on_editor_mouse_down(
          mouse.get_client_x().to_double(),
          mouse.get_client_y().to_double(),
        )
        handler.handle_mouse_down(event, mouse)
      }
      None => ()
    }
  })
  // Root-scoped mouseup for target-notified listeners (comments pairs it
  // with the mousedown); the document-level mouseup below stays the
  // drag-end/selection-finish path.
  view.root.add_event_listener("mouseup", event => {
    match event.to_mouse_event() {
      Some(mouse) => handler.handle_mouse_up(mouse)
      None => ()
    }
  })
  view.root.add_event_listener("copy", event => {
    if self.handle_copy_event(event) {
      event.prevent_default()
      event.stop_propagation()
    }
  })
  // The editor owns its keyboard input (Monaco routes keys through the hidden
  // textarea / edit context into editor commands); the focusable root receives
  // keys once the mousedown handler above focuses it.
  view.root.add_event_listener("keydown", event => {
    match event.to_keyboard_event() {
      Some(keyboard) =>
        if self.handle_editor_key_down(
            keyboard.key(),
            alt=keyboard.alt_key(),
            ctrl_cmd=keyboard.ctrl_key() || keyboard.meta_key(),
          ) {
          event.prevent_default()
          event.stop_propagation()
        }
      None => ()
    }
  })
  view.root.add_event_listener("mouseleave", event => {
    let (posx, posy) = match event.to_mouse_event() {
      Some(mouse) =>
        (mouse.get_client_x().to_double(), mouse.get_client_y().to_double())
      None => (-1.0, -1.0)
    }
    self.on_editor_mouse_leave(posx, posy)
  })
  view.overflow_guard.add_event_listener("wheel", event => {
    match event.to_wheel_event() {
      Some(wheel) => {
        event.prevent_default()
        event.stop_propagation()
        handler.handle_editor_wheel(wheel)
      }
      None => ()
    }
  })
  handler.hook_scrollable_scrollbar_input(
    view.editor_scrollbar.scrollable(),
    EditorScrollableElement,
  )
  handler.hook_browser_desperate_reveal()
  let document = @rdom.document()
  document.add_event_listener("mousemove", event => {
    handler.handle_scrollable_drag_move(event)
    handler.handle_selection_drag_move(event)
  })
  document.add_event_listener("mouseup", _ => {
    handler.end_scrollable_drag()
    handler.finish_selection()
  })
}

///|
/// The readonly viewer's keyboard entry: the registered commands resolve
/// first (`editor.action.hideHover` on Escape, gated on `hoverVisible`),
/// then the built-in scroll cluster (the
/// synthetic-scroll analog of Monaco's `EditorScroll` command family).
/// Returns whether the key was handled (and the browser default
/// suppressed). Unmodified keys only for the built-ins; chords fall through
/// to the browser like Monaco's unbound chords.
fn Viewer::handle_editor_key_down(
  self : Viewer,
  key : String,
  alt~ : Bool,
  ctrl_cmd~ : Bool,
) -> Bool {
  if editor_registry().dispatch_keybinding(self, key, alt~, ctrl_cmd~) {
    return true
  }
  if alt || ctrl_cmd {
    return false
  }
  match key {
    "PageUp" => {
      self.scroll_by_pages(-1)
      true
    }
    "PageDown" => {
      self.scroll_by_pages(1)
      true
    }
    "Home" => {
      self.scroll_home()
      true
    }
    "End" => {
      self.scroll_end()
      true
    }
    "ArrowUp" => {
      self.scroll_by_lines(-1)
      true
    }
    "ArrowDown" => {
      self.scroll_by_lines(1)
      true
    }
    _ => false
  }
}

///|
/// The pointer-event modifier flags the hover controller reads (`event.ctrlKey` /
/// `metaKey` / `altKey`), following the local-extern pattern already used for
/// `shiftKey` in `viewer/browser/controller`.
fn mouse_modifiers(mouse : @rdom.MouseEvent) -> @hover.EventModifiers {
  {
    ctrl: mouse_ctrl_key(mouse),
    meta: mouse_meta_key(mouse),
    alt: mouse_alt_key(mouse),
  }
}

///|
extern "js" fn mouse_ctrl_key(mouse : @rdom.MouseEvent) -> Bool = "(m) => !!m.ctrlKey"

///|
extern "js" fn mouse_meta_key(mouse : @rdom.MouseEvent) -> Bool = "(m) => !!m.metaKey"

///|
extern "js" fn mouse_alt_key(mouse : @rdom.MouseEvent) -> Bool = "(m) => !!m.altKey"

///|
/// FFI gap-fill (no `focus()` binding in the vendored `@rdom`).
/// `preventScroll`: focusing must not double-scroll the root the layout model
/// already positions.
extern "js" fn focus_element(el : @rdom.Element) -> Unit =
  #| (el) => el.focus({ preventScroll: true })

///|
/// Whether the document's active element sits inside `el` — the
/// `hasWidgetFocus` containment test (no `document.activeElement` binding in
/// the vendored `@rdom`).
extern "js" fn element_contains_active(el : @rdom.Element) -> Bool =
  #| (el) => el.contains(document.activeElement)

///|
/// Read phase of the render loop: the view box, the glyph probe, and
/// the derived gutter width feed the layout model and every later hit
/// test. DOM scroll offsets are treated only as browser reveal deltas;
/// `ViewLayout` owns the editor scroll truth.
fn Viewer::measure(self : Viewer, view : @view.View) -> Unit {
  let rect = view.root.get_bounding_client_rect()
  let probe_width = view.probe.get_bounding_client_rect().get_width()
  if probe_width > 0.0 {
    self.char_width = probe_width / @core.char_probe_text.length().to_double()
  }
  let gutter_width = match self.view_model {
    Some(view_model) => self.gutter_width(view_model.line_count())
    None => 0.0
  }
  let content_width = rect.get_width() - gutter_width
  self.view_layout.set_viewport_size(
    width=if content_width > 0.0 { content_width } else { 0.0 },
    height=rect.get_height(),
  )
  |> ignore
  let next_wrap_column = self.options.soft_wrap_column_for_content_width(
    content_width,
    self.measured_char_width(),
  )
  if next_wrap_column != self.soft_wrap_column {
    self.soft_wrap_column = next_wrap_column
    self.on_configuration_changed()
  } else {
    self.sync_content_width()
  }
}

///|
fn Viewer::sync_content_width(self : Viewer) -> Unit {
  let content_width = if self.options.soft_wrap && self.soft_wrap_column > 0 {
    self.view_layout.dimensions().width
  } else {
    self.max_line_length.to_double() * self.measured_char_width() +
    @core.code_right_padding
  }
  self.view_layout.set_content_width(content_width) |> ignore
}

///|
fn Viewer::measured_char_width(self : Viewer) -> Double {
  if self.char_width > 0.0 {
    self.char_width
  } else {
    @core.fallback_char_width
  }
}

///|
/// The line-number band width: digit slots (at least the old `min-width: 5ch`)
/// plus the gutter padding, in measured glyph advances — Monaco's
/// `layoutInfo.lineNumbersWidth`.
fn Viewer::line_numbers_width(self : Viewer, line_count : Int) -> Double {
  let digits = line_count.to_string().length()
  let slots = if digits > @core.gutter_min_digits {
    digits
  } else {
    @core.gutter_min_digits
  }
  slots.to_double() * self.measured_char_width() +
  @core.gutter_padding_px.to_double()
}

///|
/// The full margin width: the line-number band plus the line-decorations
/// lane — Monaco's `layoutInfo.contentLeft` (the viewer has no glyph margin,
/// so `contentLeft = lineNumbersWidth + decorationsWidth`).
fn Viewer::gutter_width(self : Viewer, line_count : Int) -> Double {
  self.line_numbers_width(line_count) +
  self.options.line_decorations_width.to_double()
}

///|
/// Builds the hit-test geometry for the current content from the layout
/// model, falling back to font constants before the first measurement.
fn Viewer::view_metrics(
  self : Viewer,
  line_count : Int,
) -> @viewer_common.ViewMetrics {
  {
    origin_x: 0.0,
    origin_y: 0.0,
    scroll_top: self.view_layout.position().scroll_top,
    scroll_left: self.view_layout.position().scroll_left,
    viewport_height: self.view_layout.dimensions().height,
    line_height: @core.editor_line_height,
    char_width: self.measured_char_width(),
    gutter_width: self.gutter_width(line_count),
    line_decorations_width: self.options.line_decorations_width.to_double(),
    view_zones: self.view_layout.view_zones(),
  }
}
