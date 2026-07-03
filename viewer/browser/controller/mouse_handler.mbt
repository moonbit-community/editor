// Browser input controller — the local analog of Monaco's
// `editor/browser/controller/mouseHandler.ts`. Like Monaco's `MouseHandler`,
// it owns the DOM listener wiring and the pointer-input state (the active
// scrollbar-thumb drag and the `MouseDownState` multi-click/selection-drag), and
// it never reaches into the concrete view: it calls back through a
// `PointerHandlerHelper`, the analog of Monaco's `IPointerHandlerHelper`.
//
// In Monaco that helper is the object literal `View._createPointerHandlerHelper`
// returns — DOM nodes as fields, view-dependent operations as closures. The
// faithful MoonBit translation is the same: a struct of nodes + closures, built
// by the viewer where the view is in scope (mirroring `ViewContext`). The edge
// stays one-directional: `viewer -> viewer/browser/controller`.
//
// The dispatch side — turning a resolved pointer position into a selection
// command — stays in the viewer core (`Viewer::dispatch_mouse`), as Monaco keeps
// `view/viewController.ts` under `view/`, not `controller/`. The controller only
// builds the `MouseDispatch` intent and hands it back through the helper.

///|
/// VS Code's default multi-click time/distance gating (`MouseDownState`).
let multi_click_time = 500.0

///|
let multi_click_distance = 6.0

///|
/// Cap on one drag-autoscroll step (Monaco's `dragScrolling`).
let selection_autoscroll_max_step = 36.0

///|
/// A resolved pointer intent the controller hands back to the viewer's dispatch
/// (Monaco's `IMouseDispatchData`, here kept controller-side to honor the
/// one-directional edge, then mapped to the core dispatch type by the helper).
pub(all) struct MouseDispatch {
  view_position : @base_common.Position
  in_selection_mode : Bool
  mouse_down_count : Int
  started_on_line_numbers : Bool
}

///|
/// The narrow view capabilities the input controller calls back into, the local
/// analog of Monaco's `IPointerHandlerHelper`. The viewer builds one of these in
/// `hook_view_input` (where the view exists), closing over the view and itself —
/// exactly as Monaco's `View._createPointerHandlerHelper` closes over `this`.
pub(all) struct PointerHandlerHelper {
  /// Monaco `viewDomNode`: the view root element.
  view_root : @rdom.Element
  /// The overflow guard element that owns wheel + browser-reveal scroll events.
  overflow_guard : @rdom.Element
  /// The editor's scrollable element (Monaco's editor scrollbar target).
  editor_scrollable : @scrollbar.ScrollableElementDom
  /// The hover content widget's scrollable, if the hover widget is mounted
  /// (lazily created, so this is a closure, not a field).
  hover_scrollable : () -> @scrollbar.ScrollableElementDom?
  /// The editor scroll/layout model.
  view_layout : () -> @view_layout.ViewLayout
  /// Commit a scroll change produced from `view_layout()` (repaint + reveal).
  apply_scroll : (@view_layout.ScrollChange?) -> Unit
  /// The editor line height in pixels.
  line_height : () -> Double
  /// The current render frame, if a model is rendered.
  frame : () -> @view_model.RenderFrame?
  /// The hit-test geometry for a frame (Monaco's `ViewContext`-derived metrics).
  view_metrics : (@view_model.RenderFrame) -> @viewer_common.ViewMetrics
  /// Refines a content target with DOM caret hit-testing (Monaco's
  /// `viewHelper.getPositionFromDOMInfo`): frame, client x/y, fallback target.
  refine_content_target : (
    @view_model.RenderFrame,
    Double,
    Double,
    @viewer_common.MouseTarget,
  ) -> @viewer_common.MouseTarget
  /// Dispatch a resolved pointer intent (Monaco's `ViewController.dispatchMouse`).
  dispatch_mouse : (MouseDispatch) -> Unit
  /// Report a hover-relevant mouse move (Monaco's `ViewUserInputEvents` move).
  notify_mouse_moved : (@viewer_common.MouseTarget) -> Unit
  /// Report a left-button mousedown's hit-tested target — Monaco's
  /// `ViewController.emitMouseDown` (`mouseHandler.ts` `_onMouseDown` tail).
  notify_mouse_down : (@viewer_common.MouseTarget) -> Unit
  /// Report a left-button mouseup's hit-tested target — Monaco's
  /// `ViewController.emitMouseUp`.
  notify_mouse_up : (@viewer_common.MouseTarget) -> Unit
  /// Request a repaint.
  schedule_render : () -> Unit
}

