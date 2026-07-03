// Ported from `vscode/src/vs/editor/browser/stableEditorScroll.ts`
// (`StableEditorScrollState`; `StableEditorBottomScrollState` has no viewer
// consumer and is not ported). Anchors the viewport on the first visible
// position so content-height changes above it (a zone growing) do not shift
// what the user is looking at. Package-private: the only consumer is the
// comments zone-widget relayout (`commentThreadZoneWidget.ts:521`); Monaco
// does not export the class through its public API either. The
// `hasPendingScrollAnimation` guard has no analog — the viewer has no smooth
// scrolling, and the `_cursorPosition` member backing the unported
// `restoreRelativeVerticalPositionOfCursor` (no cursor-anchored consumer) is
// omitted.

///|
priv struct StableEditorScrollState {
  initial_scroll_top : Double
  initial_content_height : Double
  visible_position : @base_common.Position?
  visible_position_scroll_delta : Double
}

///|
/// `capture` (`stableEditorScroll.ts:12-28`).
fn StableEditorScrollState::capture(viewer : Viewer) -> StableEditorScrollState {
  if viewer.get_scroll_top() <= 0.0 {
    // Never mess with the scroll top if the editor is at the top of the file.
    return {
      initial_scroll_top: viewer.get_scroll_top(),
      initial_content_height: viewer.get_content_height(),
      visible_position: None,
      visible_position_scroll_delta: 0.0,
    }
  }
  let mut visible_position : @base_common.Position? = None
  let mut visible_position_scroll_delta = 0.0
  let visible_ranges = viewer.get_visible_ranges()
  match visible_ranges.get(0) {
    Some(first) => {
      let position = @base_common.Position(
        first.start_line_number,
        first.start_column,
      )
      visible_position = Some(position)
      let visible_position_scroll_top = viewer.get_top_for_position(
        position.line_number,
        position.column,
      )
      visible_position_scroll_delta = viewer.get_scroll_top() -
        visible_position_scroll_top
    }
    None => ()
  }
  {
    initial_scroll_top: viewer.get_scroll_top(),
    initial_content_height: viewer.get_content_height(),
    visible_position,
    visible_position_scroll_delta,
  }
}

///|
/// `restore` (`stableEditorScroll.ts:38-49`).
fn StableEditorScrollState::restore(
  self : StableEditorScrollState,
  viewer : Viewer,
) -> Unit {
  if self.initial_content_height == viewer.get_content_height() &&
    self.initial_scroll_top == viewer.get_scroll_top() {
    // The editor's content height and scroll top haven't changed, so we
    // don't need to do anything.
    return
  }
  match self.visible_position {
    Some(position) => {
      let visible_position_scroll_top = viewer.get_top_for_position(
        position.line_number,
        position.column,
      )
      viewer.set_scroll_top(
        visible_position_scroll_top + self.visible_position_scroll_delta,
      )
    }
    None => ()
  }
}
