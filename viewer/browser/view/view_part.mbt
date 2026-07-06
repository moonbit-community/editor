///|
/// Private Monaco-shaped render lifecycle for browser view concerns. The
/// event-handling half (`on_view_event` / `should_render` / `set_should_render`
/// / `on_did_render`) mirrors Monaco's `ViewEventHandler`: a typed view event is
/// offered to every part, and a part that returns `true` is marked dirty for the
/// next render. `should_render` returns that accumulated flag (no longer a
/// snapshot diff). The render half (`on_before_render` / `prepare_render` /
/// `render`) mirrors Monaco's `ViewPart`/`DynamicViewOverlay`.
priv trait ViewPart {
  fn on_view_event(Self, ViewEvent) -> Bool
  fn should_render(Self) -> Bool
  fn set_should_render(Self, Bool) -> Unit
  fn on_before_render(Self, @view_layout.ViewportData) -> Unit
  fn prepare_render(Self, RenderingContext) -> Unit
  fn render(Self, RestrictedRenderingContext) -> Unit
  fn on_did_render(Self) -> Unit
}

///|
/// Dispatches a frame's view events to one part, accumulating its dirty flag.
/// Mirrors `ViewEventHandler.handleEvents`.
fn ViewPartHandle::handle_view_events(
  self : ViewPartHandle,
  events : Array[ViewEvent],
) -> Unit {
  for event in events {
    if self.on_view_event(event) {
      self.set_should_render(true)
    }
  }
}

///|
priv enum ViewPartHandle {
  ViewLinesPart(@view_lines.ViewLines)
  ViewZonesPart(@view_zones.ViewZones)
  ContentViewOverlaysPart(@selections.ContentViewOverlays)
  MarginViewOverlaysPart(@margin.MarginViewOverlays)
  ContentWidgetsPart(@content_widgets.ContentWidgets)
  ViewCursorsPart(@view_cursors.ViewCursors)
  OverlayWidgetsPart(@overlay_widgets.OverlayWidgets)
  EditorScrollbarPart(@editor_scrollbar.EditorScrollbar)
}

///|
fn default_view_parts(
  view_lines : @view_lines.ViewLines,
  view_zones : @view_zones.ViewZones,
  content_view_overlays : @selections.ContentViewOverlays,
  margin_view_overlays : @margin.MarginViewOverlays,
  content_widgets : @content_widgets.ContentWidgets,
  view_cursors : @view_cursors.ViewCursors,
  overlay_widgets : @overlay_widgets.OverlayWidgets,
  editor_scrollbar : @editor_scrollbar.EditorScrollbar,
) -> Array[ViewPartHandle] {
  [
    ViewLinesPart(view_lines),
    ViewZonesPart(view_zones),
    ContentViewOverlaysPart(content_view_overlays),
    MarginViewOverlaysPart(margin_view_overlays),
    ContentWidgetsPart(content_widgets),
    // Monaco pushes `viewCursors` after content widgets, before overlay
    // widgets (`view.ts:246-252`).
    ViewCursorsPart(view_cursors),
    OverlayWidgetsPart(overlay_widgets),
    EditorScrollbarPart(editor_scrollbar),
  ]
}

///|
impl ViewPart for ViewPartHandle with fn on_view_event(self, event) {
  match self {
    ViewLinesPart(part) => ViewPart::on_view_event(part, event)
    ViewZonesPart(part) => ViewPart::on_view_event(part, event)
    ContentViewOverlaysPart(part) => ViewPart::on_view_event(part, event)
    MarginViewOverlaysPart(part) => ViewPart::on_view_event(part, event)
    ContentWidgetsPart(part) => ViewPart::on_view_event(part, event)
    ViewCursorsPart(part) => ViewPart::on_view_event(part, event)
    OverlayWidgetsPart(part) => ViewPart::on_view_event(part, event)
    EditorScrollbarPart(part) => ViewPart::on_view_event(part, event)
  }
}

