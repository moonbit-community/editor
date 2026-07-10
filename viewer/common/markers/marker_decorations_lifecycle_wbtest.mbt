///|
fn lifecycle_uri(scheme : String, path : String) -> @base_common.Uri {
  try! @base_common.Uri::from(scheme~, authority="model", path~)
}

///|
fn lifecycle_model(
  uri : @base_common.Uri,
  name : String,
  text : String,
) -> @model.TextModel {
  TextModel(uri, name, "moonbit", 1, "rev", text)
}

///|
fn lifecycle_marker(
  message : String,
  start_column? : Int = 1,
  end_column? : Int = 2,
) -> MarkerData {
  MarkerData::new(
    severity=Error,
    message~,
    start_line_number=1,
    start_column~,
    end_line_number=1,
    end_column~,
  )
}

///|
test "preloaded markers seed once and same-identity leases refcount" {
  let markers = MarkerService::new()
  let uri = lifecycle_uri("inmemory", "/preload.mbt")
  markers.change_one("host", uri, [lifecycle_marker("preloaded")])
  let service = MarkerDecorationsService::new(markers)
  let model = lifecycle_model(uri, "preload.mbt", "alpha")
  let changed : Array[String] = []
  let changed_subscription = service.on_did_change_marker_decorations(m => {
    changed.push(m.instance_id)
  })

  let first = service.acquire_model(model)
  assert_eq(model.get_all_decorations().length(), 1)
  assert_true(changed == [model.instance_id])
  let second = service.acquire_model(model)
  assert_eq(service.model_registrations.length(), 1)
  assert_eq(
    service.model_registrations.get(model.instance_id).unwrap().ref_count,
    2,
  )
  assert_true(
    service.model_ids_by_uri.get(uri.to_string()).unwrap() ==
    [model.instance_id],
  )
  assert_eq(changed.length(), 1)

  // Release the later lease first (the root Viewer integration covers the
  // opposite order); either handle independently decrements once.
  second.dispose()
  second.dispose()
  assert_eq(
    service.model_registrations.get(model.instance_id).unwrap().ref_count,
    1,
  )
  assert_eq(model.get_all_decorations().length(), 1)
  first.dispose()
  assert_eq(service.model_registrations.length(), 0)
  assert_eq(service.model_ids_by_uri.length(), 0)
  assert_eq(model.get_all_decorations().length(), 0)
  // Ordinary release never owns the host's diagnostics, even for a transient
  // URI. A later lease for the still-live identity re-seeds the same host data
  // in a fresh owner, without any historical watch or ordering entry.
  assert_eq(markers.read(MarkerReadOptions::new(resource=uri)).length(), 1)
  let reattached = service.acquire_model(model)
  assert_eq(model.get_all_decorations().length(), 1)
  assert_eq(service.model_registrations.length(), 1)
  reattached.dispose()
  assert_eq(model.get_all_decorations().length(), 0)
  // The final release removed the new model-dispose watch too, so later host
  // disposal is unseen and cannot run transient cleanup.
  model.dispose()
  assert_eq(markers.read(MarkerReadOptions::new(resource=uri)).length(), 1)
  changed_subscription.dispose()
  service.dispose()
}

