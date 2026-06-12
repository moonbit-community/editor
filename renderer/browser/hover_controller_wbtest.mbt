///|
test "stale hover results are dropped by version and token guards" {
  let notifications : Array[ViewerNotification] = []
  let notify = (notification : ViewerNotification) => {
    notifications.push(notification)
  }
  let (emit, _cell) = @rabbita.cell_with_emit(
    model=(),
    update=(_, _ : ViewerMsg, model) => (@rabbita.none, model),
    view=(_, _) => @html.div(""),
  )
  let controller = HoverController::empty()
  let hover : @language.Hover? = Some({
    range: Range(3, 7),
    contents: "fn main",
  })
  // Version moved on: result dropped, nothing reported.
  let (_, stale_version) = controller.resolved_hover(
    notify, emit, 1, 0, hover, 2,
  )
  assert_true(stale_version.view is None && stale_version.pending_view is None)
  assert_eq(notifications.length(), 0)
  // Anchor token moved on: result dropped.
  let rescheduled = { ..controller, token: 5 }
  let (_, stale_token) = rescheduled.resolved_hover(
    notify, emit, 2, 4, hover, 2,
  )
  assert_true(stale_token.view is None && stale_token.pending_view is None)
  // Current version and token: result lands behind the display gate and the
  // resolution fact is reported for the host to format.
  let (_, fresh) = rescheduled.resolved_hover(notify, emit, 2, 5, hover, 2)
  assert_true(fresh.pending_view is Some(_))
  assert_true(notifications.length() == 1)
  assert_true(notifications[0] is ViewerHoverResolved(ok=true, version=2))
  let opened = { ..rescheduled, display_open: true }
  let (_, shown) = opened.resolved_hover(notify, emit, 2, 5, hover, 2)
  assert_true(shown.view is Some(_))
}
