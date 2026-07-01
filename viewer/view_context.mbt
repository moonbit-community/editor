///|
/// Shared browser render state passed to view parts during one coordinated
/// render. It exposes only the explicit capabilities parts need; the public
/// facade remains `Viewer` and browser DOM ownership stays on each part.
///
/// `pub(all)`: built by `Viewer::build_view_context` (`view_host.mbt`), which
/// lives with `Viewer` and thus, by the foreign-method rule, cannot live in
/// this package — so construction is a plain cross-package record literal
/// rather than a same-package `ViewContext::new`.
pub(all) struct ViewContext {
  root : @rdom.Element
  languages : @languages.Languages
  handle_hover_mousedown : (@rdom.Event, @rdom.MouseEvent) -> Unit
  handle_hover_keydown : (
    @content_widgets.HoverWidgetDom,
    @rdom.Event,
    @rdom.KeyboardEvent,
  ) -> Unit
  // The pointer is over the hover widget: keep the hover open and drop any
  // pending hide (Monaco's `_shouldKeepCurrentHover` over the content widget).
  keep_hover_open : () -> Unit
  hook_scrollable_scrollbar_input : (
    @scrollbar.ScrollableElementDom,
    @scrollbar.ScrollableElementOwner,
  ) -> Unit
  // Monaco's `RenderingContext.linesVisibleRangesForRange` seam: measures the
  // pixel rects of a zero-based view-column range on a view line off the live
  // line DOM, which the selection overlay renders after `ViewLines` writes.
  measure_line_selection : (Int, Int, Int) -> Array[(Double, Double)]
}
