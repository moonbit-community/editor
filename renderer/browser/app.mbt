///|
priv struct BrowserDocumentView {
  uri : String
  display_name : String
  language_id : String
  version : Int
}

///|
/// Pixel height of one rendered code line. Keep in sync with
/// `--editor-line-height` in app/src/style.css.
let editor_line_height = 18

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
  hover : HoverController
  definition : DefinitionController
  references : ReferencesController
  scroll_top : Double
  viewer_height : Double
  char_width : Double
  gutter_width : Double
  last_target : @renderer.MouseTarget?
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
  EditorMouseMoved(Double, Double, Bool)
  EditorMouseDown(Double, Double, Bool)
  EditorContextMenu(Double, Double)
  EditorMouseLeft
  EditorScrolled(Double)
  ViewerMeasured(Double, Double, Double)
  ViewerResized
  FireHover(Int)
  HoverDisplayDue(Int)
  HoverLoadingDue(Int)
  HoverMeasured(Bool, Double)
  HoverResolved(Int, Int, @language.Hover?)
  DefinitionResolved(Int, @language.Location?)
  ReferencesResolved(Int, Array[@remote_protocol.ReferenceItem])
  DiagnosticsResolved(Int, Array[@language.Diagnostic])
  SymbolsResolved(Int, Array[@language.DocumentSymbol])
  SemanticTokensResolved(Int, Array[@language.SemanticToken])
  GlobalKeyDown(@common.Keyboard)
  GlobalKeyUp(@common.Keyboard)
  SelectReference(Int)
  OpenReference(Int)
  ClosePeek
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
    subscriptions=(emit, _model) => {
      @sub.batch([
        @sub.on_key_down(emit.map(keyboard => GlobalKeyDown(keyboard))),
        @sub.on_key_up(emit.map(keyboard => GlobalKeyUp(keyboard))),
        @sub.on_resize(emit.map(_ => ViewerResized)),
      ])
    },
  )
  let app = @rabbita.new(cell)
  app.with_init(
    @cmd.custom_cmd(scheduler => {
      browser_dispatch.val = Some(msg => scheduler.add(emit(msg)))
      protocol_send.val = Some(packet => scheduler.add(
        send_client_packet_cmd(emit, packet),
      ))
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
    hover: HoverController::empty(),
    definition: DefinitionController::empty(),
    references: ReferencesController::empty(),
    scroll_top: 0.0,
    viewer_height: 0.0,
    char_width: 0.0,
    gutter_width: 0.0,
    last_target: None,
  }
}

///|
/// Outer update: after every state transition, the changed feature surface
/// (if any) is pushed into the embedded code cell, so the cell only
/// re-renders when something it draws actually changed.
fn update_browser_app(
  emit : @rabbita.Emit[BrowserMsg],
  msg : BrowserMsg,
  model : BrowserAppModel,
) -> (@rabbita.Cmd, BrowserAppModel) {
  let (cmd, next) = browser_update(emit, msg, model)
  (@rabbita.batch([cmd, push_code_surface_cmd(next)]), next)
}

///|
fn browser_update(
  emit : @rabbita.Emit[BrowserMsg],
  msg : BrowserMsg,
  model : BrowserAppModel,
) -> (@rabbita.Cmd, BrowserAppModel) {
  match msg {
    ConnectProtocol => {
      invalidate_code_cell()
      (
        connect_protocol_cmd(emit),
        { ..model, status: "loading", status_message: "", frame: None },
      )
    }
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
        DocumentRenderFailed(uri, status, message) => {
          invalidate_code_cell()
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
              hover: model.hover.cleared(),
              definition: model.definition.deactivated(),
            },
          )
        }
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
    EditorMouseMoved(x, y, modifier) =>
      editor_mouse_moved_update(emit, model, x, y, modifier)
    EditorMouseDown(x, y, modifier) =>
      editor_mouse_down_update(emit, model, x, y, modifier)
    EditorContextMenu(x, y) => editor_context_menu_update(emit, model, x, y)
    EditorMouseLeft => editor_event_update(emit, model, MouseLeft)
    EditorScrolled(top) => (@rabbita.none, { ..model, scroll_top: top })
    ViewerMeasured(height, char_width, gutter_width) =>
      (
        @rabbita.none,
        { ..model, viewer_height: height, char_width, gutter_width },
      )
    ViewerResized => (measure_viewer_cmd(), model)
    FireHover(token) => {
      let (cmd, hover) = model.hover.fire(emit, editor_context(model), token)
      (cmd, { ..model, hover, })
    }
    HoverDisplayDue(token) => {
      let (cmd, hover) = model.hover.display_due(token)
      (cmd, { ..model, hover, })
    }
    HoverLoadingDue(token) => {
      let (cmd, hover) = model.hover.loading_due(token)
      (cmd, { ..model, hover, })
    }
    HoverMeasured(below, shift_left) =>
      (@rabbita.none, { ..model, hover: model.hover.measured(below, shift_left) })
    HoverResolved(version, token, hover) => {
      let (cmd, controller) = model.hover.resolved_hover(
        version,
        token,
        hover,
        frame_version(model.frame),
      )
      (cmd, { ..model, hover: controller })
    }
    DefinitionResolved(version, location) =>
      definition_resolved_update(emit, model, version, location)
    ReferencesResolved(version, items) =>
      (
        @rabbita.none,
        {
          ..model,
          references: model.references.resolved(items, version, model.frame),
        },
      )
    DiagnosticsResolved(version, diagnostics) =>
      if document_version(model.source_document) == version {
        semantic_payload_update(model, {
          ..model.provider_result,
          diagnostics,
        })
      } else {
        (@rabbita.none, model)
      }
    SymbolsResolved(version, symbols) =>
      if document_version(model.source_document) == version {
        semantic_payload_update(model, { ..model.provider_result, symbols, })
      } else {
        (@rabbita.none, model)
      }
    SemanticTokensResolved(version, semantic_tokens) =>
      if document_version(model.source_document) == version {
        semantic_payload_update(model, {
          ..model.provider_result,
          semantic_tokens,
        })
      } else {
        (@rabbita.none, model)
      }
    GlobalKeyDown(keyboard) => {
      let modifier = keyboard.ctrl_key() || keyboard.meta_key()
      if keyboard.key() == "Escape" {
        fan_editor_events(emit, model, [
          EscapePressed,
          GotoModifierChanged(modifier),
        ])
      } else if keyboard.key() == "F12" {
        editor_event_update(emit, model, GotoKeyCommand(keyboard.shift_key()))
      } else {
        editor_event_update(emit, model, GotoModifierChanged(modifier))
      }
    }
    GlobalKeyUp(keyboard) =>
      editor_event_update(
        emit,
        model,
        GotoModifierChanged(keyboard.ctrl_key() || keyboard.meta_key()),
      )
    SelectReference(index) =>
      (@rabbita.none, { ..model, references: model.references.selected(index) })
    OpenReference(index) =>
      match model.references.item_at(index) {
        Some(item) => {
          let closed = { ..model, references: model.references.closed() }
          definition_navigation_update(emit, closed, {
            uri: item.uri,
            range: item.range,
          })
        }
        None => (@rabbita.none, model)
      }
    ClosePeek =>
      (@rabbita.none, { ..model, references: model.references.closed() })
  }
}

