// Headless pointer/event matrix supplement. Real gestures and visible DOM
// selection live in the browser component suite; this file owns exact event
// payloads and reentrant callback state.

///|
fn assert_pointer_transition(
  viewer : Viewer,
  events : Array[CursorSelectionChangedEvent],
  previous_length : Int,
  old_selection : @core.Selection,
  source : String,
) -> Unit raise {
  assert_eq(events.length(), previous_length + 1)
  let event = events[events.length() - 1]
  guard event.old_selections is Some(old) else {
    fail("ordinary pointer transition must retain old selections")
  }
  assert_eq(old.length(), 1)
  assert_selection_eq(old[0], old_selection)
  assert_selection_eq(event.selection, viewer.get_selection().unwrap())
  assert_eq(event.source, source)
  assert_true(event.reason == Explicit)
}

///|
test "live pointer branches retain exact old selections after committed state" {
  with_test_viewer("alpha beta\nsecond line\nthird\nfourth", viewer => {
    let events : Array[CursorSelectionChangedEvent] = []
    let mut position_callbacks_committed = true
    let mut selection_callbacks_committed = true
    viewer.on_did_change_cursor_position(event => {
      position_callbacks_committed = position_callbacks_committed &&
        viewer.get_position().unwrap() == event.position &&
        viewer.test_cursor().model_state().position == event.position
    })
    |> ignore
    viewer.on_did_change_cursor_selection(event => {
      selection_callbacks_committed = selection_callbacks_committed &&
        viewer.get_selection().unwrap() == event.selection &&
        viewer.test_cursor().get_model_selection() == event.selection
      events.push(event)
    })
    |> ignore

    let mut before = viewer.get_selection().unwrap()
    let mut count = events.length()
    viewer.dispatch_mouse(mouse_dispatch_data(Position(1, 3)))
    assert_pointer_transition(viewer, events, count, before, "mouse")

    before = viewer.get_selection().unwrap()
    count = events.length()
    viewer.dispatch_mouse(
      mouse_dispatch_data(Position(1, 8), mouse_down_count=2),
    )
    assert_pointer_transition(viewer, events, count, before, "mouse")

    before = viewer.get_selection().unwrap()
    count = events.length()
    viewer.dispatch_mouse(
      mouse_dispatch_data(
        Position(1, 2),
        in_selection_mode=true,
        mouse_down_count=2,
      ),
    )
    assert_pointer_transition(viewer, events, count, before, "mouse")

    before = viewer.get_selection().unwrap()
    count = events.length()
    viewer.dispatch_mouse(
      mouse_dispatch_data(Position(2, 3), mouse_down_count=3),
    )
    assert_pointer_transition(viewer, events, count, before, "mouse")

    before = viewer.get_selection().unwrap()
    count = events.length()
    viewer.dispatch_mouse(
      mouse_dispatch_data(
        Position(4, 3),
        in_selection_mode=true,
        mouse_down_count=3,
      ),
    )
    assert_pointer_transition(viewer, events, count, before, "mouse")

    before = viewer.get_selection().unwrap()
    count = events.length()
    viewer.dispatch_mouse(
      mouse_dispatch_data(Position(1, 2), started_on_line_numbers=true),
    )
    assert_pointer_transition(viewer, events, count, before, "mouse")

    before = viewer.get_selection().unwrap()
    count = events.length()
    viewer.dispatch_mouse(
      mouse_dispatch_data(
        Position(3, 2),
        started_on_line_numbers=true,
        in_selection_mode=true,
      ),
    )
    assert_pointer_transition(viewer, events, count, before, "mouse")

    before = viewer.get_selection().unwrap()
    count = events.length()
    viewer.dispatch_mouse(
      mouse_dispatch_data(Position(2, 2), mouse_down_count=4),
    )
    assert_pointer_transition(viewer, events, count, before, "keyboard")
    assert_true(position_callbacks_committed)
    assert_true(selection_callbacks_committed)
  })
}

///|
test "selection-listener reentrancy preserves adjacent cursor event pairs" {
  with_test_viewer("abcdef", viewer => {
    let order : Array[String] = []
    let mut reentered = false
    viewer.on_did_change_cursor_position(event => {
      order.push("position:\{event.position.column}")
    })
    |> ignore
    viewer.on_did_change_cursor_selection(event => {
      order.push("selection:\{event.selection.get_position().column}")
      if !reentered {
        reentered = true
        viewer.set_position(Position(1, 5))
      }
    })
    |> ignore
    viewer.set_position(Position(1, 3))
    assert_true(
      order == ["position:3", "selection:3", "position:5", "selection:5"],
    )
    assert_position(viewer.get_position().unwrap(), Position(1, 5))
  })
}
