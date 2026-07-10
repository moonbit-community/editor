// The anchor-candidate pass and anchor semantics of
// `contentHoverWidgetWrapper._findHoverAnchorCandidates` /
// `hoverTypes.ts`'s `equals` / `canAdoptVisibleHover`, plus the marker
// participant's anchor-line column filter
// (`contentHoverComputer._getLineDecorations`). One case per
// behavior-switching branch.

///|
fn range_anchor(
  line : Int,
  start_column : Int,
  end_column : Int,
) -> HoverAnchor {
  HoverRangeAnchor(
    priority=0,
    range=Range(line, start_column, line, end_column),
    initial_mouse_pos_x=None,
    initial_mouse_pos_y=None,
  )
}

///|
fn foreign_anchor(
  injected_text_index : Int,
  supports_marker_hover? : Bool = true,
) -> HoverAnchor {
  HoverForeignElementAnchor(
    priority=10,
    injected_text_index~,
    range=Range(1, 5, 1, 5),
    initial_mouse_pos_x=None,
    initial_mouse_pos_y=None,
    supports_marker_hover~,
  )
}

///|
test "anchor equals: range anchors compare ranges, foreign anchors compare owners only" {
  assert_true(hover_anchor_equals(range_anchor(1, 4, 4), range_anchor(1, 4, 4)))
  assert_false(
    hover_anchor_equals(range_anchor(1, 4, 4), range_anchor(1, 5, 5)),
  )
  assert_false(hover_anchor_equals(range_anchor(1, 4, 4), foreign_anchor(0)))
  // The single foreign owner (the inlay participant) makes any two foreign
  // anchors equal — the source's inherited owner-only comparison.
  assert_true(hover_anchor_equals(foreign_anchor(0), foreign_anchor(3)))
  assert_false(hover_anchor_equals(foreign_anchor(0), range_anchor(1, 4, 4)))
}

///|
test "anchor canAdoptVisibleHover is type-gated" {
  // Range adopts range on the same line only.
  assert_true(
    hover_anchor_can_adopt(range_anchor(1, 9, 9), range_anchor(1, 4, 4)),
  )
  assert_false(
    hover_anchor_can_adopt(range_anchor(2, 4, 4), range_anchor(1, 4, 4)),
  )
  assert_false(hover_anchor_can_adopt(range_anchor(1, 4, 4), foreign_anchor(0)))
  // Foreign adopts foreign (same owner).
  assert_true(hover_anchor_can_adopt(foreign_anchor(1), foreign_anchor(0)))
  assert_false(hover_anchor_can_adopt(foreign_anchor(1), range_anchor(1, 4, 4)))
}

///|
test "hover parts are valid only for range anchors that their columns contain" {
  let part = MarkdownHover(
    range=Range(1, 4, 1, 8),
    contents=[PlainText("x")],
    ordinal=100,
  )
  assert_true(hover_part_valid_for_anchor(part, range_anchor(1, 5, 5)))
  assert_false(hover_part_valid_for_anchor(part, range_anchor(1, 9, 9)))
  // A foreign anchor invalidates range parts (`anchor.type === Range` gate).
  assert_false(hover_part_valid_for_anchor(part, foreign_anchor(0)))
}

///|
fn anchor_test_model() -> @model.TextModel {
  TextModel(
    try! @base_common.Uri::from(
      scheme="inmemory",
      authority="model",
      path="/anchor-test.mbt",
    ),
    "anchor-test.mbt",
    "moonbit",
    1,
    "rev-1",
    "fn main {\n  value\n}\n",
  )
}

///|
test "marker participant filters by anchor-line columns with the showIfCollapsed relaxation" {
  let markers = @markers.MarkerService::new()
  let marker_decorations = @markers.MarkerDecorationsService::new(markers)
  let model = anchor_test_model()
  marker_decorations.on_model_added(model)
  markers.set_diagnostics("diagnostics:0", model.uri, [
    {
      range: Range(2, 3, 2, 8),
      severity: Warning,
      message: "marker",
      tags: None,
    },
  ])
  let participant = MarkerHoverParticipant::new(marker_decorations)
  let compute = (anchor : HoverAnchor) => {
    participant.compute_sync({ model, anchor, inlay_hints: [] })
  }
  // A position inside the marker span hits; the part range clamps to the
  // anchor line's marker columns.
  match compute(range_anchor(2, 5, 5)).get(0) {
    Some(MarkerHover(range~, ..)) => assert_true(range == Range(2, 3, 2, 8))
    _ => fail("expected a marker hover part")
  }
  // The ±1 relaxation: one column past either edge still hits …
  assert_eq(compute(range_anchor(2, 2, 2)).length(), 1)
  assert_eq(compute(range_anchor(2, 9, 9)).length(), 1)
  // … two columns past does not, and neither does another line.
  assert_eq(compute(range_anchor(2, 1, 1)).length(), 0)
  assert_eq(compute(range_anchor(2, 10, 10)).length(), 0)
  assert_eq(compute(range_anchor(1, 5, 5)).length(), 0)
  // A foreign anchor computes markers only when it supports them.
  assert_eq(
    compute(
      HoverForeignElementAnchor(
        priority=10,
        injected_text_index=0,
        range=Range(2, 5, 2, 5),
        initial_mouse_pos_x=None,
        initial_mouse_pos_y=None,
        supports_marker_hover=true,
      ),
    ).length(),
    1,
  )
  assert_eq(
    compute(
      HoverForeignElementAnchor(
        priority=10,
        injected_text_index=0,
        range=Range(2, 5, 2, 5),
        initial_mouse_pos_x=None,
        initial_mouse_pos_y=None,
        supports_marker_hover=false,
      ),
    ).length(),
    0,
  )
}

///|
test "marker participant isolates distinct live models sharing one URI" {
  let uri = try! @base_common.Uri::from(
    scheme="file",
    authority="model",
    path="/same-uri-hover.mbt",
  )
  let model_a : @model.TextModel = TextModel(
    uri, "a.mbt", "moonbit", 1, "a", "alpha",
  )
  let model_b : @model.TextModel = TextModel(
    uri, "b.mbt", "moonbit", 1, "b", "x yz",
  )
  let markers = @markers.MarkerService::new()
  // The same raw empty range expands against each model's own word facts:
  // A -> [1,6), B -> [3,5). A URI-union hover lookup would therefore leak
  // A's marker into B at column 1.
  markers.set_diagnostics("host", uri, [
    {
      range: Range(1, 3, 1, 3),
      severity: Error,
      message: "same URI",
      tags: None,
    },
  ])
  let marker_decorations = @markers.MarkerDecorationsService::new(markers)
  let lease_a = marker_decorations.acquire_model(model_a)
  let lease_b = marker_decorations.acquire_model(model_b)
  let participant = MarkerHoverParticipant::new(marker_decorations)

  let compute = (model : @model.TextModel, column : Int) => {
    participant.compute_sync({
      model,
      anchor: range_anchor(1, column, column),
      inlay_hints: [],
    })
  }
  assert_eq(compute(model_a, 1).length(), 1)
  assert_eq(compute(model_b, 1).length(), 0)
  assert_eq(compute(model_b, 3).length(), 1)

  lease_b.dispose()
  lease_a.dispose()
  marker_decorations.dispose()
}
