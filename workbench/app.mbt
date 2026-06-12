///|
/// The shipped app shell, the `vs/workbench` role: it owns the websocket
/// protocol client, composes the viewer library with the explorer widget,
/// and renders the chrome around them (topbar, sidebar, diagnostics
/// panel, status messages, theme).
priv struct WorkbenchDocumentView {
  uri : String
  display_name : String
  language_id : String
  version : Int
}

///|
priv struct WorkbenchModel {
  status : String
  status_message : String
  theme : String
  document : WorkbenchDocumentView?
  line_count : Int
  diagnostics : Array[@language.Diagnostic]
  /// Mirrors whether the viewer holds a rendered frame; while it does not,
  /// the shell renders its own status placeholder instead of the viewer.
  viewer_has_frame : Bool
}

///|
priv enum WorkbenchMsg {
  ConnectProtocol
  ProtocolEvent(@websocket.Event)
  ProtocolSendFailed(String)
  SelectWorkspace(@workspace.DocumentUri)
  AutoOpenResolved(@workspace.DocumentUri?)
  ViewerNotified(@browser.ViewerNotification)
  ToggleTheme
  GlobalKeyDown(@common.Keyboard)
  WindowResized
}

///|
let workbench_dispatch : Ref[((WorkbenchMsg) -> Unit)?] = Ref(None)

///|
fn dispatch_workbench_msg(msg : WorkbenchMsg) -> Unit {
  match workbench_dispatch.val {
    Some(dispatch) => dispatch(msg)
    None => ()
  }
}

///|
/// The embedded viewer instance, created on first use with the remote
/// document source and the notification bridge into the shell update loop.
let viewer_cell : Ref[@browser.Viewer?] = Ref(None)

///|
fn workbench_viewer() -> @browser.Viewer {
  match viewer_cell.val {
    Some(viewer) => viewer
    None => {
      let viewer = @browser.Viewer(
        document_source,
        on_notification=notification => {
          dispatch_workbench_msg(ViewerNotified(notification))
        },
        theme=stored_theme(),
        placeholder=source_message(initial_workbench_model()),
      )
      viewer_cell.val = Some(viewer)
      viewer
    }
  }
}

///|
pub fn start_app() -> Unit {
  @dom.install_host_capabilities()
  register_remote_language_providers()
  mount_app()
}

///|
pub fn mount_app() -> Unit {
  let (emit, cell) = @rabbita.cell_with_emit(
    model=initial_workbench_model(),
    update=update_workbench,
    view=view_workbench,
    subscriptions=(emit, _model) => {
      @sub.batch([
        @sub.on_key_down(emit.map(keyboard => GlobalKeyDown(keyboard))),
        @sub.on_resize(emit.map(_ => WindowResized)),
      ])
    },
  )
  let app = @rabbita.new(cell)
  app.with_init(
    @cmd.custom_cmd(scheduler => {
      workbench_dispatch.val = Some(msg => scheduler.add(emit(msg)))
      protocol_send.val = Some(packet => {
        scheduler.add(send_client_packet_cmd(emit, packet))
      })
      scheduler.add(emit(ConnectProtocol))
    }),
  )
  app.mount("app")
}

///|
fn initial_workbench_model() -> WorkbenchModel {
  {
    status: "loading",
    status_message: "",
    theme: stored_theme(),
    document: None,
    line_count: 0,
    diagnostics: [],
    viewer_has_frame: false,
  }
}

///|
/// Outer update: the shell owns the empty-viewer message policy, and the
/// viewer displays it; push the wording into the viewer whenever a state
/// transition changes it.
fn update_workbench(
  emit : @rabbita.Emit[WorkbenchMsg],
  msg : WorkbenchMsg,
  model : WorkbenchModel,
) -> (@rabbita.Cmd, WorkbenchModel) {
  let (cmd, next) = workbench_update(emit, msg, model)
  let message = source_message(next)
  if message == source_message(model) {
    (cmd, next)
  } else {
    (@rabbita.batch([cmd, workbench_viewer().set_placeholder(message)]), next)
  }
}

