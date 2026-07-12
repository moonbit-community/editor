///|
/// Mutable collector shared by nested `begin_view_event_batch` scopes.  Event
/// order is the append order; only the outermost matching `end` dispatches the
/// collected batch.
pub(all) struct ViewEventCollector {
  priv view_events : Array[ViewEvent]
}

///|
fn ViewEventCollector::new() -> ViewEventCollector {
  { view_events: [] }
}

///|
pub fn ViewEventCollector::emit(
  self : ViewEventCollector,
  event : ViewEvent,
) -> Unit {
  self.view_events.push(event)
}

///|
pub fn ViewEventCollector::emit_many(
  self : ViewEventCollector,
  events : Array[ViewEvent],
) -> Unit {
  for event in events {
    self.view_events.push(event)
  }
}

///|
/// Reentrant FIFO dispatcher corresponding to Monaco's `ViewEventDispatcher`
/// plus `ViewEventsCollector`.  The callback represents the fixed, ordered
/// ViewPart handler array owned by `View`.
priv struct ViewEventDispatcher {
  deliver : (Array[ViewEvent]) -> Unit
  mut pending_view_events : Array[ViewEvent]?
  mut consuming : Bool
  mut collector : ViewEventCollector?
  mut collector_depth : Int
}

///|
fn ViewEventDispatcher::new(
  deliver : (Array[ViewEvent]) -> Unit,
) -> ViewEventDispatcher {
  {
    deliver,
    pending_view_events: None,
    consuming: false,
    collector: None,
    collector_depth: 0,
  }
}

///|
fn ViewEventDispatcher::begin(self : ViewEventDispatcher) -> ViewEventCollector {
  self.collector_depth = self.collector_depth + 1
  match self.collector {
    Some(collector) => collector
    None => {
      let collector = ViewEventCollector::new()
      self.collector = Some(collector)
      collector
    }
  }
}

///|
fn ViewEventDispatcher::end(self : ViewEventDispatcher) -> Unit {
  if self.collector_depth <= 0 {
    abort("ViewEventDispatcher.end without matching begin")
  }
  self.collector_depth = self.collector_depth - 1
  if self.collector_depth > 0 {
    return
  }
  let events = match self.collector {
    Some(collector) => collector.view_events.copy()
    None => abort("ViewEventDispatcher collector missing")
  }
  self.collector = None
  self.enqueue(events)
}

///|
fn ViewEventDispatcher::emit_view_event(
  self : ViewEventDispatcher,
  event : ViewEvent,
) -> Unit {
  match self.collector {
    Some(collector) => collector.emit(event)
    None => {
      let collector = self.begin()
      defer self.end()
      collector.emit(event)
    }
  }
}

///|
fn ViewEventDispatcher::emit_view_events(
  self : ViewEventDispatcher,
  events : Array[ViewEvent],
) -> Unit {
  if events.length() == 0 {
    return
  }
  match self.collector {
    Some(collector) => collector.emit_many(events)
    None => {
      let collector = self.begin()
      defer self.end()
      collector.emit_many(events)
    }
  }
}

///|
fn ViewEventDispatcher::enqueue(
  self : ViewEventDispatcher,
  events : Array[ViewEvent],
) -> Unit {
  if events.length() == 0 {
    return
  }
  match self.pending_view_events {
    Some(pending) =>
      for event in events {
        pending.push(event)
      }
    None => self.pending_view_events = Some(events.copy())
  }
  self.consume()
}

///|
fn ViewEventDispatcher::consume(self : ViewEventDispatcher) -> Unit {
  if self.consuming {
    return
  }
  self.consuming = true
  defer self.finish_consuming()
  // `deliver` is statically non-raising, so the consuming gate is restored on
  // every possible return.  A reentrant emit installs a fresh pending array;
  // clearing before delivery prevents callbacks from interleaving batches.
  while true {
    let events = match self.pending_view_events {
      Some(events) => events
      None => break
    }
    self.pending_view_events = None
    (self.deliver)(events)
  }
}

///|
fn ViewEventDispatcher::finish_consuming(self : ViewEventDispatcher) -> Unit {
  self.consuming = false
}

///|
fn ViewEventDispatcher::dispose(self : ViewEventDispatcher) -> Unit {
  self.pending_view_events = None
  self.collector = None
  self.collector_depth = 0
  self.consuming = false
}
