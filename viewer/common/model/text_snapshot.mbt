///|
/// Immutable text plus cached line starts, the readonly analog of Monaco's
/// text buffer: the field pair is the piece tree's leaf (`StringBuffer
/// { buffer, lineStarts }`, `pieceTreeBase.ts:147`) and the 1-based methods
/// are the `IReadonlyTextBuffer` read surface (`model.ts:1524`). Offsets and
/// columns are UTF-16 code units so browser, Monaco, and LSP-facing code
/// share one convention. Document identity (language id, version) lives on
/// `TextModel`, not the buffer — same split as Monaco.
pub(all) struct TextSnapshot {
  text : String
  line_starts : Array[Int]
} derive(Debug)

///|
/// Builds a snapshot and derives the line-start table used by all position
/// conversion helpers.
pub fn TextSnapshot::TextSnapshot(text : String) -> TextSnapshot {
  let line_starts = build_line_starts(text)
  { text, line_starts }
}

///|
/// Snapshot length in the repo's JavaScript-compatible UTF-16 indexing model.
/// Mirrors `IReadonlyTextBuffer.getLength`.
pub fn TextSnapshot::get_length(self : TextSnapshot) -> Int {
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
    self.get_length()
  }
  if raw_end > self.line_starts[line] && self.text[raw_end - 1].to_int() == 13 {
    raw_end - 1
  } else {
    raw_end
  }
}

///|
/// Text of one logical line without its line break. Zero-based, part of the
/// offset-centric internal layer (see the README parity ledger); the
/// `IReadonlyTextBuffer` surface is `get_line_content`.
pub fn TextSnapshot::line_text(self : TextSnapshot, line : Int) -> String {
  let start = self.line_start_offset(line)
  let end = self.line_end_offset(line)
  self.text[start:end].to_owned()
}

///|
/// Text of the one-based `line_number` without its line break, clamped into
/// the snapshot. Mirrors `IReadonlyTextBuffer.getLineContent` (the viewer
/// clamps where Monaco throws `Illegal value for lineNumber`).
pub fn TextSnapshot::get_line_content(
  self : TextSnapshot,
  line_number : Int,
) -> String {
  self.line_text(line_number - 1)
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
  let start = @base_common.clamp_int(range.start, 0, self.get_length())
  let end = @base_common.clamp_int(
    range.end_exclusive,
    start,
    self.get_length(),
  )
  self.text[start:end].to_owned()
}

///|
/// Zero-based line containing `offset`, with out-of-range offsets clamped to
/// the snapshot.
pub fn TextSnapshot::line_at_offset(self : TextSnapshot, offset : Int) -> Int {
  let offset = @base_common.clamp_int(offset, 0, self.get_length())
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
/// axes that keeps the rest of the viewer in 1-based coordinates). Mirrors
/// `IReadonlyTextBuffer.getPositionAt`.
pub fn TextSnapshot::get_position_at(
  self : TextSnapshot,
  offset : Int,
) -> @base_common.Position {
  let offset = @base_common.clamp_int(offset, 0, self.get_length())
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
    self.get_position_at(offset_range.start),
    self.get_position_at(offset_range.end_exclusive),
  )
}

///|
/// Converts a line/column `Range` to an offset span (inverse of `range_of`).
pub fn TextSnapshot::offset_range_of(
  self : TextSnapshot,
  range : @base_common.Range,
) -> @base_common.OffsetRange {
  OffsetRange(
    self.get_offset_at(range.start_line_number, range.start_column),
    self.get_offset_at(range.end_line_number, range.end_column),
  )
}

///|
/// Converts a one-based line/column pair to a clamped document offset,
/// undoing the +1 this boundary added in `get_position_at`. Mirrors
/// `IReadonlyTextBuffer.getOffsetAt` (same arity; the `Position`-taking
/// form is `TextModel::get_offset_at`).
pub fn TextSnapshot::get_offset_at(
  self : TextSnapshot,
  line_number : Int,
  column : Int,
) -> Int {
  let line = @base_common.clamp_int(line_number - 1, 0, self.line_count() - 1)
  let start = self.line_start_offset(line)
  let end = self.line_end_offset(line)
  @base_common.clamp_int(start + column - 1, start, end)
}

///|
/// Length, in UTF-16 code units, of `line`'s content (1-based, EOL excluded).
/// Mirrors `IReadonlyTextBuffer.getLineLength`.
pub fn TextSnapshot::get_line_length(self : TextSnapshot, line : Int) -> Int {
  self.line_text(line - 1).length()
}

///|
/// Max (1-based) column for `line`: content length + 1. Mirrors
/// `getLineMaxColumn`.
pub fn TextSnapshot::get_line_max_column(
  self : TextSnapshot,
  line : Int,
) -> Int {
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
/// Offsets where each line begins (0-based). Mirrors Monaco's
/// `createLineStartsFast` (`pieceTreeBase.ts:37`): `\n`, a lonely `\r`
/// (classic-Mac CR EOL), and `\r\n` each end a line, with the `\r\n` pair
/// counted as one line break. Byte-identical copy in
/// `internal/shell/workspace/document.mbt`; the two straddle the product/shell
/// boundary, so they are intentionally not unified but must change together.
fn build_line_starts(text : String) -> Array[Int] {
  let starts = [0]
  let len = text.length()
  let mut i = 0
  while i < len {
    let code = text[i].to_int()
    if code == 13 {
      if i + 1 < len && text[i + 1].to_int() == 10 {
        // \r\n... case
        starts.push(i + 2)
        i += 2
      } else {
        // \r... case
        starts.push(i + 1)
        i += 1
      }
    } else {
      if code == 10 {
        starts.push(i + 1)
      }
      i += 1
    }
  }
  starts
}
