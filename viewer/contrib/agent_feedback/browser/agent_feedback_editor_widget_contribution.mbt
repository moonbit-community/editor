///|
/// The per-editor state of `AgentFeedbackEditorWidgetContribution`
/// (`agentFeedbackEditorWidgetContribution.ts:1034-1311`), reached through
/// the instance table below (`docs/architecture.md`, "Controller access").
/// The `Viewer::` glue in `agent_feedback_widgets_host.mbt` keeps the
/// rebuild/layout role and reads/writes state here. Field names follow the
/// source; the widget id pool and the highlight id array are glue-side
/// bookkeeping kept from the port.
pub(all) struct AgentFeedbackEditorWidgetContribution {
  /// `_widgets`: the mounted bubbles.
  widgets : Array[AgentFeedbackEditorWidget]
  /// `_replyDraftState`: reply drafts surviving rebuilds, by comment id.
  reply_drafts : Map[String, String]
  /// The overlay-widget id pool for mounted bubbles.
  mut widget_id_pool : Int
  /// The item-hover range highlight (`_highlightRange`), as owner-scoped
  /// decoration ids.
  mut highlight_decoration_ids : Array[String]
}

///|
/// Per-editor instances keyed by `viewer.get_id()`.
let widget_instances : Map[String, AgentFeedbackEditorWidgetContribution] = {}

///|
pub fn AgentFeedbackEditorWidgetContribution::attach(
  editor_id : String,
) -> AgentFeedbackEditorWidgetContribution {
  let controller : AgentFeedbackEditorWidgetContribution = {
    widgets: [],
    reply_drafts: {},
    widget_id_pool: 1,
    highlight_decoration_ids: [],
  }
  widget_instances[editor_id] = controller
  controller
}

///|
pub fn AgentFeedbackEditorWidgetContribution::get(
  editor_id : String,
) -> AgentFeedbackEditorWidgetContribution? {
  widget_instances.get(editor_id)
}

///|
pub fn AgentFeedbackEditorWidgetContribution::detach(
  editor_id : String,
) -> Unit {
  widget_instances.remove(editor_id)
}

///|
/// Drops the per-model decoration bookkeeping on a model swap: the
/// range-highlight ids belong to the outgoing model's storage.
pub fn AgentFeedbackEditorWidgetContribution::reset_model_state(
  self : AgentFeedbackEditorWidgetContribution,
) -> Unit {
  self.highlight_decoration_ids = []
}
