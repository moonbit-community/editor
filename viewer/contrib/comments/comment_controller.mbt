// The DOM-free logic of the comments editor contribution, ported from
// `vscode/src/vs/workbench/contrib/comments/browser/commentsController.ts`
// (`CommentingRangeDecorator`, the mouse-down/up pairing state) and
// `commentThreadZoneWidget.ts` (`parseMouseDownInfoFromEvent`,
// `isMouseUpEventMatchMouseDown`) plus the glyph options of
// `commentGlyphWidget.ts` (`createDecorationOptions`). The multiline
// drag-selection arm of `CommentingRangeDecorator._doUpdate` is dropped —
// creating a thread is gutter-click-only in the viewer (recorded deviation).
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
/// (`CommentController.mouseDownInfo`) and the commenting-range decorator's
/// last hover line (`CommentingRangeDecorator._lastHover`, `-1` = none).
pub struct CommentController {
  mut mouse_down_line : Int?
  mut hover_line : Int
}

///|
pub fn CommentController::new() -> CommentController {
  { mouse_down_line: None, hover_line: -1 }
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
/// `isMouseUpEventMatchMouseDown` (`commentThreadZoneWidget.ts:95-110`) plus
/// the `mouseUpIsOnDecorator` gate of `onEditorMouseUp`
/// (`commentsController.ts:1111-1141`), collapsed to the click-only flow:
/// the up must land on the lane, on the same line as the down, on a line
/// that renders a comment glyph (the gutter-drag range-selection arm is out
/// of scope). Returns the line to act on and clears the pending down.
pub fn CommentController::on_mouse_up(
  self : CommentController,
  kind : @viewer_common.MouseTargetKind,
  line_number : Int,
  line_in_commenting_context : Bool,
) -> Int? {
  let down = self.mouse_down_line
  self.mouse_down_line = None
  guard down is Some(down_line) else { return None }
  if line_number < 1 || line_number != down_line {
    return None
  }
  if kind != GutterLineDecorations {
    return None
  }
  if !line_in_commenting_context {
    return None
  }
  Some(line_number)
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
/// `CommentingRangeDecorator._doUpdate` (`commentsController.ts:181-249`)
/// without the selection/multiline arm: each commenting range renders
/// `comment-range-glyph comment-diff-added` whole-line pieces, with the
/// hovered line swapped for `comment-range-glyph line-hover` (the CSS "+")
/// and split before/after remainders. A hovered line that already carries a
/// thread glyph is skipped (`_lineHasThread`, `:233-235`), realized as the
/// `thread_lines` argument since the viewer's decoration options carry no
/// queryable description.
pub fn commenting_range_decorations(
  ranges : Array[@base_common.Range],
  hover_line : Int,
  thread_lines : Array[Int],
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
  for range in ranges {
    if range.start_line_number <= hover_line &&
      hover_line <= range.end_line_number {
      if range.start_line_number < hover_line {
        decorations.push({
          range: Range(range.start_line_number, 1, hover_line - 1, 1),
          options: base_options,
        })
      }
      if !thread_lines.contains(hover_line) {
        decorations.push({
          range: Range(hover_line, 1, hover_line, 1),
          options: hover_options,
        })
      }
      if hover_line < range.end_line_number {
        decorations.push({
          range: Range(hover_line + 1, 1, range.end_line_number, 1),
          options: base_options,
        })
      }
    } else {
      decorations.push({ range, options: base_options })
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
