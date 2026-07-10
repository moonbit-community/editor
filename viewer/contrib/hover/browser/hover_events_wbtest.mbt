// The anchor-candidate pass of
// `contentHoverWidgetWrapper._findHoverAnchorCandidates`, relocated with
// `find_anchor_candidates` (see hover_events.mbt's header). One case per
// behavior-switching branch, over Monaco-shaped model-space targets.

///|
fn text_target(
  line : Int,
  column : Int,
  injected_text? : @view_model.InjectedText,
) -> @editor_browser.MouseTarget {
  MouseTargetContentText(
    element=None,
    mouse_column=column,
    position=Position(line, column),
    range=Range(line, column, line, column),
    detail={ might_be_foreign_element: injected_text is Some(_), injected_text },
  )
}

///|
fn empty_target(
  line : Int,
  column : Int,
  horizontal_distance_to_text : Double?,
  is_after_lines? : Bool = false,
) -> @editor_browser.MouseTarget {
  MouseTargetContentEmpty(
    element=None,
    mouse_column=column,
    position=Position(line, column),
    range=Range(line, column, line, column),
    detail={ is_after_lines, horizontal_distance_to_text },
  )
}

///|
test "find_anchor_candidates: a content-text hit yields the priority-0 range anchor at the hit position" {
  let candidates = find_anchor_candidates([], text_target(2, 4), 10.0)
  assert_eq(candidates.length(), 1)
  match candidates[0] {
    HoverRangeAnchor(priority~, range~, ..) => {
      assert_eq(priority, 0)
      assert_true(range == Range(2, 4, 2, 4))
    }
    _ => fail("expected the range anchor")
  }
}

///|
test "find_anchor_candidates: the inlay participant's foreign anchor outranks the range anchor" {
  let participants : Array[&@hover.HoverParticipant] = [
    @hover.InlayHintsHover::new(),
  ]
  let injected : @view_model.InjectedText = InjectedText(
    Position(0, 4),
    ": Int",
    "inlay-hint",
    source_index=2,
  )
  let candidates = find_anchor_candidates(
    participants,
    text_target(1, 5, injected_text=injected),
    10.0,
  )
  // Both the foreign (priority 10) and the range (priority 0) anchors are
  // suggested; the sort puts the foreign anchor first.
  assert_eq(candidates.length(), 2)
  match candidates[0] {
    HoverForeignElementAnchor(injected_text_index~, supports_marker_hover~, ..) => {
      assert_eq(injected_text_index, 2)
      assert_true(supports_marker_hover)
    }
    _ => fail("expected the foreign anchor to sort first")
  }
  assert_true(candidates[1] is HoverRangeAnchor(..))
}

///|
test "find_anchor_candidates: content-empty anchors only within the epsilon past the line end" {
  // typicalHalfwidthCharacterWidth 10 -> epsilon 5. Distance 4.0 anchors.
  let close = find_anchor_candidates([], empty_target(1, 10, Some(4.0)), 10.0)
  assert_eq(close.length(), 1)
  // Monaco has no lower bound: a distance of exactly 0 anchors too.
  let zero = find_anchor_candidates([], empty_target(1, 10, Some(0.0)), 10.0)
  assert_eq(zero.length(), 1)
  // Distance at/over the epsilon does not.
  let far = find_anchor_candidates([], empty_target(1, 10, Some(5.0)), 10.0)
  assert_eq(far.length(), 0)
  // An absent distance (Monaco's non-`number` `horizontalDistanceToText`,
  // e.g. an unrendered line) yields no anchor.
  let unknown = find_anchor_candidates([], empty_target(1, 1, None), 10.0)
  assert_eq(unknown.length(), 0)
  // Below every line (`isAfterLines: true`) yields no anchor even with a
  // small distance.
  let after_lines = find_anchor_candidates(
    [],
    empty_target(3, 1, Some(1.0), is_after_lines=true),
    10.0,
  )
  assert_eq(after_lines.length(), 0)
}
