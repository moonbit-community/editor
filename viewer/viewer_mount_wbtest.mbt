///|
test "ViewerMount represents all headless and mounted model shapes" {
  let headless = Viewer::Viewer()
  let headless_model = test_model("headless")
  assert_true(headless.mount is Headless)
  assert_true(headless.get_model() is None)
  assert_true(headless.get_view() is None)
  assert_false(headless.mount.has_pending_render())
  headless.set_model(Some(headless_model))
  assert_true(headless.mount is Headless)
  assert_true(headless.get_model() is Some(_))
  assert_true(headless.current_browser_data() is None)
  assert_false(headless.mount.has_pending_render())
  headless.dispose()
  headless_model.dispose()

  install_mounted_test_browser()
  defer restore_mounted_test_browser()
  let mounted = Viewer::Viewer()
  defer mounted.dispose()
  let mounted_model = test_model("mounted")
  defer mounted_model.dispose()
  let host = @rdom.document().create_element("div")
  mounted.attach(host)
  assert_true(mounted.mount is Mounted(_))
  assert_true(mounted.get_model() is None)
  assert_true(mounted.get_view() is None)
  guard mounted.mount is Mounted(mounted_state) else {
    fail("attached Viewer did not publish Mounted state")
  }
  guard mounted_state.placeholder is Some(placeholder) else {
    fail("mounted no-model Viewer lost its placeholder pair")
  }
  assert_true(
    @base_browser.element_contains(mounted_state.container, placeholder.root),
  )
  mounted.set_model(Some(mounted_model))
  assert_true(mounted.mount is Mounted(_))
  assert_true(mounted.get_model() is Some(_))
  assert_true(mounted.current_browser_data() is Some(_))
  assert_false(
    @base_browser.element_contains(mounted_state.container, placeholder.root),
  )
}

///|
test "mount keeps one host and one placeholder pair across detach" {
  install_mounted_test_browser()
  defer restore_mounted_test_browser()
  let viewer = Viewer::Viewer()
  defer viewer.dispose()
  let first = test_model("first")
  defer first.dispose()
  let second = test_model("second")
  defer second.dispose()
  let host = @rdom.document().create_element("div")
  let ignored_host = @rdom.document().create_element("div")
  viewer.attach(host)
  viewer.attach(ignored_host)
  assert_true(same_mounted_test_element(viewer.get_container_dom_node(), host))
  assert_eq(mounted_test_child_count(host), 1)
  assert_eq(mounted_test_child_count(ignored_host), 0)
  guard viewer.mount is Mounted(mounted) else {
    fail("attached Viewer did not publish Mounted state")
  }
  guard mounted.placeholder is Some(placeholder) else {
    fail("attached Viewer did not publish a complete placeholder")
  }
  let placeholder_root = placeholder.root
  let placeholder_text = placeholder.text

  // Attach owns exactly one coalesced no-model frame. Theme propagation is
  // synchronous; placeholder text is painted by that frame.
  viewer.layout()
  viewer.layout()
  assert_true(mounted.has_pending_render())
  assert_eq(mounted_test_frame_count(), 1)
  viewer.update_options(
    viewer
    .get_options()
    .with_theme("mount-test-theme")
    .with_placeholder("no model"),
  )
  assert_eq(placeholder_root.get_attribute("data-theme"), "mount-test-theme")
  flush_mounted_test_frames()
  assert_false(mounted.has_pending_render())
  assert_eq(mounted_test_node_value(placeholder_text), "no model")

  viewer.set_model(Some(first))
  assert_eq(mounted_test_child_count(host), 1)
  assert_false(@base_browser.element_contains(host, placeholder_root))
  guard mounted.placeholder is Some(installed_pair) else {
    fail("model attach discarded the retained placeholder pair")
  }
  assert_true(
    same_mounted_test_element(installed_pair.root, placeholder_root) &&
    same_mounted_test_element(installed_pair.text, placeholder_text),
  )

  viewer.focus()
  assert_true(viewer.has_text_focus())
  viewer.set_model(Some(second))
  assert_true(viewer.has_text_focus())
  assert_true(viewer.get_model().unwrap().same(second))
  assert_eq(mounted_test_child_count(host), 1)
  assert_false(@base_browser.element_contains(host, placeholder_root))
  let focus_seen_in_model_event = Ref(true)
  let subscription = viewer.on_did_change_model(_ => {
    focus_seen_in_model_event.val = viewer.has_text_focus()
  })
  viewer.set_model(None)
  assert_false(focus_seen_in_model_event.val)
  assert_false(viewer.has_text_focus())
  assert_eq(mounted_test_child_count(host), 1)
  assert_true(@base_browser.element_contains(host, placeholder_root))
  guard mounted.placeholder is Some(restored_pair) else {
    fail("ordinary detach did not retain the placeholder pair")
  }
  assert_true(
    same_mounted_test_element(restored_pair.root, placeholder_root) &&
    same_mounted_test_element(restored_pair.text, placeholder_text),
  )
  assert_eq(restored_pair.root.get_attribute("data-theme"), "mount-test-theme")
  subscription.dispose()
}

