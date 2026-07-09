///|
/// Hooks the view's native input listeners. The pointer input (moves, downs,
/// ups, leaves, selection drags) is owned entirely by the
/// `viewer/browser/controller` `MouseHandler`, which registers its own DOM
/// listeners on the view root through `EditorMouseEventFactory` — the viewer
/// builds it here with a `PointerHandlerHelper` closing over the view (the
/// local analog of Monaco's `View._createPointerHandlerHelper`). Copy,
/// keyboard, focus tracking, wheel and the scrollbar/browser-reveal cluster
/// stay here.
fn Viewer::hook_view_input(self : Viewer, view : @view.View) -> Unit {
  let handler = @controller.MouseHandler::new(self.pointer_handler_helper(view))
  self.mouse_handler = Some(handler)
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
  view.root.add_event_listener("copy", event => {
    if self.handle_copy_event(event) {
      event.prevent_default()
      event.stop_propagation()
    }
  })
  // The editor owns its keyboard input (Monaco routes keys through the hidden
  // textarea / edit context into editor commands); the focusable root receives
  // keys once the mousedown handler focuses it.
  view.root.add_event_listener("keydown", event => {
    match event.to_keyboard_event() {
      Some(keyboard) =>
        if self.handle_editor_key_down(
            keyboard.key(),
            alt=keyboard.alt_key(),
            ctrl_cmd=keyboard.ctrl_key() || keyboard.meta_key(),
            shift=keyboard.shift_key(),
          ) {
          event.prevent_default()
          event.stop_propagation()
        }
      None => ()
    }
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
}

///|
/// The once-per-viewer document-level drag listeners for scrollbar-thumb
/// drags (drag moves and drag ends land outside the editor box). They
/// delegate to the *current* per-view `mouse_handler` — the per-view
/// listeners die with the view's DOM subtree at detach, but document
/// listeners cannot, so these hook once at `attach`. Selection drags no
/// longer ride here: the `MouseDownOperation`'s
/// `GlobalEditorPointerMoveMonitor` monitors them per gesture, like Monaco.
fn Viewer::hook_document_input(self : Viewer) -> Unit {
  if self.document_input_hooked {
    return
  }
  self.document_input_hooked = true
  let document = @rdom.document()
  document.add_event_listener("mousemove", event => {
    match self.mouse_handler {
      Some(handler) => handler.handle_scrollable_drag_move(event)
      None => ()
    }
  })
  document.add_event_listener("mouseup", _ => {
    match self.mouse_handler {
      Some(handler) => handler.end_scrollable_drag()
      None => ()
    }
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
  shift? : Bool = false,
) -> Bool {
  if editor_registry().dispatch_keybinding(self, key, alt~, ctrl_cmd~, shift~) {
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
/// Re-derives the active `FontInfo` from the current options: through
/// `FontMeasurements.readFontInfo` when a DOM view exists (Monaco's
/// `_readConfiguration`), the headless estimate otherwise. A changed line
/// height re-flows the layout; the view root is restyled in place.
fn Viewer::refresh_font_info(self : Viewer) -> Unit {
  let bare = self.options.bare_font_info(
    pixel_ratio=@browser_config.device_pixel_ratio(),
  )
  let font_info = match self.get_view() {
    Some(_) => @browser_config.font_measurements().read_font_info(bare)
    None => @config.FontInfo::estimated(bare)
  }
  if font_info.equals(self.font_info) {
    return
  }
  self.font_info = font_info
  match self.get_view_model() {
    Some(view_model) =>
      view_model.view_layout.set_line_height(font_info.line_height) |> ignore
    None => ()
  }
  match self.get_view() {
    Some(view) => self.apply_font_info_to_view(view)
    None => ()
  }
}

///|
/// Monaco `applyFontInfo` on the editor root (`view.ts`). The stylesheets
/// consume the font through the `--editor-*` custom properties
/// (`view_lines.css` / `margin.css` / `theme.css`), so those are refreshed
/// alongside the inline font style.
fn Viewer::apply_font_info_to_view(self : Viewer, view : @view.View) -> Unit {
  let bare = self.font_info.bare()
  @browser_config.apply_font_info(view.root, bare)
  @browser_config.set_style_property(
    view.root,
    "--editor-font-family",
    bare.get_massaged_font_family(),
  )
  @browser_config.set_style_property(
    view.root,
    "--editor-font-size",
    "\{bare.font_size}px",
  )
  @browser_config.set_style_property(
    view.root,
    "--editor-line-height",
    "\{bare.line_height}px",
  )
}

///|
/// Read phase of the render loop: the view box, the measured font, and
/// the derived gutter width feed the layout model and every later hit
/// test. DOM scroll offsets are treated only as browser reveal deltas;
/// `ViewLayout` owns the editor scroll truth.
fn Viewer::measure(self : Viewer, view : @view.View) -> Unit {
  let rect = view.root.get_bounding_client_rect()
  self.refresh_font_info()
  let gutter_width = match self.get_view_model() {
    Some(view_model) => self.gutter_width(view_model.line_count())
    None => 0.0
  }
  let content_width = rect.get_width() - gutter_width
  self.measured_content_width = if content_width > 0.0 {
    content_width
  } else {
    0.0
  }
  self.measured_height = rect.get_height()
  match self.get_view_model() {
    Some(view_model) =>
      view_model.view_layout.set_viewport_size(
        width=self.measured_content_width,
        height=self.measured_height,
      )
      |> ignore
    None => ()
  }
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
  guard self.get_view_model() is Some(view_model) else { return }
  let content_width = if self.options.soft_wrap && self.soft_wrap_column > 0 {
    self.measured_content_width
  } else {
    self.max_line_length.to_double() * self.measured_char_width() +
    @core.code_right_padding
  }
  view_model.view_layout.set_content_width(content_width) |> ignore
}

///|
/// `fontInfo.typicalHalfwidthCharacterWidth`, the uniform monospace advance
/// every width computation keys on.
fn Viewer::measured_char_width(self : Viewer) -> Double {
  self.font_info.typical_halfwidth_character_width
}

///|
/// The line-number band width — Monaco's `layoutInfo.lineNumbersWidth`,
/// `Math.round(digitCount * maxDigitWidth)` with the digit count at least
/// `line_numbers_min_chars` (`editorOptions.ts:2914-2917`).
fn Viewer::line_numbers_width(self : Viewer, line_count : Int) -> Double {
  let digits = line_count.to_string().length()
  let slots = digits.max(self.options.line_numbers_min_chars)
  (slots.to_double() * self.font_info.max_digit_width).round()
}

///|
/// The line-decorations lane width the layout uses — Monaco's
/// `EditorLayoutInfoComputer` (`editorOptions.ts:2906-2910`): the configured
/// `lineDecorationsWidth`, plus 16px for the folding controls when folding
/// is enabled and `showFoldingControls` is not `never`.
fn Viewer::layout_decorations_width(self : Viewer) -> Double {
  let folding_reserve : Double = if self.options.folding &&
    self.options.show_folding_controls != Never {
    16.0
  } else {
    0.0
  }
  self.options.line_decorations_width.to_double() + folding_reserve
}

///|
/// The full margin width: the line-number band plus the line-decorations
/// lane — Monaco's `layoutInfo.contentLeft` (the viewer has no glyph margin,
/// so `contentLeft = lineNumbersWidth + decorationsWidth`).
fn Viewer::gutter_width(self : Viewer, line_count : Int) -> Double {
  self.line_numbers_width(line_count) + self.layout_decorations_width()
}
