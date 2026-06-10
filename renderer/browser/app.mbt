///|
priv struct BrowserDocumentView {
  uri : String
  display_name : String
  language_id : String
  version : Int
}

///|
priv struct HoverView {
  range : @core.Range
  contents : String
}

///|
priv struct DefinitionView {
  uri : String
  range : @core.Range
}

///|
priv struct BrowserAppModel {
  status : String
  status_message : String
  frame : @renderer.RenderFrame?
  source_document : @workspace.SourceDocument?
  document : BrowserDocumentView?
  selected_workspace_id : String
  docs_expanded : Bool
  fixtures_expanded : Bool
  hover : HoverView?
  definition : DefinitionView?
}

///|
priv enum BrowserMsg {
  StartDefaultDocument
  DocumentRenderResolved(DocumentRenderResult, Bool)
  DocumentWatchChanged(String, Bool)
  SelectWorkspace(String)
  ToggleFolder(String)
  RequestHover(Int, Int, Int, Int)
  HoverResolved(Int, Int, HoverResolution)
  RequestDefinition(Int, Int)
  DefinitionResolved(DefinitionResolution)
}

///|
let browser_dispatch : Ref[((BrowserMsg) -> Unit)?] = Ref(None)

///|
fn dispatch_browser_msg(msg : BrowserMsg) -> Unit {
  match browser_dispatch.val {
    Some(dispatch) => dispatch(msg)
    None => ()
  }
}

///|
pub fn mount_app() -> Unit {
  let (emit, cell) = @rabbita.cell_with_emit(
    model=initial_browser_model(),
    update=update_browser_app,
    view=view_browser_app,
  )
  let app = @rabbita.new(cell)
  app.with_init(
    @cmd.custom_cmd(scheduler => {
      browser_dispatch.val = Some(msg => scheduler.add(emit(msg)))
      scheduler.add(emit(StartDefaultDocument))
    }),
  )
  app.mount("app")
}

///|
fn initial_browser_model() -> BrowserAppModel {
  {
    status: "loading",
    status_message: "",
    frame: None,
    source_document: None,
    document: None,
    selected_workspace_id: "docs/fixtures/demo.mbt",
    docs_expanded: true,
    fixtures_expanded: true,
    hover: None,
    definition: None,
  }
}

///|
fn update_browser_app(
  emit : @rabbita.Emit[BrowserMsg],
  msg : BrowserMsg,
  model : BrowserAppModel,
) -> (@rabbita.Cmd, BrowserAppModel) {
  match msg {
    StartDefaultDocument =>
      (
        default_document_cmd(),
        { ..model, status: "loading", status_message: "", frame: None },
      )
    DocumentRenderResolved(result, watch) =>
      match result {
        DocumentRendered(rendered) =>
          document_rendered_update(emit, model, rendered, watch)
        DocumentRenderFailed(uri, status, message) =>
          (
            dom_mounted_status_cmd(status),
            {
              ..model,
              status,
              status_message: message,
              frame: None,
              source_document: None,
              document: update_document_uri(model.document, uri),
              hover: None,
              definition: None,
            },
          )
      }
    DocumentWatchChanged(uri, deleted) =>
      if active_document_uri(model.document) == uri {
        if deleted {
          (
            dom_mounted_status_cmd("missing"),
            {
              ..model,
              status: "missing",
              status_message: "Source file is missing.",
              frame: None,
              hover: None,
              definition: None,
            },
          )
        } else {
          match model.source_document {
            Some(document) =>
              (
                @rabbita.batch([
                  dom_mounted_status_cmd("stale"),
                  load_document_uri_cmd(
                    document.uri,
                    model.source_document,
                    false,
                  ),
                ]),
                { ..model, status: "stale", status_message: "" },
              )
            None => (@rabbita.none, model)
          }
        }
      } else {
        (@rabbita.none, model)
      }
    SelectWorkspace(id) => {
      let next = {
        ..model,
        selected_workspace_id: id,
        status: "loading",
        status_message: "",
        frame: None,
        hover: None,
        definition: None,
      }
      (
        @rabbita.batch([
          stop_document_watch_cmd(),
          load_workspace_document_cmd(emit, id, model.source_document),
        ]),
        next,
      )
    }
    ToggleFolder(id) =>
      if id == "docs" {
        (@rabbita.none, { ..model, docs_expanded: !model.docs_expanded })
      } else if id == "docs/fixtures" {
        (
          @rabbita.none,
          { ..model, fixtures_expanded: !model.fixtures_expanded },
        )
      } else {
        (@rabbita.none, model)
      }
    RequestHover(start, end, offset, version) =>
      (
        hover_resolution_cmd(
          emit,
          model.source_document,
          start,
          end,
          offset,
          version,
        ),
        { ..model, hover: None },
      )
    HoverResolved(start, end, result) =>
      if frame_version(model.frame) == result.version {
        if result.ok && result.start < end && start < result.end {
          (
            @rabbita.none,
            {
              ..model,
              hover: Some({
                range: Range(result.start, result.end),
                contents: result.contents,
              }),
            },
          )
        } else {
          (@rabbita.none, model)
        }
      } else {
        (@rabbita.none, model)
      }
    RequestDefinition(offset, version) =>
      (
        definition_resolution_cmd(emit, model.source_document, offset, version),
        { ..model, definition: None },
      )
    DefinitionResolved(result) =>
      if frame_version(model.frame) == result.version {
        if result.ok && result.uri != "" {
          let definition : DefinitionView = {
            uri: result.uri,
            range: Range(result.start, result.end),
          }
          let cmd = match model.source_document {
            Some(document) =>
              if document.uri.to_string() != result.uri {
                match @workspace.DocumentUri::parse(result.uri) {
                  ParsedDocumentUri(uri) =>
                    load_document_uri_cmd(uri, model.source_document, true)
                  DocumentUriError(_) => @rabbita.none
                }
              } else {
                @rabbita.none
              }
            None => @rabbita.none
          }
          (@rabbita.batch([cmd]), { ..model, definition: Some(definition) })
        } else {
          (@rabbita.none, model)
        }
      } else {
        (@rabbita.none, model)
      }
  }
}

