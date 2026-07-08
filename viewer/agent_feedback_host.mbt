// The viewer core's side of the agent-feedback contrib — the editor
// lifecycle of `vscode/src/vs/sessions/contrib/agentFeedback/browser/
// agentFeedbackEditorInputContribution.ts` (`AgentFeedbackEditorInputContribution`):
// service subscriptions, the hover "+" glyph decoration and its gates
// (`_updateHoverGlyph`), the reserved gutter lane
// (`_updateReservedGutterSpace`), the selection → inline-input flow
// (`_onSelectionChanged` / `_show` / `_updatePosition`) and the glyph-click
// line selection (`_selectLine`). The widget DOM lives in
// `viewer/contrib/agent_feedback/browser`; the DOM-free store and grouping
// in `viewer/contrib/agent_feedback`. Kept here per the foreign-method rule
// (every `Viewer::` method lives in `Viewer`'s own package).
//
// Deviations from the source, recorded up front: the session scope gate is
// the service's `is_feedback_enabled` (the host decides which files are in
// scope); Escape and Ctrl/Cmd+I route through the keybinding registry
// instead of an editor-DOM keydown listener (and the readonly-editor
// "typing steals focus into the input" arm is dropped — the viewer is
// always readonly, but its editor keys are navigation-only, so there is no
// typing to steal); blur auto-hide is the widget's own empty-blur event
// rather than the editor-blur `setTimeout(0)` dance; and the editor-resize
// reposition rides the scroll event (the viewer has no separate
// `onDidLayoutChange`).

///|
/// `_RESERVED_GUTTER_WIDTH` (`agentFeedbackEditorInputContribution.ts:252`):
/// extra lane width reserved so the add glyph renders fully.
let agent_feedback_reserved_gutter_px : Int = 18

///|
/// The overlay-widget id of the singleton input widget
/// (`AgentFeedbackInputWidget._ID`).
let agent_feedback_input_widget_id : String = "agentFeedback.inputWidget"

///|
/// `registerEditorContribution(AgentFeedbackEditorInputContribution.ID, …,
/// Eventually)` (`agentFeedbackEditorInputContribution.ts:911`) plus the
/// Escape/Ctrl+I routing the upstream contribution wired as DOM listeners.
fn register_agent_feedback_contribution(
  registry : EditorContributionRegistry,
) -> Unit {
  registry.register_editor_contribution(
    "agentFeedback.editorInputContribution",
    Eventually,
    viewer => {
      let subscriptions = viewer.hook_agent_feedback()
      {
        id: "agentFeedback.editorInputContribution",
        dispose: () => {
          for subscription in subscriptions {
            subscription.dispose()
          }
        },
      }
    },
  )
  // The editor-level Escape arm of `_registerWidgetListeners` ("Don't
  // capture Escape … this._hide()"): close the input while the editor has
  // focus. Escape inside the textarea is the widget's own keydown.
  registry.register_editor_command(
    "agentFeedback.cancelInput",
    viewer => viewer.agent_feedback_input_visible,
    viewer => viewer.hide_agent_feedback_input(refocus_editor=false),
    [("Escape", false, false)],
  )
  // "Ctrl+I / Cmd+I explicitly focuses the feedback input".
  registry.register_editor_command(
    "agentFeedback.focusInput",
    viewer => viewer.agent_feedback_input_visible,
    viewer => viewer.focus_agent_feedback_input(),
    [("i", false, true)],
  )
  register_agent_feedback_widgets_contribution(registry)
}

///|
/// The constructor-time wiring of `AgentFeedbackEditorInputContribution`:
/// service, cursor/model, scroll, and mouse subscriptions.
fn Viewer::hook_agent_feedback(self : Viewer) -> Array[@base_common.Disposable] {
  self.sync_agent_feedback_lane()
  [
    self.services.agent_feedback.on_did_change_feedback(event => {
      if self.is_current_resource(event.resource) {
        self.sync_agent_feedback_lane()
        // A feedback item may have landed on the glyph line; re-evaluate
        // the "line already has feedback" gate.
        let line = self.agent_feedback_hover_line
        if line >= 1 {
          self.clear_agent_feedback_hover_glyph()
          self.update_agent_feedback_hover_glyph(line)
        }
      }
    }),
    self.on_did_change_model(_ => self.on_agent_feedback_model_changed()),
    self.on_did_change_cursor_selection(_ => {
      self.on_agent_feedback_selection_changed()
    }),
    self.on_did_scroll_change(_ => {
      if self.agent_feedback_input_visible {
        self.update_agent_feedback_input_position()
      }
    }),
    self.on_mouse_move(event => self.on_agent_feedback_mouse_move(event)),
    self.on_mouse_leave(_ => self.clear_agent_feedback_hover_glyph()),
    self.on_mouse_down(event => self.on_agent_feedback_mouse_down(event.target)),
    self.on_mouse_up(event => self.on_agent_feedback_mouse_up(event.target)),
  ]
}

