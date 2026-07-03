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
  // The same measurement with `keep_empty=true`, for the decorations overlay:
  // a collapsed range must yield its zero-width caret rect so the
  // `showIfCollapsed` widening has geometry to center on.
  measure_line_decorations : (Int, Int, Int) -> Array[(Double, Double)]
  // Monaco's `RenderingContext.visibleRangeForPosition(...).left` seam: the
  // caret x of a one-based view column on a rendered view line
  // (`View::offset_for_column`; `-1` when the line is not rendered).
  offset_for_column : (Int, Int) -> Double
  // Model position → document offset through the model snapshot. The hover
  // state is `Range`-typed; the content-widget pixel placement is the one
  // offset consumer left (deviations-closeout Track E), converting here.
  model_position_to_offset : (@base_common.Position) -> Int
}
