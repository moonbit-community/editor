// The agent-feedback data model, ported from
// `vscode/src/vs/sessions/contrib/agentFeedback/browser/agentFeedbackModel.ts`
// (`AgentFeedbackKind`, `AgentFeedbackState`, `IAgentFeedback`), trimmed to
// the viewer's scope: no session resource (the store keys by the file
// resource directly), no PR-review kind or `sourcePRReviewCommentId` (the
// viewer has no PR machinery), no `suggestion` edits, no `codeSelection`/
// `diffHunks` context capture, and no `pendingAgentReveal` marker. Replies
// and the full lifecycle state machine are kept. Like upstream, the model is
// a leaf file so the service and future storage backends can share it.

///|
/// The origin of a feedback item — `AgentFeedbackKind` (`agentFeedbackModel.ts`)
/// minus `PRReview`. The string forms surfaced to the agent upstream map to:
/// `UserReview` = `'user'` (authored in the editor), `AgentReview` =
/// `'codeReview'` (seeded by the agent/host, e.g. an `addComment` tool).
pub(all) enum AgentFeedbackKind {
  UserReview
  AgentReview
} derive(Eq, Debug)

///|
/// Lifecycle state — `AgentFeedbackState` (`agentFeedbackModel.ts`). An item
/// is in exactly one state and progresses Created → Accepted → Submitted →
/// Resolved. `Created` items were added by a system (not yet user-accepted);
/// only `Accepted` items are submittable; `Resolved` items are hidden from
/// the editor UI.
pub(all) enum AgentFeedbackState {
  Created
  Accepted
  Submitted
  Resolved
} derive(Eq, Debug)

///|
/// One feedback item — `IAgentFeedback` (`agentFeedbackModel.ts`) trimmed.
/// `range` is in model coordinates. `text` is the initial comment; `replies`
/// are subsequent messages in the same thread about the same code region.
/// Items are value-shaped: mutations replace the stored item through the
/// service so change events fire (upstream's `backend.upsert({...existing})`
/// spread-copy style).
pub(all) struct AgentFeedback {
  id : String
  text : String
  resource : @base_common.Uri
  range : @base_common.Range
  kind : AgentFeedbackKind
  replies : Array[String]
  state : AgentFeedbackState
} derive(Debug)
