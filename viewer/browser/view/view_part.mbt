///|
/// Private Monaco-shaped render lifecycle for browser view concerns. The
/// event-handling half (`on_view_event` / `should_render` / `force_should_render`
/// / `on_did_render`) mirrors Monaco's `ViewEventHandler`: a typed view event is
/// offered to every part, and a part that returns `true` is marked dirty for the
/// next render. `should_render` returns that accumulated flag (no longer a
/// snapshot diff). The render half (`prepare_render` / `render`) mirrors
/// Monaco's `ViewPart`/`DynamicViewOverlay`: `prepare_render` computes and
/// stores any state that needs the read phase, `render` writes the DOM.
priv trait ViewPart {
  fn on_view_event(Self, ViewEvent) -> Bool
  fn should_render(Self) -> Bool
  fn force_should_render(Self) -> Unit
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
  handle_view_part_events(self, events)
}

///|
/// Generic form kept separate so whitebox parity tests can prove the exact
/// accumulate-once contract without adding test-only members to the fixed
/// production `ViewPartHandle` union.
fn[T : ViewPart] handle_view_part_events(
  part : T,
  events : Array[ViewEvent],
) -> Unit {
  let mut should_render = false
  for event in events {
    if ViewPart::on_view_event(part, event) {
      should_render = true
    }
  }
  if should_render {
    ViewPart::force_should_render(part)
  }
}

///|
priv enum ViewPartHandle {
  ViewLinesPart(@view_lines.ViewLines)
  ViewZonesPart(@view_zones.ViewZones)
  ContentViewOverlaysPart(ContentViewOverlays)
  MarginViewOverlaysPart(MarginViewOverlays)
  ContentWidgetsPart(@content_widgets.ContentWidgets)
  ViewCursorsPart(@view_cursors.ViewCursors)
  OverlayWidgetsPart(@overlay_widgets.OverlayWidgets)
  EditorScrollbarPart(@editor_scrollbar.EditorScrollbar)
}

///|
/// View-owned teardown (`view.ts:503-519`). The seven DOM-only local parts
/// retain no listeners, timers, animation frames, emitters, or external
/// nodes; removing the View root releases their complete DOM state. The
/// scrollbar is the sole active owner and cancels its hide timer here.
fn ViewPartHandle::dispose(self : ViewPartHandle) -> Unit {
  match self {
    ViewLinesPart(_) => ()
    ViewZonesPart(_) => ()
    ContentViewOverlaysPart(_) => ()
    MarginViewOverlaysPart(_) => ()
    ContentWidgetsPart(_) => ()
    ViewCursorsPart(_) => ()
    OverlayWidgetsPart(_) => ()
    EditorScrollbarPart(part) => part.scrollable().dispose()
  }
}

