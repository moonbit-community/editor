///| White-box tests for the `setValue` flush lane (`text_model.mbt` setValue
/// region + `text_model_events.mbt`) — the plan's Phase-4 matrix rows local
/// to the model: version ids, whole-buffer equality, decoration
/// destruction, the public payload shape, the two-loop dispatch order, the
/// deferred content emitter, and the disposing guard.

///|
test "set_value bumps the version id and swaps the snapshot" {
  let model = wb_model("alpha\nbravo")
  assert_eq(model.get_version_id(), 1)
  model.set_value("x\ny\nz")
  assert_eq(model.get_version_id(), 2)
  assert_eq(model.get_value(), "x\ny\nz")
  assert_eq(model.get_line_count(), 3)
  // identical content still flushes (the no-op early return is the host's,
  // per modelService.ts:370-373)
  model.set_value("x\ny\nz")
  assert_eq(model.get_version_id(), 3)
}

///|
test "set_value destroys all decorations; stale ids delta as a no-op" {
  let model = wb_model("alpha\nbravo")
  let ids = model.delta_decorations([], [
    { range: Range(1, 1, 1, 3), options: wb_options("one") },
    { range: Range(2, 1, 2, 4), options: wb_options("two") },
  ])
  assert_eq(model.get_all_decorations().length(), 2)
  model.set_value("alpha\nbravo")
  assert_eq(model.decorations.length(), 0)
  assert_eq(model.get_all_decorations().length(), 0)
  // the destroyed ids are unknown to the fresh storage: removing them is a
  // no-op and re-adding through them seeds fresh nodes
  let replaced = model.delta_decorations(ids, [
    { range: Range(1, 1, 1, 2), options: wb_options("three") },
  ])
  assert_eq(replaced.length(), 1)
  assert_eq(model.get_all_decorations().length(), 1)
}

///|
test "set_value emits one full-range public change with isFlush" {
  let model = wb_model("alpha\nbravo")
  let events : Array[ModelContentChangedEvent] = []
  let _sub = model.on_did_change_content(e => events.push(e))
  model.set_value("x\ny\nz")
  assert_eq(events.length(), 1)
  let e = events[0]
  assert_eq(e.is_flush, true)
  assert_eq(e.is_eol_change, false)
  assert_eq(e.is_undoing, false)
  assert_eq(e.is_redoing, false)
  assert_eq(e.version_id, 2)
  assert_eq(e.eol, "\n")
  assert_eq(e.changes.length(), 1)
  let change = e.changes[0]
  // the replaced range is the OLD full model range and length
  assert_true(change.range == Range(1, 1, 2, 6))
  assert_eq(change.range_offset, 0)
  assert_eq(change.range_length, "alpha\nbravo".length())
  // the text is the NEW full value (read after the buffer swap)
  assert_eq(change.text, "x\ny\nz")
}

///|
test "set_value re-seeds tokenization before view models and listeners" {
  let model = wb_model("alpha\nbravo")
  model.tokenization.force_tokenization()
  assert_eq(model.tokenization.has_tokens(), true)
  let to_lines : Array[Int] = []
  let _sub = model.on_did_change_tokens(e => {
    to_lines.push(e.ranges[0].to_line_number)
  })
  model.set_value("one\ntwo\nthree")
  // reset_tokenization fired over the NEW line count: the part's frozen
  // lines were replaced before the reset announced the change
  assert_true(to_lines == [3])
  assert_eq(model.tokenization.has_tokens(), false)
  model.tokenization.force_tokenization()
  assert_eq(model.tokenization.has_tokens(), true)
}

///|
test "no content event is emitted while disposing" {
  let model = wb_model("alpha")
  let mut content_events = 0
  let _sub = model.on_did_change_content(_ => {
    content_events = content_events + 1
  })
  let _will = model.on_will_dispose(() => model.set_value("ghost"))
  model.dispose()
  // the swap and version bump still happened; only the events are
  // suppressed (`textModel.ts:468-471`)
  assert_eq(content_events, 0)
  assert_eq(model.get_value(), "ghost")
  assert_eq(model.get_version_id(), 2)
}

