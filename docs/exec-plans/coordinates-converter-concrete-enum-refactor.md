# Coordinates Converter Concrete-Enum Refactor

Status: implemented — concrete enum migration, branch-matrix tests, generated
interfaces, and all repository gates complete

Date: 2026-07-13

Oracle commit: `b18492a288de038fbc7643aae6de8247029d11bd`

## Scope (Phase 0)

This is a representation-only refactor of the currently ported coordinate
converter surface. Replace the open
`viewer/common/core.CoordinatesConverter` trait and the single-purpose
`ProjectedCoordinatesConverter` wrapper with one closed concrete
`viewer/common/view_model.CoordinatesConverter` enum. Its initial closed set is:

```mbt nocheck
pub enum CoordinatesConverter {
  Projected(ViewModelLinesFromProjectedModel)
}
```

The enum owns inherent methods for the five operations the current viewer
exposes. Future large-file parity can add `Identity(TextModel)` without changing
the type consumed by `ViewModel`, browser input conversion, cursor closure
construction, or decorations.

Complete upstream units inventoried here:

- `vscode/src/vs/editor/common/coordinatesConverter.ts` — complete file:
  `ICoordinatesConverter` and `IdentityCoordinatesConverter`.
- `vscode/src/vs/editor/common/viewModel/viewModelLines.ts:1073-1119` — complete
  projected `CoordinatesConverter` class.

Complete local method cluster to be rewritten:

- `viewer/common/core/coordinates_converter.mbt` — complete trait.
- `viewer/common/view_model/view_model_lines_projected.mbt:870-951` — complete
  `ProjectedCoordinatesConverter` wrapper and core-trait implementation.
- `viewer/common/view_model/view_model_decorations.mbt:59-78` — complete adapter
  to the separate inline-decorations seam.
- `viewer/browser/view/view_user_input_events.mbt:13-126` — complete two-method
  mouse-target conversion cluster.

Explicitly out of scope for this representation milestone:

- adding `ViewModelLinesFromModelAsIs` or the `Identity` enum variant;
- wiring the large-file constructor branch;
- adding the four currently absent converter operations
  (`validateViewPosition`, `validateViewRange`,
  `getModelLineViewLineCount`, `getViewLineNumberOfModelPosition`);
- widening the enum's model-to-view method with the source's
  `allowZeroLineNumber` / `belowHiddenRanges` options (the projected collection
  retains those existing lower-level operations);
- changing coordinate arithmetic, affinity defaults, hidden-range behavior,
  cursor behavior, mouse-target reconstruction, or public `Viewer` behavior;
- changing `viewer/common/inline_decorations.CoordinatesConverter`, which has
  both the production adapter and a conformance-test identity implementation.

## Inventory (Phase 1)

### Upstream members

`ICoordinatesConverter` has 9 members:

1. `convertViewPositionToModelPosition`
2. `convertViewRangeToModelRange`
3. `validateViewPosition`
4. `validateViewRange`
5. `convertModelPositionToViewPosition`
6. `convertModelRangeToViewRange`
7. `modelPositionIsVisible`
8. `getModelLineViewLineCount`
9. `getViewLineNumberOfModelPosition`

`IdentityCoordinatesConverter` has 13 constructor/method members:

1. constructor
2. `_validPosition`
3. `_validRange`
4. `convertViewPositionToModelPosition`
5. `convertViewRangeToModelRange`
6. `validateViewPosition`
7. `validateViewRange`
8. `convertModelPositionToViewPosition`
9. `convertModelRangeToViewRange`
10. `modelPositionIsVisible`
11. `modelRangeIsVisible` (an identity-class member outside the interface)
12. `getModelLineViewLineCount`
13. `getViewLineNumberOfModelPosition`

The projected `CoordinatesConverter` class has 10 constructor/method members:

1. constructor
2. `convertViewPositionToModelPosition`
3. `convertViewRangeToModelRange`
4. `validateViewPosition`
5. `validateViewRange`
6. `convertModelPositionToViewPosition`
7. `convertModelRangeToViewRange`
8. `modelPositionIsVisible`
9. `getModelLineViewLineCount`
10. `getViewLineNumberOfModelPosition`

Total upstream member denominator: **32**.