///|
fn default_view_parts(
  view_lines : @view_lines.ViewLines,
  view_zones : @view_zones.ViewZones,
  content_view_overlays : ContentViewOverlays,
  margin_view_overlays : MarginViewOverlays,
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
impl ViewPart for ViewPartHandle with fn force_should_render(self) {
  match self {
    ViewLinesPart(part) => ViewPart::force_should_render(part)
    ViewZonesPart(part) => ViewPart::force_should_render(part)
    ContentViewOverlaysPart(part) => ViewPart::force_should_render(part)
    MarginViewOverlaysPart(part) => ViewPart::force_should_render(part)
    ContentWidgetsPart(part) => ViewPart::force_should_render(part)
    ViewCursorsPart(part) => ViewPart::force_should_render(part)
    OverlayWidgetsPart(part) => ViewPart::force_should_render(part)
    EditorScrollbarPart(part) => ViewPart::force_should_render(part)
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
    ViewConfigurationChanged(_) => true
    ViewLineMappingChanged => true
    ViewLinesDeleted(_) | ViewLinesInserted(_) => true
    ViewScrollChanged(e) => e.scroll_top_changed || e.scroll_width_changed
    ViewZonesChanged => true
    _ => false
  }
}

///|
impl ViewPart for @view_zones.ViewZones with fn force_should_render(self) {
  self.should_render = true
}

///|
impl ViewPart for @view_zones.ViewZones with fn prepare_render(_self, _context) {
  // Monaco `ViewZones.prepareRender`: nothing to read.
}

///|
impl ViewPart for @view_zones.ViewZones with fn render(self, context) {
  self.render_view_zones(
    context.input.browser_view_zones,
    context.viewport,
    context.translate_y,
  )
}

///|
impl ViewPart for @view_zones.ViewZones with fn on_did_render(self) {
  self.should_render = false
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
    ViewFlushed => {
      self.flush_retained_lines()
      true
    }
    ViewLinesChanged(e) => self.on_lines_changed(e.from_line_number, e.count)
    ViewLinesDeleted(e) => {
      self.on_lines_deleted(e.from_line_number, e.to_line_number)
      true
    }
    ViewLinesInserted(e) => {
      self.on_lines_inserted(e.from_line_number, e.to_line_number)
      true
    }
    ViewDecorationsChanged(_) => {
      self.on_decorations_changed()
      true
    }
    ViewScrollChanged(e) => {
      // `ViewLines.onScrollChanged` writes the new scroll width even when it
      // does not invalidate text rows; only top/left require a render pass.
      self.dom_node.set_width(Pixels(e.scroll_width))
      self.on_visible_scroll_changed(e.scroll_top_changed) ||
      e.scroll_top_changed ||
      e.scroll_left_changed
    }
    ViewConfigurationChanged(e) => {
      self.on_visible_configuration_changed(e.has_changed(LayoutInfo)) |> ignore
      self.on_configuration_changed() |> ignore
      // Source `ViewLines.onConfigurationChanged` always returns true after
      // the nested layout-info and option-equality checks.
      true
    }
    ViewCursorStateChanged(_) => self.on_selection_changed()
    ViewTokensChanged(e) => {
      let ranges : Array[@base_common.LineRange] = []
      for range in e.ranges {
        ranges.push(LineRange(range.from_line_number, range.to_line_number + 1))
      }
      self.on_token_ranges_changed(ranges)
    }
    ViewZonesChanged => self.on_visible_zones_changed()
    _ => false
  }
}

///|
fn current_line_scroll_changed(event : ViewScrollChangedEvent) -> Bool {
  event.scroll_width_changed || event.scroll_top_changed
}

///|
impl ViewPart for @view_lines.ViewLines with fn force_should_render(self) {
  self.should_render = true
}

///|
impl ViewPart for @view_lines.ViewLines with fn prepare_render(_self, _context) {
  // Monaco `ViewLines.prepareRender` throws "Not supported": the lines
  // render through `renderText`, which `View::render` drives directly ahead
  // of the part loops (like `View._actualRender`).
  abort("Not supported")
}

///|
impl ViewPart for @view_lines.ViewLines with fn render(_self, _context) {
  // Monaco `ViewLines.render` throws "Not supported" — see `prepare_render`.
  abort("Not supported")
}

///|
impl ViewPart for @view_lines.ViewLines with fn on_did_render(self) {
  self.should_render = false
}

// `ViewPart` impl for `MarginViewOverlays` (`view_overlays.mbt`, this
// package — Monaco's `viewOverlays.ts`), plus the `DynamicViewOverlay`
// impls for the margin overlays (`view_parts/margin`).

///|
impl ViewPart for MarginViewOverlays with fn should_render(self) {
  self.should_render
}

