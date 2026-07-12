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
  on_event_emitter : @base_common.Emitter[CursorStateChangedEvent]
  outgoing_events : Array[PendingOutgoingEvent]
  event_delivery_queue : Array[CursorStateChangedEvent]
  mut event_delivery_is_draining : Bool
  mut disposed : Bool
}

///|
/// Creates an empty dispatcher.
fn CursorEventDispatcher::new() -> CursorEventDispatcher {
  // Construction witness for the different-kind merge arm. Non-cursor event
  // classes themselves remain deferred to their owning child plans.
  let different_kind_witness = DeferredSiblingEvent
  ignore(different_kind_witness)
  {
    on_event_emitter: @base_common.Emitter::new(),
    outgoing_events: [],
    event_delivery_queue: [],
    event_delivery_is_draining: false,
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
  self.event_delivery_queue.clear()
  self.on_event_emitter.dispose()
}

///|
/// Exposes the dispatcher's cursor event.
fn CursorEventDispatcher::on_event(
  self : CursorEventDispatcher,
  listener : (CursorStateChangedEvent) -> Unit,
) -> @base_common.Disposable {
  self.on_event_emitter.event(listener)
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
/// Mirrors the source emitter's `EventDeliveryQueue`: a listener may enqueue
/// a reentrant event, but every remaining listener first observes the current
/// event. The outgoing-event drain itself remains recursively source-shaped;
/// this separate queue belongs to `_onEvent.fire`, not to event coalescing.
fn CursorEventDispatcher::deliver_event(
  self : CursorEventDispatcher,
  event : CursorStateChangedEvent,
) -> Unit {
  if self.disposed {
    return
  }
  self.event_delivery_queue.push(event)
  if self.event_delivery_is_draining {
    return
  }
  self.event_delivery_is_draining = true
  while self.event_delivery_queue.length() > 0 && !self.disposed {
    let next = self.event_delivery_queue.remove(0)
    self.on_event_emitter.fire(next)
  }
  self.event_delivery_is_draining = false
}
