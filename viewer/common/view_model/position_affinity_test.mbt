// PositionAffinity conformance matrix (deviations-closeout Track B):
// boundary behavior of `translateToOutputPosition`,
// `normalizeOutputPosition`, and `convertModelRangeToViewRange`
// (`modelLineProjectionData.ts:111-192`, `viewModelLines.ts:892-901`) at
// injected-text anchors and soft-wrap breaks.

///|
/// Hints are written as `after` injected-text decorations on a backing
/// model (Track F: injected text lives in decoration storage);
/// `(column, content)` pairs are 1-based hint columns.
fn affinity_view_model(
  text : String,
  hints : Array[(Int, String)],
  soft_wrap_column~ : Int,
) -> @view_model.ViewModel {
  let model = @model.TextModel(
    @base_common.Uri::memory("affinity-test.mbt"),
    "affinity-test.mbt",
    "moonbit",
    1,
    "rev-1",
    text,
  )
  let decorations : Array[@model.DeltaDecoration] = []
  for index in 0..<hints.length() {
    let (column, content) = hints[index]
    decorations.push({
      range: Range(1, column, 1, column),
      options: @model.Decoration(
        "",
        description="inlay-hint",
        show_if_collapsed=true,
        after=@model.ModelInjectedTextOptions(
          content,
          inline_class_name="inlay-hint inlay-hint-type",
          attached_index=index,
        ),
      ),
    })
  }
  model.delta_decorations([], decorations) |> ignore
  let doc = model.snapshot
  let tokenized = @view_model.TokenizedDocument::build(
    doc,
    @syntax.highlight(doc),
  )
  let providers = @language.ProviderResult::{
    hovers: [],
    diagnostics: [],
    definitions: [],
    symbols: [],
  }
  let source = @view_model.FrameSource(tokenized, providers, model~)
  @view_model.ViewModel::with_options(
    source,
    ViewModelOptions(soft_wrap_column~),
  )
}

///|
fn view_of(
  vm : @view_model.ViewModel,
  line : Int,
  column : Int,
  affinity? : @model.PositionAffinity,
) -> String {
  let converter = vm.coordinates_converter()
  let position = converter.model_position_to_view_position(
    Position(line, column),
    affinity?,
  )
  "\{position.line_number}:\{position.column}"
}

///|
fn normalized(
  vm : @view_model.ViewModel,
  line : Int,
  column : Int,
  affinity : @model.PositionAffinity,
) -> String {
  let position = vm.normalize_position(Position(line, column), affinity)
  "\{position.line_number}:\{position.column}"
}

///|
/// Two hints share the anchor at offset 2 of `abcdef` (hint positions are
/// 1-based; `bucket_injected_text` converts), projecting to `abXXYYcdef` —
/// the `Right` walks must cross both touching injections.
fn hinted_view_model() -> @view_model.ViewModel {
  affinity_view_model("abcdef", [(3, "XX"), (3, "YY")], soft_wrap_column=0)
}

///|
test "translate at an inlay-hint anchor: only Right crosses the injections" {
  let vm = hinted_view_model()
  // Model column 3 (offset 2) is the anchor of both hints.
  inspect(view_of(vm, 1, 3), content="1:3")
  inspect(view_of(vm, 1, 3, affinity=Left), content="1:3")
  inspect(view_of(vm, 1, 3, affinity=LeftOfInjectedText), content="1:3")
  inspect(view_of(vm, 1, 3, affinity=RightOfInjectedText), content="1:3")
  inspect(view_of(vm, 1, 3, affinity=Right), content="1:7")
}

///|
test "translate mid-token ignores affinity" {
  let vm = hinted_view_model()
  inspect(view_of(vm, 1, 2), content="1:2")
  inspect(view_of(vm, 1, 2, affinity=Left), content="1:2")
  inspect(view_of(vm, 1, 2, affinity=Right), content="1:2")
  inspect(view_of(vm, 1, 2, affinity=LeftOfInjectedText), content="1:2")
  inspect(view_of(vm, 1, 2, affinity=RightOfInjectedText), content="1:2")
}