///|
impl ViewPart for MarginViewOverlays with fn on_view_event(_self, event) {
  match event {
    ViewFlushed => true
    ViewLinesChanged(_)
    | ViewLinesDeleted(_)
    | ViewLinesInserted(_)
    | ViewTokensChanged(_) => {
      _self.overlays.on_content_or_tokens_changed()
      true
    }
    // The line-decorations lane renders margin decorations
    // (`LinesDecorationsOverlay.onDecorationsChanged` → true); the
    // glyph-margin view part stays deferred.
    ViewDecorationsChanged(_) => true
    ViewScrollChanged(e) => {
      let nested_current_line_dirty = current_line_scroll_changed(e)
      // The retained ViewOverlays collection itself always invalidates on a
      // scroll event; keep the nested predicate evaluated and explicit.
      nested_current_line_dirty || true
    }
    ViewConfigurationChanged(_) => {
      _self.on_configuration_changed()
      _self.current_line_margin.state.on_configuration_changed()
      true
    }
    ViewLineMappingChanged => true
    ViewZonesChanged => true
    // The margin current-line highlight follows the cursor and the focus
    // state (`currentLineHighlight.ts:97-100,:116-123`).
    ViewCursorStateChanged(e) => {
      let nested_current_line_dirty = _self.current_line_margin.state.on_cursor_state_changed(
        e.selections,
      )
      // Pinned `LineNumbersOverlay.onCursorStateChanged` is also false for an
      // absolute-line-number, same-model-line column move. The fixed grouped
      // local handle deliberately over-renders that branch; the focused
      // white-box test proves retained rows/classes/styles perform zero DOM
      // writes when every nested result is unchanged.
      nested_current_line_dirty || true
    }
    ViewFocusChanged(e) => {
      _self.overlays.on_focus_changed(e.is_focused)
      _self.current_line_margin.state.on_focus_changed(e.is_focused) |> ignore
      true
    }
    _ => false
  }
}

///|
impl ViewPart for MarginViewOverlays with fn force_should_render(self) {
  self.should_render = true
}

///|
impl ViewPart for MarginViewOverlays with fn prepare_render(self, context) {
  // `ViewOverlays.prepareRender` (`viewOverlays.ts:113-121`).
  self.overlays.prepare_overlays(context)
}

///|
impl ViewPart for MarginViewOverlays with fn render(self, context) {
  // `MarginViewOverlays._viewOverlaysRender` (`viewOverlays.ts:262-266`):
  // render the rows, size the container to `_contentLeft`. The `.margin`
  // clip is viewport-fixed; the rows container carries the vertical rail
  // translation (the viewer's `margin_transform`).
  self.overlays.render_lines(context.viewport)
  let margin_style = "width:" + self.content_left.to_string() + "px"
  if self.dom_node.get_attribute("style") != margin_style {
    self.dom_node.set_attribute("style", margin_style)
  }
  self.render_focused()
  let overlays = self.overlays.dom_node.element()
  let height = if context.dimensions.scroll_height < 1000000.0 {
    context.dimensions.scroll_height
  } else {
    1000000.0
  }
  let overlays_style = context.margin_transform +
    ";width:" +
    self.content_left.to_string() +
    "px;height:" +
    height.to_string() +
    "px"
  if overlays.get_attribute("style") != overlays_style {
    overlays.set_attribute("style", overlays_style)
  }
}

///|
impl ViewPart for MarginViewOverlays with fn on_did_render(self) {
  self.should_render = false
}

///|
impl DynamicViewOverlay for @margin.CurrentLineMarginHighlightOverlay with fn prepare_render(
  self,
  context,
) {
  let state = self.state
  let cursor_view_line = state.cursor_line_numbers.get(0)
  self.render_result = @margin.prepare_current_line_margin_render(
    context.viewport,
    Some(context.input.view_model),
    cursor_view_line,
    state.selection_is_empty,
    state.focused,
    state.word_wrap,
    state.render_line_highlight,
    state.render_line_highlight_only_when_focus,
    // `_contentLeft`, the margin width (cLH:227).
    state.content_left,
  )
}

///|
impl DynamicViewOverlay for @margin.CurrentLineMarginHighlightOverlay with fn render(
  self,
  start_line_number,
  line_number,
) {
  render_result_slice(self.render_result, start_line_number, line_number)
}

