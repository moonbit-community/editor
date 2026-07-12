///|
/// Adapts the DOM-free cursor reason to the stable public Viewer enum.
fn public_cursor_change_reason(
  reason : @cursor.CursorChangeReason,
) -> CursorChangeReason {
  match reason {
    NotSet => NotSet
    ContentFlush => ContentFlush
    RecoverFromMarkers => RecoverFromMarkers
    Explicit => Explicit
    Paste => Paste
    Undo => Undo
    Redo => Redo
  }
}

///|
fn is_model_flush_cursor_event(
  event : @view_model.CursorStateChangedEvent,
) -> Bool {
  event.reason == ContentFlush &&
  event.old_selections is None &&
  event.old_model_version_id == 0
}

///|
fn Viewer::has_completed_cursor_content_version(
  self : Viewer,
  version_id : Int,
) -> Bool {
  self.cursor_completed_content_versions.contains(version_id)
}

///|
/// Keeps the exposed depth equal to the exact number of queued Flush facts
/// still waiting for their own public content version.
fn Viewer::refresh_cursor_content_barrier_depth(self : Viewer) -> Unit {
  let mut depth = 0
  for event in self.cursor_delivery_queue {
    if is_model_flush_cursor_event(event) &&
      !self.has_completed_cursor_content_version(event.model_version_id) {
      depth += 1
    }
  }
  self.cursor_content_barrier_depth = depth
}

///|
/// Receives one ViewModel outgoing cursor fact. View state is already
/// committed; scheduling happens before any public listener. Flush facts open
/// a content barrier and remain queued until the model's public content event
/// has run.
fn Viewer::enqueue_cursor_state_change(
  self : Viewer,
  event : @view_model.CursorStateChangedEvent,
) -> Unit {
  // `set_selections` publicly accepts any reason, including ContentFlush.
  // Only the controller's real model-flush fact has the null-old-state
  // sentinel and therefore needs to wait for the public content event.
  self.schedule_render()
  self.cursor_delivery_queue.push(event)
  self.refresh_cursor_content_barrier_depth()
  self.drain_cursor_delivery_queue()
}

///|
/// Closes one model-content barrier after all public content listeners return.
/// Nested/reentrant set-value calls increment the depth independently, so no
/// flush fact can overwrite another or drain before its content event.
fn Viewer::complete_model_content_delivery(
  self : Viewer,
  version_id : Int,
) -> Unit {
  if !self.has_completed_cursor_content_version(version_id) {
    self.cursor_completed_content_versions.push(version_id)
  }
  self.refresh_cursor_content_barrier_depth()
  self.drain_cursor_delivery_queue()
}

///|
/// Drains cursor facts FIFO. A fact is removed before callbacks, and the gate
/// remains set through both public fires, so a reentrant cursor transition is
/// appended for a later iteration rather than interleaving the current pair.
fn Viewer::drain_cursor_delivery_queue(self : Viewer) -> Unit {
  if self.cursor_delivery_is_draining {
    return
  }
  self.cursor_delivery_is_draining = true
  while self.cursor_delivery_queue.length() > 0 {
    let next = self.cursor_delivery_queue[0]
    if self.cursor_content_barrier_depth > 0 &&
      is_model_flush_cursor_event(next) &&
      !self.has_completed_cursor_content_version(next.model_version_id) {
      break
    }
    let event = self.cursor_delivery_queue.remove(0)
    if is_model_flush_cursor_event(event) {
      match
        self.cursor_completed_content_versions.search_by(version => {
          version == event.model_version_id
        }) {
        Some(index) =>
          self.cursor_completed_content_versions.remove(index) |> ignore
        None => ()
      }
    }
    guard event.selections.length() > 0 else { continue }
    let selection = event.selections[0]
    let reason = public_cursor_change_reason(event.reason)
    self.did_change_cursor_position.fire({
      position: selection.get_position(),
      secondary_positions: [],
      reason,
      source: event.source,
    })
    self.did_change_cursor_selection.fire({
      selection,
      secondary_selections: [],
      model_version_id: event.model_version_id,
      old_selections: event.old_selections,
      old_model_version_id: event.old_model_version_id,
      source: event.source,
      reason,
    })
  }
  self.cursor_delivery_is_draining = false
  self.refresh_cursor_content_barrier_depth()
}

///|
/// Drops pending facts when their model-scoped ViewModel is detached.
fn Viewer::reset_cursor_delivery(self : Viewer) -> Unit {
  self.cursor_delivery_queue.clear()
  self.cursor_content_barrier_depth = 0
  self.cursor_completed_content_versions.clear()
}
