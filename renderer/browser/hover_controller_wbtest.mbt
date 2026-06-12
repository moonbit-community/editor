///|
test "stale hover results are dropped by version and token guards" {
  let notifications : Array[ViewerNotification] = []
  let notify = (notification : ViewerNotification) => {
    notifications.push(notification)
  }
  let controller = HoverController::empty()
  let hover : @language.Hover? = Some({
    range: Range(3, 7),
    contents: "fn main",
  })
  // Version moved on: result dropped, nothing reported.
  let stale_version = controller.resolved_hover(notify, 1, 0, hover, 2)
  assert_true(stale_version.view is None && stale_version.pending_view is None)
  assert_eq(notifications.length(), 0)
  // Anchor token moved on: result dropped.
  let rescheduled = { ..controller, token: 5 }
  let stale_token = rescheduled.resolved_hover(notify, 2, 4, hover, 2)
  assert_true(stale_token.view is None && stale_token.pending_view is None)
  // Current version and token: result lands behind the display gate and the
  // resolution fact is reported for the host to format.
  let fresh = rescheduled.resolved_hover(notify, 2, 5, hover, 2)
  assert_true(fresh.pending_view is Some(_))
  assert_true(notifications.length() == 1)
  assert_true(notifications[0] is ViewerHoverResolved(ok=true, version=2))
  let opened = { ..rescheduled, display_open: true }
  let shown = opened.resolved_hover(notify, 2, 5, hover, 2)
  assert_true(shown.view is Some(_))
}

///|
test "hover scheduling restarts timers only for new anchors" {
  let controller = HoverController::empty()
  let (effect, scheduled) = controller.schedule(3, 7)
  assert_true(effect is HoverSchedule(1))
  // The same anchor keeps the pending hover untouched.
  let (again, unchanged) = scheduled.schedule(3, 7)
  assert_true(again is HoverNoEffect)
  assert_eq(unchanged.token, scheduled.token)
  // A new anchor rotates the token, invalidating in-flight timers.
  let (rescheduled, moved) = scheduled.schedule(10, 14)
  assert_true(rescheduled is HoverSchedule(2))
  assert_eq(moved.token, 2)
  // The half-delay timer requests the provider only for the live token.
  let (request, _) = moved.fire(2)
  assert_true(request is HoverRequest(12, 2))
  let (stale, _) = moved.fire(1)
  assert_true(stale is HoverNoEffect)
}