///|
/// Owns the active scrollbar-thumb drag and the multi-click/selection-drag
/// state, plus the scroll- and pointer-input wiring. Mirrors Monaco's
/// `MouseHandler` holding its `MouseDownOperation`/`MouseDownState`.
pub struct MouseHandler {
  helper : PointerHandlerHelper
  mut drag : @scrollbar.ScrollbarDrag?
  mut selection_dragging : Bool
  mut selection_started_on_line_numbers : Bool
  mut last_mouse_down_count : Int
  mut last_mouse_down_time : Double
  mut last_mouse_down_x : Double
  mut last_mouse_down_y : Double
  mut selection_autoscroll_active : Bool
  mut selection_autoscroll_x : Double
  mut selection_autoscroll_y : Double
}

///|
/// Creates the input controller over a view helper.
pub fn MouseHandler::new(helper : PointerHandlerHelper) -> MouseHandler {
  {
    helper,
    drag: None,
    selection_dragging: false,
    selection_started_on_line_numbers: false,
    last_mouse_down_count: 0,
    last_mouse_down_time: 0.0,
    last_mouse_down_x: 0.0,
    last_mouse_down_y: 0.0,
    selection_autoscroll_active: false,
    selection_autoscroll_x: 0.0,
    selection_autoscroll_y: 0.0,
  }
}

// === Mouse selection + hit test (Monaco MouseDownOperation / mouseTarget) ===

///|
/// Converts a container mouse event into view-relative coordinates using the
/// view root, so hit-testing is independent of page layout.
pub fn MouseHandler::handle_mouse_move(
  self : MouseHandler,
  mouse : @rdom.MouseEvent,
) -> Unit {
  guard (self.helper.frame)() is Some(frame) else { return }
  let rect = self.helper.view_root.get_bounding_client_rect()
  let x = mouse.get_client_x().to_double() - rect.get_left()
  let y = mouse.get_client_y().to_double() - rect.get_top()
  let target = @viewer_common.hit_test(
    frame,
    (self.helper.view_metrics)(frame),
    x,
    y,
  )
  (self.helper.notify_mouse_moved)(target)
}

///|
pub fn MouseHandler::handle_mouse_down(
  self : MouseHandler,
  event : @rdom.Event,
  mouse : @rdom.MouseEvent,
) -> Unit {
  if mouse.get_button() != 0 {
    return
  }
  guard (self.helper.frame)() is Some(frame) else { return }
  focus_element(self.helper.view_root)
  let client_x = mouse.get_client_x().to_double()
  let client_y = mouse.get_client_y().to_double()
  let rect = self.helper.view_root.get_bounding_client_rect()
  let x = client_x - rect.get_left()
  let y = client_y - rect.get_top()
  let target = @viewer_common.hit_test(
    frame,
    (self.helper.view_metrics)(frame),
    x,
    y,
  )
  // Monaco emits the mouse-down event after its selection handling
  // (`mouseHandler.ts:349` `emitMouseDown`); the viewer notifies before the
  // early return below so non-selecting targets (the decorations lane) still
  // reach listeners. Only left-button downs arrive here, matching the one
  // consumer (comments gates on `e.event.leftButton`).
  (self.helper.notify_mouse_down)(target)
  // Resolve the pointer to a view position and whether the drag started on the
  // line-number gutter (which selects whole lines).
  let resolved : (@base_common.Position, Bool)? = match target.kind {
    ContentText | ContentEmpty => {
      let refined = (self.helper.refine_content_target)(
        frame, client_x, client_y, target,
      )
      Some((Position(refined.line_number, refined.column + 1), false))
    }
    GutterLineNumbers => Some((Position(target.line_number, 1), true))
    // `_onMouseDown` (`mouseHandler.ts:314-336`): a gutter target other than
    // the line numbers prevents the default ("Do not steal focus") but starts
    // no selection.
    GutterLineDecorations => {
      event.prevent_default()
      None
    }
    _ => None
  }
  guard resolved is Some((view_position, started_on_line_numbers)) else {
    return
  }
  event.prevent_default()
  event.stop_propagation()
  let mouse_down_count = self.next_mouse_down_count(client_x, client_y)
  self.selection_started_on_line_numbers = started_on_line_numbers
  self.selection_dragging = true
  (self.helper.dispatch_mouse)({
    view_position,
    in_selection_mode: mouse_shift_key(mouse),
    mouse_down_count,
    started_on_line_numbers,
  })
}