///|
impl ViewPart for ViewPartHandle with fn should_render(self) {
  match self {
    ViewLinesPart(part) => ViewPart::should_render(part)
    ViewZonesPart(part) => ViewPart::should_render(part)
    ContentViewOverlaysPart(part) => ViewPart::should_render(part)
    MarginViewOverlaysPart(part) => ViewPart::should_render(part)
    ContentWidgetsPart(part) => ViewPart::should_render(part)
    ViewCursorsPart(part) => ViewPart::should_render(part)
    OverlayWidgetsPart(part) => ViewPart::should_render(part)
    EditorScrollbarPart(part) => ViewPart::should_render(part)
  }
}

///|
impl ViewPart for ViewPartHandle with fn set_should_render(self, value) {
  match self {
    ViewLinesPart(part) => ViewPart::set_should_render(part, value)
    ViewZonesPart(part) => ViewPart::set_should_render(part, value)
    ContentViewOverlaysPart(part) => ViewPart::set_should_render(part, value)
    MarginViewOverlaysPart(part) => ViewPart::set_should_render(part, value)
    ContentWidgetsPart(part) => ViewPart::set_should_render(part, value)
    ViewCursorsPart(part) => ViewPart::set_should_render(part, value)
    OverlayWidgetsPart(part) => ViewPart::set_should_render(part, value)
    EditorScrollbarPart(part) => ViewPart::set_should_render(part, value)
  }
}

///|
impl ViewPart for ViewPartHandle with fn on_before_render(self, viewport) {
  match self {
    ViewLinesPart(part) => ViewPart::on_before_render(part, viewport)
    ViewZonesPart(part) => ViewPart::on_before_render(part, viewport)
    ContentViewOverlaysPart(part) => ViewPart::on_before_render(part, viewport)
    MarginViewOverlaysPart(part) => ViewPart::on_before_render(part, viewport)
    ContentWidgetsPart(part) => ViewPart::on_before_render(part, viewport)
    ViewCursorsPart(part) => ViewPart::on_before_render(part, viewport)
    OverlayWidgetsPart(part) => ViewPart::on_before_render(part, viewport)
    EditorScrollbarPart(part) => ViewPart::on_before_render(part, viewport)
  }
}

///|
impl ViewPart for ViewPartHandle with fn prepare_render(self, context) {
  match self {
    ViewLinesPart(part) => ViewPart::prepare_render(part, context)
    ViewZonesPart(part) => ViewPart::prepare_render(part, context)
    ContentViewOverlaysPart(part) => ViewPart::prepare_render(part, context)
    MarginViewOverlaysPart(part) => ViewPart::prepare_render(part, context)
    ContentWidgetsPart(part) => ViewPart::prepare_render(part, context)
    ViewCursorsPart(part) => ViewPart::prepare_render(part, context)
    OverlayWidgetsPart(part) => ViewPart::prepare_render(part, context)
    EditorScrollbarPart(part) => ViewPart::prepare_render(part, context)
  }
}

///|
impl ViewPart for ViewPartHandle with fn render(self, context) {
  match self {
    ViewLinesPart(part) => ViewPart::render(part, context)
    ViewZonesPart(part) => ViewPart::render(part, context)
    ContentViewOverlaysPart(part) => ViewPart::render(part, context)
    MarginViewOverlaysPart(part) => ViewPart::render(part, context)
    ContentWidgetsPart(part) => ViewPart::render(part, context)
    ViewCursorsPart(part) => ViewPart::render(part, context)
    OverlayWidgetsPart(part) => ViewPart::render(part, context)
    EditorScrollbarPart(part) => ViewPart::render(part, context)
  }
}