///|
fn document_rendered_update(
  emit : @rabbita.Emit[BrowserMsg],
  model : BrowserAppModel,
  rendered : RenderedDocument,
  watch : Bool,
) -> (@rabbita.Cmd, BrowserAppModel) {
  let document = document_to_view(rendered.document)
  let next = {
    ..model,
    status: "ready",
    status_message: "",
    frame: Some(rendered.frame),
    source_document: Some(rendered.document),
    document: Some(document),
    selected_workspace_id: selected_workspace_for_document(document),
    hover: None,
    definition: None,
  }
  let cmd = if watch {
    @rabbita.batch([
      dom_mounted_cmd(rendered.frame, "ready"),
      watch_document_cmd(emit, rendered.document),
    ])
  } else {
    dom_mounted_cmd(rendered.frame, "ready")
  }
  (cmd, next)
}

///|
fn view_browser_app(
  emit : @rabbita.Emit[BrowserMsg],
  model : BrowserAppModel,
) -> @html.Html {
  @html.main_(class="editor-shell", attrs=shell_attrs(model), [
    view_topbar(model),
    @html.div(class="editor-main", [
      view_sidebar(emit, model),
      match model.frame {
        Some(frame) => view_code_viewer(emit, model, frame)
        None => view_empty_viewer(model)
      },
    ]),
    view_diagnostics(model.frame),
    view_hover_tooltip(model.hover),
  ])
}

///|
fn shell_attrs(model : BrowserAppModel) -> @html.Attrs {
  let mut attrs = @html.Attrs::build()
  attrs = attrs.data_set("status", model.status)
  attrs = attrs.data_set("line-count", line_count_string(model.frame))
  match model.document {
    Some(document) => attrs = attrs.data_set("source-uri", document.uri)
    None => ()
  }
  attrs
}

///|
fn view_topbar(model : BrowserAppModel) -> @html.Html {
  @html.div(class="topbar", [
    @html.div(class="source-title", [
      @html.strong(document_title(model)),
      @html.span(document_meta(model)),
    ]),
    @html.div(
      class="source-status source-status-" + model.status,
      status_text(model),
    ),
  ])
}

