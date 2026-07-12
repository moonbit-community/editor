///|
fn async_test_model(path : String, text : String) -> @model.TextModel {
  TextModel(
    try! @base_common.Uri::from(
      scheme="inmemory",
      authority="async-model-features",
      path~,
    ),
    path,
    "moonbit",
    7,
    "shared-host-revision",
    text,
  )
}

///|
test "inlay request authority is physical model internal version generation and token" {
  let controller = InlayHintsController::attach("async-stamp-authority")
  let first = async_test_model("/same.mbt", "first")
  let replacement = async_test_model("/same.mbt", "replacement")

  let initial = controller.begin_request(first)
  assert_true(controller.accepts_request(initial, Some(first)))
  // Same URI, host version, and revision cannot substitute for physical
  // identity.
  assert_false(controller.accepts_request(initial, Some(replacement)))

  first.set_value("changed")
  assert_false(controller.accepts_request(initial, Some(first)))

  let disposed = async_test_model("/disposed.mbt", "disposed")
  let disposed_stamp = controller.begin_request(disposed)
  disposed.dispose()
  assert_false(controller.accepts_request(disposed_stamp, Some(disposed)))

  let current = controller.begin_request(first)
  assert_true(initial.token.is_cancellation_requested())
  assert_true(current.generation > initial.generation)
  assert_true(controller.accepts_request(current, Some(first)))
  assert_false(controller.accepts_request(current, None))

  controller.cancel_request()
  assert_true(current.token.is_cancellation_requested())
  assert_false(controller.accepts_request(current, Some(first)))
  InlayHintsController::detach("async-stamp-authority")
}

///|
test "inlay generations never reset across model-state reset" {
  let controller = InlayHintsController::attach("async-stamp-generation")
  let first = async_test_model("/first.mbt", "first")
  let second = async_test_model("/second.mbt", "second")
  let first_stamp = controller.begin_request(first)
  controller.reset_model_state()
  let second_stamp = controller.begin_request(second)
  assert_true(first_stamp.token.is_cancellation_requested())
  assert_true(second_stamp.generation > first_stamp.generation)
  assert_true(controller.accepts_request(second_stamp, Some(second)))
  controller.finish_request(second_stamp.generation)
  assert_false(second_stamp.token.is_cancellation_requested())
  InlayHintsController::detach("async-stamp-generation")
}

///|
fn deferred_hint(label : String) -> @language.InlayHint {
  InlayHint(Position(1, 1), label)
}

///|
test "newest inlay completion wins and stale empty cannot clear" {
  let services = ViewerServices::new(languages=@languages.Languages::new())
  let viewer = Viewer(services~)
  let model = async_test_model("/set-value.mbt", "old")
  viewer.set_model(Some(model))
  let controller = viewer.inlay_hints_controller().unwrap()
  let old = controller.begin_request(model)
  let newest = controller.begin_request(model)
  assert_true(old.token.is_cancellation_requested())
  viewer.commit_model_features(newest, [deferred_hint("newest")])
  assert_eq(viewer.current_inlay_hints()[0].label, "newest")
  viewer.commit_model_features(old, [])
  assert_eq(viewer.current_inlay_hints()[0].label, "newest")

  viewer.dispose()
  dispose_explicit_services(services)
}

///|
test "stale inlay can finish first before newest completion applies" {
  let services = ViewerServices::new(languages=@languages.Languages::new())
  let viewer = Viewer(services~)
  let model = async_test_model("/old-first.mbt", "old")
  viewer.set_model(Some(model))
  let controller = viewer.inlay_hints_controller().unwrap()
  let old = controller.begin_request(model)
  let newest = controller.begin_request(model)
  viewer.commit_model_features(old, [deferred_hint("old-first")])
  assert_true(viewer.current_inlay_hints().is_empty())
  viewer.commit_model_features(newest, [deferred_hint("newest-last")])
  assert_eq(viewer.current_inlay_hints()[0].label, "newest-last")
  viewer.dispose()
  dispose_explicit_services(services)
}

