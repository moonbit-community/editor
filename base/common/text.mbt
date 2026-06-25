///|
/// Zero-based line and UTF-16 column inside a text snapshot.
pub(all) struct Position {
  line : Int
  column : Int
} derive(Eq, Debug)

///|
/// Half-open UTF-16 offset range `[start, end)` in a text snapshot. This is the
/// viewer's offset-based span, mirroring Monaco's `OffsetRange`. The name
/// `Range` is reserved for Monaco's line/column range (see `monaco_range.mbt`).
pub(all) struct OffsetRange {
  start : Int
  end : Int
} derive(Eq, Debug)

///|
/// Builds a position without normalization; callers decide the coordinate
/// space before conversion through a snapshot.
pub fn Position::Position(line : Int, column : Int) -> Position {
  { line, column }
}

///|
/// Builds a normalized half-open range by swapping endpoints when needed.
pub fn OffsetRange::OffsetRange(start : Int, end : Int) -> OffsetRange {
  if start <= end {
    { start, end }
  } else {
    { start: end, end: start }
  }
}

///|
/// Whether `offset` falls inside the half-open range.
pub fn OffsetRange::contains_offset(self : OffsetRange, offset : Int) -> Bool {
  self.start <= offset && offset < self.end
}

///|
/// Whether two half-open ranges overlap.
pub fn OffsetRange::intersects(self : OffsetRange, other : OffsetRange) -> Bool {
  self.start < other.end && other.start < self.end
}

///|
/// Whether the range contains no offsets.
pub fn OffsetRange::is_empty(self : OffsetRange) -> Bool {
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
