///|
/// Converts a rendered view-model line to line-renderer data. Decorations are
/// supplied already in view coordinates (`ViewModelDecoration`) and clipped to
/// this view line; no document-offset arithmetic is involved.
pub fn view_line_rendering_data_from_render_line(
  line : RenderLine,
  view_decorations? : Array[ViewModelDecoration] = [],
) -> @view_line_renderer.ViewLineRenderingData {
  {
    min_column: 1,
    max_column: line.text.length() + 1,
    content: line.text,
    continues_with_wrapped_line: false,
    contains_rtl: @base_common.contains_rtl(line.text),
    is_basic_ascii: is_basic_ascii(line.text),
    tokens: line_parts_from_render_line(line),
    inline_decorations: inline_decorations_for_line(line, view_decorations),
    tab_size: 2,
    start_visible_column: 0,
    text_direction: LTR,
    has_variable_fonts: false,
  }
}

///|
/// Builds full line-renderer input from a rendered view-model line, applying
/// the view-coordinate decorations that cover the line.
pub fn render_line_input_from_render_line(
  line : RenderLine,
  view_decorations? : Array[ViewModelDecoration] = [],
  space_width? : Double = 7.2,
  render_whitespace? : @view_line_renderer.RenderWhitespace = None,
  render_control_characters? : Bool = false,
  vertical_scrollbar_size? : Double = 0.0,
) -> @view_line_renderer.RenderLineInput {
  @view_line_renderer.RenderLineInput::from_view_line(
    view_line_rendering_data_from_render_line(line, view_decorations~),
    line_decorations=line_decorations_for_line(line, view_decorations),
    space_width~,
    render_whitespace~,
    render_control_characters~,
    vertical_scrollbar_size~,
  )
}

///|
fn line_parts_from_render_line(
  line : RenderLine,
) -> Array[@view_line_renderer.LinePart] {
  // Monaco's `renderViewLine` token loop: one `LinePart` per token, ending at
  // the token's exclusive offset with its `mtk<colorId>` class. Zero-length
  // tokens (a blank line's placeholder) are dropped so a blank line yields no
  // part, matching Monaco's empty-line handling.
  let parts : Array[@view_line_renderer.LinePart] = []
  let tokens = line.tokens
  let mut start = 0
  for i in 0..<tokens.get_count() {
    let end = tokens.get_end_offset(i)
    if start < end {
      parts.push(
        LinePart(
          end,
          tokens.get_class_name(i),
          contains_rtl=@base_common.contains_rtl(tokens.get_token_text(i)),
        ),
      )
    }
    start = end
  }
  if parts.length() == 0 && line.text.length() > 0 {
    // Defensive fallback: a non-empty line always tokenizes to at least one
    // non-empty token, so this covers only degenerate input. Style it with the
    // default-foreground class (`mtk1`), never a `tok-*`.
    parts.push(
      LinePart(
        line.text.length(),
        TokenMetadata::get_class_name_from_metadata(
          LineTokens::default_token_metadata(),
        ),
      ),
    )
  }
  parts
}

///|
/// Inline decorations (line-local, zero-based half-open columns) covering this
/// view line, clipped from each decoration's view range. Mirrors Monaco's
/// per-line inline-decoration projection; current-line decorations style the
/// line node itself, not its spans, so they are skipped here.
fn inline_decorations_for_line(
  line : RenderLine,
  view_decorations : Array[ViewModelDecoration],
) -> Array[@view_line_renderer.InlineDecoration] {
  // Injected text (inlay hints) contributes its own inline decorations, the
  // Monaco `ViewLineData.inlineDecorations` carried straight on the line.
  let inline : Array[@view_line_renderer.InlineDecoration] = line.injected_inline_decorations.copy()
  let max_column = line.text.length() + 1
  for decoration in view_decorations {
    if decoration.kind == CurrentLine {
      continue
    }
    match decoration.columns_on_view_line(line.line_number, max_column) {
      Some((start_column, end_column)) => {
        let range = @base_common.OffsetRange(start_column - 1, end_column - 1)
        // An empty `class_name` is Monaco's `className: undefined` (Hint+
        // Deprecated): no squiggle span, only the inline class below.
        if decoration.class_name != "" {
          inline.push(InlineDecoration(range, decoration.class_name))
        }
        // Marker decorations carry a second inline class (unnecessary/deprecated
        // styling) over the same columns (markerDecorationsService.ts:275-282).
        match decoration.inline_class_name {
          Some(inline_class_name) =>
            inline.push(InlineDecoration(range, inline_class_name))
          None => ()
        }
      }
      None => ()
    }
  }
  inline
}

///|
/// Line decorations in one-based columns for the line renderer, clipped from
/// each decoration's view range.
pub fn line_decorations_for_line(
  line : RenderLine,
  view_decorations : Array[ViewModelDecoration],
) -> Array[@view_line_renderer.LineDecoration] {
  let line_decorations : Array[@view_line_renderer.LineDecoration] = []
  // Injected-text inline decorations (inlay-hint classes) render through the
  // same renderer merge as model inline decorations; project each onto a
  // one-based `LineDecoration` over the injected run's view columns.
  for injected in line.injected_inline_decorations {
    line_decorations.push(
      LineDecoration(
        injected.range.start + 1,
        injected.range.end_exclusive + 1,
        injected.class_name,
      ),
    )
  }
  let max_column = line.text.length() + 1
  for decoration in view_decorations {
    if decoration.kind == CurrentLine {
      continue
    }
    match decoration.columns_on_view_line(line.line_number, max_column) {
      Some((start_column, end_column)) => {
        // Empty `class_name` = Monaco's `className: undefined`; skip it.
        if decoration.class_name != "" {
          line_decorations.push(
            LineDecoration(start_column, end_column, decoration.class_name),
          )
        }
        match decoration.inline_class_name {
          Some(inline_class_name) =>
            line_decorations.push(
              LineDecoration(start_column, end_column, inline_class_name),
            )
          None => ()
        }
      }
      None => ()
    }
  }
  line_decorations
}

///|
fn is_basic_ascii(text : String) -> Bool {
  for i in 0..<text.length() {
    if text[i].to_int() > 127 {
      return false
    }
  }
  true
}
