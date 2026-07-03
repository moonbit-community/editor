// The comment data hub, porting the store/pub-sub role of
// `vscode/src/vs/workbench/contrib/comments/browser/commentService.ts`
// (`setDocumentComments`, `createCommentThreadTemplate`,
// `onDidUpdateCommentThreads`, `updateCommentingRanges`) in the
// `viewer/common/markers` service style: resources keyed by
// `uri.to_string()`, `@base_common.Emitter` events, host-facing setters plus
// controller-facing mutations. Multi-provider/owner plumbing, replies,
// reactions, and resolved state are out of scope; comment mutations
// (create/update/delete) are applied to the store directly and reported
// through dedicated events so the host can persist them.
//
// Filed with its feature, mirroring Monaco: the service lives in the comments
// contrib (Monaco: `workbench/contrib/comments/browser/commentService.ts`),
// while the thread/comment types stay in `viewer/common/comments` (Monaco:
// `editor/common/languages.ts`). The service is DOM-free, so this package
// stays multi-target.

///|
/// `ICommentThreadChangedEvent` reduced to one resource and the
/// added/removed/changed thread lists.
pub(all) struct CommentThreadChangedEvent {
  resource : @base_common.Uri
  added : Array[@comments_common.CommentThread]
  removed : Array[@comments_common.CommentThread]
  changed : Array[@comments_common.CommentThread]
} derive(Debug)

///|
/// A single applied comment mutation, for host persistence: the thread it
/// happened in and the comment that was created/updated/deleted.
pub(all) struct CommentMutationEvent {
  thread : @comments_common.CommentThread
  comment : @comments_common.Comment
} derive(Debug)

///|
/// The comment store shared by the host app and the viewer's comment
/// controller, handed in through `ViewerServices`.
pub struct CommentService {
  did_update_comment_threads : @base_common.Emitter[CommentThreadChangedEvent]
  did_change_commenting_ranges : @base_common.Emitter[@base_common.Uri]
  did_create_comment : @base_common.Emitter[CommentMutationEvent]
  did_update_comment : @base_common.Emitter[CommentMutationEvent]
  did_delete_comment : @base_common.Emitter[CommentMutationEvent]
  threads_by_resource : Map[String, Array[@comments_common.CommentThread]]
  ranges_by_resource : Map[String, Array[@base_common.Range]]
  mut next_thread_handle : Int
  /// The author name stamped on comments created inside the viewer. VS Code
  /// gets the identity from the comment provider; the viewer has no
  /// provider, so the host sets it (viewer-specific glue).
  mut current_user_name : String
}

///|
/// Creates an empty comment store.
pub fn CommentService::new() -> CommentService {
  {
    did_update_comment_threads: @base_common.Emitter::new(),
    did_change_commenting_ranges: @base_common.Emitter::new(),
    did_create_comment: @base_common.Emitter::new(),
    did_update_comment: @base_common.Emitter::new(),
    did_delete_comment: @base_common.Emitter::new(),
    threads_by_resource: {},
    ranges_by_resource: {},
    next_thread_handle: 1,
    current_user_name: "You",
  }
}

///|
pub fn CommentService::dispose(self : CommentService) -> Unit {
  self.did_update_comment_threads.dispose()
  self.did_change_commenting_ranges.dispose()
  self.did_create_comment.dispose()
  self.did_update_comment.dispose()
  self.did_delete_comment.dispose()
}

// --- subscriptions -----------------------------------------------------------

///|
/// `onDidUpdateCommentThreads` (`commentService.ts`).
pub fn CommentService::on_did_update_comment_threads(
  self : CommentService,
  listener : (CommentThreadChangedEvent) -> Unit,
) -> @base_common.Disposable {
  self.did_update_comment_threads.event(listener)
}

///|
/// `onDidUpdateCommentingRanges` (`commentService.ts`).
pub fn CommentService::on_did_change_commenting_ranges(
  self : CommentService,
  listener : (@base_common.Uri) -> Unit,
) -> @base_common.Disposable {
  self.did_change_commenting_ranges.event(listener)
}

///|
/// Fired after a comment created inside the viewer lands in the store; the
/// host persists it.
pub fn CommentService::on_did_create_comment(
  self : CommentService,
  listener : (CommentMutationEvent) -> Unit,
) -> @base_common.Disposable {
  self.did_create_comment.event(listener)
}

