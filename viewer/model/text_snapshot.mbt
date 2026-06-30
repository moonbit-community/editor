///|
/// Immutable text plus cached line starts. Offsets and columns are UTF-16
/// code units so browser, Monaco, and LSP-facing code share one convention.
pub(all) struct TextSnapshot {
  text : String
  language_id : String
  version : Int
  line_starts : Array[Int]
} derive(Debug)

///|
/// Builds a snapshot and derives the line-start table used by all position
/// conversion helpers.
pub fn TextSnapshot::TextSnapshot(
  text : String,
  language_id? : String = "moonbit",
  version? : Int = 1,
) -> TextSnapshot {
  let line_starts = build_line_starts(text)
  { text, language_id, version, line_starts }
}

///|
/// Snapshot length in the repo's JavaScript-compatible UTF-16 indexing model.
pub fn TextSnapshot::length(self : TextSnapshot) -> Int {
  self.text.length()
}

///|
/// Number of logical lines, including the final empty line after a trailing
/// newline.
pub fn TextSnapshot::line_count(self : TextSnapshot) -> Int {
  self.line_starts.length()
}

///|
/// Start offset for `line`, clamped into the snapshot's line range.
pub fn TextSnapshot::line_start_offset(self : TextSnapshot, line : Int) -> Int {
  let line = @base_common.clamp_int(line, 0, self.line_count() - 1)
  self.line_starts[line]
}

///|
/// End offset for `line`, clamped into the snapshot's line range and excluding
/// the line break. CRLF lines exclude both the `\r` and `\n`.
pub fn TextSnapshot::line_end_offset(self : TextSnapshot, line : Int) -> Int {
  let line = @base_common.clamp_int(line, 0, self.line_count() - 1)
  let raw_end = if line + 1 < self.line_count() {
    self.line_starts[line + 1] - 1
  } else {
    self.length()
  }
  if raw_end > self.line_starts[line] && self.text[raw_end - 1].to_int() == 13 {
    raw_end - 1
  } else {
    raw_end
  }
}

///|
/// Text of one logical line without its line break.
pub fn TextSnapshot::line_text(self : TextSnapshot, line : Int) -> String {
  let start = self.line_start_offset(line)
  let end = self.line_end_offset(line)
  self.text[start:end].to_owned()
}

///|
/// Full document text with lines joined by `\n` (the viewer's normalized
/// end-of-line). Mirrors Monaco's `getValue()` at its default LF EOL; the
/// viewer has no EOL option, so it always emits `\n`.
pub fn TextSnapshot::get_value(self : TextSnapshot) -> String {
  let sb = StringBuilder::new()
  for line in 0..<self.line_count() {
    if line > 0 {
      sb.write_string("\n")
    }
    sb.write_string(self.line_text(line))
  }
  sb.to_string()
}

///|
/// Text inside a 1-based line/column `Range`, interior line breaks emitted as
/// `\n`. Mirrors Monaco's `getValueInRange` at its default LF EOL. Columns are
/// clamped into each line.
pub fn TextSnapshot::get_value_in_range(
  self : TextSnapshot,
  range : @base_common.Range,
) -> String {
  let start_line = @base_common.clamp_int(
    range.start_line_number - 1,
    0,
    self.line_count() - 1,
  )
  let end_line = @base_common.clamp_int(
    range.end_line_number - 1,
    0,
    self.line_count() - 1,
  )
  if start_line == end_line {
    let line = self.line_text(start_line)
    let a = @base_common.clamp_int(range.start_column - 1, 0, line.length())
    let b = @base_common.clamp_int(range.end_column - 1, a, line.length())
    return line[a:b].to_owned()
  }
  let sb = StringBuilder::new()
  let first = self.line_text(start_line)
  let a = @base_common.clamp_int(range.start_column - 1, 0, first.length())
  sb.write_string(first[a:first.length()].to_owned())
  for line = start_line + 1; line < end_line; line = line + 1 {
    sb.write_string("\n")
    sb.write_string(self.line_text(line))
  }
  let last = self.line_text(end_line)
  let b = @base_common.clamp_int(range.end_column - 1, 0, last.length())
  sb.write_string("\n")
  sb.write_string(last[0:b].to_owned())
  sb.to_string()
}