///|
/// Whether a service event's resource is the installed model's —
/// the per-editor filter every contribution subscription applies
/// (previously homed with the comments contrib).
fn Viewer::is_current_resource(
  self : Viewer,
  resource : @base_common.Uri,
) -> Bool {
  match self.text_model {
    Some(model) => model.uri.to_string() == resource.to_string()
    None => false
  }
}

///|
/// The model line under a mouse target (gutter targets carry view lines).
fn Viewer::mouse_target_model_line(
  self : Viewer,
  target : @viewer_common.MouseTarget,
) -> Int {
  guard target.line_number >= 1 else { return 0 }
  match self.view_model {
    Some(view_model) =>
      view_model.lines().model_line_number_of_view_line(target.line_number)
    None => target.line_number
  }
}

///|
/// Whether the current model's resource has the feedback affordances on —
/// the `_getSessionForFile` stand-in.
fn Viewer::agent_feedback_enabled(self : Viewer) -> Bool {
  match self.text_model {
    Some(model) => self.services.agent_feedback.is_feedback_enabled(model.uri)
    None => false
  }
}

///|
/// `_onModelChanged`: hide, clear the glyph, drop the one-shot suppress, and
/// re-evaluate the lane for the new resource.
fn Viewer::on_agent_feedback_model_changed(self : Viewer) -> Unit {
  self.hide_agent_feedback_input(refocus_editor=false)
  self.clear_agent_feedback_hover_glyph()
  self.agent_feedback_suppress_selection_once = false
  self.sync_agent_feedback_lane()
}

// --- reserved lane ----------------------------------------------------------------

///|
/// `_updateReservedGutterSpace`: reserve extra room in the line-decorations
/// margin while the resource offers feedback, restore the host's base width
/// when it no longer does (the comments contrib's store/restore shape; the
/// upstream added/subtracted a delta).
fn Viewer::sync_agent_feedback_lane(self : Viewer) -> Unit {
  let needed = self.agent_feedback_enabled()
  match (needed, self.agent_feedback_lane_base_width) {
    (true, None) => {
      let base = self.options.line_decorations_width
      self.agent_feedback_lane_base_width = Some(base)
      self.update_options({
        ..self.options,
        line_decorations_width: base + agent_feedback_reserved_gutter_px,
      })
    }
    (false, Some(base)) => {
      self.agent_feedback_lane_base_width = None
      self.update_options({ ..self.options, line_decorations_width: base })
    }
    _ => ()
  }
}

// --- hover "+" glyph ---------------------------------------------------------------

///|
/// `_onEditorMouseMove`: the glyph follows the hovered line unless the input
/// is open (or holds a draft).
fn Viewer::on_agent_feedback_mouse_move(
  self : Viewer,
  event : EditorMouseEvent,
) -> Unit {
  if self.agent_feedback_input_visible || self.agent_feedback_has_draft() {
    self.clear_agent_feedback_hover_glyph()
    return
  }
  let line = match event.target.kind {
    GutterLineNumbers | GutterLineDecorations | ContentText | ContentEmpty =>
      self.mouse_target_model_line(event.target)
    _ => -1
  }
  self.update_agent_feedback_hover_glyph(line)
}

