///|
/// Per-model-line projection, Monaco's `IModelLineProjection`
/// (`modelLineProjection.ts:16`) with the package's enum dispatch standing in
/// for interface polymorphism. `Identity` is Monaco's
/// `IdentityModelLineProjection.INSTANCE`: a visible line with no wrapping
/// and no injected text that delegates straight to the model, so the common
/// no-wrap document allocates no per-line projection data at all. `Hidden` is
/// Monaco's `HiddenModelLineProjection.INSTANCE`: a line hidden by
/// `setHiddenAreas` (folding), producing zero view lines. `Projected` is
/// Monaco's `ModelLineProjection` class, used to wrap model lines and inject
/// text; it carries its own visibility like Monaco's `_isVisible`.
///
/// Content queries on an invisible projection abort — the `Hidden` arms are
/// the port of both `HiddenModelLineProjection`'s `throw new Error('Not
/// supported')` and `ModelLineProjection._assertVisible` (an invisible
/// `Projected` is not asserted per method; only valid view lines reach these
/// accessors).
pub(all) enum ModelLineProjection {
  Identity
  Hidden
  Projected(ModelLineProjectionData, is_visible~ : Bool)
}

///|
/// `createModelLineProjection` (`modelLineProjection.ts:52`): `None`
/// line-break data means no mapping is needed.
pub fn create_model_line_projection(
  data : ModelLineProjectionData?,
  is_visible : Bool,
) -> ModelLineProjection {
  match data {
    None => if is_visible { Identity } else { Hidden }
    Some(data) => Projected(data, is_visible~)
  }
}

///|
/// Whether this model line is visible — `isVisible`.
pub fn ModelLineProjection::is_visible(self : ModelLineProjection) -> Bool {
  match self {
    Identity => true
    Hidden => false
    Projected(_, is_visible~) => is_visible
  }
}

///|
/// Returns this projection with the given visibility — `setVisible`
/// (`modelLineProjection.ts:22`, "this invalidates the current instance"):
/// callers store the returned projection back, exactly Monaco's
/// `projections[i] = projections[i].setVisible(v)` pattern. The identity
/// singletons swap between `Identity` and `Hidden`.
pub fn ModelLineProjection::set_visible(
  self : ModelLineProjection,
  is_visible : Bool,
) -> ModelLineProjection {
  match self {
    Identity | Hidden => if is_visible { Identity } else { Hidden }
    Projected(data, ..) => Projected(data, is_visible~)
  }
}

///|
/// Number of view lines this model line produces — `getViewLineCount`:
/// zero while hidden.
pub fn ModelLineProjection::get_view_line_count(
  self : ModelLineProjection,
) -> Int {
  match self {
    Identity => 1
    Hidden => 0
    Projected(data, is_visible~) =>
      if is_visible {
        data.view_line_count()
      } else {
        0
      }
  }
}

///|
/// Text of one view line — `getViewLineContent`: the projected segment's
/// slice with the continuation indent prepended (`spaces(...) + r`), or the
/// model line as-is.
pub fn ModelLineProjection::get_view_line_content(
  self : ModelLineProjection,
  model : @model.TextModel,
  model_line_number : Int,
  output_line_index : Int,
) -> String {
  match self {
    Identity => model.snapshot.line_text(model_line_number - 1)
    Hidden => abort("Not supported")
    Projected(data, ..) => {
      let segment = data.segment_at_view_line_index(output_line_index)
      let content = data.projected_line.text[segment.start_offset:segment.end_offset].to_owned()
      if segment.wrapped_text_indent_length > 0 {
        spaces(segment.wrapped_text_indent_length) + content
      } else {
        content
      }
    }
  }
}

///|
/// Minimum one-based column of one view line — `getViewLineMinColumn`
/// (`modelLineProjection.ts:141-144`): `getMinOutputOffset + 1`, i.e. the
/// continuation indent width plus one (view columns are segment-local; the
/// segment's `start_column` is a projected-line column, a different axis).
pub fn ModelLineProjection::get_view_line_min_column(
  self : ModelLineProjection,
  output_line_index : Int,
) -> Int {
  match self {
    Identity => 1
    Hidden => abort("Not supported")
    Projected(data, ..) =>
      data.segment_at_view_line_index(output_line_index).wrapped_text_indent_length +
      1
  }
}