///|
impl ViewPart for ViewPartHandle with fn on_did_render(self) {
  match self {
    ViewLinesPart(part) => ViewPart::on_did_render(part)
    ViewZonesPart(part) => ViewPart::on_did_render(part)
    ContentViewOverlaysPart(part) => ViewPart::on_did_render(part)
    MarginViewOverlaysPart(part) => ViewPart::on_did_render(part)
    ContentWidgetsPart(part) => ViewPart::on_did_render(part)
    ViewCursorsPart(part) => ViewPart::on_did_render(part)
    OverlayWidgetsPart(part) => ViewPart::on_did_render(part)
    EditorScrollbarPart(part) => ViewPart::on_did_render(part)
  }
}

// `ViewPart` impl for `@view_zones.ViewZones` (`browser/view_parts/view_zones`).
// Kept here, not in that package, per the cycle-backlog fix: MoonBit's orphan
// rule lets the trait-owning package implement a trait for a foreign type,
// and `view_part.mbt` needs `ViewZones` as a concrete type anyway (the
// `ViewPartHandle` enum above), so this keeps `browser/view_parts/view_zones`
// from needing an import back into `browser/view/`.

///|
impl ViewPart for @view_zones.ViewZones with fn should_render(self) {
  self.should_render
}

///|
impl ViewPart for @view_zones.ViewZones with fn on_view_event(_self, event) {
  match event {
    ViewFlushed => true
    ViewLinesChanged => true
    ViewScrollChanged(e) =>
      e.window_changed || e.position_changed || e.dimensions_changed
    ViewZonesChanged => true
    _ => false
  }
}

///|
impl ViewPart for @view_zones.ViewZones with fn set_should_render(self, value) {
  self.should_render = value
}

///|
impl ViewPart for @view_zones.ViewZones with fn on_before_render(
  _self,
  _viewport,
) {
  ()
}

///|
impl ViewPart for @view_zones.ViewZones with fn prepare_render(self, context) {
  self.prepared = Some({
    zones: context.input.browser_view_zones,
    viewport: context.viewport,
  })
}

///|
impl ViewPart for @view_zones.ViewZones with fn render(self, context) {
  match self.prepared {
    Some(prepared) => {
      self.render_view_zones(
        prepared.zones,
        prepared.viewport,
        context.translate_y,
      )
      self.view_zones.set_attribute("style", context.content_transform)
    }
    None => ()
  }
}

///|
impl ViewPart for @view_zones.ViewZones with fn on_did_render(self) {
  self.should_render = false
  self.prepared = None
}

// `ViewPart` impl for `@view_lines.ViewLines` (`browser/view_parts/view_lines`).
// Kept here for the same reason as `@view_zones.ViewZones` above.

///|
impl ViewPart for @view_lines.ViewLines with fn should_render(self) {
  self.should_render
}

///|
impl ViewPart for @view_lines.ViewLines with fn on_view_event(self, event) {
  match event {
    ViewFlushed => true
    ViewLinesChanged => true
    // Inline decorations render inside the line HTML (`onDecorationsChanged`
    // → true, `viewLines.ts`).
    ViewDecorationsChanged => true
    ViewScrollChanged(e) =>
      e.window_changed || e.position_changed || e.dimensions_changed
    ViewConfigurationChanged(e) => e.gutter_width_changed || e.font_changed
    // `viewLine.ts:94-100` `onSelectionChanged`: a selection change only
    // dirties the lines when whitespace renders under the selection. Keyed off
    // the *last rendered* whitespace mode, mirroring Monaco's check of
    // `_renderedViewLine.input.renderWhitespace`.
    ViewCursorStateChanged => self.last_render_whitespace == Selection
    _ => false
  }
}

///|
impl ViewPart for @view_lines.ViewLines with fn set_should_render(self, value) {
  self.should_render = value
}

///|
impl ViewPart for @view_lines.ViewLines with fn on_before_render(
  _self,
  _viewport,
) {
  ()
}