///|
test "same-URI identities fan out and URI lookups preserve acquisition order" {
  let markers = MarkerService::new()
  let uri = lifecycle_uri("file", "/same-uri.mbt")
  markers.change_one("host", uri, [
    lifecycle_marker("first", start_column=3, end_column=3),
  ])
  let service = MarkerDecorationsService::new(markers)
  let model_a = lifecycle_model(uri, "a.mbt", "alpha")
  let model_b = lifecycle_model(uri, "b.mbt", "x yz")
  let events : Array[String] = []
  let event_subscription = service.on_did_change_marker_decorations(model => {
    events.push(model.instance_id)
  })
  let a_first = service.acquire_model(model_a)
  let b = service.acquire_model(model_b)
  let a_second = service.acquire_model(model_a)

  assert_eq(service.model_registrations.length(), 2)
  assert_true(
    service.model_ids_by_uri.get(uri.to_string()).unwrap() ==
    [model_a.instance_id, model_b.instance_id],
  )
  let union = service.get_live_markers(uri)
  assert_eq(union.length(), 2)
  assert_true(union[0].0 == Range(1, 1, 1, 6))
  assert_true(union[1].0 == Range(1, 3, 1, 5))
  assert_eq(service.get_live_markers_for_model(model_a).length(), 1)
  assert_true(
    service.get_live_markers_for_model(model_a)[0].0 == Range(1, 1, 1, 6),
  )
  assert_true(
    service.get_live_markers_for_model(model_b)[0].0 == Range(1, 3, 1, 5),
  )
  let a_id = model_a.get_all_decorations()[0].id
  let b_id = model_b.get_all_decorations()[0].id
  assert_true(a_id.has_prefix(model_a.instance_id))
  assert_true(b_id.has_prefix(model_b.instance_id))
  assert_eq(service.get_marker(uri, a_id).unwrap().message, "first")
  assert_eq(service.get_marker(uri, b_id).unwrap().message, "first")
  assert_true(service.get_marker(uri, "missing") is None)

  events.clear()
  markers.change_one("host", uri, [
    lifecycle_marker("fanout", start_column=2, end_column=2),
  ])
  assert_true(events == [model_a.instance_id, model_b.instance_id])
  assert_eq(service.get_marker(uri, a_id).unwrap().message, "fanout")
  assert_eq(service.get_marker(uri, b_id).unwrap().message, "fanout")

  // Reacquisition never moved A behind B. Releasing either lease order keeps
  // the one identity owner alive until A's final lease.
  a_second.dispose()
  b.dispose()
  assert_eq(service.get_live_markers(uri).length(), 1)
  assert_true(
    service.model_ids_by_uri.get(uri.to_string()).unwrap() ==
    [model_a.instance_id],
  )
  a_first.dispose()
  assert_eq(service.get_live_markers(uri).length(), 0)
  event_subscription.dispose()
  service.dispose()
}

///|
test "set_value refreshes one owner once without acquiring another lease" {
  let markers = MarkerService::new()
  let uri = lifecycle_uri("file", "/set-value.mbt")
  markers.change_one("host", uri, [lifecycle_marker("stable")])
  let service = MarkerDecorationsService::new(markers)
  let model = lifecycle_model(uri, "set-value.mbt", "before")
  let first = service.acquire_model(model)
  let second = service.acquire_model(model)
  let old_id = model.get_all_decorations()[0].id
  let events : Array[String] = []
  let event_subscription = service.on_did_change_marker_decorations(changed => {
    events.push(changed.instance_id)
  })

  model.set_value("after")
  assert_true(events == [model.instance_id])
  assert_eq(model.get_all_decorations().length(), 1)
  assert_false(model.get_all_decorations()[0].id == old_id)
  assert_eq(
    service.model_registrations.get(model.instance_id).unwrap().ref_count,
    2,
  )
  first.dispose()
  assert_eq(
    service.model_registrations.get(model.instance_id).unwrap().ref_count,
    1,
  )
  second.dispose()
  assert_eq(service.model_registrations.length(), 0)
  event_subscription.dispose()
  service.dispose()
}

///|
test "service disposal blocks reentrant marker and model ingress first" {
  let markers = MarkerService::new()
  let uri = lifecycle_uri("file", "/dispose-reentrant.mbt")
  markers.change_one("host", uri, [lifecycle_marker("before")])
  let service = MarkerDecorationsService::new(markers)
  let model = lifecycle_model(uri, "dispose-reentrant.mbt", "before")
  let lease = service.acquire_model(model)
  let outward_events = Ref(0)
  let outward_subscription = service.on_did_change_marker_decorations(_ => {
    outward_events.val += 1
  })
  let reentered = Ref(false)
  let saw_teardown_order = Ref(false)
  let model_subscription = model.on_did_change_decorations(_ => {
    if !reentered.val {
      reentered.val = true
      match service.model_registrations.get(model.instance_id) {
        Some(registration) =>
          saw_teardown_order.val = !registration.active &&
            registration.content_subscription is None &&
            registration.dispose_subscription is None &&
            service.model_ids_by_uri.contains(uri.to_string())
        None => ()
      }
      // Owner disposal reaches this callback. Both source ingress lanes must
      // already be inert, a fresh acquisition must be rejected, and the two
      // ownership indexes must not clear until this owner returns.
      markers.change_one("host", uri, [lifecycle_marker("during-dispose")])
      service.refresh_model_registration(model.instance_id)
      let rejected = service.acquire_model(model)
      rejected.dispose()
      let rejected_suppression = service.add_marker_suppression(
        uri,
        Range(1, 1, 1, 2),
      )
      rejected_suppression.dispose()
    }
  })

  service.dispose()
  service.dispose()
  // The retained model's real content emitter no longer reaches the service.
  model.set_value("after teardown")
  assert_true(reentered.val)
  assert_true(saw_teardown_order.val)
  assert_eq(outward_events.val, 0)
  assert_true(service.disposed)
  assert_eq(service.model_registrations.length(), 0)
  assert_eq(service.model_ids_by_uri.length(), 0)
  assert_eq(model.get_all_decorations().length(), 0)
  let stored = markers.read(MarkerReadOptions::new(resource=uri))
  assert_eq(stored.length(), 1)
  assert_eq(stored[0].message, "during-dispose")
  // The injected store remains usable and is never disposed by this service.
  markers.change_one("after", uri, [lifecycle_marker("after-dispose")])
  assert_eq(markers.read(MarkerReadOptions::new(resource=uri)).length(), 2)
  lease.dispose()
  outward_subscription.dispose()
  model_subscription.dispose()
}