///|
/// Maximum one-based column of one view line — `getViewLineMaxColumn`.
pub fn ModelLineProjection::get_view_line_max_column(
  self : ModelLineProjection,
  model : @model.TextModel,
  model_line_number : Int,
  output_line_index : Int,
) -> Int {
  match self {
    Identity => model.snapshot.line_text(model_line_number - 1).length() + 1
    Hidden => abort("Not supported")
    Projected(data, ..) => {
      // `getMaxOutputOffset + 1` (`modelLineProjectionData.ts:73-79`): the
      // segment's rendered length (indent included) plus one — segment-local,
      // like `get_view_line_min_column`.
      let segment = data.segment_at_view_line_index(output_line_index)
      segment.end_offset -
      segment.start_offset +
      segment.wrapped_text_indent_length +
      1
    }
  }
}

///|
/// The view-line data of one view line — `getViewLineData`. The identity arm
/// is Monaco's `IdentityModelLineProjection.getViewLineData`
/// (`modelLineProjection.ts:298`): the model line whole, tokens inflated, no
/// injected inline decorations.
pub fn ModelLineProjection::get_view_line_data(
  self : ModelLineProjection,
  model : @model.TextModel,
  model_line_number : Int,
  output_line_index : Int,
) -> ViewLineData {
  match self {
    Identity => {
      let content = model.snapshot.line_text(model_line_number - 1)
      {
        content,
        continues_with_wrapped_line: false,
        min_column: 1,
        max_column: content.length() + 1,
        start_visible_column: 0,
        tokens: model.tokenization.get_line_tokens(model_line_number).inflate(),
        inline_decorations: [],
      }
    }
    Hidden => abort("Not supported")
    Projected(data, ..) =>
      view_line_data_for_segment(
        model.tokenization.get_line_tokens(model_line_number),
        data.projected_line,
        data.segment_at_view_line_index(output_line_index),
      )
  }
}

///|
/// Batch form of `get_view_line_data` (`modelLineProjection.ts:160-184,
/// 312-320`). A projected model line performs at most one passive token-store
/// read, and performs none when every requested output is unneeded.
fn ModelLineProjection::get_view_lines_data(
  self : ModelLineProjection,
  model : @model.TextModel,
  model_line_number : Int,
  output_line_index : Int,
  line_count : Int,
  global_start_index : Int,
  needed : Array[Bool],
  result : Array[ViewLineData?],
) -> Bool {
  match self {
    Identity => {
      if !needed[global_start_index] {
        result[global_start_index] = None
        return false
      }
      result[global_start_index] = Some(
        self.get_view_line_data(model, model_line_number, 0),
      )
      true
    }
    Hidden => abort("Not supported")
    Projected(data, is_visible~) => {
      if !is_visible {
        abort("Not supported")
      }
      let mut any_needed = false
      for local_index in 0..<line_count {
        if needed[global_start_index + local_index] {
          any_needed = true
          break
        }
      }
      if !any_needed {
        for local_index in 0..<line_count {
          result[global_start_index + local_index] = None
        }
        return false
      }
      let base_tokens = model.tokenization.get_line_tokens(model_line_number)
      let with_injections = base_tokens.with_inserted(
        injected_tokens_for_projected_line(data.projected_line),
      )
      for local_index in 0..<line_count {
        let global_index = global_start_index + local_index
        if !needed[global_index] {
          result[global_index] = None
          continue
        }
        result[global_index] = Some(
          view_line_data_for_segment_with_injections(
            with_injections,
            data.projected_line,
            data.segment_at_view_line_index(output_line_index + local_index),
          ),
        )
      }
      true
    }
  }
}

///|
/// Model column for a view position on one view line —
/// `getModelColumnOfViewPosition` (`translateToInputOffset`, which undoes the
/// continuation indent and clamps into the segment).
pub fn ModelLineProjection::get_model_column_of_view_position(
  self : ModelLineProjection,
  output_line_index : Int,
  output_column : Int,
) -> Int {
  match self {
    Identity => output_column
    Hidden => abort("Not supported")
    Projected(data, ..) => {
      let segment = data.segment_at_view_line_index(output_line_index)
      let width = segment.end_offset - segment.start_offset
      let projected_column = segment.start_offset +
        @base_common.clamp_int(
          output_column - 1 - segment.wrapped_text_indent_length,
          0,
          width,
        )
      data.projected_line.projected_column_to_model_column(projected_column) + 1
    }
  }
}

