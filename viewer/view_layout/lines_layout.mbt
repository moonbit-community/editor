///|
/// Faithful 1:1 port of Monaco's `LinesLayout` (and `EditorWhitespace`) from
/// `vscode/src/vs/editor/common/viewLayout/linesLayout.ts` at submodule commit
/// 294fb350837dbaee37b949533fead4df4e0e8971.
///
/// Layouts objects that take vertical space (lines and the whitespaces between
/// them, i.e. view zones). Lines are addressed with Monaco's 1-based line
/// numbers; whitespaces are addressed by an opaque `id`, sorted by
/// `(afterLineNumber, ordinal)`.
///
/// DEVIATION: variable line heights (`LineHeightsManager` /
/// `lineHeights.test.ts`) are out of scope (Conditional row in the conformance
/// plan), so the port keeps a single uniform `default_line_height`. Every
/// `linesLayout.test.ts` case constructs the layout with an empty
/// `customLineHeightData` (`[]`), so this matches the upstream tests exactly;
/// the accumulated-line-height helper collapses to `lineNumber * height`.

///|
/// A whitespace (view zone) that displaces the lines after `after_line_number`.
pub struct EditorWhitespace {
  id : String
  mut after_line_number : Int
  ordinal : Int
  mut height : Int
  min_width : Int
  mut prefix_sum : Int
} derive(Eq, Debug)

///|
/// Constructs a whitespace; `prefix_sum` starts at 0 (lazily computed).
pub fn EditorWhitespace::new(
  id : String,
  after_line_number : Int,
  ordinal : Int,
  height : Int,
  min_width : Int,
) -> EditorWhitespace {
  { id, after_line_number, ordinal, height, min_width, prefix_sum: 0 }
}

///|
/// Lines and relative offsets positioned between two vertical offsets — the
/// Monaco `IPartialViewLinesViewportData` shape.
pub struct PartialViewLinesViewportData {
  big_numbers_delta : Int
  start_line_number : Int
  end_line_number : Int
  relative_vertical_offset : Array[Int]
  centered_line_number : Int
  completely_visible_start_line_number : Int
  completely_visible_end_line_number : Int
  line_height : Int
} derive(Eq, Debug)

///|
/// One whitespace positioned relative to a viewport — the Monaco
/// `IViewWhitespaceViewportData` shape.
pub struct ViewWhitespaceViewportData {
  id : String
  after_line_number : Int
  vertical_offset : Int
  height : Int
} derive(Eq, Debug)

///|
priv struct PendingChange {
  id : String
  new_after_line_number : Int
  new_height : Int
}

///|
priv struct PendingRemove {
  id : String
}

///|
priv struct PendingChanges {
  mut has_pending : Bool
  mut inserts : Array[EditorWhitespace]
  mut changes : Array[PendingChange]
  mut removes : Array[PendingRemove]
}

///|
fn PendingChanges::new() -> PendingChanges {
  { has_pending: false, inserts: [], changes: [], removes: [] }
}

///|
fn PendingChanges::insert(self : PendingChanges, x : EditorWhitespace) -> Unit {
  self.has_pending = true
  self.inserts.push(x)
}

///|
fn PendingChanges::change(self : PendingChanges, x : PendingChange) -> Unit {
  self.has_pending = true
  self.changes.push(x)
}

///|
fn PendingChanges::remove(self : PendingChanges, x : PendingRemove) -> Unit {
  self.has_pending = true
  self.removes.push(x)
}

///|
fn PendingChanges::commit(
  self : PendingChanges,
  lines_layout : LinesLayout,
) -> Unit {
  if !self.has_pending {
    return
  }
  let inserts = self.inserts
  let changes = self.changes
  let removes = self.removes
  self.has_pending = false
  self.inserts = []
  self.changes = []
  self.removes = []
  lines_layout.commit_pending_changes(inserts, changes, removes)
}

///|
/// Global instance counter, mirroring Monaco's `LinesLayout.INSTANCE_COUNT`.
let lines_layout_instance_count : Ref[Int] = Ref(0)

