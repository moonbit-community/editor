///|
/// Readonly editor model identity plus immutable text snapshot, plus the
/// Monaco decoration fields (the one mutable part; the decoration API lives
/// in `text_model_decorations.mbt`).
pub struct TextModel {
  uri : @base_common.Uri
  display_name : String
  language_id : String
  version : Int
  revision : String
  snapshot : TextSnapshot
  // #region Decorations (textModel.ts:285-290; `_onDidChangeDecorations` :225)
  instance_id : String
  mut delta_decoration_call_cnt : Int
  mut last_decoration_id : Int
  decorations : Map[String, IntervalNode]
  decorations_tree : DecorationsTrees
  on_did_change_decorations : DidChangeDecorationsEmitter
  // #endregion
}

///|
pub impl Debug for TextModel with fn to_repr(self) {
  to_repr(
    "<TextModel \{self.uri.to_string()} v\{self.version} decorations: \{self.decorations.length()}>",
  )
}

///|
/// Builds a readonly text model.
///
/// `version` is the editor-model freshness guard: hosts should increment it
/// whenever they install new content for the same URI. `revision` is optional
/// source metadata such as a remote provider revision or content hash.
/// Empty display name and language id are normalized; non-positive versions
/// become version 1.
pub fn TextModel::TextModel(
  uri : @base_common.Uri,
  display_name : String,
  language_id : String,
  version : Int,
  revision : String,
  text : String,
) -> TextModel {
  let display_name = if display_name == "" {
    uri.to_string()
  } else {
    display_name
  }
  let language_id = if language_id == "" { "moonbit" } else { language_id }
  let version = if version < 1 { 1 } else { version }
  let snapshot = TextSnapshot(text)
  {
    uri,
    display_name,
    language_id,
    version,
    revision,
    snapshot,
    instance_id: next_model_instance_id(),
    delta_decoration_call_cnt: 0,
    last_decoration_id: 0,
    decorations: {},
    decorations_tree: DecorationsTrees::new(),
    on_did_change_decorations: DidChangeDecorationsEmitter::new(),
  }
}

///|
/// Returns the immutable snapshot consumed by tokenization, providers, and
/// rendering.
pub fn TextModel::snapshot(self : TextModel) -> TextSnapshot {
  self.snapshot
}

///|
/// Stable current-model identity guard used to drop stale async work.
/// URI and model version decide freshness; source revisions are metadata.
pub fn TextModel::same_identity_and_version(
  self : TextModel,
  other : TextModel,
) -> Bool {
  self.uri.to_string() == other.uri.to_string() && self.version == other.version
}

// #region Reading text — the `textModel.ts` read section (:737-1176, word
// cluster :2085-2124), delegating to the snapshot buffer exactly as Monaco's
// members delegate to `this._buffer`. `_assertNotDisposed` guards are N-A
// (no dispose lifecycle) and the viewer clamps where Monaco throws
// `BugIndicatingError`; see the README parity ledger.

///|
/// Source document language id. Mirrors `getLanguageId` (`textModel.ts:2085`;
/// Monaco delegates to its tokenization part, which the viewer doesn't carry).
pub fn TextModel::get_language_id(self : TextModel) -> String {
  self.language_id
}

///|
/// Whether the text contains any right-to-left character. Mirrors
/// `mightContainRTL` (`textModel.ts:742`).
pub fn TextModel::might_contain_rtl(self : TextModel) -> Bool {
  self.snapshot.might_contain_rtl()
}

///|
/// Clamped document offset of `position`. Mirrors `getOffsetAt`
/// (`textModel.ts:770`): relaxed-validate, then the buffer's line/column
/// arity.
pub fn TextModel::get_offset_at(
  self : TextModel,
  position : @base_common.Position,
) -> Int {
  let position = self.do_validate_position(
    position.line_number,
    position.column,
    false,
  )
  self.snapshot.get_offset_at(position.line_number, position.column)
}

///|
/// Position at the clamped document `offset`. Mirrors `getPositionAt`
/// (`textModel.ts:776`).
pub fn TextModel::get_position_at(
  self : TextModel,
  offset : Int,
) -> @base_common.Position {
  let offset = @base_common.clamp_int(offset, 0, self.snapshot.get_length())
  self.snapshot.get_position_at(offset)
}