///|
fn fan_editor_events(
  emit : @rabbita.Emit[BrowserMsg],
  model : BrowserAppModel,
  events : Array[EditorEvent],
) -> (@rabbita.Cmd, BrowserAppModel) {
  let commands : Array[@rabbita.Cmd] = []
  let mut current = model
  for event in events {
    let (cmd, next) = editor_event_update(emit, current, event)
    commands.push(cmd)
    current = next
  }
  (@rabbita.batch(commands), current)
}

///|
fn select_workspace_update(
  emit : @rabbita.Emit[BrowserMsg],
  model : BrowserAppModel,
  id : String,
) -> (@rabbita.Cmd, BrowserAppModel) {
  invalidate_code_cell()
  let next = {
    ..model,
    selected_workspace_id: id,
    status: "loading",
    status_message: "",
    frame: None,
    hover: HoverController::empty(),
    definition: {
      ..model.definition,
      link_anchor: None,
      active: None,
      pending_reveal: None,
    },
    references: model.references.closed(),
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
    Closed(_) => {
      fail_pending_requests("Connection lost.")
      (
        dom_mounted_status_cmd("stale"),
        {
          ..model,
          status: "stale",
          status_message: "Connection lost. Reconnecting...",
        },
      )
    }
    Errored => {
      fail_pending_requests("Remote protocol connection failed.")
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
}

///|
fn protocol_message_update(
  emit : @rabbita.Emit[BrowserMsg],
  model : BrowserAppModel,
  raw : String,
) -> (@rabbita.Cmd, BrowserAppModel) {
  match @remote_protocol.decode_server_packet(raw) {
    DecodedServerPacket(packet) =>
      // Correlated responses resume their waiting provider request; only
      // push packets fall through to app-level handling.
      if resolve_pending_response(packet) {
        (@rabbita.none, model)
      } else {
        server_packet_update(emit, model, packet)
      }
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
    // Feature results without a waiting request are unsolicited; provider
    // commands consume theirs through the pending table.
    HoverResult(_) => (@rabbita.none, model)
    DefinitionResult(_) => (@rabbita.none, model)
    ReferencesResult(_) => (@rabbita.none, model)
    RemoteError(error) => protocol_error_update(model, error)
  }
}

///|
fn definition_resolved_update(
  emit : @rabbita.Emit[BrowserMsg],
  model : BrowserAppModel,
  version : Int,
  location : @language.Location?,
) -> (@rabbita.Cmd, BrowserAppModel) {
  if frame_version(model.frame) != version {
    return (@rabbita.none, model)
  }
  match location {
    Some(location) => {
      emit_event(
        "language:definition",
        "{\"ok\":true,\"version\":" +
        version.to_string() +
        ",\"uri\":" +
        json_string(location.uri.to_string()) +
        "}",
      )
      definition_navigation_update(emit, model, {
        uri: location.uri.to_string(),
        range: location.range,
      })
    }
    None => {
      emit_event(
        "language:definition",
        "{\"ok\":false,\"version\":" + version.to_string() + "}",
      )
      (@rabbita.none, model)
    }
  }
}

///|
fn document_version(document : @workspace.SourceDocument?) -> Int {
  match document {
    Some(document) => document.version
    None => -1
  }
}

///|
/// Navigates to a resolved location: same-document targets are revealed
/// and highlighted in place; targets in another workspace file open that
/// file first and reveal once it renders.
fn definition_navigation_update(
  emit : @rabbita.Emit[BrowserMsg],
  model : BrowserAppModel,
  view : DefinitionView,
) -> (@rabbita.Cmd, BrowserAppModel) {
  if view.uri == active_document_uri(model.document) {
    let cmd = match model.frame {
      Some(frame) =>
        match line_col_for_offset(frame, view.range.start) {
          Some((line_number, _)) => reveal_line_cmd(line_number)
          None => @rabbita.none
        }
      None => @rabbita.none
    }
    (cmd, { ..model, definition: model.definition.navigated(view) })
  } else {
    let (cmd, next) = select_workspace_update(
      emit,
      model,
      workspace_id_from_uri(view.uri),
    )
    (cmd, { ..next, definition: next.definition.deferred(view) })
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
    hover: model.hover.cleared(),
    definition: model.definition.deactivated(),
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
    invalidate_code_cell()
    (
      dom_mounted_status_cmd("missing"),
      {
        ..model,
        status: "missing",
        status_message: "Source file is missing.",
        frame: None,
        hover: model.hover.cleared(),
        definition: model.definition.deactivated(),
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
  let (pending, definition) = model.definition.claim_pending(document.uri)
  let next = {
    ..model,
    status: "ready",
    status_message: "",
    frame: Some(rendered.frame),
    source_document: Some(rendered.document),
    document: Some(document),
    selected_workspace_id: selected_workspace_for_document(document),
    hover: model.hover.cleared(),
    definition,
  }
  let commands = [
    push_code_frame_cmd(next, rendered.frame),
    dom_mounted_cmd(rendered.frame, "ready"),
    measure_viewer_cmd(),
  ]
  if watch {
    commands.push(language_feature_cmds(emit, rendered.document))
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
        // The code surface is an embedded child cell so shell-only updates
        // skip its whole subtree (Rabbita's slot diff).
        Some(frame) => code_surface_cell(emit, model, frame).view()
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
/// Lines and spans carry no feature knowledge: feature classes arrive as
/// controller decorations merged onto the syntax classes here.
fn view_line(
  decorations : Array[@decorations.Decoration],
  line : @renderer.RenderLine,
) -> @html.Html {
  let line_start = line.offset
  let line_end = line.offset + line.text.length()
  let mut class_name = "code-line"
  for decoration in decorations {
    if decoration.kind == CurrentLine &&
      decoration.range.start <= line_end &&
      line_start <= decoration.range.end {
      class_name = class_name + " " + decoration.class_name
    }
  }
  @html.div(
    class=class_name,
    attrs=@html.Attrs::build().data_set("line", line.line_number.to_string()),
    [
      @html.div(class="gutter", line.line_number.to_string()),
      if line.spans.length() == 0 {
        @html.pre(class="code", if line.text == "" { " " } else { line.text })
      } else {
        @html.pre(class="code", span_nodes(decorations, line))
      },
    ],
  )
}

///|
fn span_nodes(
  decorations : Array[@decorations.Decoration],
  line : @renderer.RenderLine,
) -> Array[@html.Html] {
  let spans : Array[@html.Html] = []
  for i in 0..<line.spans.length() {
    let span = line.spans[i]
    let absolute_start = line.offset + span.start
    let absolute_end = line.offset + span.end
    spans.push(view_span(decorations, span, absolute_start, absolute_end))
  }
  spans
}

///|
/// Spans carry no handlers or data attributes: text plus classes only. All
/// interaction routes through the container hit test.
fn view_span(
  decorations : Array[@decorations.Decoration],
  span : @renderer.RenderSpan,
  absolute_start : Int,
  absolute_end : Int,
) -> @html.Html {
  let mut class_name = span.class_name
  if is_definition_candidate(span) {
    class_name = class_name + " definition-candidate"
  }
  let span_range = @core.Range(absolute_start, absolute_end)
  for decoration in decorations {
    if decoration.kind != CurrentLine &&
      decoration.range.intersects(span_range) {
      class_name = class_name + " " + decoration.class_name
    }
  }
  @html.span(class=class_name, span.text)
}

///|
fn view_empty_viewer(model : BrowserAppModel) -> @html.Html {
  @html.section(
    class="code-viewer source-empty",
    attrs=@html.Attrs::build().aria_label("Readonly code viewer"),
    [@html.div(class="source-message", source_message(model))],
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
      let patch_ms = @dom.now_ms() - last_build_finished_at.val
      let mut payload = "{"
      payload = payload +
        "\"renderedLines\":" +
        frame.lines.length().to_string()
      payload = payload + ",\"diagnostics\":"
      payload = payload + frame.diagnostics.length().to_string()
      payload = payload + ",\"status\":" + json_string(status)
      payload = payload + ",\"patchMs\":" + patch_ms.to_string()
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
