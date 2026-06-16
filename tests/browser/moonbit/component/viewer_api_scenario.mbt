///|
priv struct MemoryDocumentSource {
  uri : @workspace.DocumentUri
  text : String
}

///|
impl @workspace.DocumentSource for MemoryDocumentSource with fn open_document(
  self,
  uri,
) {
  if uri == self.uri {
    SourceDocumentLoaded(
      @workspace.SourceDocument::from_file_content(
        uri,
        FileContent(self.text, display_name="component.mbt"),
      ),
    )
  } else {
    SourceDocumentLoadError(
      FileSystemProviderError(FileNotFound, "Document does not exist.", uri~),
    )
  }
}

///|
impl @workspace.DocumentSource for MemoryDocumentSource with fn watch_document(
  _self,
  _uri,
  _listener,
) {
  { dispose: () => () }
}

///|
impl @workspace.DocumentSource for MemoryDocumentSource with fn close_document(
  _self,
  _uri,
) {

}

///|
fn run_viewer_api_test() -> Unit {
  @browser.register_tokenizer("moonbit", @lang_moonbit.MoonbitTokenizer::new())
  let ctx = @support.BrowserTestContext::new("viewer_api")
  let rendered_count = Ref(0)
  let rendered_line_count = Ref(0)
  let done = Ref(false)
  let uri = @workspace.DocumentUri::memory("component.mbt")
  let source : MemoryDocumentSource = { uri, text: component_source_text() }
  match mount_host() {
    Some(host) => {
      let viewer = @browser.Viewer(
        source,
        on_notification=notification => {
          match notification {
            ViewerDocumentRendered(_, rendered_lines~, fresh~, ..) =>
              if fresh {
                rendered_count.val = rendered_count.val + 1
                rendered_line_count.val = rendered_lines
              }
            ViewerDocumentFailed(error) =>
              ctx.fail("viewer failed to open document: " + error.message)
            _ => ()
          }
        },
        placeholder="Loading component fixture...",
      )
      viewer.attach(host)
      viewer.open(uri)
      @support.set_timeout(
        () => poll_rendered(ctx, rendered_count, rendered_line_count, done, 80),
        50,
      )
    }
    None => {
      ctx.fail("missing #app mount point")
      ctx.finish()
    }
  }
}

///|
fn mount_host() -> @rdom.Element? {
  let document = @rdom.document()
  match document.query_selector("#app").to_option() {
    Some(app) => {
      let shell = document.create_element("main")
      shell.set_attribute("class", "editor-shell")
      shell.set_attribute("data-theme", "dark")
      shell.set_attribute("style", "height:100vh;display:block;")
      let host = document.create_element("div")
      host.set_attribute("class", "viewer-host")
      host.set_attribute("style", "height:100vh;")
      shell.append_child(host.as_node())
      app.append_child(shell.as_node())
      Some(host)
    }
    None => None
  }
}

///|
fn poll_rendered(
  ctx : @support.BrowserTestContext,
  rendered_count : Ref[Int],
  rendered_lines : Ref[Int],
  done : Ref[Bool],
  remaining : Int,
) -> Unit {
  if done.val {
    return
  }
  let text = @support.query_text(".moonbit-viewer.readonly-editor")
  if text.contains("component_answer") {
    ctx.assert_true(
      rendered_count.val > 0,
      "viewer did not emit a rendered notification",
    )
    ctx.assert_true(rendered_lines.val > 0, "viewer rendered no lines")
    ctx.assert_true(
      @support.query_count(".moonbit-viewer.readonly-editor .view-line") > 0,
      "viewer did not create rendered line DOM",
    )
    ctx.assert_true(
      @support.query_count(".tok-keyword") > 0,
      "MoonBit tokenizer did not classify keywords",
    )
    ctx.assert_true(
      @support.query_attribute(".moonbit-viewer.readonly-editor", "data-theme") ==
      "dark",
      "viewer did not mirror the dark theme onto its root",
    )
    ctx.metric_int("renderedNotifications", rendered_count.val)
    ctx.metric_int("renderedLines", rendered_lines.val)
    done.val = true
    ctx.finish()
  } else if remaining <= 0 {
    ctx.fail("timed out waiting for component_answer to render")
    done.val = true
    ctx.finish()
  } else {
    @support.set_timeout(
      () => {
        poll_rendered(ctx, rendered_count, rendered_lines, done, remaining - 1)
      },
      50,
    )
  }
}

///|
fn component_source_text() -> String {
  (
    #|///|
    #|pub fn component_answer() -> Int {
    #|  42
    #|}
    #|
  )
}