///|
impl DynamicViewOverlay for @margin.LinesDecorationsOverlay with fn prepare_render(
  self,
  context,
) {
  // `ctx.getDecorationsInViewport()` (`linesDecorations.ts:73`): the same
  // cached viewport decoration collection the content overlays read.
  let decorations = context.input.view_model
    .decorations()
    .get_decorations_viewport_data(context.viewport.visible_range).decorations
  let to_render = @view_model.lines_decorations_to_render(decorations)
  let class_names_per_line = @view_model.dedup_margin_decorations(
    context.viewport.start_line_number,
    context.viewport.start_line_number + context.viewport.lines.length() - 1,
    to_render,
  )
  // `layoutInfo.decorationsLeft`: the lane sits between the line numbers
  // and the content.
  let line_numbers_width = context.gutter_width -
    context.input.line_decorations_width
  self.render_result = @margin.prepare_lines_decorations_render(
    class_names_per_line,
    decorations_left=line_numbers_width,
    decorations_width=context.input.line_decorations_width,
  )
}

///|
impl DynamicViewOverlay for @margin.LinesDecorationsOverlay with fn render(
  self,
  start_line_number,
  line_number,
) {
  render_result_slice(self.render_result, start_line_number, line_number)
}

///|
impl DynamicViewOverlay for @margin.LineNumbersOverlay with fn prepare_render(
  self,
  context,
) {
  // `layoutInfo.lineNumbersLeft`/`lineNumbersWidth`: the band left of the
  // line-decorations lane.
  let line_numbers_width = context.gutter_width -
    context.input.line_decorations_width
  self.render_result = @margin.prepare_line_numbers_render(
    context.viewport,
    Some(context.input.view_model),
    left=0.0,
    width=line_numbers_width,
  )
}

///|
impl DynamicViewOverlay for @margin.LineNumbersOverlay with fn render(
  self,
  start_line_number,
  line_number,
) {
  render_result_slice(self.render_result, start_line_number, line_number)
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
    ViewScrollChanged(e) => e.scroll_width_changed || e.scroll_height_changed
    ViewConfigurationChanged(_) => true
    _ => false
  }
}

///|
impl ViewPart for @overlay_widgets.OverlayWidgets with fn force_should_render(
  self,
) {
  self.should_render = true
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
    ViewScrollChanged(_) => true
    ViewConfigurationChanged(_) => true
    _ => false
  }
}

///|
impl ViewPart for @editor_scrollbar.EditorScrollbar with fn force_should_render(
  self,
) {
  self.should_render = true
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
  // `EditorScrollbar._setLayout` (`editorScrollbar.ts:109-123`): the scrollable
  // shell starts at contentLeft; the shared lines-content rail itself is free
  // to move left by the current synthetic scroll position.
  self.scrollbar_dom_node.set_left(Pixels(context.gutter_width))
  self.scrollbar_dom_node.set_width(Pixels(context.dimensions.width))
  self.scrollbar_dom_node.set_height(Pixels(context.dimensions.height))
  self.editor_scrollable.update_from_model(context.dimensions, context.position)
}

///|
impl ViewPart for @editor_scrollbar.EditorScrollbar with fn on_did_render(self) {
  self.should_render = false
}

// `ViewPart` impl for `ContentViewOverlays` (`view_overlays.mbt`, this
// package — Monaco's `viewOverlays.ts`). The dynamic overlays prepare in the
// read phase (measuring off the freshly written line DOM) and the rows write
// in `render`, Monaco's split.

///|
impl ViewPart for ContentViewOverlays with fn should_render(self) {
  self.should_render
}

