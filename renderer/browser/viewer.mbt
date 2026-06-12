///|
/// The embeddable readonly code viewer, the `vs/editor` (Monaco) role: a
/// Rabbita child cell owning the rendered frame, the input bridge, and the
/// feature controllers. It is constructed with a `&DocumentSource` and
/// reports lifecycle facts through `on_notification`; it knows nothing
/// about transports, shells, or harness event formats.
pub struct Viewer {
  priv emit : @rabbita.Emit[ViewerMsg]
  priv cell : @rabbita.Cell
}

///|
/// Lifecycle facts the viewer reports to its host. The host formats and
/// emits harness events, syncs its own chrome (title, status, tree
/// reveal), and decides what to render while the viewer has no frame.
pub(all) enum ViewerNotification {
  /// A frame build started for a document version with this many
  /// provider diagnostics merged in.
  ViewerDiagnosticsStatus(count~ : Int, version~ : Int)
  /// A frame finished building (synchronous facts, before paint).
  ViewerFrameBuilt(
    @workspace.SourceDocument,
    line_count~ : Int,
    token_count~ : Int,
    diagnostic_count~ : Int,
    build_ms~ : Double
  )
  /// The built frame painted. `fresh` marks a document switch or watched
  /// change (as opposed to a same-version feature-data re-render).
  ViewerDocumentRendered(
    @workspace.SourceDocument,
    line_count~ : Int,
    rendered_lines~ : Int,
    diagnostics~ : Array[@language.Diagnostic],
    patch_ms~ : Double,
    fresh~ : Bool
  )
  /// Opening or watching the document failed; the viewer cleared its frame.
  ViewerDocumentFailed(@workspace.FileSystemProviderError)
  /// A hover request resolved (or resolved empty) for a document version.
  ViewerHoverResolved(ok~ : Bool, version~ : Int)
}

///|
priv struct ViewerModel {
  theme : String
  /// Host-provided message shown while no frame is rendered. The host owns
  /// the policy (loading/missing/error wording); the viewer only displays
  /// it, so the viewer cell can stay mounted across document switches.
  placeholder : String
  frame : @renderer.RenderFrame?
  source_document : @workspace.SourceDocument?
  provider_result : @language.ProviderResult
  hover : HoverController
  scroll_top : Double
  viewer_height : Double
  char_width : Double
  gutter_width : Double
}

///|
priv enum ViewerMsg {
  OpenUri(@workspace.DocumentUri)
  SetTheme(String)
  SetPlaceholder(String)
  Remeasure
  EscapePressed
  PushDiagnostics(Array[@language.Diagnostic])
  PushSymbols(Array[@language.DocumentSymbol])
  PushSemanticTokens(Array[@language.SemanticToken])
  DocumentSourceResolved(@workspace.SourceDocumentLoadResult)
  DocumentRenderResolved(RenderedDocument, Bool)
  EditorMouseMoved(Double, Double)
  EditorMouseLeft
  EditorScrolled(Double)
  ViewerMeasured(Double, Double, Double)
  FireHover(Int)
  HoverDisplayDue(Int)
  HoverLoadingDue(Int)
  HoverMeasured(Bool, Double)
  HoverResolved(Int, Int, @language.Hover?)
  DiagnosticsResolved(Int, Array[@language.Diagnostic])
  SymbolsResolved(Int, Array[@language.DocumentSymbol])
  SemanticTokensResolved(Int, Array[@language.SemanticToken])
}

///|
pub fn Viewer::Viewer(
  source : &@workspace.DocumentSource,
  on_notification~ : (ViewerNotification) -> Unit,
  theme? : String = "dark",
  placeholder? : String = "",
) -> Viewer {
  let (emit, cell) = @rabbita.cell_with_emit(
    model=initial_viewer_model(theme, placeholder),
    update=(emit, msg, model) => {
      update_viewer(source, on_notification, emit, msg, model)
    },
    view=view_viewer,
  )
  { emit, cell }
}

///|
/// Embeds the viewer as a Rabbita child cell.
pub fn Viewer::view(self : Viewer) -> @html.Html {
  self.cell.view()
}

