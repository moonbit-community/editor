// The DOM half of Monaco's `CurrentLineMarginHighlightOverlay`
// (`viewParts/currentLineHighlight/currentLineHighlight.ts:224-235` over the
// abstract `prepareRender`, `:126-171`), rendered into this package because
// Monaco registers it as the first margin dynamic overlay — before the
// line-number overlay (`view.ts:225-229`). The DOM-free predicates and class
// strings live in `viewer/common/view_layout` (`current_line_highlight.mbt`);
// the content twin lives with the selections part.
//
// Local structure deviation (the line-numbers `view-layer` precedent):
// the pieces live in a dedicated first-child layer div so this overlay can
// rebuild without touching the recycled line-number nodes.

///|
/// Renders the margin current-line highlight for one frame.
/// `_shouldRenderThis` is `true` for the margin overlay (`:229-231`) — an
/// unhighlighted mode simply produces pieces with the bare `current-line`
/// class (no `current-line-margin`), which no CSS rule paints; `width` is
/// `_contentLeft`, the margin width (`:227`).
pub fn MarginViewOverlays::render_current_line_margin(
  self : MarginViewOverlays,
  viewport : @view_layout.ViewportData,
  view_model : @view_model.ViewModel?,
  cursor_view_line : Int?,
  selection_is_empty : Bool,
  editor_has_focus : Bool,
  word_wrap : Bool,
  render_line_highlight : @view_layout.RenderLineHighlight,
  render_line_highlight_only_when_focus : Bool,
  width : Double,
) -> Unit {
  self.current_line.set_inner_html("")
  guard cursor_view_line is Some(cursor_line) else { return }
  let in_margin = @view_layout.should_render_line_highlight_in_margin(
    render_line_highlight, render_line_highlight_only_when_focus, editor_has_focus,
  )
  // `_shouldRenderOther` for the margin overlay is `_shouldRenderInContent`
  // (`:232-234`) — it feeds the `current-line-margin-both` class.
  let other = @view_layout.should_render_line_highlight_in_content(
    render_line_highlight, render_line_highlight_only_when_focus, editor_has_focus,
    selection_is_empty,
  )
  let document = @rdom.document()
  let (first_line, last_line) = margin_current_line_span(
    view_model, cursor_line, word_wrap,
  )
  for view_line in first_line..<=last_line {
    let index = view_line - viewport.start_line_number
    if index < 0 || index >= viewport.relative_vertical_offset.length() {
      continue
    }
    let class_name = @view_layout.current_line_margin_class(
      in_margin~,
      other~,
      exact=view_line == cursor_line,
    )
    let node = document.create_element("div")
    node.set_attribute("class", class_name)
    node.set_attribute(
      "style",
      "top:\{viewport.relative_vertical_offset[index]}px;width:\{width}px;height:\{@core.editor_line_height}px",
    )
    self.current_line.append_child(node.as_node())
  }
}

///|
/// The view-line span (wrapped pass, `currentLineHighlight.ts:141-158`) —
/// the margin twin of the selections package's `current_line_span`.
fn margin_current_line_span(
  view_model : @view_model.ViewModel?,
  cursor_view_line : Int,
  word_wrap : Bool,
) -> (Int, Int) {
  if !word_wrap {
    return (cursor_view_line, cursor_view_line)
  }
  match view_model {
    Some(view_model) => {
      let lines = view_model.lines()
      @view_layout.view_line_span_of_model_line(
        cursor_view_line,
        lines.line_count(),
        view_line => lines.model_line_number_of_view_line(view_line),
      )
    }
    None => (cursor_view_line, cursor_view_line)
  }
}
