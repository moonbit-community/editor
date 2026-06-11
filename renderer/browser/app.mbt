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
priv struct HoverAnchor {
  start : Int
  end : Int
  offset : Int
}

///|
priv struct HoverPlacement {
  below : Bool
  shift_left : Double
}

///|
/// Pixel height of one rendered code line. Keep in sync with
/// `--editor-line-height` in app/src/style.css.
let editor_line_height = 18

///|
/// VS Code's default `editor.hover.delay`.
let hover_delay_ms = 300

///|
priv struct DefinitionView {
  uri : String
  range : @core.Range
}

///|
priv struct BrowserAppModel {
  status : String
  status_message : String
  theme : String
  frame : @renderer.RenderFrame?
  source_document : @workspace.SourceDocument?
  document : BrowserDocumentView?
  selected_workspace_id : String
  workspace_entries : Array[@remote_protocol.WorkspaceEntry]
  collapsed_workspace_ids : Array[String]
  provider_result : @language.ProviderResult
  hover : HoverView?
  hover_anchor : HoverAnchor?
  hover_token : Int
  hover_placement : HoverPlacement?
  goto_modifier : Bool
  definition : DefinitionView?
  pending_reveal : DefinitionView?
}

///|
priv enum BrowserMsg {
  ConnectProtocol
  ProtocolEvent(@websocket.Event)
  ProtocolSendFailed(String)
  DocumentRenderResolved(DocumentRenderResult, Bool)
  SelectWorkspace(String)
  ToggleFolder(String)
  ToggleTheme
  ScheduleHover(Int, Int, Int)
  FireHover(Int)
  HoverMeasured(Bool, Double)
  ClearHover
  GlobalKeyDown(@common.Keyboard)
  GlobalKeyUp(@common.Keyboard)
  SetGotoModifier(Bool)
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
    subscriptions=(emit, _model) => @sub.batch([
      @sub.on_key_down(emit.map(keyboard => GlobalKeyDown(keyboard))),
      @sub.on_key_up(emit.map(keyboard => GlobalKeyUp(keyboard))),
    ]),
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
    theme: stored_theme(),
    frame: None,
    source_document: None,
    document: None,
    selected_workspace_id: "",
    workspace_entries: [],
    collapsed_workspace_ids: [],
    provider_result: @language.ProviderResult::empty(),
    hover: None,
    hover_anchor: None,
    hover_token: 0,
    hover_placement: None,
    goto_modifier: false,
    definition: None,
    pending_reveal: None,
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
              hover_anchor: None,
              hover_placement: None,
              definition: None,
            },
          )
      }
    SelectWorkspace(id) => select_workspace_update(emit, model, id)
    ToggleFolder(id) =>
      (
        @rabbita.none,
        { ..model, collapsed_workspace_ids: toggle_collapsed_id(model, id) },
      )
    ToggleTheme => {
      let theme = if model.theme == "light" { "dark" } else { "light" }
      (persist_theme_cmd(theme), { ..model, theme, })
    }
    ScheduleHover(start, end, offset) => {
      let same = match model.hover_anchor {
        Some(anchor) => anchor.start == start && anchor.end == end
        None => false
      }
      if same {
        (@rabbita.none, model)
      } else {
        let token = model.hover_token + 1
        (
          @cmd.delay(emit(FireHover(token)), hover_delay_ms),
          {
            ..model,
            hover_token: token,
            hover_anchor: Some({ start, end, offset }),
            hover: None,
            hover_placement: None,
          },
        )
      }
    }
    FireHover(token) =>
      if token == model.hover_token {
        match model.hover_anchor {
          Some(anchor) =>
            (
              hover_resolution_cmd(
                emit,
                model.source_document,
                anchor.start,
                anchor.end,
                anchor.offset,
                frame_version(model.frame),
              ),
              model,
            )
          None => (@rabbita.none, model)
        }
      } else {
        (@rabbita.none, model)
      }
    HoverMeasured(below, shift_left) =>
      (@rabbita.none, { ..model, hover_placement: Some({ below, shift_left }) })
    ClearHover =>
      (
        @rabbita.none,
        { ..model, hover: None, hover_anchor: None, hover_placement: None },
      )
    GlobalKeyDown(keyboard) => {
      let modifier = keyboard.ctrl_key() || keyboard.meta_key()
      if keyboard.key() == "Escape" {
        (
          @rabbita.none,
          {
            ..model,
            goto_modifier: modifier,
            hover: None,
            hover_anchor: None,
            hover_placement: None,
            definition: None,
          },
        )
      } else {
        set_goto_modifier(model, modifier)
      }
    }
    GlobalKeyUp(keyboard) =>
      set_goto_modifier(model, keyboard.ctrl_key() || keyboard.meta_key())
    SetGotoModifier(modifier) => set_goto_modifier(model, modifier)
    RequestDefinition(offset, version) =>
      (
        definition_resolution_cmd(emit, model.source_document, offset, version),
        { ..model, definition: None },
      )
  }
}