///|
impl ViewPart for @view_lines.ViewLines with fn prepare_render(self, context) {
  // Per-line decorations arrive inside the viewport data (built lazily from
  // the model's decoration storage by `ViewModelDecorations`).
  self.prepared = Some({
    viewport: context.viewport,
    generation: context.input.generation,
    decorations_generation: context.input.decorations_generation,
    space_width: context.input.space_width,
    render_whitespace: context.input.render_whitespace,
    render_control_characters: context.input.render_control_characters,
    selection_view_range: context.input.selection_view_range,
  })
}

///|
impl ViewPart for @view_lines.ViewLines with fn render(self, context) {
  match self.prepared {
    Some(prepared) => {
      self.render_text(
        prepared.viewport,
        prepared.generation,
        prepared.decorations_generation,
        prepared.space_width,
        prepared.render_whitespace,
        prepared.render_control_characters,
        prepared.selection_view_range,
      )
      self.view_lines.set_attribute("style", context.content_transform)
    }
    None => ()
  }
}

///|
impl ViewPart for @view_lines.ViewLines with fn on_did_render(self) {
  self.should_render = false
  self.prepared = None
}

// `ViewPart` impl for `@margin.MarginViewOverlays` (`browser/view_parts/margin`).
// Kept here for the same reason as the impls above.

///|
impl ViewPart for @margin.MarginViewOverlays with fn should_render(self) {
  self.should_render
}

///|
impl ViewPart for @margin.MarginViewOverlays with fn on_view_event(_self, event) {
  match event {
    ViewFlushed => true
    ViewLinesChanged => true
    // The line-decorations lane renders margin decorations
    // (`LinesDecorationsOverlay.onDecorationsChanged` → true); the
    // glyph-margin view part stays deferred.
    ViewDecorationsChanged => true
    ViewScrollChanged(e) => e.window_changed || e.position_changed
    ViewConfigurationChanged(e) => e.gutter_width_changed
    ViewZonesChanged => true
    // The margin current-line highlight follows the cursor and the focus
    // state (`currentLineHighlight.ts:97-100,:116-123`).
    ViewCursorStateChanged => true
    ViewFocusChanged(_) => true
  }
}

///|
impl ViewPart for @margin.MarginViewOverlays with fn set_should_render(
  self,
  value,
) {
  self.should_render = value
}

///|
impl ViewPart for @margin.MarginViewOverlays with fn on_before_render(
  _self,
  _viewport,
) {
  ()
}

///|
impl ViewPart for @margin.MarginViewOverlays with fn prepare_render(
  self,
  context,
) {
  let cursor_view_line = match context.input.view_selection {
    Some(selection) => Some(selection.get_position().line_number)
    None => None
  }
  let selection_is_empty = match context.input.view_selection {
    Some(selection) => selection.is_empty()
    None => true
  }
  // `ctx.getDecorationsInViewport()` (`linesDecorations.ts:73`): the same
  // cached viewport decoration collection the content overlays read.
  let decorations = context.input.view_model
    .decorations()
    .get_decorations_viewport_data(context.viewport.visible_range).decorations
  self.prepared = Some({
    viewport: context.viewport,
    view_model: Some(context.input.view_model),
    generation: context.input.generation,
    decorations,
    line_decorations_width: context.input.line_decorations_width,
    cursor_view_line,
    selection_is_empty,
    editor_has_focus: context.input.editor_has_focus,
    word_wrap: context.input.word_wrap,
    render_line_highlight: context.input.render_line_highlight,
    render_line_highlight_only_when_focus: context.input.render_line_highlight_only_when_focus,
  })
}

