///|
/// Converts a rendered view-model line to line-renderer data. Decorations
/// arrive as per-line `@view_layout.LineDecoration`s already produced by the
/// faithful chain (`ViewModelDecoration` → per-line `InlineDecoration` →
/// `LineDecoration`, see `line_decorations_for_line`).
pub fn view_line_rendering_data_from_render_line(
  line : RenderLine,
  line_decorations? : Array[@view_layout.LineDecoration] = [],
) -> @view_layout.ViewLineRenderingData {
  {
    min_column: 1,
    max_column: line.text.length() + 1,
    content: line.text,
    continues_with_wrapped_line: false,
    contains_rtl: @base_common.contains_rtl(line.text),
    is_basic_ascii: is_basic_ascii(line.text),
    tokens: line_parts_from_render_line(line),
    // The offset-based mirror of the line decorations (write-only for the
    // renderer; participates in the render-input equality diff).
    inline_decorations: line_decorations.map(decoration => {
      InlineDecoration(
        OffsetRange(decoration.start_column - 1, decoration.end_column - 1),
        decoration.class_name,
        decoration_type=decoration.decoration_type,
      )
    }),
    tab_size: 2,
    start_visible_column: 0,
    text_direction: LTR,
    has_variable_fonts: false,
  }
}

///|
/// Builds full line-renderer input from a rendered view-model line and its
/// per-line decorations. The line's own injected-text (inlay hint) inline
/// decorations are always merged in — callers pass only the model-decoration
/// spans (the viewport path in `line_decorations_for_line` produces both).
pub fn render_line_input_from_render_line(
  line : RenderLine,
  line_decorations? : Array[@view_layout.LineDecoration] = [],
  space_width? : Double = 7.2,
  render_whitespace? : @view_layout.RenderWhitespace = None,
  render_control_characters? : Bool = false,
  vertical_scrollbar_size? : Double = 0.0,
) -> @view_layout.RenderLineInput {
  let merged = line_decorations.copy()
  for injected in line.injected_inline_decorations {
    merged.push(
      LineDecoration(
        injected.range.start + 1,
        injected.range.end_exclusive + 1,
        injected.class_name,
      ),
    )
  }
  @view_layout.RenderLineInput::from_view_line(
    view_line_rendering_data_from_render_line(line, line_decorations=merged),
    line_decorations=merged,
    space_width~,
    render_whitespace~,
    render_control_characters~,
    vertical_scrollbar_size~,
  )
}

