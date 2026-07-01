///| Faithful conformance port of vscode's `modelDecorations.test.ts` (pinned
/// `vscode/` submodule, commit 294fb350).
///
/// Readonly-subset triage of the file's 100 cases. The file is built end-to-end
/// on Monaco's mutable, id-based, edit-tracking decoration model
/// (`deltaDecorations` → ids, `changeDecorations`/`addDecoration`/
/// `removeDecoration`/`changeDecoration`, `getDecorationRange(id)`,
/// `getDecorationOptions(id)`, stickiness, `onDidChangeDecorations`), so 95 of
/// 100 are blocked on the interval-tree decoration-storage follow-up. The 5
/// pure-query cases map to the viewer's immutable `DecorationSet` seam and are
/// ported here — a documented adaptation (Monaco's id-model → `DecorationSet`):
/// `addDecoration`/`deltaDecorations` become `DecorationSet::from_array`,
/// `getLineDecorations(n)` becomes `between(Range(n,1,n,BIG))`, and
/// `getDecorationsInRange` becomes `between`. (Monaco's `getLineDecorations`
/// returns each decoration with its full, unclipped range — matching `between`.)
/// `DecorationKind` is irrelevant to these query assertions, so a placeholder
/// `Diagnostic` is used; only `class_name` (Monaco's `options.className`) and the
/// range are asserted.
///
/// DEFERRED (in scope, blocked on the interval-tree decoration-storage
/// follow-up — see Deferred): the other 95 cases —
///   - `Editor Model - Model Decorations` (24): `decoration gets removed`,
///     `decorations get removed`, `decoration range can be changed`, the three
///     `decorations emit event on add/change/remove`, `decorations emit event
///     when inserting one line text before it`, `decorations do not emit event
///     on no-op deltaDecorations`, the ~17 `decorations are updated when
///     inserting/deleting ... ` + `decorations are updated when changing EOL`,
///     `an apparently simple edit`, and the two `removeAllDecorationsWithOwnerId`
///     cases.
///   - `Decorations and editing` (62): the full insert/delete/replace ×
///     collapsed/non-collapsed × edit-vs-range matrix (all `applyEdits` range
///     tracking + stickiness).
///   - `deltaDecorations` (9): `result respects input`, `deltaDecorations 1/2/3`,
///     `issue #4317`, `model doesn't get confused with individual tracked
///     ranges`, `issue #41492` (the id-diff API, stickiness, and edit tracking).

///|
fn dec(
  sl : Int,
  sc : Int,
  el : Int,
  ec : Int,
  name : String,
) -> @model.Decoration {
  Decoration(Range(sl, sc, el, ec), Diagnostic, name)
}

///|
/// Monaco's `getLineDecorations(line)` adapted to the immutable set: every
/// decoration intersecting the whole line, with its original (unclipped) range.
fn line_decorations(
  set : @model.DecorationSet,
  line : Int,
) -> Array[@model.Decoration] {
  set.between(Range(line, 1, line, 1000000))
}

///|
test "single character decoration" {
  let set = DecorationSet::from_array([dec(1, 1, 1, 2, "myType")])
  let l1 = line_decorations(set, 1)
  assert_eq(l1.length(), 1)
  assert_eq(l1[0].range.start_column, 1)
  assert_eq(l1[0].range.end_column, 2)
  assert_eq(l1[0].class_name, "myType")
  assert_eq(line_decorations(set, 2).length(), 0)
  assert_eq(line_decorations(set, 3).length(), 0)
  assert_eq(line_decorations(set, 4).length(), 0)
  assert_eq(line_decorations(set, 5).length(), 0)
}

///|
test "line decoration" {
  let set = DecorationSet::from_array([dec(1, 1, 1, 14, "myType")])
  let l1 = line_decorations(set, 1)
  assert_eq(l1.length(), 1)
  assert_eq(l1[0].range.start_column, 1)
  assert_eq(l1[0].range.end_column, 14)
  assert_eq(l1[0].class_name, "myType")
  assert_eq(line_decorations(set, 2).length(), 0)
  assert_eq(line_decorations(set, 3).length(), 0)
  assert_eq(line_decorations(set, 4).length(), 0)
  assert_eq(line_decorations(set, 5).length(), 0)
}

///|
test "full line decoration" {
  let set = DecorationSet::from_array([dec(1, 1, 2, 1, "myType")])
  // Upstream queries getLineDecorations(1) twice (copy-paste); mirrored.
  let line1_decorations = line_decorations(set, 1)
  assert_eq(line1_decorations.length(), 1)
  assert_eq(line1_decorations[0].class_name, "myType")
  let line2_decorations = line_decorations(set, 1)
  assert_eq(line2_decorations.length(), 1)
  assert_eq(line2_decorations[0].class_name, "myType")
  assert_eq(line_decorations(set, 3).length(), 0)
  assert_eq(line_decorations(set, 4).length(), 0)
  assert_eq(line_decorations(set, 5).length(), 0)
}

///|
test "multiple line decoration" {
  let set = DecorationSet::from_array([dec(1, 2, 3, 2, "myType")])
  // Upstream queries getLineDecorations(1) for all three vars (copy-paste);
  // mirrored.
  let line1_decorations = line_decorations(set, 1)
  assert_eq(line1_decorations.length(), 1)
  assert_eq(line1_decorations[0].class_name, "myType")
  let line2_decorations = line_decorations(set, 1)
  assert_eq(line2_decorations.length(), 1)
  assert_eq(line2_decorations[0].class_name, "myType")
  let line3_decorations = line_decorations(set, 1)
  assert_eq(line3_decorations.length(), 1)
  assert_eq(line3_decorations[0].class_name, "myType")
  assert_eq(line_decorations(set, 4).length(), 0)
  assert_eq(line_decorations(set, 5).length(), 0)
}

///|
test "issue #16922: Clicking on link doesn't seem to do anything" {
  let set = DecorationSet::from_array([
    dec(1, 1, 1, 1, "1"),
    dec(1, 13, 1, 13, "2"),
    dec(2, 1, 2, 1, "3"),
    dec(2, 1, 2, 4, "4"),
    dec(2, 8, 2, 13, "5"),
    dec(3, 1, 4, 6, "6"),
    dec(1, 1, 3, 6, "x1"),
    dec(2, 5, 2, 8, "x2"),
    dec(1, 1, 2, 8, "x3"),
    dec(2, 5, 3, 1, "x4"),
  ])
  let in_range = set.between(Range(2, 6, 2, 6))
  let names = in_range.map(fn(d) { d.class_name })
  names.sort()
  assert_eq(names.length(), 4)
  assert_eq(names[0], "x1")
  assert_eq(names[1], "x2")
  assert_eq(names[2], "x3")
  assert_eq(names[3], "x4")
}
