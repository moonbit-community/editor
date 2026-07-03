// The viewer core's side of the comments contrib
// (`vscode/src/vs/workbench/contrib/comments/browser/commentsController.ts`):
// the mouse-down/up pairing that opens or toggles a thread at a gutter line.
// Kept here per the foreign-method rule (every `Viewer::` method lives in
// `Viewer`'s own package). The controller/service/widget halves land with the
// comments contrib; until then the mouse seam terminates in these stubs.

///|
/// `CommentController.onEditorMouseDown` (`commentsController.ts:1107`).
fn Viewer::on_comments_mouse_down(
  self : Viewer,
  target : @viewer_common.MouseTarget,
) -> Unit {
  ignore((self, target))
}

///|
/// `CommentController.onEditorMouseUp` (`commentsController.ts:1111`).
fn Viewer::on_comments_mouse_up(
  self : Viewer,
  target : @viewer_common.MouseTarget,
) -> Unit {
  ignore((self, target))
}