///|
/// View position of a model column — `getViewPositionOfModelPosition`
/// (`translateToOutputPosition(inputColumn - 1, affinity).toPosition(delta)`).
/// `delta_line_number` is the model line's first view line, so a continuation
/// segment adds its index; the view column regains the continuation indent
/// (Monaco's `getOutputPositionOfInputOffset`).
pub fn ModelLineProjection::get_view_position_of_model_position(
  self : ModelLineProjection,
  delta_line_number : Int,
  input_column : Int,
  affinity? : @model.PositionAffinity,
) -> @base_common.Position {
  match self {
    Identity => {
      ignore(affinity)
      Position(delta_line_number, input_column)
    }
    Hidden => abort("Not supported")
    Projected(data, ..) => {
      let model_column = @base_common.clamp_int(
        input_column - 1,
        0,
        data.line_length,
      )
      let projected_column = data.projected_line.model_column_to_projected_column(
        model_column,
        affinity?,
      )
      let segment_index = data.view_line_index_for_projected_column(
        projected_column,
        affinity?,
      )
      let segment = data.segment_at_view_line_index(segment_index)
      Position(
        delta_line_number + segment_index,
        projected_column -
        segment.start_offset +
        1 +
        segment.wrapped_text_indent_length,
      )
    }
  }
}

///|
/// Snaps a view position at an injected-text or wrap boundary to the side the
/// affinity asks for — `normalizePosition` (`modelLineProjection.ts:237-241`)
/// over `normalizeOutputPosition` (`modelLineProjectionData.ts:169-192`).
pub fn ModelLineProjection::normalize_position(
  self : ModelLineProjection,
  output_line_index : Int,
  position : @base_common.Position,
  affinity : @model.PositionAffinity,
) -> @base_common.Position {
  match self {
    Identity => position
    Hidden => abort("Not supported")
    Projected(data, ..) => {
      let segment = data.segment_at_view_line_index(output_line_index)
      let width = segment.end_offset - segment.start_offset
      // `outputPositionToOffsetInInputWithInjections`: undo the continuation
      // indent and clamp into the segment.
      let output_offset = @base_common.clamp_int(
        position.column - 1 - segment.wrapped_text_indent_length,
        0,
        width,
      )
      let projected = segment.start_offset + output_offset
      let normalized = data.projected_line.normalize_projected_column_around_injections(
        projected, affinity,
      )
      if normalized != projected {
        // Injected text caused a change: re-derive the view position with the
        // same affinity, relative to this model line's first view line.
        let base_view_line_number = position.line_number - output_line_index
        let segment_index = data.view_line_index_for_projected_column(
          normalized,
          affinity~,
        )
        let target = data.segment_at_view_line_index(segment_index)
        return Position(
          base_view_line_number + segment_index,
          normalized -
          target.start_offset +
          1 +
          target.wrapped_text_indent_length,
        )
      }
      // Wrap-boundary snap: `Left` at the line's min output offset moves to
      // the previous view line's max; `Right` at max moves to the next line's
      // min.
      match affinity {
        Left =>
          if output_line_index > 0 && output_offset == 0 {
            let previous = data.segment_at_view_line_index(
              output_line_index - 1,
            )
            Position(
              position.line_number - 1,
              previous.end_offset -
              previous.start_offset +
              1 +
              previous.wrapped_text_indent_length,
            )
          } else {
            position
          }
        Right =>
          if output_line_index + 1 < data.view_line_count() &&
            output_offset == width {
            Position(
              position.line_number + 1,
              1 +
              data.segment_at_view_line_index(output_line_index + 1).wrapped_text_indent_length,
            )
          } else {
            position
          }
        _ => position
      }
    }
  }
}

///|
/// The injected-text (inlay hint) source index at a 0-based view column of
/// one view line, or `-1` for source text (including the synthetic
/// continuation indent) — the index-valued form of Monaco's
/// `getInjectedTextAt`.
pub fn ModelLineProjection::injected_text_index_at(
  self : ModelLineProjection,
  output_line_index : Int,
  column : Int,
) -> Int {
  match self {
    Identity => -1
    Hidden => abort("Not supported")
    Projected(data, ..) => {
      let segment = data.segment_at_view_line_index(output_line_index)
      let indent = segment.wrapped_text_indent_length
      if column < indent {
        return -1
      }
      let offset = segment.start_offset + (column - indent)
      if offset >= segment.end_offset {
        return -1
      }
      data.projected_line.injected_text_index_at_projected_column(offset)
    }
  }
}

