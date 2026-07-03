// The thread's zone widget, porting the shell of
// `vscode/src/vs/workbench/contrib/comments/browser/commentThreadZoneWidget.ts`
// (`ReviewZoneWidget extends ZoneWidget`): arrow + frame on, the inner
// `CommentThreadWidget` fills the container, and `_refresh` re-measures the
// content to relayout the zone. The glyph decoration, expand/collapse
// bookkeeping, and reveal policy live in the root glue
// (`viewer/comments_host.mbt`).

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
}

///|
pub fn ReviewZoneWidget::new(
  zone_host : @zone_widget.ZoneWidgetHost,
  thread : @comments_common.CommentThread,
  actions : CommentWidgetActions,
) -> ReviewZoneWidget {
  // The inner widget reports content changes before the ReviewZoneWidget
  // exists; route them through a cell (VS Code wires the equivalent
  // `onDidResize` after construction, `commentThreadZoneWidget.ts:436-438`).
  let review_cell : Ref[ReviewZoneWidget?] = { val: None }
  let widget_host : CommentThreadWidgetHost = {
    on_submit_new: actions.on_submit_new,
    on_save_edit: actions.on_save_edit,
    on_delete: actions.on_delete,
    on_collapse: actions.on_collapse,
    on_content_resized: () => {
      match review_cell.val {
        Some(review) => review.refresh()
        None => ()
      }
    },
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
  let review : ReviewZoneWidget = { zone, widget }
  review_cell.val = Some(review)
  review
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
/// Applies an updated thread; the inner widget re-renders and reports the
/// resize back into `refresh`.
pub fn ReviewZoneWidget::update(
  self : ReviewZoneWidget,
  thread : @comments_common.CommentThread,
) -> Unit {
  self.widget.update(thread)
}

///|
pub fn ReviewZoneWidget::focus_form(self : ReviewZoneWidget) -> Unit {
  self.widget.focus_form()
}

///|
/// `_refresh` (`commentThreadZoneWidget.ts:496-513`): measure the content
/// and relayout — `computedLinesNumber = ceil((content + arrow + frame + 8)
/// / lineHeight)` (`:509`; head and body heights collapse into the root's
/// scroll height here). The zone widget's no-change guard keeps repeated
/// refreshes scroll-stable.
pub fn ReviewZoneWidget::refresh(self : ReviewZoneWidget) -> Unit {
  guard self.zone.is_visible() else { return }
  let line_height = (self.zone.host.line_height)()
  guard line_height > 0 else { return }
  let content = self.widget.dom().get_scroll_height()
  let arrow = (line_height.to_double() / 3.0 + 0.5).to_int()
  let frame = (line_height.to_double() / 9.0 + 0.5).to_int()
  let total = content + (arrow + frame + 8).to_double()
  let mut lines = (total / line_height.to_double()).to_int()
  if lines.to_double() * line_height.to_double() < total {
    lines += 1
  }
  self.zone.relayout(lines)
}