///|
/// Root `mouseup`: hit-tests the release position and notifies listeners —
/// Monaco's `emitMouseUp`. Left button only, pairing with
/// `handle_mouse_down`'s notification (the comments contrib matches the two
/// by line).
pub fn MouseHandler::handle_mouse_up(
  self : MouseHandler,
  mouse : @rdom.MouseEvent,
) -> Unit {
  if mouse.get_button() != 0 {
    return
  }
  guard (self.helper.frame)() is Some(frame) else { return }
  let rect = self.helper.view_root.get_bounding_client_rect()
  let x = mouse.get_client_x().to_double() - rect.get_left()
  let y = mouse.get_client_y().to_double() - rect.get_top()
  let target = @viewer_common.hit_test(
    frame,
    (self.helper.view_metrics)(frame),
    x,
    y,
  )
  (self.helper.notify_mouse_up)(target)
}

///|
extern "js" fn focus_element(element : @rdom.Element) -> Unit = "(element) => element.focus?.()"

///|
extern "js" fn mouse_shift_key(mouse : @rdom.MouseEvent) -> Bool = "(m) => !!m.shiftKey"

///|
extern "js" fn now_ms() -> Double =
  #| () => globalThis.performance?.now() ?? Date.now()

///|
/// The multi-click count for a fresh mousedown, transcribing the timing/distance
/// gating of Monaco's `MouseDownState`: a mousedown close to the previous one in
/// time and space increments the count (single → double → triple → quad), else
/// it resets to a single click.
fn MouseHandler::next_mouse_down_count(
  self : MouseHandler,
  client_x : Double,
  client_y : Double,
) -> Int {
  let now = now_ms()
  let dx = (client_x - self.last_mouse_down_x).abs()
  let dy = (client_y - self.last_mouse_down_y).abs()
  let close = now - self.last_mouse_down_time <= multi_click_time &&
    dx <= multi_click_distance &&
    dy <= multi_click_distance
  let count = if close { self.last_mouse_down_count + 1 } else { 1 }
  self.last_mouse_down_count = count
  self.last_mouse_down_time = now
  self.last_mouse_down_x = client_x
  self.last_mouse_down_y = client_y
  count
}

///|
/// Applies an in-progress selection drag (document `mousemove`).
pub fn MouseHandler::handle_selection_drag_move(
  self : MouseHandler,
  event : @rdom.Event,
) -> Unit {
  guard self.selection_dragging else { return }
  guard event.to_mouse_event() is Some(mouse) else { return }
  event.prevent_default()
  let client_x = mouse.get_client_x().to_double()
  let client_y = mouse.get_client_y().to_double()
  self.extend_selection_at(client_x, client_y)
  self.update_selection_autoscroll(client_x, client_y)
}

///|
/// Extends the in-progress selection to a pointer position (in client
/// coordinates), re-running the hit test against the current scroll. Shared by
/// pointer moves and the drag-autoscroll loop.
fn MouseHandler::extend_selection_at(
  self : MouseHandler,
  client_x : Double,
  client_y : Double,
) -> Unit {
  guard self.selection_dragging else { return }
  guard (self.helper.frame)() is Some(frame) else { return }
  let rect = self.helper.view_root.get_bounding_client_rect()
  let x = client_x - rect.get_left()
  let y = client_y - rect.get_top()
  let target = @viewer_common.hit_test(
    frame,
    (self.helper.view_metrics)(frame),
    x,
    y,
  )
  let refined = match target.kind {
    ContentText | ContentEmpty =>
      (self.helper.refine_content_target)(frame, client_x, client_y, target)
    _ => target
  }
  match drag_view_position(refined) {
    Some(view_position) =>
      (self.helper.dispatch_mouse)({
        view_position,
        in_selection_mode: true,
        mouse_down_count: self.last_mouse_down_count,
        started_on_line_numbers: self.selection_started_on_line_numbers,
      })
    None => ()
  }
}

