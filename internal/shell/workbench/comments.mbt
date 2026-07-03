// The workbench's host side of the comments contrib — the role VS Code's
// comment providers play: it declares every line of the open document
// commentable and owns persistence. The comment service reports in-viewer
// mutations (create/update/delete) through dedicated events; the workbench
// writes the affected resource's threads to localStorage and restores them
// on the resource's first open of the session.

///|
fn comments_storage_key(resource : @base_common.Uri) -> String {
  "readonly-editor:comments:" + resource.to_string()
}

///|
/// Threads restored from storage get ids in their own namespace so they can
/// never collide with the service's session-scoped `viewer-thread-N` ids.
let restored_thread_count : Ref[Int] = Ref(0)

///|
/// Subscribes the workbench to the comment service's mutation events and
/// writes the mutated resource's thread set back to localStorage.
fn install_comment_persistence(services : @viewer.ViewerServices) -> Unit {
  let persist = (event : @comments_contrib.CommentMutationEvent) => {
    persist_comment_threads(services, event.thread.resource)
  }
  services.comments.on_did_create_comment(persist) |> ignore
  services.comments.on_did_update_comment(persist) |> ignore
  services.comments.on_did_delete_comment(persist) |> ignore
}

///|
/// Declares the whole document commentable (the "+" gutter affordance on
/// every line) and restores any persisted threads. Runs on every model
/// install so a reload's new line count re-bounds the range.
fn sync_document_comments(text_model : @model.TextModel) -> Unit {
  let services = workbench_services()
  restore_comment_threads(services, text_model.uri)
  services.comments.set_commenting_ranges(text_model.uri, [
    Range(1, 1, text_model.snapshot.line_count(), 1),
  ])
}

///|
fn persist_comment_threads(
  services : @viewer.ViewerServices,
  resource : @base_common.Uri,
) -> Unit {
  let items : Array[Json] = []
  for thread in services.comments.threads(resource) {
    // Templates are unsubmitted new-comment forms: session state, not data.
    if thread.is_template || thread.comments.is_empty() {
      continue
    }
    items.push(comment_thread_to_json(thread))
  }
  storage_set_item(
    comments_storage_key(resource),
    Json::array(items).stringify(),
  )
}

///|
fn comment_thread_to_json(thread : @comments_common.CommentThread) -> Json {
  let comments : Array[Json] = []
  for comment in thread.comments {
    let fields : Map[String, Json] = {}
    fields["id"] = comment.unique_id_in_thread.to_json()
    fields["body"] = comment.body.to_json()
    fields["userName"] = comment.user_name.to_json()
    if comment.timestamp is Some(timestamp) {
      fields["timestamp"] = timestamp.to_json()
    }
    comments.push(Json::object(fields))
  }
  let fields : Map[String, Json] = {}
  fields["range"] = Json::array([
    thread.range.start_line_number.to_json(),
    thread.range.start_column.to_json(),
    thread.range.end_line_number.to_json(),
    thread.range.end_column.to_json(),
  ])
  fields["comments"] = Json::array(comments)
  Json::object(fields)
}

///|
/// Rebuilds a resource's threads from localStorage. Live service state wins:
/// restore only fills an empty store (the resource's first open this
/// session); after that the in-memory threads are the persisted set's
/// superset.
fn restore_comment_threads(
  services : @viewer.ViewerServices,
  resource : @base_common.Uri,
) -> Unit {
  guard services.comments.threads(resource).is_empty() else { return }
  let raw = storage_get_item(comments_storage_key(resource))
  guard raw != "" else { return }
  let parsed = @json.parse(raw) catch { _ => return }
  guard parsed is Array(items) else { return }
  let threads : Array[@comments_common.CommentThread] = []
  for item in items {
    if comment_thread_from_json(resource, item) is Some(thread) {
      threads.push(thread)
    }
  }
  guard !threads.is_empty() else { return }
  services.comments.set_comment_threads(resource, threads)
}

///|
fn comment_thread_from_json(
  resource : @base_common.Uri,
  value : Json,
) -> @comments_common.CommentThread? {
  guard value
    is {
      "range": Array(
        [Number(sl, ..), Number(sc, ..), Number(el, ..), Number(ec, ..)]
      ),
      "comments": Array(comment_items),
      ..
    } else {
    return None
  }
  let comments : Array[@comments_common.Comment] = []
  for item in comment_items {
    guard item
      is {
        "id": Number(id, ..),
        "body": String(body),
        "userName": String(user_name),
        ..
      } else {
      continue
    }
    let timestamp = if item is { "timestamp": String(timestamp), .. } {
      Some(timestamp)
    } else {
      None
    }
    comments.push({
      unique_id_in_thread: id.to_int(),
      body,
      user_name,
      timestamp,
    })
  }
  guard !comments.is_empty() else { return None }
  restored_thread_count.val += 1
  Some({
    thread_id: "workbench-restored-" + restored_thread_count.val.to_string(),
    resource,
    range: Range(sl.to_int(), sc.to_int(), el.to_int(), ec.to_int()),
    comments,
    collapsible_state: Collapsed,
    is_template: false,
  })
}
