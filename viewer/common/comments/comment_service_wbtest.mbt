// Behavior tests for the trimmed comment service (`comment_service.mbt`).
// Upstream ships no unit tests for `commentService.ts`'s store role; these
// cover the replace-diff, the template lifecycle, and each mutation event.

///|
fn uri(value : String) -> @base_common.Uri {
  match @base_common.Uri::parse(value) {
    ParsedUri(u) => u
    UriError(_) => abort("bad test uri: " + value)
  }
}

///|
fn host_thread(
  id : String,
  resource : @base_common.Uri,
  line : Int,
  bodies : Array[String],
) -> CommentThread {
  let comments : Array[Comment] = []
  for index in 0..<bodies.length() {
    comments.push({
      unique_id_in_thread: index + 1,
      body: bodies[index],
      user_name: "alice",
      timestamp: None,
    })
  }
  {
    thread_id: id,
    resource,
    range: Range(line, 1, line, 1),
    comments,
    collapsible_state: Collapsed,
    is_template: false,
  }
}

///|
test "set_comment_threads reports the id diff against the previous set" {
  let service = CommentService::new()
  let resource = uri("memory://review/a.mbt")
  let mut added = ""
  let mut removed = ""
  let mut changed = ""
  service.on_did_update_comment_threads(event => {
    added = event.added.map(t => t.thread_id).join(",")
    removed = event.removed.map(t => t.thread_id).join(",")
    changed = event.changed.map(t => t.thread_id).join(",")
  })
  |> ignore
  service.set_comment_threads(resource, [
    host_thread("t1", resource, 2, ["first"]),
    host_thread("t2", resource, 5, ["second"]),
  ])
  assert_eq(added, "t1,t2")
  assert_eq(removed, "")
  assert_eq(changed, "")
  service.set_comment_threads(resource, [
    host_thread("t2", resource, 5, ["second edited"]),
    host_thread("t3", resource, 9, ["third"]),
  ])
  assert_eq(added, "t3")
  assert_eq(removed, "t1")
  assert_eq(changed, "t2")
  assert_eq(service.threads(resource).length(), 2)
}

///|
test "commenting ranges are stored per resource and fire their event" {
  let service = CommentService::new()
  let resource = uri("memory://review/a.mbt")
  let mut fired = ""
  service.on_did_change_commenting_ranges(changed => fired = changed.to_string())
  |> ignore
  service.set_commenting_ranges(resource, [Range(1, 1, 10, 1)])
  assert_eq(fired, resource.to_string())
  assert_eq(service.commenting_ranges(resource).length(), 1)
  assert_eq(service.commenting_ranges(uri("memory://other.mbt")).length(), 0)
}

///|
test "template lifecycle: create, discard" {
  let service = CommentService::new()
  let resource = uri("memory://review/a.mbt")
  let template = service.create_thread_template(resource, Range(4, 1, 4, 1))
  assert_true(template.is_template)
  assert_eq(template.range.start_line_number, 4)
  assert_eq(service.threads(resource).length(), 1)
  service.discard_template(template.thread_id)
  assert_eq(service.threads(resource).length(), 0)
  // Discarding a thread that has comments is a no-op.
  service.set_comment_threads(resource, [
    host_thread("t1", resource, 2, ["kept"]),
  ])
  service.discard_template("t1")
  assert_eq(service.threads(resource).length(), 1)
}

///|
test "submit turns a template real and fires the create event" {
  let service = CommentService::new()
  let resource = uri("memory://review/a.mbt")
  service.set_current_user_name("bao")
  let template = service.create_thread_template(resource, Range(4, 1, 4, 1))
  let mut created_body = ""
  let mut created_author = ""
  service.on_did_create_comment(event => {
    created_body = event.comment.body
    created_author = event.comment.user_name
  })
  |> ignore
  service.submit_new_comment(
    template.thread_id,
    "looks good",
    timestamp="2026-07-03",
  )
  assert_false(template.is_template)
  assert_eq(template.comments.length(), 1)
  assert_eq(created_body, "looks good")
  assert_eq(created_author, "bao")
  assert_eq(template.comments[0].unique_id_in_thread, 1)
  assert_eq(template.comments[0].timestamp.unwrap(), "2026-07-03")
}

///|
test "update_comment rewrites the body and fires the update event" {
  let service = CommentService::new()
  let resource = uri("memory://review/a.mbt")
  service.set_comment_threads(resource, [
    host_thread("t1", resource, 2, ["first", "second"]),
  ])
  let mut updated = ""
  service.on_did_update_comment(event => updated = event.comment.body) |> ignore
  service.update_comment("t1", 2, "second, edited")
  assert_eq(updated, "second, edited")
  let thread = service.thread_by_id("t1").unwrap()
  assert_eq(thread.comments[1].body, "second, edited")
  assert_eq(thread.comments[1].user_name, "alice")
}

///|
test "delete_comment removes the comment; the last delete removes the thread" {
  let service = CommentService::new()
  let resource = uri("memory://review/a.mbt")
  service.set_comment_threads(resource, [
    host_thread("t1", resource, 2, ["first", "second"]),
  ])
  let mut deleted = 0
  let mut removed_threads = ""
  service.on_did_delete_comment(event => {
    deleted = event.comment.unique_id_in_thread
  })
  |> ignore
  service.on_did_update_comment_threads(event => {
    removed_threads = event.removed.map(t => t.thread_id).join(",")
  })
  |> ignore
  service.delete_comment("t1", 1)
  assert_eq(deleted, 1)
  assert_eq(removed_threads, "")
  assert_eq(service.thread_by_id("t1").unwrap().comments.length(), 1)
  service.delete_comment("t1", 2)
  assert_eq(deleted, 2)
  assert_eq(removed_threads, "t1")
  assert_true(service.thread_by_id("t1") is None)
  assert_eq(service.threads(resource).length(), 0)
}