///|
test "same URI replacement and detach reject old inlay completions" {
  let services = ViewerServices::new(languages=@languages.Languages::new())
  let viewer = Viewer(services~)
  let first = async_test_model("/replacement.mbt", "first")
  let replacement = async_test_model("/replacement.mbt", "replacement")
  viewer.set_model(Some(first))
  let controller = viewer.inlay_hints_controller().unwrap()
  let old = controller.begin_request(first)
  viewer.set_model(Some(replacement))
  assert_true(old.token.is_cancellation_requested())
  let current = controller.begin_request(replacement)
  viewer.commit_model_features(current, [deferred_hint("replacement")])
  viewer.commit_model_features(old, [deferred_hint("stale")])
  assert_eq(viewer.current_inlay_hints()[0].label, "replacement")

  let pending_detach = controller.begin_request(replacement)
  viewer.set_model(None)
  assert_true(pending_detach.token.is_cancellation_requested())
  viewer.commit_model_features(pending_detach, [deferred_hint("detached-stale")])
  match viewer.inlay_hints_controller() {
    Some(controller) => assert_true(controller.inlay_hints.is_empty())
    None => fail("controller should live until Viewer disposal")
  }

  viewer.dispose()
  dispose_explicit_services(services)
}

///|
fn async_hover_anchor() -> @hover.HoverAnchor {
  HoverRangeAnchor(
    priority=0,
    range=Range(1, 1, 1, 1),
    initial_mouse_pos_x=None,
    initial_mouse_pos_y=None,
  )
}

///|
fn async_hover_mouse_target() -> @editor_browser.MouseTarget {
  MouseTargetContentText(
    element=None,
    mouse_column=1,
    position=Position(1, 1),
    range=Range(1, 1, 1, 1),
    detail={ might_be_foreign_element: false, injected_text: None },
  )
}

///|
struct ManualHoverTimeout {
  due_ms : Int
  callback : () -> Unit
  mut active : Bool
}

///|
struct ManualHoverScheduler {
  mut now_ms : Int
  tasks : Array[ManualHoverTimeout]
}

///|
fn ManualHoverScheduler::new() -> ManualHoverScheduler {
  { now_ms: 0, tasks: [] }
}

///|
fn ManualHoverScheduler::schedule(
  self : ManualHoverScheduler,
  callback : () -> Unit,
  delay_ms : Int,
) -> @base_common.Disposable {
  let task : ManualHoverTimeout = {
    due_ms: self.now_ms + delay_ms,
    callback,
    active: true,
  }
  self.tasks.push(task)
  @base_common.Disposable::from(() => task.active = false)
}

///|
fn ManualHoverScheduler::next_due_index(
  self : ManualHoverScheduler,
  target_ms : Int,
) -> Int? {
  let mut result : Int? = None
  let mut earliest = target_ms + 1
  for index, task in self.tasks {
    if task.active && task.due_ms <= target_ms && task.due_ms < earliest {
      result = Some(index)
      earliest = task.due_ms
    }
  }
  result
}

///|
fn ManualHoverScheduler::advance_to(
  self : ManualHoverScheduler,
  target_ms : Int,
) -> Unit {
  match self.next_due_index(target_ms) {
    Some(index) => {
      let task = self.tasks[index]
      self.now_ms = task.due_ms
      task.active = false
      (task.callback)()
      self.advance_to(target_ms)
    }
    None => self.now_ms = target_ms
  }
}

///|
fn ManualHoverScheduler::active_count(self : ManualHoverScheduler) -> Int {
  let mut count = 0
  for task in self.tasks {
    if task.active {
      count += 1
    }
  }
  count
}

///|
fn arm_manual_hover(viewer : Viewer) -> Unit {
  let hc = viewer.content_hover_controller().unwrap()
  let (effect, hover) = hc.hover.start_showing_or_update_hover(
    async_hover_anchor(),
    false,
  )
  hc.hover = hover
  viewer.apply_hover_effect(effect)
}