///|
fn line_parts_from_render_line(
  line : RenderLine,
) -> Array[@view_layout.LinePart] {
  // Monaco's `renderViewLine` token loop: one `LinePart` per token, ending at
  // the token's exclusive offset with its `mtk<colorId>` class. Zero-length
  // tokens (a blank line's placeholder) are dropped so a blank line yields no
  // part, matching Monaco's empty-line handling.
  let parts : Array[@view_layout.LinePart] = []
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
/// `LineDecoration.filter` (`viewLayout/lineDecorations.ts:63-90`): the
/// faithful per-line clip of view-range inline decorations into one-based
/// column `LineDecoration`s. Empty-range Regular decorations are dropped.
pub fn line_decorations_filter(
  line_decorations : Array[@inline_decorations.InlineDecoration],
  line_number : Int,
  min_line_column : Int,
  max_line_column : Int,
) -> Array[@view_layout.LineDecoration] {
  if line_decorations.length() == 0 {
    return []
  }
  let result : Array[@view_layout.LineDecoration] = []
  for d in line_decorations {
    let range = d.range
    if range.end_line_number < line_number ||
      range.start_line_number > line_number {
      // Ignore decorations that sit outside this line
      continue
    }
    if range.is_empty() &&
      (d.type_ is Regular || d.type_ is RegularAffectingLetterSpacing) {
      // Ignore empty range decorations
      continue
    }
    let start_column = if range.start_line_number == line_number {
      range.start_column
    } else {
      min_line_column
    }
    let end_column = if range.end_line_number == line_number {
      range.end_column
    } else {
      max_line_column
    }
    result.push(
      LineDecoration(
        start_column,
        end_column,
        d.inline_class_name,
        decoration_type=to_view_layout_decoration_type(d.type_),
      ),
    )
  }
  result
}

///|
fn to_view_layout_decoration_type(
  type_ : @inline_decorations.InlineDecorationType,
) -> @view_layout.InlineDecorationType {
  match type_ {
    Regular => Regular
    Before => Before
    After => After
    RegularAffectingLetterSpacing => RegularAffectingLetterSpacing
  }
}

///|
/// Per-line decorations for `line_number` from the viewport decorations
/// collection: the faithful inline chain (`line_decorations_filter` over the
/// per-line grouped inline decorations), the injected-text (inlay hint)
/// decorations the line carries, and — TRANSITIONAL until the
/// `DecorationsOverlay` lands (decoration plan Phase 4) — one span per
/// `className` decoration covering the line, so squiggles and background
/// highlights keep rendering as line-internal spans meanwhile.
pub fn line_decorations_for_line(
  collection : ViewDecorationsCollection,
  viewport_start_line_number : Int,
  line : RenderLine,
) -> Array[@view_layout.LineDecoration] {
  let line_number = line.line_number
  let max_column = line.text.length() + 1
  let index = line_number - viewport_start_line_number
  let result = match collection.inline_decorations.get(index) {
    Some(inline_decorations) =>
      line_decorations_filter(inline_decorations, line_number, 1, max_column)
    None => []
  }
  // Injected-text inline decorations (inlay-hint classes) render through the
  // same renderer merge as model inline decorations; project each onto a
  // one-based `LineDecoration` over the injected run's view columns.
  for injected in line.injected_inline_decorations {
    result.push(
      LineDecoration(
        injected.range.start + 1,
        injected.range.end_exclusive + 1,
        injected.class_name,
      ),
    )
  }
  // TRANSITIONAL (Phase 4 deletes this in favor of the DecorationsOverlay):
  // `className` decorations render as spans, with Monaco's `showIfCollapsed`
  // 1ch widening for collapsed ranges (the squiggle on an empty range/EOL).
  for decoration in collection.decorations {
    if decoration.options.class_name == "" {
      // Monaco `className: undefined` (e.g. Hint+Deprecated): no span.
      continue
    }
    match
      class_name_columns_on_view_line(
        decoration.range,
        decoration.options.show_if_collapsed,
        line_number,
        max_column,
      ) {
      Some((start_column, end_column)) =>
        result.push(
          LineDecoration(
            start_column,
            end_column,
            decoration.options.class_name,
          ),
        )
      None => ()
    }
  }
  result
}

///|
/// Clips a `className` decoration's view range to one view line, returning
/// the one-based half-open `[start_column, end_column)` span local to that
/// line, or `None` when the decoration does not cover the line or collapses
/// to empty. `show_if_collapsed` forces a collapsed span to render one
/// column wide (`markerDecorationsService.ts` sets `showIfCollapsed: true`).
/// TRANSITIONAL with its caller above.
fn class_name_columns_on_view_line(
  range : @base_common.Range,
  show_if_collapsed : Bool,
  view_line_number : Int,
  max_column : Int,
) -> (Int, Int)? {
  if view_line_number < range.start_line_number ||
    view_line_number > range.end_line_number {
    return None
  }
  let start_column = if range.start_line_number == view_line_number {
    range.start_column
  } else {
    1
  }
  let end_column = if range.end_line_number == view_line_number {
    range.end_column
  } else {
    max_column
  }
  let start_column = @base_common.clamp_int(start_column, 1, max_column)
  let end_column = @base_common.clamp_int(end_column, 1, max_column)
  if start_column >= end_column {
    if show_if_collapsed {
      Some((start_column, start_column + 1))
    } else {
      None
    }
  } else {
    Some((start_column, end_column))
  }
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
