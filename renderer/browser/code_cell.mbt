///|
/// Feature state the code surface renders besides the frame itself. Pure
/// data with equality, so the shell can skip pushes that change nothing.
priv struct CodeSurface {
  document_uri : String
  hover : HoverController
  definition : DefinitionController
  references : ReferencesController
} derive(Eq)

///|
priv struct CodeCellModel {
  frame : @renderer.RenderFrame
  surface : CodeSurface
}

///|
priv enum CodeCellMsg {
  SurfaceUpdated(CodeSurface)
  FrameUpdated(@renderer.RenderFrame, CodeSurface)
}

///|
priv struct CodeCellEntry {
  key : String
  emit : @rabbita.Emit[CodeCellMsg]
  cell : @rabbita.Cell
  mut surface : CodeSurface
}

///|
/// The cached code-surface cell instance. Rabbita skips an embedded cell
/// slot whose instance is unchanged, so reusing one instance makes shell
/// re-renders (sidebar, topbar, status) free of line-subtree work; the
/// instance is recreated only when the document version or theme changes.
let code_cell_cache : Ref[CodeCellEntry?] = Ref(None)

///|
fn invalidate_code_cell() -> Unit {
  code_cell_cache.val = None
}

///|
fn code_cell_key(model : BrowserAppModel, frame : @renderer.RenderFrame) -> String {
  active_document_uri(model.document) +
  "#" +
  frame.version.to_string() +
  "#" +
  model.theme
}

///|
fn code_surface(model : BrowserAppModel) -> CodeSurface {
  {
    document_uri: active_document_uri(model.document),
    hover: model.hover,
    definition: model.definition,
    references: model.references,
  }
}

///|
/// Returns the cached code cell for the current document, creating a new
/// instance when the cache key rotates.
fn code_surface_cell(
  emit : @rabbita.Emit[BrowserMsg],
  model : BrowserAppModel,
  frame : @renderer.RenderFrame,
) -> @rabbita.Cell {
  let key = code_cell_key(model, frame)
  match code_cell_cache.val {
    Some(entry) => if entry.key == key { return entry.cell }
    None => ()
  }
  let surface = code_surface(model)
  let (cell_emit, cell) = @rabbita.cell_with_emit(
    model={ frame, surface },
    update=update_code_cell,
    view=(_, cell_model) => view_code_surface(emit, cell_model),
  )
  code_cell_cache.val = Some({ key, emit: cell_emit, cell, surface })
  cell
}

///|
fn update_code_cell(
  _emit : @rabbita.Emit[CodeCellMsg],
  msg : CodeCellMsg,
  model : CodeCellModel,
) -> (@rabbita.Cmd, CodeCellModel) {
  match msg {
    SurfaceUpdated(surface) => (@rabbita.none, { ..model, surface, })
    FrameUpdated(frame, surface) => (@rabbita.none, { frame, surface })
  }
}

///|
/// Pushes the current feature surface into the mounted code cell when it
/// actually changed; shell-only updates push nothing and the cell slot is
/// skipped wholesale.
fn push_code_surface_cmd(model : BrowserAppModel) -> @rabbita.Cmd {
  match (code_cell_cache.val, model.frame) {
    (Some(entry), Some(frame)) =>
      if entry.key == code_cell_key(model, frame) {
        let surface = code_surface(model)
        if surface == entry.surface {
          @rabbita.none
        } else {
          entry.surface = surface
          (entry.emit)(SurfaceUpdated(surface))
        }
      } else {
        @rabbita.none
      }
    _ => @rabbita.none
  }
}

///|
/// Replaces the cell's frame in place after a same-version re-render (for
/// example when semantic tokens arrive for the displayed document).
fn push_code_frame_cmd(
  model : BrowserAppModel,
  frame : @renderer.RenderFrame,
) -> @rabbita.Cmd {
  match code_cell_cache.val {
    Some(entry) =>
      if entry.key == code_cell_key(model, frame) {
        let surface = code_surface(model)
        entry.surface = surface
        (entry.emit)(FrameUpdated(frame, surface))
      } else {
        @rabbita.none
      }
    None => @rabbita.none
  }
}

///|
fn view_code_surface(
  emit : @rabbita.Emit[BrowserMsg],
  model : CodeCellModel,
) -> @html.Html {
  let frame = model.frame
  let surface = model.surface
  let decorations = controller_decorations(surface)
  let zone = surface.references.zone_widget(
    emit,
    frame,
    surface.document_uri,
  )
  let children : Map[String, @html.Html] = {}
  children["char-probe"] = @html.span(
    class="char-probe",
    attrs=@html.Attrs::build().aria_hidden("true"),
    char_probe_text,
  )
  for line in frame.lines {
    children["L" + line.line_number.to_string()] = view_line(decorations, line)
    match zone {
      Some((anchor_line, widget)) =>
        if anchor_line == line.line_number {
          children["references-peek"] = widget
        }
      None => ()
    }
  }
  match surface.hover.widget(frame) {
    Some(widget) => children["hover"] = widget
    None => ()
  }
  @html.section(
    class="code-viewer",
    attrs=code_viewer_attrs(emit),
    @html.div(class="code-lines", children),
  )
}
