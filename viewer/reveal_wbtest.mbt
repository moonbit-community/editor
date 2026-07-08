// Phase 2 behavior tests for the `Viewer::reveal*` surface, on the headless
// `with_test_viewer` harness (no DOM): an unattached viewer still owns a full
// view model + layout, so reveals drive real model→view conversion and the
// vertical scroll math. Horizontal reveal needs rendered client rects, so its
// coverage lives in the browser suite (Phase 3).

///|
/// `reveal_line` scrolls a line below the viewport into view, keeping the +1
/// bottom pad clear of the horizontal scrollbar (Monaco's `Simple`).
test "reveal_line brings a line below the viewport into view" {
  with_test_viewer(long_document(200), viewer => {
    viewer.test_set_viewport(width=800.0, height=180.0)
    viewer.reveal_line(50)
    // box_start=(50-1)*18=882, box_end=882+18+18=918; viewport 0..180; the box
    // sits below, so scroll to box_end-180=738.
    assert_eq(viewer.test_view_model().view_layout.position().scroll_top, 738.0)
  })
}

///|
/// Revealing a line already inside the viewport is a no-op.
test "reveal_line leaves an already-visible line untouched" {
  with_test_viewer(long_document(200), viewer => {
    viewer.test_set_viewport(width=800.0, height=180.0)
    viewer.reveal_line(5)
    assert_eq(viewer.test_view_model().view_layout.position().scroll_top, 0.0)
  })
}

///|
/// `reveal_line_in_center` centers the line in the viewport (Monaco's `Center`).
test "reveal_line_in_center centers the target line" {
  with_test_viewer(long_document(200), viewer => {
    viewer.test_set_viewport(width=800.0, height=180.0)
    viewer.reveal_line_in_center(50)
    // box_middle=((49*18)+(49*18+18))/2=891, minus half the viewport (90) = 801.
    assert_eq(viewer.test_view_model().view_layout.position().scroll_top, 801.0)
  })
}

///|
/// A multi-line `reveal_range` resets `scroll_left` to 0 (Monaco's "two or more
/// lines → scroll to base") while still moving vertically to the range.
test "reveal_range over multiple lines resets horizontal scroll" {
  with_test_viewer(long_document(200), viewer => {
    viewer.test_set_viewport(width=800.0, height=180.0)
    viewer.test_view_model().view_layout.set_content_width(2000.0) |> ignore
    viewer.set_scroll_position(scroll_top=0.0, scroll_left=500.0)
    assert_eq(
      viewer.test_view_model().view_layout.position().scroll_left,
      500.0,
    )
    let range = @base_common.Range::Range(50, 1, 52, 1)
    viewer.reveal_range(range)
    let position = viewer.test_view_model().view_layout.position()
    // Vertical: box_start=49*18=882, box_end=51*18+18+18=954; below viewport →
    // scroll to 954-180=774.
    assert_eq(position.scroll_top, 774.0)
    // Horizontal: multi-line range collapses scroll_left to 0.
    assert_eq(position.scroll_left, 0.0)
  })
}

///|
/// A single-line `reveal_range` defers the horizontal scroll: it registers a
/// pending request (flushed against real client rects once the line renders),
/// so `scroll_left` is not changed synchronously. Headlessly there is no DOM, so
/// the deferred flush never runs and `scroll_left` stays put.
test "reveal_range over a single line defers the horizontal scroll" {
  with_test_viewer(long_document(200), viewer => {
    viewer.test_set_viewport(width=800.0, height=180.0)
    viewer.test_view_model().view_layout.set_content_width(2000.0) |> ignore
    viewer.set_scroll_position(scroll_top=0.0, scroll_left=500.0)
    let range = @base_common.Range::Range(50, 3, 50, 8)
    viewer.reveal_range(range)
    // A pending horizontal reveal is registered; the reveal's own vertical
    // scroll did not cancel it.
    assert_true(viewer.horizontal_reveal_request is Some(_))
    // No synchronous horizontal movement.
    assert_eq(
      viewer.test_view_model().view_layout.position().scroll_left,
      500.0,
    )
  })
}

///|
/// A multi-line `reveal_range` clears any outstanding deferred horizontal
/// request (it resets `scroll_left` to 0 instead).
test "multi-line reveal_range clears a pending horizontal reveal" {
  with_test_viewer(long_document(200), viewer => {
    viewer.test_set_viewport(width=800.0, height=180.0)
    viewer.test_view_model().view_layout.set_content_width(2000.0) |> ignore
    let single = @base_common.Range::Range(50, 3, 50, 8)
    viewer.reveal_range(single)
    assert_true(viewer.horizontal_reveal_request is Some(_))
    let multi = @base_common.Range::Range(60, 1, 62, 1)
    viewer.reveal_range(multi)
    assert_true(viewer.horizontal_reveal_request is None)
  })
}

///|
/// A vertical scroll that stays inside the reveal's `[start, stop]` band keeps
/// the deferred request; one that leaves the band cancels it (Monaco's
/// `onScrollChanged`).
test "vertical scroll inside the band keeps, outside cancels, the deferral" {
  with_test_viewer(long_document(200), viewer => {
    viewer.test_set_viewport(width=800.0, height=180.0)
    viewer.test_view_model().view_layout.set_content_width(2000.0) |> ignore
    // Reveal line 50 from the top: band is [0, 738].
    let range = @base_common.Range::Range(50, 3, 50, 8)
    viewer.reveal_range(range)
    viewer.set_scroll_top(100.0)
    assert_true(viewer.horizontal_reveal_request is Some(_))
    viewer.set_scroll_top(2000.0)
    assert_true(viewer.horizontal_reveal_request is None)
  })
}

///|
/// A horizontal scroll by anyone else cancels the deferred reveal.
test "horizontal scroll cancels a pending horizontal reveal" {
  with_test_viewer(long_document(200), viewer => {
    viewer.test_set_viewport(width=800.0, height=180.0)
    viewer.test_view_model().view_layout.set_content_width(2000.0) |> ignore
    let range = @base_common.Range::Range(50, 3, 50, 8)
    viewer.reveal_range(range)
    assert_true(viewer.horizontal_reveal_request is Some(_))
    // Keep scroll_top at the settled 738 (inside the band) but move scroll_left.
    viewer.set_scroll_position(scroll_top=738.0, scroll_left=300.0)
    assert_true(viewer.horizontal_reveal_request is None)
  })
}