///|
test "reentrant marker updates drain after the active decoration delta" {
  let markers = MarkerService::new()
  let uri = lifecycle_uri("file", "/nested-update.mbt")
  markers.change_one("host", uri, [lifecycle_marker("before")])
  let service = MarkerDecorationsService::new(markers)
  let model = lifecycle_model(uri, "nested-update.mbt", "alpha")
  let lease = service.acquire_model(model)
  let reentered = Ref(false)
  let model_subscription = model.on_did_change_decorations(_ => {
    if !reentered.val {
      reentered.val = true
      markers.change_one("host", uri, [lifecycle_marker("nested")])
      // MicrotaskEmitter deliberately drops an event re-fired during its own
      // flush. Invoke the same service ingress directly to exercise the
      // synchronous model-decoration reentrancy seam deterministically.
      service.handle_marker_change([uri])
    }
  })
  let outward_events = Ref(0)
  let outward_subscription = service.on_did_change_marker_decorations(_ => {
    outward_events.val += 1
  })

  markers.change_one("host", uri, [lifecycle_marker("outer")])
  assert_true(reentered.val)
  assert_eq(outward_events.val, 2)
  assert_eq(model.get_all_decorations().length(), 1)
  let live = service.get_live_markers_for_model(model)
  assert_eq(live.length(), 1)
  assert_eq(live[0].1.message, "nested")
  let registration = service.model_registrations.get(model.instance_id).unwrap()
  assert_eq(registration.marker_decorations.entries.length(), 1)
  assert_false(registration.update_in_progress)
  assert_false(registration.update_requested)

  outward_subscription.dispose()
  model_subscription.dispose()
  lease.dispose()
  service.dispose()
}

///|
fn assert_active_model_dispose_cleanup(
  scheme : String,
  cleans : Bool,
) -> Unit raise {
  let markers = MarkerService::new()
  let uri = lifecycle_uri(scheme, "/active-dispose.mbt")
  markers.change_one("host", uri, [lifecycle_marker("owned by host")])
  let service = MarkerDecorationsService::new(markers)
  let model = lifecycle_model(uri, "active-dispose.mbt", "value")
  let lease = service.acquire_model(model)
  model.dispose()
  assert_eq(service.model_registrations.length(), 0)
  assert_eq(service.model_ids_by_uri.length(), 0)
  assert_eq(
    markers.read(MarkerReadOptions::new(resource=uri)).length(),
    if cleans {
      0
    } else {
      1
    },
  )
  lease.dispose()
  service.dispose()
}

///|
test "only active transient ModelDisposed removes diagnostics" {
  assert_active_model_dispose_cleanup("inmemory", true)
  assert_active_model_dispose_cleanup("internal", true)
  assert_active_model_dispose_cleanup("vscode", true)
  assert_active_model_dispose_cleanup("file", false)
}

///|
test "transient cleanup waits for the last same-URI identity" {
  let markers = MarkerService::new()
  let uri = lifecycle_uri("inmemory", "/shared-transient.mbt")
  markers.change_one("host", uri, [lifecycle_marker("shared")])
  let service = MarkerDecorationsService::new(markers)
  let model_a = lifecycle_model(uri, "a.mbt", "alpha")
  let model_b = lifecycle_model(uri, "b.mbt", "beta")
  let lease_a = service.acquire_model(model_a)
  let lease_b = service.acquire_model(model_b)

  model_a.dispose()
  assert_eq(markers.read(MarkerReadOptions::new(resource=uri)).length(), 1)
  assert_eq(service.get_live_markers_for_model(model_b).length(), 1)
  model_b.dispose()
  assert_eq(markers.read(MarkerReadOptions::new(resource=uri)).length(), 0)
  lease_a.dispose()
  lease_b.dispose()
  service.dispose()
}
