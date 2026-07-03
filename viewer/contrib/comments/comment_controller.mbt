// The DOM-free logic of the comments editor contribution, ported from
// `vscode/src/vs/workbench/contrib/comments/browser/commentsController.ts`
// (`CommentingRangeDecorator` with both the hover and the drag-selection/
// multiline arms, the mouse-down/up pairing state) and
// `commentThreadZoneWidget.ts` (`parseMouseDownInfoFromEvent`,
// `isMouseUpEventDragFromMouseDown`, `isMouseUpEventMatchMouseDown`) plus the
// glyph options of `commentGlyphWidget.ts` (`createDecorationOptions`).
// Monaco's DOM checks (`e.target.element.className.indexOf(
// 'comment-range-glyph')`) become the semantic `line_in_commenting_context`
// argument: the rendered lane class *is* the decoration's
// `lines_decorations_class_name`, so "the line renders a commenting-range or
// thread glyph" is the same predicate, evaluated DOM-free.

///|
/// `CommentingRangeDecorator.description` — stamped on commenting-range
/// decorations.
pub let commenting_range_decoration_description : String = "commenting-range-decorator"

///|
/// `CommentGlyphWidget.description` — stamped on per-thread glyph
/// decorations (`commentGlyphWidget.ts`).
pub let comment_glyph_decoration_description : String = "comment-glyph-widget"

///|
/// The editor-side comment interaction state: the pending mouse-down line
/// (`CommentController.mouseDownInfo`), the commenting-range decorator's
/// last hover line (`CommentingRangeDecorator._lastHover`, `-1` = none), and
/// the in-progress gutter-drag selection (`_lastSelection` /
/// `_lastSelectionCursor`, as a normalized line pair).
pub struct CommentController {
  mut mouse_down_line : Int?
  mut hover_line : Int
  mut last_selection : (Int, Int)?
  mut last_selection_cursor : Int?
}

///|
pub fn CommentController::new() -> CommentController {
  {
    mouse_down_line: None,
    hover_line: -1,
    last_selection: None,
    last_selection_cursor: None,
  }
}

///|
/// `CommentingRangeDecorator.updateSelection` (`commentsController.ts:
/// 157-166`): records the gutter-drag selection (normalized; Monaco's
/// `Range` constructor swaps reversed endpoints) and its drag cursor. In the
/// readonly viewer the selection lives for the drag only — Monaco keeps it
/// across cursor-selection changes, which the drag itself produces here.
pub fn CommentController::update_selection(
  self : CommentController,
  cursor_line : Int,
  anchor_line : Int,
) -> Unit {
  self.last_selection = if anchor_line <= cursor_line {
    Some((anchor_line, cursor_line))
  } else {
    Some((cursor_line, anchor_line))
  }
  self.last_selection_cursor = Some(cursor_line)
}

///|
/// Clears the drag selection (drag finished or cancelled).
pub fn CommentController::clear_selection(self : CommentController) -> Unit {
  self.last_selection = None
  self.last_selection_cursor = None
}

///|
/// `parseMouseDownInfoFromEvent` (`commentThreadZoneWidget.ts:53-77`): a
/// left-button mousedown counts only on a line-decorations-lane target within
/// 20px of the lane's left edge ("don't collide with folding and git
/// decorations") on a line that renders a comment glyph.
pub fn parse_mouse_down_info(
  kind : @viewer_common.MouseTargetKind,
  gutter_offset_x : Double,
  line_number : Int,
  line_in_commenting_context : Bool,
) -> Int? {
  if line_number < 1 {
    // `!range` (`:56`).
    return None
  }
  if kind != GutterLineDecorations {
    return None
  }
  if gutter_offset_x > 20.0 {
    return None
  }
  if !line_in_commenting_context {
    // `onEditorMouseDown`'s `className.indexOf('comment-range-glyph')` gate
    // (`commentsController.ts:1108`).
    return None
  }
  Some(line_number)
}

///|
/// Records a mousedown's parse result (`CommentController.onEditorMouseDown`,
/// `commentsController.ts:1107-1109`).
pub fn CommentController::on_mouse_down(
  self : CommentController,
  kind : @viewer_common.MouseTargetKind,
  gutter_offset_x : Double,
  line_number : Int,
  line_in_commenting_context : Bool,
) -> Unit {
  self.mouse_down_line = parse_mouse_down_info(
    kind, gutter_offset_x, line_number, line_in_commenting_context,
  )
}

