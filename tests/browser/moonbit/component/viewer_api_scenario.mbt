///|
priv struct MemoryDocumentProvider {
  uri : @base_common.Uri
  text : String
}

///|
impl @workspace.DocumentProvider for MemoryDocumentProvider with fn read(
  self,
  uri,
) {
  if uri == self.uri {
    DocumentLoaded(
      @workspace.DocumentSnapshot::from_content(
        uri,
        DocumentContent(self.text, display_name="component.mbt"),
      ),
    )
  } else {
    DocumentReadFailed(
      DocumentError(FileNotFound, "Document does not exist.", uri~),
    )
  }
}

///|
impl @workspace.DocumentProvider for MemoryDocumentProvider with fn watch(
  _self,
  _uri,
  _listener,
) {
  @base_common.Disposable::from(() => ())
}

///|
impl @workspace.DocumentProvider for MemoryDocumentProvider with fn close(
  _self,
  _uri,
) {

}

///|
priv struct ComponentHoverProvider {
  hover_text : String
  diagnostic_text : String
}

///|
fn ComponentHoverProvider::new() -> ComponentHoverProvider {
  {
    hover_text: "wrapped component hover",
    diagnostic_text: "wrapped component diagnostic",
  }
}

///|
impl @language.HoverProvider for ComponentHoverProvider with fn provide_hover(
  self,
  document,
  position,
  _token,
) {
  let needle = "keeps"
  let offset = document.offset_at_position(position)
  match document.text.find(needle) {
    Some(start) =>
      if offset >= start && offset < start + needle.length() {
        Some({
          range: Range(start, start + needle.length()),
          contents: [PlainText(self.hover_text)],
        })
      } else {
        None
      }
    None => None
  }
}

///|
impl @language.DiagnosticsProvider for ComponentHoverProvider with fn provide_diagnostics(
  self,
  document,
  _token,
) {
  let needle = "keeps"
  match document.text.find(needle) {
    Some(start) =>
      [
        {
          range: Range(start, start + needle.length()),
          severity: Warning,
          message: self.diagnostic_text,
        },
      ]
    None => []
  }
}

///|
impl @language.FoldingRangeProvider for ComponentHoverProvider with fn provide_folding_ranges(
  _self,
  _document,
  _token,
) {
  [FoldingRange(2, 5)]
}

///|
impl @language.InlayHintsProvider for ComponentHoverProvider with fn provide_inlay_hints(
  _self,
  _document,
  _range,
  _token,
) {
  [
    InlayHint(Position(1, 23), " : T", kind=TypeHint, tooltip=[
      PlainText("component inlay hint"),
    ]),
  ]
}

///|
fn run_viewer_api_test() -> Unit {
  @viewer.register_tokenizer("moonbit", @lang_moonbit.MoonbitTokenizer::new())
  let ctx = @support.BrowserTestContext::new("viewer_api")
  let rendered_count = Ref(0)
  let rendered_line_count = Ref(0)
  let view_line_count = Ref(0)
  let done = Ref(false)
  let uri = @base_common.Uri::memory("component.mbt")
  let source : MemoryDocumentProvider = { uri, text: component_source_text() }
  let model_line_count = component_model_line_count()
  match mount_host() {
    Some(host) => {
      let services = @viewer.ViewerServices::new()
      let provider = ComponentHoverProvider::new()
      services.language_features.register_hover_provider(
        LanguageId("moonbit"),
        provider,
      )
      |> ignore
      services.language_features.register_diagnostics_provider(
        LanguageId("moonbit"),
        provider,
      )
      |> ignore
      services.language_features.register_folding_range_provider(
        LanguageId("moonbit"),
        provider,
      )
      |> ignore
      services.language_features.register_inlay_hints_provider(
        LanguageId("moonbit"),
        provider,
      )
      |> ignore
      let viewer = @viewer.Viewer(
        source,
        services~,
        options=ViewerOptions(soft_wrap=true),
        placeholder="Loading component fixture...",
      )
      viewer.on_did_render_document(event => {
        if event.fresh {
          rendered_count.val = rendered_count.val + 1
          view_line_count.val = event.line_count
          rendered_line_count.val = event.rendered_lines
        }
      })
      |> ignore
      viewer.on_did_fail_document(error => {
        ctx.fail("viewer failed to open document: " + error.message)
      })
      |> ignore
      viewer.attach(host)
      viewer.open(uri)
      let zone = @rdom.document().create_element("div")
      zone.set_inner_html("component view zone")
      viewer.change_view_zones(accessor => {
        accessor.add_zone("component-zone", 4, 36, zone)
      })
      @support.set_timeout(
        () => {
          poll_rendered(
            ctx, rendered_count, rendered_line_count, view_line_count, model_line_count,
            done, 80,
          )
        },
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
      host.set_attribute("style", "height:180px;width:180px;")
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
  view_lines : Ref[Int],
  model_lines : Int,
  done : Ref[Bool],
  remaining : Int,
) -> Unit {
  if done.val {
    return
  }
  let text = @support.query_text(".monaco-editor.readonly-editor")
  if text.contains("component_answer") {
    ctx.assert_true(
      rendered_count.val > 0,
      "viewer did not emit a rendered notification",
    )
    ctx.assert_true(rendered_lines.val > 0, "viewer rendered no lines")
    ctx.assert_true(
      view_lines.val > model_lines,
      "soft wrap did not project additional view lines",
    )
    ctx.assert_true(
      @support.query_count(".monaco-editor.readonly-editor .view-line") > 0,
      "viewer did not create rendered line DOM",
    )
    ctx.assert_true(
      @support.query_count(".tok-keyword") > 0,
      "MoonBit tokenizer did not classify keywords",
    )
    ctx.assert_true(
      @support.query_attribute(".monaco-editor.readonly-editor", "data-theme") ==
      "dark",
      "viewer did not mirror the dark theme onto its root",
    )
    ctx.assert_true(
      @support.query_count(".line-number") ==
      @support.query_count(".monaco-editor.readonly-editor .view-line"),
      "line numbers did not stay aligned with rendered view lines",
    )
    ctx.metric_int("renderedNotifications", rendered_count.val)
    ctx.metric_int("renderedLines", rendered_lines.val)
    ctx.metric_int("viewLines", view_lines.val)
    ctx.metric_int("modelLines", model_lines)
    done.val = true
    ctx.finish()
  } else if remaining <= 0 {
    ctx.fail("timed out waiting for component_answer to render")
    done.val = true
    ctx.finish()
  } else {
    @support.set_timeout(
      () => {
        poll_rendered(
          ctx,
          rendered_count,
          rendered_lines,
          view_lines,
          model_lines,
          done,
          remaining - 1,
        )
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
    #|  let really_long_component_identifier_name = "component_answer keeps this line long enough to wrap"
    #|  really_long_component_identifier_name.length()
    #|}
    #|
  )
}

///|
fn component_model_line_count() -> Int {
  @workspace.DocumentSnapshot(
    @base_common.Uri::memory("component.mbt"),
    "component.mbt",
    "moonbit",
    "component-rev",
    component_source_text(),
  ).line_count()
}