///|
test "normalize snaps positions inside injected text per affinity" {
  let vm = hinted_view_model()
  // View column 4 sits strictly inside the first hint (`abXX…`).
  inspect(normalized(vm, 1, 4, None), content="1:3")
  inspect(normalized(vm, 1, 4, Left), content="1:3")
  inspect(normalized(vm, 1, 4, LeftOfInjectedText), content="1:3")
  inspect(normalized(vm, 1, 4, Right), content="1:7")
  inspect(normalized(vm, 1, 4, RightOfInjectedText), content="1:7")
  // View column 5 is the boundary between the two touching hints: a cursor
  // stop for `None` (`InjectedTextCursorStops.Both`), still crossed by
  // Left/Right.
  inspect(normalized(vm, 1, 5, None), content="1:5")
  inspect(normalized(vm, 1, 5, Left), content="1:3")
  inspect(normalized(vm, 1, 5, Right), content="1:7")
  // Mid-token positions never move.
  inspect(normalized(vm, 1, 2, None), content="1:2")
  inspect(normalized(vm, 1, 2, Left), content="1:2")
  inspect(normalized(vm, 1, 2, Right), content="1:2")
}

///|
test "translate at a soft-wrap break: only Left stays on the earlier line" {
  let vm = affinity_view_model("abcdefgh", [], soft_wrap_column=4)
  // Model column 5 (offset 4) is the break between `abcd` and `efgh`.
  inspect(view_of(vm, 1, 5), content="2:1")
  inspect(view_of(vm, 1, 5, affinity=Right), content="2:1")
  inspect(view_of(vm, 1, 5, affinity=LeftOfInjectedText), content="2:1")
  inspect(view_of(vm, 1, 5, affinity=RightOfInjectedText), content="2:1")
  inspect(view_of(vm, 1, 5, affinity=Left), content="1:5")
}

///|
test "normalize snaps wrap boundaries per affinity" {
  let vm = affinity_view_model("abcdefgh", [], soft_wrap_column=4)
  inspect(normalized(vm, 2, 1, Left), content="1:5")
  inspect(normalized(vm, 2, 1, None), content="2:1")
  inspect(normalized(vm, 2, 1, Right), content="2:1")
  inspect(normalized(vm, 1, 5, Right), content="2:1")
  inspect(normalized(vm, 1, 5, None), content="1:5")
  inspect(normalized(vm, 1, 5, Left), content="1:5")
}

///|
test "range conversion: non-empty ranges exclude injected text at the edges" {
  let vm = hinted_view_model()
  let converter = vm.coordinates_converter()
  // Start at the hint anchor converts with `Right` (past both hints), end
  // mid-source with `Left` (`viewModelLines.ts:897-899`).
  let view_range = converter.model_range_to_view_range(Range(1, 3, 1, 7))
  inspect(
    "\{view_range.start_line_number}:\{view_range.start_column}-\{view_range.end_line_number}:\{view_range.end_column}",
    content="1:7-1:11",
  )
}

///|
test "range conversion: empty ranges default to Left at a wrap break" {
  let vm = affinity_view_model("abcdefgh", [], soft_wrap_column=4)
  let converter = vm.coordinates_converter()
  let view_range = converter.model_range_to_view_range(Range(1, 5, 1, 5))
  inspect(
    "\{view_range.start_line_number}:\{view_range.start_column}-\{view_range.end_line_number}:\{view_range.end_column}",
    content="1:5-1:5",
  )
  let right = converter.model_range_to_view_range(
    Range(1, 5, 1, 5),
    affinity=Right,
  )
  inspect(
    "\{right.start_line_number}:\{right.start_column}-\{right.end_line_number}:\{right.end_column}",
    content="2:1-2:1",
  )
}