///|
/// Updates the drag-autoscroll state from the latest pointer position. When the
/// pointer is dragged past the top or bottom of the content viewport, the
/// remembered position drives a continuous scroll-and-extend loop (Monaco's
/// `dragScrolling`); when it returns inside, the loop stops on its next tick.
fn MouseHandler::update_selection_autoscroll(
  self : MouseHandler,
  client_x : Double,
  client_y : Double,
) -> Unit {
  self.selection_autoscroll_x = client_x
  self.selection_autoscroll_y = client_y
  if self.selection_drag_edge_delta(client_y) != 0.0 {
    if !self.selection_autoscroll_active {
      self.selection_autoscroll_active = true
      self.schedule_selection_autoscroll()
    }
  } else {
    self.selection_autoscroll_active = false
  }
}

///|
/// The signed vertical overshoot of a client-Y past the content viewport edges:
/// negative above the top, positive below the bottom, zero inside.
fn MouseHandler::selection_drag_edge_delta(
  self : MouseHandler,
  client_y : Double,
) -> Double {
  let rect = self.helper.view_root.get_bounding_client_rect()
  let y = client_y - rect.get_top()
  let viewport_height = (self.helper.view_layout)().dimensions().height
  if y < 0.0 {
    y
  } else if viewport_height > 0.0 && y > viewport_height {
    y - viewport_height
  } else {
    0.0
  }
}

///|
fn MouseHandler::schedule_selection_autoscroll(self : MouseHandler) -> Unit {
  @rdom.window().request_animation_frame(_ => self.selection_autoscroll_tick())
  |> ignore
}

///|
/// One frame of drag autoscroll: scroll toward the remembered off-edge pointer,
/// re-extend the selection at the new scroll, and reschedule until the drag ends
/// or the pointer returns inside the viewport.
fn MouseHandler::selection_autoscroll_tick(self : MouseHandler) -> Unit {
  guard self.selection_dragging && self.selection_autoscroll_active else {
    self.selection_autoscroll_active = false
    return
  }
  let delta = self.selection_drag_edge_delta(self.selection_autoscroll_y)
  if delta == 0.0 {
    self.selection_autoscroll_active = false
    return
  }
  let step = delta.clamp(
    min=-selection_autoscroll_max_step,
    max=selection_autoscroll_max_step,
  )
  (self.helper.apply_scroll)(
    (self.helper.view_layout)().scroll_by(delta_left=0.0, delta_top=step),
  )
  self.extend_selection_at(
    self.selection_autoscroll_x,
    self.selection_autoscroll_y,
  )
  self.schedule_selection_autoscroll()
}

///|
/// Ends an in-progress selection drag (document `mouseup`).
pub fn MouseHandler::finish_selection(self : MouseHandler) -> Unit {
  if !self.selection_dragging {
    return
  }
  self.selection_dragging = false
  self.selection_autoscroll_active = false
  (self.helper.schedule_render)()
}

///|
/// Cancels an in-progress selection drag without a repaint, for viewer
/// lifecycle resets (model change/clear). The autoscroll loop self-cancels on
/// its next tick once `selection_dragging` is false.
pub fn MouseHandler::cancel_selection(self : MouseHandler) -> Unit {
  self.selection_dragging = false
}

///|
/// The view position a drag should extend the selection to, for any target that
/// resolves to a line (content, below-content, or the line-number gutter).
fn drag_view_position(
  target : @viewer_common.MouseTarget,
) -> @base_common.Position? {
  match target.kind {
    ContentText
    | ContentEmpty
    | BelowContent
    | GutterLineNumbers
    | GutterLineDecorations =>
      if target.line_number >= 1 {
        Some(Position(target.line_number, target.column + 1))
      } else {
        None
      }
    _ => None
  }
}

// === Scroll / scrollbar interaction (Monaco ScrollableElement pointer input) ===