///|
/// Mutable accessor handed to `change_whitespace`, mirroring Monaco's
/// `IWhitespaceChangeAccessor`.
pub struct WhitespaceChangeAccessor {
  priv layout : LinesLayout
  priv mut had_a_change : Bool
}

///|
/// Queues a whitespace insertion; returns its freshly minted id.
pub fn WhitespaceChangeAccessor::insert_whitespace(
  self : WhitespaceChangeAccessor,
  after_line_number : Int,
  ordinal : Int,
  height_in_px : Int,
  min_width : Int,
) -> String {
  self.had_a_change = true
  self.layout.last_whitespace_id = self.layout.last_whitespace_id + 1
  let id = "\{self.layout.instance_id}\{self.layout.last_whitespace_id}"
  self.layout.pending_changes.insert(
    EditorWhitespace::new(
      id, after_line_number, ordinal, height_in_px, min_width,
    ),
  )
  id
}

///|
/// Queues a whitespace `afterLineNumber`/`height` change.
pub fn WhitespaceChangeAccessor::change_one_whitespace(
  self : WhitespaceChangeAccessor,
  id : String,
  new_after_line_number : Int,
  new_height : Int,
) -> Unit {
  self.had_a_change = true
  self.layout.pending_changes.change({ id, new_after_line_number, new_height })
}

///|
/// Queues a whitespace removal.
pub fn WhitespaceChangeAccessor::remove_whitespace(
  self : WhitespaceChangeAccessor,
  id : String,
) -> Unit {
  self.had_a_change = true
  self.layout.pending_changes.remove({ id, })
}

///|
/// Vertical line layout: lines (uniform `default_line_height`) and the
/// whitespaces (view zones) that push them down.
pub struct LinesLayout {
  priv instance_id : String
  priv pending_changes : PendingChanges
  priv mut last_whitespace_id : Int
  priv mut arr : Array[EditorWhitespace]
  priv mut prefix_sum_valid_index : Int
  priv mut min_width : Int
  priv mut line_count : Int
  priv mut padding_top : Int
  priv mut padding_bottom : Int
  priv mut default_line_height : Int
}

///|
/// Creates a lines layout. `custom_line_height_data` is accepted for shape
/// parity with Monaco but ignored (uniform heights — see file deviation).
pub fn LinesLayout::new(
  line_count : Int,
  default_line_height : Int,
  padding_top : Int,
  padding_bottom : Int,
) -> LinesLayout {
  lines_layout_instance_count.val = lines_layout_instance_count.val + 1
  {
    instance_id: single_letter_hash(lines_layout_instance_count.val),
    pending_changes: PendingChanges::new(),
    last_whitespace_id: 0,
    arr: [],
    prefix_sum_valid_index: -1,
    min_width: -1,
    line_count,
    padding_top,
    padding_bottom,
    default_line_height,
  }
}

///|
/// Find the insertion index for a new whitespace inside a sorted array. If the
/// value is already present, the index is after the existing one.
pub fn LinesLayout::find_insertion_index(
  arr : Array[EditorWhitespace],
  after_line_number : Int,
  ordinal : Int,
) -> Int {
  let mut low = 0
  let mut high = arr.length()
  while low < high {
    let mid = (low + high) / 2
    if after_line_number == arr[mid].after_line_number {
      if ordinal < arr[mid].ordinal {
        high = mid
      } else {
        low = mid + 1
      }
    } else if after_line_number < arr[mid].after_line_number {
      high = mid
    } else {
      low = mid + 1
    }
  }
  low
}

///|
/// Change the uniform line height in pixels.
pub fn LinesLayout::set_default_line_height(
  self : LinesLayout,
  line_height : Int,
) -> Unit {
  self.default_line_height = line_height
}

///|
/// Changes the padding used to calculate vertical offsets.
pub fn LinesLayout::set_padding(
  self : LinesLayout,
  padding_top : Int,
  padding_bottom : Int,
) -> Unit {
  self.padding_top = padding_top
  self.padding_bottom = padding_bottom
}

