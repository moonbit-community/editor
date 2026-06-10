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
  workspace_entries : Array[@remote_protocol.WorkspaceEntry]
  collapsed_workspace_ids : Array[String]
  provider_result : @language.ProviderResult
  hover : HoverView?
  definition : DefinitionView?
}

///|
priv enum BrowserMsg {
  ConnectProtocol
  ProtocolEvent(@websocket.Event)
  ProtocolSendFailed(String)
  DocumentRenderResolved(DocumentRenderResult, Bool)
  SelectWorkspace(String)
  ToggleFolder(String)
  RequestHover(Int, Int, Int, Int)
  RequestDefinition(Int, Int)
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
      scheduler.add(emit(ConnectProtocol))
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
    selected_workspace_id: "",
    workspace_entries: [],
    collapsed_workspace_ids: [],
    provider_result: @language.ProviderResult::empty(),
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
    ConnectProtocol =>
      (
        connect_protocol_cmd(emit),
        { ..model, status: "loading", status_message: "", frame: None },
      )
    ProtocolEvent(event) => protocol_event_update(emit, model, event)
    ProtocolSendFailed(message) =>
      (
        dom_mounted_status_cmd("error"),
        { ..model, status: "error", status_message: message },
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
              provider_result: @language.ProviderResult::empty(),
              hover: None,
              definition: None,
            },
          )
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
          close_active_document_cmd(emit, model.source_document),
          load_workspace_document_cmd(emit, id),
        ]),
        next,
      )
    }
    ToggleFolder(id) =>
      (
        @rabbita.none,
        { ..model, collapsed_workspace_ids: toggle_collapsed_id(model, id) },
      )
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
    RequestDefinition(offset, version) =>
      (
        definition_resolution_cmd(emit, model.source_document, offset, version),
        { ..model, definition: None },
      )
  }
}

///|
fn protocol_event_update(
  emit : @rabbita.Emit[BrowserMsg],
  model : BrowserAppModel,
  event : @websocket.Event,
) -> (@rabbita.Cmd, BrowserAppModel) {
  match event {
    Opened =>
      (
        send_client_packet_cmd(emit, ListWorkspace({ id: "list-workspace" })),
        { ..model, status_message: "" },
      )
    Message(raw) => protocol_message_update(emit, model, raw)
    Closed(_) =>
      (
        dom_mounted_status_cmd("stale"),
        {
          ..model,
          status: "stale",
          status_message: "Connection lost. Reconnecting...",
        },
      )
    Errored =>
      (
        dom_mounted_status_cmd("error"),
        {
          ..model,
          status: "error",
          status_message: "Remote protocol connection failed.",
        },
      )
  }
}

///|
fn protocol_message_update(
  emit : @rabbita.Emit[BrowserMsg],
  model : BrowserAppModel,
  raw : String,
) -> (@rabbita.Cmd, BrowserAppModel) {
  match @remote_protocol.decode_server_packet(raw) {
    DecodedServerPacket(packet) => server_packet_update(emit, model, packet)
    ServerPacketDecodeError(error) => protocol_error_update(model, error)
  }
}

///|
fn server_packet_update(
  emit : @rabbita.Emit[BrowserMsg],
  model : BrowserAppModel,
  packet : @remote_protocol.ServerPacket,
) -> (@rabbita.Cmd, BrowserAppModel) {
  match packet {
    WorkspaceListed(payload) => workspace_listed_update(emit, model, payload)
    DocumentLoaded(payload) => document_payload_update(model, payload)
    DocumentChanged(payload) => document_payload_update(model, payload)
    Diagnostics(payload) =>
      semantic_payload_update(model, {
        ..model.provider_result,
        diagnostics: payload.diagnostics,
      })
    DocumentSymbolsResult(payload) =>
      semantic_payload_update(model, {
        ..model.provider_result,
        symbols: payload.symbols,
      })
    SemanticTokensResult(payload) =>
      semantic_payload_update(model, {
        ..model.provider_result,
        semantic_tokens: payload.semantic_tokens,
      })
    HoverResult(payload) =>
      if frame_version(model.frame) == payload.version {
        match payload.hover {
          Some(hover) => {
            emit_event(
              "language:hover",
              "{\"ok\":true,\"version\":" + payload.version.to_string() + "}",
            )
            (
              @rabbita.none,
              {
                ..model,
                hover: Some({ range: hover.range, contents: hover.contents }),
              },
            )
          }
          None => {
            emit_event(
              "language:hover",
              "{\"ok\":false,\"version\":" + payload.version.to_string() + "}",
            )
            (@rabbita.none, model)
          }
        }
      } else {
        (@rabbita.none, model)
      }
    DefinitionResult(payload) =>
      if frame_version(model.frame) == payload.version {
        match payload.location {
          Some(location) => {
            emit_event(
              "language:definition",
              "{\"ok\":true,\"version\":" +
              payload.version.to_string() +
              ",\"uri\":" +
              json_string(location.uri.to_string()) +
              "}",
            )
            (
              @rabbita.none,
              {
                ..model,
                definition: Some({
                  uri: location.uri.to_string(),
                  range: location.range,
                }),
              },
            )
          }
          None => {
            emit_event(
              "language:definition",
              "{\"ok\":false,\"version\":" + payload.version.to_string() + "}",
            )
            (@rabbita.none, model)
          }
        }
      } else {
        (@rabbita.none, model)
      }
    RemoteError(error) => protocol_error_update(model, error)
  }
}