### Branches, constants, and owned presentation

- `convertModelPositionToViewPosition` carries three behavior switches:
  optional affinity, zero-line allowance, and below-hidden-range selection.
- Identity position visibility returns `false` for line numbers below 1 or
  above the model line count.
- Identity range visibility independently rejects an invalid start or end line.
- Identity conversion validates positions/ranges through the model; it is not a
  raw unchecked pass-through.
- Projected conversion delegates to the projected line collection without
  reordering calls or adding branches.
- There are no constants, magic timing/geometry numbers, DOM nodes, CSS classes,
  attributes, or properties in scope.

### Local dependency and API inventory

- `viewer/common/core` imports `viewer/common/model` only for the trait's
  `PositionAffinity`; deleting the trait removes that package edge.
- `viewer/common/view_model` already owns the projected line collection and
  imports `core` for `Selection`; moving converter dispatch here adds no cycle.
- `viewer/browser/view` already imports `viewer/common/view_model`, so its
  mouse-target helper can take the concrete enum without a new edge.
- `viewer/common/cursor.CursorContext` already stores three typed closures and
  neither imports nor retains the converter trait.
- There is one production core-trait implementation and no core-trait object.
  The only generic core-trait consumer is the browser mouse-target helper and
  its private view-zone helper.
- `ProjectedCoordinatesConverter` appears in 27 product/generated-interface
  references; method call sites can retain their current names after the enum
  becomes the returned concrete type.
- Generated API changes are intentional: remove the trait from
  `viewer/common/core/pkg.generated.mbti`, remove
  `ProjectedCoordinatesConverter`, add the concrete `CoordinatesConverter` to
  `viewer/common/view_model/pkg.generated.mbti`, and make the browser helper
  take that concrete type.

Review gate: **stop here before editing product code.**

## Parity Ledger (Phase 2)