///|
impl ViewPart for @margin.MarginViewOverlays with fn render(self, context) {
  match self.prepared {
    Some(prepared) => {
      self.render_current_line_margin(
        prepared.viewport,
        prepared.view_model,
        prepared.cursor_view_line,
        prepared.selection_is_empty,
        prepared.editor_has_focus,
        prepared.word_wrap,
        prepared.render_line_highlight,
        prepared.render_line_highlight_only_when_focus,
        // `_contentLeft`, the margin width (cLH:227).
        context.gutter_width,
      )
      self.render_line_numbers(prepared.viewport, prepared.generation)
      // `layoutInfo.decorationsLeft`: the lane sits between the line numbers
      // and the content. Deviation vs. Monaco: the viewer keeps line numbers
      // in the line-number band, so that layer is constrained to
      // `line_numbers_width` instead of the full margin.
      let line_numbers_width = context.gutter_width -
        prepared.line_decorations_width
      let to_render = @view_model.lines_decorations_to_render(
        prepared.decorations,
      )
      let class_names_per_line = @view_model.dedup_margin_decorations(
        prepared.viewport.start_line_number,
        prepared.viewport.start_line_number +
        prepared.viewport.lines.length() -
        1,
        to_render,
      )
      self.render_lines_decorations(
        prepared.viewport,
        class_names_per_line,
        decorations_left=line_numbers_width,
        decorations_width=prepared.line_decorations_width,
      )
      self.margin.set_attribute(
        "style",
        "width:" + context.gutter_width.to_string() + "px",
      )
      let band_constraint = ";width:" + line_numbers_width.to_string() + "px"
      self.current_line.set_attribute("style", context.margin_transform)
      self.line_numbers.set_attribute(
        "style",
        context.margin_transform + band_constraint,
      )
      self.lines_decorations.set_attribute("style", context.margin_transform)
    }
    None => ()
  }
}

///|
impl ViewPart for @margin.MarginViewOverlays with fn on_did_render(self) {
  self.should_render = false
  self.prepared = None
}

// `ViewPart` impl for `@overlay_widgets.OverlayWidgets`
// (`browser/view_parts/overlay_widgets`). Kept here for the same reason as
// the impls above.

///|
impl ViewPart for @overlay_widgets.OverlayWidgets with fn should_render(self) {
  self.should_render
}

///|
impl ViewPart for @overlay_widgets.OverlayWidgets with fn on_view_event(
  _self,
  event,
) {
  match event {
    ViewFlushed => true
    ViewScrollChanged(e) => e.dimensions_changed
    _ => false
  }
}

///|
impl ViewPart for @overlay_widgets.OverlayWidgets with fn set_should_render(
  self,
  value,
) {
  self.should_render = value
}

///|
impl ViewPart for @overlay_widgets.OverlayWidgets with fn on_before_render(
  _self,
  _viewport,
) {
  ()
}

///|
impl ViewPart for @overlay_widgets.OverlayWidgets with fn prepare_render(
  _self,
  _context,
) {
  ()
}

///|
impl ViewPart for @overlay_widgets.OverlayWidgets with fn render(
  _self,
  _context,
) {
  ()
}

///|
impl ViewPart for @overlay_widgets.OverlayWidgets with fn on_did_render(self) {
  self.should_render = false
}

// `ViewPart` impl for `@editor_scrollbar.EditorScrollbar`
// (`browser/view_parts/editor_scrollbar`). Kept here for the same reason as
// the impls above.

///|
impl ViewPart for @editor_scrollbar.EditorScrollbar with fn should_render(self) {
  self.should_render
}

///|
impl ViewPart for @editor_scrollbar.EditorScrollbar with fn on_view_event(
  _self,
  event,
) {
  match event {
    ViewFlushed => true
    ViewScrollChanged(e) => e.position_changed || e.dimensions_changed
    ViewConfigurationChanged(e) => e.gutter_width_changed
    _ => false
  }
}

///|
impl ViewPart for @editor_scrollbar.EditorScrollbar with fn set_should_render(
  self,
  value,
) {
  self.should_render = value
}

///|
impl ViewPart for @editor_scrollbar.EditorScrollbar with fn on_before_render(
  _self,
  _viewport,
) {
  ()
}

///|
impl ViewPart for @editor_scrollbar.EditorScrollbar with fn prepare_render(
  _self,
  _context,
) {
  ()
}