///|
fn view_sidebar(
  emit : @rabbita.Emit[BrowserMsg],
  model : BrowserAppModel,
) -> @html.Html {
  let children : Array[@html.Html] = [
    @html.div(class="workspace-title", "Explorer"),
    view_folder(emit, "docs", "docs", 0, model.docs_expanded),
  ]
  if model.docs_expanded {
    children.push(
      view_folder(emit, "docs/fixtures", "fixtures", 1, model.fixtures_expanded),
    )
    if model.fixtures_expanded {
      children.push(
        view_file(emit, model, "docs/fixtures/demo.mbt", "demo.mbt", 2),
      )
    }
  }
  children.push(view_file(emit, model, "web/main.mbt", "main.mbt", 0))
  children.push(
    view_file(emit, model, "renderer/browser/backend.mbt", "backend.mbt", 0),
  )
  @html.aside(
    class="workspace-sidebar",
    attrs=@html.Attrs::build().aria_label("Workspace files"),
    children,
  )
}

///|
fn view_folder(
  emit : @rabbita.Emit[BrowserMsg],
  id : String,
  label : String,
  depth : Int,
  expanded : Bool,
) -> @html.Html {
  @html.button(
    type_="button",
    class="workspace-item workspace-folder",
    on_click=emit(ToggleFolder(id)),
    attrs=@html.Attrs::build()
      .data_set("workspace-id", id)
      .data_set("workspace-kind", "folder")
      .aria_expanded(expanded.to_string())
      .style("--depth", depth.to_string()),
    [
      @html.span(class="workspace-disclosure", if expanded { "v" } else { ">" }),
      @html.span(class="workspace-label", label),
    ],
  )
}

///|
fn view_file(
  emit : @rabbita.Emit[BrowserMsg],
  model : BrowserAppModel,
  id : String,
  label : String,
  depth : Int,
) -> @html.Html {
  let selected = model.selected_workspace_id == id
  let class_name = if selected {
    "workspace-item workspace-file is-selected"
  } else {
    "workspace-item workspace-file"
  }
  @html.button(
    type_="button",
    class=class_name,
    on_click=emit(SelectWorkspace(id)),
    attrs=@html.Attrs::build()
      .data_set("workspace-id", id)
      .data_set("workspace-kind", "file")
      .data_set("selected", selected.to_string())
      .aria_selected(selected.to_string())
      .style("--depth", depth.to_string()),
    [
      @html.span(class="workspace-file-icon", "mb"),
      @html.span(class="workspace-label", label),
    ],
  )
}

///|
fn view_code_viewer(
  emit : @rabbita.Emit[BrowserMsg],
  model : BrowserAppModel,
  frame : @renderer.RenderFrame,
) -> @html.Html {
  @html.section(
    class="code-viewer",
    attrs=@html.Attrs::build().aria_label("Readonly code viewer"),
    @html.div(class="code-lines", line_nodes(emit, model, frame)),
  )
}

///|
fn line_nodes(
  emit : @rabbita.Emit[BrowserMsg],
  model : BrowserAppModel,
  frame : @renderer.RenderFrame,
) -> Array[@html.Html] {
  let rows : Array[@html.Html] = []
  for line in frame.lines {
    rows.push(view_line(emit, model, frame, line))
  }
  rows
}

///|
fn view_line(
  emit : @rabbita.Emit[BrowserMsg],
  model : BrowserAppModel,
  frame : @renderer.RenderFrame,
  line : @renderer.RenderLine,
) -> @html.Html {
  @html.div(
    class="code-line",
    attrs=@html.Attrs::build().data_set("line", line.line_number.to_string()),
    [
      @html.div(class="gutter", line.line_number.to_string()),
      if line.spans.length() == 0 {
        @html.pre(class="code", if line.text == "" { " " } else { line.text })
      } else {
        @html.pre(class="code", span_nodes(emit, model, frame, line))
      },
    ],
  )
}

///|
fn span_nodes(
  emit : @rabbita.Emit[BrowserMsg],
  model : BrowserAppModel,
  frame : @renderer.RenderFrame,
  line : @renderer.RenderLine,
) -> Array[@html.Html] {
  let spans : Array[@html.Html] = []
  for i in 0..<line.spans.length() {
    let span = line.spans[i]
    let absolute_start = line.offset + span.start
    let absolute_end = line.offset + span.end
    spans.push(
      view_span(emit, model, frame, span, absolute_start, absolute_end),
    )
  }
  spans
}

