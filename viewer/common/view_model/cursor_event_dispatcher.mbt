///|
/// Semantic kind of the scoped outgoing event. Monaco's const-enum value is
/// `7`; MoonBit deliberately exposes no numeric ABI for the variant.
pub(all) enum OutgoingViewModelEventKind {
  CursorStateChanged
} derive(Eq, Debug)

///|
/// Complete outgoing cursor payload owned by the ViewModel. It retains the
/// earliest old state when merged and the latest new state/source/reason.
pub(all) struct CursorStateChangedEvent {
  kind : OutgoingViewModelEventKind
  old_selections : Array[@core.Selection]?
  selections : Array[@core.Selection]
  old_model_version_id : Int
  model_version_id : Int
  source : String
  reason : @cursor.CursorChangeReason
  reached_max_cursor_count : Bool
} derive(Debug)

///|
/// Builds the outgoing event from one controller transition fact.
fn CursorStateChangedEvent::from_change(
  change : @cursor.CursorStateChange,
) -> CursorStateChangedEvent {
  {
    kind: CursorStateChanged,
    old_selections: change.old_selections,
    selections: change.selections,
    old_model_version_id: change.old_model_version_id,
    model_version_id: change.model_version_id,
    source: change.source,
    reason: change.reason,
    reached_max_cursor_count: change.reached_max_cursor_count,
  }
}

///|
/// Nullable ordered-selection equality from
/// `CursorStateChangedEvent._selectionsAreEqual`.
fn selections_are_equal(
  a : Array[@core.Selection]?,
  b : Array[@core.Selection]?,
) -> Bool {
  match (a, b) {
    (None, None) => true
    (None, Some(_)) | (Some(_), None) => false
    (Some(a), Some(b)) => {
      if a.length() != b.length() {
        return false
      }
      for index in 0..<a.length() {
        if a[index] != b[index] {
          return false
        }
      }
      true
    }
  }
}

///|
/// An outgoing cursor event is a no-op only when both the selections and the
/// internal model versions are equal.
pub fn CursorStateChangedEvent::is_no_op(
  self : CursorStateChangedEvent,
) -> Bool {
  selections_are_equal(self.old_selections, Some(self.selections)) &&
  self.old_model_version_id == self.model_version_id
}

///|
/// Private heterogeneous queue arm retained only so the cursor event's
/// different-kind merge rejection remains represented while non-cursor event
/// classes stay with their owning plans.
priv enum PendingOutgoingEvent {
  CursorEvent(CursorStateChangedEvent)
  DeferredSiblingEvent
}

///|
/// Merges only another cursor event. Earliest old state/version remain; latest
/// new state/version/source/reason win.
fn CursorStateChangedEvent::attempt_to_merge(
  self : CursorStateChangedEvent,
  other : PendingOutgoingEvent,
) -> CursorStateChangedEvent? {
  match other {
    DeferredSiblingEvent => None
    CursorEvent(other) =>
      Some({
        kind: CursorStateChanged,
        old_selections: self.old_selections,
        selections: other.selections,
        old_model_version_id: self.old_model_version_id,
        model_version_id: other.model_version_id,
        source: other.source,
        reason: other.reason,
        reached_max_cursor_count: self.reached_max_cursor_count ||
        other.reached_max_cursor_count,
      })
  }
}

///|
/// DOM-free outgoing-only half of Monaco's `ViewModelEventDispatcher`.
/// Pending cursor events coalesce into their first same-kind slot; delivery is
/// FIFO, discards no-ops, and remains safe when listeners emit reentrantly.
struct CursorEventDispatcher {
  event_listeners : Array[CursorEventListenerCell]
  outgoing_events : Array[PendingOutgoingEvent]
  mut listener_count : Int
  mut listeners_are_array : Bool
  mut delivery_index : Int
  mut delivery_end : Int
  mut delivery_value : CursorStateChangedEvent?
  mut delivery_active : Bool
  mut disposed : Bool
}

///|
/// Stable listener slot. Disposals mark slots inactive instead of changing the
/// array while a source-shaped delivery walk is in progress.
priv struct CursorEventListenerCell {
  listener : (CursorStateChangedEvent) -> Unit
  active : Ref[Bool]
}

///|
/// Creates an empty dispatcher.
fn CursorEventDispatcher::new() -> CursorEventDispatcher {
  // Construction witness for the different-kind merge arm. Non-cursor event
  // classes themselves remain deferred to their owning child plans.
  let different_kind_witness = DeferredSiblingEvent
  ignore(different_kind_witness)
  {
    event_listeners: [],
    outgoing_events: [],
    listener_count: 0,
    listeners_are_array: false,
    delivery_index: -1,
    delivery_end: 0,
    delivery_value: None,
    delivery_active: false,
    disposed: false,
  }
}

///|
/// Retires the registered outgoing listeners and drops any queued facts.
/// Later subscriptions and emissions are inert, matching the source-owned
/// emitter's registration in the ViewModel lifetime store.
fn CursorEventDispatcher::dispose(self : CursorEventDispatcher) -> Unit {
  if self.disposed {
    return
  }
  self.disposed = true
  self.outgoing_events.clear()
  for cell in self.event_listeners {
    cell.active.val = false
  }
  self.event_listeners.clear()
  self.listener_count = 0
  self.reset_event_delivery()
}