///|
impl ViewPart for @editor_scrollbar.EditorScrollbar with fn render(
  self,
  context,
) {
  self.editor_scrollable.content.set_attribute(
    "style",
    "left:" + context.gutter_width.to_string() + "px",
  )
  self.editor_scrollable.update_from_model(
    context.dimensions,
    context.position,
    horizontal_left=context.gutter_width,
  )
}

///|
impl ViewPart for @editor_scrollbar.EditorScrollbar with fn on_did_render(self) {
  self.should_render = false
}

// `ViewPart` impl for `@selections.ContentViewOverlays`
// (`browser/view_parts/selections`). Kept here for the same reason as the
// impls above.

///|
impl ViewPart for @selections.ContentViewOverlays with fn should_render(self) {
  self.should_render
}

///|
impl ViewPart for @selections.ContentViewOverlays with fn on_view_event(
  _self,
  event,
) {
  match event {
    ViewFlushed => true
    ViewLinesChanged => true
    // `DecorationsOverlay.onDecorationsChanged` (`decorations.ts:44-46`).
    ViewDecorationsChanged => true
    // `DecorationsOverlay.onConfigurationChanged` (`decorations.ts:39-43`):
    // re-reads typicalHalfwidthCharacterWidth.
    ViewConfigurationChanged(_) => true
    ViewScrollChanged(e) => e.window_changed || e.position_changed
    ViewCursorStateChanged => true
    ViewZonesChanged => true
    // `ViewOverlays.onFocusChanged` (`viewOverlays.ts:76-79`).
    ViewFocusChanged(_) => true
  }
}

///|
impl ViewPart for @selections.ContentViewOverlays with fn set_should_render(
  self,
  value,
) {
  self.should_render = value
}

///|
impl ViewPart for @selections.ContentViewOverlays with fn on_before_render(
  _self,
  _viewport,
) {
  ()
}

///|
impl ViewPart for @selections.ContentViewOverlays with fn prepare_render(
  self,
  context,
) {
  let cursor_view_line = match context.input.view_selection {
    Some(selection) => Some(selection.get_position().line_number)
    None => None
  }
  let selection_is_empty = match context.input.view_selection {
    Some(selection) => selection.is_empty()
    None => true
  }
  // `ctx.getDecorationsInViewport()` (`decorations.ts:68`): the viewport's
  // decoration collection (a cache hit — the viewport data resolved the same
  // range).
  let decorations = context.input.view_model
    .decorations()
    .get_decorations_viewport_data(context.viewport.visible_range).decorations
  self.prepared = Some({
    viewport: context.viewport,
    selection_view_range: context.input.selection_view_range,
    view_model: Some(context.input.view_model),
    decorations,
    space_width: context.input.space_width,
    editor_has_focus: context.input.editor_has_focus,
    cursor_view_line,
    selection_is_empty,
    word_wrap: context.input.word_wrap,
    render_line_highlight: context.input.render_line_highlight,
    render_line_highlight_only_when_focus: context.input.render_line_highlight_only_when_focus,
  })
}