///|
/// What a mouseup that pairs with a recorded mousedown asks the editor to
/// do (`onEditorMouseUp`, `commentsController.ts:1111-1145`).
pub(all) enum MouseUpOutcome {
  /// No pending down, no line, or a same-line up off the decorator.
  NoAction
  /// Same-line up on the decorator: toggle a thread at the line or create
  /// one there (`mouseUpIsOnDecorator` + same line).
  LaneClick(Int)
  /// "drag along gutter decoration" (`:1124`): down and up lines differ;
  /// carries `(down_line, up_line)`.
  GutterDrag(Int, Int)
} derive(Eq, Debug)

///|
/// `isMouseUpEventDragFromMouseDown` + `isMouseUpEventMatchMouseDown`
/// (`commentThreadZoneWidget.ts:79-110`) and the branch heads of
/// `onEditorMouseUp` (`commentsController.ts:1111-1141`): a drag needs only
/// a target line (any kind — the drag can end over content); a same-line
/// click must land back on the decorator. Consumes the pending down.
pub fn CommentController::on_mouse_up(
  self : CommentController,
  kind : @viewer_common.MouseTargetKind,
  line_number : Int,
  line_in_commenting_context : Bool,
) -> MouseUpOutcome {
  let down = self.mouse_down_line
  self.mouse_down_line = None
  guard down is Some(down_line) else { return NoAction }
  if line_number < 1 {
    return NoAction
  }
  if line_number != down_line {
    return GutterDrag(down_line, line_number)
  }
  if kind != GutterLineDecorations || !line_in_commenting_context {
    return NoAction
  }
  LaneClick(line_number)
}

///|
/// `CommentingRangeDecorator.updateHover` (`commentsController.ts:150-155`):
/// returns whether the hover line changed (the caller re-syncs decorations
/// when it did). `-1` clears the hover (mouse leave).
pub fn CommentController::update_hover(
  self : CommentController,
  line_number : Int,
) -> Bool {
  if line_number == self.hover_line {
    false
  } else {
    self.hover_line = line_number
    true
  }
}

