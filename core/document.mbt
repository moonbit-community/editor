///|
/// Zero-based line and UTF-16 column inside a document snapshot.
pub(all) struct Position {
  line : Int
  column : Int
} derive(Eq, Debug)

///|
/// Half-open UTF-16 offset range `[start, end)` in a document snapshot.
pub(all) struct Range {
  start : Int
  end : Int
} derive(Eq, Debug)

///|
/// Immutable text plus cached line starts. Offsets and columns are UTF-16
/// code units so browser, Monaco, and LSP-facing code share one convention.
pub(all) struct DocumentSnapshot {
  text : String
  language_id : String
  version : Int
  line_starts : Array[Int]
} derive(Debug)

///|
/// Builds a snapshot and derives the line-start table used by all position
/// conversion helpers.
pub fn DocumentSnapshot::DocumentSnapshot(
  text : String,
  language_id? : String = "moonbit",
  version? : Int = 1,
) -> DocumentSnapshot {
  let line_starts = build_line_starts(text)
  { text, language_id, version, line_starts }
}

///|
/// Snapshot length in the repo's JavaScript-compatible UTF-16 indexing model.
pub fn DocumentSnapshot::length(self : DocumentSnapshot) -> Int {
  self.text.length()
}

///|
/// Number of logical lines, including the final empty line after a trailing
/// newline.
pub fn DocumentSnapshot::line_count(self : DocumentSnapshot) -> Int {
  self.line_starts.length()
}

///|
/// Start offset for `line`, clamped into the snapshot's line range.
pub fn DocumentSnapshot::line_start_offset(
  self : DocumentSnapshot,
  line : Int,
) -> Int {
  let line = clamp_int(line, 0, self.line_count() - 1)
  self.line_starts[line]
}

///|
/// End offset for `line`, clamped into the snapshot's line range and excluding
/// the line break. CRLF lines exclude both the `\r` and `\n`.
pub fn DocumentSnapshot::line_end_offset(
  self : DocumentSnapshot,
  line : Int,
) -> Int {
  let line = clamp_int(line, 0, self.line_count() - 1)
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
pub fn DocumentSnapshot::line_text(
  self : DocumentSnapshot,
  line : Int,
) -> String {
  let start = self.line_start_offset(line)
  let end = self.line_end_offset(line)
  self.text[start:end].to_owned()
}

///|
/// Returns a clamped half-open slice of the snapshot text.
pub fn DocumentSnapshot::slice(
  self : DocumentSnapshot,
  range : Range,
) -> String {
  let start = clamp_int(range.start, 0, self.length())
  let end = clamp_int(range.end, start, self.length())
  self.text[start:end].to_owned()
}

///|
/// Zero-based line containing `offset`, with out-of-range offsets clamped to
/// the snapshot.
pub fn DocumentSnapshot::line_at_offset(
  self : DocumentSnapshot,
  offset : Int,
) -> Int {
  let offset = clamp_int(offset, 0, self.length())
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
pub fn DocumentSnapshot::position_at_offset(
  self : DocumentSnapshot,
  offset : Int,
) -> Position {
  let offset = clamp_int(offset, 0, self.length())
  let line = self.line_at_offset(offset)
  { line, column: offset - self.line_starts[line] }
}

///|
/// Converts a zero-based line/column position to a clamped document offset.
pub fn DocumentSnapshot::offset_at_position(
  self : DocumentSnapshot,
  position : Position,
) -> Int {
  let line = clamp_int(position.line, 0, self.line_count() - 1)
  let start = self.line_start_offset(line)
  let end = self.line_end_offset(line)
  clamp_int(start + position.column, start, end)
}

///|
/// Builds a position without normalization; callers decide the coordinate
/// space before conversion through `DocumentSnapshot`.
pub fn Position::Position(line : Int, column : Int) -> Position {
  { line, column }
}

///|
/// Builds a normalized half-open range by swapping endpoints when needed.
pub fn Range::Range(start : Int, end : Int) -> Range {
  if start <= end {
    { start, end }
  } else {
    { start: end, end: start }
  }
}

///|
/// Whether `offset` falls inside the half-open range.
pub fn Range::contains_offset(self : Range, offset : Int) -> Bool {
  self.start <= offset && offset < self.end
}

///|
/// Whether two half-open ranges overlap.
pub fn Range::intersects(self : Range, other : Range) -> Bool {
  self.start < other.end && other.start < self.end
}

///|
/// Whether the range contains no offsets.
pub fn Range::is_empty(self : Range) -> Bool {
  self.start == self.end
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

///|
/// Clamps an integer to an inclusive range.
pub fn clamp_int(value : Int, low : Int, high : Int) -> Int {
  if value < low {
    low
  } else if value > high {
    high
  } else {
    value
  }
}
