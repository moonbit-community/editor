///|
/// Line-renderer viewport data derived from the backend-neutral view model and
/// layout state.
pub(all) struct ViewportData {
  start_line_number : Int
  end_line_number : Int
  relative_vertical_offset : Array[Int]
  line_height : Int
  visible_range : @view_line_renderer.ViewRange
  big_numbers_delta : Int
  lines : Array[@view_line_renderer.ViewLineRenderingData]
  line_decorations : Array[Array[@view_line_renderer.LineDecoration]]
  view_zones : Array[ViewZoneViewportData]
} derive(Eq, Debug)

///|
/// Builds viewport data from a precomputed render frame. This path has no
/// coordinate converter, so it carries no decorations; the view-model path
/// below is the one the running viewer uses.
pub fn ViewportData::from_render_frame(
  frame : @view_model.RenderFrame,
  line_height~ : Int,
) -> ViewportData {
  let lines : Array[@view_line_renderer.ViewLineRenderingData] = []
  let line_decorations : Array[Array[@view_line_renderer.LineDecoration]] = []
  let relative_vertical_offset : Array[Int] = []
  for index in 0..<frame.lines.length() {
    let line = frame.lines[index]
    lines.push(@view_model.view_line_rendering_data_from_render_line(line))
    line_decorations.push(@view_model.line_decorations_for_line(line, []))
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
pub fn ViewportData::from_view_model(
  view_model : @view_model.ViewModel,
  window : LineWindow,
  line_height~ : Int,
  decorations? : Array[@decorations.Decoration] = [],
  layout? : ViewLayout,
) -> ViewportData {
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
  let lines : Array[@view_line_renderer.ViewLineRenderingData] = []
  let line_decorations : Array[Array[@view_line_renderer.LineDecoration]] = []
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
  let normalized_window : LineWindow = { start: start_line, end: end_line }
  for line_number in start_line..<end_line {
    let render_line = view_model_lines.render_line(line_number)
    lines.push(
      view_model_lines.view_line_rendering_data(line_number, view_decorations~),
    )
    line_decorations.push(
      @view_model.line_decorations_for_line(render_line, view_decorations),
    )
    relative_vertical_offset.push(
      match layout {
        Some(layout) =>
          layout.relative_vertical_offset_for_line(
            normalized_window,
            line_number,
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

///|
/// Line-rendering data for a one-based line number inside this viewport.
pub fn ViewportData::line_data(
  self : ViewportData,
  line_number : Int,
) -> @view_line_renderer.ViewLineRenderingData? {
  let index = line_number - self.start_line_number
  if index >= 0 && index < self.lines.length() {
    Some(self.lines[index])
  } else {
    None
  }
}

///|
/// Line decorations for a one-based line number inside this viewport.
pub fn ViewportData::decorations_for_line(
  self : ViewportData,
  line_number : Int,
) -> Array[@view_line_renderer.LineDecoration] {
  let index = line_number - self.start_line_number
  match self.line_decorations.get(index) {
    Some(decorations) => decorations
    None => []
  }
}

///|
/// Flattened decorations for every line in this viewport.
pub fn ViewportData::decorations_in_viewport(
  self : ViewportData,
) -> Array[@view_line_renderer.LineDecoration] {
  let out : Array[@view_line_renderer.LineDecoration] = []
  for line in self.line_decorations {
    for decoration in line {
      out.push(decoration)
    }
  }
  out
}
