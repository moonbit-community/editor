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
  overlay_widgets : @overlay_widgets.OverlayWidgets,
  editor_scrollbar : @editor_scrollbar.EditorScrollbar,
) -> Array[ViewPartHandle] {
  [
    ViewLinesPart(view_lines),
    ViewZonesPart(view_zones),
    ContentViewOverlaysPart(content_view_overlays),
    MarginViewOverlaysPart(margin_view_overlays),
    ContentWidgetsPart(content_widgets),
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
      self.render_view_zones(prepared.zones, prepared.viewport)
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
    // Line content, tokens, and decorations are regenerated together.
    ViewLinesChanged => true
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
  // The line node's own class carries current-line decorations; convert the
  // controller decorations to view coordinates so the class test stays in
  // view `Position`s like the inline path.
  let view_decorations = match context.input.view_model {
    Some(view_model) =>
      view_model.decorations().to_view_decorations(context.input.decorations)
    None => []
  }
  self.prepared = Some({
    frame: context.input.frame,
    viewport: context.viewport,
    view_decorations,
    generation: context.input.generation,
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
        prepared.frame,
        prepared.viewport,
        prepared.view_decorations,
        prepared.generation,
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
    ViewScrollChanged(e) => e.window_changed || e.position_changed
    ViewConfigurationChanged(e) => e.gutter_width_changed
    ViewLineMappingChanged => true
    ViewZonesChanged => true
    _ => false
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
  self.prepared = Some({
    frame: context.input.frame,
    viewport: context.viewport,
    view_model: context.input.view_model,
    folding_ranges: context.input.folding_ranges,
    folded_ranges: context.input.folded_ranges,
    on_toggle_fold: context.input.on_toggle_fold,
    generation: context.input.generation,
  })
}

///|
impl ViewPart for @margin.MarginViewOverlays with fn render(self, context) {
  match self.prepared {
    Some(prepared) => {
      self.render_line_numbers(
        prepared.frame,
        prepared.viewport,
        prepared.generation,
      )
      self.render_folding_markers(
        prepared.viewport,
        prepared.view_model,
        prepared.folding_ranges,
        prepared.folded_ranges,
        on_toggle_fold=prepared.on_toggle_fold,
      )
      self.margin.set_attribute(
        "style",
        "width:" + context.gutter_width.to_string() + "px",
      )
      self.line_numbers.set_attribute("style", context.margin_transform)
      self.folding.set_attribute("style", context.margin_transform)
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
    ViewScrollChanged(e) => e.window_changed || e.position_changed
    ViewCursorStateChanged => true
    ViewZonesChanged => true
    // `ViewOverlays.onFocusChanged` (`viewOverlays.ts:76-79`).
    ViewFocusChanged(_) => true
    _ => false
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
  self.prepared = Some({
    frame: context.input.frame,
    viewport: context.viewport,
    selection_view_range: context.input.selection_view_range,
    view_model: context.input.view_model,
    space_width: context.input.space_width,
    editor_has_focus: context.input.editor_has_focus,
  })
}

///|
impl ViewPart for @selections.ContentViewOverlays with fn render(self, context) {
  match self.prepared {
    Some(prepared) => {
      self.render_selection_overlays(
        prepared.frame,
        prepared.viewport,
        prepared.selection_view_range,
        prepared.view_model,
        prepared.space_width,
        context.view_context.measure_line_selection,
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
    frame: context.input.frame,
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
      }
      self.render_hover_widget(
        host,
        prepared.frame,
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
