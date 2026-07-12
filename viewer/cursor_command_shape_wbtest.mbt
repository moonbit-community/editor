///|
test "partial core command args fall back to empty and return before mutation" {
  with_test_viewer("alpha\nbeta", viewer => {
    let view_model = viewer.test_view_model()
    let before = view_model.cursor.get_primary_cursor_state()
    let mut events = 0
    viewer.on_did_change_cursor_selection(_ => events += 1) |> ignore

    assert_false(viewer.run_move_to_core_command(view_model, None, false))
    assert_false(viewer.run_word_core_command(view_model, None, false))
    assert_false(viewer.run_line_core_command(view_model, None, false))
    assert_false(viewer.run_set_selection_core_command(None))
    assert_true(view_model.cursor.get_primary_cursor_state() == before)
    assert_eq(events, 0)
  })
}

///|
test "move core command accepts absent and supplied view positions" {
  let options = ViewerOptions(soft_wrap=true)
  with_test_viewer(
    "abcdefghij",
    viewer => {
      viewer.test_set_soft_wrap_column(5)
      let view_model = viewer.test_view_model()
      assert_true(
        viewer.run_move_to_core_command(
          view_model,
          Some(
            CursorMoveCommandArgs::new(
              source="mouse",
              position=Position(1, 6),
              reveal_type=None,
            ),
          ),
          false,
        ),
      )
      assert_position(viewer.get_position().unwrap(), Position(1, 6))
      assert_position(view_model.cursor.view_state().position, Position(2, 1))

      assert_true(
        viewer.run_move_to_core_command(
          view_model,
          Some(
            CursorMoveCommandArgs::new(
              source="mouse",
              position=Position(1, 6),
              view_position=Position(1, 6),
              reveal_type=None,
            ),
          ),
          false,
        ),
      )
      assert_position(view_model.cursor.view_state().position, Position(1, 6))
    },
    options~,
  )
}

///|
test "omitted move command reveal type follows undefined non-None gate" {
  with_test_viewer(long_document(40), viewer => {
    viewer.test_set_viewport(width=800.0, height=180.0)
    let view_model = viewer.test_view_model()

    assert_true(
      viewer.run_move_to_core_command(
        view_model,
        Some(CursorMoveCommandArgs::new(position=Position(30, 1))),
        false,
      ),
    )
    assert_true(view_model.view_layout.position().scroll_top > 0.0)
    assert_true(viewer.horizontal_reveal_request is Some(_))

    reset_cursor_mouse_reveal(viewer)
    viewer.run_word_core_command(
      view_model,
      Some(CursorMoveCommandArgs::new(position=Position(30, 3))),
      false,
    )
    |> ignore
    assert_true(view_model.view_layout.position().scroll_top > 0.0)
    assert_true(viewer.horizontal_reveal_request is Some(_))

    reset_cursor_mouse_reveal(viewer)
    viewer.run_line_core_command(
      view_model,
      Some(CursorMoveCommandArgs::new(position=Position(30, 3))),
      false,
    )
    |> ignore
    assert_true(view_model.view_layout.position().scroll_top > 0.0)
    assert_true(viewer.horizontal_reveal_request is None)
  })
}

///|
test "view controller selection adapters preserve exact keyboard and mouse sources" {
  with_test_viewer("alpha\nbeta", viewer => {
    let sources : Array[String] = []
    let reasons : Array[CursorChangeReason] = []
    viewer.on_did_change_cursor_selection(event => {
      sources.push(event.source)
      reasons.push(event.reason)
    })
    |> ignore

    assert_true(
      viewer.set_selection_from_view_controller(
        @core.Selection::new(Position(1, 2), Position(1, 4)),
      ),
    )
    assert_true(
      viewer.select_from_view_controller(
        @core.Selection::new(Position(2, 1), Position(2, 3)),
      ),
    )
    assert_true(sources == ["keyboard", "mouse"])
    assert_true(reasons == [Explicit, Explicit])
  })
}

///|
test "selectAll returns without a view and hard-codes keyboard source" {
  let detached = Viewer::Viewer()
  assert_false(detached.run_select_all_core_command())
  detached.dispose()

  with_test_viewer("a\nbb", viewer => {
    let sources : Array[String] = []
    viewer.on_did_change_cursor_selection(event => sources.push(event.source))
    |> ignore
    assert_true(viewer.run_select_all_core_command(nominal_source="mouse"))
    assert_selection_eq(
      viewer.get_selection().unwrap(),
      @core.Selection::new(Position(1, 1), Position(2, 3)),
    )
    assert_true(sources == ["keyboard"])
  })
}