///|
impl ViewPart for ContentViewOverlays with fn on_view_event(_self, event) {
  match event {
    ViewFlushed => true
    ViewLinesChanged(_)
    | ViewLinesDeleted(_)
    | ViewLinesInserted(_)
    | ViewTokensChanged(_) => {
      _self.overlays.on_content_or_tokens_changed()
      true
    }
    // `DecorationsOverlay.onDecorationsChanged` (`decorations.ts:44-46`).
    ViewDecorationsChanged(_) => true
    // `DecorationsOverlay.onConfigurationChanged` (`decorations.ts:39-43`)
    // and `AbstractLineHighlightOverlay.onConfigurationChanged` (`:87-96`)
    // both re-read their live configuration before returning true.
    ViewConfigurationChanged(_) => {
      _self.on_configuration_changed()
      _self.current_line.state.on_configuration_changed()
      true
    }
    ViewScrollChanged(e) => {
      let nested_current_line_dirty = current_line_scroll_changed(e)
      nested_current_line_dirty || true
    }
    ViewCursorStateChanged(e) => {
      let nested_current_line_dirty = _self.current_line.state.on_cursor_state_changed(
        e.selections,
      )
      // The selections overlay consumes every cursor event.
      nested_current_line_dirty || true
    }
    ViewLineMappingChanged => true
    ViewZonesChanged => true
    // `ViewOverlays.onFocusChanged` (`viewOverlays.ts:76-79`).
    ViewFocusChanged(e) => {
      _self.overlays.on_focus_changed(e.is_focused)
      _self.current_line.state.on_focus_changed(e.is_focused) |> ignore
      true
    }
    _ => false
  }
}

///|
impl ViewPart for ContentViewOverlays with fn force_should_render(self) {
  self.should_render = true
}

///|
impl ViewPart for ContentViewOverlays with fn prepare_render(self, context) {
  // `ViewOverlays.prepareRender` (`viewOverlays.ts:113-121`): each dynamic
  // overlay builds its per-line `_renderResult` off the read context.
  self.overlays.prepare_overlays(context)
}

///|
impl ViewPart for ContentViewOverlays with fn render(self, context) {
  // `ContentViewOverlays._viewOverlaysRender` (`viewOverlays.ts:225-229`):
  // render the rows, then size the container to
  // `max(ctx.scrollWidth, contentWidth)`.
  self.overlays.render_lines(context.viewport)
  let width = if context.dimensions.scroll_width > self.content_width {
    context.dimensions.scroll_width
  } else {
    self.content_width
  }
  self.set_focused(self.overlays.is_focused)
  self.overlays.dom_node.set_width(Pixels(width))
}

///|
impl ViewPart for ContentViewOverlays with fn on_did_render(self) {
  self.should_render = false
}

// `DynamicViewOverlay` impls for the content overlays
// (`view_parts/{current_line_highlight,selections,decorations}`), kept in the
// trait-owning package like the `ViewPart` impls above: `RenderingContext`
// is package-private, so the part packages export pure per-line HTML
// builders and these impls feed them the context.

///|
impl DynamicViewOverlay for @current_line_highlight.CurrentLineHighlightOverlay with fn prepare_render(
  self,
  context,
) {
  let state = self.state
  let cursor_view_line = state.cursor_line_numbers.get(0)
  self.render_result = @current_line_highlight.prepare_current_line_render(
    context.viewport,
    Some(context.input.view_model),
    cursor_view_line,
    state.selection_is_empty,
    state.focused,
    state.word_wrap,
    state.render_line_highlight,
    state.render_line_highlight_only_when_focus,
    // `max(ctx.scrollWidth, this._contentWidth)` (cLH:211).
    if context.dimensions.scroll_width > state.content_width {
      context.dimensions.scroll_width
    } else {
      state.content_width
    },
  )
}

///|
impl DynamicViewOverlay for @current_line_highlight.CurrentLineHighlightOverlay with fn render(
  self,
  start_line_number,
  line_number,
) {
  render_result_slice(self.render_result, start_line_number, line_number)
}

///|
impl DynamicViewOverlay for @selections.SelectionsOverlay with fn prepare_render(
  self,
  context,
) {
  self.render_result = @selections.prepare_selections_render(
    context.viewport,
    context.input.selection_view_range,
    Some(context.input.view_model),
    context.input.space_width,
    context.view_context.measure_line_selection,
  )
}

