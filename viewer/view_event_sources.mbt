///|
/// Emits one typed view event at its root Viewer source. A headless Viewer has
/// no browser View (and therefore no ViewPart consumer), so it deliberately
/// performs only the same ViewModel/cache mutations in that mode.
fn Viewer::emit_view_event(self : Viewer, event : @view.ViewEvent) -> Unit {
  match self.get_view() {
    Some(view) => view.emit_view_event(event)
    None => ()
  }
}

///|
/// Opens a source-shaped nested event batch on the current browser View. The
/// returned View is the exact dispatcher whose matching `end` must run even
/// if Viewer state changes before the batch completes.
fn Viewer::begin_view_event_batch(self : Viewer) -> @view.View? {
  match self.get_view() {
    Some(view) => {
      view.begin_view_event_batch() |> ignore
      Some(view)
    }
    None => None
  }
}

///|
fn end_view_event_batch(view : @view.View?) -> Unit {
  match view {
    Some(view) => view.end_view_event_batch()
    None => ()
  }
}

///|
/// Maps the complete typed ViewerOptions snapshots onto the exact semantic
/// option identities consumed by the scoped ViewParts. The caller supplies
/// the already-computed layout-info comparison because that identity depends
/// on the live model's digit count and measured font metrics, not raw options
/// alone.
fn view_configuration_changed_event(
  previous : ViewerOptions,
  current : ViewerOptions,
  previous_font_info : @config.FontInfo,
  current_font_info : @config.FontInfo,
  previous_soft_wrap_column : Int,
  current_soft_wrap_column : Int,
  layout_info_changed~ : Bool,
) -> @view.ViewConfigurationChangedEvent? {
  let changed : Array[@view.ViewConfigurationOption] = []
  if layout_info_changed {
    changed.push(LayoutInfo)
  }
  if !previous_font_info.equals(current_font_info) {
    changed.push(FontInfo)
  }
  if previous_font_info.line_height != current_font_info.line_height {
    changed.push(LineHeight)
  }
  if previous.soft_wrap != current.soft_wrap ||
    previous.tab_size != current.tab_size ||
    previous.wrapping_indent != current.wrapping_indent ||
    previous_soft_wrap_column != current_soft_wrap_column {
    changed.push(WrappingInfo)
  }
  if previous.render_whitespace != current.render_whitespace {
    changed.push(RenderWhitespace)
  }
  if previous.render_control_characters != current.render_control_characters {
    changed.push(RenderControlCharacters)
  }
  if previous.render_line_highlight != current.render_line_highlight {
    changed.push(RenderLineHighlight)
  }
  if previous.render_line_highlight_only_when_focus !=
    current.render_line_highlight_only_when_focus {
    changed.push(RenderLineHighlightOnlyWhenFocus)
  }
  if previous.render_validation_decorations !=
    current.render_validation_decorations {
    changed.push(RenderValidationDecorations)
  }
  if changed.length() == 0 {
    None
  } else {
    Some(@view.ViewConfigurationChangedEvent::from_changed_options(changed))
  }
}

///|
/// Preserves every inclusive grammar-token range in producer order. Semantic
/// token application is outside this readonly grammar-token child; the View
/// event's source payload intentionally carries only the line ranges consumed
/// by ViewLines and ViewCursors.
fn view_tokens_changed_event(
  changed_ranges : Array[(Int, Int)],
) -> @view.ViewTokensChangedEvent {
  let ranges : Array[@view.ViewTokenChangeRange] = []
  for range in changed_ranges {
    let (from_line_number, to_line_number) = range
    ranges.push(ViewTokenChangeRange(from_line_number, to_line_number))
  }
  ViewTokensChangedEvent(ranges)
}

///|
/// Emits the committed view-space cursor state before the public outgoing
/// cursor pair, as in Monaco.
fn Viewer::emit_view_cursor_state_changed(
  self : Viewer,
  view_model : @view_model.ViewModel,
) -> Unit {
  self.emit_view_event(
    ViewCursorStateChanged(view_cursor_state_changed_event(view_model)),
  )
}

///|
fn view_cursor_state_changed_event(
  view_model : @view_model.ViewModel,
) -> @view.ViewCursorStateChangedEvent {
  ViewCursorStateChangedEvent([view_model.cursor.get_view_selection()])
}

///|
/// Emits a mapping-only cursor reprojection only when the view-coordinate
/// selection actually changed. The model selection remains stable and the
/// source reason is `NotSet`.
fn Viewer::emit_view_cursor_reprojection(
  self : Viewer,
  view_model : @view_model.ViewModel,
  previous_view_selection : @core.Selection,
) -> Unit {
  let current_view_selection = view_model.cursor.get_view_selection()
  if current_view_selection == previous_view_selection {
    return
  }
  self.emit_view_event(
    ViewCursorStateChanged(
      ViewCursorStateChangedEvent([current_view_selection]),
    ),
  )
}

///|
/// Preserves the width needed by ViewLines and all four independent changed
/// flags from ViewLayout's source event.
fn Viewer::emit_view_scroll_changed(
  self : Viewer,
  change : @view_layout.ScrollChange,
) -> Unit {
  self.emit_view_event(ViewScrollChanged(view_scroll_changed_event(change)))
}

///|
fn view_scroll_changed_event(
  change : @view_layout.ScrollChange,
) -> @view.ViewScrollChangedEvent {
  ViewScrollChangedEvent(
    change.scroll_width,
    change.scroll_width_changed,
    change.scroll_left_changed,
    change.scroll_height_changed,
    change.scroll_top_changed,
  )
}
