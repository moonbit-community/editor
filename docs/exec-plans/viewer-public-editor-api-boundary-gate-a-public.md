# Viewer Public Editor API Boundary — Gate A Public Surface Ledger

Status: approved historical inventory — implementation started 2026-07-14

Date: 2026-07-14

Parent plan: docs/exec-plans/viewer-public-editor-api-boundary.md

Oracle commit: vscode submodule b18492a288de038fbc7643aae6de8247029d11bd

Local baseline: repository HEAD e5beb1c8cd5c9d5b2fbfbfca55025438b17e1ca3

This companion closes only the current root public-surface and caller-evidence
parts of Gate A. It changes no product source, package manifest, or generated
interface. The upstream ledger and dependency/interface snapshots are separate
Gate A companions. At inventory time implementation remained stopped until all
three companions were reviewed together; the user approved them on 2026-07-14.

## Frozen denominator

The source of truth is the checked-in viewer/pkg.generated.mbti at the baseline
above: 280 lines, 14,194 bytes, SHA-256
9c6b4fe4d5d57704db1d0ada58a5401d6ed55fa049b1cb9bf74b3854e62b0d75.

One row is emitted for every top-level public value, public type declaration,
public enum variant, public struct field, public root-package method, and public
type alias. Private fields of opaque structs and comments are not rows. Type
rows reproduce the exact declaration head; member, value, method, and alias
rows reproduce the complete generated signature line.

The closed denominator is 210 unique rows:

| Kind | Rows |
|---|---:|
| top-level value | 4 |
| type declaration | 18 |
| enum variant | 12 |
| public struct field | 77 |
| public method | 97 |
| public alias | 2 |
| total | 210 |

Stable IDs follow generated-interface order. API-Vnnn identifies top-level
values, API-Tnnn identifies types, .Vnn/.Fnn/.Mnn identify their variants,
fields, and methods, and API-Annn identifies aliases. IDs are inventory keys,
not promises to preserve the declarations.

Reproduction:

    BASE=e5beb1c8cd5c9d5b2fbfbfca55025438b17e1ca3
    git show "$BASE:viewer/pkg.generated.mbti" | wc -l
    git show "$BASE:viewer/pkg.generated.mbti" | wc -c
    git show "$BASE:viewer/pkg.generated.mbti" | shasum -a 256
    moon info
    git diff --exit-code -- viewer/pkg.generated.mbti

The inventory count is reproduced mechanically by scanning the generated file
in order: count public values; public enum/struct declarations; every variant
and public field inside pub(all); every pub fn Type::method; and every pub using
alias. The reconciliation commands below independently enforce 210 unique
ledger IDs and one terminal disposition per row.

## Caller-evidence method

Each ledger Evidence cell contains one or more of these non-exclusive codes:

