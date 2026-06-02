///|
pub(all) struct Position {
  line : Int
  column : Int
} derive(Eq, Debug)

///|
pub(all) struct Range {
  start : Int
  end : Int
} derive(Eq, Debug)

///|
pub(all) struct DocumentSnapshot {
  text : String
  language_id : String
  version : Int
  line_starts : Array[Int]
} derive(Debug)

///|
pub fn DocumentSnapshot::new(
  text : String,
  language_id? : String = "moonbit",
  version? : Int = 1,
) -> DocumentSnapshot {
  let line_starts = build_line_starts(text)
  { text, language_id, version, line_starts }
}

///|
pub fn DocumentSnapshot::length(self : DocumentSnapshot) -> Int {
  self.text.length()
}

///|
pub fn DocumentSnapshot::line_count(self : DocumentSnapshot) -> Int {
  self.line_starts.length()
}

///|
pub fn DocumentSnapshot::line_start_offset(
  self : DocumentSnapshot,
  line : Int,
) -> Int {
  let line = clamp_int(line, 0, self.line_count() - 1)
  self.line_starts[line]
}

///|
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
pub fn DocumentSnapshot::line_text(
  self : DocumentSnapshot,
  line : Int,
) -> String {
  let start = self.line_start_offset(line)
  let end = self.line_end_offset(line)
  self.text[start:end].to_owned()
}

///|
pub fn DocumentSnapshot::slice(
  self : DocumentSnapshot,
  range : Range,
) -> String {
  let start = clamp_int(range.start, 0, self.length())
  let end = clamp_int(range.end, start, self.length())
  self.text[start:end].to_owned()
}

///|
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
pub fn DocumentSnapshot::position_at_offset(
  self : DocumentSnapshot,
  offset : Int,
) -> Position {
  let offset = clamp_int(offset, 0, self.length())
  let line = self.line_at_offset(offset)
  { line, column: offset - self.line_starts[line] }
}

///|
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
pub fn Position::Position(line : Int, column : Int) -> Position {
  { line, column }
}

///|
pub fn Range::new(start : Int, end : Int) -> Range {
  if start <= end {
    { start, end }
  } else {
    { start: end, end: start }
  }
}

///|
pub fn Range::contains_offset(self : Range, offset : Int) -> Bool {
  self.start <= offset && offset < self.end
}

///|
pub fn Range::intersects(self : Range, other : Range) -> Bool {
  self.start < other.end && other.start < self.end
}

///|
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
pub fn clamp_int(value : Int, low : Int, high : Int) -> Int {
  if value < low {
    low
  } else if value > high {
    high
  } else {
    value
  }
}