///|
/// Length, in UTF-16 code units, of `get_value_in_range`. Mirrors Monaco's
/// `getValueLengthInRange` at its default LF EOL.
pub fn TextSnapshot::get_value_length_in_range(
  self : TextSnapshot,
  range : @base_common.Range,
) -> Int {
  self.get_value_in_range(range).length()
}

///|
/// Returns a clamped half-open slice of the snapshot text.
pub fn TextSnapshot::slice(
  self : TextSnapshot,
  range : @base_common.OffsetRange,
) -> String {
  let start = @base_common.clamp_int(range.start, 0, self.length())
  let end = @base_common.clamp_int(range.end_exclusive, start, self.length())
  self.text[start:end].to_owned()
}

///|
/// Zero-based line containing `offset`, with out-of-range offsets clamped to
/// the snapshot.
pub fn TextSnapshot::line_at_offset(self : TextSnapshot, offset : Int) -> Int {
  let offset = @base_common.clamp_int(offset, 0, self.length())
  let mut found = 0
  for i in 0..<self.line_starts.length() {
    if self.line_starts[i] <= offset {
      found = i
    }
  }
  found
}

///|
/// Converts an offset to a one-based line/column `Position` (Monaco's
/// convention; this is the offset↔position boundary, so it adds the +1 on both
/// axes that keeps the rest of the viewer in 1-based coordinates).
pub fn TextSnapshot::position_at_offset(
  self : TextSnapshot,
  offset : Int,
) -> @base_common.Position {
  let offset = @base_common.clamp_int(offset, 0, self.length())
  let line = self.line_at_offset(offset)
  { line_number: line + 1, column: offset - self.line_starts[line] + 1 }
}

///|
/// Converts an offset span to a line/column `Range` (the boundary helper for
/// code that carries `Range` but holds offsets, e.g. the hover widget).
pub fn TextSnapshot::range_of(
  self : TextSnapshot,
  offset_range : @base_common.OffsetRange,
) -> @base_common.Range {
  @base_common.Range::from_positions(
    self.position_at_offset(offset_range.start),
    self.position_at_offset(offset_range.end_exclusive),
  )
}

///|
/// Converts a line/column `Range` to an offset span (inverse of `range_of`).
pub fn TextSnapshot::offset_range_of(
  self : TextSnapshot,
  range : @base_common.Range,
) -> @base_common.OffsetRange {
  OffsetRange(
    self.offset_at_position(range.get_start_position()),
    self.offset_at_position(range.get_end_position()),
  )
}

///|
/// Converts a one-based line/column `Position` to a clamped document offset,
/// undoing the +1 this boundary added in `position_at_offset`.
pub fn TextSnapshot::offset_at_position(
  self : TextSnapshot,
  position : @base_common.Position,
) -> Int {
  let line = @base_common.clamp_int(
    position.line_number - 1,
    0,
    self.line_count() - 1,
  )
  let start = self.line_start_offset(line)
  let end = self.line_end_offset(line)
  @base_common.clamp_int(start + position.column - 1, start, end)
}

///|
/// Length, in UTF-16 code units, of `line`'s content (1-based, EOL excluded).
/// Mirrors Monaco's `getLineLength`.
fn TextSnapshot::get_line_length(self : TextSnapshot, line : Int) -> Int {
  self.line_text(line - 1).length()
}

///|
/// Max (1-based) column for `line`: content length + 1. Mirrors
/// `getLineMaxColumn`.
pub fn TextSnapshot::get_line_max_column(self : TextSnapshot, line : Int) -> Int {
  self.get_line_length(line) + 1
}

///|
/// Code unit at 0-based `index` of `line`'s content. Mirrors `getLineCharCode`.
fn TextSnapshot::get_line_char_code(
  self : TextSnapshot,
  line : Int,
  index : Int,
) -> Int {
  self.line_text(line - 1)[index].to_int()
}