///|
/// Set the number of lines (Monaco's `onFlushed`).
pub fn LinesLayout::on_flushed(self : LinesLayout, line_count : Int) -> Unit {
  self.line_count = line_count
}

///|
/// Run `callback` with a whitespace-change accessor, then commit the batch.
/// Returns whether anything changed.
pub fn LinesLayout::change_whitespace(
  self : LinesLayout,
  callback : (WhitespaceChangeAccessor) -> Unit,
) -> Bool {
  let accessor = { layout: self, had_a_change: false }
  callback(accessor)
  self.pending_changes.commit(self)
  accessor.had_a_change
}

///|
fn LinesLayout::commit_pending_changes(
  self : LinesLayout,
  inserts : Array[EditorWhitespace],
  changes : Array[PendingChange],
  removes : Array[PendingRemove],
) -> Unit {
  if inserts.length() > 0 || removes.length() > 0 {
    self.min_width = -1
  }
  if inserts.length() + changes.length() + removes.length() <= 1 {
    // when only one thing happened, handle it "delicately"
    for insert in inserts {
      self.insert_whitespace(insert)
    }
    for change in changes {
      self.change_one_whitespace(
        change.id,
        change.new_after_line_number,
        change.new_height,
      )
    }
    for remove in removes {
      let index = self.find_whitespace_index(remove.id)
      if index == -1 {
        continue
      }
      self.remove_whitespace(index)
    }
    return
  }

  // simply rebuild the entire datastructure
  let to_remove : Map[String, Bool] = {}
  for remove in removes {
    to_remove[remove.id] = true
  }
  let to_change : Map[String, PendingChange] = {}
  for change in changes {
    to_change[change.id] = change
  }
  let apply_remove_and_change = fn(
    whitespaces : Array[EditorWhitespace],
  ) -> Array[EditorWhitespace] {
    let result : Array[EditorWhitespace] = []
    for whitespace in whitespaces {
      if to_remove.contains(whitespace.id) {
        continue
      }
      match to_change.get(whitespace.id) {
        Some(change) => {
          whitespace.after_line_number = change.new_after_line_number
          whitespace.height = change.new_height
        }
        None => ()
      }
      result.push(whitespace)
    }
    result
  }
  let result = apply_remove_and_change(self.arr)
  for w in apply_remove_and_change(inserts) {
    result.push(w)
  }
  result.sort_by(fn(a, b) {
    if a.after_line_number == b.after_line_number {
      a.ordinal - b.ordinal
    } else {
      a.after_line_number - b.after_line_number
    }
  })
  self.arr = result
  self.prefix_sum_valid_index = -1
}

///|
fn LinesLayout::insert_whitespace(
  self : LinesLayout,
  whitespace : EditorWhitespace,
) -> Unit {
  let insert_index = LinesLayout::find_insertion_index(
    self.arr,
    whitespace.after_line_number,
    whitespace.ordinal,
  )
  self.arr.insert(insert_index, whitespace)
  self.prefix_sum_valid_index = self.prefix_sum_valid_index.min(
    insert_index - 1,
  )
}

///|
fn LinesLayout::find_whitespace_index(self : LinesLayout, id : String) -> Int {
  let arr = self.arr
  for i in 0..<arr.length() {
    if arr[i].id == id {
      return i
    }
  }
  -1
}

///|
fn LinesLayout::change_one_whitespace(
  self : LinesLayout,
  id : String,
  new_after_line_number : Int,
  new_height : Int,
) -> Unit {
  let index = self.find_whitespace_index(id)
  if index == -1 {
    return
  }
  if self.arr[index].height != new_height {
    self.arr[index].height = new_height
    self.prefix_sum_valid_index = self.prefix_sum_valid_index.min(index - 1)
  }
  if self.arr[index].after_line_number != new_after_line_number {
    // `afterLineNumber` changed: removing then re-inserting may reorder it.
    let whitespace = self.arr[index]
    self.remove_whitespace(index)
    whitespace.after_line_number = new_after_line_number
    self.insert_whitespace(whitespace)
  }
}