///|
impl ViewPart for @selections.ContentViewOverlays with fn render(self, context) {
  match self.prepared {
    Some(prepared) => {
      // One clear per part render; the current-line highlight then paints
      // before the selection pieces, preserving Monaco's dynamic-overlay
      // registration order (`view.ts:218-219`). The overlay renderers live
      // in their Monaco-mirroring packages
      // (`view_parts/{current_line_highlight,decorations,selections}`) as
      // free functions over the shared container.
      self.view_overlays.set_inner_html("")
      @current_line_highlight.render_current_line(
        self.view_overlays,
        prepared.viewport,
        prepared.view_model,
        prepared.cursor_view_line,
        prepared.selection_is_empty,
        prepared.editor_has_focus,
        prepared.word_wrap,
        prepared.render_line_highlight,
        prepared.render_line_highlight_only_when_focus,
        // `max(ctx.scrollWidth, this._contentWidth)` (cLH:211).
        if context.dimensions.scroll_width > context.dimensions.width {
          context.dimensions.scroll_width
        } else {
          context.dimensions.width
        },
      )
      self.render_selection_overlays(
        prepared.viewport,
        prepared.selection_view_range,
        prepared.view_model,
        prepared.space_width,
        context.view_context.measure_line_selection,
      )
      // Decorations render after current-line and selections — Monaco's
      // dynamic-overlay registration order (`view.ts:218-221`).
      @decorations.render_decorations_overlay(
        self.view_overlays,
        prepared.decorations,
        prepared.viewport,
        line_number => {
          match prepared.view_model {
            Some(view_model) =>
              view_model.lines().get_view_line_max_column(line_number)
            None => 1
          }
        },
        context.view_context.measure_line_decorations,
        prepared.space_width,
      )
      self.set_focused(prepared.editor_has_focus)
      self.view_overlays.set_attribute("style", context.content_transform)
    }
    None => ()
  }
}

///|
impl ViewPart for @selections.ContentViewOverlays with fn on_did_render(self) {
  self.should_render = false
  self.prepared = None
}

// `ViewPart` impl for `@content_widgets.ContentWidgets`
// (`browser/view_parts/content_widgets`). Kept here for the same reason as
// the impls above — plus it is the one impl that also builds the
// `HoverWidgetHost` capability struct (unpacking `context.view_context`'s
// fields) and resolves `HoverController::widget_view` before handing the
// content-widgets package only its already-derived `HoverWidgetView`, since
// that package cannot import `ViewContext` (owned by `browser/view/`, which
// needs `ContentWidgets` back) or the full `HoverController` (which stays
// with `Viewer`) — see `content_widgets`'s README.

///|
impl ViewPart for @content_widgets.ContentWidgets with fn should_render(self) {
  self.should_render
}

///|
// Hover content changes invalidate this part directly (see `View::render`),
// mirroring Monaco's contrib hover widget rather than a view event.
impl ViewPart for @content_widgets.ContentWidgets with fn on_view_event(
  _self,
  event,
) {
  match event {
    ViewFlushed => true
    ViewLinesChanged => true
    ViewScrollChanged(e) =>
      e.window_changed || e.position_changed || e.dimensions_changed
    ViewZonesChanged => true
    _ => false
  }
}

///|
impl ViewPart for @content_widgets.ContentWidgets with fn set_should_render(
  self,
  value,
) {
  self.should_render = value
}

///|
impl ViewPart for @content_widgets.ContentWidgets with fn on_before_render(
  _self,
  _viewport,
) {
  ()
}

///|
impl ViewPart for @content_widgets.ContentWidgets with fn prepare_render(
  self,
  context,
) {
  self.prepared = Some({
    window: context.input.window,
    language_id: context.input.view_model.language_id(),
    layout: context.input.layout,
    hover_view: context.input.hover_state.widget_view(),
    on_hover_measured: context.input.on_hover_measured,
    space_width: context.input.space_width,
  })
}

///|
impl ViewPart for @content_widgets.ContentWidgets with fn render(self, context) {
  self.content_widgets.set_attribute("style", context.content_transform)
  match self.prepared {
    Some(prepared) => {
      let host : @content_widgets.HoverWidgetHost = {
        root: context.view_context.root,
        languages: context.view_context.languages,
        keep_hover_open: context.view_context.keep_hover_open,
        handle_hover_mousedown: context.view_context.handle_hover_mousedown,
        hook_scrollable_scrollbar_input: context.view_context.hook_scrollable_scrollbar_input,
        handle_hover_keydown: context.view_context.handle_hover_keydown,
        model_position_to_view_position: context.view_context.model_position_to_view_position,
      }
      self.render_hover_widget(
        host,
        prepared.window,
        prepared.language_id,
        prepared.layout,
        prepared.hover_view,
        prepared.on_hover_measured,
        prepared.space_width,
        context.gutter_width,
      )
    }
    None => ()
  }
}