///|
/// Core of `validate_position` (Monaco's `_validatePosition`). When `surrogate`
/// is true, a column landing in the middle of a high-low surrogate pair is
/// moved to before the pair. `surrogate=false` is Monaco's `Relaxed` mode (a
/// plain clamp). Inputs are integers, so Monaco's `NaN`/float coercion is moot.
fn TextSnapshot::do_validate_position(
  self : TextSnapshot,
  line_number : Int,
  column : Int,
  surrogate : Bool,
) -> @base_common.Position {
  let line_count = self.line_count()
  if line_number < 1 {
    return Position(1, 1)
  }
  if line_number > line_count {
    return Position(line_count, self.get_line_max_column(line_count))
  }
  if column <= 1 {
    return Position(line_number, 1)
  }
  let max_column = self.get_line_max_column(line_number)
  if column >= max_column {
    return Position(line_number, max_column)
  }
  if surrogate {
    // column > 1 here; if it would split a high-low pair, move before it.
    let char_code_before = self.get_line_char_code(line_number, column - 2)
    if @base_common.is_high_surrogate(char_code_before) {
      return Position(line_number, column - 1)
    }
  }
  Position(line_number, column)
}

///|
/// Clamps a position into the snapshot, snapping out of the middle of a
/// surrogate pair. Mirrors Monaco's `validatePosition`.
pub fn TextSnapshot::validate_position(
  self : TextSnapshot,
  position : @base_common.Position,
) -> @base_common.Position {
  self.do_validate_position(position.line_number, position.column, true)
}

///|
/// Clamps a range into the snapshot, expanding out of any surrogate pair its
/// ends land inside. Mirrors Monaco's `validateRange`.
pub fn TextSnapshot::validate_range(
  self : TextSnapshot,
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
  let sl = start.line_number
  let sc = start.column
  let el = end.line_number
  let ec = end.column
  let char_before_start = if sc > 1 {
    self.get_line_char_code(sl, sc - 2)
  } else {
    0
  }
  let char_before_end = if ec > 1 && ec <= self.get_line_length(el) {
    self.get_line_char_code(el, ec - 2)
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
/// snapshot. Mirrors Monaco's `modifyPosition` (relaxed-validate, then offset
/// round-trip).
pub fn TextSnapshot::modify_position(
  self : TextSnapshot,
  position : @base_common.Position,
  offset : Int,
) -> @base_common.Position {
  let valid = self.do_validate_position(
    position.line_number,
    position.column,
    false,
  )
  let candidate = self.offset_at_position(valid) + offset
  let clamped = @base_common.clamp_int(candidate, 0, self.length())
  self.position_at_offset(clamped)
}

///|
/// 1-based column of the first non-whitespace character on `line`, or `0` if the
/// line is empty/whitespace-only. Mirrors `getLineFirstNonWhitespaceColumn`.
pub fn TextSnapshot::get_line_first_non_whitespace_column(
  self : TextSnapshot,
  line : Int,
) -> Int {
  let result = @base_common.first_non_whitespace_index(self.line_text(line - 1))
  if result == -1 {
    0
  } else {
    result + 1
  }
}

///|
/// 1-based column just past the last non-whitespace character on `line`, or `0`
/// if the line is empty/whitespace-only. Mirrors
/// `getLineLastNonWhitespaceColumn`.
pub fn TextSnapshot::get_line_last_non_whitespace_column(
  self : TextSnapshot,
  line : Int,
) -> Int {
  let result = @base_common.last_non_whitespace_index(self.line_text(line - 1))
  if result == -1 {
    0
  } else {
    result + 2
  }
}

///|
/// Whether the snapshot text contains any right-to-left character. Mirrors
/// `mightContainRTL` (recomputed on demand rather than cached at construction).
pub fn TextSnapshot::might_contain_rtl(self : TextSnapshot) -> Bool {
  @base_common.contains_rtl(self.text)
}

///|
/// Offsets where each line begins (0-based), splitting only on `\n` (LF). A
/// lonely `\r` (classic-Mac CR EOL) does not start a new line. This LF-only
/// limitation is shared with the byte-identical copy in
/// `internal/shell/workspace/document.mbt`; the two straddle the product/shell
/// boundary, so they are intentionally not unified but must change together if
/// CR handling is ever added.
fn build_line_starts(text : String) -> Array[Int] {
  let starts = [0]
  for i in 0..<text.length() {
    if text[i].to_int() == 10 {
      starts.push(i + 1)
    }
  }
  starts
}