///|
fn select_workspace_update(
  emit : @rabbita.Emit[BrowserMsg],
  model : BrowserAppModel,
  id : String,
) -> (@rabbita.Cmd, BrowserAppModel) {
  let next = {
    ..model,
    selected_workspace_id: id,
    status: "loading",
    status_message: "",
    frame: None,
    hover: None,
    hover_anchor: None,
    hover_placement: None,
    definition: None,
    pending_reveal: None,
  }
  (
    @rabbita.batch([
      close_active_document_cmd(emit, model.source_document),
      load_workspace_document_cmd(emit, id),
    ]),
    next,
  )
}

///|
fn set_goto_modifier(
  model : BrowserAppModel,
  modifier : Bool,
) -> (@rabbita.Cmd, BrowserAppModel) {
  if model.goto_modifier == modifier {
    (@rabbita.none, model)
  } else {
    (@rabbita.none, { ..model, goto_modifier: modifier })
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
              measure_hover_cmd(),
              {
                ..model,
                hover: Some({ range: hover.range, contents: hover.contents }),
                hover_placement: None,
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
            definition_navigation_update(emit, model, location)
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
/// Navigates to a resolved definition: same-document targets are revealed
/// and highlighted in place; targets in another workspace file open that
/// file first and reveal once it renders.
fn definition_navigation_update(
  emit : @rabbita.Emit[BrowserMsg],
  model : BrowserAppModel,
  location : @language.Location,
) -> (@rabbita.Cmd, BrowserAppModel) {
  let uri = location.uri.to_string()
  let view : DefinitionView = { uri, range: location.range }
  if uri == active_document_uri(model.document) {
    let cmd = match model.frame {
      Some(frame) =>
        match line_col_for_offset(frame, location.range.start) {
          Some((line_number, _)) => reveal_line_cmd(line_number)
          None => @rabbita.none
        }
      None => @rabbita.none
    }
    (cmd, { ..model, definition: Some(view) })
  } else {
    let (cmd, next) = select_workspace_update(
      emit,
      model,
      workspace_id_from_uri(uri),
    )
    (cmd, { ..next, pending_reveal: Some(view) })
  }
}

///|
/// Scrolls the target line to the vertical center of the viewer when it is
/// outside the visible range, mirroring VS Code's reveal behavior.
fn reveal_line_cmd(line_number : Int) -> @rabbita.Cmd {
  @cmd.custom_cmd(
    _ => {
      let document = @rdom.document()
      match
        (
          document
          .query_selector(
            ".code-line[data-line=\"" + line_number.to_string() + "\"]",
          )
          .to_option(),
          document.query_selector(".code-viewer").to_option(),
        ) {
        (Some(line), Some(viewer)) => {
          let line_rect = line.get_bounding_client_rect()
          let viewer_rect = viewer.get_bounding_client_rect()
          if line_rect.get_top() < viewer_rect.get_top() ||
            line_rect.get_bottom() > viewer_rect.get_bottom() {
            let target = ((line_number - 1) * editor_line_height).to_double() -
              viewer_rect.get_height() / 2.0
            viewer.set_scroll_top(if target < 0.0 { 0.0 } else { target })
          }
        }
        _ => ()
      }
    },
    kind=@cmd.after_render,
  )
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
    hover_anchor: None,
    hover_placement: None,
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
        hover_anchor: None,
        hover_placement: None,
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
  let pending = match model.pending_reveal {
    Some(item) => if item.uri == document.uri { Some(item) } else { None }
    None => None
  }
  let next = {
    ..model,
    status: "ready",
    status_message: "",
    frame: Some(rendered.frame),
    source_document: Some(rendered.document),
    document: Some(document),
    selected_workspace_id: selected_workspace_for_document(document),
    hover: None,
    hover_anchor: None,
    hover_placement: None,
    definition: pending,
    pending_reveal: None,
  }
  let commands = [dom_mounted_cmd(rendered.frame, "ready")]
  if watch {
    commands.push(language_requests_cmd(emit, rendered.document))
  }
  match pending {
    Some(item) =>
      match line_col_for_offset(rendered.frame, item.range.start) {
        Some((line_number, _)) => commands.push(reveal_line_cmd(line_number))
        None => ()
      }
    None => ()
  }
  (@rabbita.batch(commands), next)
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
  ])
}

///|
fn shell_attrs(model : BrowserAppModel) -> @html.Attrs {
  let mut attrs = @html.Attrs::build()
  attrs = attrs.data_set("status", model.status)
  attrs = attrs.data_set("theme", model.theme)
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
    @html.div(class="workspace-title", [
      @html.span(class="workspace-title-label", "Explorer"),
      @html.button(
        type_="button",
        class="sidebar-action",
        title="Toggle Color Theme",
        on_click=emit(ToggleTheme),
        attrs=@html.Attrs::build()
          .data_set("action", "toggle-theme")
          .aria_label("Toggle color theme"),
        icon_color_mode(),
      ),
    ]),
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
      view_indent_guides(depth),
      @html.span(class="workspace-twistie", icon_chevron_right()),
      @html.span(class="workspace-label", label),
    ],
  )
}

