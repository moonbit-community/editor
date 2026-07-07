// The DOM half of Monaco's `CurrentLineHighlightOverlay`
// (`viewParts/currentLineHighlight/currentLineHighlight.ts:207-219` over the
// abstract `prepareRender`, `:126-171`), rendered into the shared
// `.view-overlays` container owned by `view_parts/selections`'
// `ContentViewOverlays` because Monaco registers it there as the first
// dynamic overlay — before `SelectionsOverlay` (`view.ts:218-219`), which
// keeps the highlight painting under the selection; the shared `ViewPart`
// shell in `viewer/browser/view/view_part.mbt` sequences the overlay
// packages. The DOM-free predicates and class strings live in
// `viewer/common/view_layout` (`current_line_highlight.mbt`); the margin
// twin lives with the margin part.
//
// Flat-overlay deviation (like the selection pieces): one absolutely
// positioned div per highlighted view line instead of per-line container
// HTML, sized inline (`height:100%` in Monaco's CSS becomes an explicit
// line-height px).

///|
/// Renders the current-line highlight for one frame. The caller (the
/// `ViewPart` impl) has already cleared the container; pieces are appended
/// before the selection pieces so DOM order preserves Monaco's overlay
/// z-order. `width` is `max(ctx.scrollWidth, contentWidth)`
/// (`currentLineHighlight.ts:211`). `container` is the `.view-overlays`
/// element owned by `@selections.ContentViewOverlays` (foreign-method rule:
/// this sibling package exposes a free function instead of a method).
pub fn render_current_line(
  container : @rdom.Element,
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
  // `_shouldRenderThis` (`:213-215`) → `_shouldRenderInContent` (`:191-197`).
  if !@view_layout.should_render_line_highlight_in_content(
      render_line_highlight, render_line_highlight_only_when_focus, editor_has_focus,
      selection_is_empty,
    ) {
    return
  }
  guard cursor_view_line is Some(cursor_line) else { return }
  let in_margin = @view_layout.should_render_line_highlight_in_margin(
    render_line_highlight, render_line_highlight_only_when_focus, editor_has_focus,
  )
  let document = @rdom.document()
  // Wrapped pass (`:141-158`): every view line of the cursor's model line
  // gets the non-exact class; the exact pass (`:160-168`) then claims the
  // cursor's own view line.
  let (first_line, last_line) = current_line_span(
    view_model, cursor_line, word_wrap,
  )
  for view_line in first_line..<=last_line {
    let index = view_line - viewport.start_line_number
    if index < 0 || index >= viewport.relative_vertical_offset.length() {
      continue
    }
    let class_name = @view_layout.current_line_content_class(
      in_margin~,
      exact=view_line == cursor_line,
    )
    let node = document.create_element("div")
    node.set_attribute("class", class_name)
    node.set_attribute(
      "style",
      current_line_style(viewport.relative_vertical_offset[index], width),
    )
    container.append_child(node.as_node())
  }
}

///|
/// The view-line span the highlight covers: the wrapped-line pass's model-line
/// span when wrapping (`currentLineHighlight.ts:141-158`), else just the
/// cursor line.
pub fn current_line_span(
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
        lines.get_view_line_count(),
        view_line => lines.model_line_number_of_view_line(view_line),
      )
    }
    None => (cursor_view_line, cursor_view_line)
  }
}

///|
fn current_line_style(top : Int, width : Double) -> String {
  "top:\{top}px;width:\{width}px;height:\{@core.editor_line_height}px"
}
