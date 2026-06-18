///|
/// Idempotent lifecycle handle for subscriptions, watches, and teardown
/// callbacks. Calling `dispose` more than once runs the callback at most once.
pub struct Disposable {
  priv dispose_handler : () -> Unit
}

///|
/// Builds a disposable handle from a teardown callback.
pub fn Disposable::from(dispose : () -> Unit) -> Disposable {
  let disposed = Ref(false)
  {
    dispose_handler: () => {
      if !disposed.val {
        disposed.val = true
        dispose()
      }
    },
  }
}

///|
/// Convenience constructor matching Monaco's `toDisposable` helper name.
pub fn to_disposable(dispose : () -> Unit) -> Disposable {
  Disposable::from(dispose)
}

///|
/// Runs the disposable's teardown callback if it has not already run.
pub fn Disposable::dispose(self : Disposable) -> Unit {
  (self.dispose_handler)()
}

///|
priv struct ListenerCell[T] {
  id : Int
  listener : (T) -> Unit
  active : Ref[Bool]
}

///|
/// Small typed event emitter for host-neutral subscription APIs. It stores
/// listeners in registration order and returns a disposable per listener.
pub struct Emitter[T] {
  priv listeners : Array[ListenerCell[T]]
  priv disposed : Ref[Bool]
  priv next_id : Ref[Int]
}

///|
/// Creates an empty typed emitter.
pub fn[T] Emitter::new() -> Emitter[T] {
  { listeners: [], disposed: Ref(false), next_id: Ref(0) }
}

///|
/// Registers a listener and returns a disposable for just that listener.
pub fn[T] Emitter::event(
  self : Emitter[T],
  listener : (T) -> Unit,
) -> Disposable {
  if self.disposed.val {
    return Disposable::from(() => ())
  }
  let id = self.next_id.val
  self.next_id.val = id + 1
  let active = Ref(true)
  self.listeners.push({ id, listener, active })
  Disposable::from(() => {
    active.val = false
    let retained = self.listeners.filter(cell => cell.id != id)
    self.listeners.clear()
    self.listeners.append(retained)
  })
}

///|
/// Notifies currently active listeners in registration order.
pub fn[T] Emitter::fire(self : Emitter[T], event : T) -> Unit {
  if self.disposed.val {
    return
  }
  for cell in self.listeners {
    if cell.active.val {
      (cell.listener)(event)
    }
  }
}

///|
/// Disposes every listener and prevents later registrations from firing.
pub fn[T] Emitter::dispose(self : Emitter[T]) -> Unit {
  if !self.disposed.val {
    self.disposed.val = true
    for cell in self.listeners {
      cell.active.val = false
    }
    self.listeners.clear()
  }
}