///|
impl DynamicViewOverlay for @selections.SelectionsOverlay with fn render(
  self,
  start_line_number,
  line_number,
) {
  render_result_slice(self.render_result, start_line_number, line_number)
}

///|
impl DynamicViewOverlay for @decorations.DecorationsOverlay with fn prepare_render(
  self,
  context,
) {
  // `ctx.getDecorationsInViewport()` (`decorations.ts:68`): the viewport's
  // decoration collection (a cache hit — the viewport data resolved the same
  // range).
  let decorations = context.input.view_model
    .decorations()
    .get_decorations_viewport_data(context.viewport.visible_range).decorations
  self.render_result = @decorations.prepare_decorations_render(
    decorations,
    context.viewport.start_line_number,
    context.viewport.end_line_number,
    line_number => {
      context.input.view_model.lines().get_view_line_max_column(line_number)
    },
    context.view_context.measure_line_decorations,
    context.input.space_width,
  )
}

///|
impl DynamicViewOverlay for @decorations.DecorationsOverlay with fn render(
  self,
  start_line_number,
  line_number,
) {
  render_result_slice(self.render_result, start_line_number, line_number)
}

// `ViewPart` impl for `@content_widgets.ContentWidgets`
// (`browser/view_parts/content_widgets`). Kept here for the same reason as
// the impls above. It unpacks the render context into the package's
// `ContentWidgetsRenderContext` capability struct, since that package cannot
// import `ViewContext`/`RenderingContext` (owned by `browser/view/`, which
// needs `ContentWidgets` back for `View`'s fields).

///|
impl ViewPart for @content_widgets.ContentWidgets with fn should_render(self) {
  self.should_render
}

///|
// Widget position changes invalidate this part directly through
// `set_widget_position` (Monaco `setWidgetPosition`'s `setShouldRender`). The
// mapping family also reprojects retained model anchors synchronously before
// returning `true`; configuration delegates its exact `layoutInfo` bit to all
// retained widgets before dirtying.
impl ViewPart for @content_widgets.ContentWidgets with fn on_view_event(
  self,
  event,
) {
  match event {
    ViewFlushed => true
    ViewConfigurationChanged(e) => {
      self.on_configuration_changed(e.has_changed(LayoutInfo))
      true
    }
    ViewDecorationsChanged(_) => true
    ViewLineMappingChanged
    | ViewLinesChanged(_)
    | ViewLinesDeleted(_)
    | ViewLinesInserted(_) => {
      self.update_anchors_view_positions()
      true
    }
    ViewScrollChanged(_) => true
    ViewZonesChanged => true
    _ => false
  }
}

///|
impl ViewPart for @content_widgets.ContentWidgets with fn force_should_render(
  self,
) {
  self.should_render = true
}

///|
/// Monaco `ViewContentWidgets.prepareRender`: compute each widget's box
/// layout for this frame from its recorded anchors.
impl ViewPart for @content_widgets.ContentWidgets with fn prepare_render(
  self,
  context,
) {
  self.prepare_render_widgets({
    vertical_offset_for_line: line => {
      context.input.layout.vertical_offset_for_line(line)
    },
    window_start: context.input.window.start,
    window_end: context.input.window.end,
    line_height: context.input.layout.line_height().to_double(),
    char_width: context.input.space_width,
    typical_fullwidth_character_width: context.input.typical_fullwidth_character_width,
    scroll_top: context.position.scroll_top,
    scroll_left: context.position.scroll_left,
    viewport_width: context.dimensions.width,
    viewport_height: context.dimensions.height,
  })
}

///|
/// Monaco `ViewContentWidgets.render`: write each widget's `top`/`left`/
/// `visibility` onto its mounted DOM — never content, never a re-mount.
impl ViewPart for @content_widgets.ContentWidgets with fn render(self, context) {
  self.render_widgets(context.translate_y)
}

