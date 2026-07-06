///|
/// Constructs `@view_layout.ViewportData` from view-model state. These live in
/// `view_model` (not `view_layout`) to keep the dependency one-directional:
/// `view_model -> view_layout`. `viewLayout/viewLinesViewportData.ts` in Monaco
/// takes an `IViewModel` in its constructor, which is the file-level
/// `viewLayout <-> viewModel` cycle TypeScript tolerates; MoonBit forbids the
/// cross-package cycle, so the view-model-dependent constructors are inverted
/// here as free functions over the `pub(all)` `ViewportData`.

///|
/// An empty per-line decoration collection for the frame-only path below,
/// which has no coordinate converter and so carries no decorations.
fn empty_view_decorations_collection(
  view_range : @base_common.Range,
) -> ViewDecorationsCollection {
  let inline_decorations : Array[Array[@inline_decorations.InlineDecoration]] = []
  let has_variable_fonts : Array[Bool] = []
  for _j in view_range.start_line_number..<=view_range.end_line_number {
    inline_decorations.push([])
    has_variable_fonts.push(false)
  }
  { decorations: [], inline_decorations, has_variable_fonts }
}

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
    // No decorations on this path (no backing model); injected-text inline
    // decorations still project onto the line.
    let decorations = line_decorations_for_line(
      empty_view_decorations_collection(
        Range(line.line_number, 1, line.line_number, 1),
      ),
      line.line_number,
      line,
    )
    lines.push(
      view_line_rendering_data_from_render_line(
        line,
        line_decorations=decorations,
      ),
    )
    line_decorations.push(decorations)
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
  // The Monaco flow (`viewModelImpl.getViewportViewLineRenderingData`):
  // resolve the decorations for the whole viewport range lazily through
  // `ViewModelDecorations`, then clip per line.
  let end_line_inclusive = end_line - 1
  let viewport_range : @base_common.Range = Range(
    start_line,
    view_model_lines.get_view_line_min_column(start_line),
    end_line_inclusive,
    view_model_lines.get_view_line_max_column(end_line_inclusive),
  )
  let collection = view_model
    .decorations()
    .get_decorations_viewport_data(viewport_range)
  let normalized_window : @view_layout.LineWindow = {
    start: start_line,
    end: end_line,
  }
  for line_number in start_line..<end_line {
    let render_line = view_model_lines.render_line(line_number)
    let decorations = line_decorations_for_line(
      collection, start_line, render_line,
    )
    lines.push(
      view_line_rendering_data_from_render_line(
        render_line,
        line_decorations=decorations,
      ),
    )
    line_decorations.push(decorations)
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