///|
fn view_span(
  emit : @rabbita.Emit[BrowserMsg],
  model : BrowserAppModel,
  frame : @renderer.RenderFrame,
  span : @renderer.RenderSpan,
  absolute_start : Int,
  absolute_end : Int,
) -> @html.Html {
  let hover = hover_for_span(model.hover, absolute_start, absolute_end)
  let definition = definition_for_span(
    model.definition,
    active_document_uri(model.document),
    absolute_start,
    absolute_end,
  )
  let offset = (absolute_start + absolute_end) / 2
  let mut class_name = span.class_name
  if hover is Some(_) {
    class_name = class_name + " has-hover"
  }
  if is_definition_candidate(span) {
    class_name = class_name + " definition-candidate"
  }
  if definition is Some(_) {
    class_name = class_name + " has-definition definition-target"
  }
  let mut attrs = @html.Attrs::build()
  attrs = attrs.data_set("start", absolute_start.to_string())
  attrs = attrs.data_set("end", absolute_end.to_string())
  attrs = attrs.on_mouseover(_ => {
    emit(RequestHover(absolute_start, absolute_end, offset, frame.version))
  })
  attrs = attrs.on_mousemove(_ => {
    emit(RequestHover(absolute_start, absolute_end, offset, frame.version))
  })
  attrs = attrs.on_focus(_ => {
    emit(RequestHover(absolute_start, absolute_end, offset, frame.version))
  })
  match hover {
    Some(item) => {
      attrs = attrs.title(item.contents)
      attrs = attrs.data_set("hover", item.contents)
    }
    None => ()
  }
  if is_definition_candidate(span) {
    attrs = attrs.tabindex(0)
    attrs = attrs.on_dblclick(_ => {
      emit(RequestDefinition(offset, frame.version))
    })
  }
  match definition {
    Some(item) => {
      attrs = attrs.data_set("definition-uri", item.uri)
      attrs = attrs.data_set("definition-start", item.range.start.to_string())
      attrs = attrs.data_set("definition-target", "true")
    }
    None => ()
  }
  @html.span(class=class_name, attrs~, span.text)
}

///|
fn view_empty_viewer(model : BrowserAppModel) -> @html.Html {
  @html.section(
    class="code-viewer source-empty",
    attrs=@html.Attrs::build().aria_label("Readonly code viewer"),
    [
      @html.div(class="source-message", source_message(model)),
      if model.status == "loading" {
        @html.nothing
      } else {
        @html.div(class="source-actions", [
          @html.button(type_="button", class="source-open-button", "Open file"),
        ])
      },
    ],
  )
}

///|
fn view_diagnostics(frame : @renderer.RenderFrame?) -> @html.Html {
  let children : Array[@html.Html] = [@html.strong("Diagnostics")]
  match frame {
    Some(item) =>
      for diagnostic in item.diagnostics {
        children.push(
          @html.div(
            class="diagnostic-item",
            diagnostic.severity.label() + ": " + diagnostic.message,
          ),
        )
      }
    None => ()
  }
  @html.aside(
    class="diagnostics",
    attrs=@html.Attrs::build().aria_label("Diagnostics"),
    children,
  )
}

///|
fn view_hover_tooltip(hover : HoverView?) -> @html.Html {
  match hover {
    Some(item) =>
      @html.div(
        class="hover-tooltip",
        attrs=@html.Attrs::build()
          .role("tooltip")
          .style("left", "320px")
          .style("top", "72px"),
        item.contents,
      )
    None => @html.nothing
  }
}

///|
fn document_to_view(
  document : @workspace.SourceDocument,
) -> BrowserDocumentView {
  {
    uri: document.uri.to_string(),
    display_name: document.display_name,
    language_id: document.language_id,
    version: document.version,
  }
}

///|
fn update_document_uri(
  document : BrowserDocumentView?,
  uri : String,
) -> BrowserDocumentView? {
  match document {
    Some(item) =>
      if uri == "" || item.uri == uri {
        Some(item)
      } else {
        Some({
          uri,
          display_name: display_name_from_uri(uri),
          language_id: "",
          version: 1,
        })
      }
    None =>
      if uri == "" {
        None
      } else {
        Some({
          uri,
          display_name: display_name_from_uri(uri),
          language_id: "",
          version: 1,
        })
      }
  }
}

///|
fn selected_workspace_for_document(document : BrowserDocumentView) -> String {
  let prefix = "readonly-remote://workspace/"
  if document.uri.has_prefix(prefix) {
    document.uri[prefix.length():].to_owned()
  } else if document.uri == "memory://demo.mbt" {
    "docs/fixtures/demo.mbt"
  } else {
    document.uri
  }
}