///|
/// `_updateHoverGlyph` and its gates: a valid, non-empty line in an enabled
/// resource whose line has no existing feedback.
fn Viewer::update_agent_feedback_hover_glyph(self : Viewer, line : Int) -> Unit {
  guard self.text_model is Some(model) else {
    self.clear_agent_feedback_hover_glyph()
    return
  }
  if line < 1 || line > model.snapshot.line_count() {
    self.clear_agent_feedback_hover_glyph()
    return
  }
  // "Don't offer feedback on empty lines (nothing to comment on)."
  if model.snapshot.get_line_first_non_whitespace_column(line) == 0 {
    self.clear_agent_feedback_hover_glyph()
    return
  }
  if self.agent_feedback_hover_line == line {
    return
  }
  if !self.agent_feedback_enabled() {
    self.clear_agent_feedback_hover_glyph()
    return
  }
  // "Don't render the add glyph on lines that already have a feedback
  // comment" (the add affordance would overlap the comment's gutter spot).
  if agent_feedback_line_has_feedback(
      self.services.agent_feedback.get_feedback(model.uri),
      line,
    ) {
    self.clear_agent_feedback_hover_glyph()
    return
  }
  self.agent_feedback_hover_line = line
  self.agent_feedback_hover_decoration_ids = model.delta_decorations(
    self.agent_feedback_hover_decoration_ids,
    [
      {
        range: Range(line, 1, line, 1),
        options: ModelDecorationOptions(
          "",
          is_whole_line=true,
          lines_decorations_class_name="agent-feedback-glyph line-hover",
          description="agent-feedback-hover-glyph",
        ),
      },
    ],
    owner_id=self.editor_id,
  )
}

///|
/// `_lineHasExistingFeedback`, resolved against unresolved items only (a
/// resolved item is invisible, so its line offers the add affordance again).
fn agent_feedback_line_has_feedback(
  items : Array[@agent_feedback.AgentFeedback],
  line : Int,
) -> Bool {
  items.search_by(item => {
    item.state != Resolved &&
    line >= item.range.start_line_number &&
    line <= item.range.end_line_number
  })
  is Some(_)
}

///|
/// `_clearHoverGlyph`.
fn Viewer::clear_agent_feedback_hover_glyph(self : Viewer) -> Unit {
  if self.agent_feedback_hover_line == -1 {
    return
  }
  self.agent_feedback_hover_line = -1
  guard self.text_model is Some(model) else {
    self.agent_feedback_hover_decoration_ids = []
    return
  }
  self.agent_feedback_hover_decoration_ids = model.delta_decorations(
    self.agent_feedback_hover_decoration_ids,
    [],
    owner_id=self.editor_id,
  )
}

// --- mouse → input flow --------------------------------------------------------------

///|
/// Whether the mouse target is the rendered hover glyph. Upstream checks the
/// DOM class (`_isHoverGlyphTarget`); the viewer's lane class *is* the
/// hover-line decoration, so "a line-decorations hit on the glyph's line" is
/// the same predicate, DOM-free (the comments contrib precedent).
fn Viewer::is_agent_feedback_glyph_target(
  self : Viewer,
  target : @viewer_common.MouseTarget,
) -> Bool {
  target.kind == GutterLineDecorations &&
  self.agent_feedback_hover_line >= 1 &&
  self.mouse_target_model_line(target) == self.agent_feedback_hover_line
}

///|
/// `onMouseDown`: a glyph hit selects the line (which opens the input via
/// the selection-change handler); anything else records the pending press
/// and auto-hides. Widget-internal presses never reach here — the widget's
/// containment stops propagation (`_isWidgetTarget`).
fn Viewer::on_agent_feedback_mouse_down(
  self : Viewer,
  target : @viewer_common.MouseTarget,
) -> Unit {
  if self.is_agent_feedback_glyph_target(target) {
    let line = self.mouse_target_model_line(target)
    self.select_agent_feedback_line(line)
    return
  }
  self.agent_feedback_mouse_down = true
  self.auto_hide_agent_feedback_input()
}

///|
/// `onMouseUp`: the press ended; re-evaluate the selection (a drag-selection
/// finished here opens the input).
fn Viewer::on_agent_feedback_mouse_up(
  self : Viewer,
  target : @viewer_common.MouseTarget,
) -> Unit {
  self.agent_feedback_mouse_down = false
  if self.is_agent_feedback_glyph_target(target) {
    return
  }
  self.on_agent_feedback_selection_changed()
}

///|
/// `_selectLine`: select the whole clicked line, focus the editor (the
/// selection-change handler opens the input synchronously), then move focus
/// into the input so typing can start immediately.
fn Viewer::select_agent_feedback_line(self : Viewer, line : Int) -> Unit {
  if self.agent_feedback_input_visible && self.agent_feedback_has_draft() {
    self.focus_agent_feedback_input()
    return
  }
  guard self.text_model is Some(model) else { return }
  if line < 1 || line > model.snapshot.line_count() {
    return
  }
  if model.snapshot.get_line_first_non_whitespace_column(line) == 0 {
    return
  }
  let max_column = model.snapshot.line_text(line - 1).length() + 1
  self.set_selection(
    @core.Selection::from_positions(
      Position(line, 1),
      Position(line, max_column),
    ),
  )
  self.focus()
  // The selection change while unfocused was ignored; the focused
  // re-evaluation below opens the input for the fresh selection.
  self.on_agent_feedback_selection_changed()
  self.focus_agent_feedback_input()
}

