// Public mouse events — Monaco `ICodeEditor.onMouseDown` / `onMouseUp` /
// `onMouseMove` / `onMouseLeave` (`codeEditorWidget.ts`), fired from the
// controller's notify seams (`ViewController.emitMouseDown/Up` and the
// hit-tested move/leave path). Reduced payload: `IEditorMouseEvent` collapses
// to the hit-tested `target` plus the left-button fact — the raw browser
// event and Monaco's `IMouseTargetMarginData` details are not re-exposed
// (`target.gutter_offset_x` already carries the one detail a consumer needs).

///|
/// Monaco's `IEditorMouseEvent`, reduced (see the file header).
pub(all) struct EditorMouseEvent {
  target : @viewer_common.MouseTarget
  /// `event.leftButton`: for down/up, whether the left button produced the
  /// event; for moves, whether it is currently held (`buttons & 1`).
  left_button : Bool
} derive(Debug)

///|
/// Fires on editor mousedown with the hit-tested target — Monaco's
/// `onMouseDown`.
pub fn Viewer::on_mouse_down(
  self : Viewer,
  listener : (EditorMouseEvent) -> Unit,
) -> @base_common.Disposable {
  self.did_mouse_down.event(listener)
}

///|
/// Fires on editor mouseup with the hit-tested target — Monaco's
/// `onMouseUp`.
pub fn Viewer::on_mouse_up(
  self : Viewer,
  listener : (EditorMouseEvent) -> Unit,
) -> @base_common.Disposable {
  self.did_mouse_up.event(listener)
}

///|
/// Fires on editor mousemove with the hit-tested target — Monaco's
/// `onMouseMove`.
pub fn Viewer::on_mouse_move(
  self : Viewer,
  listener : (EditorMouseEvent) -> Unit,
) -> @base_common.Disposable {
  self.did_mouse_move.event(listener)
}

///|
/// Fires when the pointer leaves the editor — Monaco's `onMouseLeave`
/// (`IPartialEditorMouseEvent` reduced to the leave fact; its target is
/// always `null` for leaves the viewer produces).
pub fn Viewer::on_mouse_leave(
  self : Viewer,
  listener : (Unit) -> Unit,
) -> @base_common.Disposable {
  self.did_mouse_leave.event(listener)
}