///|
/// The commenting-range decoration set for one resource —
/// `CommentingRangeDecorator._doUpdate` (`commentsController.ts:181-249`):
/// each commenting range renders `comment-range-glyph comment-diff-added`
/// whole-line pieces; the emphasis line (the drag cursor when a selection is
/// live, else the hovered line) swaps in `comment-range-glyph line-hover`
/// (the CSS "+"), and a live gutter-drag selection renders
/// `comment-range-glyph multiline-add` over its remainder, all with split
/// before/after base pieces. An emphasis line that already carries a thread
/// glyph is skipped (`_lineHasThread`, `:233-235`), realized as the
/// `thread_lines` argument since the viewer's decoration options carry no
/// queryable description.
pub fn commenting_range_decorations(
  ranges : Array[@base_common.Range],
  hover_line : Int,
  thread_lines : Array[Int],
  selection? : (Int, Int),
  selection_cursor? : Int,
) -> Array[@model.DeltaDecoration] {
  let decorations : Array[@model.DeltaDecoration] = []
  let base_options = @model.Decoration::Decoration(
    "",
    is_whole_line=true,
    lines_decorations_class_name="comment-range-glyph comment-diff-added",
    description=commenting_range_decoration_description,
  )
  let hover_options = @model.Decoration::Decoration(
    "",
    is_whole_line=true,
    lines_decorations_class_name="comment-range-glyph line-hover",
    description=commenting_range_decoration_description,
  )
  let multiline_options = @model.Decoration::Decoration(
    "",
    is_whole_line=true,
    lines_decorations_class_name="comment-range-glyph multiline-add",
    description=commenting_range_decoration_description,
  )
  // `emphasisLine = this._lastSelectionCursor ?? emphasisLine` (`:187`).
  let emphasis_line = match selection_cursor {
    Some(cursor) => cursor
    None => hover_line
  }
  for range in ranges {
    // `rangeObject.intersectRanges(selectionRange)`, line-wise.
    let intersecting : (Int, Int)? = match selection {
      Some((sel_start, sel_end)) => {
        let start = if sel_start > range.start_line_number {
          sel_start
        } else {
          range.start_line_number
        }
        let end = if sel_end < range.end_line_number {
          sel_end
        } else {
          range.end_line_number
        }
        if start <= end {
          Some((start, end))
        } else {
          None
        }
      }
      None => None
    }
    // The selection arm (`:191-224`); a single-line selection whose emphasis
    // is that line drops into the hover arm (`:193-195`).
    let selection_arm : (Int, Int)? = match intersecting {
      Some((isect_start, isect_end)) =>
        if emphasis_line >= 0 &&
          !(isect_start == isect_end && emphasis_line == isect_start) {
          Some((isect_start, isect_end))
        } else {
          None
        }
      None => None
    }
    match selection_arm {
      Some((isect_start, isect_end)) => {
        // Clip the emphasis and selection ranges to the commenting range
        // (`:199-208`).
        let (emphasis, remainder_start, remainder_end) = if emphasis_line <=
          isect_start {
          (isect_start, isect_start + 1, isect_end)
        } else {
          (isect_end, isect_start, isect_end - 1)
        }
        if remainder_start <= remainder_end {
          decorations.push({
            range: Range(remainder_start, 1, remainder_end, 1),
            options: multiline_options,
          })
        }
        if !thread_lines.contains(emphasis) {
          decorations.push({
            range: Range(emphasis, 1, emphasis, 1),
            options: hover_options,
          })
        }
        let before_end = (if emphasis < remainder_start {
            emphasis
          } else {
            remainder_start
          }) -
          1
        if range.start_line_number <= before_end {
          decorations.push({
            range: Range(range.start_line_number, 1, before_end, 1),
            options: base_options,
          })
        }
        let after_start = (if emphasis > remainder_end {
            emphasis
          } else {
            remainder_end
          }) +
          1
        if range.end_line_number >= after_start {
          decorations.push({
            range: Range(after_start, 1, range.end_line_number, 1),
            options: base_options,
          })
        }
      }
      _ =>
        if range.start_line_number <= emphasis_line &&
          emphasis_line <= range.end_line_number {
          if range.start_line_number < emphasis_line {
            decorations.push({
              range: Range(range.start_line_number, 1, emphasis_line - 1, 1),
              options: base_options,
            })
          }
          if !thread_lines.contains(emphasis_line) {
            decorations.push({
              range: Range(emphasis_line, 1, emphasis_line, 1),
              options: hover_options,
            })
          }
          if emphasis_line < range.end_line_number {
            decorations.push({
              range: Range(emphasis_line + 1, 1, range.end_line_number, 1),
              options: base_options,
            })
          }
        } else {
          decorations.push({ range, options: base_options })
        }
    }
  }
  decorations
}

///|
/// The per-thread gutter glyph decorations —
/// `CommentGlyphWidget.createDecorationOptions` (`commentGlyphWidget.ts:
/// 52-66`, resolved/unresolved variants and the overview-ruler color out of
/// scope). The glyph sits on the thread range's end line, like
/// `ReviewZoneWidget.display` anchors its glyph.
pub fn thread_glyph_decorations(
  threads : Array[@comments_common.CommentThread],
) -> Array[@model.DeltaDecoration] {
  let options = @model.Decoration::Decoration(
    "",
    is_whole_line=true,
    lines_decorations_class_name="comment-range-glyph comment-thread",
    description=comment_glyph_decoration_description,
  )
  let decorations : Array[@model.DeltaDecoration] = []
  for thread in threads {
    let line = thread.range.end_line_number
    decorations.push({ range: Range(line, 1, line, 1), options })
  }
  decorations
}

///|
/// The glyph lines of the given threads, for `_lineHasThread` checks and the
/// mouse-gate `line_in_commenting_context` predicate.
pub fn thread_lines(
  threads : Array[@comments_common.CommentThread],
) -> Array[Int] {
  threads.map(thread => thread.range.end_line_number)
}

///|
/// Whether a model line is inside any commenting range or carries a thread
/// glyph — the DOM-free `line_in_commenting_context` predicate for the mouse
/// gates.
pub fn line_in_commenting_context(
  ranges : Array[@base_common.Range],
  threads : Array[@comments_common.CommentThread],
  line_number : Int,
) -> Bool {
  for range in ranges {
    if range.start_line_number <= line_number &&
      line_number <= range.end_line_number {
      return true
    }
  }
  thread_lines(threads).contains(line_number)
}