| ID | Source member | Arithmetic/transition | Proposed MoonBit disposition | Status |
|---|---|---|---|---|
| ICC-001 | interface `convertViewPositionToModelPosition` (`coordinatesConverter.ts:12`) | View position to model position | `CoordinatesConverter::view_position_to_model_position` enum match | TESTED |
| ICC-002 | interface `convertViewRangeToModelRange` (`:13`) | View range to model range | `CoordinatesConverter::view_range_to_model_range` enum match | TESTED |
| ICC-003 | interface `validateViewPosition` (`:14`) | Validate supplied view/model pair | No current local surface | DEFERRED (cursor dual-side validation seam remains absent) |
| ICC-004 | interface `validateViewRange` (`:15`) | Validate supplied view/model ranges | No current local surface | DEFERRED (cursor dual-side validation seam remains absent) |
| ICC-005 | interface `convertModelPositionToViewPosition` (`:22`) | Affinity plus zero/below-hidden switches | Preserve current affinity-only enum method; lower collection keeps the other switches | DEFERRED (full converter signature is outside this representation refactor) |
| ICC-006 | interface `convertModelRangeToViewRange` (`:26`) | Range conversion; affinity affects empty ranges | `CoordinatesConverter::model_range_to_view_range` enum match | TESTED |
| ICC-007 | interface `modelPositionIsVisible` (`:27`) | Bounds/projection visibility | `CoordinatesConverter::model_position_is_visible` enum match | TESTED |
| ICC-008 | interface `getModelLineViewLineCount` (`:28`) | Model-line projection count | No current converter surface | DEFERRED (complete converter surface not in this refactor) |
| ICC-009 | interface `getViewLineNumberOfModelPosition` (`:29`) | Model position to containing view line | No current converter surface | DEFERRED (complete converter surface not in this refactor) |
| IDC-001 | identity constructor (`:36-38`) | Retain model | Future `Identity(TextModel)` variant | DEFERRED (large-file as-is collection parity) |
| IDC-002 | identity `_validPosition` (`:40-42`) | Model position validation | Future identity arm | DEFERRED (large-file as-is collection parity) |
| IDC-003 | identity `_validRange` (`:44-46`) | Model range validation | Future identity arm | DEFERRED (large-file as-is collection parity) |
| IDC-004 | identity `convertViewPositionToModelPosition` (`:50-52`) | Validate view position as model position | Future identity arm | DEFERRED (large-file as-is collection parity) |
| IDC-005 | identity `convertViewRangeToModelRange` (`:54-56`) | Validate view range as model range | Future identity arm | DEFERRED (large-file as-is collection parity) |
| IDC-006 | identity `validateViewPosition` (`:58-60`) | Ignore supplied view; validate expected model | Future identity arm | DEFERRED (large-file as-is collection parity) |
| IDC-007 | identity `validateViewRange` (`:62-64`) | Ignore supplied view; validate expected model | Future identity arm | DEFERRED (large-file as-is collection parity) |
| IDC-008 | identity `convertModelPositionToViewPosition` (`:68-70`) | Validate model position | Future identity arm | DEFERRED (large-file as-is collection parity) |
| IDC-009 | identity `convertModelRangeToViewRange` (`:72-74`) | Validate model range | Future identity arm | DEFERRED (large-file as-is collection parity) |
| IDC-010 | identity `modelPositionIsVisible` (`:76-83`) | Reject line outside `[1, lineCount]` | Future identity arm | DEFERRED (large-file as-is collection parity) |
| IDC-011 | identity `modelRangeIsVisible` (`:85-96`) | Reject invalid start, then invalid end | Future identity helper if consumed | DEFERRED (large-file as-is collection parity) |
| IDC-012 | identity `getModelLineViewLineCount` (`:98-100`) | Constant 1 | Future identity arm | DEFERRED (large-file as-is collection parity) |
| IDC-013 | identity `getViewLineNumberOfModelPosition` (`:102-104`) | Return model line | Future identity arm | DEFERRED (large-file as-is collection parity) |
| PCC-001 | projected constructor (`viewModelLines.ts:1076-1078`) | Retain projected lines | `Projected(lines)` enum construction | TESTED |
| PCC-002 | projected `convertViewPositionToModelPosition` (`:1082-1084`) | Delegate line/column | Projected arm of view-position method | TESTED |
| PCC-003 | projected `convertViewRangeToModelRange` (`:1086-1088`) | Delegate range | Projected arm of view-range method | TESTED |
| PCC-004 | projected `validateViewPosition` (`:1090-1092`) | Delegate view line/column plus expected model position | No current local surface | DEFERRED (cursor dual-side validation seam remains absent) |
| PCC-005 | projected `validateViewRange` (`:1094-1096`) | Delegate view and expected model ranges | No current local surface | DEFERRED (cursor dual-side validation seam remains absent) |
| PCC-006 | projected `convertModelPositionToViewPosition` (`:1100-1102`) | Delegate position and three switches | Preserve current affinity-only enum arm | DEFERRED (full converter signature is outside this representation refactor) |
| PCC-007 | projected `convertModelRangeToViewRange` (`:1104-1106`) | Delegate range and affinity | Projected arm of model-range method | TESTED |
| PCC-008 | projected `modelPositionIsVisible` (`:1108-1110`) | Delegate line/column visibility | Projected arm of visibility method | TESTED |
| PCC-009 | projected `getModelLineViewLineCount` (`:1112-1114`) | Delegate model-line count | No current converter surface | DEFERRED (complete converter surface not in this refactor) |
| PCC-010 | projected `getViewLineNumberOfModelPosition` (`:1116-1118`) | Delegate model line/column | No current converter surface | DEFERRED (complete converter surface not in this refactor) |

Ledger total: **32 rows = 32 inventoried members**. Final status:
`TESTED / DEFERRED / N-A = 9 / 23 / 0`.

## Implementation

1. Add a focused `viewer/common/view_model/coordinates_converter.mbt` owning the
   public closed enum and its five inherent methods.
2. Make `ViewModelLinesFromProjectedModel::create_coordinates_converter`
   construct `Projected(self)` and return the enum.
3. Change `ViewModel`, `ViewModelDecorations`, cursor-context construction, and
   the inline-decorations adapter to consume the enum.
4. Change the browser mouse-target conversion cluster from a generic core-trait
   parameter to `@view_model.CoordinatesConverter`.
5. Delete `viewer/common/core/coordinates_converter.mbt` and remove the now
   unused `viewer/common/model` import from `viewer/common/core/moon.pkg`.