///|
impl ViewPart for @content_widgets.ContentWidgets with fn on_did_render(self) {
  self.should_render = false
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
// performs the same immediate `on_focus_changed` side effect without dirtying
// the part). No `onLineMappingChanged` handler in Monaco —
// a remap that moves the cursor arrives as `ViewCursorStateChanged` via the
// reprojected view selection.
impl ViewPart for @view_cursors.ViewCursors with fn on_view_event(self, event) {
  match event {
    ViewFlushed => true
    ViewLinesChanged(_) | ViewLinesDeleted(_) | ViewLinesInserted(_) => true
    ViewScrollChanged(_) => true
    ViewCursorStateChanged(e) => {
      self.last_position = if e.selections.length() == 0 {
        None
      } else {
        Some(e.selections[0].get_position())
      }
      let selection_is_empty = e.selections.length() == 0 ||
        e.selections[0].is_empty()
      // `ViewCursors.onCursorStateChanged` updates the layer class
      // synchronously, but only when the selection shape crosses the
      // empty/nonempty boundary. Keep the last rendered cursor rectangle
      // paired with its old position until the next render completes.
      if self.selection_is_empty != selection_is_empty {
        self.selection_is_empty = selection_is_empty
        self.dom_node.set_attribute(
          "class",
          @view_cursors.cursors_layer_class(!self.selection_is_empty),
        )
      }
      true
    }
    ViewDecorationsChanged(_) => true
    ViewConfigurationChanged(_) => true
    ViewTokensChanged(e) =>
      match self.last_position {
        None => false
        Some(position) => {
          for range in e.ranges {
            if position.line_number >= range.from_line_number &&
              position.line_number <= range.to_line_number {
              return true
            }
          }
          false
        }
      }
    ViewZonesChanged => true
    ViewFocusChanged(e) => {
      // Source `onFocusChanged`: update cursor visibility immediately, but do
      // not dirty the part.
      self.on_focus_changed(e.is_focused)
      false
    }
    _ => false
  }
}

///|
impl ViewPart for @view_cursors.ViewCursors with fn force_should_render(self) {
  self.should_render = true
}

///|
// `ViewCursor._prepareRender` (`viewCursor.ts:163-203`), Line-style arm: the
// caret x is `ctx.visibleRangeForPosition(position)` — the port measures it
// off the rendered line DOM (`View::offset_for_column` via the
// `ViewContext.offset_for_column` seam; `-1` = line not rendered → Monaco's
// "Outside viewport → null"). The caret top is the line's viewport-relative
// vertical offset, like every flat overlay piece. The result is stored as
// the part's `render_data` (Monaco's `this._renderData`).
impl ViewPart for @view_cursors.ViewCursors with fn prepare_render(
  self,
  context,
) {
  self.render_data = match context.input.view_selection {
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
              context.viewport.line_height,
              @view_cursors.device_pixel_ratio(),
            ),
          )
        }
      }
    }
  }
  // Monaco's `ViewCursor._position`, kept even while outside the viewport so
  // token-range invalidation can test the primary cursor line exactly.
  self.last_position = context.input.view_selection.map(selection => {
    selection.get_position()
  })
}

///|
impl ViewPart for @view_cursors.ViewCursors with fn render(self, context) {
  let has_selection = match context.input.view_selection {
    Some(selection) => !selection.is_empty()
    None => false
  }
  self.render_cursor(
    has_selection~,
    editor_has_focus=context.input.editor_has_focus,
  )
  // Source `ViewCursors._renderData` is an array built only by this render
  // pass. Pair the freshly painted rectangle with the position prepared for
  // this same pass; later cursor events leave this pair intact for hit tests.
  self.last_rendered_position = self.last_position
}

///|
impl ViewPart for @view_cursors.ViewCursors with fn on_did_render(self) {
  self.should_render = false
}