///|
fn LinesLayout::remove_whitespace(
  self : LinesLayout,
  remove_index : Int,
) -> Unit {
  self.arr.remove(remove_index) |> ignore
  self.prefix_sum_valid_index = self.prefix_sum_valid_index.min(
    remove_index - 1,
  )
}

///|
/// Notify that a continuous zone of lines was deleted (inclusive bounds).
pub fn LinesLayout::on_lines_deleted(
  self : LinesLayout,
  from_line_number : Int,
  to_line_number : Int,
) -> Unit {
  self.line_count = self.line_count - (to_line_number - from_line_number + 1)
  for i in 0..<self.arr.length() {
    let after_line_number = self.arr[i].after_line_number
    if from_line_number <= after_line_number &&
      after_line_number <= to_line_number {
      // The line this whitespace was after has been deleted
      //  => move whitespace to before first deleted line
      self.arr[i].after_line_number = from_line_number - 1
    } else if after_line_number > to_line_number {
      // The line this whitespace was after has been moved up
      //  => move whitespace up
      self.arr[i].after_line_number = self.arr[i].after_line_number -
        (to_line_number - from_line_number + 1)
    }
  }
}

///|
/// Notify that a continuous zone of lines was inserted (inclusive bounds).
pub fn LinesLayout::on_lines_inserted(
  self : LinesLayout,
  from_line_number : Int,
  to_line_number : Int,
) -> Unit {
  self.line_count = self.line_count + (to_line_number - from_line_number + 1)
  for i in 0..<self.arr.length() {
    let after_line_number = self.arr[i].after_line_number
    if from_line_number <= after_line_number {
      self.arr[i].after_line_number = self.arr[i].after_line_number +
        (to_line_number - from_line_number + 1)
    }
  }
}

///|
/// The sum of all whitespace heights.
pub fn LinesLayout::get_whitespaces_total_height(self : LinesLayout) -> Int {
  if self.arr.length() == 0 {
    return 0
  }
  self.get_whitespaces_accumulated_height(self.arr.length() - 1)
}

///|
/// Sum of the heights of whitespaces in `[0..index]` (inclusive of `index`).
pub fn LinesLayout::get_whitespaces_accumulated_height(
  self : LinesLayout,
  index : Int,
) -> Int {
  let mut start_index = (0).max(self.prefix_sum_valid_index + 1)
  if start_index == 0 {
    self.arr[0].prefix_sum = self.arr[0].height
    start_index = start_index + 1
  }
  for i in start_index..<=index {
    self.arr[i].prefix_sum = self.arr[i - 1].prefix_sum + self.arr[i].height
  }
  self.prefix_sum_valid_index = self.prefix_sum_valid_index.max(index)
  self.arr[index].prefix_sum
}

///|
/// The sum of heights for all objects (lines + whitespaces + padding).
pub fn LinesLayout::get_lines_total_height(self : LinesLayout) -> Int {
  let lines_height = self.accumulated_line_heights_including_line_number(
    self.line_count,
  )
  let whitespaces_height = self.get_whitespaces_total_height()
  lines_height + whitespaces_height + self.padding_top + self.padding_bottom
}

///|
/// Accumulated height of whitespaces strictly before `line_number`.
pub fn LinesLayout::get_whitespace_accumulated_height_before_line_number(
  self : LinesLayout,
  line_number : Int,
) -> Int {
  let last_whitespace_before = self.find_last_whitespace_before_line_number(
    line_number,
  )
  if last_whitespace_before == -1 {
    return 0
  }
  self.get_whitespaces_accumulated_height(last_whitespace_before)
}

///|
fn LinesLayout::find_last_whitespace_before_line_number(
  self : LinesLayout,
  line_number : Int,
) -> Int {
  let arr = self.arr
  let mut low = 0
  let mut high = arr.length() - 1
  while low <= high {
    let delta = high - low
    let half_delta = delta / 2
    let mid = low + half_delta
    if arr[mid].after_line_number < line_number {
      if mid + 1 >= arr.length() ||
        arr[mid + 1].after_line_number >= line_number {
        return mid
      } else {
        low = mid + 1
      }
    } else {
      high = mid - 1
    }
  }
  -1
}