///|
fn workbench_update(
  emit : @rabbita.Emit[WorkbenchMsg],
  msg : WorkbenchMsg,
  model : WorkbenchModel,
) -> (@rabbita.Cmd, WorkbenchModel) {
  match msg {
    ConnectProtocol =>
      (
        connect_protocol_cmd(emit),
        { ..model, status: "loading", status_message: "" },
      )
    ProtocolEvent(event) => protocol_event_update(emit, model, event)
    ProtocolSendFailed(message) =>
      (
        dom_mounted_status_cmd("error"),
        { ..model, status: "error", status_message: message },
      )
    SelectWorkspace(uri) => select_workspace_update(model, uri)
    AutoOpenResolved(found) =>
      match found {
        Some(uri) =>
          if model.document is None {
            select_workspace_update(model, uri)
          } else {
            (@rabbita.none, model)
          }
        // An empty workspace keeps the loading placeholder.
        None => (@rabbita.none, model)
      }
    ViewerNotified(notification) => viewer_notified_update(model, notification)
    ToggleTheme => {
      let theme = if model.theme == "light" { "dark" } else { "light" }
      (
        @rabbita.batch([
          persist_theme_cmd(theme),
          workbench_viewer().set_theme(theme),
        ]),
        { ..model, theme, },
      )
    }
    GlobalKeyDown(keyboard) =>
      if keyboard.key() == "Escape" {
        (workbench_viewer().escape(), model)
      } else {
        (@rabbita.none, model)
      }
    WindowResized => (workbench_viewer().remeasure(), model)
  }
}

///|
fn select_workspace_update(
  model : WorkbenchModel,
  uri : @workspace.DocumentUri,
) -> (@rabbita.Cmd, WorkbenchModel) {
  (
    workbench_viewer().open(uri),
    { ..model, status: "loading", status_message: "", viewer_has_frame: false },
  )
}

///|
/// Viewer lifecycle facts drive the shell: status and topbar sync, the
/// explorer's autoReveal, and the harness events the viewer no longer
/// formats itself.
fn viewer_notified_update(
  model : WorkbenchModel,
  notification : @browser.ViewerNotification,
) -> (@rabbita.Cmd, WorkbenchModel) {
  match notification {
    ViewerDiagnosticsStatus(count~, version~) => {
      emit_language_status(count, version)
      (@rabbita.none, model)
    }
    ViewerFrameBuilt(
      document,
      line_count~,
      token_count~,
      diagnostic_count~,
      build_ms~
    ) => {
      @dom.set_current_document(document.to_json())
      emit_render_event(
        line_count,
        token_count,
        diagnostic_count,
        document.version,
        build_ms,
      )
      (@rabbita.none, model)
    }
    ViewerDocumentRendered(
      document,
      line_count~,
      rendered_lines~,
      diagnostics~,
      patch_ms~,
      fresh~
    ) => {
      emit_dom_mounted(
        rendered_lines,
        diagnostics.length(),
        "ready",
        patch_ms=Some(patch_ms),
      )
      let next = {
        ..model,
        status: "ready",
        status_message: "",
        document: Some(document_to_view(document)),
        line_count,
        diagnostics,
        viewer_has_frame: true,
      }
      if fresh {
        // The viewer lifecycle drives the explorer's autoReveal: a freshly
        // loaded document expands its ancestor chain and selects its row.
        (workspace_file_tree().set_active(document.uri), next)
      } else {
        (@rabbita.none, next)
      }
    }
    ViewerDocumentFailed(error) => {
      emit_event("language:error", error.to_json())
      if error.code == FileNotFound {
        (
          dom_mounted_status_cmd("missing"),
          {
            ..model,
            status: "missing",
            status_message: "Source file is missing.",
            viewer_has_frame: false,
          },
        )
      } else {
        (
          dom_mounted_status_cmd("error"),
          {
            ..model,
            status: "error",
            status_message: error.message,
            viewer_has_frame: false,
          },
        )
      }
    }
    ViewerHoverResolved(ok~, version~) => {
      emit_hover_status(ok, version)
      (@rabbita.none, model)
    }
  }
}