///|
/// Exposes the dispatcher's cursor event.
fn CursorEventDispatcher::on_event(
  self : CursorEventDispatcher,
  listener : (CursorStateChangedEvent) -> Unit,
) -> @base_common.Disposable {
  if self.disposed {
    return @base_common.Disposable::from(() => ())
  }
  if self.listener_count == 1 && !self.listeners_are_array {
    // Monaco upgrades from its optimized single-listener representation to a
    // sparse array when the second listener is registered. It deliberately
    // does not downgrade that array while one listener remains.
    self.listeners_are_array = true
  }
  let active = Ref(true)
  self.event_listeners.push({ listener, active })
  self.listener_count += 1
  @base_common.Disposable::from(() => {
    if active.val {
      active.val = false
      self.listener_count -= 1
      if self.listener_count == 0 {
        self.listeners_are_array = false
      }
    }
  })
}

///|
/// Adds or merges first, then attempts an immediate drain.
fn CursorEventDispatcher::emit_outgoing_event(
  self : CursorEventDispatcher,
  event : CursorStateChangedEvent,
) -> Unit {
  if self.disposed {
    return
  }
  self.add_outgoing_event(CursorEvent(event))
  self.emit_outgoing_events()
}

///|
/// Scans queued events in order and replaces the first mergeable slot;
/// otherwise appends at the FIFO tail.
fn CursorEventDispatcher::add_outgoing_event(
  self : CursorEventDispatcher,
  event : PendingOutgoingEvent,
) -> Unit {
  if self.disposed {
    return
  }
  for index, pending in self.outgoing_events {
    match pending {
      CursorEvent(existing) =>
        match existing.attempt_to_merge(event) {
          Some(merged) => {
            self.outgoing_events[index] = CursorEvent(merged)
            return
          }
          None => ()
        }
      DeferredSiblingEvent => ()
    }
  }
  self.outgoing_events.push(event)
}

///|
/// Drains FIFO until empty. There is deliberately no local reentrancy gate:
/// the source recursively shifts/fires a reentrant outgoing event immediately
/// unless its separate generic view-event collector is active (that collector
/// is outside this child). The root Viewer's delivery FIFO, not this semantic
/// dispatcher, keeps public position/selection pairs adjacent.
fn CursorEventDispatcher::emit_outgoing_events(
  self : CursorEventDispatcher,
) -> Unit {
  if self.disposed {
    return
  }
  while self.outgoing_events.length() > 0 {
    match self.outgoing_events.remove(0) {
      CursorEvent(event) => if !event.is_no_op() { self.deliver_event(event) }
      DeferredSiblingEvent => ()
    }
  }
}

///|
/// Resets the listener-level delivery cursor. Incrementing the cursor before a
/// callback and finishing an active walk at the start of a nested `fire` are
/// the two ordering rules owned by Monaco's `Emitter._deliverQueue`/`fire`.
fn CursorEventDispatcher::reset_event_delivery(
  self : CursorEventDispatcher,
) -> Unit {
  self.delivery_index = self.delivery_end
  self.delivery_end = 0
  self.delivery_value = None
  self.delivery_active = false
}

///|
/// Finishes the currently enqueued listener walk. A nested fire calls this
/// before enqueuing its own value, so the remaining listeners observe A, then
/// all listeners observe B, before the first A callback resumes.
fn CursorEventDispatcher::finish_event_delivery(
  self : CursorEventDispatcher,
) -> Unit {
  while self.delivery_active &&
        self.delivery_index < self.delivery_end &&
        !self.disposed {
    let index = self.delivery_index
    // Source increments before invoking the listener because the callback can
    // recursively finish this same delivery state.
    self.delivery_index += 1
    let cell = self.event_listeners[index]
    if cell.active.val {
      guard self.delivery_value is Some(value) else {
        self.reset_event_delivery()
        return
      }
      (cell.listener)(value)
    }
  }
  if self.delivery_active &&
    (self.delivery_index >= self.delivery_end || self.disposed) {
    self.reset_event_delivery()
  }
}

///|
/// Mirrors the source emitter's direct single-listener representation and its
/// listener-level `EventDeliveryQueue`. This cannot be an outer event FIFO:
/// on a nested fire, the source first drains the remaining listeners for the
/// current value and delivers the nested value before returning to the caller.
fn CursorEventDispatcher::deliver_event(
  self : CursorEventDispatcher,
  event : CursorStateChangedEvent,
) -> Unit {
  if self.disposed {
    return
  }
  if self.delivery_active {
    self.finish_event_delivery()
  }
  if self.disposed || self.listener_count == 0 {
    return
  }
  if !self.listeners_are_array {
    for cell in self.event_listeners {
      if cell.active.val {
        (cell.listener)(event)
        return
      }
    }
    return
  }
  self.delivery_index = 0
  self.delivery_end = self.event_listeners.length()
  self.delivery_value = Some(event)
  self.delivery_active = true
  self.finish_event_delivery()
}