///|
fn LinesLayout::find_first_whitespace_after_line_number(
  self : LinesLayout,
  line_number : Int,
) -> Int {
  let last_whitespace_before = self.find_last_whitespace_before_line_number(
    line_number,
  )
  let first_whitespace_after = last_whitespace_before + 1
  if first_whitespace_after < self.arr.length() {
    return first_whitespace_after
  }
  -1
}

///|
/// Index of the first whitespace with `afterLineNumber` >= `line_number`,
/// or -1 if there is none.
pub fn LinesLayout::get_first_whitespace_index_after_line_number(
  self : LinesLayout,
  line_number : Int,
) -> Int {
  self.find_first_whitespace_after_line_number(line_number)
}

///|
/// Vertical offset (sum of heights of everything above) of `line_number`.
pub fn LinesLayout::get_vertical_offset_for_line_number(
  self : LinesLayout,
  line_number : Int,
  include_view_zones? : Bool = false,
) -> Int {
  let previous_lines_height = if line_number > 1 {
    self.accumulated_line_heights_including_line_number(line_number - 1)
  } else {
    0
  }
  let previous_whitespaces_height = self.get_whitespace_accumulated_height_before_line_number(
    line_number - (if include_view_zones { 1 } else { 0 }),
  )
  previous_lines_height + previous_whitespaces_height + self.padding_top
}

///|
/// The (uniform) height of `line_number`.
pub fn LinesLayout::get_line_height_for_line_number(
  self : LinesLayout,
  _line_number : Int,
) -> Int {
  self.default_line_height
}

///|
/// Vertical offset including `line_number`'s own height.
pub fn LinesLayout::get_vertical_offset_after_line_number(
  self : LinesLayout,
  line_number : Int,
  include_view_zones? : Bool = false,
) -> Int {
  let previous_lines_height = self.accumulated_line_heights_including_line_number(
    line_number,
  )
  let previous_whitespaces_height = self.get_whitespace_accumulated_height_before_line_number(
    line_number + (if include_view_zones { 1 } else { 0 }),
  )
  previous_lines_height + previous_whitespaces_height + self.padding_top
}

///|
/// Whether there is any whitespace in the document.
pub fn LinesLayout::has_whitespace(self : LinesLayout) -> Bool {
  self.get_whitespaces_count() > 0
}

///|
/// The maximum min width over all whitespaces.
pub fn LinesLayout::get_whitespace_min_width(self : LinesLayout) -> Int {
  if self.min_width == -1 {
    let mut min_width = 0
    for i in 0..<self.arr.length() {
      min_width = min_width.max(self.arr[i].min_width)
    }
    self.min_width = min_width
  }
  self.min_width
}

///|
/// Whether `vertical_offset` is below all lines.
pub fn LinesLayout::is_after_lines(
  self : LinesLayout,
  vertical_offset : Int,
) -> Bool {
  vertical_offset > self.get_lines_total_height()
}

///|
/// Whether `vertical_offset` falls in the top padding.
pub fn LinesLayout::is_in_top_padding(
  self : LinesLayout,
  vertical_offset : Int,
) -> Bool {
  if self.padding_top == 0 {
    return false
  }
  vertical_offset < self.padding_top
}

///|
/// Whether `vertical_offset` falls in the bottom padding.
pub fn LinesLayout::is_in_bottom_padding(
  self : LinesLayout,
  vertical_offset : Int,
) -> Bool {
  if self.padding_bottom == 0 {
    return false
  }
  vertical_offset >= self.get_lines_total_height() - self.padding_bottom
}

