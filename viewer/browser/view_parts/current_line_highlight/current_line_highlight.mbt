// Monaco's `CurrentLineHighlightOverlay`
// (`viewParts/currentLineHighlight/currentLineHighlight.ts`): the content
// half of the abstract `AbstractLineHighlightOverlay.prepareRender`
// (`:126-171`) plus `CurrentLineHighlightOverlay._renderOne` (`:209-212`),
// as a pure per-line HTML builder. The overlay renders into
// `browser/view`'s `ContentViewOverlays` rows as the first registered
// dynamic overlay — before `SelectionsOverlay` (`view.ts:218-219`), which
// keeps the highlight painting under the selection. The `DynamicViewOverlay`
// impl lives in `viewer/browser/view/view_part.mbt` (the trait-owning
// package); the DOM-free predicates and class strings live in
// `viewer/common/view_layout` (`current_line_highlight.mbt`); the margin
// twin lives with the margin part.

///|
/// The content current-line dynamic overlay's state: the prepared per-line
/// HTML (`_renderData`). `pub(all)`: the `DynamicViewOverlay` impl in
/// `browser/view/view_part.mbt` reads/writes `render_result` directly.
pub(all) struct CurrentLineHighlightOverlay {
  mut render_result : Array[String]
}

///|
pub fn CurrentLineHighlightOverlay::new() -> CurrentLineHighlightOverlay {
  { render_result: [] }
}

///|
/// `AbstractLineHighlightOverlay.prepareRender` (`:126-171`) over the content
/// overlay's predicates: every line starts empty; when the highlight should
/// render in content, the wrapped pass (`:141-158`) fills the cursor's whole
/// model-line span with the non-exact div and the exact pass (`:160-168`)
/// claims the cursor's own view line. `width` is
/// `max(ctx.scrollWidth, contentWidth)` (`_renderOne`, `:211`).
pub fn prepare_current_line_render(
  viewport : @view_layout.ViewportData,
  view_model : @view_model.ViewModel?,
  cursor_view_line : Int?,
  selection_is_empty : Bool,
  editor_has_focus : Bool,
  word_wrap : Bool,
  render_line_highlight : @view_layout.RenderLineHighlight,
  render_line_highlight_only_when_focus : Bool,
  width : Double,
) -> Array[String] {
  let render_data : Array[String] = []
  for _ in 0..<viewport.lines.length() {
    render_data.push("")
  }
  // `_shouldRenderThis` (`:213-215`) → `_shouldRenderInContent` (`:191-197`).
  if !@view_layout.should_render_line_highlight_in_content(
      render_line_highlight, render_line_highlight_only_when_focus, editor_has_focus,
      selection_is_empty,
    ) {
    return render_data
  }
  guard cursor_view_line is Some(cursor_line) else { return render_data }
  let in_margin = @view_layout.should_render_line_highlight_in_margin(
    render_line_highlight, render_line_highlight_only_when_focus, editor_has_focus,
  )
  // Wrapped pass (`:141-158`), gated on word wrap like the source's
  // `_wordWrap`; then the exact pass (`:160-168`).
  let (first_line, last_line) = current_line_span(
    view_model, cursor_line, word_wrap,
  )
  for view_line in first_line..<=last_line {
    let index = view_line - viewport.start_line_number
    if index < 0 || index >= render_data.length() {
      continue
    }
    render_data[index] = render_one(
      in_margin~,
      exact=view_line == cursor_line,
      width~,
    )
  }
  render_data
}

///|
/// `CurrentLineHighlightOverlay._renderOne` (`:209-212`); the class string
/// comes from the ported `current_line_content_class`, height from the row
/// (`height: 100%` in `current_line_highlight.css`).
fn render_one(in_margin~ : Bool, exact~ : Bool, width~ : Double) -> String {
  let class_name = @view_layout.current_line_content_class(in_margin~, exact~)
  "<div class=\"" +
  class_name +
  "\" style=\"width:" +
  width.to_string() +
  "px;\"></div>"
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