///|
fn workspace_listed_update(
  emit : @rabbita.Emit[BrowserMsg],
  model : BrowserAppModel,
  payload : @remote_protocol.WorkspaceListedPayload,
) -> (@rabbita.Cmd, BrowserAppModel) {
  let selected = if model.selected_workspace_id == "" {
    first_workspace_file(payload.entries)
  } else {
    model.selected_workspace_id
  }
  let next = {
    ..model,
    workspace_entries: payload.entries,
    selected_workspace_id: selected,
  }
  if selected == "" {
    (@rabbita.none, next)
  } else if model.source_document is None {
    (load_workspace_document_cmd(emit, selected), { ..next, status: "loading" })
  } else {
    (@rabbita.none, next)
  }
}

///|
fn document_payload_update(
  model : BrowserAppModel,
  payload : @remote_protocol.DocumentPayload,
) -> (@rabbita.Cmd, BrowserAppModel) {
  let next = {
    ..model,
    provider_result: @language.ProviderResult::empty(),
    hover: None,
    definition: None,
  }
  (
    render_document_cmd(
      payload.document,
      model.source_document,
      next.provider_result,
      true,
    ),
    next,
  )
}

///|
fn semantic_payload_update(
  model : BrowserAppModel,
  providers : @language.ProviderResult,
) -> (@rabbita.Cmd, BrowserAppModel) {
  match model.source_document {
    Some(document) =>
      (
        render_document_cmd(document, model.source_document, providers, false),
        { ..model, provider_result: providers },
      )
    None => (@rabbita.none, model)
  }
}

///|
fn protocol_error_update(
  model : BrowserAppModel,
  error : @remote_protocol.ProtocolError,
) -> (@rabbita.Cmd, BrowserAppModel) {
  emit_event("language:error", error.to_json())
  if error.provider_code == "FileNotFound" {
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
    (
      dom_mounted_status_cmd("error"),
      { ..model, status: "error", status_message: error.message },
    )
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
      language_requests_cmd(emit, rendered.document),
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
  ]
  for entry in model.workspace_entries {
    if workspace_entry_visible(model, entry) {
      if entry.kind == "directory" {
        children.push(
          view_folder(
            emit,
            entry.path,
            entry.name,
            entry.depth,
            !is_workspace_collapsed(model, entry.path),
          ),
        )
      } else {
        children.push(
          view_file(emit, model, entry.path, entry.name, entry.depth),
        )
      }
    }
  }
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
  workspace_id_from_uri(document.uri)
}

///|
fn workspace_id_from_uri(uri : String) -> String {
  let prefix = "readonly-remote://workspace/"
  if uri.has_prefix(prefix) {
    uri[prefix.length():].to_owned()
  } else {
    uri
  }
}

///|
fn first_workspace_file(
  entries : Array[@remote_protocol.WorkspaceEntry],
) -> String {
  for entry in entries {
    if entry.kind == "file" && entry.path.has_suffix(".mbt") {
      return entry.path
    }
  }
  for entry in entries {
    if entry.kind == "file" {
      return entry.path
    }
  }
  ""
}

///|
fn is_workspace_collapsed(model : BrowserAppModel, path : String) -> Bool {
  for collapsed in model.collapsed_workspace_ids {
    if collapsed == path {
      return true
    }
  }
  false
}

///|
fn toggle_collapsed_id(model : BrowserAppModel, path : String) -> Array[String] {
  let next : Array[String] = []
  let mut removed = false
  for collapsed in model.collapsed_workspace_ids {
    if collapsed == path {
      removed = true
    } else {
      next.push(collapsed)
    }
  }
  if !removed {
    next.push(path)
  }
  next
}

///|
fn workspace_entry_visible(
  model : BrowserAppModel,
  entry : @remote_protocol.WorkspaceEntry,
) -> Bool {
  let mut parent = ""
  for part_view in entry.path.split("/") {
    let part = part_view.to_owned()
    if part != "" && part != entry.name {
      parent = if parent == "" { part } else { parent + "/" + part }
      if is_workspace_collapsed(model, parent) {
        return false
      }
    }
  }
  true
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
