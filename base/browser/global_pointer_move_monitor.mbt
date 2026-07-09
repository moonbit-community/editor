// Ported from `vscode/src/vs/base/browser/globalPointerMoveMonitor.ts`
// (vscode submodule commit b18492a288de038fbc7643aae6de8247029d11bd).
//
// Omissions:
//   * `setPointerCapture`/`releasePointerCapture` and the `pointerId`
//     parameter — the vendored `@rdom` has no pointer-capture bindings. The
//     source itself falls back to binding the listeners on the window when
//     `setPointerCapture` throws (globalPointerMoveMonitor.ts:82-90); this
//     port always takes that fallback branch, so `initialElement` is only the
//     future capture seam and is currently unused.
//   * `DisposableStore` is an `Array[@base_common.Disposable]` (base/common
//     ports no store type).

///|
pub struct GlobalPointerMoveMonitor {
  priv hooks : Array[@base_common.Disposable]
  priv mut pointer_move_callback : ((@rdom.MouseEvent) -> Unit)?
  priv mut on_stop_callback : ((@rdom.Event?) -> Unit)?
}

///|
pub fn GlobalPointerMoveMonitor::new() -> GlobalPointerMoveMonitor {
  { hooks: [], pointer_move_callback: None, on_stop_callback: None }
}

///|
pub fn GlobalPointerMoveMonitor::dispose(
  self : GlobalPointerMoveMonitor,
) -> Unit {
  self.stop_monitoring(false)
}

///|
pub fn GlobalPointerMoveMonitor::stop_monitoring(
  self : GlobalPointerMoveMonitor,
  invoke_stop_callback : Bool,
  browser_event? : @rdom.Event,
) -> Unit {
  if !self.is_monitoring() {
    return
  }
  for hook in self.hooks {
    hook.dispose()
  }
  self.hooks.clear()
  self.pointer_move_callback = None
  let on_stop_callback = self.on_stop_callback
  self.on_stop_callback = None
  if invoke_stop_callback && on_stop_callback is Some(callback) {
    callback(browser_event)
  }
}

///|
pub fn GlobalPointerMoveMonitor::is_monitoring(
  self : GlobalPointerMoveMonitor,
) -> Bool {
  self.pointer_move_callback is Some(_)
}

///|
/// `startMonitoring` (globalPointerMoveMonitor.ts:49-113), permanently on the
/// window-fallback event source (see the header).
pub fn GlobalPointerMoveMonitor::start_monitoring(
  self : GlobalPointerMoveMonitor,
  _initial_element : @rdom.Element,
  initial_buttons : Int,
  pointer_move_callback : (@rdom.MouseEvent) -> Unit,
  on_stop_callback : (@rdom.Event?) -> Unit,
) -> Unit {
  if self.is_monitoring() {
    self.stop_monitoring(false)
  }
  self.pointer_move_callback = Some(pointer_move_callback)
  self.on_stop_callback = Some(on_stop_callback)
  let event_source = @rdom.window()
  let pointer_move = (event : @rdom.Event) => {
    match event.to_mouse_event() {
      Some(e) =>
        if e.get_buttons() != initial_buttons {
          // Buttons state has changed in the meantime
          self.stop_monitoring(true)
        } else {
          e.prevent_default()
          match self.pointer_move_callback {
            Some(callback) => callback(e)
            None => ()
          }
        }
      None => ()
    }
  }
  let pointer_up = (_event : @rdom.Event) => self.stop_monitoring(true)
  event_source.add_event_listener("pointermove", pointer_move)
  event_source.add_event_listener("pointerup", pointer_up)
  self.hooks.push(
    @base_common.Disposable::from(() => {
      event_source.remove_event_listener("pointermove", pointer_move)
    }),
  )
  self.hooks.push(
    @base_common.Disposable::from(() => {
      event_source.remove_event_listener("pointerup", pointer_up)
    }),
  )
}