///|
fn protocol_event_update(
  emit : @rabbita.Emit[WorkbenchMsg],
  model : WorkbenchModel,
  event : @websocket.Event,
) -> (@rabbita.Cmd, WorkbenchModel) {
  match event {
    // A fresh socket (first connect or reconnect) re-resolves the explorer
    // tree; the auto-open policy fills the viewer when nothing is open yet.
    Opened => {
      let commands = [workspace_file_tree().refresh()]
      if model.document is None {
        commands.push(auto_open_first_file_cmd(emit))
      }
      (@rabbita.batch(commands), { ..model, status_message: "" })
    }
    Message(raw) => protocol_message_update(model, raw)
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
  model : WorkbenchModel,
  raw : String,
) -> (@rabbita.Cmd, WorkbenchModel) {
  match @remote_protocol.decode_server_packet(raw) {
    DecodedServerPacket(packet) =>
      // Correlated responses resume their waiting provider request; only
      // push packets fall through to app-level handling.
      if resolve_pending_response(packet) {
        (@rabbita.none, model)
      } else {
        server_packet_update(model, packet)
      }
    ServerPacketDecodeError(error) => protocol_error_update(model, error)
  }
}

///|
fn server_packet_update(
  model : WorkbenchModel,
  packet : @remote_protocol.ServerPacket,
) -> (@rabbita.Cmd, WorkbenchModel) {
  match packet {
    // Uncorrelated document packets are watch pushes; the document source
    // routes them to the listener registered for their URI.
    DocumentLoaded(payload) => (route_watched_document_cmd(payload), model)
    DocumentChanged(payload) => (route_watched_document_cmd(payload), model)
    // Server-initiated feature pushes flow into the viewer's public
    // feature-data API.
    Diagnostics(payload) =>
      (workbench_viewer().push_diagnostics(payload.diagnostics), model)
    DocumentSymbolsResult(payload) =>
      (workbench_viewer().push_symbols(payload.symbols), model)
    SemanticTokensResult(payload) =>
      (workbench_viewer().push_semantic_tokens(payload.semantic_tokens), model)
    // Feature results without a waiting request are unsolicited; provider
    // commands consume theirs through the pending table.
    DirectoryResolved(_) => (@rabbita.none, model)
    HoverResult(_) => (@rabbita.none, model)
    DefinitionResult(_) => (@rabbita.none, model)
    ReferencesResult(_) => (@rabbita.none, model)
    RemoteError(error) =>
      match watched_uri_for_error(error) {
        Some(uri_key) => (route_watched_error_cmd(uri_key, error), model)
        None => protocol_error_update(model, error)
      }
  }
}

///|
fn protocol_error_update(
  model : WorkbenchModel,
  error : @remote_protocol.ProtocolError,
) -> (@rabbita.Cmd, WorkbenchModel) {
  emit_event("language:error", error.to_json())
  if error.provider_code == "FileNotFound" {
    (
      dom_mounted_status_cmd("missing"),
      {
        ..model,
        status: "missing",
        status_message: "Source file is missing.",
        viewer_has_frame: false,
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
fn document_to_view(
  document : @workspace.SourceDocument,
) -> WorkbenchDocumentView {
  {
    uri: document.uri.to_string(),
    display_name: document.display_name,
    language_id: document.language_id,
    version: document.version,
  }
}

///|
fn view_workbench(
  emit : @rabbita.Emit[WorkbenchMsg],
  model : WorkbenchModel,
) -> @html.Html {
  @html.main_(class="editor-shell", attrs=shell_attrs(model), [
    view_topbar(model),
    @html.div(class="editor-main", [
      view_sidebar(emit, model),
      // The viewer cell is always embedded so its update loop runs even
      // before the first document renders; while it has no frame it shows
      // the placeholder message the shell pushes in.
      workbench_viewer().view(),
    ]),
    view_diagnostics(model),
  ])
}

///|
fn shell_attrs(model : WorkbenchModel) -> @html.Attrs {
  let mut attrs = @html.Attrs::build()
  attrs = attrs.data_set("status", model.status)
  attrs = attrs.data_set("theme", model.theme)
  attrs = attrs.data_set("line-count", line_count_string(model))
  match model.document {
    Some(document) => attrs = attrs.data_set("source-uri", document.uri)
    None => ()
  }
  attrs
}

///|
fn view_topbar(model : WorkbenchModel) -> @html.Html {
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
/// Sidebar chrome (Explorer title, theme toggle) stays in the shell; the
/// tree itself is the embedded explorer widget cell.
fn view_sidebar(
  emit : @rabbita.Emit[WorkbenchMsg],
  _model : WorkbenchModel,
) -> @html.Html {
  @html.aside(
    class="workspace-sidebar",
    attrs=@html.Attrs::build().aria_label("Workspace files"),
    [
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
      workspace_file_tree().view(),
    ],
  )
}

///|
fn view_diagnostics(model : WorkbenchModel) -> @html.Html {
  let children : Array[@html.Html] = [@html.strong("Diagnostics")]
  if model.viewer_has_frame {
    for diagnostic in model.diagnostics {
      children.push(
        @html.div(
          class="diagnostic-item",
          diagnostic.severity.label() + ": " + diagnostic.message,
        ),
      )
    }
  }
  @html.aside(
    class="diagnostics",
    attrs=@html.Attrs::build().aria_label("Diagnostics"),
    children,
  )
}

///|
fn line_count_string(model : WorkbenchModel) -> String {
  if model.viewer_has_frame {
    model.line_count.to_string()
  } else {
    "0"
  }
}

///|
fn document_title(model : WorkbenchModel) -> String {
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
fn document_meta(model : WorkbenchModel) -> String {
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
fn status_text(model : WorkbenchModel) -> String {
  let count = if model.viewer_has_frame {
    model.line_count.to_string() + " lines"
  } else {
    ""
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
fn source_message(model : WorkbenchModel) -> String {
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
