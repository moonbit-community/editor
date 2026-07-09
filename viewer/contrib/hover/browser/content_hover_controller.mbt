///|
/// Monaco `ContentHoverController` (`contentHoverController.ts`): the
/// per-editor hover feature state, reached through the instance table below —
/// the `ContentHoverController.get(editor)` / `getContribution(id)` analog
/// documented in `docs/architecture.md` ("Controller access"). The `Viewer::`
/// glue in `editor_events.mbt` keeps the dispatch role (the foreign-method
/// rule pins it to the root package) and reads/writes state here.
pub(all) struct ContentHoverController {
  /// The shown-hover state machine (anchor, operation, derived view).
  mut hover : @hover.HoverController
  /// Mouse-move grace state (Monaco's `_reactToEditorMouseMoveRunner`):
  /// while a hover widget is on screen, a move off the anchor is deferred by
  /// `hiding_delay` instead of reacting immediately, so the pointer can
  /// reach the widget. `hover_react_token` invalidates a deferred reaction
  /// the pointer cancelled by entering the widget.
  mut hover_react_pending : Bool
  mut hover_react_token : Int
  mut hover_pending_target : @editor_browser.MouseTarget?
  /// The `editor.hover` snapshot (`_hoverSettings`).
  hover_settings : @hover.HoverSettings
  /// `shouldKeepOpenOnEditorMouseMoveOrLeave`.
  mut hover_keep_open : Bool
  /// `_ignoreMouseEvents`: suppresses every handler while a context menu is
  /// up.
  mut hover_ignore_mouse_events : Bool
  /// The last pointer client position + modifiers (`_mouseMoveEvent`), so
  /// `_isMouseOnContentHoverWidget` / `shouldShowHover` can be evaluated
  /// where the controller reacts (the pointer-handler seam only carries a
  /// hit target).
  mut hover_mouse_posx : Double
  mut hover_mouse_posy : Double
  mut hover_last_modifiers : @hover.EventModifiers
  /// Monaco `RenderedContentHover`'s mouse-getting-closer state
  /// (`isMouseGettingCloser`): reset whenever a new hover view is shown, so
  /// a sticky hover the pointer is approaching is kept open even off the
  /// anchor token.
  hover_mouse_closer : @hover.MouseCloserState
  /// The last anchor token for which the public hover-resolution status
  /// fired, so it fires exactly once per anchor when the operation completes.
  mut hover_notified_token : Int
  /// The hover highlight's model decoration ids (the hover-owned decorations
  /// collection): rewritten whenever the hover view's highlighted range
  /// changes.
  mut hover_decoration_ids : Array[String]
  mut hover_decoration_range : @base_common.Range?
}

///|
/// Per-editor controller instances keyed by `viewer.get_id()` — the
/// WeakMap/`getContribution` analog from `docs/architecture.md`
/// ("Controller access"). Populated by the hover contribution's ctor,
/// cleared by its dispose.
let instances : Map[String, ContentHoverController] = {}

///|
/// Constructs the controller for an editor and registers it in the instance
/// table — the contribution-ctor half of Monaco's
/// `registerEditorContribution(ContentHoverController.ID, …)`.
pub fn ContentHoverController::attach(
  editor_id : String,
) -> ContentHoverController {
  let controller : ContentHoverController = {
    hover: @hover.HoverController::empty(),
    hover_react_pending: false,
    hover_react_token: 0,
    hover_pending_target: None,
    hover_settings: @hover.HoverSettings::defaults(),
    hover_keep_open: false,
    hover_ignore_mouse_events: false,
    hover_mouse_posx: 0.0,
    hover_mouse_posy: 0.0,
    hover_last_modifiers: @hover.EventModifiers::none(),
    hover_mouse_closer: @hover.MouseCloserState::new(),
    hover_notified_token: 0,
    hover_decoration_ids: [],
    hover_decoration_range: None,
  }
  instances[editor_id] = controller
  controller
}

///|
/// The live controller instance for an editor — Monaco's
/// `ContentHoverController.get(editor)`. `None` after dispose.
pub fn ContentHoverController::get(
  editor_id : String,
) -> ContentHoverController? {
  instances.get(editor_id)
}

///|
/// Removes the instance — the contribution's dispose.
pub fn ContentHoverController::detach(editor_id : String) -> Unit {
  instances.remove(editor_id)
}

///|
/// Cancels any deferred mouse-move reaction (Monaco's
/// `_reactToEditorMouseMoveRunner.cancel()`). Bumping the token invalidates a
/// timer that is already in flight.
pub fn ContentHoverController::cancel_react(
  self : ContentHoverController,
) -> Unit {
  self.hover_react_token += 1
  self.hover_react_pending = false
  self.hover_pending_target = None
}

///|
/// Records the latest pointer client position and modifier flags so the
/// handlers — which run from the pointer-handler seam that only carries a
/// hit target — can evaluate `_isMouseOnContentHoverWidget` and
/// `shouldShowHover`.
pub fn ContentHoverController::record_pointer(
  self : ContentHoverController,
  posx : Double,
  posy : Double,
  modifiers : @hover.EventModifiers,
) -> Unit {
  self.hover_mouse_posx = posx
  self.hover_mouse_posy = posy
  self.hover_last_modifiers = modifiers
}

///|
/// Drops the per-model decoration bookkeeping on a model swap: the ids
/// belong to the outgoing model's decoration storage.
pub fn ContentHoverController::reset_model_state(
  self : ContentHoverController,
) -> Unit {
  self.hover_decoration_ids = []
  self.hover_decoration_range = None
}
