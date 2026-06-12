///|
/// Feature state the code surface renders besides the frame itself. Pure
/// data with equality, so the shell can skip pushes that change nothing.
priv struct CodeSurface {
  hover : HoverController
} derive(Eq)

///|
priv struct CodeCellModel {
  frame : @renderer.RenderFrame
  surface : CodeSurface
  window : @renderer.LineWindow
}

///|
priv enum CodeCellMsg {
  SurfaceUpdated(CodeSurface)
  FrameUpdated(@renderer.RenderFrame, CodeSurface)
  WindowShifted(@renderer.LineWindow)
}

///|
priv struct CodeCellEntry {
  key : String
  emit : @rabbita.Emit[CodeCellMsg]
  cell : @rabbita.Cell
  mut surface : CodeSurface
  mut window : @renderer.LineWindow
}

///|
/// Lines rendered beyond each viewport edge so native scrolling stays
/// inside already-rendered DOM between window updates.
let line_overscan = 20

///|
fn desired_window(
  model : ViewerModel,
  frame : @renderer.RenderFrame,
) -> @renderer.LineWindow {
  @renderer.visible_window(
    model.scroll_top,
    model.viewer_height,
    editor_line_height,
    frame.line_count,
    line_overscan,
  )
}

///|
/// Whether the cached cell instance survives for this model and frame.
fn code_cell_retained(
  model : ViewerModel,
  frame : @renderer.RenderFrame,
) -> Bool {
  match code_cell_cache.val {
    Some(entry) => entry.key == code_cell_key(model, frame)
    None => false
  }
}

///|
/// The window the mounted (or about-to-mount) code cell renders.
fn code_cell_window(
  model : ViewerModel,
  frame : @renderer.RenderFrame,
) -> @renderer.LineWindow {
  match code_cell_cache.val {
    Some(entry) =>
      if entry.key == code_cell_key(model, frame) {
        entry.window
      } else {
        desired_window(model, frame)
      }
    None => desired_window(model, frame)
  }
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
fn code_cell_key(model : ViewerModel, frame : @renderer.RenderFrame) -> String {
  let uri = match model.source_document {
    Some(document) => document.uri.to_string()
    None => ""
  }
  uri + "#" + frame.version.to_string() + "#" + model.theme
}

///|
fn code_surface(model : ViewerModel) -> CodeSurface {
  { hover: model.hover }
}

///|
/// Returns the cached code cell for the current document, creating a new
/// instance when the cache key rotates.
fn code_surface_cell(
  emit : @rabbita.Emit[ViewerMsg],
  model : ViewerModel,
  frame : @renderer.RenderFrame,
) -> @rabbita.Cell {
  let key = code_cell_key(model, frame)
  match code_cell_cache.val {
    Some(entry) => if entry.key == key { return entry.cell }
    None => ()
  }
  let surface = code_surface(model)
  let window = desired_window(model, frame)
  let (cell_emit, cell) = @rabbita.cell_with_emit(
    model={ frame, surface, window },
    update=update_code_cell,
    view=(_, cell_model) => view_code_surface(emit, cell_model),
  )
  code_cell_cache.val = Some({ key, emit: cell_emit, cell, surface, window })
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
    FrameUpdated(frame, surface) => (@rabbita.none, { ..model, frame, surface })
    WindowShifted(window) => (@rabbita.none, { ..model, window, })
  }
}

///|
/// Pushes a recomputed line window into the mounted code cell when scroll
/// or viewport changes moved it past the hysteresis band.
fn push_code_window_cmd(model : ViewerModel) -> @rabbita.Cmd {
  match (code_cell_cache.val, model.frame) {
    (Some(entry), Some(frame)) =>
      if entry.key == code_cell_key(model, frame) {
        let next = desired_window(model, frame)
        if @renderer.window_needs_update(entry.window, next, line_overscan) {
          entry.window = next
          (entry.emit)(WindowShifted(next))
        } else {
          @rabbita.none
        }
      } else {
        @rabbita.none
      }
    _ => @rabbita.none
  }
}

///|
/// Pushes the current feature surface into the mounted code cell when it
/// actually changed; shell-only updates push nothing and the cell slot is
/// skipped wholesale.
fn push_code_surface_cmd(model : ViewerModel) -> @rabbita.Cmd {
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
  model : ViewerModel,
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
/// Renders only the windowed lines, with spacers keeping the full scroll
/// height so the native scrollbar stays correct.
fn view_code_surface(
  emit : @rabbita.Emit[ViewerMsg],
  model : CodeCellModel,
) -> @html.Html {
  let frame = model.frame
  let surface = model.surface
  let start = @core.clamp_int(model.window.start, 0, frame.lines.length())
  let end = @core.clamp_int(model.window.end, start, frame.lines.length())
  let decorations = controller_decorations(surface)
  let top_px = start * editor_line_height
  let bottom_px = (frame.line_count - end) * editor_line_height
  let children : Map[String, @html.Html] = {}
  children["char-probe"] = @html.span(
    class="char-probe",
    attrs=@html.Attrs::build().aria_hidden("true"),
    char_probe_text,
  )
  children["top-spacer"] = line_spacer(top_px)
  for index in start..<end {
    let line = frame.lines[index]
    children["L" + line.line_number.to_string()] = view_line(decorations, line)
  }
  children["bottom-spacer"] = line_spacer(bottom_px)
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

///|
fn line_spacer(height_px : Int) -> @html.Html {
  @html.div(
    attrs=@html.Attrs::build()
      .style("height", height_px.to_string() + "px")
      .aria_hidden("true"),
    ([] : Array[@html.Html]),
  )
}