///|
/// Fired after an in-viewer comment edit is applied.
pub fn CommentService::on_did_update_comment(
  self : CommentService,
  listener : (CommentMutationEvent) -> Unit,
) -> @base_common.Disposable {
  self.did_update_comment.event(listener)
}

///|
/// Fired after an in-viewer comment delete is applied (also when the delete
/// removed the whole thread).
pub fn CommentService::on_did_delete_comment(
  self : CommentService,
  listener : (CommentMutationEvent) -> Unit,
) -> @base_common.Disposable {
  self.did_delete_comment.event(listener)
}

// --- host-facing state --------------------------------------------------------

///|
/// The display name stamped on comments created inside the viewer.
pub fn CommentService::set_current_user_name(
  self : CommentService,
  user_name : String,
) -> Unit {
  self.current_user_name = user_name
}

///|
/// Replaces a resource's threads — `setDocumentComments` collapsed to a full
/// replace; the event reports the id-diff against the previous set.
pub fn CommentService::set_comment_threads(
  self : CommentService,
  resource : @base_common.Uri,
  threads : Array[@comments_common.CommentThread],
) -> Unit {
  let key = resource.to_string()
  let previous = match self.threads_by_resource.get(key) {
    Some(existing) => existing
    None => []
  }
  let added : Array[@comments_common.CommentThread] = []
  let removed : Array[@comments_common.CommentThread] = []
  let changed : Array[@comments_common.CommentThread] = []
  for thread in threads {
    if previous.search_by(p => p.thread_id == thread.thread_id) is Some(_) {
      changed.push(thread)
    } else {
      added.push(thread)
    }
  }
  for thread in previous {
    if threads.search_by(n => n.thread_id == thread.thread_id) is None {
      removed.push(thread)
    }
  }
  self.threads_by_resource.set(key, threads)
  self.did_update_comment_threads.fire({ resource, added, removed, changed })
}

///|
/// Replaces a resource's commenting ranges — the trimmed
/// `updateCommentingRanges`: the line ranges whose gutter offers the "+"
/// affordance.
pub fn CommentService::set_commenting_ranges(
  self : CommentService,
  resource : @base_common.Uri,
  ranges : Array[@base_common.Range],
) -> Unit {
  self.ranges_by_resource.set(resource.to_string(), ranges)
  self.did_change_commenting_ranges.fire(resource)
}

///|
/// The stored threads for a resource. The array is live service state;
/// mutations go through the service methods so events fire.
pub fn CommentService::threads(
  self : CommentService,
  resource : @base_common.Uri,
) -> Array[@comments_common.CommentThread] {
  match self.threads_by_resource.get(resource.to_string()) {
    Some(threads) => threads
    None => []
  }
}

///|
/// The stored commenting ranges for a resource.
pub fn CommentService::commenting_ranges(
  self : CommentService,
  resource : @base_common.Uri,
) -> Array[@base_common.Range] {
  match self.ranges_by_resource.get(resource.to_string()) {
    Some(ranges) => ranges
    None => []
  }
}

///|
/// Finds a thread by id across resources.
pub fn CommentService::thread_by_id(
  self : CommentService,
  thread_id : String,
) -> @comments_common.CommentThread? {
  for _, threads in self.threads_by_resource {
    match threads.search_by(t => t.thread_id == thread_id) {
      Some(index) => return Some(threads[index])
      None => ()
    }
  }
  None
}

// --- controller-facing mutations ----------------------------------------------

///|
/// `createCommentThreadTemplate` (`commentService.ts:387`): an expanded,
/// zero-comment thread over `range` (a single line for a gutter click, a
/// multi-line span for a gutter drag or a commented text selection) that
/// shows the new-comment form. Discarded by `discard_template`, made real by
/// `submit_new_comment`.
pub fn CommentService::create_thread_template(
  self : CommentService,
  resource : @base_common.Uri,
  range : @base_common.Range,
) -> @comments_common.CommentThread {
  let thread : @comments_common.CommentThread = {
    thread_id: "viewer-thread-" + self.next_thread_handle.to_string(),
    resource,
    range,
    comments: [],
    collapsible_state: Expanded,
    is_template: true,
  }
  self.next_thread_handle += 1
  let key = resource.to_string()
  let threads = match self.threads_by_resource.get(key) {
    Some(existing) => existing
    None => {
      let created : Array[@comments_common.CommentThread] = []
      self.threads_by_resource.set(key, created)
      created
    }
  }
  threads.push(thread)
  self.did_update_comment_threads.fire({
    resource,
    added: [thread],
    removed: [],
    changed: [],
  })
  thread
}