///|
/// Builds one view line the Monaco `_getViewLineData` way: splice the injected
/// text into the model line's tokens with `with_inserted`
/// (`getLineTokensWithInjections`), then slice the output line's segment with
/// `slice_and_inflate`. Injected-text classes become inline decorations
/// (`InjectedTextInlineDecorationsComputer`), never token colors — the
/// spliced injected tokens carry only default syntactic metadata.
/// Continuation lines render `wrapped_text_indent_length` leading spaces and
/// shift their token offsets by the same amount (`spaces(...) + lineContent`
/// and `sliceAndInflate(..., deltaStartIndex)`).
fn view_line_data_for_segment(
  base_tokens : @tokens.LineTokens,
  projected_line : ProjectedTextLine,
  segment : ModelLineProjectionSegment,
) -> ViewLineData {
  let with_injections = base_tokens.with_inserted(
    injected_tokens_for_projected_line(projected_line),
  )
  view_line_data_for_segment_with_injections(
    with_injections, projected_line, segment,
  )
}

///|
/// Builds one segment after the batch caller has shared the model line's
/// passive token read and injection splice.
fn view_line_data_for_segment_with_injections(
  with_injections : @tokens.LineTokens,
  projected_line : ProjectedTextLine,
  segment : ModelLineProjectionSegment,
) -> ViewLineData {
  let indent = segment.wrapped_text_indent_length
  let start_offset = segment.start_offset
  let end_offset = segment.end_offset
  let content = projected_line.text[start_offset:end_offset].to_owned()
  let content = if indent > 0 { spaces(indent) + content } else { content }
  {
    content,
    continues_with_wrapped_line: segment.continues_with_wrapped_line,
    // Segment-local view columns (`getViewLineMinColumn`/`MaxColumn`): the
    // indent-prefixed rendered content's bounds.
    min_column: segment.wrapped_text_indent_length + 1,
    max_column: content.length() + 1,
    // The renderer's whitespace math counts code units in Int columns;
    // Monaco feeds the raw (possibly fractional) number into the same
    // formulas. Truncation only diverges when `columnsForFullWidthChar` is
    // fractional, and only for whitespace glyph tab stops.
    start_visible_column: segment.start_visible_column.to_int(),
    tokens: with_injections.slice_and_inflate(start_offset, end_offset, indent),
    inline_decorations: projected_injected_inline_decorations(
      projected_line, start_offset, end_offset, indent,
    ),
  }
}

///|
/// A run of `n` spaces — the leading indent prepended to a wrapped continuation
/// line. Monaco's `spaces(count)`.
fn spaces(n : Int) -> String {
  let sb = StringBuilder::new()
  for _ in 0..<n {
    sb.write_char(' ')
  }
  sb.to_string()
}

///|
/// The injected text of a projected line as `with_inserted` splice tokens —
/// Monaco's `getLineTokensWithInjections`. Each run inserts at its 0-based model
/// column with default token metadata (no per-token color); the inlay color is
/// applied as an inline decoration instead. Offsets are ascending, satisfying
/// `with_inserted`'s precondition.
fn injected_tokens_for_projected_line(
  projected_line : ProjectedTextLine,
) -> Array[@tokens.InsertedToken] {
  let inserts : Array[@tokens.InsertedToken] = []
  for part in projected_line.parts {
    match part.kind {
      InjectedSegment(model_column~, ..) =>
        inserts.push(
          @tokens.InsertedToken::new(
            model_column,
            projected_line.text[part.start:part.end].to_owned(),
            @tokens.LineTokens::default_token_metadata(),
          ),
        )
      SourceSegment(_) => ()
    }
  }
  inserts
}

///|
/// Inline decorations for the injected text of a projected line, clipped to the
/// output (view-local) segment `[start_offset, end_offset)` — Monaco's
/// `InjectedTextInlineDecorationsComputer.getInlineDecorations`. Each injected
/// run with a class emits one decoration over its projected columns.
fn projected_injected_inline_decorations(
  projected_line : ProjectedTextLine,
  start_offset : Int,
  end_offset : Int,
  indent : Int,
) -> Array[@view_layout.InlineDecoration] {
  let decorations : Array[@view_layout.InlineDecoration] = []
  for part in projected_line.parts {
    match part.kind {
      InjectedSegment(class_name~, ..) => {
        let start = part.start.max(start_offset)
        let end = part.end.min(end_offset)
        if start < end {
          // View-local columns shift right by the continuation indent.
          decorations.push(
            InlineDecoration(
              OffsetRange(
                start - start_offset + indent,
                end - start_offset + indent,
              ),
              class_name,
            ),
          )
        }
      }
      SourceSegment(_) => ()
    }
  }
  decorations
}