///|
test "live hover timers follow 150 300 900ms and cancel stale generations" {
  let services = ViewerServices::new(languages=@languages.Languages::new())
  let viewer = Viewer(services~)
  let model = async_test_model("/hover-timers.mbt", "hover")
  let scheduler = ManualHoverScheduler::new()
  viewer.set_hover_host_for_test(
    (callback, delay_ms) => scheduler.schedule(callback, delay_ms),
    _ => (),
  )
  viewer.set_model(Some(model))
  let hc = viewer.content_hover_controller().unwrap()

  // A superseded operation clears both host handles and invalidates all three
  // latest-options debouncers before a new generation is armed.
  arm_manual_hover(viewer)
  assert_true(hc.hover.operation.state is HoverOpFirstWait)
  assert_eq(scheduler.active_count(), 2)
  viewer.dismiss_hover()
  assert_eq(scheduler.active_count(), 0)

  arm_manual_hover(viewer)
  assert_true(hc.hover.operation.state is HoverOpFirstWait)
  scheduler.advance_to(149)
  assert_true(hc.hover.operation.state is HoverOpFirstWait)
  scheduler.advance_to(150)
  assert_true(hc.hover.operation.state is HoverOpSecondWait)
  // The async trigger arms the second half relative to logical 150ms.
  scheduler.advance_to(299)
  assert_true(hc.hover.operation.state is HoverOpSecondWait)
  scheduler.advance_to(300)
  assert_true(hc.hover.operation.state is HoverOpWaitingForAsync)
  scheduler.advance_to(899)
  assert_true(hc.hover.operation.state is HoverOpWaitingForAsync)
  scheduler.advance_to(900)
  assert_true(hc.hover.operation.state is HoverOpWaitingForAsyncShowingLoading)
  assert_eq(scheduler.active_count(), 0)

  viewer.dispose()
  dispose_explicit_services(services)
}

///|
test "content and model invalidation clear a pending mouse-react handle" {
  let services = ViewerServices::new(languages=@languages.Languages::new())
  let viewer = Viewer(services~)
  let first = async_test_model("/hover-react-first.mbt", "hover")
  let replacement = async_test_model("/hover-react-second.mbt", "hover")
  let scheduler = ManualHoverScheduler::new()
  viewer.set_hover_host_for_test(
    (callback, delay_ms) => scheduler.schedule(callback, delay_ms),
    _ => (),
  )
  viewer.set_model(Some(first))
  let hc = viewer.content_hover_controller().unwrap()

  hc.hover = shown_hover_controller()
  viewer.sync_content_hover_widget()
  viewer.on_editor_mouse_move(async_hover_mouse_target())
  assert_true(hc.hover_react_pending)
  assert_eq(scheduler.active_count(), 1)
  viewer.set_value("content changed")
  assert_false(hc.hover_react_pending)
  assert_eq(scheduler.active_count(), 0)

  hc.hover = shown_hover_controller()
  viewer.sync_content_hover_widget()
  viewer.on_editor_mouse_move(async_hover_mouse_target())
  assert_true(hc.hover_react_pending)
  assert_eq(scheduler.active_count(), 1)
  viewer.set_model(Some(replacement))
  assert_false(hc.hover_react_pending)
  assert_eq(scheduler.active_count(), 0)

  viewer.dispose()
  dispose_explicit_services(services)
}

///|
test "hover widget mouseleave hides when the editor DOM is missing" {
  let services = ViewerServices::new(languages=@languages.Languages::new())
  let viewer = Viewer(services~)
  viewer.set_model(Some(async_test_model("/hover-no-dom.mbt", "hover")))
  let hc = viewer.content_hover_controller().unwrap()
  hc.hover = shown_hover_controller()
  viewer.sync_content_hover_widget()
  assert_true(viewer.content_hover_visible())
  assert_true(viewer.get_view() is None)

  viewer.on_content_hover_widget_mouse_leave(0.0, 0.0)

  assert_true(hc.hover.view is None)
  assert_false(viewer.content_hover_visible())
  viewer.dispose()
  dispose_explicit_services(services)
}

