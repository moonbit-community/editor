///|
/// Zero-based line and UTF-16 column inside a text snapshot.
pub(all) struct Position {
  line : Int
  column : Int
} derive(Eq, Debug)

///|
/// Half-open UTF-16 offset range `[start, end)` in a text snapshot.
pub(all) struct Range {
  start : Int
  end : Int
} derive(Eq, Debug)

///|
/// Builds a position without normalization; callers decide the coordinate
/// space before conversion through `TextSnapshot`.
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
