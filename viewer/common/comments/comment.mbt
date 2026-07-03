// The comment data model, ported from the comment shapes in
// `vscode/src/vs/editor/common/languages.ts` (`Comment`, `CommentThread`,
// `CommentThreadCollapsibleState`), trimmed to the viewer's scope: no
// provider/owner handles, no replies, no reactions, no resolved state, no
// editing mode enum (edit state lives in the widget). This common-tier
// package matches Monaco's filing for the types; the `CommentService` lives
// with its feature in `viewer/contrib/comments` (Monaco:
// `workbench/contrib/comments/browser/commentService.ts`).

///|
/// `CommentThreadCollapsibleState` (`languages.ts`): whether the thread's
/// zone widget is open.
pub(all) enum CommentThreadCollapsibleState {
  Collapsed
  Expanded
} derive(Eq, Debug)

///|
/// One comment in a thread — `Comment` (`languages.ts`) trimmed to
/// `uniqueIdInThread`/`body`/`userName`/`timestamp`. `body` is markdown
/// source; the widget renders it with the shared cmark pipeline.
pub(all) struct Comment {
  unique_id_in_thread : Int
  body : String
  user_name : String
  timestamp : String?
} derive(Eq, Debug)

///|
/// A comment thread anchored to a model range — `CommentThread`
/// (`languages.ts`) trimmed. `range` is in model coordinates; the thread
/// renders at `range.start_line_number` and the root glue converts to view
/// lines when it opens a widget. `is_template` marks a zero-comment thread
/// created from the gutter that is still showing the new-comment form
/// (`isTemplate` on Monaco's thread; discarded on cancel, made real by the
/// first submitted comment).
pub(all) struct CommentThread {
  thread_id : String
  resource : @base_common.Uri
  range : @base_common.Range
  comments : Array[Comment]
  mut collapsible_state : CommentThreadCollapsibleState
  mut is_template : Bool
} derive(Debug)
