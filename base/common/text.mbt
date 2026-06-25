///|
/// A position in the editor, a 1:1 port of Monaco/VS Code's `Position`
/// (`vs/editor/common/core/position.ts`). One-based on both axes:
/// `line_number` starts at 1 and `column` starts at 1 (the first character on a
/// line sits between column 1 and column 2). Field names use the repo's
/// snake_case convention (`line_number`), matching `Range::start_line_number`.
pub(all) struct Position {
  line_number : Int
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
pub fn Position::Position(line_number : Int, column : Int) -> Position {
  { line_number, column }
}

///|
/// A new position derived from this one. `None` for either axis keeps this
/// position's value, mirroring Monaco's `with(newLineNumber, newColumn)`
/// defaults. (`with_` because `with` clashes with MoonBit's struct-update and
/// trait-impl syntax.)
pub fn Position::with_(
  self : Position,
  line_number? : Int,
  column? : Int,
) -> Position {
  let new_line_number = line_number.unwrap_or(self.line_number)
  let new_column = column.unwrap_or(self.column)
  if new_line_number == self.line_number && new_column == self.column {
    self
  } else {
    Position::Position(new_line_number, new_column)
  }
}

///|
/// Derive a new position by shifting it, clamping both axes to at least 1.
/// Mirrors Monaco's `delta(deltaLineNumber, deltaColumn)`.
pub fn Position::delta(
  self : Position,
  delta_line_number~ : Int = 0,
  delta_column~ : Int = 0,
) -> Position {
  self.with_(
    line_number=clamp_int(self.line_number + delta_line_number, 1, 2147483647),
    column=clamp_int(self.column + delta_column, 1, 2147483647),
  )
}

///|
/// Whether this position equals `other`. Mirrors Monaco's `Position.equals`.
pub fn Position::equals(self : Position, other : Position) -> Bool {
  self.line_number == other.line_number && self.column == other.column
}

///|
/// Whether this position is strictly before `other` (equal positions return
/// false). Mirrors Monaco's `Position.isBefore`.
pub fn Position::is_before(self : Position, other : Position) -> Bool {
  if self.line_number < other.line_number {
    return true
  }
  if other.line_number < self.line_number {
    return false
  }
  self.column < other.column
}

///|
/// Whether this position is before or equal to `other`. Mirrors Monaco's
/// `Position.isBeforeOrEqual`.
pub fn Position::is_before_or_equal(self : Position, other : Position) -> Bool {
  if self.line_number < other.line_number {
    return true
  }
  if other.line_number < self.line_number {
    return false
  }
  self.column <= other.column
}

///|
/// Compares two positions for sorting (line, then column). Mirrors Monaco's
/// static `Position.compare`.
pub fn Position::compare(a : Position, b : Position) -> Int {
  if a.line_number == b.line_number {
    return a.column - b.column
  }
  a.line_number - b.line_number
}

///|
/// A copy of this position. Mirrors Monaco's `Position.clone` (a value copy
/// here, since `Position` is a value type).
pub fn Position::clone(self : Position) -> Position {
  Position::Position(self.line_number, self.column)
}

///|
/// Human-readable `(line,column)` form. Mirrors Monaco's `Position.toString`.
pub fn Position::to_string(self : Position) -> String {
  "(\{self.line_number},\{self.column})"
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
