///|
/// Text inserted into a rendered line without existing in the source document,
/// currently used for inlay hints.
pub(all) struct InjectedText {
  position : @base_common.Position
  text : String
  class_name : String
  source_index : Int
} derive(Eq, Debug)

///|
/// Builds injected text at a model position.
pub fn InjectedText::InjectedText(
  position : @base_common.Position,
  text : String,
  class_name : String,
  source_index? : Int = -1,
) -> InjectedText {
  { position, text, class_name, source_index }
}

///|
/// Converts a language inlay hint to injected renderer text.
pub fn InjectedText::from_inlay_hint(
  hint : @language.InlayHint,
  source_index : Int,
) -> InjectedText {
  InjectedText(
    hint.position,
    padded_inlay_hint_label(hint),
    inlay_hint_class_name(hint),
    source_index~,
  )
}

///|
/// Converts all non-empty inlay hints into injected text while preserving source
/// indices for hover lookup.
pub fn injected_text_from_inlay_hints(
  hints : Array[@language.InlayHint],
) -> Array[InjectedText] {
  let injected : Array[InjectedText] = []
  for index in 0..<hints.length() {
    let text = InjectedText::from_inlay_hint(hints[index], index)
    if text.text.length() > 0 {
      injected.push(text)
    }
  }
  injected
}

///|
fn padded_inlay_hint_label(hint : @language.InlayHint) -> String {
  let builder = StringBuilder()
  if hint.padding_left {
    builder.write_string(" ")
  }
  builder.write_string(hint.label)
  if hint.padding_right {
    builder.write_string(" ")
  }
  builder.to_string()
}

///|
fn inlay_hint_class_name(hint : @language.InlayHint) -> String {
  match hint.kind {
    Some(TypeHint) => "inlay-hint inlay-hint-type"
    Some(ParameterHint) => "inlay-hint inlay-hint-parameter"
    None => "inlay-hint"
  }
}

///|
/// Segment kind inside a projected line: source text or injected text.
pub(all) enum ProjectedLinePartKind {
  SourceSegment(model_start~ : Int, model_end~ : Int)
  InjectedSegment(
    model_column~ : Int,
    injected_text_index~ : Int,
    class_name~ : String
  )
} derive(Eq, Debug)

///|
/// Half-open projected text segment with its source/injected identity.
pub(all) struct ProjectedLinePart {
  start : Int
  end : Int
  kind : ProjectedLinePartKind
} derive(Eq, Debug)

///|
/// One model line after injected text has been projected into display text,
/// with column maps in both directions.
///
/// Deliberate deviation (no `PositionAffinity`): Monaco's
/// `ModelLineProjectionData` maps columns with offset arithmetic and binary
/// search (`translateToOutputPosition` / `translateToInputOffset`), each
/// parameterized by a `PositionAffinity` that disambiguates which side of an
/// injected-text or wrap boundary a position resolves to. This type instead
/// precomputes per-column lookup tables (`model_to_projected_columns`,
/// `model_columns`) for O(1) `.get()` and models **no** affinity: the boundary
/// side is fixed by the table. That disambiguation only matters for caret
/// placement and cursor movement, which the readonly viewer omits (no caret,
/// no keyboard navigation), so affinity has no role here. Same result as Monaco
/// for the tested cases (`view_model_test.mbt`); reduced scope by design.
pub(all) struct ProjectedTextLine {
  text : String
  model_line_length : Int
  model_columns : Array[Int]
  injected_text_indices : Array[Int]
  model_to_projected_columns : Array[Int]
  parts : Array[ProjectedLinePart]
} derive(Eq, Debug)

///|
/// Projection for a line with no injected text.
pub fn ProjectedTextLine::identity(line_text : String) -> ProjectedTextLine {
  ProjectedTextLine::from_injected_text(line_text, [])
}

///|
/// Builds projected text and column maps for one model line plus injected text.
pub fn ProjectedTextLine::from_injected_text(
  line_text : String,
  injected_text : Array[InjectedText],
) -> ProjectedTextLine {
  let normalized = normalize_injected_text(line_text, injected_text)
  if normalized.length() == 0 {
    return identity_projected_text_line(line_text)
  }
  let builder = StringBuilder()
  let model_columns : Array[Int] = [0]
  let injected_text_indices : Array[Int] = []
  let model_to_projected_columns = initial_model_to_projected_columns(
    line_text.length(),
  )
  let parts : Array[ProjectedLinePart] = []
  let mut source_cursor = 0
  let mut view_cursor = 0
  for item in normalized {
    let column = @base_common.clamp_int(
      item.position.column,
      0,
      line_text.length(),
    )
    if column > source_cursor {
      append_source_text(
        builder, line_text, source_cursor, column, model_columns, injected_text_indices,
        model_to_projected_columns, parts, view_cursor,
      )
      view_cursor += column - source_cursor
      source_cursor = column
    }
    append_injected_text(
      builder, item, column, model_columns, injected_text_indices, parts, view_cursor,
    )
    view_cursor += item.text.length()
  }
  if source_cursor < line_text.length() {
    append_source_text(
      builder,
      line_text,
      source_cursor,
      line_text.length(),
      model_columns,
      injected_text_indices,
      model_to_projected_columns,
      parts,
      view_cursor,
    )
    view_cursor += line_text.length() - source_cursor
  }
  fill_unmapped_model_columns(model_to_projected_columns, view_cursor)
  {
    text: builder.to_string(),
    model_line_length: line_text.length(),
    model_columns,
    injected_text_indices,
    model_to_projected_columns,
    parts,
  }
}