///|
/// Owns the full document-switch choreography: closes the previous
/// document and its watch, invalidates the code cell, subscribes the new
/// watch, and opens the document through the source.
pub fn Viewer::open(
  self : Viewer,
  uri : @workspace.DocumentUri,
) -> @rabbita.Cmd {
  (self.emit)(OpenUri(uri))
}

///|
/// Pushes the host's theme into the viewer (the theme keys the code cell,
/// so a change remounts it and restores the scroll offset).
pub fn Viewer::set_theme(self : Viewer, theme : String) -> @rabbita.Cmd {
  (self.emit)(SetTheme(theme))
}

///|
/// Re-measures the viewer box after a host-observed layout change.
pub fn Viewer::remeasure(self : Viewer) -> @rabbita.Cmd {
  (self.emit)(Remeasure)
}

///|
/// Pushes the message shown while the viewer has no rendered frame.
pub fn Viewer::set_placeholder(self : Viewer, message : String) -> @rabbita.Cmd {
  (self.emit)(SetPlaceholder(message))
}

///|
/// Forwards the host-captured Escape key to the feature controllers.
pub fn Viewer::escape(self : Viewer) -> @rabbita.Cmd {
  (self.emit)(EscapePressed)
}

///|
/// Push APIs for unsolicited feature data (for example server-initiated
/// diagnostics pushes routed by the host).
pub fn Viewer::push_diagnostics(
  self : Viewer,
  diagnostics : Array[@language.Diagnostic],
) -> @rabbita.Cmd {
  (self.emit)(PushDiagnostics(diagnostics))
}

///|
pub fn Viewer::push_symbols(
  self : Viewer,
  symbols : Array[@language.DocumentSymbol],
) -> @rabbita.Cmd {
  (self.emit)(PushSymbols(symbols))
}

///|
pub fn Viewer::push_semantic_tokens(
  self : Viewer,
  semantic_tokens : Array[@language.SemanticToken],
) -> @rabbita.Cmd {
  (self.emit)(PushSemanticTokens(semantic_tokens))
}

///|
fn initial_viewer_model(theme : String, placeholder : String) -> ViewerModel {
  {
    theme,
    placeholder,
    frame: None,
    source_document: None,
    provider_result: @language.ProviderResult::empty(),
    hover: HoverController::empty(),
    scroll_top: 0.0,
    viewer_height: 0.0,
    char_width: 0.0,
    gutter_width: 0.0,
  }
}

///|
/// Outer update: after every state transition, the changed feature surface
/// (if any) is pushed into the embedded code cell, so the cell only
/// re-renders when something it draws actually changed.
fn update_viewer(
  source : &@workspace.DocumentSource,
  notify : (ViewerNotification) -> Unit,
  emit : @rabbita.Emit[ViewerMsg],
  msg : ViewerMsg,
  model : ViewerModel,
) -> (@rabbita.Cmd, ViewerModel) {
  let (cmd, next) = viewer_update(source, notify, emit, msg, model)
  (
    @rabbita.batch([
      cmd,
      push_code_surface_cmd(next),
      push_code_window_cmd(next),
    ]),
    next,
  )
}