// --- selection → input ---------------------------------------------------------------

///|
/// `_onSelectionChanged`: the non-empty selection drives the input's
/// presence; a draft freezes it; the anchor follows the selection's active
/// end (below an LTR selection, above an RTL one).
fn Viewer::on_agent_feedback_selection_changed(self : Viewer) -> Unit {
  if self.agent_feedback_suppress_selection_once {
    self.agent_feedback_suppress_selection_once = false
    return
  }
  if self.agent_feedback_mouse_down || !self.has_text_focus() {
    return
  }
  if self.agent_feedback_input_visible && self.agent_feedback_has_draft() {
    return
  }
  guard self.get_selection() is Some(selection) && !selection.is_empty() else {
    self.auto_hide_agent_feedback_input()
    return
  }
  guard self.text_model is Some(_) && self.agent_feedback_enabled() else {
    self.auto_hide_agent_feedback_input()
    return
  }
  let prefer_below = selection.direction() == LTR
  let anchor = if prefer_below { selection.end() } else { selection.start() }
  let range : @base_common.Range = Range(
    selection.start().line_number,
    selection.start().column,
    selection.end().line_number,
    selection.end().column,
  )
  self.show_agent_feedback_input(range, anchor, prefer_below, focus_input=false)
}

///|
/// `_show`.
fn Viewer::show_agent_feedback_input(
  self : Viewer,
  range : @base_common.Range,
  anchor : @base_common.Position,
  prefer_below : Bool,
  focus_input~ : Bool,
) -> Unit {
  let widget = self.ensure_agent_feedback_input()
  self.clear_agent_feedback_hover_glyph()
  self.agent_feedback_input_visible = true
  self.agent_feedback_pinned_range = Some(range)
  self.agent_feedback_anchor = Some(anchor)
  self.agent_feedback_prefer_below = prefer_below
  widget.set_placeholder("Add Feedback")
  widget.clear_input()
  widget.show()
  self.update_agent_feedback_input_position()
  if focus_input {
    widget.focus_input()
  }
}

///|
/// `_ensureWidget`: the widget and its overlay mount are created once per
/// viewer, on first use.
fn Viewer::ensure_agent_feedback_input(
  self : Viewer,
) -> @agent_feedback_browser.AgentFeedbackInputWidget {
  match self.agent_feedback_input {
    Some(widget) => widget
    None => {
      let widget = @agent_feedback_browser.AgentFeedbackInputWidget::new({
        on_add: () => self.add_agent_feedback_from_input(submit=false),
        on_add_and_submit: () => self.add_agent_feedback_from_input(submit=true),
        on_cancel: () => self.hide_agent_feedback_input(refocus_editor=true),
        on_layout: () => self.update_agent_feedback_input_position(),
        on_blur_empty: () => self.auto_hide_agent_feedback_input(),
        content_width: () => {
          let layout = self.get_layout_info()
          let width = layout.width - layout.content_left
          if width > 0.0 {
            width
          } else {
            0.0
          }
        },
      })
      self.agent_feedback_input = Some(widget)
      self.add_overlay_widget(
        agent_feedback_input_widget_id,
        widget.get_dom_node(),
      )
      widget
    }
  }
}

///|
fn Viewer::agent_feedback_has_draft(self : Viewer) -> Bool {
  match self.agent_feedback_input {
    Some(widget) => widget.has_text()
    None => false
  }
}

///|
/// `_hide` (+ the `_hideAndRefocusEditor` variant the add/cancel paths use:
/// the refocus suppresses the selection re-evaluation once).
fn Viewer::hide_agent_feedback_input(
  self : Viewer,
  refocus_editor~ : Bool,
) -> Unit {
  if !self.agent_feedback_input_visible {
    return
  }
  self.agent_feedback_input_visible = false
  self.agent_feedback_pinned_range = None
  self.agent_feedback_anchor = None
  match self.agent_feedback_input {
    Some(widget) => {
      widget.hide()
      widget.clear_input()
    }
    None => ()
  }
  if refocus_editor {
    self.agent_feedback_suppress_selection_once = true
    self.focus()
  }
}