///|
/// First line number at or after vertical offset `vertical_offset`.
pub fn LinesLayout::get_line_number_at_or_after_vertical_offset(
  self : LinesLayout,
  vertical_offset : Int,
) -> Int {
  if vertical_offset < 0 {
    return 1
  }
  let lines_count = self.line_count
  let mut min_line_number = 1
  let mut max_line_number = lines_count
  while min_line_number < max_line_number {
    let mid_line_number = (min_line_number + max_line_number) / 2
    let line_height = self.get_line_height_for_line_number(mid_line_number)
    let mid_line_number_vertical_offset = self.get_vertical_offset_for_line_number(
      mid_line_number,
    )
    if vertical_offset >= mid_line_number_vertical_offset + line_height {
      // vertical offset is after mid line number
      min_line_number = mid_line_number + 1
    } else if vertical_offset >= mid_line_number_vertical_offset {
      // Hit
      return mid_line_number
    } else {
      // vertical offset is before mid line number, but it could still be it
      max_line_number = mid_line_number
    }
  }
  if min_line_number > lines_count {
    return lines_count
  }
  min_line_number
}

///|
/// All lines (and their relative vertical offsets) positioned between
/// `vertical_offset1` and `vertical_offset2`.
pub fn LinesLayout::get_lines_viewport_data(
  self : LinesLayout,
  vertical_offset1 : Int,
  vertical_offset2 : Int,
) -> PartialViewLinesViewportData {
  // Find first line number (it might start before or after verticalOffset1).
  let start_line_number = self.get_line_number_at_or_after_vertical_offset(
    vertical_offset1,
  )
  let start_line_number_vertical_offset = self.get_vertical_offset_for_line_number(
    start_line_number,
  )
  let mut end_line_number = self.line_count

  // Also keep track of what whitespace we've got.
  let mut whitespace_index = self.get_first_whitespace_index_after_line_number(
    start_line_number,
  )
  let whitespace_count = self.get_whitespaces_count()
  let mut current_whitespace_height = 0
  let mut current_whitespace_after_line_number = 0
  if whitespace_index == -1 {
    whitespace_index = whitespace_count
    current_whitespace_after_line_number = end_line_number + 1
    current_whitespace_height = 0
  } else {
    current_whitespace_after_line_number = self.get_after_line_number_for_whitespace_index(
      whitespace_index,
    )
    current_whitespace_height = self.get_height_for_whitespace_index(
      whitespace_index,
    )
  }
  let mut current_vertical_offset = start_line_number_vertical_offset
  let mut current_line_relative_offset = current_vertical_offset

  // IE cannot handle units above ~1.5M px, so step down past 500k px.
  let step_size = 500000
  let mut big_numbers_delta = 0
  if start_line_number_vertical_offset >= step_size {
    big_numbers_delta = start_line_number_vertical_offset /
      step_size *
      step_size
    big_numbers_delta = big_numbers_delta /
      self.default_line_height *
      self.default_line_height
    current_line_relative_offset = current_line_relative_offset -
      big_numbers_delta
  }
  let lines_offsets : Array[Int] = []
  let vertical_center = vertical_offset1.to_double() +
    (vertical_offset2 - vertical_offset1).to_double() / 2.0
  let mut centered_line_number = -1

  // Figure out how far the lines go.
  let mut line_number = start_line_number
  while line_number <= end_line_number {
    let line_height = self.get_line_height_for_line_number(line_number)
    if centered_line_number == -1 {
      let current_line_top = current_vertical_offset
      let current_line_bottom = current_vertical_offset + line_height
      if (
          current_line_top.to_double() <= vertical_center &&
          vertical_center < current_line_bottom.to_double()
        ) ||
        current_line_top.to_double() > vertical_center {
        centered_line_number = line_number
      }
    }

    // Count current line height in the vertical offsets.
    current_vertical_offset = current_vertical_offset + line_height
    lines_offsets.push(current_line_relative_offset)

    // Next line starts immediately after this one.
    current_line_relative_offset = current_line_relative_offset + line_height
    while current_whitespace_after_line_number == line_number {
      // Push down next line with the height of the current whitespace.
      current_line_relative_offset = current_line_relative_offset +
        current_whitespace_height

      // Count current whitespace in the vertical offsets.
      current_vertical_offset = current_vertical_offset +
        current_whitespace_height
      whitespace_index = whitespace_index + 1
      if whitespace_index >= whitespace_count {
        current_whitespace_after_line_number = end_line_number + 1
      } else {
        current_whitespace_after_line_number = self.get_after_line_number_for_whitespace_index(
          whitespace_index,
        )
        current_whitespace_height = self.get_height_for_whitespace_index(
          whitespace_index,
        )
      }
    }
    if current_vertical_offset >= vertical_offset2 {
      // We have covered the entire viewport area, time to stop.
      end_line_number = line_number
      break
    }
    line_number = line_number + 1
  }
  if centered_line_number == -1 {
    centered_line_number = end_line_number
  }
  let end_line_number_vertical_offset = self.get_vertical_offset_for_line_number(
    end_line_number,
  )
  let mut completely_visible_start_line_number = start_line_number
  let mut completely_visible_end_line_number = end_line_number
  if completely_visible_start_line_number < completely_visible_end_line_number {
    if start_line_number_vertical_offset < vertical_offset1 {
      completely_visible_start_line_number = completely_visible_start_line_number +
        1
    }
  }
  if completely_visible_start_line_number < completely_visible_end_line_number {
    let end_line_height = self.get_line_height_for_line_number(end_line_number)
    if end_line_number_vertical_offset + end_line_height > vertical_offset2 {
      completely_visible_end_line_number = completely_visible_end_line_number -
        1
    }
  }
  {
    big_numbers_delta,
    start_line_number,
    end_line_number,
    relative_vertical_offset: lines_offsets,
    centered_line_number,
    completely_visible_start_line_number,
    completely_visible_end_line_number,
    line_height: self.default_line_height,
  }
}