///|
/// Removes a still-empty template thread (Escape/cancel in the new-comment
/// form). Threads with comments are unaffected.
pub fn CommentService::discard_template(
  self : CommentService,
  thread_id : String,
) -> Unit {
  guard self.thread_by_id(thread_id) is Some(thread) else { return }
  guard thread.is_template && thread.comments.is_empty() else { return }
  self.remove_thread(thread)
  self.did_update_comment_threads.fire({
    resource: thread.resource,
    added: [],
    removed: [thread],
    changed: [],
  })
}

///|
/// Submits the new-comment form: appends the thread's first comment (stamped
/// with `current_user_name`), makes a template thread real, and reports the
/// creation for host persistence.
pub fn CommentService::submit_new_comment(
  self : CommentService,
  thread_id : String,
  body : String,
  timestamp? : String,
) -> Unit {
  guard self.thread_by_id(thread_id) is Some(thread) else { return }
  let mut max_id = 0
  for comment in thread.comments {
    if comment.unique_id_in_thread > max_id {
      max_id = comment.unique_id_in_thread
    }
  }
  let comment : @comments_common.Comment = {
    unique_id_in_thread: max_id + 1,
    body,
    user_name: self.current_user_name,
    timestamp,
  }
  thread.comments.push(comment)
  thread.is_template = false
  self.did_create_comment.fire({ thread, comment })
  self.did_update_comment_threads.fire({
    resource: thread.resource,
    added: [],
    removed: [],
    changed: [thread],
  })
}

///|
/// Applies an in-widget edit to a comment's body and reports it for host
/// persistence.
pub fn CommentService::update_comment(
  self : CommentService,
  thread_id : String,
  unique_id_in_thread : Int,
  body : String,
) -> Unit {
  guard self.thread_by_id(thread_id) is Some(thread) else { return }
  guard thread.comments.search_by(c => {
      c.unique_id_in_thread == unique_id_in_thread
    })
    is Some(index) else {
    return
  }
  let updated : @comments_common.Comment = { ..thread.comments[index], body, }
  thread.comments[index] = updated
  self.did_update_comment.fire({ thread, comment: updated })
  self.did_update_comment_threads.fire({
    resource: thread.resource,
    added: [],
    removed: [],
    changed: [thread],
  })
}

///|
/// Deletes a comment; deleting the last comment removes the thread (and its
/// gutter glyph). Both outcomes fire `did_delete_comment` for persistence.
pub fn CommentService::delete_comment(
  self : CommentService,
  thread_id : String,
  unique_id_in_thread : Int,
) -> Unit {
  guard self.thread_by_id(thread_id) is Some(thread) else { return }
  guard thread.comments.search_by(c => {
      c.unique_id_in_thread == unique_id_in_thread
    })
    is Some(index) else {
    return
  }
  let comment = thread.comments.remove(index)
  self.did_delete_comment.fire({ thread, comment })
  if thread.comments.is_empty() {
    self.remove_thread(thread)
    self.did_update_comment_threads.fire({
      resource: thread.resource,
      added: [],
      removed: [thread],
      changed: [],
    })
  } else {
    self.did_update_comment_threads.fire({
      resource: thread.resource,
      added: [],
      removed: [],
      changed: [thread],
    })
  }
}

///|
fn CommentService::remove_thread(
  self : CommentService,
  thread : @comments_common.CommentThread,
) -> Unit {
  let key = thread.resource.to_string()
  guard self.threads_by_resource.get(key) is Some(threads) else { return }
  match threads.search_by(t => t.thread_id == thread.thread_id) {
    Some(index) => {
      threads.remove(index) |> ignore
      if threads.is_empty() {
        self.threads_by_resource.remove(key)
      }
    }
    None => ()
  }
}