///|
/// Full document text, lines joined by `\n`. Mirrors `getValue`
/// (`textModel.ts:799`) at its default LF EOL, no BOM preservation.
pub fn TextModel::get_value(self : TextModel) -> String {
  self.snapshot.get_value()
}

///|
/// Length of `get_value` in UTF-16 code units. Mirrors `getValueLength`
/// (`textModel.ts:819`).
pub fn TextModel::get_value_length(self : TextModel) -> Int {
  self.get_value_length_in_range(self.get_full_model_range())
}

///|
/// Text inside a validated `range`. Mirrors `getValueInRange`
/// (`textModel.ts:831`): validate, then read the buffer.
pub fn TextModel::get_value_in_range(
  self : TextModel,
  range : @base_common.Range,
) -> String {
  self.snapshot.get_value_in_range(self.validate_range(range))
}

///|
/// Length, in UTF-16 code units, of `get_value_in_range`. Mirrors
/// `getValueLengthInRange` (`textModel.ts:836`).
pub fn TextModel::get_value_length_in_range(
  self : TextModel,
  range : @base_common.Range,
) -> Int {
  self.snapshot.get_value_length_in_range(self.validate_range(range))
}

///|
/// Number of logical lines. Mirrors `getLineCount` (`textModel.ts:846`).
pub fn TextModel::get_line_count(self : TextModel) -> Int {
  self.snapshot.line_count()
}

///|
/// Text of the one-based `line_number`, clamped into the document. Mirrors
/// `getLineContent` (`textModel.ts:851`).
pub fn TextModel::get_line_content(
  self : TextModel,
  line_number : Int,
) -> String {
  self.snapshot.get_line_content(line_number)
}

///|
/// Content length of the one-based `line_number`, EOL excluded. Mirrors
/// `getLineLength` (`textModel.ts:860`).
pub fn TextModel::get_line_length(self : TextModel, line_number : Int) -> Int {
  self.snapshot.get_line_length(line_number)
}

///|
/// Every line's content, EOLs excluded. Mirrors `getLinesContent`
/// (`textModel.ts:869`).
pub fn TextModel::get_lines_content(self : TextModel) -> Array[String] {
  let lines : Array[String] = []
  for line in 0..<self.snapshot.line_count() {
    lines.push(self.snapshot.line_text(line))
  }
  lines
}

///|
/// Minimum column of a line, always `1`. Mirrors `getLineMinColumn`
/// (`textModel.ts:892`).
pub fn TextModel::get_line_min_column(
  _self : TextModel,
  _line_number : Int,
) -> Int {
  1
}

///|
/// Max (1-based) column for `line_number`: content length + 1. Mirrors
/// `getLineMaxColumn` (`textModel.ts:897`).
pub fn TextModel::get_line_max_column(
  self : TextModel,
  line_number : Int,
) -> Int {
  self.snapshot.get_line_max_column(line_number)
}

///|
/// 1-based column of the first non-whitespace character on `line_number`, or
/// `0` for whitespace-only lines. Mirrors `getLineFirstNonWhitespaceColumn`
/// (`textModel.ts:905`).
pub fn TextModel::get_line_first_non_whitespace_column(
  self : TextModel,
  line_number : Int,
) -> Int {
  self.snapshot.get_line_first_non_whitespace_column(line_number)
}

///|
/// 1-based column just past the last non-whitespace character on
/// `line_number`, or `0` for whitespace-only lines. Mirrors
/// `getLineLastNonWhitespaceColumn` (`textModel.ts:913`).
pub fn TextModel::get_line_last_non_whitespace_column(
  self : TextModel,
  line_number : Int,
) -> Int {
  self.snapshot.get_line_last_non_whitespace_column(line_number)
}

///|
/// The whole document as a `Range`. Mirrors `getFullModelRange`
/// (`textModel.ts:1168`).
pub fn TextModel::get_full_model_range(self : TextModel) -> @base_common.Range {
  let line_count = self.get_line_count()
  Range(1, 1, line_count, self.get_line_max_column(line_count))
}