///|
/// Vertical offset of the whitespace at `whitespace_index`.
pub fn LinesLayout::get_vertical_offset_for_whitespace_index(
  self : LinesLayout,
  whitespace_index : Int,
) -> Int {
  let after_line_number = self.get_after_line_number_for_whitespace_index(
    whitespace_index,
  )
  let previous_lines_height = if after_line_number >= 1 {
    self.accumulated_line_heights_including_line_number(after_line_number)
  } else {
    0
  }
  let previous_whitespaces_height = if whitespace_index > 0 {
    self.get_whitespaces_accumulated_height(whitespace_index - 1)
  } else {
    0
  }
  previous_lines_height + previous_whitespaces_height + self.padding_top
}

///|
/// Index of the first whitespace at or after vertical offset `vertical_offset`,
/// or -1 if there is none.
pub fn LinesLayout::get_whitespace_index_at_or_after_vertical_offset(
  self : LinesLayout,
  vertical_offset : Int,
) -> Int {
  let mut min_whitespace_index = 0
  let mut max_whitespace_index = self.get_whitespaces_count() - 1
  if max_whitespace_index < 0 {
    return -1
  }
  // Special case: nothing to be found.
  let max_whitespace_vertical_offset = self.get_vertical_offset_for_whitespace_index(
    max_whitespace_index,
  )
  let max_whitespace_height = self.get_height_for_whitespace_index(
    max_whitespace_index,
  )
  if vertical_offset >= max_whitespace_vertical_offset + max_whitespace_height {
    return -1
  }
  while min_whitespace_index < max_whitespace_index {
    let mid_whitespace_index = (min_whitespace_index + max_whitespace_index) / 2
    let mid_whitespace_vertical_offset = self.get_vertical_offset_for_whitespace_index(
      mid_whitespace_index,
    )
    let mid_whitespace_height = self.get_height_for_whitespace_index(
      mid_whitespace_index,
    )
    if vertical_offset >= mid_whitespace_vertical_offset + mid_whitespace_height {
      // vertical offset is after whitespace
      min_whitespace_index = mid_whitespace_index + 1
    } else if vertical_offset >= mid_whitespace_vertical_offset {
      // Hit
      return mid_whitespace_index
    } else {
      // before whitespace, but mid index could still be the answer
      max_whitespace_index = mid_whitespace_index
    }
  }
  min_whitespace_index
}

