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
  view.add_disposable(@base_common.Disposable::from(() => handler.dispose()))
  // Monaco tracks focus on the hidden textarea / edit context and fans it out
  // as `ViewFocusChangedEvent`; the viewer's focusable surface is the root
  // itself. `focus`/`blur` do not bubble, so these observe only the root's own
  // focus and emit only on the actual Bool transition.
  add_view_event_listener(view, view.root, "focus", _ => {
    if !self.editor_has_focus {
      self.editor_has_focus = true
      self.emit_view_event(
        ViewFocusChanged(
          @view.ViewFocusChangedEvent::ViewFocusChangedEvent(true),
        ),
      )
      self.schedule_render()
    }
  })
  add_view_event_listener(view, view.root, "blur", _ => {
    if self.editor_has_focus {
      self.editor_has_focus = false
      self.emit_view_event(
        ViewFocusChanged(
          @view.ViewFocusChangedEvent::ViewFocusChangedEvent(false),
        ),
      )
      self.schedule_render()
    }
  })
  add_view_event_listener(view, view.root, "copy", event => {
    if self.handle_copy_event(event) {
      event.prevent_default()
      event.stop_propagation()
    }
  })
  // The editor owns its keyboard input (Monaco routes keys through the hidden
  // textarea / edit context into editor commands); the focusable root receives
  // keys once the mousedown handler focuses it.
  add_view_event_listener(view, view.root, "keydown", event => {
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
  add_view_event_listener(view, view.overflow_guard, "wheel", event => {
    match event.to_wheel_event() {
      Some(wheel) =>
        if handler.handle_editor_wheel(event, wheel) {
          event.prevent_default()
          event.stop_propagation()
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
/// Registers one DOM listener in the per-model View lifetime store. The same
/// closure identity is used for removal, and a late registration is disposed
/// immediately by `View::add_disposable`.
fn add_view_event_listener(
  view : @view.View,
  element : @rdom.Element,
  event_name : String,
  listener : (@rdom.Event) -> Unit,
) -> Unit {
  element.add_event_listener(event_name, listener)
  view.add_disposable(
    @base_common.Disposable::from(() => {
      element.remove_event_listener(event_name, listener)
    }),
  )
}

///|
/// The readonly viewer's keyboard entry: the registered commands resolve
/// in registration order (`editor.action.hideHover` on Escape, the focused
/// hover navigation cluster, then the 16 primary cursor navigation bindings).
/// Returns whether the key was handled (and the browser default
/// suppressed). Exact chord matching leaves unregistered Alt/CtrlCmd variants
/// to the browser. A cursor command whose model-bound precondition wins stays
/// handled even when it reaches a document boundary and changes no state.
fn Viewer::handle_editor_key_down(
  self : Viewer,
  key : String,
  alt~ : Bool,
  ctrl_cmd~ : Bool,
  shift? : Bool = false,
) -> Bool {
  editor_registry().dispatch_keybinding(self, key, alt~, ctrl_cmd~, shift~)
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
/// Monaco's `container.contains(node)` branch, also used to avoid moving an
/// already nested placeholder back to the host root.
extern "js" fn element_contains_node(
  container : @rdom.Element,
  child : @rdom.Element,
) -> Bool =
  #| (container, child) => container.contains(child)

///|
/// Removes an owned descendant without assuming it is a direct child. This is
/// the source `contains` guard plus `node.remove()`, avoiding `removeChild`
/// exceptions when host DOM was rearranged.
extern "js" fn remove_element_if_contained(
  container : @rdom.Element,
  child : @rdom.Element,
) -> Unit =
  #| (container, child) => {
  #|   if (container.contains(child)) child.remove();
  #| }

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
  let previous_font_info = self.font_info
  let previous_soft_wrap_column = self.soft_wrap_column
  let previous_layout_identity = self.layout_identity(
    self.layout_model_line_count,
    self.layout_line_count,
  )
  let model_line_count = match self.get_model() {
    Some(model) => model.snapshot.line_count()
    None => 0
  }
  let event_batch = self.begin_view_event_batch()
  self.refresh_font_info()
  let gutter_width = self.gutter_width(model_line_count)
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
  let current_view_line_count = match self.get_view_model() {
    Some(view_model) => view_model.line_count()
    None => 0
  }
  let current_model_line_count = match self.get_model() {
    Some(model) => model.snapshot.line_count()
    None => 0
  }
  self.layout_model_line_count = current_model_line_count
  self.layout_line_count = current_view_line_count
  let layout_info_changed = previous_layout_identity !=
    self.layout_identity(current_model_line_count, current_view_line_count)
  match
    view_configuration_changed_event(
      self.options,
      self.options,
      previous_font_info,
      self.font_info,
      previous_soft_wrap_column,
      self.soft_wrap_column,
      layout_info_changed~,
    ) {
    Some(event) => self.emit_view_event(ViewConfigurationChanged(event))
    None => ()
  }
  end_view_event_batch(event_batch)
}

///|
fn Viewer::sync_content_width(self : Viewer) -> Unit {
  guard self.get_view_model() is Some(view_model) else { return }
  // Rendered ViewLines now owns the measured maximum and feeds it into
  // ViewLayout. The Viewer only supplies the wrapping policy; logical UTF-16
  // length must never stand in for browser geometry.
  view_model.view_layout.set_is_viewport_wrapping(
    self.options.soft_wrap && self.soft_wrap_column > 0,
  )
  |> ignore
}

///|
/// `fontInfo.typicalHalfwidthCharacterWidth`, retained for wrapping-column and
/// pointer/drag calculations. Horizontal extent comes from rendered DOM width.
fn Viewer::measured_char_width(self : Viewer) -> Double {
  self.font_info.typical_halfwidth_character_width
}

///|
/// The line-number band width — Monaco's `layoutInfo.lineNumbersWidth`,
/// `Math.round(digitCount * maxDigitWidth)` with the digit count at least
/// `line_numbers_min_chars` (`editorOptions.ts:2914-2917`).
fn Viewer::line_numbers_width(self : Viewer, model_line_count : Int) -> Double {
  let digits = digit_count(model_line_count)
  let slots = digits.max(self.options.line_numbers_min_chars)
  (slots.to_double() * self.font_info.max_digit_width).round()
}

///|
/// `EditorConfiguration._digitCount`: base-10 digits with a minimum of one.
/// Line counts are nonnegative, but keeping the loop numeric (instead of
/// stringifying) preserves the source's decimal-band boundary behavior.
fn digit_count(value : Int) -> Int {
  let mut value = value
  let mut result = 0
  while value > 0 {
    value = value / 10
    result += 1
  }
  result.max(1)
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
fn Viewer::gutter_width(self : Viewer, model_line_count : Int) -> Double {
  self.line_numbers_width(model_line_count) + self.layout_decorations_width()
}

///|
/// Independent computed `EditorLayoutInfo` identity. Comparing only
/// `contentLeft` (the sum of the first two fields) loses compensated changes
/// where the line-number band shrinks as the decorations lane grows.
priv struct ViewerLayoutIdentity {
  line_numbers_width : Double
  decorations_width : Double
  content_left : Double
  content_width : Double
  height : Double
  view_line_count : Int
} derive(Eq)

///|
fn Viewer::layout_identity(
  self : Viewer,
  model_line_count : Int,
  view_line_count : Int,
) -> ViewerLayoutIdentity {
  let line_numbers_width = self.line_numbers_width(model_line_count)
  let decorations_width = self.layout_decorations_width()
  {
    line_numbers_width,
    decorations_width,
    content_left: line_numbers_width + decorations_width,
    content_width: self.measured_content_width,
    height: self.measured_height,
    view_line_count,
  }
}