6. Remove `ProjectedCoordinatesConverter`; do not keep a compatibility alias or
   a one-variant wrapper around the enum.
7. Update current package documentation and generated interfaces; do not edit
   historical implemented plans.

Implementation milestone: `4340d29` (`refactor(view-model): close coordinates
converter representation`).

## Deviations (Phase 3)

- Monaco uses an open TypeScript interface because normal and large-file line
  collections provide different implementations. The current MoonBit product
  owns a closed set and has only the projected collection, so a closed enum is
  the explicit representation seam. Adding the already-reserved large-file
  path extends the enum with `Identity`; it does not change consumers.
- Method names keep the current MoonBit-owned omission of Monaco's `convert`
  prefix. This refactor does not widen the naming scope.
- All source members marked `DEFERRED` above remain existing parity gaps; the
  representation refactor must not silently claim them.

## Test Matrix (Phase 4)

- No-wrap `ModelLineProjection::Identity`: existing model/view position and
  range round trips.
- Projected soft wrap: continuation boundaries and round trips.
- Injected text: left/right affinity at injected boundaries.
- Hidden areas: visibility, above/below hidden mapping, and zero-line behavior
  through the existing lower-level/ViewModel APIs.
- Cursor closure bridge: model/view conversion after wrapping and hidden-area
  remapping.
- Browser input boundary: every mouse-target arm, including view-zone detail.
- Decoration adapter: model-position and model-range conversion through the
  unchanged inline-decorations trait.

Evidence:

- `viewer/common/view_model/view_model_test.mbt` proves the closed `Projected`
  construction and no-wrap/wrapped position and range conversions.
- `viewer/common/view_model/position_affinity_test.mbt` covers injected-text
  and wrap-boundary affinity, including empty-range behavior.
- `viewer/common/view_model/hidden_areas_test.mbt` covers visibility and the
  existing lower-level zero-line/below-hidden switches.
- Existing cursor movement/flush tests exercise the typed-closure bridge after
  wrapping, hidden-area changes, and model flushes.
- `viewer/browser/view/view_user_input_events_wbtest.mbt` drives all nine
  mouse-target variants, optional unknown coordinates, and both optional
  view-zone positions through a wrapped converter.
- Existing view-model decoration tests exercise the unchanged generic
  inline-decorations adapter with the concrete enum.

Required validation after implementation:

```sh
moon check --target all
moon test --target all viewer/common/view_model
moon test --target js viewer
moon fmt
moon info
just check
just test
just build
just test-browser
```

Validation evidence on 2026-07-13:

- `moon check --target all --warn-list +73` passed with the three pre-existing
  unused-field warnings in `viewer/browser/view/rendering_context.mbt` and no
  new warnings.
- The plan's package-specific `moon test --target all
  viewer/common/view_model` spelling is not supported because this package
  declares only the `js` and `native` targets. The equivalent supported matrix
  passed as `169/169` on each target.
- `moon test --target js viewer` passed `186/186`.
- `moon fmt` and `moon info` completed; the generated APIs contain the concrete
  enum and no core converter trait or projected wrapper.
- `just check`, `just test` (`1387/1387` JS, `989/989` native), `just build`,
  and `just test-browser` (`82/82`) all passed.

## Exit Gate (Phase 5)

- [x] inventory count equals ledger-row count: 32 == 32
- [x] all 9 representation TODO rows and all five current enum methods are
      implemented and tested
- [x] generated API contains concrete `view_model.CoordinatesConverter` and no
      core converter trait or projected wrapper
- [x] every ported method is reread side by side with the pinned source
- [x] behavior matrix is green across common, root viewer, and browser layers
- [x] all representation deviations remain explicit
- [x] closing reread of both complete upstream source units finds no
      unaccounted member

Closing reconciliation: the complete
`editor/common/coordinatesConverter.ts` file and projected
`viewModelLines.ts:1073-1119` class were reread at oracle commit
`b18492a288de038fbc7643aae6de8247029d11bd`. All 32 inventoried members remain
represented by exactly one ledger row; the nine representation rows are
tested, and the other 23 retain their explicit large-file or absent-surface
deferral reasons. The five shipped enum methods preserve the projected
delegation order and existing affinity/visibility surface without additional
branches or arithmetic.