///|
test "programmatic hover forwards immediate mode source focus and mouse state" {
  let services = ViewerServices::new(languages=@languages.Languages::new())
  let viewer = Viewer(services~)
  viewer.set_model(Some(async_test_model("/programmatic-hover.mbt", "hover")))
  viewer.set_hover_host_for_test(
    (_callback, _delay_ms) => @base_common.Disposable::from(() => ()),
    _ => (),
  )
  let hc = viewer.content_hover_controller().unwrap()
  assert_false(hc.hover_is_mouse_down)
  assert_false(hc.hover_ignore_mouse_events)
  assert_true(hc.hover_settings.enabled is HoverEnabledOn)
  assert_true(hc.hover_settings.sticky)
  assert_eq(hc.hover_settings.hiding_delay, 300)
  viewer.start_showing_hover_at_range(
    Range(1, 1, 1, 2),
    HoverStartImmediate,
    HoverStartKeyboard,
    true,
  )
  match hc.hover.operation.options {
    Some(options) => {
      assert_true(options.source is HoverStartKeyboard)
      assert_true(options.should_focus)
      assert_eq(options.anchor.priority(), 0)
    }
    None => fail("expected forwarded hover options")
  }
  assert_true(hc.hover.operation.state is HoverOpWaitingForAsync)

  viewer.on_editor_mouse_down(0.0, 0.0)
  assert_true(hc.hover_is_mouse_down)
  viewer.on_editor_mouse_up()
  assert_false(hc.hover_is_mouse_down)
  hc.hover_ignore_mouse_events = true
  viewer.on_editor_mouse_down(0.0, 0.0)
  assert_false(hc.hover_is_mouse_down)
  viewer.on_editor_mouse_up()
  assert_false(hc.hover_is_mouse_down)

  viewer.dispose()
  dispose_explicit_services(services)
}

///|
fn hover_scroll_change(
  left_changed : Bool,
  top_changed : Bool,
) -> @view_layout.ScrollChange {
  let before = @view_layout.ScrollState::new(
    force_integer_values=false,
    100.0,
    500.0,
    0.0,
    100.0,
    500.0,
    0.0,
  )
  let after = @view_layout.ScrollState::new(
    force_integer_values=false,
    100.0,
    500.0,
    if left_changed {
      1.0
    } else {
      0.0
    },
    100.0,
    500.0,
    if top_changed {
      1.0
    } else {
      0.0
    },
  )
  after.create_scroll_event(before, false)
}

///|
test "hover scroll handling covers neither top left both and ignored input" {
  let services = ViewerServices::new(languages=@languages.Languages::new())
  let viewer = Viewer(services~)
  viewer.set_model(Some(async_test_model("/hover-scroll.mbt", "hover")))
  let hc = viewer.content_hover_controller().unwrap()

  for
    case in [
      (false, false, false),
      (false, true, true),
      (true, false, true),
      (true, true, true),
    ] {
    let (left_changed, top_changed, should_hide) = case
    hc.hover = shown_hover_controller()
    viewer.on_editor_scroll_changed(
      hover_scroll_change(left_changed, top_changed),
    )
    assert_eq(hc.hover.view is None, should_hide)
  }

  hc.hover = shown_hover_controller()
  hc.hover_ignore_mouse_events = true
  viewer.on_editor_scroll_changed(hover_scroll_change(true, true))
  assert_true(hc.hover.view is Some(_))
  hc.hover_ignore_mouse_events = false

  viewer.dispose()
  dispose_explicit_services(services)
}

///|
fn shown_hover_controller() -> @hover.HoverController {
  let (_, started) = @hover.HoverController::empty().start_showing_or_update_hover(
    async_hover_anchor(),
    false,
  )
  let token = started.operation.token
  let (_, after_async_trigger) = started.op_trigger_async(token)
  let after_sync = after_async_trigger.op_trigger_sync(token, [
    MarkdownHover(
      range=Range(1, 1, 1, 1),
      contents=[PlainText("shown")],
      ordinal=100,
    ),
  ])
  after_sync.op_async_done(token)
}

///|
test "invisible hover dismissal cancels work idempotently" {
  let services = ViewerServices::new(languages=@languages.Languages::new())
  let viewer = Viewer(services~)
  viewer.set_model(
    Some(async_test_model("/hover-invisible-dismiss.mbt", "hover")),
  )
  let hc = viewer.content_hover_controller().unwrap()
  let (_, pending) = hc.hover.start_showing_or_update_hover(
    async_hover_anchor(),
    false,
  )
  hc.hover = pending
  let request = new_feature_cancellation_source()
  hc.begin_request(request, pending.operation.token)
  let token_before = pending.operation.token
  viewer.hide_content_hover()

  assert_true(request.token().is_cancellation_requested())
  assert_true(hc.hover.operation.token > token_before)
  assert_true(hc.hover.operation.state is HoverOpIdle)
  assert_true(hc.hover.view is None)

  // Cancellation remains unconditional even when the controller is already
  // invisible; only its absence of render/DOM input is idempotent.
  let first_clear_token = hc.hover.operation.token
  viewer.hide_content_hover()
  assert_true(hc.hover.operation.token > first_clear_token)

  viewer.dispose()
  dispose_explicit_services(services)
}