///|
test "mounted scheduler clears publication before a reentrant schedule" {
  install_mounted_test_browser()
  defer restore_mounted_test_browser()
  let viewer = Viewer::Viewer()
  defer viewer.dispose()
  let host = @rdom.document().create_element("div")
  viewer.attach(host)
  flush_mounted_test_frames()
  guard viewer.mount is Mounted(mounted) else {
    fail("attached Viewer did not publish Mounted state")
  }
  let calls = Ref(0)
  let slot_was_clear = Ref(true)
  mounted.schedule_render(() => {
    slot_was_clear.val = slot_was_clear.val && !mounted.has_pending_render()
    calls.val += 1
    mounted.schedule_render(() => {
      slot_was_clear.val = slot_was_clear.val && !mounted.has_pending_render()
      calls.val += 1
    })
  })
  assert_true(mounted.has_pending_render())
  assert_eq(mounted_test_frame_count(), 1)
  flush_mounted_test_frames()
  assert_eq(calls.val, 2)
  assert_true(slot_was_clear.val)
  assert_false(mounted.has_pending_render())
}

///|
test "dispose retains mount and host until and after the dispose event" {
  install_mounted_test_browser()
  defer restore_mounted_test_browser()
  let viewer = Viewer::Viewer()
  let model = test_model("focused")
  let host = @rdom.document().create_element("div")
  let ignored_after_dispose = @rdom.document().create_element("div")
  viewer.attach(host)
  viewer.set_model(Some(model))
  viewer.focus()
  assert_true(viewer.has_text_focus())
  let event_saw_mounted_host = Ref(false)
  let event_saw_placeholder_pair = Ref(false)
  let event_saw_focus = Ref(false)
  let event_saw_cleared_frame = Ref(false)
  viewer.on_did_dispose(() => {
    match viewer.mount {
      Headless => ()
      Mounted(mounted) => {
        event_saw_mounted_host.val = same_mounted_test_element(
          mounted.container,
          host,
        )
        event_saw_placeholder_pair.val = mounted.placeholder is Some(_)
        event_saw_focus.val = mounted.editor_has_focus
        event_saw_cleared_frame.val = !mounted.has_pending_render()
      }
    }
  })
  |> ignore

  viewer.dispose()
  assert_true(event_saw_mounted_host.val)
  assert_true(event_saw_placeholder_pair.val)
  assert_true(event_saw_focus.val)
  assert_true(event_saw_cleared_frame.val)
  guard viewer.mount is Mounted(disposed_mount) else {
    fail("disposed mounted Viewer transitioned back to Headless")
  }
  assert_true(same_mounted_test_element(disposed_mount.container, host))
  assert_true(disposed_mount.placeholder is None)
  assert_false(disposed_mount.has_pending_render())
  assert_false(disposed_mount.editor_has_focus)
  assert_eq(mounted_test_child_count(host), 0)
  assert_true(same_mounted_test_element(viewer.get_container_dom_node(), host))

  // Both the ordinary second attach and attach-after-dispose are ignored;
  // the original caller host remains the only retained container.
  viewer.attach(ignored_after_dispose)
  assert_true(same_mounted_test_element(viewer.get_container_dom_node(), host))
  assert_eq(mounted_test_child_count(ignored_after_dispose), 0)
  assert_false(model.is_disposed())
  model.dispose()
}