| Code | Caller bucket |
|---|---|
| EXT | external embedding example under internal/shell/examples/embedded_viewer |
| WB | internal shell/workbench under internal/shell/workbench |
| BR | browser scenarios under tests/browser |
| WT | root-package white-box tests, viewer/*_wbtest.mbt or viewer/*_test.mbt |
| ROOT | production caller under viewer; auxiliary evidence kept separate from the four requested consumer buckets |
| NONE | moon ide reports exactly one reference, the definition; no local caller |

The classification uses MoonBit semantic references first. rg is a path-bucket
and spelling cross-check; it does not override semantic identity. For fields
and variants, the loc form anchors the query at the owning source declaration.

    moon ide find-references 'Viewer::get_value' --no-check
    moon ide find-references 'ViewerOptions' --no-check
    moon ide find-references soft_wrap --loc viewer/viewer_options.mbt:4:3 --no-check
    moon ide find-references NotSet --loc viewer/viewer.mbt:237:3 --no-check
    rg -n '@viewer\.|Viewer::|ViewerOptions|ViewerServices' \
      internal/shell/examples/embedded_viewer internal/shell/workbench \
      tests/browser viewer --glob '*.mbt'
    moon ide analyze viewer --no-check

For a full rerun, enumerate every value/type/method/alias from the generated
interface, issue find-references for qualified callable symbols, then issue
loc-based queries for every type, field, variant, and alias at its source
declaration. Normalize absolute paths to the codes above. A result of Found 1
reference is NONE only after confirming that line is the definition.

### External embedding example

internal/shell/examples/embedded_viewer/main.mbt uses Viewer, Viewer::create,
Viewer::set_model, ViewerOptions construction with placeholder, the render
debug hook, and ViewerModelRenderedEvent.model/fresh. Its fixed migration is
Viewer::on_did_change_model: when new_model_url matches the selected attachment
URI, the listener schedules a native animation-frame callback. `attach_model`
queues the Viewer's render before `did_change_model` fires, so browser rAF FIFO
ordering runs that callback after the pending DOM flush. The callback rechecks
the current model URI, then selects the tree item and sets the existing ready
status; a stale swap callback does nothing. The facade construction and model
attachment remain public.

### Internal workbench/shell

internal/shell/workbench/app.mbt, language_client.mbt, and agent_feedback.mbt
use Viewer/ViewerOptions/ViewerServices; create, focus, get_model, get_options,
layout, set_model, update_options, save/restore, and event hooks; the
three debug hooks; and ScrollEvent.scroll_top/scroll_left. Concrete service
field callers are preserved below because they determine capability owners:
languages is used by app and language_client, markers by app and
language_client, agent_feedback by agent_feedback, and log_service by
language_client.

Workbench debug/performance subscriptions move to the internal JS-only
viewer/browser/testing observability package described below; they do not
remain root public hooks.

### Browser scenarios

The BR evidence spans the component, model_swap, folding, quick_diff,
agent_feedback, read_api, reveal, set_value, whitespace, and performance
scenarios under tests/browser/moonbit. It covers browser construction, options
and services, model/value/selection/scroll/reveal/read geometry, decorations,
events, and view zones. ViewZone construction appears in render_invalidation,
scroll_perf, view_zones, viewer_api, and model_swap. The view_zones scenario
also has two explicit @viewer.ViewZoneChangeAccessor references.

Browser conformance/performance debug subscriptions move to the same internal
JS-only viewer/browser/testing observability package. The package is forbidden
to external embedders.

### Root white-box tests

WT evidence is confined to viewer/*_wbtest.mbt and viewer/*_test.mbt. It covers
the headless Viewer constructor, option normalization and derivation,
contribution lifecycle, decorations, cursor event/reason matrices, geometry,
reveal/scroll/state round trips, model swapping, and concrete service hosts.
Test-only use does not justify retaining a root public declaration. Root
white-box debug assertions use a package-private root hook, never the JS
testing package or a public debug event.

### No local caller

The semantic sweep found exactly 20 items with Found 1 reference, the
definition only:

- EditorDecorationsCollection::append, get_range, and get_ranges.
- EditorContributionInstantiation::AfterFirstRender and Lazy.
- Viewer::get_container_dom_node, get_id, and has_widget_focus.
- Viewer::reveal_line_in_center_if_outside_viewport, reveal_line_near_top,
  reveal_lines, reveal_lines_in_center,
  reveal_lines_in_center_if_outside_viewport, and reveal_lines_near_top.
- Viewer::reveal_position_in_center and reveal_position_near_top.
- Viewer::reveal_range_at_top, reveal_range_in_center, reveal_range_near_top,
  and reveal_range_near_top_if_outside_viewport.

NONE is evidence, not automatic removal. The decoration and readonly
Monaco-shaped methods are retained for external embedders; most remain KEEP,
while the nullable container query is REPLACE under the create-only invariant.
The two contribution variants are REMOVE with their internal registry type.

### Closed debug-hook migration

The three debug functions and their three payload families have one fixed
caller-specific migration, not a choice among alternatives:

| Caller | Required replacement |
|---|---|
| EXT embedded viewer | Viewer::on_did_change_model, filtered to the selected new_model_url; schedule a native rAF after the already-queued Viewer flush, recheck the current URI, then select the tree item and set ready |
| WB workbench | internal JS-only viewer/browser/testing observability, subscribed by the existing Viewer::get_id value |
| BR browser conformance/performance | the same Viewer-id-keyed viewer/browser/testing registry; external import is forbidden |
| WT root white-box | package-private root test hook |

viewer/browser/testing exposes test/workbench-only registrations for build,
render, and hover-resolution facts. WB/BR subscribe with Viewer::get_id; root
emits and removes entries under the same id. This adds a post-migration caller
to the already-public Monaco id contract but adds no new root id API. Debug
payloads do not enter the public viewer interface. The REMOVE rows below all
point to this closed table.

### Closed opaque-options migration

ViewerOptions remains an immutable opaque root snapshot. ViewerOptions(...)
keeps named construction but accepts canonical editor_api enums; get_options
returns the opaque snapshot, and update_options accepts one. Record spread and
field mutation do not remain public.

The exact non-root record-update callers close to immutable builders:

- WB uses with_placeholder and with_theme.
- BR uses with_render_whitespace, with_render_control_characters,
  with_render_line_highlight, with_render_line_highlight_only_when_focus,
  with_render_validation_decorations, with_tab_size, with_soft_wrap,
  with_line_numbers_min_chars, with_line_decorations_width, and
  with_line_height.
- A saved opaque snapshot can still be passed back to update_options, so the
  render-invalidation restore-original case needs no representation access.

The semantic sweep found exactly two non-root scalar reads:
tests/browser/moonbit/component/browser_geometry_scenario.mbt:411 reads
soft_wrap, and tests/browser/moonbit/component/view_zones_scenario.mbt:391
reads line_height. Add only ViewerOptions::soft_wrap and
ViewerOptions::line_height getters. All other fields remain root-private, and
no generic field/getter API is introduced.

Two constructor inputs have deliberately different upstream owners. `tab_size`
is a text-model/global option upstream, not an `IEditorOptions` registration;
the local readonly Viewer keeps it in its opaque snapshot because
`TextSnapshot` carries no model options. Construction and `with_tab_size`
normalize it, rederive view-model columns/wrapping, and refresh folding. `theme`
is standalone/global construction state upstream, not an editor-option
registration; the local constructor and `with_theme` mirror it to the
placeholder/live view `data-theme` state and refresh squiggle colors in place.
Neither is claimed as an ordinary `editorOptions.ts` registration.

### Closed scroll-mode reduction

The root facade does not expose Monaco's `ScrollType`. Every public
`reveal_*`, `set_scroll_top`, `set_scroll_left`, and `set_scroll_position`
operation commits immediately. This is a reviewed readonly-host reduction from
Monaco's smooth default for public reveal calls: deterministic host positioning
does not inherit physical-input animation policy. `smooth_scrolling` still
controls wheel/scrollbar input and internal cursor-command reveals that
explicitly request smooth movement; disabling it, or moving at most one line,
downgrades those internal requests to immediate. Tests cover public immediate
reveal/setter behavior, enabled/disabled internal smooth behavior, the one-line
downgrade, and deferred horizontal-reveal inheritance.

### Closed container and unmanaged-overlay targets

The exact root additions/replacement signatures are:

```text
pub fn Viewer::get_container_dom_node(Self) -> @dom.Element
pub fn overlay_widget(String, @dom.Element) -> @browser.OverlayWidget
pub fn Viewer::add_overlay_widget(Self, @browser.OverlayWidget) -> Unit
pub fn Viewer::remove_overlay_widget(Self, @browser.OverlayWidget) -> Unit
pub fn ViewerServices::dispose(Self) -> Unit
```

`Viewer::create` establishes the non-null container invariant. Disposal removes
Viewer-owned DOM/listeners but retains the original host reference, so
`get_container_dom_node` returns that same element before and after disposal.
The private headless constructor is outside this public invariant and its tests
must not call the method. `get_dom_node` remains nullable because no model/view
may be attached.

`viewer/browser` owns an opaque `OverlayWidget`. Its public
`OverlayWidget::unmanaged(id, dom_node)`, `get_id`, and `get_dom_node` operations
expose immutable identity/node facts; the root `overlay_widget` helper delegates
to that constructor so an external root/common-only host relies on inference
instead of importing `viewer/browser`. The handle is fixed to Monaco's null
position/self-positioned subset. Re-adding an id is last-writer-wins, remove
uses the supplied handle's id, unknown removal is a no-op, registrations survive
model swaps, and Viewer disposal clears them. Content-widget operations,
positioned overlay preferences/coordinates, overflow, layout events, minimum
content width, and `layoutOverlayWidget` are `DEFERRED`: the current Viewer has
no implementation or caller for those seams, so this boundary plan does not
invent them.

The non-exclusive row totals after classifying all 210 rows are:

| Evidence code | Ledger rows |
|---|---:|
| EXT | 9 |
| WB | 45 |
| BR | 95 |
| WT | 102 |
| ROOT | 148 |
| NONE | 20 |

## Disposition meanings

Every row has exactly one terminal disposition:

- KEEP: preserve the public item at its current facade owner, though signatures
  may consume canonical moved payload types.
- MOVE: transfer canonical declaration ownership and delete the root copy.
- ALIAS: retain a deliberate compatibility alias. Gate A selects no aliases
  because breaking changes are allowed and parallel public types are forbidden.
- OPAQUE: preserve the public facade type or capability but hide representation.
- REPLACE: preserve the capability with a reviewed public contract/signature.
- REMOVE: delete the public item and migrate callers to the named private or
  semantic seam.

## Complete public disposition ledger

| ID | Kind | Public item | Current signature | Evidence | Disposition | Target owner | Migration rationale |
|---|---|---|---|---|---|---|---|
| API-V001 | VALUE | debug_on_did_build_view_model | pub fn debug_on_did_build_view_model(Viewer, (ViewerViewModelBuiltEvent) -> Unit) -> @moonbit-community/editor/base/common.Disposable | WB,WT | REMOVE | closed debug-hook migration above | WB subscribes to JS-only viewer/browser/testing by existing Viewer::get_id; WT uses the package-private root hook. |
| API-V002 | VALUE | debug_on_did_render_model | pub fn debug_on_did_render_model(Viewer, (ViewerModelRenderedEvent) -> Unit) -> @moonbit-community/editor/base/common.Disposable | EXT,WB,BR | REMOVE | closed debug-hook migration above | EXT uses filtered Viewer::on_did_change_model plus a URI-guarded native rAF ordered after the queued Viewer flush; WB/BR subscribe to viewer/browser/testing by existing Viewer::get_id. |
| API-V003 | VALUE | debug_on_did_resolve_hover | pub fn debug_on_did_resolve_hover(Viewer, (ViewerHoverResolvedEvent) -> Unit) -> @moonbit-community/editor/base/common.Disposable | WB,BR | REMOVE | closed debug-hook migration above | WB/BR subscribe to JS-only viewer/browser/testing hover observability by existing Viewer::get_id. |
| API-V004 | VALUE | view_zone | pub fn view_zone(Int, @dom.Element, after_column? : Int, after_column_affinity? : @model.PositionAffinity, show_in_hidden_areas? : Bool, ordinal? : Int, suppress_mouse_down? : Bool, height_in_lines? : Double, height_in_px? : Double, min_width_in_px? : Double, margin_dom_node? : @dom.Element, on_dom_node_top? : (Double) -> Unit raise, on_computed_height? : (Double) -> Unit raise) -> @view.ViewZone | BR | REPLACE | viewer facade returning viewer/browser ViewZone | Preserve external-host construction without expanding architecture policy: keep the root convenience factory, but retarget its return to the canonical browser-owned descriptor while private rendered state remains in viewer/browser/view. |
| API-T001 | TYPE | CursorChangeReason | pub(all) enum CursorChangeReason | BR,WT,ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T001.V01 | VARIANT | CursorChangeReason::NotSet | NotSet | BR,WT,ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T001.V02 | VARIANT | CursorChangeReason::ContentFlush | ContentFlush | BR,WT,ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T001.V03 | VARIANT | CursorChangeReason::RecoverFromMarkers | RecoverFromMarkers | BR,ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T001.V04 | VARIANT | CursorChangeReason::Explicit | Explicit | BR,WT,ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T001.V05 | VARIANT | CursorChangeReason::Paste | Paste | BR,WT,ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T001.V06 | VARIANT | CursorChangeReason::Undo | Undo | BR,WT,ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T001.V07 | VARIANT | CursorChangeReason::Redo | Redo | BR,WT,ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T002 | TYPE | CursorPositionChangedEvent | pub(all) struct CursorPositionChangedEvent | WT,ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T002.F01 | FIELD | CursorPositionChangedEvent.position | position : @moonbit-community/editor/base/common.Position | BR,WT,ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T002.F02 | FIELD | CursorPositionChangedEvent.secondary_positions | secondary_positions : Array[@moonbit-community/editor/base/common.Position] | BR,WT,ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T002.F03 | FIELD | CursorPositionChangedEvent.reason | reason : CursorChangeReason | BR,WT,ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T002.F04 | FIELD | CursorPositionChangedEvent.source | source : String | BR,WT,ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T003 | TYPE | CursorSelectionChangedEvent | pub(all) struct CursorSelectionChangedEvent | WT,ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T003.F01 | FIELD | CursorSelectionChangedEvent.selection | selection : @core.Selection | BR,WT,ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T003.F02 | FIELD | CursorSelectionChangedEvent.secondary_selections | secondary_selections : Array[@core.Selection] | BR,WT,ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T003.F03 | FIELD | CursorSelectionChangedEvent.model_version_id | model_version_id : Int | BR,WT,ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T003.F04 | FIELD | CursorSelectionChangedEvent.old_selections | old_selections : Array[@core.Selection]? | BR,WT,ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T003.F05 | FIELD | CursorSelectionChangedEvent.old_model_version_id | old_model_version_id : Int | BR,WT,ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T003.F06 | FIELD | CursorSelectionChangedEvent.source | source : String | BR,WT,ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T003.F07 | FIELD | CursorSelectionChangedEvent.reason | reason : CursorChangeReason | BR,WT,ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T004 | TYPE | EditorContribution | pub(all) struct EditorContribution | ROOT | REMOVE | viewer private contribution registry | Registry handles and instantiation policy are implementation details; migrate root tests to white-box access and delete external exposure. |
| API-T004.F01 | FIELD | EditorContribution.id | id : String | WT,ROOT | REMOVE | viewer private contribution registry | Registry handles and instantiation policy are implementation details; migrate root tests to white-box access and delete external exposure. |
| API-T004.F02 | FIELD | EditorContribution.dispose | dispose : () -> Unit | WT,ROOT | REMOVE | viewer private contribution registry | Registry handles and instantiation policy are implementation details; migrate root tests to white-box access and delete external exposure. |
| API-T005 | TYPE | EditorContributionInstantiation | pub(all) enum EditorContributionInstantiation | ROOT | REMOVE | viewer private contribution registry | Registry handles and instantiation policy are implementation details; migrate root tests to white-box access and delete external exposure. |
| API-T005.V01 | VARIANT | EditorContributionInstantiation::Eager | Eager | WT,ROOT | REMOVE | viewer private contribution registry | Registry handles and instantiation policy are implementation details; migrate root tests to white-box access and delete external exposure. |
| API-T005.V02 | VARIANT | EditorContributionInstantiation::AfterFirstRender | AfterFirstRender | NONE | REMOVE | viewer private contribution registry | Registry handles and instantiation policy are implementation details; migrate root tests to white-box access and delete external exposure. |
| API-T005.V03 | VARIANT | EditorContributionInstantiation::BeforeFirstInteraction | BeforeFirstInteraction | ROOT | REMOVE | viewer private contribution registry | Registry handles and instantiation policy are implementation details; migrate root tests to white-box access and delete external exposure. |
| API-T005.V04 | VARIANT | EditorContributionInstantiation::Eventually | Eventually | ROOT | REMOVE | viewer private contribution registry | Registry handles and instantiation policy are implementation details; migrate root tests to white-box access and delete external exposure. |
| API-T005.V05 | VARIANT | EditorContributionInstantiation::Lazy | Lazy | NONE | REMOVE | viewer private contribution registry | Registry handles and instantiation policy are implementation details; migrate root tests to white-box access and delete external exposure. |
| API-T006 | TYPE | EditorDecorationsCollection | pub struct EditorDecorationsCollection | ROOT | KEEP | viewer | Accepted Monaco-shaped readonly decoration collection on the opaque root facade; definition-only methods remain for embedders. |
| API-T006.M01 | METHOD | EditorDecorationsCollection::append | pub fn EditorDecorationsCollection::append(Self, Array[@model.ModelDeltaDecoration]) -> Array[String] | NONE | KEEP | viewer | Accepted Monaco-shaped readonly decoration collection on the opaque root facade; definition-only methods remain for embedders. |
| API-T006.M02 | METHOD | EditorDecorationsCollection::clear | pub fn EditorDecorationsCollection::clear(Self) -> Unit | ROOT | KEEP | viewer | Accepted Monaco-shaped readonly decoration collection on the opaque root facade; definition-only methods remain for embedders. |
| API-T006.M03 | METHOD | EditorDecorationsCollection::get_range | pub fn EditorDecorationsCollection::get_range(Self, Int) -> @moonbit-community/editor/base/common.Range? | NONE | KEEP | viewer | Accepted Monaco-shaped readonly decoration collection on the opaque root facade; definition-only methods remain for embedders. |
| API-T006.M04 | METHOD | EditorDecorationsCollection::get_ranges | pub fn EditorDecorationsCollection::get_ranges(Self) -> Array[@moonbit-community/editor/base/common.Range] | NONE | KEEP | viewer | Accepted Monaco-shaped readonly decoration collection on the opaque root facade; definition-only methods remain for embedders. |
| API-T006.M05 | METHOD | EditorDecorationsCollection::length | pub fn EditorDecorationsCollection::length(Self) -> Int | WT | KEEP | viewer | Accepted Monaco-shaped readonly decoration collection on the opaque root facade; definition-only methods remain for embedders. |
| API-T006.M06 | METHOD | EditorDecorationsCollection::set | pub fn EditorDecorationsCollection::set(Self, Array[@model.ModelDeltaDecoration]) -> Array[String] | ROOT | KEEP | viewer | Accepted Monaco-shaped readonly decoration collection on the opaque root facade; definition-only methods remain for embedders. |
| API-T007 | TYPE | EditorMouseEvent | pub(all) struct EditorMouseEvent | ROOT | MOVE | viewer/browser canonical hit-tested EditorMouseEvent | Move the hit-tested wrapper to browser; rename the existing raw DOM wrapper to EditorDomMouseEvent so the public name is unambiguous. |
| API-T007.F01 | FIELD | EditorMouseEvent.event | event : @moonbit-community/editor/viewer/browser.EditorMouseEvent | ROOT | MOVE | viewer/browser EditorMouseEvent.event : EditorDomMouseEvent | Preserve the raw DOM event as a distinctly named browser contract inside the canonical hit-tested wrapper. |
| API-T007.F02 | FIELD | EditorMouseEvent.target | target : @moonbit-community/editor/viewer/browser.MouseTarget | BR,ROOT | MOVE | viewer/browser EditorMouseEvent.target | Keep MouseTarget beside the canonical hit-tested browser wrapper; root mouse events consume it directly. |
| API-T008 | TYPE | ModelChangedEvent | pub(all) struct ModelChangedEvent | ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T008.F01 | FIELD | ModelChangedEvent.old_model_url | old_model_url : @moonbit-community/editor/base/common.Uri? | ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T008.F02 | FIELD | ModelChangedEvent.new_model_url | new_model_url : @moonbit-community/editor/base/common.Uri? | ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T009 | TYPE | PartialEditorMouseEvent | pub(all) struct PartialEditorMouseEvent | ROOT | MOVE | viewer/browser canonical PartialEditorMouseEvent | Move the partial hit-tested wrapper beside the full browser wrapper; root mouse-leave consumes it directly. |
| API-T009.F01 | FIELD | PartialEditorMouseEvent.event | event : @moonbit-community/editor/viewer/browser.EditorMouseEvent | ROOT | MOVE | viewer/browser PartialEditorMouseEvent.event : EditorDomMouseEvent | Retarget the raw event field to the renamed EditorDomMouseEvent contract. |
| API-T009.F02 | FIELD | PartialEditorMouseEvent.target | target : @moonbit-community/editor/viewer/browser.MouseTarget? | ROOT | MOVE | viewer/browser PartialEditorMouseEvent.target | Preserve the optional hit-test target in the canonical browser wrapper. |
| API-T010 | TYPE | ScrollEvent | pub(all) struct ScrollEvent | WB,ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T010.F01 | FIELD | ScrollEvent.scroll_top | scroll_top : Double | WB,BR,ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T010.F02 | FIELD | ScrollEvent.scroll_left | scroll_left : Double | WB,BR,ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T010.F03 | FIELD | ScrollEvent.scroll_width | scroll_width : Double | ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T010.F04 | FIELD | ScrollEvent.scroll_height | scroll_height : Double | ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T010.F05 | FIELD | ScrollEvent.scroll_top_changed | scroll_top_changed : Bool | ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T010.F06 | FIELD | ScrollEvent.scroll_left_changed | scroll_left_changed : Bool | ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T010.F07 | FIELD | ScrollEvent.scroll_width_changed | scroll_width_changed : Bool | ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T010.F08 | FIELD | ScrollEvent.scroll_height_changed | scroll_height_changed : Bool | ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T011 | TYPE | ScrolledVisiblePosition | pub(all) struct ScrolledVisiblePosition | ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T011.F01 | FIELD | ScrolledVisiblePosition.top | top : Double | BR,ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T011.F02 | FIELD | ScrolledVisiblePosition.left | left : Double | BR,ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T011.F03 | FIELD | ScrolledVisiblePosition.height | height : Double | BR,ROOT | MOVE | viewer/common/editor_api | DOM-free public editor contract; move one canonical declaration below root, view-model, and browser consumers and delete the root copy. |
| API-T012 | TYPE | Viewer | pub struct Viewer | EXT,WB,BR,WT,ROOT | KEEP | viewer | Root facade remains opaque and is the stable readonly editor handle. |
| API-T012.M01 | METHOD | Viewer::Viewer | pub fn Viewer::Viewer(services? : ViewerServices, options? : ViewerOptions) -> Self | WT,ROOT | REMOVE | viewer private test constructor | Headless construction is a white-box seam; external construction uses Viewer::create. |
| API-T012.M02 | METHOD | Viewer::add_overlay_widget | pub fn Viewer::add_overlay_widget(Self, String, @dom.Element) -> Unit | ROOT | REPLACE | viewer facade over viewer/browser OverlayWidget contract | Replace with add_overlay_widget(Self, @browser.OverlayWidget); the closed unmanaged-overlay target above fixes construction, identity, model-swap, and disposal semantics. |
| API-T012.M03 | METHOD | Viewer::change_view_zones | pub fn Viewer::change_view_zones(Self, (@view.ViewZoneChangeAccessor) -> Unit raise) -> Unit | BR,WT | KEEP | viewer facade using viewer/browser ViewZoneChangeAccessor | Keep the operation but retarget its callback to the public browser descriptor/accessor, not private browser/view. |
| API-T012.M04 | METHOD | Viewer::create | pub fn Viewer::create(@dom.Element, services? : ViewerServices, options? : ViewerOptions) -> Self | EXT,WB,BR | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M05 | METHOD | Viewer::create_decorations_collection | pub fn Viewer::create_decorations_collection(Self, decorations? : Array[@model.ModelDeltaDecoration]) -> EditorDecorationsCollection | WT,ROOT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M06 | METHOD | Viewer::delta_decorations | pub fn Viewer::delta_decorations(Self, Array[String], Array[@model.ModelDeltaDecoration]) -> Array[String] | BR,WT,ROOT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M07 | METHOD | Viewer::dispose | pub fn Viewer::dispose(Self) -> Unit | BR,WT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M08 | METHOD | Viewer::focus | pub fn Viewer::focus(Self) -> Unit | WB,BR,ROOT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M09 | METHOD | Viewer::get_bottom_for_line_number | pub fn Viewer::get_bottom_for_line_number(Self, Int, include_view_zones? : Bool) -> Double | WT | REPLACE | viewer | Match public ICodeEditor with a line-only method; move include_view_zones control to a package-private geometry test/helper seam. |
| API-T012.M10 | METHOD | Viewer::get_container_dom_node | pub fn Viewer::get_container_dom_node(Self) -> @dom.Element? | NONE | REPLACE | viewer | Return non-null @dom.Element under the public create-only invariant; retain the original host through disposal, while the private headless seam must not call this method. |
| API-T012.M11 | METHOD | Viewer::get_content_height | pub fn Viewer::get_content_height(Self) -> Double | BR,WT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M12 | METHOD | Viewer::get_content_width | pub fn Viewer::get_content_width(Self) -> Double | BR,WT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M13 | METHOD | Viewer::get_contribution | pub fn Viewer::get_contribution(Self, String) -> EditorContribution? | WT | REMOVE | viewer private contribution registry | Public lookup exposes internal registry ownership; migrate feature hosts to direct single-owner wiring. |
| API-T012.M14 | METHOD | Viewer::get_decorations_in_range | pub fn Viewer::get_decorations_in_range(Self, @moonbit-community/editor/base/common.Range) -> Array[@model.ModelDecoration] | WT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M15 | METHOD | Viewer::get_dom_node | pub fn Viewer::get_dom_node(Self) -> @dom.Element? | BR | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M16 | METHOD | Viewer::get_editor_type | pub fn Viewer::get_editor_type(Self) -> String | ROOT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M17 | METHOD | Viewer::get_id | pub fn Viewer::get_id(Self) -> String | NONE | KEEP | viewer | Preserve the public Monaco id contract; currently definition-only, it becomes the fixed WB/BR subscription key for viewer/browser/testing without adding a new id API. |
| API-T012.M18 | METHOD | Viewer::get_layout_info | pub fn Viewer::get_layout_info(Self) -> @config.EditorLayoutInfo | BR,WT,ROOT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M19 | METHOD | Viewer::get_line_decorations | pub fn Viewer::get_line_decorations(Self, Int) -> Array[@model.ModelDecoration] | WT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M20 | METHOD | Viewer::get_line_height_for_position | pub fn Viewer::get_line_height_for_position(Self, @moonbit-community/editor/base/common.Position) -> Double | WT,ROOT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M21 | METHOD | Viewer::get_model | pub fn Viewer::get_model(Self) -> @model.TextModel? | WB,BR,WT,ROOT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M22 | METHOD | Viewer::get_offset_for_column | pub fn Viewer::get_offset_for_column(Self, Int, Int) -> Double | BR,WT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M23 | METHOD | Viewer::get_options | pub fn Viewer::get_options(Self) -> ViewerOptions | WB,BR,WT | KEEP | viewer | Keep only an opaque immutable ViewerOptions snapshot; callers use the fixed with_field builders and two scalar getters above. |
| API-T012.M24 | METHOD | Viewer::get_position | pub fn Viewer::get_position(Self) -> @moonbit-community/editor/base/common.Position? | BR,WT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M25 | METHOD | Viewer::get_scroll_height | pub fn Viewer::get_scroll_height(Self) -> Double | BR,WT,ROOT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M26 | METHOD | Viewer::get_scroll_left | pub fn Viewer::get_scroll_left(Self) -> Double | BR,WT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M27 | METHOD | Viewer::get_scroll_top | pub fn Viewer::get_scroll_top(Self) -> Double | BR,WT,ROOT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M28 | METHOD | Viewer::get_scroll_width | pub fn Viewer::get_scroll_width(Self) -> Double | BR,WT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M29 | METHOD | Viewer::get_scrolled_visible_position | pub fn Viewer::get_scrolled_visible_position(Self, @moonbit-community/editor/base/common.Position) -> ScrolledVisiblePosition? | BR,WT,ROOT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M30 | METHOD | Viewer::get_selection | pub fn Viewer::get_selection(Self) -> @core.Selection? | BR,WT,ROOT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M31 | METHOD | Viewer::get_selections | pub fn Viewer::get_selections(Self) -> Array[@core.Selection]? | WT,ROOT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M32 | METHOD | Viewer::get_statusbar_column | pub fn Viewer::get_statusbar_column(Self, @moonbit-community/editor/base/common.Position) -> Int | WT | REMOVE | viewer private read-geometry helper | Upstream marks this status-bar convention internal; root white-box callers use the package-private helper. |
| API-T012.M33 | METHOD | Viewer::get_top_for_line_number | pub fn Viewer::get_top_for_line_number(Self, Int, include_view_zones? : Bool) -> Double | BR,WT,ROOT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M34 | METHOD | Viewer::get_top_for_position | pub fn Viewer::get_top_for_position(Self, Int, Int) -> Double | WT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M35 | METHOD | Viewer::get_value | pub fn Viewer::get_value(Self) -> String | WT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M36 | METHOD | Viewer::get_visible_column_from_position | pub fn Viewer::get_visible_column_from_position(Self, @moonbit-community/editor/base/common.Position) -> Int | WT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M37 | METHOD | Viewer::get_visible_ranges | pub fn Viewer::get_visible_ranges(Self) -> Array[@moonbit-community/editor/base/common.Range] | WT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M38 | METHOD | Viewer::get_visible_ranges_plus_viewport_above_below | pub fn Viewer::get_visible_ranges_plus_viewport_above_below(Self) -> Array[@moonbit-community/editor/base/common.Range] | WT | REMOVE | viewer private viewport helper | Upstream marks overscanned ranges internal; root white-box callers use the package-private helper. |
| API-T012.M39 | METHOD | Viewer::get_width_of_line | pub fn Viewer::get_width_of_line(Self, Int) -> Double | BR,WT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M40 | METHOD | Viewer::has_model | pub fn Viewer::has_model(Self) -> Bool | BR,ROOT | REMOVE | viewer private state plus viewer/browser/testing | Upstream exposes this only as an internal type guard; ROOT reads private state and BR queries has_model by existing Viewer id through the test-only registry. |
| API-T012.M41 | METHOD | Viewer::has_text_focus | pub fn Viewer::has_text_focus(Self) -> Bool | BR,ROOT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M42 | METHOD | Viewer::has_widget_focus | pub fn Viewer::has_widget_focus(Self) -> Bool | NONE | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M43 | METHOD | Viewer::layout | pub fn Viewer::layout(Self) -> Unit | WB,BR | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M44 | METHOD | Viewer::on_did_change_cursor_position | pub fn Viewer::on_did_change_cursor_position(Self, (CursorPositionChangedEvent) -> Unit) -> @moonbit-community/editor/base/common.Disposable | BR,WT,ROOT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M45 | METHOD | Viewer::on_did_change_cursor_selection | pub fn Viewer::on_did_change_cursor_selection(Self, (CursorSelectionChangedEvent) -> Unit) -> @moonbit-community/editor/base/common.Disposable | BR,WT,ROOT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M46 | METHOD | Viewer::on_did_change_model | pub fn Viewer::on_did_change_model(Self, (ModelChangedEvent) -> Unit) -> @moonbit-community/editor/base/common.Disposable | WT,ROOT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M47 | METHOD | Viewer::on_did_change_model_content | pub fn Viewer::on_did_change_model_content(Self, (@model.ModelContentChangedEvent) -> Unit) -> @moonbit-community/editor/base/common.Disposable | BR,WT,ROOT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M48 | METHOD | Viewer::on_did_change_view_zones | pub fn Viewer::on_did_change_view_zones(Self, () -> Unit) -> @moonbit-community/editor/base/common.Disposable | BR | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M49 | METHOD | Viewer::on_did_dispose | pub fn Viewer::on_did_dispose(Self, () -> Unit) -> @moonbit-community/editor/base/common.Disposable | WB,WT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M50 | METHOD | Viewer::on_did_scroll_change | pub fn Viewer::on_did_scroll_change(Self, (ScrollEvent) -> Unit) -> @moonbit-community/editor/base/common.Disposable | WB,BR,ROOT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M51 | METHOD | Viewer::on_mouse_down | pub fn Viewer::on_mouse_down(Self, (EditorMouseEvent) -> Unit) -> @moonbit-community/editor/base/common.Disposable | BR,ROOT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M52 | METHOD | Viewer::on_mouse_leave | pub fn Viewer::on_mouse_leave(Self, (PartialEditorMouseEvent) -> Unit) -> @moonbit-community/editor/base/common.Disposable | ROOT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M53 | METHOD | Viewer::on_mouse_move | pub fn Viewer::on_mouse_move(Self, (EditorMouseEvent) -> Unit) -> @moonbit-community/editor/base/common.Disposable | ROOT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M54 | METHOD | Viewer::on_mouse_up | pub fn Viewer::on_mouse_up(Self, (EditorMouseEvent) -> Unit) -> @moonbit-community/editor/base/common.Disposable | ROOT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M55 | METHOD | Viewer::remove_decorations | pub fn Viewer::remove_decorations(Self, Array[String]) -> Unit | BR,WT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M56 | METHOD | Viewer::remove_overlay_widget | pub fn Viewer::remove_overlay_widget(Self, String) -> Unit | ROOT | REPLACE | viewer facade over viewer/browser OverlayWidget contract | Replace with remove_overlay_widget(Self, @browser.OverlayWidget); removal uses the immutable handle id and remains an unknown-id no-op. |
| API-T012.M57 | METHOD | Viewer::restore_view_state | pub fn Viewer::restore_view_state(Self, ViewerViewState?) -> Unit | WB,WT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M58 | METHOD | Viewer::reveal_line | pub fn Viewer::reveal_line(Self, Int) -> Unit | WT | KEEP | viewer | Keep the fixed immediate host operation documented by the closed scroll-mode reduction; no public ScrollType is added. |
| API-T012.M59 | METHOD | Viewer::reveal_line_in_center | pub fn Viewer::reveal_line_in_center(Self, Int) -> Unit | WT | KEEP | viewer | Keep the fixed immediate host operation documented by the closed scroll-mode reduction; no public ScrollType is added. |
| API-T012.M60 | METHOD | Viewer::reveal_line_in_center_if_outside_viewport | pub fn Viewer::reveal_line_in_center_if_outside_viewport(Self, Int) -> Unit | NONE | KEEP | viewer | Keep the fixed immediate host operation documented by the closed scroll-mode reduction; no public ScrollType is added. |
| API-T012.M61 | METHOD | Viewer::reveal_line_near_top | pub fn Viewer::reveal_line_near_top(Self, Int) -> Unit | NONE | KEEP | viewer | Keep the fixed immediate host operation documented by the closed scroll-mode reduction; no public ScrollType is added. |
| API-T012.M62 | METHOD | Viewer::reveal_lines | pub fn Viewer::reveal_lines(Self, Int, Int) -> Unit | NONE | KEEP | viewer | Keep the fixed immediate host operation documented by the closed scroll-mode reduction; no public ScrollType is added. |
| API-T012.M63 | METHOD | Viewer::reveal_lines_in_center | pub fn Viewer::reveal_lines_in_center(Self, Int, Int) -> Unit | NONE | KEEP | viewer | Keep the fixed immediate host operation documented by the closed scroll-mode reduction; no public ScrollType is added. |
| API-T012.M64 | METHOD | Viewer::reveal_lines_in_center_if_outside_viewport | pub fn Viewer::reveal_lines_in_center_if_outside_viewport(Self, Int, Int) -> Unit | NONE | KEEP | viewer | Keep the fixed immediate host operation documented by the closed scroll-mode reduction; no public ScrollType is added. |
| API-T012.M65 | METHOD | Viewer::reveal_lines_near_top | pub fn Viewer::reveal_lines_near_top(Self, Int, Int) -> Unit | NONE | KEEP | viewer | Keep the fixed immediate host operation documented by the closed scroll-mode reduction; no public ScrollType is added. |
| API-T012.M66 | METHOD | Viewer::reveal_position | pub fn Viewer::reveal_position(Self, @moonbit-community/editor/base/common.Position) -> Unit | BR | KEEP | viewer | Keep the fixed immediate host operation documented by the closed scroll-mode reduction; no public ScrollType is added. |
| API-T012.M67 | METHOD | Viewer::reveal_position_in_center | pub fn Viewer::reveal_position_in_center(Self, @moonbit-community/editor/base/common.Position) -> Unit | NONE | KEEP | viewer | Keep the fixed immediate host operation documented by the closed scroll-mode reduction; no public ScrollType is added. |
| API-T012.M68 | METHOD | Viewer::reveal_position_in_center_if_outside_viewport | pub fn Viewer::reveal_position_in_center_if_outside_viewport(Self, @moonbit-community/editor/base/common.Position) -> Unit | ROOT | KEEP | viewer | Keep the fixed immediate host operation documented by the closed scroll-mode reduction; no public ScrollType is added. |
| API-T012.M69 | METHOD | Viewer::reveal_position_near_top | pub fn Viewer::reveal_position_near_top(Self, @moonbit-community/editor/base/common.Position) -> Unit | NONE | KEEP | viewer | Keep the fixed immediate host operation documented by the closed scroll-mode reduction; no public ScrollType is added. |
| API-T012.M70 | METHOD | Viewer::reveal_range | pub fn Viewer::reveal_range(Self, @moonbit-community/editor/base/common.Range) -> Unit | WT | KEEP | viewer | Keep the fixed immediate host operation documented by the closed scroll-mode reduction; no public ScrollType is added. |
| API-T012.M71 | METHOD | Viewer::reveal_range_at_top | pub fn Viewer::reveal_range_at_top(Self, @moonbit-community/editor/base/common.Range) -> Unit | NONE | KEEP | viewer | Keep the fixed immediate host operation documented by the closed scroll-mode reduction; no public ScrollType is added. |
| API-T012.M72 | METHOD | Viewer::reveal_range_in_center | pub fn Viewer::reveal_range_in_center(Self, @moonbit-community/editor/base/common.Range) -> Unit | NONE | KEEP | viewer | Keep the fixed immediate host operation documented by the closed scroll-mode reduction; no public ScrollType is added. |
| API-T012.M73 | METHOD | Viewer::reveal_range_in_center_if_outside_viewport | pub fn Viewer::reveal_range_in_center_if_outside_viewport(Self, @moonbit-community/editor/base/common.Range) -> Unit | ROOT | KEEP | viewer | Keep the fixed immediate host operation documented by the closed scroll-mode reduction; no public ScrollType is added. |
| API-T012.M74 | METHOD | Viewer::reveal_range_near_top | pub fn Viewer::reveal_range_near_top(Self, @moonbit-community/editor/base/common.Range) -> Unit | NONE | KEEP | viewer | Keep the fixed immediate host operation documented by the closed scroll-mode reduction; no public ScrollType is added. |
| API-T012.M75 | METHOD | Viewer::reveal_range_near_top_if_outside_viewport | pub fn Viewer::reveal_range_near_top_if_outside_viewport(Self, @moonbit-community/editor/base/common.Range) -> Unit | NONE | KEEP | viewer | Keep the fixed immediate host operation documented by the closed scroll-mode reduction; no public ScrollType is added. |
| API-T012.M76 | METHOD | Viewer::save_view_state | pub fn Viewer::save_view_state(Self) -> ViewerViewState? | WB,WT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M77 | METHOD | Viewer::set_hidden_areas | pub fn Viewer::set_hidden_areas(Self, Array[@moonbit-community/editor/base/common.Range], source? : String, force_update? : Bool) -> Unit | BR,WT,ROOT | REMOVE | viewer private folding host plus viewer/browser/testing | WT/ROOT call the package-private folding host; browser_geometry uses test-only set_hidden_areas by existing Viewer id. |
| API-T012.M78 | METHOD | Viewer::set_model | pub fn Viewer::set_model(Self, @model.TextModel?) -> Unit | EXT,WB,BR,WT,ROOT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M79 | METHOD | Viewer::set_position | pub fn Viewer::set_position(Self, @moonbit-community/editor/base/common.Position, source? : String) -> Unit | BR,WT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M80 | METHOD | Viewer::set_scroll_left | pub fn Viewer::set_scroll_left(Self, Double) -> Unit | WT | KEEP | viewer | Keep an immediate host setter; the closed scroll-mode reduction reserves smooth behavior for physical input/internal cursor requests. |
| API-T012.M81 | METHOD | Viewer::set_scroll_position | pub fn Viewer::set_scroll_position(Self, scroll_top? : Double, scroll_left? : Double) -> Unit | BR,WT | KEEP | viewer | Keep an immediate host setter with omitted-axis preservation; the closed scroll-mode reduction adds no public ScrollType. |
| API-T012.M82 | METHOD | Viewer::set_scroll_top | pub fn Viewer::set_scroll_top(Self, Double) -> Unit | BR,WT | KEEP | viewer | Keep an immediate host setter; the closed scroll-mode reduction reserves smooth behavior for physical input/internal cursor requests. |
| API-T012.M83 | METHOD | Viewer::set_selection | pub fn Viewer::set_selection(Self, @core.Selection, source? : String) -> Unit | BR,WT,ROOT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M84 | METHOD | Viewer::set_selections | pub fn Viewer::set_selections(Self, Array[@core.Selection], source? : String, reason? : CursorChangeReason) -> Unit | WT,ROOT | KEEP | viewer | Accepted readonly Monaco-shaped facade operation; preserve behavior on opaque Viewer and retarget moved payload types where applicable. |
| API-T012.M85 | METHOD | Viewer::set_value | pub fn Viewer::set_value(Self, String) -> Unit | BR,WT | KEEP | viewer | Preserve host-driven whole-buffer model replacement. Readonly excludes interactive edit commands, actions, and undo/redo exposure; it does not prevent the owning host from replacing document content. |
| API-T012.M86 | METHOD | Viewer::update_options | pub fn Viewer::update_options(Self, ViewerOptions) -> Unit | WB,BR,WT,ROOT | KEEP | viewer | Keep update_options for opaque snapshots produced by construction, fixed with_field builders, or get_options round trips. |
| API-T013 | TYPE | ViewerHoverResolvedEvent | pub(all) struct ViewerHoverResolvedEvent | WB,ROOT | REMOVE | closed debug-hook migration above | Use the caller-specific closed debug migration above, then remove this root payload item. |
| API-T013.F01 | FIELD | ViewerHoverResolvedEvent.ok | ok : Bool | WB,BR,ROOT | REMOVE | closed debug-hook migration above | Use the caller-specific closed debug migration above, then remove this root payload item. |
| API-T013.F02 | FIELD | ViewerHoverResolvedEvent.revision | revision : String | WB,BR,ROOT | REMOVE | closed debug-hook migration above | Use the caller-specific closed debug migration above, then remove this root payload item. |
| API-T014 | TYPE | ViewerModelRenderedEvent | pub(all) struct ViewerModelRenderedEvent | EXT,WB,ROOT | REMOVE | closed debug-hook migration above | Use the caller-specific closed debug migration above, then remove this root payload item. |
| API-T014.F01 | FIELD | ViewerModelRenderedEvent.model | model : @model.TextModel | EXT,WB,BR,ROOT | REMOVE | closed debug-hook migration above | Use the caller-specific closed debug migration above, then remove this root payload item. |
| API-T014.F02 | FIELD | ViewerModelRenderedEvent.line_count | line_count : Int | WB,BR,ROOT | REMOVE | closed debug-hook migration above | Use the caller-specific closed debug migration above, then remove this root payload item. |
| API-T014.F03 | FIELD | ViewerModelRenderedEvent.rendered_lines | rendered_lines : Int | WB,BR,ROOT | REMOVE | closed debug-hook migration above | Use the caller-specific closed debug migration above, then remove this root payload item. |
| API-T014.F04 | FIELD | ViewerModelRenderedEvent.diagnostics | diagnostics : Array[@language.Diagnostic] | WB,ROOT | REMOVE | closed debug-hook migration above | Use the caller-specific closed debug migration above, then remove this root payload item. |
| API-T014.F05 | FIELD | ViewerModelRenderedEvent.patch_ms | patch_ms : Double | WB,ROOT | REMOVE | closed debug-hook migration above | Use the caller-specific closed debug migration above, then remove this root payload item. |
| API-T014.F06 | FIELD | ViewerModelRenderedEvent.fresh | fresh : Bool | EXT,WB,BR,ROOT | REMOVE | closed debug-hook migration above | Use the caller-specific closed debug migration above, then remove this root payload item. |
| API-T015 | TYPE | ViewerOptions | pub(all) struct ViewerOptions | EXT,WB,BR,WT,ROOT | OPAQUE | viewer | Keep the root option facade but hide its representation; the closed opaque-options migration above fixes construction, builders, snapshot use, and getters. |
| API-T015.F01 | FIELD | ViewerOptions.soft_wrap | soft_wrap : Bool | BR,ROOT | OPAQUE | viewer private ViewerOptions field | Hide the field; expose only with_soft_wrap and the soft_wrap scalar getter fixed by the closed opaque-options migration. |
| API-T015.F02 | FIELD | ViewerOptions.tab_size | tab_size : Int | BR,WT,ROOT | OPAQUE | viewer private ViewerOptions field | Hide the field; expose only with_tab_size. This is local model/view-model configuration because TextSnapshot has no model options, not an editorOptions registration. |
| API-T015.F03 | FIELD | ViewerOptions.wrapping_indent | wrapping_indent : @view_model.WrappingIndent | ROOT | OPAQUE | viewer private field; input enum in viewer/common/editor_api | Hide the field; no builder or getter is justified, so it remains constructor/root-private state only. |
| API-T015.F04 | FIELD | ViewerOptions.render_whitespace | render_whitespace : @view_layout.RenderWhitespace | BR,WT,ROOT | OPAQUE | viewer private field; input enum in viewer/common/editor_api | Hide the field; expose only with_render_whitespace for the proven update callers, with no scalar getter. |
| API-T015.F05 | FIELD | ViewerOptions.render_control_characters | render_control_characters : Bool | BR,WT,ROOT | OPAQUE | viewer private ViewerOptions field | Hide the field; expose only with_render_control_characters for the proven update callers, with no scalar getter. |
| API-T015.F06 | FIELD | ViewerOptions.render_line_highlight | render_line_highlight : @view_layout.RenderLineHighlight | BR,WT,ROOT | OPAQUE | viewer private field; input enum in viewer/common/editor_api | Hide the field; expose only with_render_line_highlight for the proven update callers, with no scalar getter. |
| API-T015.F07 | FIELD | ViewerOptions.render_line_highlight_only_when_focus | render_line_highlight_only_when_focus : Bool | BR,WT,ROOT | OPAQUE | viewer private ViewerOptions field | Hide the field; expose only with_render_line_highlight_only_when_focus for the proven update callers, with no scalar getter. |
| API-T015.F08 | FIELD | ViewerOptions.render_validation_decorations | render_validation_decorations : @view_model.RenderValidationDecorations | BR,WT,ROOT | OPAQUE | viewer private field; input enum in viewer/common/editor_api | Hide the field; expose only with_render_validation_decorations for the proven update callers, with no scalar getter. |
| API-T015.F09 | FIELD | ViewerOptions.theme | theme : String | WB,ROOT | OPAQUE | viewer private ViewerOptions field | Hide the field; expose only with_theme. It is standalone/global construction state mirrored to DOM theme state, not an editorOptions registration. |
| API-T015.F10 | FIELD | ViewerOptions.placeholder | placeholder : String | WB,ROOT | OPAQUE | viewer private ViewerOptions field | Hide the field; expose only with_placeholder for the proven update callers, with no scalar getter. |
| API-T015.F11 | FIELD | ViewerOptions.line_decorations_width | line_decorations_width : Int | BR,WT,ROOT | OPAQUE | viewer private ViewerOptions field | Hide the field; expose only with_line_decorations_width for the proven update callers, with no scalar getter. |
| API-T015.F12 | FIELD | ViewerOptions.line_numbers_min_chars | line_numbers_min_chars : Int | BR,ROOT | OPAQUE | viewer private ViewerOptions field | Hide the field; expose only with_line_numbers_min_chars for the proven update callers, with no scalar getter. |
| API-T015.F13 | FIELD | ViewerOptions.folding | folding : Bool | ROOT | OPAQUE | viewer private ViewerOptions field | Hide the field; no builder or getter is justified, so it remains constructor/root-private state only. |
| API-T015.F14 | FIELD | ViewerOptions.show_folding_controls | show_folding_controls : @moonbit-community/editor/viewer/contrib/folding/browser.ShowFoldingControls | ROOT | OPAQUE | viewer private field; input enum in viewer/common/editor_api | Hide the field; no builder or getter is justified, so it remains constructor/root-private state only. |
| API-T015.F15 | FIELD | ViewerOptions.folding_highlight | folding_highlight : Bool | ROOT | OPAQUE | viewer private ViewerOptions field | Hide the field; no builder or getter is justified, so it remains constructor/root-private state only. |
| API-T015.F16 | FIELD | ViewerOptions.folding_maximum_regions | folding_maximum_regions : Int | ROOT | OPAQUE | viewer private ViewerOptions field | Hide the field; no builder or getter is justified, so it remains constructor/root-private state only. |
| API-T015.F17 | FIELD | ViewerOptions.unfold_on_click_after_end_of_line | unfold_on_click_after_end_of_line : Bool | ROOT | OPAQUE | viewer private ViewerOptions field | Hide the field; no builder or getter is justified, so it remains constructor/root-private state only. |
| API-T015.F18 | FIELD | ViewerOptions.smooth_scrolling | smooth_scrolling : Bool | WT,ROOT | OPAQUE | viewer private ViewerOptions field | Hide the field; no builder or getter is justified, so it remains constructor/root-private state only. |
| API-T015.F19 | FIELD | ViewerOptions.show_unused | show_unused : Bool | ROOT | OPAQUE | viewer private ViewerOptions field | Hide the field; no builder or getter is justified, so it remains constructor/root-private state only. |
| API-T015.F20 | FIELD | ViewerOptions.show_deprecated | show_deprecated : Bool | ROOT | OPAQUE | viewer private ViewerOptions field | Hide the field; no builder or getter is justified, so it remains constructor/root-private state only. |
| API-T015.F21 | FIELD | ViewerOptions.font_family | font_family : String | ROOT | OPAQUE | viewer private ViewerOptions field | Hide the field; no builder or getter is justified, so it remains constructor/root-private state only. |
| API-T015.F22 | FIELD | ViewerOptions.font_weight | font_weight : String | ROOT | OPAQUE | viewer private ViewerOptions field | Hide the field; no builder or getter is justified, so it remains constructor/root-private state only. |
| API-T015.F23 | FIELD | ViewerOptions.font_size | font_size : Double | ROOT | OPAQUE | viewer private ViewerOptions field | Hide the field; no builder or getter is justified, so it remains constructor/root-private state only. |
| API-T015.F24 | FIELD | ViewerOptions.line_height | line_height : Double | BR,ROOT | OPAQUE | viewer private ViewerOptions field | Hide the field; expose only with_line_height and the line_height scalar getter fixed by the closed opaque-options migration. |
| API-T015.F25 | FIELD | ViewerOptions.letter_spacing | letter_spacing : Double | ROOT | OPAQUE | viewer private ViewerOptions field | Hide the field; no builder or getter is justified, so it remains constructor/root-private state only. |
| API-T015.M01 | METHOD | ViewerOptions::ViewerOptions | pub fn ViewerOptions::ViewerOptions(soft_wrap? : Bool, tab_size? : Int, wrapping_indent? : @view_model.WrappingIndent, render_whitespace? : @view_layout.RenderWhitespace, render_control_characters? : Bool, render_line_highlight? : @view_layout.RenderLineHighlight, render_line_highlight_only_when_focus? : Bool, render_validation_decorations? : @view_model.RenderValidationDecorations, theme? : String, placeholder? : String, line_decorations_width? : Int, line_numbers_min_chars? : Int, folding? : Bool, show_folding_controls? : @moonbit-community/editor/viewer/contrib/folding/browser.ShowFoldingControls, folding_highlight? : Bool, folding_maximum_regions? : Int, unfold_on_click_after_end_of_line? : Bool, smooth_scrolling? : Bool, show_unused? : Bool, show_deprecated? : Bool, font_family? : String, font_weight? : String, font_size? : Double, line_height? : Double, letter_spacing? : Double) -> Self | EXT,WB,BR,WT,ROOT | REPLACE | viewer | Use the closed opaque constructor: canonical enums and documented scalars, with tab_size treated as local model/view-model configuration and theme as standalone/global construction state. |
| API-T015.M02 | METHOD | ViewerOptions::default | pub fn ViewerOptions::default() -> Self | WT,ROOT | KEEP | viewer | Preserve public default construction for the opaque option facade. |
| API-T015.M03 | METHOD | ViewerOptions::soft_wrap_column_for_content_width | pub fn ViewerOptions::soft_wrap_column_for_content_width(Self, Double, Double) -> Int | WT,ROOT | REMOVE | viewer private option derivation | Layout/view-model derivation is implementation machinery; keep it callable only inside the root package. |
| API-T015.M04 | METHOD | ViewerOptions::view_model_options | pub fn ViewerOptions::view_model_options(Self, Int, font_info~ : @config.FontInfo, editor_id? : Int) -> @view_model.ViewModelOptions | WT,ROOT | REMOVE | viewer private option derivation | Layout/view-model derivation is implementation machinery; keep it callable only inside the root package. |
| API-T016 | TYPE | ViewerServices | pub(all) struct ViewerServices | WB,BR,WT,ROOT | OPAQUE | viewer | Keep the host-injection facade, hide every concrete field, and add the fixed idempotent bundle dispose lifecycle below. |
| API-T016.F01 | FIELD | ViewerServices.languages | languages : @languages.Languages | WB,BR,ROOT | OPAQUE | viewer private field over viewer/common/languages capability handle | Exact callers prove this capability; hide the concrete service and use an opaque handle owned beside its DTOs/concrete implementation, avoiding an upward dependency from editor_api. |
| API-T016.F02 | FIELD | ViewerServices.markers | markers : @markers.MarkerService | WB,BR,WT,ROOT | OPAQUE | viewer private field over viewer/common/markers capability handle | Exact callers prove this capability; hide the concrete service and use an opaque handle owned beside its DTOs/concrete implementation, avoiding an upward dependency from editor_api. |
| API-T016.F03 | FIELD | ViewerServices.marker_decorations | marker_decorations : @markers.MarkerDecorationsService | BR,WT,ROOT | OPAQUE | viewer private field over viewer/common/markers capability handle | Exact callers prove this capability; hide the concrete service and use an opaque handle owned beside its DTOs/concrete implementation, avoiding an upward dependency from editor_api. |
| API-T016.F04 | FIELD | ViewerServices.agent_feedback | agent_feedback : @agent_feedback.AgentFeedbackService | WB,BR,WT,ROOT | OPAQUE | viewer private field over viewer/common/agent_feedback_api handle | Move only the host/service DTOs and callback handle named below to the allowed common feature API; concrete and UI adapters remain in contrib/agent_feedback. |
| API-T016.F05 | FIELD | ViewerServices.quick_diff | quick_diff : @moonbit-community/editor/viewer/contrib/quick_diff/common.QuickDiffService | BR,WT,ROOT | OPAQUE | viewer private field over viewer/common/quick_diff_api handle | Move the baseline callback handle to the allowed common feature API; concrete service/adapters remain in contrib/quick_diff. |
| API-T016.F06 | FIELD | ViewerServices.log_service | log_service : @log.LogService | WB,WT,ROOT | OPAQUE | viewer private field over platform/log capability handle | Exact callers prove this capability; hide the concrete service and use an opaque handle owned beside its DTOs/concrete implementation, avoiding an upward dependency from editor_api. |
| API-T016.M01 | METHOD | ViewerServices::new | pub fn ViewerServices::new(languages? : @languages.Languages, log_service? : @log.LogService) -> Self | WB,BR,WT,ROOT | REPLACE | viewer | Use the exact LanguageHandle/MarkerDecorationsSource/AgentFeedbackHandle/QuickDiffHandle/LogHandle constructor below and track bundle-created defaults for ViewerServices::dispose. |
| API-T017 | TYPE | ViewerViewModelBuiltEvent | pub(all) struct ViewerViewModelBuiltEvent | WB,ROOT | REMOVE | closed debug-hook migration above | Use the caller-specific closed debug migration above, then remove this root payload item. |
| API-T017.F01 | FIELD | ViewerViewModelBuiltEvent.model | model : @model.TextModel | WB,ROOT | REMOVE | closed debug-hook migration above | Use the caller-specific closed debug migration above, then remove this root payload item. |
| API-T017.F02 | FIELD | ViewerViewModelBuiltEvent.line_count | line_count : Int | WB,ROOT | REMOVE | closed debug-hook migration above | Use the caller-specific closed debug migration above, then remove this root payload item. |
| API-T017.F03 | FIELD | ViewerViewModelBuiltEvent.token_count | token_count : Int | WB,WT,ROOT | REMOVE | closed debug-hook migration above | Use the caller-specific closed debug migration above, then remove this root payload item. |
| API-T017.F04 | FIELD | ViewerViewModelBuiltEvent.diagnostic_count | diagnostic_count : Int | WB,ROOT | REMOVE | closed debug-hook migration above | Use the caller-specific closed debug migration above, then remove this root payload item. |
| API-T017.F05 | FIELD | ViewerViewModelBuiltEvent.tokenize_ms | tokenize_ms : Double | WB,ROOT | REMOVE | closed debug-hook migration above | Use the caller-specific closed debug migration above, then remove this root payload item. |
| API-T017.F06 | FIELD | ViewerViewModelBuiltEvent.build_ms | build_ms : Double | WB,ROOT | REMOVE | closed debug-hook migration above | Use the caller-specific closed debug migration above, then remove this root payload item. |
| API-T018 | TYPE | ViewerViewState | pub(all) struct ViewerViewState | ROOT | OPAQUE | viewer | Keep save/restore as an opaque round-trip token; hide scroll representation so state can evolve. |
| API-T018.F01 | FIELD | ViewerViewState.scroll_top | scroll_top : Double | WT,ROOT | OPAQUE | viewer | Keep save/restore as an opaque round-trip token; hide scroll representation so state can evolve. |
| API-T018.F02 | FIELD | ViewerViewState.scroll_left | scroll_left : Double | WT,ROOT | OPAQUE | viewer | Keep save/restore as an opaque round-trip token; hide scroll representation so state can evolve. |
| API-A001 | ALIAS | ViewZone | pub using @view {type ViewZone} | ROOT | MOVE | viewer/browser | Remove the root alias to consolidated private viewer/browser/view; canonical public descriptor/accessor ownership is viewer/browser. |
| API-A002 | ALIAS | ViewZoneChangeAccessor | pub using @view {type ViewZoneChangeAccessor} | BR,ROOT | MOVE | viewer/browser | Remove the root alias to consolidated private viewer/browser/view; canonical public descriptor/accessor ownership is viewer/browser. |

## Dependency-sensitive service correction

The parent plan suggested common/editor_api for host capability records only if
that owner remains dependency-bottom. Caller and signature inspection proves
that a single aggregate capability package there would depend upward on model
or feature DTOs. Generic viewer/common/editor_api therefore remains value-only.
ViewerServices stays opaque at the root; language, marker, and log handles stay
beside their allowed owners, while custom feature handles use dedicated common
API packages that external hosts are allowed to import:

| Private ViewerServices field | Exact caller buckets | Capability declaration owner |
|---|---|---|
| languages | WB, BR, ROOT | viewer/common/languages.LanguageHandle |
| markers | WB, BR, WT, ROOT | viewer/common/markers.MarkerServiceHandle, constructor-only lower adapter |
| marker_decorations | BR, WT, ROOT | viewer/common/markers.MarkerDecorationsHandle |
| agent_feedback | WB, BR, WT, ROOT | viewer/common/agent_feedback_api.AgentFeedbackHandle |
| quick_diff | BR, WT, ROOT | viewer/common/quick_diff_api.QuickDiffHandle |
| log_service | WB, WT, ROOT | platform/log.LogHandle |

viewer/common/agent_feedback_api contains only AgentFeedback, Kind, State,
NavigationBearing, Added/Change/ReplyAdded/Submitted events, and the callback
handle. UI-only SessionEditorComment plus grouping/sort helpers remain in
viewer/contrib/agent_feedback, preserving agent_feedback/browser. The quick
diff common API owns only the baseline callback handle; concrete services and
adapters remain in contrib.

The marker owner also defines `MarkerDecorationsSource` with exactly two
variants: `MarkerStore(MarkerServiceHandle)` and
`Decorations(MarkerDecorationsHandle)`. The lower service handle contains only
`on_did_change_markers`, `read`, and `remove`, the operations used to construct
the final decorations adapter. The adapter constructor itself is replaced by
the exact, implementable seam:

```text
pub fn MarkerDecorationsService::new(MarkerServiceHandle) -> Self
```

All 17 current non-definition callers retain their concrete `MarkerService`
and pass `markers.marker_service_handle()`.

The opaque common feature handles have public all-callback constructors, so an
external host can implement them without importing either contribution
package:

```text
pub fn AgentFeedbackHandle::new(
  on_did_change_feedback~ : ((AgentFeedbackChangeEvent) -> Unit) -> @common.Disposable,
  on_did_change_navigation~ : ((@common.Uri) -> Unit) -> @common.Disposable,
  is_feedback_enabled~ : (@common.Uri) -> Bool,
  get_feedback~ : (@common.Uri) -> Array[AgentFeedback],
  get_navigation_bearing~ : (@common.Uri, Array[String]) -> AgentFeedbackNavigationBearing,
  add_feedback~ : (@common.Uri, @common.Range, String, AgentFeedbackKind?, AgentFeedbackState?) -> AgentFeedback,
  mark_feedback_submitted~ : (@common.Uri) -> Unit,
  remove_feedback~ : (@common.Uri, String) -> Unit,
  accept_feedback~ : (@common.Uri, String) -> Unit,
  set_navigation_anchor~ : (@common.Uri, String?) -> Unit,
  update_feedback~ : (@common.Uri, String, String) -> Unit,
  add_reply~ : (@common.Uri, String, String) -> Unit,
) -> Self

pub fn QuickDiffHandle::new(
  get_original_content~ : (@common.Uri) -> String?,
  on_did_change_original~ : ((@common.Uri) -> Unit) -> @common.Disposable,
) -> Self
```

Every callback is required and neither constructor owns captured backing
state. The public `AgentFeedbackHandle::add_feedback` operation keeps optional
`kind?` and `state?` arguments and forwards normalized optional values to the
callback, leaving omitted-value defaults with the backing implementation.

The public root constructor is REPLACE, not a public field migration:

```text
pub fn ViewerServices::new(
  languages? : @languages.LanguageHandle,
  markers? : @markers.MarkerDecorationsSource,
  agent_feedback? : @agent_feedback_api.AgentFeedbackHandle,
  quick_diff? : @quick_diff_api.QuickDiffHandle,
  log_service? : @log.LogHandle,
) -> Self
```

Omitted markers make the bundle own default store and decorations backings;
`MarkerStore` leaves the store caller-owned and makes only the generated
decorations adapter bundle-owned; `Decorations` leaves the supplied adapter
caller-owned. This single union prevents ambiguous independent marker
optionals. The dependency companion freezes all adapter method names and the
manifest proof.

ViewerServices gains a public idempotent dispose method. It releases only
default backings created by that bundle, in marker-decorations -> marker-service
-> feedback order; it never disposes a caller-supplied handle. A Viewer calls
it only for the bundle that Viewer created internally. An explicitly supplied
bundle remains caller-owned and may be shared; its owner calls dispose only
after every sharing Viewer is disposed. Callers own and may idempotently dispose
each returned registration/subscription handle. Disposing a bundle-owned
default backing necessarily terminates subscriptions and leases serviced by
that backing; caller-supplied backings and their still-live handles are never
touched by bundle disposal.

tests/browser/moonbit/model_swap/model_swap_scenario.mbt retains a concrete
MarkerService, passes `MarkerStore(service.marker_service_handle())` into
ViewerServices, calls
services.dispose() after the last Viewer for bundle-created decorations and
feedback defaults, then explicitly disposes its retained MarkerService. Any
separately caller-created decorations backing follows the same explicit rule;
no public test bundle factory is added. viewer/lifecycle_ownership_wbtest.mbt
replaces dispose_explicit_services with bundle disposal for bundle-created
defaults and separately disposes injected concrete backings. It verifies
idempotence, default-only release, explicit-handle non-ownership, backing-owned
subscription termination, and shared-bundle ordering.

## Mouse-wrapper name collision

The current viewer/browser.EditorMouseEvent is the raw editor-DOM event, while
root EditorMouseEvent is the public hit-tested pair. The MOVE disposition
renames the raw browser contract to EditorDomMouseEvent and gives the canonical
public name EditorMouseEvent to the hit-tested wrapper in viewer/browser.
PartialEditorMouseEvent moves beside it. Root on_mouse_* methods consume these
browser types directly; no parallel root wrapper or adapter remains.

## View-zone ownership correction

The current generated root surface imports and aliases the consolidated private
viewer/browser/view package. It does not point at the historical view_parts
path. API-V004 is replaced by a root convenience factory returning the
browser-owned descriptor, so external hosts need no direct viewer/browser
import. API-T012.M03 stays at the root with its callback retargeted to the
browser-owned accessor; the callback type remains inferable. API-A001 and
API-A002 move canonical ownership to viewer/browser and the private aliases
disappear. Mutable rendered zone state remains private to browser/view.

## Mechanical reconciliation

Disposition totals:

| Disposition | Rows |
|---|---:|
| KEEP | 85 |
| MOVE | 45 |
| ALIAS | 0 |
| OPAQUE | 36 |
| REPLACE | 7 |
| REMOVE | 37 |
| total | 210 |

Reviewers can mechanically recheck the ledger with:

    file=docs/exec-plans/viewer-public-editor-api-boundary-gate-a-public.md
    rg '^\| API-(V|T|A)[0-9]{3}(\.(V|F|M)[0-9]{2})? \|' "$file" | wc -l
    rg '^\| API-(V|T|A)[0-9]{3}(\.(V|F|M)[0-9]{2})? \|' "$file" \
      | awk -F'|' '{gsub(/^ +| +$/, "", $2); print $2}' | sort | uniq -d
    rg '^\| API-(V|T|A)[0-9]{3}(\.(V|F|M)[0-9]{2})? \|' "$file" \
      | awk -F'|' '{gsub(/^ +| +$/, "", $7); print $7}' \
      | sort | uniq -c
    rg -n '[T]ODO|[T]BD|[D]RAFT|[P]LACEHOLDER' "$file"
    git diff --check -- "$file"

Expected results are 210 rows, no duplicate IDs, only the six terminal labels
with the totals above, no placeholder markers, and a clean diff check.

## Historical review gate

Gate A completed the baseline root public surface but granted no implementation
authority by itself. The user reviewed this ledger together with the upstream
and dependency/interface companions and approved the combined Gate A on
2026-07-14 before implementation began.
