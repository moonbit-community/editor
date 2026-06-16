///|
pub(all) struct ViewportData {
  start_line_number : Int
  end_line_number : Int
  relative_vertical_offset : Array[Int]
  line_height : Int
  visible_range : @view_line_renderer.ViewRange
  big_numbers_delta : Int
  lines : Array[@view_line_renderer.ViewLineRenderingData]
  line_decorations : Array[Array[@view_line_renderer.LineDecoration]]
} derive(Eq, Debug)

///|
pub fn ViewportData::from_render_frame(
  frame : @view_model.RenderFrame,
  line_height~ : Int,
  decorations? : Array[@decorations.Decoration] = [],
) -> ViewportData {
  let lines : Array[@view_line_renderer.ViewLineRenderingData] = []
  let line_decorations : Array[Array[@view_line_renderer.LineDecoration]] = []
  let relative_vertical_offset : Array[Int] = []
  for index in 0..<frame.lines.length() {
    let line = frame.lines[index]
    lines.push(
      @view_model.view_line_rendering_data_from_render_line(line, decorations~),
    )
    line_decorations.push(
      @view_model.line_decorations_for_line(line, decorations),
    )
    relative_vertical_offset.push(index * line_height)
  }
  let start_line_number = frame.viewport.start_line + 1
  let end_line_number = frame.viewport.end_line
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
  }
}

///|
pub fn ViewportData::from_view_model(
  view_model : @view_model.ViewModel,
  window : LineWindow,
  line_height~ : Int,
  decorations? : Array[@decorations.Decoration] = [],
) -> ViewportData {
  let start_line = @core.clamp_int(window.start, 0, view_model.line_count() - 1)
  let end_line = @core.clamp_int(
    window.end,
    start_line + 1,
    view_model.line_count(),
  )
  let lines : Array[@view_line_renderer.ViewLineRenderingData] = []
  let line_decorations : Array[Array[@view_line_renderer.LineDecoration]] = []
  let relative_vertical_offset : Array[Int] = []
  let view_model_lines = view_model.lines()
  for index in start_line..<end_line {
    let render_line = view_model_lines.render_line(index + 1)
    lines.push(
      @view_model.view_line_rendering_data_from_render_line(
        render_line,
        decorations~,
      ),
    )
    line_decorations.push(
      @view_model.line_decorations_for_line(render_line, decorations),
    )
    relative_vertical_offset.push((index - start_line) * line_height)
  }
  let start_line_number = start_line + 1
  let end_line_number = end_line
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
  }
}

///|
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