///|
/// Wires one scrollable element's scrollbar interactions: reveal-on-hover and
/// thumb/track drags. Shared by the editor scrollbar and the hover widget
/// scrollbar (Monaco's `ScrollableElement` pointer handling).
pub fn MouseHandler::hook_scrollable_scrollbar_input(
  self : MouseHandler,
  scrollable : @scrollbar.ScrollableElementDom,
  owner : @scrollbar.ScrollableElementOwner,
) -> Unit {
  scrollable.wrapper.add_event_listener("mouseover", _ => {
    scrollable.mouse_entered()
  })
  scrollable.wrapper.add_event_listener("mousemove", _ => {
    scrollable.mouse_entered()
  })
  scrollable.wrapper.add_event_listener("mouseleave", _ => {
    scrollable.mouse_left()
  })
  scrollable
  .slider(true)
  .add_event_listener("mousedown", event => {
    match event.to_mouse_event() {
      Some(mouse) => {
        event.prevent_default()
        event.stop_propagation()
        self.start_scrollable_drag(scrollable, owner, vertical=true, mouse)
      }
      None => ()
    }
  })
  scrollable
  .slider(false)
  .add_event_listener("mousedown", event => {
    match event.to_mouse_event() {
      Some(mouse) => {
        event.prevent_default()
        event.stop_propagation()
        self.start_scrollable_drag(scrollable, owner, vertical=false, mouse)
      }
      None => ()
    }
  })
  scrollable
  .track(true)
  .add_event_listener("mousedown", event => {
    match event.to_mouse_event() {
      Some(mouse) => {
        event.prevent_default()
        event.stop_propagation()
        self.scrollable_track_jump(scrollable, owner, vertical=true, mouse)
      }
      None => ()
    }
  })
  scrollable
  .track(false)
  .add_event_listener("mousedown", event => {
    match event.to_mouse_event() {
      Some(mouse) => {
        event.prevent_default()
        event.stop_propagation()
        self.scrollable_track_jump(scrollable, owner, vertical=false, mouse)
      }
      None => ()
    }
  })
}

///|
/// Wheel delta normalization is shared with widget scrollables: line and
/// page delta modes scale to pixels; pixel deltas pass through.
pub fn MouseHandler::handle_editor_wheel(
  self : MouseHandler,
  wheel : @rdom.WheelEvent,
) -> Unit {
  let (delta_left, delta_top) = @scrollbar.normalized_wheel_delta(
    wheel,
    (self.helper.line_height)(),
    (self.helper.view_layout)().dimensions().height,
  )
  (self.helper.apply_scroll)(
    (self.helper.view_layout)().scroll_by(delta_left~, delta_top~),
  )
}

///|
fn MouseHandler::start_scrollable_drag(
  self : MouseHandler,
  scrollable : @scrollbar.ScrollableElementDom,
  owner : @scrollbar.ScrollableElementOwner,
  vertical~ : Bool,
  mouse : @rdom.MouseEvent,
) -> Unit {
  scrollable.drag_started()
  self.drag = Some({
    owner,
    vertical,
    start_coord: @scrollbar.drag_coord(mouse, vertical),
    start_slider: scrollable.state(vertical).slider_position(),
  })
  scrollable.set_slider_active(vertical~, true)
}

///|
/// Ends an in-progress thumb drag (document `mouseup`).
pub fn MouseHandler::end_scrollable_drag(self : MouseHandler) -> Unit {
  match self.drag {
    Some(drag) =>
      match self.scrollable_for_drag(drag.owner) {
        Some(scrollable) => {
          scrollable.set_slider_active(vertical=drag.vertical, false)
          scrollable.drag_ended()
        }
        None => ()
      }
    None => ()
  }
  self.drag = None
}

///|
/// Applies an in-progress thumb drag (document `mousemove`).
pub fn MouseHandler::handle_scrollable_drag_move(
  self : MouseHandler,
  event : @rdom.Event,
) -> Unit {
  guard self.drag is Some(drag) else { return }
  guard event.to_mouse_event() is Some(mouse) else { return }
  event.prevent_default()
  let delta = @scrollbar.drag_coord(mouse, drag.vertical) - drag.start_coord
  guard self.scrollable_for_drag(drag.owner) is Some(scrollable) else {
    self.drag = None
    return
  }
  let desired = scrollable
    .state(drag.vertical)
    .desired_position_from_slider(drag.start_slider + delta)
  self.apply_scrollable_position(
    scrollable,
    drag.owner,
    vertical=drag.vertical,
    desired,
  )
}

