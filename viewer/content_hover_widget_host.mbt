// The viewer core's side of the content-hover widget seam: Monaco's
// `ContentHoverWidgetWrapper._showHover`/`_hideHover` (driving the persistent
// `ContentHoverWidget` when `_setCurrentResult` changed the shown result) plus
// the `ICodeEditor` surface the widget consumes (`addContentWidget` /
// `layoutContentWidget` / `render`), expressed as `Viewer::` glue — the
// foreign-method rule keeps these out of the widget's own package.

///|
/// Reconciles the persistent content-hover widget with the controller's
/// derived view. Idempotent (dedupes on the `HoverWidgetView`), so every
/// hover-state chokepoint may call it: Monaco's `_setCurrentResult` calls
/// `_showHover`/`_hideHover` exactly when the result object changed.
fn Viewer::sync_content_hover_widget(self : Viewer) -> Unit {
  let widget_view = match self.content_hover_controller() {
    Some(hc) => hc.hover.widget_view()
    None => None
  }
  if widget_view == self.hover_widget_view {
    return
  }
  self.hover_widget_view = widget_view
  match widget_view {
    Some(view) =>
      match self.ensure_content_hover_widget() {
        Some(widget) => widget.show(self.rendered_content_hover(view))
        None => ()
      }
    None =>
      match self.content_hover_widget {
        Some(widget) => widget.hide()
        None => ()
      }
  }
}

///|
/// Monaco `RenderedContentHover`'s constructor work
/// (`contentHoverRendered.ts`): resolve where the widget anchors
/// (`computeHoverPositions` over the parts, with the anchor view line's
/// minimum column as the `startColumnBoundary`) and render the part rows.
fn Viewer::rendered_content_hover(
  self : Viewer,
  view : @hover.HoverWidgetView,
) -> @hover_browser.RenderedContentHover {
  let placement_parts : Array[@hover.HoverPositionPart] = []
  for part in view.parts {
    placement_parts.push({
      range: @hover.hover_part_range(part),
      force_show_at_range: false,
    })
  }
  // `startColumnBoundary` (`contentHoverRendered.ts:127-133`): the anchor view
  // line's minimum column, converted back to model space — under wrapping this
  // is the wrapped row's first model column.
  let anchor_start = view.anchor_range.get_start_position()
  let start_column_boundary = match
    self.model_to_view_position(anchor_start.line_number, anchor_start.column) {
    Some(view_position) =>
      self.view_to_model(Position(view_position.line_number, 1)).column
    None => 1
  }
  let (show_at_position, show_at_secondary_position) = @hover.compute_hover_positions(
    view.anchor_range,
    placement_parts,
    start_column_boundary,
  )
  let language_id = match self.get_view_model() {
    Some(view_model) => view_model.language_id()
    None => ""
  }
  {
    show_at_position,
    show_at_secondary_position,
    rows: @hover.render_hover_parts(view.parts, language_id),
  }
}

///|
/// Lazily constructs the widget and mounts it — Monaco's
/// `ContentHoverWidget` constructor calling `_editor.addContentWidget(this)`.
/// The widget itself is created once per `Viewer`; each per-model `View`
/// re-adds it through `create_view`'s widget re-add loop (`cew:1893-1899`).
/// `None` before a view exists.
fn Viewer::ensure_content_hover_widget(
  self : Viewer,
) -> @hover_browser.ContentHoverWidget? {
  match self.content_hover_widget {
    Some(widget) => Some(widget)
    None => {
      guard self.get_view() is Some(view) else { return None }
      let widget = @hover_browser.ContentHoverWidget::new({
        root: view.root,
        layout_content_widget: () => self.layout_content_hover_widget(),
        render_now: () => self.flush_render(),
        focus_editor: () => self.focus(),
        scrolled_visible_position_top: position => {
          self.scrolled_visible_position_top(position)
        },
        // Monaco reads `EditorOption.lineHeight` — configuration, not layout.
        line_height: () => self.font_info.line_height.to_double(),
        keep_hover_open: () => self.keep_hover_open(),
        handle_keydown: (event, keyboard) => {
          self.handle_hover_keydown(event, keyboard)
        },
        hook_scrollable_scrollbar_input: (scrollable, owner) => {
          match self.mouse_handler {
            Some(handler) =>
              handler.hook_scrollable_scrollbar_input(scrollable, owner)
            None => ()
          }
        },
      })
      self.content_hover_widget = Some(widget)
      view.content_widgets.add_widget(widget)
      Some(widget)
    }
  }
}

///|
/// Monaco `ICodeEditor.layoutContentWidget(widget)`: re-read the widget's
/// `get_position()` into the content-widgets part and repaint.
fn Viewer::layout_content_hover_widget(self : Viewer) -> Unit {
  guard self.get_view() is Some(view) else { return }
  guard self.content_hover_widget is Some(widget) else { return }
  view.content_widgets.set_widget_position(widget)
  self.schedule_render()
}

///|
/// Monaco `ICodeEditor.getScrolledVisiblePosition(position).top`: the model
/// position's line top in editor-viewport pixels.
fn Viewer::scrolled_visible_position_top(
  self : Viewer,
  position : @base_common.Position,
) -> Double {
  guard self.get_view_model() is Some(view_model) else { return 0.0 }
  match self.model_to_view_position(position.line_number, position.column) {
    Some(view_position) =>
      view_model.view_layout.vertical_offset_for_line(view_position.line_number) -
      view_model.view_layout.position().scroll_top
    None => 0.0
  }
}
