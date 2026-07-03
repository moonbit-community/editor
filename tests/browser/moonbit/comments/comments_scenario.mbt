// In-page scenario for the comments contrib: seeds the comment service with
// commenting ranges and a host-supplied two-comment thread, then asserts the
// gutter renders the range and thread glyphs. The interactive flow (gutter
// click → widget → submit/edit/delete, folding, scroll tracking) is driven by
// the paired Playwright spec (`tests/browser/component/comments.spec.js`)
// with real mouse/keyboard input; service mutation events are mirrored onto
// `#comment-events` data attributes so the spec can observe host-persistence
// facts after the report has finished.

///|
fn run_comments_test() -> Unit {
  let ctx = @support.BrowserTestContext::new("comments")
  let done = Ref(false)
  let uri = @base_common.Uri::memory("comments.mbt")
  let model = @model.TextModel(
    uri,
    "comments.mbt",
    "moonbit",
    1,
    "comments-rev-1",
    comments_source_text(),
  )
  match mount_host() {
    Some((host, event_log)) => {
      let services = @viewer.ViewerServices::new()
      // Consume the feature service through its contrib package directly —
      // the workbench-tier import class (the shell/tests reach viewer
      // internals the way VS Code's workbench reaches `vs/editor/**`).
      let comments : @comments_contrib.CommentService = services.comments
      comments.set_current_user_name("tester")
      let created = Ref(0)
      let updated = Ref(0)
      let deleted = Ref(0)
      let last_body : Ref[String] = Ref("")
      let write_log = () => {
        event_log.set_attribute("data-created", created.val.to_string())
        event_log.set_attribute("data-updated", updated.val.to_string())
        event_log.set_attribute("data-deleted", deleted.val.to_string())
        event_log.set_attribute("data-last-body", last_body.val)
      }
      comments.on_did_create_comment(event => {
        created.val = created.val + 1
        last_body.val = event.comment.body
        write_log()
      })
      |> ignore
      comments.on_did_update_comment(event => {
        updated.val = updated.val + 1
        last_body.val = event.comment.body
        write_log()
      })
      |> ignore
      comments.on_did_delete_comment(event => {
        deleted.val = deleted.val + 1
        last_body.val = event.comment.body
        write_log()
      })
      |> ignore
      write_log()
      // Seed the store before the model attaches: `set_model`'s comment sync
      // must pick the data up.
      comments.set_commenting_ranges(uri, [Range(1, 1, 6, 1)])
      comments.set_comment_threads(uri, [seed_thread(uri)])
      let viewer = @viewer.Viewer::create(
        host,
        services~,
        options=ViewerOptions(placeholder="Loading comments fixture..."),
      )
      viewer.set_model(Some(model))
      @support.set_timeout(() => poll_rendered(ctx, done, 80), 50)
    }
    None => {
      ctx.fail("missing #app mount point")
      ctx.finish()
    }
  }
}

///|
fn seed_thread(uri : @base_common.Uri) -> @comments_common.CommentThread {
  {
    thread_id: "seed-thread",
    resource: uri,
    range: Range(9, 1, 9, 1),
    comments: [
      {
        unique_id_in_thread: 1,
        body: "Host-supplied first comment",
        user_name: "alice",
        timestamp: Some("2026-07-01"),
      },
      {
        unique_id_in_thread: 2,
        body: "Host-supplied second comment",
        user_name: "bob",
        timestamp: Some("2026-07-02"),
      },
    ],
    collapsible_state: Collapsed,
    is_template: false,
  }
}

///|
fn poll_rendered(
  ctx : @support.BrowserTestContext,
  done : Ref[Bool],
  remaining : Int,
) -> Unit {
  if done.val {
    return
  }
  let range_glyphs = @support.query_count(
    ".lines-decorations .cldr.comment-range-glyph.comment-diff-added",
  )
  let thread_glyphs = @support.query_count(
    ".lines-decorations .cldr.comment-range-glyph.comment-thread",
  )
  if range_glyphs > 0 && thread_glyphs > 0 {
    ctx.assert_true(
      range_glyphs >= 6,
      "commenting range lines 1-6 did not all render lane pieces",
    )
    ctx.assert_true(
      thread_glyphs == 1,
      "expected exactly one thread glyph for the seed thread",
    )
    ctx.assert_true(
      @support.query_count(".review-widget") == 0,
      "a collapsed thread must not open its widget",
    )
    ctx.metric_int("rangeGlyphs", range_glyphs)
    ctx.metric_int("threadGlyphs", thread_glyphs)
    done.val = true
    ctx.finish()
  } else if remaining <= 0 {
    ctx.fail("timed out waiting for comment gutter glyphs")
    done.val = true
    ctx.finish()
  } else {
    @support.set_timeout(() => poll_rendered(ctx, done, remaining - 1), 50)
  }
}

///|
fn mount_host() -> (@rdom.Element, @rdom.Element)? {
  let document = @rdom.document()
  match document.query_selector("#app").to_option() {
    Some(app) => {
      let shell = document.create_element("main")
      shell.set_attribute("class", "editor-shell")
      shell.set_attribute("data-theme", "dark")
      shell.set_attribute("style", "height:100vh;display:block;")
      let host = document.create_element("div")
      host.set_attribute("class", "viewer-host")
      host.set_attribute("style", "height:360px;width:520px;")
      let event_log = document.create_element("div")
      event_log.set_attribute("id", "comment-events")
      shell.append_child(host.as_node())
      shell.append_child(event_log.as_node())
      app.append_child(shell.as_node())
      Some((host, event_log))
    }
    None => None
  }
}

///|
fn comments_source_text() -> String {
  // The trailing filler lines push the content height past the 360px host so
  // the scroll-tracking spec step has room to wheel.
  let filler = StringBuilder::new()
  for index in 1..<=20 {
    filler.write_string("// filler line " + index.to_string() + "\n")
  }
  (
    #|// comments fixture
    #|fn commented_area() -> Int {
    #|  let alpha = 1
    #|  let beta = 2
    #|  alpha + beta
    #|}
    #|
    #|fn folded_area() -> Unit {
    #|  let hidden_target = "thread anchor"
    #|  ignore(hidden_target)
    #|}
    #|// end of fixture
    #|
  ) +
  filler.to_string()
}