///|
test "visible hover dismissal clears the shown view" {
  let services = ViewerServices::new(languages=@languages.Languages::new())
  let viewer = Viewer(services~)
  viewer.set_model(
    Some(async_test_model("/hover-visible-dismiss.mbt", "hover")),
  )
  let hc = viewer.content_hover_controller().unwrap()
  hc.hover = shown_hover_controller()
  let token_before = hc.hover.operation.token
  viewer.hide_content_hover()

  assert_true(hc.hover.operation.token > token_before)
  assert_true(hc.hover.view is None)

  viewer.dispose()
  dispose_explicit_services(services)
}

///|
test "content invalidation cancels hover request but preserves shown view" {
  let services = ViewerServices::new(languages=@languages.Languages::new())
  let viewer = Viewer(services~)
  let model = async_test_model("/hover-content.mbt", "content")
  viewer.set_model(Some(model))
  let hc = viewer.content_hover_controller().unwrap()
  hc.hover = shown_hover_controller()
  let before = hc.hover
  let source = new_feature_cancellation_source()
  hc.begin_request(source, before.operation.token)

  viewer.set_value("changed")

  assert_true(source.token().is_cancellation_requested())
  assert_true(hc.hover.operation.token > before.operation.token)
  assert_true(hc.hover.view == before.view)
  assert_true(hc.hover.anchor is None)
  assert_true(hc.hover_decoration_ids.is_empty())
  assert_true(hc.hover_decoration_range is None)
  viewer.dispose()
  dispose_explicit_services(services)
}

///|
test "content invalidation removes loading visibility and permits same-anchor restart" {
  let services = ViewerServices::new(languages=@languages.Languages::new())
  let viewer = Viewer(services~)
  let model = async_test_model("/hover-loading-content.mbt", "content")
  viewer.set_model(Some(model))
  let hc = viewer.content_hover_controller().unwrap()
  let anchor = async_hover_anchor()
  let (_, armed) = hc.hover.start_showing_or_update_hover(anchor, false)
  let token = armed.operation.token
  let (_, second_wait) = armed.op_trigger_async(token)
  hc.hover = second_wait.op_trigger_sync(token, []).op_trigger_loading(token)
  assert_true(hc.hover.view is None)
  viewer.sync_content_hover_widget()
  assert_true(viewer.content_hover_visible())

  viewer.set_value("changed")

  assert_true(hc.hover.view is None)
  assert_true(hc.hover.current_anchor is None)
  assert_false(viewer.content_hover_visible())
  let (effect, restarted) = hc.hover.start_showing_or_update_hover(
    anchor,
    false,
    live_widget_visible=viewer.content_hover_visible(),
  )
  assert_true(effect is HoverScheduleDelayed(_))
  assert_true(restarted.anchor == Some(anchor))
  viewer.dispose()
  dispose_explicit_services(services)
}

///|
test "hover request stamp rejects version identity generation and token drift" {
  let first = async_test_model("/hover-same.mbt", "first")
  let replacement = async_test_model("/hover-same.mbt", "replacement")
  let hover = shown_hover_controller()
  let source = @language.CancellationTokenSource::new()
  let request = hover.request_stamp(first, source.token())
  assert_true(request.is_current(Some(first), hover.operation.token))
  assert_false(request.is_current(Some(replacement), hover.operation.token))
  assert_false(request.is_current(Some(first), hover.operation.token + 1))
  first.set_value("changed")
  assert_false(request.is_current(Some(first), hover.operation.token))

  let fresh = hover.request_stamp(first, source.token())
  source.cancel()
  assert_false(fresh.is_current(Some(first), hover.operation.token))
}

///|
test "inlay hover owner is stable per Viewer and distinct across Viewers" {
  let first = @hover_browser.ContentHoverController::attach(
    "async-hover-owner-first",
  )
  let second = @hover_browser.ContentHoverController::attach(
    "async-hover-owner-second",
  )
  assert_true(first.inlay_hover_owner == first.inlay_hover_owner)
  assert_false(first.inlay_hover_owner == second.inlay_hover_owner)
  @hover_browser.ContentHoverController::detach("async-hover-owner-first")
  @hover_browser.ContentHoverController::detach("async-hover-owner-second")
}