///|
/// `_autoHide`: never discard a draft.
fn Viewer::auto_hide_agent_feedback_input(self : Viewer) -> Unit {
  if self.agent_feedback_has_draft() {
    return
  }
  self.hide_agent_feedback_input(refocus_editor=false)
}

///|
fn Viewer::focus_agent_feedback_input(self : Viewer) -> Unit {
  if self.agent_feedback_input_visible {
    match self.agent_feedback_input {
      Some(widget) => widget.focus_input()
      None => ()
    }
  }
}

// --- submit ---------------------------------------------------------------------------

///|
/// `_addFeedback` / `_addFeedbackAndSubmit`: store the draft over the pinned
/// range (falling back to the live selection like upstream), then hide and
/// refocus. The submit arm marks the accepted items submitted; the host
/// reacts to the service's submit event (the chat hand-off upstream drives
/// here stays outside the viewer).
fn Viewer::add_agent_feedback_from_input(self : Viewer, submit~ : Bool) -> Unit {
  guard self.agent_feedback_input is Some(widget) else { return }
  let text = widget.value().trim().to_owned()
  if text.is_empty() {
    return
  }
  let range = match self.agent_feedback_pinned_range {
    Some(range) => Some(range)
    None =>
      match self.get_selection() {
        Some(selection) =>
          Some(
            Range(
              selection.start().line_number,
              selection.start().column,
              selection.end().line_number,
              selection.end().column,
            ),
          )
        None => None
      }
  }
  guard range is Some(range) && self.text_model is Some(model) else { return }
  let service = self.services.agent_feedback
  service.add_feedback(model.uri, range, text) |> ignore
  self.hide_agent_feedback_input(refocus_editor=true)
  if submit {
    service.mark_feedback_submitted(model.uri)
  }
}

// --- positioning ----------------------------------------------------------------------

///|
/// `_updatePosition` + `_getPositioningTarget`: anchor at the pinned
/// position (or the live selection's active end), prefer below/above by the
/// selection direction, flip when out of bounds, clamp into the editor and
/// right of the gutter.
fn Viewer::update_agent_feedback_input_position(self : Viewer) -> Unit {
  guard self.agent_feedback_input is Some(widget) &&
    self.agent_feedback_input_visible else {
    return
  }
  let target : (@base_common.Position, Bool)? = match
    (self.agent_feedback_pinned_range, self.agent_feedback_anchor) {
    (Some(_), Some(anchor)) => Some((anchor, self.agent_feedback_prefer_below))
    _ =>
      match self.get_selection() {
        Some(selection) =>
          if selection.is_empty() {
            None
          } else {
            let prefer_below = selection.direction() == LTR
            let anchor = if prefer_below {
              selection.end()
            } else {
              selection.start()
            }
            Some((anchor, prefer_below))
          }
        None => None
      }
  }
  guard target is Some((anchor, prefer_below)) else {
    self.auto_hide_agent_feedback_input()
    return
  }
  guard self.get_scrolled_visible_position(anchor) is Some(scrolled) else {
    return
  }
  let layout = self.get_layout_info()
  let widget_height = widget.measured_height()
  let widget_width = widget.measured_width()
  let line_height = scrolled.height
  let mut top = if prefer_below {
    // Cursor at the selection's bottom → below the line, flipping above
    // when out of space.
    let below = scrolled.top + line_height
    if below + widget_height > layout.height {
      scrolled.top - widget_height
    } else {
      below
    }
  } else {
    // Cursor at the selection's top → above the line, flipping below.
    let above = scrolled.top - widget_height
    if above < 0.0 {
      scrolled.top + line_height
    } else {
      above
    }
  }
  // Clamp vertically into the editor.
  let max_top = layout.height - widget_height
  if top > max_top {
    top = max_top
  }
  if top < 0.0 {
    top = 0.0
  }
  // Clamp horizontally: never over the gutter, never past the right edge.
  let min_left = layout.content_left
  let mut max_left = layout.width - widget_width
  if max_left < min_left {
    max_left = min_left
  }
  let mut left = scrolled.left
  if left < min_left {
    left = min_left
  }
  if left > max_left {
    left = max_left
  }
  widget.set_position(top, left)
}
