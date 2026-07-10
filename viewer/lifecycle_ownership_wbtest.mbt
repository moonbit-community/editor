///|
/// Pushes one stable diagnostic before attachment so lifecycle tests can
/// distinguish MarkerService data from the derived per-model decorations.
fn seed_lifecycle_marker(
  services : ViewerServices,
  model : @model.TextModel,
) -> Unit {
  services.markers.change_one("lifecycle-owner", model.uri, [
    @markers.MarkerData::new(
      severity=Error,
      message="preloaded",
      start_line_number=1,
      start_column=1,
      end_line_number=1,
      end_column=2,
    ),
  ])
}

///|
fn dispose_explicit_services(services : ViewerServices) -> Unit {
  services.marker_decorations.dispose()
  services.markers.dispose()
  services.agent_feedback.dispose()
}

///|
test "preloaded markers survive detach and seed again on reattach" {
  let services = ViewerServices::new()
  let viewer = Viewer::Viewer(services~)
  let model = test_model("alpha")
  seed_lifecycle_marker(services, model)
  viewer.set_model(Some(model))
  assert_eq(model.get_all_decorations().length(), 1)
  assert_true(viewer.decorations_generation > 0)
  viewer.set_model(None)
  assert_eq(model.get_all_decorations().length(), 0)
  assert_eq(services.markers.diagnostics_for_resource(model.uri).length(), 1)
  viewer.set_model(Some(model))
  assert_eq(model.get_all_decorations().length(), 1)
  viewer.dispose()
  assert_false(model.is_disposed())
  model.dispose()
  dispose_explicit_services(services)
}

///|
test "set_value refresh does not acquire another shared-model lease" {
  let services = ViewerServices::new()
  let first = Viewer::Viewer(services~)
  let second = Viewer::Viewer(services~)
  let model = test_model("alpha")
  seed_lifecycle_marker(services, model)
  first.set_model(Some(model))
  second.set_model(Some(model))
  assert_eq(model.get_all_decorations().length(), 1)
  first.set_value("beta")
  assert_eq(model.get_all_decorations().length(), 1)
  first.dispose()
  assert_eq(model.get_all_decorations().length(), 1)
  second.dispose()
  assert_eq(model.get_all_decorations().length(), 0)
  assert_eq(services.markers.diagnostics_for_resource(model.uri).length(), 1)
  model.dispose()
  dispose_explicit_services(services)
}

///|
test "distinct same-URI models retain independent decoration owners" {
  let services = ViewerServices::new()
  let first_viewer = Viewer::Viewer(services~)
  let second_viewer = Viewer::Viewer(services~)
  let first_model = test_model("first")
  let second_model = test_model("second")
  assert_true(first_model.uri.to_string() == second_model.uri.to_string())
  assert_true(first_model.instance_id != second_model.instance_id)
  seed_lifecycle_marker(services, first_model)
  first_viewer.set_model(Some(first_model))
  second_viewer.set_model(Some(second_model))
  assert_eq(first_model.get_all_decorations().length(), 1)
  assert_eq(second_model.get_all_decorations().length(), 1)
  first_viewer.dispose()
  assert_eq(first_model.get_all_decorations().length(), 0)
  assert_eq(second_model.get_all_decorations().length(), 1)
  second_viewer.dispose()
  assert_eq(second_model.get_all_decorations().length(), 0)
  first_model.dispose()
  second_model.dispose()
  dispose_explicit_services(services)
}

///|
test "model disposal detaches two Viewers sharing one registration" {
  let services = ViewerServices::new()
  let first = Viewer::Viewer(services~)
  let second = Viewer::Viewer(services~)
  let model = test_model("alpha")
  seed_lifecycle_marker(services, model)
  first.set_model(Some(model))
  second.set_model(Some(model))
  model.dispose()
  assert_true(first.get_model() is None)
  assert_true(second.get_model() is None)
  assert_eq(model.get_all_decorations().length(), 0)
  first.dispose()
  second.dispose()
  dispose_explicit_services(services)
}

///|
test "explicit services stay borrowed after Viewer disposal" {
  let services = ViewerServices::new()
  let viewer = Viewer::Viewer(services~)
  assert_false(viewer.owns_services)
  viewer.dispose()
  let model = test_model("alpha")
  seed_lifecycle_marker(services, model)
  let lease = services.marker_decorations.acquire_model(model)
  assert_eq(model.get_all_decorations().length(), 1)
  lease.dispose()
  model.dispose()
  dispose_explicit_services(services)
}

///|
test "omitted services are owned and Viewer disposal is idempotent" {
  let viewer = Viewer::Viewer()
  let services = viewer.services
  let model = test_model("alpha")
  seed_lifecycle_marker(services, model)
  viewer.set_model(Some(model))
  let mut dispose_events = 0
  let contribution_alive_in_event = Ref(false)
  let lifetime_store_alive_in_event = Ref(false)
  let model_detached_in_event = Ref(false)
  viewer.on_did_dispose(() => {
    dispose_events += 1
    contribution_alive_in_event.val = viewer.get_contribution(
        "editor.contrib.contentHover",
      )
      is Some(_)
    lifetime_store_alive_in_event.val = !viewer.lifetime_disposables.is_empty()
    model_detached_in_event.val = viewer.get_model() is None
  })
  |> ignore
  viewer.dispose()
  viewer.dispose()
  assert_true(viewer.owns_services)
  assert_true(viewer.disposed)
  assert_eq(dispose_events, 1)
  assert_true(contribution_alive_in_event.val)
  assert_true(lifetime_store_alive_in_event.val)
  assert_true(model_detached_in_event.val)
  assert_eq(viewer.lifetime_disposables.length(), 0)
  assert_true(viewer.render_frame is None)
  assert_true(viewer.container is None)
  assert_true(viewer.placeholder_element is None)
  assert_false(model.is_disposed())
  let later_model = test_model("later")
  let late_lease = services.marker_decorations.acquire_model(later_model)
  assert_eq(later_model.get_all_decorations().length(), 0)
  late_lease.dispose()
  model.dispose()
  later_model.dispose()
}

///|
test "disposed headless Viewer ignores later model and callback work" {
  let services = ViewerServices::new()
  let viewer = Viewer::Viewer(services~)
  let model = test_model("alpha")
  viewer.set_model(Some(model))
  let mut content_events = 0
  viewer.on_did_change_model_content(_ => content_events += 1) |> ignore
  viewer.dispose()
  model.set_value("beta")
  // The Viewer-level font subscription is both released and guarded. A
  // source emission after disposal must not mark layout work pending.
  @browser_config.font_measurements().clear_all_font_infos()
  viewer.set_model(Some(model))
  viewer.schedule_render()
  assert_eq(content_events, 0)
  assert_false(viewer.measure_requested)
  assert_true(viewer.get_model() is None)
  assert_true(viewer.render_frame is None)
  model.dispose()
  dispose_explicit_services(services)
}
