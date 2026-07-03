// The thread's zone widget, porting the shell of
// `vscode/src/vs/workbench/contrib/comments/browser/commentThreadZoneWidget.ts`
// (`ReviewZoneWidget extends ZoneWidget`): arrow + frame on, the inner
// `CommentThreadWidget` fills the container, resize observation drives
// `_refresh` (`this._commentThreadWidget.onDidResize(dimensions =>
// this._refresh(dimensions))`, `:436-438`), and the relayout is bracketed by
// `StableEditorScrollState.capture/restore` (`:521-523`). The glyph
// decoration, expand/collapse bookkeeping, and reveal policy live in the
// root glue (`viewer/comments_host.mbt`).

///|
/// The comment actions the glue routes to the `CommentService`.
pub(all) struct CommentWidgetActions {
  on_submit_new : (String) -> Unit
  on_save_edit : (Int, String) -> Unit
  on_delete : (Int) -> Unit
  on_collapse : () -> Unit
}

///|
pub struct ReviewZoneWidget {
  zone : @zone_widget.ZoneWidget
  widget : CommentThreadWidgetDom
  mut observed : Bool
}

///|
pub fn ReviewZoneWidget::new(
  zone_host : @zone_widget.ZoneWidgetHost,
  thread : @comments_common.CommentThread,
  actions : CommentWidgetActions,
) -> ReviewZoneWidget {
  let widget_host : CommentThreadWidgetHost = {
    on_submit_new: actions.on_submit_new,
    on_save_edit: actions.on_save_edit,
    on_delete: actions.on_delete,
    on_collapse: actions.on_collapse,
  }
  let widget = CommentThreadWidgetDom::new(widget_host, thread)
  let zone = @zone_widget.ZoneWidget::new(
    zone_host,
    "comment-thread-" + thread.thread_id,
    show_arrow=true,
    show_frame=true,
    class_name="review-widget-zone",
    fill=container => container.append_child(widget.dom().as_node()),
  )
  let review : ReviewZoneWidget = { zone, widget, observed: false }
  // `_commentThreadWidget.onDidResize(dimensions => this._refresh(dimensions))`
  // (`commentThreadZoneWidget.ts:436-438`): content-size changes in the body
  // or the form re-measure the zone. The head is fixed-height; the root's
  // border box is pinned by the container, so the content-sized children are
  // the observed elements.
  observe_element_resize(widget.body_dom(), () => review.refresh())
  observe_element_resize(widget.form_dom(), () => review.refresh())
  review.observed = true
  review
}

///|
/// Unhooks the resize observers; the zone/overlay side is `hide`.
pub fn ReviewZoneWidget::dispose(self : ReviewZoneWidget) -> Unit {
  if self.observed {
    self.observed = false
    unobserve_element_resize(self.widget.body_dom())
    unobserve_element_resize(self.widget.form_dom())
  }
  self.hide()
}

///|
/// `ReviewZoneWidget.display`: opens the zone at the (view) anchor line and
/// sizes it to the content (`show(range, 2)` then measure, `:420-436`).
pub fn ReviewZoneWidget::display(
  self : ReviewZoneWidget,
  anchor_view_line : Int,
) -> Unit {
  self.zone.show(anchor_view_line, 2)
  self.refresh()
}

///|
pub fn ReviewZoneWidget::hide(self : ReviewZoneWidget) -> Unit {
  self.zone.hide()
}

///|
pub fn ReviewZoneWidget::is_visible(self : ReviewZoneWidget) -> Bool {
  self.zone.is_visible()
}

///|
/// Re-anchors an open widget after folding/wrapping moved its view line.
pub fn ReviewZoneWidget::update_anchor(
  self : ReviewZoneWidget,
  anchor_view_line : Int,
) -> Unit {
  self.zone.update_anchor(anchor_view_line)
}

///|
/// Applies an updated thread; the inner widget re-renders and the resize
/// observers report the new content size back into `refresh`.
pub fn ReviewZoneWidget::update(
  self : ReviewZoneWidget,
  thread : @comments_common.CommentThread,
) -> Unit {
  self.widget.update(thread)
  self.refresh()
}

///|
pub fn ReviewZoneWidget::focus_form(self : ReviewZoneWidget) -> Unit {
  self.widget.focus_form()
}

///|
/// `_refresh` (`commentThreadZoneWidget.ts:496-527`): measure the content
/// and relayout — `computedLinesNumber = ceil((headHeight + dimensions.height
/// + arrowHeight + frameThickness + 8) / lineHeight)` (`:504-509`), where the
/// head is *computed* (`ceil(lineHeight * 1.2)`) and `dimensions` is the
/// natural size of the body container, which in the source also hosts the
/// reply form (`commentThreadWidget.ts:287`) and is never height-constrained
/// by the zone. Measuring the root `.review-widget` instead would read the
/// zone's own height back (the root is `height:100%` with a scrolling body),
/// latching a re-opened widget at its 2-line spacer size. No-op when the line
/// count is unchanged (`:511-513`), and the relayout runs inside a
/// `StableEditorScrollState` bracket (`:521-523`) so a zone growing above the
/// viewport does not shift the visible content.
pub fn ReviewZoneWidget::refresh(self : ReviewZoneWidget) -> Unit {
  guard self.zone.is_visible() else { return }
  let line_height = (self.zone.host.line_height)()
  guard line_height > 0 else { return }
  // `ceil(lineHeight * 1.2)` (`:504`), as an integer ceiling.
  let head = (line_height * 12 + 9) / 10
  let content = self.widget.body_dom().get_scroll_height() +
    self.widget.form_dom().get_scroll_height()
  let arrow = (line_height.to_double() / 3.0 + 0.5).to_int()
  // `frameThickness = Math.round(lineHeight / 9) * 2` (`:507`) — both borders.
  let frame = (line_height.to_double() / 9.0 + 0.5).to_int() * 2
  let total = content + (head + arrow + frame + 8).to_double()
  let mut lines = (total / line_height.to_double()).to_int()
  if lines.to_double() * line_height.to_double() < total {
    lines += 1
  }
  if lines == self.zone.height_in_lines {
    return
  }
  let restore = (self.zone.host.capture_stable_scroll)()
  self.zone.relayout(lines)
  restore()
}

///|
/// FFI gap-fill (no ResizeObserver binding in the vendored `@rdom`): one
/// observer per element, parked on an expando so `unobserve` can disconnect
/// it.
extern "js" fn observe_element_resize(
  element : @rdom.Element,
  callback : () -> Unit,
) -> Unit =
  #| (el, cb) => {
  #|   const observer = new ResizeObserver(() => cb());
  #|   observer.observe(el);
  #|   el.__viewerResizeObserver = observer;
  #| }

///|
extern "js" fn unobserve_element_resize(element : @rdom.Element) -> Unit =
  #| (el) => {
  #|   el.__viewerResizeObserver?.disconnect();
  #|   delete el.__viewerResizeObserver;
  #| }