///|
/// Exactly the whitespace layouted at `vertical_offset`, or `None`.
pub fn LinesLayout::get_whitespace_at_vertical_offset(
  self : LinesLayout,
  vertical_offset : Int,
) -> ViewWhitespaceViewportData? {
  let candidate_index = self.get_whitespace_index_at_or_after_vertical_offset(
    vertical_offset,
  )
  if candidate_index < 0 {
    return None
  }
  if candidate_index >= self.get_whitespaces_count() {
    return None
  }
  let candidate_top = self.get_vertical_offset_for_whitespace_index(
    candidate_index,
  )
  if candidate_top > vertical_offset {
    return None
  }
  let candidate_height = self.get_height_for_whitespace_index(candidate_index)
  let candidate_id = self.get_id_for_whitespace_index(candidate_index)
  let candidate_after_line_number = self.get_after_line_number_for_whitespace_index(
    candidate_index,
  )
  Some({
    id: candidate_id,
    after_line_number: candidate_after_line_number,
    vertical_offset: candidate_top,
    height: candidate_height,
  })
}

///|
/// All whitespaces positioned between `vertical_offset1` and `vertical_offset2`.
pub fn LinesLayout::get_whitespace_viewport_data(
  self : LinesLayout,
  vertical_offset1 : Int,
  vertical_offset2 : Int,
) -> Array[ViewWhitespaceViewportData] {
  let start_index = self.get_whitespace_index_at_or_after_vertical_offset(
    vertical_offset1,
  )
  let end_index = self.get_whitespaces_count() - 1
  if start_index < 0 {
    return []
  }
  let result : Array[ViewWhitespaceViewportData] = []
  for i in start_index..<=end_index {
    let top = self.get_vertical_offset_for_whitespace_index(i)
    let height = self.get_height_for_whitespace_index(i)
    if top >= vertical_offset2 {
      break
    }
    result.push({
      id: self.get_id_for_whitespace_index(i),
      after_line_number: self.get_after_line_number_for_whitespace_index(i),
      vertical_offset: top,
      height,
    })
  }
  result
}

///|
/// All whitespaces (a copy).
pub fn LinesLayout::get_whitespaces(
  self : LinesLayout,
) -> Array[EditorWhitespace] {
  self.arr.copy()
}

///|
/// The number of whitespaces.
pub fn LinesLayout::get_whitespaces_count(self : LinesLayout) -> Int {
  self.arr.length()
}

///|
/// The `id` of the whitespace at `index`.
pub fn LinesLayout::get_id_for_whitespace_index(
  self : LinesLayout,
  index : Int,
) -> String {
  self.arr[index].id
}

///|
/// The `afterLineNumber` of the whitespace at `index`.
pub fn LinesLayout::get_after_line_number_for_whitespace_index(
  self : LinesLayout,
  index : Int,
) -> Int {
  self.arr[index].after_line_number
}

///|
/// The `height` of the whitespace at `index`.
pub fn LinesLayout::get_height_for_whitespace_index(
  self : LinesLayout,
  index : Int,
) -> Int {
  self.arr[index].height
}

///|
/// Uniform-height accumulation: sum of line heights for lines `1..=line_number`
/// (`0` for `line_number <= 0`). Replaces Monaco's `LineHeightsManager`.
fn LinesLayout::accumulated_line_heights_including_line_number(
  self : LinesLayout,
  line_number : Int,
) -> Int {
  if line_number <= 0 {
    0
  } else {
    line_number * self.default_line_height
  }
}

///|
/// Port of Monaco's `strings.singleLetterHash`: maps `n` to a single letter
/// (`a..z` then `A..Z`, wrapping), used to prefix whitespace ids per instance.
fn single_letter_hash(n : Int) -> String {
  let letters_cnt = 26
  let n = n % (2 * letters_cnt)
  if n < letters_cnt {
    let code = 'a'.to_int() + n
    Int::unsafe_to_char(code).to_string()
  } else {
    let code = 'A'.to_int() + n - letters_cnt
    Int::unsafe_to_char(code).to_string()
  }
}