///|
/// Core of `validate_position` (Monaco's `_validatePosition`). When `surrogate`
/// is true, a column landing in the middle of a high-low surrogate pair is
/// moved to before the pair. `surrogate=false` is Monaco's `Relaxed` mode (a
/// plain clamp). Inputs are integers, so Monaco's `NaN`/float coercion is moot.
fn TextModel::do_validate_position(
  self : TextModel,
  line_number : Int,
  column : Int,
  surrogate : Bool,
) -> @base_common.Position {
  let snapshot = self.snapshot
  let line_count = snapshot.line_count()
  if line_number < 1 {
    return Position(1, 1)
  }
  if line_number > line_count {
    return Position(line_count, snapshot.get_line_max_column(line_count))
  }
  if column <= 1 {
    return Position(line_number, 1)
  }
  let max_column = snapshot.get_line_max_column(line_number)
  if column >= max_column {
    return Position(line_number, max_column)
  }
  if surrogate {
    // column > 1 here; if it would split a high-low pair, move before it.
    let char_code_before = snapshot.get_line_char_code(line_number, column - 2)
    if @base_common.is_high_surrogate(char_code_before) {
      return Position(line_number, column - 1)
    }
  }
  Position(line_number, column)
}

///|
/// Clamps a position into the document, snapping out of the middle of a
/// surrogate pair. Mirrors `validatePosition` (`textModel.ts:1063`).
pub fn TextModel::validate_position(
  self : TextModel,
  position : @base_common.Position,
) -> @base_common.Position {
  self.do_validate_position(position.line_number, position.column, true)
}

///|
/// Clamps a range into the document without surrogate snapping. Mirrors
/// `_validateRangeRelaxedNoAllocations` (`textModel.ts:925`) — the
/// decoration paths use this cheaper clamp instead of `validateRange`.
pub fn TextModel::validate_range_relaxed(
  self : TextModel,
  range : @base_common.Range,
) -> @base_common.Range {
  let start = self.do_validate_position(
    range.start_line_number,
    range.start_column,
    false,
  )
  let end = self.do_validate_position(
    range.end_line_number,
    range.end_column,
    false,
  )
  Range(start.line_number, start.column, end.line_number, end.column)
}

///|
/// Clamps a range into the document, expanding out of any surrogate pair its
/// ends land inside. Mirrors `validateRange` (`textModel.ts:1110`).
pub fn TextModel::validate_range(
  self : TextModel,
  range : @base_common.Range,
) -> @base_common.Range {
  let snapshot = self.snapshot
  let start = self.do_validate_position(
    range.start_line_number,
    range.start_column,
    false,
  )
  let end = self.do_validate_position(
    range.end_line_number,
    range.end_column,
    false,
  )
  let sl = start.line_number
  let sc = start.column
  let el = end.line_number
  let ec = end.column
  let char_before_start = if sc > 1 {
    snapshot.get_line_char_code(sl, sc - 2)
  } else {
    0
  }
  let char_before_end = if ec > 1 && ec <= snapshot.get_line_length(el) {
    snapshot.get_line_char_code(el, ec - 2)
  } else {
    0
  }
  let start_inside = @base_common.is_high_surrogate(char_before_start)
  let end_inside = @base_common.is_high_surrogate(char_before_end)
  if !start_inside && !end_inside {
    return Range(sl, sc, el, ec)
  }
  if sl == el && sc == ec {
    // do not expand a collapsed range, simply move it to a valid location
    return Range(sl, sc - 1, el, ec - 1)
  }
  if start_inside && end_inside {
    return Range(sl, sc - 1, el, ec + 1)
  }
  if start_inside {
    return Range(sl, sc - 1, el, ec)
  }
  Range(sl, sc, el, ec + 1)
}

///|
/// Position `offset` UTF-16 code units away from `position`, clamped to the
/// document. Mirrors `modifyPosition` (`textModel.ts:1162`): relaxed-validate,
/// then offset round-trip.
pub fn TextModel::modify_position(
  self : TextModel,
  position : @base_common.Position,
  offset : Int,
) -> @base_common.Position {
  let valid = self.do_validate_position(
    position.line_number,
    position.column,
    false,
  )
  let candidate = self.snapshot.get_offset_at(valid.line_number, valid.column) +
    offset
  let clamped = @base_common.clamp_int(candidate, 0, self.snapshot.get_length())
  self.snapshot.get_position_at(clamped)
}

// #endregion