///|
/// Maps a model column to a projected display column.
pub fn ProjectedTextLine::model_column_to_projected_column(
  self : ProjectedTextLine,
  model_column : Int,
) -> Int {
  let column = @base_common.clamp_int(model_column, 0, self.model_line_length)
  match self.model_to_projected_columns.get(column) {
    Some(projected_column) => projected_column
    None => self.text.length()
  }
}

///|
/// Maps a projected display column back to a model column.
pub fn ProjectedTextLine::projected_column_to_model_column(
  self : ProjectedTextLine,
  projected_column : Int,
) -> Int {
  let column = @base_common.clamp_int(projected_column, 0, self.text.length())
  match self.model_columns.get(column) {
    Some(model_column) => model_column
    None => self.model_line_length
  }
}

///|
/// Returns the inlay-hint source index at a projected display column, or `-1`
/// for source text.
pub fn ProjectedTextLine::injected_text_index_at_projected_column(
  self : ProjectedTextLine,
  projected_column : Int,
) -> Int {
  let column = @base_common.clamp_int(projected_column, 0, self.text.length())
  match self.injected_text_indices.get(column) {
    Some(index) => index
    None => -1
  }
}

///|
fn identity_projected_text_line(line_text : String) -> ProjectedTextLine {
  let model_columns : Array[Int] = []
  let injected_text_indices : Array[Int] = []
  let model_to_projected_columns : Array[Int] = []
  for column in 0..<=line_text.length() {
    model_columns.push(column)
    model_to_projected_columns.push(column)
    if column < line_text.length() {
      injected_text_indices.push(-1)
    }
  }
  let parts : Array[ProjectedLinePart] = []
  if line_text.length() > 0 {
    parts.push({
      start: 0,
      end: line_text.length(),
      kind: SourceSegment(model_start=0, model_end=line_text.length()),
    })
  }
  {
    text: line_text,
    model_line_length: line_text.length(),
    model_columns,
    injected_text_indices,
    model_to_projected_columns,
    parts,
  }
}

///|
fn normalize_injected_text(
  line_text : String,
  injected_text : Array[InjectedText],
) -> Array[InjectedText] {
  let normalized : Array[InjectedText] = []
  for item in injected_text {
    if item.text.length() > 0 {
      let column = @base_common.clamp_int(
        item.position.column,
        0,
        line_text.length(),
      )
      normalized.push({ ..item, position: { ..item.position, column, } })
    }
  }
  normalized.sort_by((left, right) => {
    if left.position.column != right.position.column {
      left.position.column - right.position.column
    } else {
      left.source_index - right.source_index
    }
  })
  normalized
}

///|
fn initial_model_to_projected_columns(line_length : Int) -> Array[Int] {
  let columns : Array[Int] = []
  for _ in 0..<=line_length {
    columns.push(-1)
  }
  columns[0] = 0
  columns
}

///|
fn append_source_text(
  builder : StringBuilder,
  line_text : String,
  start_column : Int,
  end_column : Int,
  model_columns : Array[Int],
  injected_text_indices : Array[Int],
  model_to_projected_columns : Array[Int],
  parts : Array[ProjectedLinePart],
  view_cursor : Int,
) -> Unit {
  builder.write_string(line_text[start_column:end_column].to_owned())
  let mut view = view_cursor
  for column in start_column..<end_column {
    injected_text_indices.push(-1)
    view += 1
    model_columns.push(column + 1)
    if model_to_projected_columns[column + 1] < 0 {
      model_to_projected_columns[column + 1] = view
    }
  }
  parts.push({
    start: view_cursor,
    end: view,
    kind: SourceSegment(model_start=start_column, model_end=end_column),
  })
}

///|
fn append_injected_text(
  builder : StringBuilder,
  item : InjectedText,
  model_column : Int,
  model_columns : Array[Int],
  injected_text_indices : Array[Int],
  parts : Array[ProjectedLinePart],
  view_cursor : Int,
) -> Unit {
  builder.write_string(item.text)
  let mut view = view_cursor
  for _ in 0..<item.text.length() {
    injected_text_indices.push(item.source_index)
    view += 1
    model_columns.push(model_column)
  }
  parts.push({
    start: view_cursor,
    end: view,
    kind: InjectedSegment(
      model_column~,
      injected_text_index=item.source_index,
      class_name=item.class_name,
    ),
  })
}

///|
fn fill_unmapped_model_columns(
  model_to_projected_columns : Array[Int],
  fallback : Int,
) -> Unit {
  let mut last = fallback
  for index in 0..<model_to_projected_columns.length() {
    if model_to_projected_columns[index] >= 0 {
      last = model_to_projected_columns[index]
    } else {
      model_to_projected_columns[index] = last
    }
  }
}