///|
test "equals_text_snapshot is whole-buffer, EOL-sensitive equality" {
  let model = wb_model("alpha\r\nbravo")
  assert_eq(model.equals_text_snapshot(TextSnapshot("alpha\r\nbravo")), true)
  assert_eq(model.equals_text_snapshot(TextSnapshot("alpha\nbravo")), false)
  model.set_value("x")
  assert_eq(model.equals_text_snapshot(TextSnapshot("x")), true)
  assert_eq(TextSnapshot("a").equals(TextSnapshot("a")), true)
  assert_eq(TextSnapshot("a").equals(TextSnapshot("b")), false)
}

///|
test "DidChangeContentEmitter merges flushes inside a deferred bracket" {
  let model = wb_model("a")
  let events : Array[ModelContentChangedEvent] = []
  let _sub = model.on_did_change_content(e => events.push(e))
  model.event_emitter.begin_deferred_emit()
  model.set_value("b")
  model.set_value("c\nd")
  assert_eq(events.length(), 0)
  model.event_emitter.end_deferred_emit()
  assert_eq(events.length(), 1)
  let e = events[0]
  // merged: both changes, the LAST version id, isFlush sticky-true
  assert_eq(e.changes.length(), 2)
  assert_eq(e.version_id, 3)
  assert_eq(e.is_flush, true)
  assert_eq(e.changes[1].text, "c\nd")
}

///|
/// A recording stub of the registered-view-model seam for the two-loop
/// order test (`textModel.ts:1652-1667`).
priv struct RecordingViewModel {
  name : String
  log : Array[String]
}

///|
impl ViewModel for RecordingViewModel with fn on_did_change_content_or_injected_text(
  self,
  _e,
) {
  self.log.push(self.name + ":structure")
}

///|
impl ViewModel for RecordingViewModel with fn emit_content_change_event(
  self,
  _e,
) {
  self.log.push(self.name + ":emit")
}

///|
test "two-loop dispatch: every structural update precedes every emit" {
  let log : Array[String] = []
  let model = wb_model("x")
  let boxed_a = ({ name: "a", log } : RecordingViewModel) as &ViewModel
  let boxed_b = ({ name: "b", log } : RecordingViewModel) as &ViewModel
  model.register_view_model(boxed_a)
  model.register_view_model(boxed_b)
  // the public emitter fires only after both loops (`textModel.ts:480-481`)
  let _sub = model.on_did_change_content(_ => log.push("public"))
  model.set_value("y")
  assert_true(
    log == ["a:structure", "b:structure", "a:emit", "b:emit", "public"],
  )
  // unregistering removes exactly the passed box
  model.unregister_view_model(boxed_a)
  log.clear()
  model.set_value("z")
  assert_true(log == ["b:structure", "b:emit", "public"])
}

///|
test "raw change union carries the tier-2 shape (contains_event, merge)" {
  let flush_only : ModelRawContentChangedEvent = {
    changes: [ModelRawFlush],
    version_id: 2,
    is_undoing: false,
    is_redoing: false,
  }
  assert_eq(flush_only.contains_event(Flush), true)
  assert_eq(flush_only.contains_event(LinesInserted), false)
  let inserted : ModelRawContentChangedEvent = {
    changes: [
      ModelRawLinesInserted(
        from_line_number=1,
        from_line_number_post_edit=1,
        count=2,
      ),
    ],
    version_id: 3,
    is_undoing: true,
    is_redoing: false,
  }
  let merged = ModelRawContentChangedEvent::merge(flush_only, inserted)
  assert_eq(merged.changes.length(), 2)
  assert_eq(merged.version_id, 3)
  assert_eq(merged.is_undoing, true)
  assert_eq(merged.is_redoing, false)
  assert_eq(merged.contains_event(Flush), true)
  assert_eq(merged.contains_event(LinesInserted), true)
}