///|
/// A mousedown on the track (outside the thumb, which stops propagation)
/// uses Monaco's editor default `scrollByPage: false`: jump so the thumb
/// centers on the pointer.
fn MouseHandler::scrollable_track_jump(
  self : MouseHandler,
  scrollable : @scrollbar.ScrollableElementDom,
  owner : @scrollbar.ScrollableElementOwner,
  vertical~ : Bool,
  mouse : @rdom.MouseEvent,
) -> Unit {
  let desired = scrollable.desired_position_from_track(vertical~, mouse)
  self.apply_scrollable_position(scrollable, owner, vertical~, desired)
}

///|
fn MouseHandler::apply_scrollable_position(
  self : MouseHandler,
  scrollable : @scrollbar.ScrollableElementDom,
  owner : @scrollbar.ScrollableElementOwner,
  vertical~ : Bool,
  desired : Double,
) -> Unit {
  match owner {
    EditorScrollableElement =>
      if vertical {
        (self.helper.apply_scroll)(
          (self.helper.view_layout)().scroll_to(scroll_top=desired),
        )
      } else {
        let position = (self.helper.view_layout)().position()
        (self.helper.apply_scroll)(
          (self.helper.view_layout)().scroll_to(
            scroll_top=position.scroll_top,
            scroll_left=desired,
          ),
        )
      }
    HoverScrollableElement => scrollable.native_scroll_to(vertical~, desired)
  }
}

///|
fn MouseHandler::scrollable_for_drag(
  self : MouseHandler,
  owner : @scrollbar.ScrollableElementOwner,
) -> @scrollbar.ScrollableElementDom? {
  match owner {
    EditorScrollableElement => Some(self.helper.editor_scrollable)
    HoverScrollableElement => (self.helper.hover_scrollable)()
  }
}

///|
/// Wires the browser-driven reveal listeners: when focus or the browser mutates
/// a DOM scroll offset, the delta is translated into the model and the DOM
/// offset reset (Monaco's editor scrollbar bridge).
pub fn MouseHandler::hook_browser_desperate_reveal(self : MouseHandler) -> Unit {
  let editor_scrollable = self.helper.editor_scrollable
  self.helper.view_root.add_event_listener("scroll", _ => {
    self.handle_browser_desperate_reveal(
      self.helper.view_root,
      look_at_scroll_top=true,
      look_at_scroll_left=true,
    )
  })
  self.helper.overflow_guard.add_event_listener("scroll", _ => {
    self.handle_browser_desperate_reveal(
      self.helper.overflow_guard,
      look_at_scroll_top=true,
      look_at_scroll_left=false,
    )
  })
  editor_scrollable.content.add_event_listener("scroll", _ => {
    self.handle_browser_desperate_reveal(
      editor_scrollable.content,
      look_at_scroll_top=true,
      look_at_scroll_left=false,
    )
  })
  editor_scrollable.wrapper.add_event_listener("scroll", _ => {
    self.handle_browser_desperate_reveal(
      editor_scrollable.wrapper,
      look_at_scroll_top=true,
      look_at_scroll_left=false,
    )
  })
}

///|
/// Mirrors Monaco's editor scrollbar bridge for browser-driven reveal:
/// when focus or the browser mutates a DOM scroll offset, translate that
/// delta into the model and reset the DOM offset to zero.
fn MouseHandler::handle_browser_desperate_reveal(
  self : MouseHandler,
  element : @rdom.Element,
  look_at_scroll_top~ : Bool,
  look_at_scroll_left~ : Bool,
) -> Unit {
  let mut delta_top = 0.0
  let mut delta_left = 0.0
  if look_at_scroll_top {
    delta_top = element.get_scroll_top()
    if delta_top != 0.0 {
      element.set_scroll_top(0.0)
    }
  }
  if look_at_scroll_left {
    delta_left = element.get_scroll_left()
    if delta_left != 0.0 {
      element.set_scroll_left(0.0)
    }
  }
  if delta_top != 0.0 || delta_left != 0.0 {
    (self.helper.apply_scroll)(
      (self.helper.view_layout)().scroll_by(delta_left~, delta_top~),
    )
  } else {
    ()
  }
}