///|
fn viewer_update(
  source : &@workspace.DocumentSource,
  notify : (ViewerNotification) -> Unit,
  emit : @rabbita.Emit[ViewerMsg],
  msg : ViewerMsg,
  model : ViewerModel,
) -> (@rabbita.Cmd, ViewerModel) {
  match msg {
    OpenUri(uri) => {
      invalidate_code_cell()
      let next = { ..model, frame: None, hover: HoverController::empty() }
      (
        @rabbita.batch([
          close_document_cmd(source, model.source_document),
          load_document_cmd(source, emit, uri),
        ]),
        next,
      )
    }
    SetTheme(theme) =>
      // The theme keys the code cell, so changing it remounts the viewer
      // element; rehook the fresh element and restore its scroll offset.
      (
        @rabbita.batch([
          attach_scroll_hook_cmd(emit),
          restore_scroll_cmd(model.scroll_top),
        ]),
        { ..model, theme, },
      )
    SetPlaceholder(message) =>
      (@rabbita.none, { ..model, placeholder: message })
    Remeasure => (measure_viewer_cmd(emit), model)
    EscapePressed => editor_event_update(emit, model, EscapePressed)
    PushDiagnostics(diagnostics) =>
      provider_result_update(notify, emit, model, {
        ..model.provider_result,
        diagnostics,
      })
    PushSymbols(symbols) =>
      provider_result_update(notify, emit, model, {
        ..model.provider_result,
        symbols,
      })
    PushSemanticTokens(semantic_tokens) =>
      provider_result_update(notify, emit, model, {
        ..model.provider_result,
        semantic_tokens,
      })
    DocumentSourceResolved(result) =>
      match result {
        SourceDocumentLoaded(document) =>
          document_loaded_update(notify, emit, model, document)
        SourceDocumentLoadError(error) => {
          invalidate_code_cell()
          (
            @cmd.custom_cmd(_ => notify(ViewerDocumentFailed(error))),
            { ..model, frame: None, hover: model.hover.cleared() },
          )
        }
      }
    DocumentRenderResolved(rendered, fresh) =>
      document_rendered_update(notify, emit, model, rendered, fresh)
    EditorMouseMoved(x, y) => editor_mouse_moved_update(emit, model, x, y)
    EditorMouseLeft => editor_event_update(emit, model, MouseLeft)
    EditorScrolled(top) => (@rabbita.none, { ..model, scroll_top: top })
    ViewerMeasured(height, char_width, gutter_width) =>
      (
        @rabbita.none,
        { ..model, viewer_height: height, char_width, gutter_width },
      )
    FireHover(token) => {
      let (cmd, hover) = model.hover.fire(emit, editor_context(model), token)
      (cmd, { ..model, hover, })
    }
    HoverDisplayDue(token) => {
      let (cmd, hover) = model.hover.display_due(emit, token)
      (cmd, { ..model, hover, })
    }
    HoverLoadingDue(token) => {
      let (cmd, hover) = model.hover.loading_due(token)
      (cmd, { ..model, hover, })
    }
    HoverMeasured(below, shift_left) =>
      (
        @rabbita.none,
        { ..model, hover: model.hover.measured(below, shift_left) },
      )
    HoverResolved(version, token, hover) => {
      let (cmd, controller) = model.hover.resolved_hover(
        notify,
        emit,
        version,
        token,
        hover,
        frame_version(model.frame),
      )
      (cmd, { ..model, hover: controller })
    }
    DiagnosticsResolved(version, diagnostics) =>
      if document_version(model.source_document) == version {
        provider_result_update(notify, emit, model, {
          ..model.provider_result,
          diagnostics,
        })
      } else {
        (@rabbita.none, model)
      }
    SymbolsResolved(version, symbols) =>
      if document_version(model.source_document) == version {
        provider_result_update(notify, emit, model, {
          ..model.provider_result,
          symbols,
        })
      } else {
        (@rabbita.none, model)
      }
    SemanticTokensResolved(version, semantic_tokens) =>
      if document_version(model.source_document) == version {
        provider_result_update(notify, emit, model, {
          ..model.provider_result,
          semantic_tokens,
        })
      } else {
        (@rabbita.none, model)
      }
  }
}

///|
/// Opens and watches a document through the `DocumentSource` trait: the
/// open resolves as a correlated request, the watch listener dispatches
/// every later load result back into the viewer's update loop.
fn load_document_cmd(
  source : &@workspace.DocumentSource,
  emit : @rabbita.Emit[ViewerMsg],
  uri : @workspace.DocumentUri,
) -> @rabbita.Cmd {
  @rabbita.batch([
    @cmd.custom_cmd(scheduler => {
      dispose_active_document_watch()
      active_document_watch.val = Some(
        source.watch_document(uri, result => {
          scheduler.add(emit(DocumentSourceResolved(result)))
        }),
      )
    }),
    @cmd.perform(result => emit(DocumentSourceResolved(result)), async fn() noraise {
      source.open_document(uri) catch {
        _ =>
          SourceDocumentLoadError(
            FileSystemProviderError(Unavailable, "Document open failed.", uri~),
          )
      }
    }),
  ])
}

///|
fn close_document_cmd(
  source : &@workspace.DocumentSource,
  document : @workspace.SourceDocument?,
) -> @rabbita.Cmd {
  match document {
    Some(document) =>
      @cmd.custom_cmd(_ => {
        dispose_active_document_watch()
        source.close_document(document.uri)
      })
    None => @rabbita.none
  }
}