///|
fn active_document_uri(document : BrowserDocumentView?) -> String {
  match document {
    Some(item) => item.uri
    None => ""
  }
}

///|
fn frame_version(frame : @renderer.RenderFrame?) -> Int {
  match frame {
    Some(item) => item.version
    None => 0
  }
}

///|
fn line_count_string(frame : @renderer.RenderFrame?) -> String {
  match frame {
    Some(item) => item.line_count.to_string()
    None => "0"
  }
}

///|
fn document_title(model : BrowserAppModel) -> String {
  match model.document {
    Some(document) =>
      if document.display_name == "" {
        display_name_from_uri(document.uri)
      } else {
        document.display_name
      }
    None => "Readonly MoonBit Editor"
  }
}

///|
fn document_meta(model : BrowserAppModel) -> String {
  match model.document {
    Some(document) => {
      let language = if document.language_id == "" {
        "moonbit"
      } else {
        document.language_id
      }
      language + " v" + document.version.to_string()
    }
    None => "moonbit v-"
  }
}

///|
fn status_text(model : BrowserAppModel) -> String {
  let count = match model.frame {
    Some(frame) => frame.line_count.to_string() + " lines"
    None => ""
  }
  let label = status_label(model.status)
  if count == "" {
    label
  } else {
    label + " - " + count
  }
}

///|
fn status_label(status : String) -> String {
  match status {
    "ready" => "Ready"
    "loading" => "Loading"
    "missing" => "Missing"
    "stale" => "Reconnecting"
    _ => "Error"
  }
}

///|
fn source_message(model : BrowserAppModel) -> String {
  match model.status {
    "loading" => "Loading source..."
    "missing" => "Source file is missing."
    "stale" => "Connection lost. Reconnecting..."
    "error" =>
      if model.status_message == "" {
        "Unable to load source."
      } else {
        model.status_message
      }
    _ => ""
  }
}

///|
fn hover_for_span(hover : HoverView?, start : Int, end : Int) -> HoverView? {
  match hover {
    Some(item) =>
      if item.range.start < end && start < item.range.end {
        Some(item)
      } else {
        None
      }
    None => None
  }
}

///|
fn definition_for_span(
  definition : DefinitionView?,
  document_uri : String,
  start : Int,
  end : Int,
) -> DefinitionView? {
  match definition {
    Some(item) =>
      if item.uri == document_uri &&
        item.range.start < end &&
        start < item.range.end {
        Some(item)
      } else {
        None
      }
    None => None
  }
}

///|
fn is_definition_candidate(span : @renderer.RenderSpan) -> Bool {
  if span.text.trim() == "" {
    return false
  }
  for class_view in span.class_name.split(" ") {
    if class_view.to_owned() == "tok-identifier" {
      return true
    }
  }
  false
}

///|
fn display_name_from_uri(uri : String) -> String {
  let path = match uri.find("://") {
    Some(index) => uri[index + 3:].to_owned()
    None => uri
  }
  let segments = path.split("/")
  let mut found = uri
  for segment_view in segments {
    let segment = segment_view.to_owned()
    if segment != "" {
      found = segment
    }
  }
  found
}

///|
fn dom_mounted_cmd(
  frame : @renderer.RenderFrame,
  status : String,
) -> @rabbita.Cmd {
  @cmd.custom_cmd(
    _ => {
      let mut payload = "{"
      payload = payload +
        "\"renderedLines\":" +
        frame.lines.length().to_string()
      payload = payload + ",\"diagnostics\":"
      payload = payload + frame.diagnostics.length().to_string()
      payload = payload + ",\"status\":" + json_string(status)
      payload = payload + "}"
      emit_event("dom:mounted", payload)
    },
    kind=@cmd.after_render,
  )
}

///|
fn dom_mounted_status_cmd(status : String) -> @rabbita.Cmd {
  @cmd.custom_cmd(
    _ => {
      let payload = "{\"renderedLines\":0,\"diagnostics\":0,\"status\":" +
        json_string(status) +
        "}"
      emit_event("dom:mounted", payload)
    },
    kind=@cmd.after_render,
  )
}

///|
fn json_string(value : String) -> String {
  value.escape(quote=true)
}
