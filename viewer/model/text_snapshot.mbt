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
/// Returns a clamped half-open slice of the snapshot text.
pub fn TextSnapshot::slice(
  self : TextSnapshot,
  range : @base_common.OffsetRange,
) -> String {
  let start = @base_common.clamp_int(range.start, 0, self.length())
  let end = @base_common.clamp_int(range.end, start, self.length())
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
/// Converts an offset to a zero-based line/column position.
pub fn TextSnapshot::position_at_offset(
  self : TextSnapshot,
  offset : Int,
) -> @base_common.Position {
  let offset = @base_common.clamp_int(offset, 0, self.length())
  let line = self.line_at_offset(offset)
  { line, column: offset - self.line_starts[line] }
}

///|
/// Converts a zero-based line/column position to a clamped document offset.
pub fn TextSnapshot::offset_at_position(
  self : TextSnapshot,
  position : @base_common.Position,
) -> Int {
  let line = @base_common.clamp_int(position.line, 0, self.line_count() - 1)
  let start = self.line_start_offset(line)
  let end = self.line_end_offset(line)
  @base_common.clamp_int(start + position.column, start, end)
}

///|
fn build_line_starts(text : String) -> Array[Int] {
  let starts = [0]
  for i in 0..<text.length() {
    if text[i].to_int() == 10 {
      starts.push(i + 1)
    }
  }
  starts
}