///|
/// The single live document watch. Opening a new document disposes the
/// previous watch before subscribing the next one.
let active_document_watch : Ref[@workspace.FileWatch?] = Ref(None)

///|
fn dispose_active_document_watch() -> Unit {
  match active_document_watch.val {
    Some(watch) => watch.dispose()
    None => ()
  }
  active_document_watch.val = None
}

///|
fn document_loaded_update(
  notify : (ViewerNotification) -> Unit,
  emit : @rabbita.Emit[ViewerMsg],
  model : ViewerModel,
  document : @workspace.SourceDocument,
) -> (@rabbita.Cmd, ViewerModel) {
  let next = {
    ..model,
    provider_result: @language.ProviderResult::empty(),
    hover: model.hover.cleared(),
  }
  (
    render_document_cmd(
      notify,
      emit,
      document,
      model.source_document,
      next.provider_result,
      true,
    ),
    next,
  )
}

///|
/// Re-renders the current document with updated feature data.
fn provider_result_update(
  notify : (ViewerNotification) -> Unit,
  emit : @rabbita.Emit[ViewerMsg],
  model : ViewerModel,
  providers : @language.ProviderResult,
) -> (@rabbita.Cmd, ViewerModel) {
  match model.source_document {
    Some(document) =>
      (
        render_document_cmd(
          notify,
          emit,
          document,
          model.source_document,
          providers,
          false,
        ),
        { ..model, provider_result: providers },
      )
    None => (@rabbita.none, model)
  }
}

///|
fn document_rendered_update(
  notify : (ViewerNotification) -> Unit,
  emit : @rabbita.Emit[ViewerMsg],
  model : ViewerModel,
  rendered : RenderedDocument,
  fresh : Bool,
) -> (@rabbita.Cmd, ViewerModel) {
  let next = {
    ..model,
    frame: Some(rendered.frame),
    source_document: Some(rendered.document),
    hover: model.hover.cleared(),
  }
  // A rotated cell key remounts the viewer element, which starts at
  // scroll offset zero.
  let next = if code_cell_retained(next, rendered.frame) {
    next
  } else {
    { ..next, scroll_top: 0.0 }
  }
  let window = code_cell_window(next, rendered.frame)
  let commands = [
    push_code_frame_cmd(next, rendered.frame),
    rendered_notification_cmd(
      notify,
      rendered,
      window.end - window.start,
      fresh,
    ),
    attach_scroll_hook_cmd(emit),
    measure_viewer_cmd(emit),
  ]
  if fresh {
    commands.push(language_feature_cmds(emit, rendered.document))
  }
  (@rabbita.batch(commands), next)
}

///|
/// Reports the painted frame to the host after the patch flushed, so the
/// notification carries the real DOM patch duration.
fn rendered_notification_cmd(
  notify : (ViewerNotification) -> Unit,
  rendered : RenderedDocument,
  rendered_lines : Int,
  fresh : Bool,
) -> @rabbita.Cmd {
  @cmd.custom_cmd(
    _ => {
      let patch_ms = @dom.now_ms() - last_build_finished_at.val
      notify(
        ViewerDocumentRendered(
          rendered.document,
          line_count=rendered.frame.line_count,
          rendered_lines~,
          diagnostics=rendered.frame.diagnostics,
          patch_ms~,
          fresh~,
        ),
      )
    },
    kind=@cmd.after_render,
  )
}

///|
fn document_version(document : @workspace.SourceDocument?) -> Int {
  match document {
    Some(document) => document.version
    None => -1
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
fn view_viewer(
  emit : @rabbita.Emit[ViewerMsg],
  model : ViewerModel,
) -> @html.Html {
  match model.frame {
    // The code surface is an embedded child cell so viewer-state updates
    // that change nothing it draws skip its whole subtree (Rabbita's
    // slot diff).
    Some(frame) => code_surface_cell(emit, model, frame).view()
    None =>
      @html.section(
        class="code-viewer source-empty",
        attrs=@html.Attrs::build().aria_label("Readonly code viewer"),
        [@html.div(class="source-message", model.placeholder)],
      )
  }
}