///|
impl ViewPart for @content_widgets.ContentWidgets with fn on_did_render(self) {
  self.should_render = false
  self.prepared = None
}

// `ViewPart` impl for `@view_cursors.ViewCursors`
// (`browser/view_parts/view_cursors`). Kept here for the same reason as the
// impls above. The viewport math and DOM measurement live here (not in the
// part package) because they need `RenderingContext` / `ViewContext`.

///|
impl ViewPart for @view_cursors.ViewCursors with fn should_render(self) {
  self.should_render
}

///|
// Event map from `viewCursors.ts`: `onFlushed` (:180), `onLinesChanged`
// (:188; the port's merged lines/tokens/decorations event also covers
// `onTokensChanged`/`onDecorationsChanged`, :176,:200), `onScrollChanged`
// (:197, unconditionally true), `onCursorStateChanged` (:161),
// `onConfigurationChanged` (:112), `onZonesChanged` (:219), `onFocusChanged`
// (:183 — Monaco flips visibility inline and returns false; the readonly port
// has no blink timers, so the flip happens in `render_cursor` instead and the
// event marks the part dirty). No `onLineMappingChanged` handler in Monaco —
// a remap that moves the cursor arrives as `ViewCursorStateChanged` via the
// reprojected view selection.
impl ViewPart for @view_cursors.ViewCursors with fn on_view_event(_self, event) {
  match event {
    ViewFlushed => true
    ViewLinesChanged => true
    ViewScrollChanged(_) => true
    ViewCursorStateChanged => true
    ViewConfigurationChanged(_) => true
    ViewZonesChanged => true
    ViewFocusChanged(_) => true
    _ => false
  }
}

///|
impl ViewPart for @view_cursors.ViewCursors with fn set_should_render(
  self,
  value,
) {
  self.should_render = value
}

///|
impl ViewPart for @view_cursors.ViewCursors with fn on_before_render(
  _self,
  _viewport,
) {
  ()
}

///|
// `ViewCursor._prepareRender` (`viewCursor.ts:163-203`), Line-style arm: the
// caret x is `ctx.visibleRangeForPosition(position)` — the port measures it
// off the rendered line DOM (`View::offset_for_column` via the
// `ViewContext.offset_for_column` seam; `-1` = line not rendered → Monaco's
// "Outside viewport → null"). The caret top is the line's viewport-relative
// vertical offset, like every flat overlay piece.
impl ViewPart for @view_cursors.ViewCursors with fn prepare_render(
  self,
  context,
) {
  let input = context.input
  let render_data : @view_cursors.CursorRenderData? = match
    input.view_selection {
    None => None
    Some(selection) => {
      let position = selection.get_position()
      let index = position.line_number - context.viewport.start_line_number
      if index < 0 || index >= context.viewport.lines.length() {
        None
      } else {
        let left = (context.view_context.offset_for_column)(
          position.line_number,
          position.column,
        )
        if left < 0.0 {
          None
        } else {
          Some(
            @view_cursors.prepare_cursor_render_data(
              left,
              context.viewport.relative_vertical_offset[index],
              @core.editor_line_height,
              @view_cursors.device_pixel_ratio(),
            ),
          )
        }
      }
    }
  }
  let has_selection = match input.view_selection {
    Some(selection) => !selection.is_empty()
    None => false
  }
  self.prepared = Some({
    render_data,
    has_selection,
    editor_has_focus: input.editor_has_focus,
  })
}

///|
impl ViewPart for @view_cursors.ViewCursors with fn render(self, context) {
  match self.prepared {
    Some(prepared) => self.render_cursor(prepared, context.content_transform)
    None => ()
  }
}

///|
impl ViewPart for @view_cursors.ViewCursors with fn on_did_render(self) {
  self.should_render = false
  self.prepared = None
}
