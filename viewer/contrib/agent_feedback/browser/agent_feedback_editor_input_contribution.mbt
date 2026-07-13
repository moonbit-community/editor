///|
/// The per-editor state of `AgentFeedbackEditorInputContribution`
/// (`agentFeedbackEditorInputContribution.ts`), reached through the instance
/// table below — the `getContribution(id)` analog documented in
/// `docs/architecture.md` ("Controller access"). The `Viewer::` glue in
/// `agent_feedback_host.mbt` keeps the wiring role (the foreign-method rule
/// pins it to the root package) and reads/writes state here. Field names
/// follow the source members; deviations kept from the glue: the reserved
/// gutter lane stores the host's base width (`lane_base_width`, the source's
/// boolean `_reservedGutterSpace` plus the restore value), the hover line
/// uses a `-1` sentinel, and the hover decoration collection is an id array.
pub(all) struct AgentFeedbackEditorInputContribution {
  /// `_widget`: the lazily-created inline input widget.
  mut widget : AgentFeedbackInputWidget?
  /// `_visible`.
  mut visible : Bool
  /// `_pinnedRange`.
  mut pinned_range : @base_common.Range?
  /// `_anchorPosition`.
  mut anchor_position : @base_common.Position?
  /// `_preferBelow`.
  mut prefer_below : Bool
  /// `_hoverLineNumber` (`-1` for none).
  mut hover_line_number : Int
  /// `_hoverDecorations`, as owner-scoped decoration ids.
  mut hover_decoration_ids : Array[String]
  /// `_reservedGutterSpace`, storing the base `line_decorations_width` to
  /// restore (`Some` while the lane is reserved).
  mut lane_base_width : Int?
  /// `_mouseDown`.
  mut mouse_down : Bool
  /// `_suppressSelectionChangeOnce`.
  mut suppress_selection_change_once : Bool
}

///|
/// Per-editor instances keyed by `viewer.get_id()` — the WeakMap/
/// `getContribution` analog. Populated by the contribution's ctor, cleared
/// by its dispose.
let input_instances : Map[String, AgentFeedbackEditorInputContribution] = Map([])

///|
pub fn AgentFeedbackEditorInputContribution::attach(
  editor_id : String,
) -> AgentFeedbackEditorInputContribution {
  let controller : AgentFeedbackEditorInputContribution = {
    widget: None,
    visible: false,
    pinned_range: None,
    anchor_position: None,
    prefer_below: true,
    hover_line_number: -1,
    hover_decoration_ids: [],
    lane_base_width: None,
    mouse_down: false,
    suppress_selection_change_once: false,
  }
  input_instances[editor_id] = controller
  controller
}

///|
pub fn AgentFeedbackEditorInputContribution::get(
  editor_id : String,
) -> AgentFeedbackEditorInputContribution? {
  input_instances.get(editor_id)
}

///|
pub fn AgentFeedbackEditorInputContribution::detach(editor_id : String) -> Unit {
  input_instances.remove(editor_id)
}

///|
/// Drops the per-model decoration bookkeeping on a model swap: the hover
/// glyph's decoration ids belong to the outgoing model's storage.
pub fn AgentFeedbackEditorInputContribution::reset_model_state(
  self : AgentFeedbackEditorInputContribution,
) -> Unit {
  self.hover_decoration_ids = []
  self.hover_line_number = -1
}