///|
/// `PartFingerprint` (`vscode/src/vs/editor/browser/view/viewPart.ts:34-46`,
/// vscode submodule commit b18492a288de038fbc7643aae6de8247029d11bd). The
/// numeric values are load-bearing: they are written into `data-mprt`
/// attributes and compared by index in `ElementPath`'s predicates, so the
/// enum order must never change. `TextArea`, `Minimap` and `ViewLinesGpu`
/// keep their slots (7/9/10) but are never written — the viewer has no such
/// parts (Monaco's checkout writes no `ViewLinesGpu` either).
pub(all) enum PartFingerprint {
  None
  ContentWidgets
  OverflowingContentWidgets
  OverflowGuard
  OverlayWidgets
  OverflowingOverlayWidgets
  ScrollableElement
  TextArea
  ViewLines
  Minimap
  ViewLinesGpu
} derive(Eq, Debug)

///|
pub fn PartFingerprint::to_int(self : PartFingerprint) -> Int {
  match self {
    None => 0
    ContentWidgets => 1
    OverflowingContentWidgets => 2
    OverflowGuard => 3
    OverlayWidgets => 4
    OverflowingOverlayWidgets => 5
    ScrollableElement => 6
    TextArea => 7
    ViewLines => 8
    Minimap => 9
    ViewLinesGpu => 10
  }
}

///|
pub fn PartFingerprint::from_int(value : Int) -> PartFingerprint {
  match value {
    1 => ContentWidgets
    2 => OverflowingContentWidgets
    3 => OverflowGuard
    4 => OverlayWidgets
    5 => OverflowingOverlayWidgets
    6 => ScrollableElement
    7 => TextArea
    8 => ViewLines
    9 => Minimap
    10 => ViewLinesGpu
    _ => None
  }
}

///|
/// `PartFingerprints` (viewPart.ts:48-82). Deviation: Monaco stamps inside
/// each part's constructor, but this port's dependency direction is inverted
/// (part packages cannot import `@view`), so `View::new` stamps every part
/// root right after construction (view.mbt).
pub(all) struct PartFingerprints {}

///|
pub fn PartFingerprints::write(
  target : @rdom.Element,
  part_id : PartFingerprint,
) -> Unit {
  target.set_attribute("data-mprt", part_id.to_int().to_string())
}

///|
pub fn PartFingerprints::read(target : @rdom.Element) -> PartFingerprint {
  PartFingerprint::from_int(read_data_mprt(target))
}

///|
/// `collect` (viewPart.ts:62-81): the root-first fingerprint path from
/// `child` up to (excluding) `stop_at`, as bytes mirroring the source's
/// `Uint8Array`. The walk visits elements only (`parentElement`), stopping at
/// the document body like the source.
pub fn PartFingerprints::collect(
  child : @rdom.Element?,
  stop_at : @rdom.Element,
) -> Bytes {
  let result : Array[Byte] = []
  let mut node = child
  while node is Some(el) && !is_document_body(el) {
    if el.is_same_node(stop_at.as_node()) {
      break
    }
    result.push(PartFingerprints::read(el).to_int().to_byte())
    node = parent_element(el)
  }
  Bytes::makei(result.length(), i => result[result.length() - i - 1])
}

///|
/// FFI gap-fills (no `ownerDocument.body` / null-distinguishing
/// `getAttribute` / `parentElement` bindings in the vendored `@rdom`).
extern "js" fn is_document_body(el : @rdom.Element) -> Bool =
  #| (el) => el === el.ownerDocument.body

///|
extern "js" fn read_data_mprt(el : @rdom.Element) -> Int =
  #| (el) => {
  #|   const r = el.getAttribute("data-mprt");
  #|   return r === null ? 0 : (parseInt(r, 10) | 0);
  #| }

///|
fn parent_element(el : @rdom.Element) -> @rdom.Element? {
  match el.get_parent_node().to_option() {
    Some(node) => node.to_element()
    None => None
  }
}