///|
fn view_indent_guides(depth : Int) -> @html.Html {
  let guides : Array[@html.Html] = []
  for _ in 0..<depth {
    guides.push(@html.span(class="indent-guide", ""))
  }
  @html.span(class="workspace-guides", guides)
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
      view_indent_guides(depth),
      @html.span(class="workspace-twistie workspace-twistie-spacer", ""),
      @html.span(class="workspace-file-icon", icon_file()),
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
  let children = line_nodes(emit, model, frame)
  match view_hover_widget(model, frame) {
    Some(widget) => children.push(widget)
    None => ()
  }
  @html.section(
    class="code-viewer",
    attrs=@html.Attrs::build()
      .aria_label("Readonly code viewer")
      .on_mouseleave(_ => emit(ClearHover)),
    @html.div(class="code-lines", children),
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
  let class_name = if line_intersects_definition(model, line) {
    "code-line range-highlight"
  } else {
    "code-line"
  }
  @html.div(
    class=class_name,
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
  let candidate = is_definition_candidate(span)
  let mut class_name = span.class_name
  if hover is Some(_) {
    class_name = class_name + " has-hover"
  }
  if candidate {
    class_name = class_name + " definition-candidate"
    if model.goto_modifier &&
      anchor_matches(model.hover_anchor, absolute_start, absolute_end) {
      class_name = class_name + " goto-definition-link"
    }
  }
  if definition is Some(_) {
    class_name = class_name + " has-definition definition-target"
  }
  let mut attrs = @html.Attrs::build()
  attrs = attrs.data_set("start", absolute_start.to_string())
  attrs = attrs.data_set("end", absolute_end.to_string())
  attrs = attrs.on_mouseover(_ => {
    emit(ScheduleHover(absolute_start, absolute_end, offset))
  })
  attrs = attrs.on_mousemove(event => {
    let modifier = event.get_ctrl_key() || event.get_meta_key()
    if modifier != model.goto_modifier {
      @rabbita.batch([
        emit(SetGotoModifier(modifier)),
        emit(ScheduleHover(absolute_start, absolute_end, offset)),
      ])
    } else {
      emit(ScheduleHover(absolute_start, absolute_end, offset))
    }
  })
  attrs = attrs.on_focus(_ => {
    emit(ScheduleHover(absolute_start, absolute_end, offset))
  })
  match hover {
    Some(item) => attrs = attrs.data_set("hover", item.contents)
    None => ()
  }
  if candidate {
    attrs = attrs.tabindex(0)
    attrs = attrs.on_click(event => if event.get_ctrl_key() ||
      event.get_meta_key() {
      emit(RequestDefinition(offset, frame.version))
    } else {
      @rabbita.none
    })
    attrs = attrs.on_keydown(event => if event.key() == "F12" &&
      !event.shift_key() {
      emit(RequestDefinition(offset, frame.version))
    } else {
      @rabbita.none
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
/// Renders the hover widget inside `.code-lines`, anchored at the hovered
/// range like VS Code's editor hover: above the line by default, flipped
/// below when the measured widget would leave the viewport, and shifted left
/// when it would overflow the viewer's right edge.
fn view_hover_widget(
  model : BrowserAppModel,
  frame : @renderer.RenderFrame,
) -> @html.Html? {
  match model.hover {
    Some(hover) =>
      match line_col_for_offset(frame, hover.range.start) {
        Some((line_number, column)) => {
          let mut class_name = "hover-widget"
          let mut shift_left = 0.0
          let mut below = false
          match model.hover_placement {
            Some(placement) => {
              below = placement.below
              shift_left = placement.shift_left
            }
            None => class_name = class_name + " measuring"
          }
          let top = if below {
            line_number * editor_line_height
          } else {
            (line_number - 1) * editor_line_height
          }
          if below {
            class_name = class_name + " below"
          }
          let digits = frame.line_count.to_string().length()
          let mut attrs = @html.Attrs::build()
            .role("tooltip")
            .style("top", top.to_string() + "px")
            .style(
              "left",
              "calc(" +
              (digits + column).to_string() +
              "ch + " +
              gutter_padding_px.to_string() +
              "px)",
            )
          if shift_left > 0.0 {
            attrs = attrs.style("margin-left", "-" + shift_left.to_string() +
              "px")
          }
          Some(
            @html.div(class=class_name, attrs~, [
              @html.div(class="hover-row", [
                @html.div(class="hover-contents", hover.contents),
              ]),
            ]),
          )
        }
        None => None
      }
    None => None
  }
}

///|
/// Total horizontal padding of the line-number gutter. Keep in sync with
/// `.gutter` padding in app/src/style.css.
let gutter_padding_px = 34

///|
fn line_col_for_offset(
  frame : @renderer.RenderFrame,
  offset : Int,
) -> (Int, Int)? {
  for line in frame.lines {
    let end = line.offset + line.text.length()
    if offset >= line.offset && offset <= end {
      return Some((line.line_number, offset - line.offset))
    }
  }
  None
}

///|
/// Measures the rendered hover widget after paint and reports whether it
/// must flip below the anchor line or shift left to stay inside the viewer.
fn measure_hover_cmd() -> @rabbita.Cmd {
  @cmd.custom_cmd(
    _ => {
      let document = @rdom.document()
      match
        (
          document.query_selector(".hover-widget").to_option(),
          document.query_selector(".code-viewer").to_option(),
        ) {
        (Some(widget), Some(viewer)) => {
          let widget_rect = widget.get_bounding_client_rect()
          let viewer_rect = viewer.get_bounding_client_rect()
          let below = widget_rect.get_top() < viewer_rect.get_top()
          let overflow = widget_rect.get_right() - viewer_rect.get_right()
          let shift_left = if overflow > 0.0 { overflow } else { 0.0 }
          dispatch_browser_msg(HoverMeasured(below, shift_left))
        }
        _ => ()
      }
    },
    kind=@cmd.after_render,
  )
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
fn anchor_matches(anchor : HoverAnchor?, start : Int, end : Int) -> Bool {
  match anchor {
    Some(item) => item.start == start && item.end == end
    None => false
  }
}

///|
fn line_intersects_definition(
  model : BrowserAppModel,
  line : @renderer.RenderLine,
) -> Bool {
  match model.definition {
    Some(item) =>
      item.uri == active_document_uri(model.document) &&
      item.range.start <= line.offset + line.text.length() &&
      line.offset <= item.range.end
    None => false
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
let theme_storage_key = "readonly-editor:theme"

///|
fn stored_theme() -> String {
  match @dom.storage_get_item(theme_storage_key) {
    "light" => "light"
    _ => "dark"
  }
}

///|
fn persist_theme_cmd(theme : String) -> @rabbita.Cmd {
  @cmd.custom_cmd(_ => @dom.storage_set_item(theme_storage_key, theme))
}

///|
fn json_string(value : String) -> String {
  value.escape(quote=true)
}
