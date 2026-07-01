///|
/// Constructs `@view_layout.ViewportData` from view-model state. These live in
/// `view_model` (not `view_layout`) to keep the dependency one-directional:
/// `view_model -> view_layout`. `viewLayout/viewLinesViewportData.ts` in Monaco
/// takes an `IViewModel` in its constructor, which is the file-level
/// `viewLayout <-> viewModel` cycle TypeScript tolerates; MoonBit forbids the
/// cross-package cycle, so the view-model-dependent constructors are inverted
/// here as free functions over the `pub(all)` `ViewportData`.

///|
/// Builds viewport data from a precomputed render frame. This path has no
/// coordinate converter, so it carries no decorations; the view-model path
/// below is the one the running viewer uses.
pub fn viewport_data_from_render_frame(
  frame : RenderFrame,
  line_height~ : Int,
) -> @view_layout.ViewportData {
  let lines : Array[@view_layout.ViewLineRenderingData] = []
  let line_decorations : Array[Array[@view_layout.LineDecoration]] = []
  let relative_vertical_offset : Array[Int] = []
  for index in 0..<frame.lines.length() {
    let line = frame.lines[index]
    lines.push(view_line_rendering_data_from_render_line(line))
    line_decorations.push(line_decorations_for_line(line, []))
    relative_vertical_offset.push(index * line_height)
  }
  // The frame viewport is a 1-based half-open window; the inclusive last line is
  // `end_line - 1`.
  let start_line_number = frame.viewport.start_line
  let end_line_number = frame.viewport.end_line - 1
  let end_column = match lines.last() {
    Some(line) => line.max_column
    None => 1
  }
  {
    start_line_number,
    end_line_number,
    relative_vertical_offset,
    line_height,
    visible_range: {
      start_line_number,
      start_column: 1,
      end_line_number,
      end_column,
    },
    big_numbers_delta: 0,
    lines,
    line_decorations,
    view_zones: [],
  }
}

///|
/// Builds viewport data directly from a view model and layout window.
pub fn viewport_data_from_view_model(
  view_model : ViewModel,
  window : @view_layout.LineWindow,
  line_height~ : Int,
  decorations? : Array[@model.Decoration] = [],
  layout? : @view_layout.ViewLayout,
) -> @view_layout.ViewportData {
  let start_line = @base_common.clamp_int(
    window.start,
    1,
    view_model.line_count(),
  )
  let end_line = @base_common.clamp_int(
    window.end,
    start_line + 1,
    view_model.line_count() + 1,
  )
  let lines : Array[@view_layout.ViewLineRenderingData] = []
  let line_decorations : Array[Array[@view_layout.LineDecoration]] = []
  let relative_vertical_offset : Array[Int] = []
  let view_model_lines = view_model.lines()
  // Decorations baked into the source (markers/diagnostics) plus the
  // controller-contributed ones (hover) are converted once to view
  // coordinates, then clipped per line — no document-offset round-trips.
  let model_decorations = view_model.decorations()
  let view_decorations = [
    ..model_decorations.view_decorations(),
    ..model_decorations.to_view_decorations(decorations),
  ]
  let normalized_window : @view_layout.LineWindow = {
    start: start_line,
    end: end_line,
  }
  for line_number in start_line..<end_line {
    let render_line = view_model_lines.render_line(line_number)
    lines.push(
      view_model_lines.view_line_rendering_data(line_number, view_decorations~),
    )
    line_decorations.push(
      line_decorations_for_line(render_line, view_decorations),
    )
    relative_vertical_offset.push(
      match layout {
        Some(layout) =>
          layout.relative_vertical_offset_for_line(
            normalized_window, line_number,
          )
        None => (line_number - start_line) * line_height
      },
    )
  }
  let start_line_number = start_line
  let end_line_number = end_line - 1
  let end_column = match lines.last() {
    Some(line) => line.max_column
    None => 1
  }
  {
    start_line_number,
    end_line_number,
    relative_vertical_offset,
    line_height,
    visible_range: {
      start_line_number,
      start_column: 1,
      end_line_number,
      end_column,
    },
    big_numbers_delta: 0,
    lines,
    line_decorations,
    view_zones: match layout {
      Some(layout) => layout.view_zone_viewport_data(normalized_window)
      None => []
    },
  }
}
