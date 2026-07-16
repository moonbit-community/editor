# Browser View Package Consolidation — Gate A Local Inventory

Status: inventory ready — STOP FOR REVIEW
Date: 2026-07-14
Plan: `docs/exec-plans/browser-view-package-consolidation.md`
Oracle: checked-in `vscode` submodule
Local baseline: recorded repository state

This companion is the complete local-package half of Gate A. It inventories
the current MoonBit packages, production and test declarations, manifests,
generated interfaces, READMEs, callers, collision resolutions, target files,
and CSS delivery path. The upstream member-by-member parity ledger lives in
the sibling Gate A artifact.

No product move is authorized by this document. Every row below has a terminal
structural disposition, but implementation remains stopped for review.

## Counting rules and commands

A local declaration is one top-level item reported by `moon ide outline`:
type, struct, enum, error, function/method, constant/global, external, or test.
Struct fields and enum variants inherit the disposition of their owning type;
public fields and variants are additionally visible in each checked-in
`pkg.generated.mbti` and are covered by the exhaustive visibility rule below.

The denominator was reproduced with:

```sh
rg --files viewer/browser/view viewer/browser/view_layer \
  viewer/browser/view_parts

rg --files viewer/browser/view viewer/browser/view_layer \
  viewer/browser/view_parts -g '*.mbt' \
  -g '!**/*test.mbt' -g '!**/*wbtest.mbt' | xargs wc -l

rg -n '^(async )?test([[:space:]]|$)' \
  viewer/browser/view viewer/browser/view_layer viewer/browser/view_parts \
  -g '*test.mbt' -g '*wbtest.mbt'

moon ide outline <each-production-or-test-file>
moon ide analyze <each-of-the-12-package-directories>

rg -n 'moonbit-community/editor/viewer/browser/(view|view_layer|view_parts/)' \
  -g moon.pkg .

rg -n 'style\.css|<owner-css-name>' scripts/build-web.mbtx
```

The outline reconciliation is:

| Denominator | Count | Terminal disposition |
|---|---:|---|
| Production files | 30 current / 31 target | `STAY` 14 root files; `MOVE` 16 child files; rename `part_fingerprints.mbt` to `view_part.mbt` and extract one `margin.mbt` without changing the declaration denominator |
| Production lines | 9,323 | `PRESERVE`; target is 677 lines below 10,000 |
| Production top-level declarations | 536 | 241 currently public + 295 nonpublic; all listed below |
| Test files | 16 | `STAY` 7 root tests; `MOVE` 9 child tests |
| Named tests | 118 | `PRESERVE`; all labels listed below |
| Test helper declarations | 130 | `PRESERVE`; all listed below |
| Total test top-level declarations | 248 | 118 tests + 130 helpers |
| Total local top-level declarations | 784 | 536 production + 248 test |
| CSS files | 14 / 512 lines | `KEEP PATH AND ORDER` |
| Manifests | 12 | `KEEP+REWRITE` root; `DELETE` 11 children |
| READMEs | 12 / 337 lines | `FOLD` 11 children into root; delete children |
| Generated interfaces | 12 / 859 lines | `REGENERATE` root; `DELETE` 11 children |
| Other asset | `viewer/browser/view/codicon/codicon.ttf` | `KEEP PATH` |

No duplicate named test label exists across the 118 tests. A declaration-name
collision scan over all production and test `.mbt` files found only the two
private symbol pairs recorded under **Collision ledger**.

## Package and artifact denominator

| Current package | Production files / lines | Tests | CSS | Current role | Terminal package disposition |
|---|---:|---:|---:|---|---|
| `viewer/browser/view` | 14 / 3,187 | 7 / 48 | 2 | View, render contexts, dispatcher, lifecycle adapters | `KEEP+EXPAND`; sole target package |
| `viewer/browser/view_layer` | 1 / 359 | 0 / 0 | 0 | Generic retained-row recycler | `MOVE`; delete package artifacts/directory |
| `view_parts/content_widgets` | 1 / 1,164 | 1 / 26 | 1 | Content widget contracts, placement, DOM | `MOVE`; retain directory only as CSS asset owner |
| `view_parts/current_line_highlight` | 1 / 259 | 0 / 0 | 1 | Content-side current-line overlay | `MOVE`; retain directory only as CSS asset owner |
| `view_parts/decorations` | 1 / 372 | 1 / 7 | 1 | Decoration overlay computation | `MOVE`; retain directory only as CSS asset owner |
| `view_parts/editor_scrollbar` | 1 / 57 | 0 / 0 | 0 | Scrollbar ViewPart wrapper | `MOVE`; delete package artifacts/directory |
| `view_parts/margin` | 3 / 217 | 0 / 0 | 2 | Margin current-line, decorations, numbers | `MOVE`; retain directory only as CSS asset owner |
| `view_parts/overlay_widgets` | 1 / 84 | 0 / 0 | 1 | Overlay widget DOM registry | `MOVE`; retain directory only as CSS asset owner |
| `view_parts/selections` | 1 / 421 | 0 / 0 | 2 | Selection overlay computation | `MOVE`; retain directory only as CSS asset owner |
| `view_parts/view_cursors` | 1 / 230 | 1 / 3 | 1 | Cursor state, geometry, DOM | `MOVE`; retain directory only as CSS asset owner |
| `view_parts/view_lines` | 4 / 2,123 | 5 / 31 | 3 | Virtualized rows, geometry, DOM Range | `MOVE` atomically with `view_layer`; retain directory only as CSS asset owner |
| `view_parts/view_zones` | 1 / 850 | 1 / 3 | 0 | Zone registration, whitespace, DOM | `MOVE`; delete package artifacts/directory |
| **Total** | **30 / 9,323** | **16 / 118** | **14** |  | **one MoonBit package** |

For every non-root package, `moon.pkg`, `README.md`, and
`pkg.generated.mbti` end in `DELETE` after source/tests move and README content
is folded. The root versions end in `KEEP+REWRITE`, `KEEP+FOLD`, and
`REGENERATE`, respectively.

## Current dependency graph and target manifest

### Scoped edges

| From | To | Evidence/use | Terminal disposition |
|---|---|---|---|
| `browser/view` | all ten `view_parts/*` packages | root manifest lines 5–14; concrete fields, constructors, lifecycle calls | `REMOVE IMPORT`; calls become local |
| `browser/view` | `browser/view_layer` | root manifest line 15; `ViewOverlays` recycler | `REMOVE IMPORT`; calls become local |
| `view_parts/margin` | `view_parts/current_line_highlight` | shared `CurrentLineHighlightState` | `REMOVE IMPORT`; move atomically |
| `view_parts/view_lines` | `browser/view_layer` | `ViewLayerRenderer::new` at `view_lines.mbt:639` | `REMOVE IMPORT`; move atomically |

There are no other leaf-to-leaf manifest edges.

### Union of non-scoped imports

The sole target `viewer/browser/view/moon.pkg` remains
`supported_targets = "js"` and contains exactly this union, with the aliases
already established by the root or the moving source:

```text
moonbit-community/editor/base/common                         @base_common
moonbit-community/editor/platform/log                        @log (default)
moonbit-community/editor/viewer/browser                      @editor_browser
moonbit-community/editor/viewer/common                       @viewer_common
moonbit-community/editor/viewer/common/core                  @core
moonbit-community/editor/viewer/common/cursor                @cursor
moonbit-community/editor/viewer/common/markers               @markers
moonbit-community/editor/viewer/common/model                 @model
moonbit-community/editor/viewer/common/view_layout           @view_layout
moonbit-community/editor/viewer/common/view_model            @view_model
moonbit-community/editor/viewer/ui/scrollbar                 @scrollbar
moonbit-community/rabbita/dom                                @rdom
```

`viewer/common/model` moves from root wbtest-only import to a production
import because content widgets and view zones use `PositionAffinity` in
production. `viewer/common` is added for `view_lines`. All eleven scoped
imports disappear. Self-package qualifiers such as `@view_lines`,
`@content_widgets`, and `@view_layer` become unqualified names.

## Caller matrix

Manifest search proves exactly four consumers remain outside the target after
the merge. All other current consumers are target-local or are the two scoped
leaf edges above.

| Caller category/package | Current imports | Exact qualified entry points / field-method uses | Target rewrite | Terminal visibility proof |
|---|---|---|---|---|
| Root `viewer` | `view`, `content_widgets`, `editor_scrollbar`, `view_lines`, `view_zones` | 41 direct `@view`, 8 direct `@view_lines`, 3 direct `@view_zones`; direct `View` fields call content widgets, overlay widgets, cursors, lines, zones, scrollbar | keep only `view`; rewrite leaf types to `@view` | root/view/event/config APIs and the named part methods remain public |
| `viewer/browser/controller` | `view`, `view_cursors`, `view_lines` | `HorizontalPosition`, `PartFingerprint`, `PartFingerprints::collect`, `ViewCursorRenderData`, `VIEW_LINE_CLASS_NAME` | keep only `view`; rewrite two leaf owners to `@view` | those five contracts remain public |
| `viewer/contrib/hover/browser` | `content_widgets` | `ContentWidgetHandle`, `ContentWidgetPosition`, `ContentWidgetPositionPreference` in `content_hover_widget.mbt` | import `view`; rewrite `@content_widgets` to `@view` | widget value contracts remain public |
| `tests/browser/moonbit/component` | `content_widgets` | `ContentWidgets`, handle, preference, render context in `browser_geometry_scenario.mbt` | import `view`; rewrite `@content_widgets` to `@view` | direct component-test seam remains public |

The root `viewer` field-level callers are exact:

```text
View.root:
  attach_model.mbt, content_hover_widget_host.mbt, controller_host.mbt,
  input.mbt, viewer.mbt
View.overflow_guard:
  controller_host.mbt, input.mbt
View.view_lines:
  attach_model.mbt, controller_host.mbt
View.view_zones:
  hidden_areas_event_order_wbtest.mbt (test-only direct seam)
View.content_widgets:
  attach_model.mbt, content_hover_widget_host.mbt
View.view_cursors:
  controller_host.mbt
View.overlay_widgets:
  attach_model.mbt, overlay_widgets_host.mbt
View.editor_scrollbar:
  controller_host.mbt, input.mbt, viewer.mbt
```

The direct externally called leaf methods are:

```text
ContentWidgets::{new,add_widget,set_widget_position,
  install_live_view_context,install_live_view_context_with_affinity,
  dom_node,overflowing_content_widgets_dom_node,
  prepare_render_widgets,render_widgets}
EditorScrollbar::{content,scrollable}
OverlayWidgets::{add_widget,remove_widget}
ViewCursors::get_last_render_data
ViewLines::{get_dom_node,get_position_from_dom_info,get_line_width,
  install_geometry_readers,install_live_configuration_reader}
ViewZone::new
ViewZoneChangeAccessor::{add_zone,remove_zone,layout_zone}
ViewZones::{did_render,should_render} (root wbtest seam)
```

These are the current call-site spellings. Milestone D rewrites each primary
`::new` entry in that list to its `Type::Type` spelling as recorded in the
constructor ledger below.

The public root aliases `viewer.ViewZone` and `viewer.ViewZoneChangeAccessor`
currently name the `view_zones` owner. They rewrite to `@view` without changing
the root public names. Browser/model-swap scenarios call the accessor methods
through those root aliases, so they are genuine public contracts, not merely
target-package seams.

## Exhaustive visibility disposition

All 295 currently nonpublic production declarations remain private after
`STAY`/`MOVE`. Of the 241 currently public top-level declarations, only the
following caller-proven set remains public; **every other currently public
declaration becomes private after the merge**. Public fields/variants inherit
their owning carrier's listed disposition.

| Owner | `KEEP PUBLIC` set | Public-carrier field rule |
|---|---|---|
| root view core | `View`; the literal 18-method `KEEP PUBLIC` set in the root-method ledger below; `convert_view_to_model_mouse_target`; `empty_editor_class_name`; `ViewContext`; `ViewRenderInput` | retain the current `View` carrier and fields in this structural plan because eight fields have direct root callers; the later public-boundary plan owns any accessor conversion |
| root event boundary | `ViewEventCollector`; `ViewEvent`; `ViewConfigurationOption`; all event payload types required by those enums; constructors called from root `viewer` | preserve the collector type returned by `begin_view_event_batch`; make payload fields private in Milestone D where root constructs through a constructor; keep `ViewContext`/`ViewRenderInput` fields public because root constructs record literals |
| hit testing | `HorizontalPosition` with readable `left`; `PartFingerprint`; `PartFingerprints`; `PartFingerprint::{to_int,from_int}`; `PartFingerprints::collect` | `HorizontalPosition` remains `pub(all)` until an accessor replaces the controller field read; other geometry carriers become private |
| content widgets | `ContentWidgetPositionPreference`, `ContentWidgetPosition`, `ContentWidgetDimension`, `ContentWidgetRenderedCoordinate`, `ContentWidgetHandle` and its constructor, `ContentWidgets`, `ContentWidgetsRenderContext`, and the externally called methods listed above | value records/context remain constructible; `ContentWidgets` internal state fields become private |
| scrollbar | `EditorScrollbar`, `content`, `scrollable` | all fields, constructor, and DOM getter become private |
| overlay widgets | `OverlayWidgets`, `add_widget`, `remove_widget` | fields, constructor, and node getters become private |
| cursor | `ViewCursorRenderData`, `ViewCursors`, `get_last_render_data` | render-data fields remain readable by controller; cursor implementation fields become private |
| view lines | `VIEW_LINE_CLASS_NAME`, `ViewLineOptions` + constructor, `ViewLinesConfiguration` + constructor, `ViewLines`, the externally called methods listed above, and test seam `render_line_input_for_viewport` | implementation/cache fields and all `ViewLine`/`DomReadingContext` carriers become private |
| view zones | `ViewZone` + constructor, `ViewZoneChangeAccessor` + three methods, `ViewZones`, test-seam methods `did_render` and `should_render` | mutable `ViewZone` delegate fields remain public; implementation owner fields become private |

`ViewEventCollector` and `View::begin_view_event_batch` retain their current
signatures and visibility in this plan. The root caller currently ignores the
returned collector, but changing that signature is not a file-move
requirement; the later public-boundary plan may inventory it separately.
`View::emit_view_events` and `View::with_view_event_batch` have no external
caller and become private in Milestone D without changing their signatures or
bodies.

### Root `View` method visibility ledger — 21/21 declarations

“External caller” here means a caller outside the sole target
`viewer/browser/view` package. Each current root `View::` method has exactly
one terminal row; the target constructor spelling is shown for `View::new`.

| Current method → target spelling | Terminal visibility | Caller evidence |
|---|---|---|
| `View::new` → `View::View` | `KEEP PUBLIC` | `viewer/attach_model.mbt:234`; `viewer/hidden_areas_event_order_wbtest.mbt:83` |
| `View::install_view_zones_context` | `KEEP PUBLIC` | `viewer/attach_model.mbt:237` |
| `View::change_view_zones` | `KEEP PUBLIC` | `viewer/view_zones_host.mbt:65` |
| `View::should_suppress_mouse_down_on_view_zone` | `KEEP PUBLIC` | `viewer/controller_host.mbt:27` |
| `View::add_disposable` | `KEEP PUBLIC` | `viewer/input.mbt:13,88` |
| `View::dispose` | `KEEP PUBLIC` | `viewer/viewer.mbt:188` |
| `View::begin_view_event_batch` | `KEEP PUBLIC` | `viewer/view_event_sources.mbt:19`; preserve returned `ViewEventCollector` |
| `View::end_view_event_batch` | `KEEP PUBLIC` | `viewer/view_event_sources.mbt:29` |
| `View::with_view_event_batch` | `PRIVATE` | no external caller; only target white-box coverage at `view_events_wbtest.mbt:390,397` |
| `View::emit_view_event` | `KEEP PUBLIC` | `viewer/view_event_sources.mbt:7` |
| `View::emit_view_zones_changed_then` | `KEEP PUBLIC` | `viewer/attach_model.mbt:245` |
| `View::emit_view_events` | `PRIVATE` | no external caller; only target white-box coverage at `view_events_wbtest.mbt:254` |
| `View::render` | `KEEP PUBLIC` | `viewer/view_host.mbt:87` |
| `View::get_view_parts_to_render` | `PRIVATE` | target-local calls only at `view.mbt:376,397` |
| `View::is_line_rendered` | `KEEP PUBLIC` | `viewer/reveal.mbt:403` |
| `View::offset_for_column` | `KEEP PUBLIC` | `viewer/view_host.mbt:27`; `viewer/public_read_api.mbt:412,463` |
| `View::line_width` | `KEEP PUBLIC` | `viewer/public_read_api.mbt:432` |
| `View::measure_line_selection` | `KEEP PUBLIC` | `viewer/view_host.mbt:16,19`; `viewer/reveal.mbt:409` |
| `View::visible_range_for_position` | `KEEP PUBLIC` | `viewer/controller_host.mbt:40` |
| `View::install_current_line_configuration_reader` | `KEEP PUBLIC` | `viewer/attach_model.mbt:306` |
| `View::apply_squiggly_theme` | `KEEP PUBLIC` | `viewer/attach_model.mbt:317`; `viewer/viewer.mbt:635` |

The sets are therefore literal: 18 `KEEP PUBLIC` methods and three `PRIVATE`
methods. There is no catch-all “externally used” rule left for `View`.

### Primary-constructor conversion/retention ledger — 45/45 `::new` declarations

The production-scope declaration search finds 45 exact primary `Type::new`
methods. Every one is the type's ordinary construction path, so all 45 end in
`CONVERT` and every call site moves to `Type::Type` in the same coherent
milestone. No signature, default, validation, allocation order, or side effect
changes with the spelling.

| Current constructor → target spelling | Target file | Terminal action |
|---|---|---|
| `HorizontalPosition::new` → `HorizontalPosition::HorizontalPosition` | `rendering_context.mbt` | `CONVERT` |
| `LineVisibleRanges::new` → `LineVisibleRanges::LineVisibleRanges` | `rendering_context.mbt` | `CONVERT` |
| `HorizontalRange::new` → `HorizontalRange::HorizontalRange` | `rendering_context.mbt` | `CONVERT` |
| `FloatHorizontalRange::new` → `FloatHorizontalRange::FloatHorizontalRange` | `rendering_context.mbt` | `CONVERT` |
| `VisibleRanges::new` → `VisibleRanges::VisibleRanges` | `rendering_context.mbt` | `CONVERT` |
| `View::new` → `View::View` | `view.mbt` | `CONVERT+KEEP PUBLIC` |
| `ViewEventCollector::new` → `ViewEventCollector::ViewEventCollector` | `view_event_dispatcher.mbt` | `CONVERT` |
| `ViewEventDispatcher::new` → `ViewEventDispatcher::ViewEventDispatcher` | `view_event_dispatcher.mbt` | `CONVERT` |
| `ViewCursorStateChangedEvent::new` → `ViewCursorStateChangedEvent::ViewCursorStateChangedEvent` | `view_events.mbt` | `CONVERT` |
| `ViewDecorationsChangedEvent::new` → `ViewDecorationsChangedEvent::ViewDecorationsChangedEvent` | `view_events.mbt` | `CONVERT` |
| `ViewFocusChangedEvent::new` → `ViewFocusChangedEvent::ViewFocusChangedEvent` | `view_events.mbt` | `CONVERT` |
| `ViewLinesChangedEvent::new` → `ViewLinesChangedEvent::ViewLinesChangedEvent` | `view_events.mbt` | `CONVERT` |
| `ViewLinesDeletedEvent::new` → `ViewLinesDeletedEvent::ViewLinesDeletedEvent` | `view_events.mbt` | `CONVERT` |
| `ViewLinesInsertedEvent::new` → `ViewLinesInsertedEvent::ViewLinesInsertedEvent` | `view_events.mbt` | `CONVERT` |
| `ViewScrollChangedEvent::new` → `ViewScrollChangedEvent::ViewScrollChangedEvent` | `view_events.mbt` | `CONVERT` |
| `ViewThemeChangedEvent::new` → `ViewThemeChangedEvent::ViewThemeChangedEvent` | `view_events.mbt` | `CONVERT` |
| `ViewTokenChangeRange::new` → `ViewTokenChangeRange::ViewTokenChangeRange` | `view_events.mbt` | `CONVERT` |
| `ViewTokensChangedEvent::new` → `ViewTokensChangedEvent::ViewTokensChangedEvent` | `view_events.mbt` | `CONVERT` |
| `ViewOverlayLine::new` → `ViewOverlayLine::ViewOverlayLine` | `view_overlays.mbt` | `CONVERT` |
| `ViewOverlays::new` → `ViewOverlays::ViewOverlays` | `view_overlays.mbt` | `CONVERT` |
| `ContentViewOverlays::new` → `ContentViewOverlays::ContentViewOverlays` | `view_overlays.mbt` | `CONVERT` |
| `MarginViewOverlays::new` → `MarginViewOverlays::MarginViewOverlays` | `margin.mbt` | `CONVERT` |
| `ViewLayerRenderer::new` → `ViewLayerRenderer::ViewLayerRenderer` | `view_layer.mbt` | `CONVERT` |
| `ContentWidgets::new` → `ContentWidgets::ContentWidgets` | `content_widgets.mbt` | `CONVERT+KEEP PUBLIC` |
| `CurrentLineHighlightState::new` → `CurrentLineHighlightState::CurrentLineHighlightState` | `current_line_highlight.mbt` | `CONVERT` |
| `CurrentLineHighlightOverlay::new` → `CurrentLineHighlightOverlay::CurrentLineHighlightOverlay` | `current_line_highlight.mbt` | `CONVERT` |
| `DecorationsOverlay::new` → `DecorationsOverlay::DecorationsOverlay` | `decorations.mbt` | `CONVERT` |
| `EditorScrollbar::new` → `EditorScrollbar::EditorScrollbar` | `editor_scrollbar.mbt` | `CONVERT` |
| `CurrentLineMarginHighlightOverlay::new` → `CurrentLineMarginHighlightOverlay::CurrentLineMarginHighlightOverlay` | `current_line_margin_highlight.mbt` | `CONVERT` |
| `LineNumbersOverlay::new` → `LineNumbersOverlay::LineNumbersOverlay` | `line_numbers.mbt` | `CONVERT` |
| `LinesDecorationsOverlay::new` → `LinesDecorationsOverlay::LinesDecorationsOverlay` | `lines_decorations.mbt` | `CONVERT` |
| `OverlayWidgets::new` → `OverlayWidgets::OverlayWidgets` | `overlay_widgets.mbt` | `CONVERT` |
| `SelectionsOverlay::new` → `SelectionsOverlay::SelectionsOverlay` | `selections.mbt` | `CONVERT` |
| `ViewCursors::new` → `ViewCursors::ViewCursors` | `view_cursors.mbt` | `CONVERT` |
| `DomReadingContext::new` → `DomReadingContext::DomReadingContext` | `dom_reading_context.mbt` | `CONVERT` |
| `ViewLineOptions::new` → `ViewLineOptions::ViewLineOptions` | `view_line.mbt` | `CONVERT+KEEP PUBLIC` |
| `ViewLine::new` → `ViewLine::ViewLine` | `view_line.mbt` | `CONVERT` |
| `RenderedViewLine::new` → `RenderedViewLine::RenderedViewLine` | `view_line.mbt` | `CONVERT` |
| `ViewLinesConfiguration::new` → `ViewLinesConfiguration::ViewLinesConfiguration` | `view_lines.mbt` | `CONVERT+KEEP PUBLIC` |
| `LastRenderedData::new` → `LastRenderedData::LastRenderedData` | `view_lines.mbt` | `CONVERT` |
| `RunOnceScheduler::new` → `RunOnceScheduler::RunOnceScheduler` | `view_lines.mbt` | `CONVERT`; `new_with_timer` remains the alternate injection path |
| `ViewLines::new` → `ViewLines::ViewLines` | `view_lines.mbt` | `CONVERT` |
| `ViewZone::new` → `ViewZone::ViewZone` | `view_zones.mbt` | `CONVERT+KEEP PUBLIC` |
| `FastViewZoneDomNode::new` → `FastViewZoneDomNode::FastViewZoneDomNode` | `view_zones.mbt` | `CONVERT` |
| `ViewZones::new` → `ViewZones::ViewZones` | `view_zones.mbt` | `CONVERT` |

No primary `::new` row ends in `RETAIN`. The distinct named paths outside that
45-row denominator remain unchanged: `RunOnceScheduler::new_with_timer`
(timer-injection alternate), `HorizontalRange::from` (endpoint conversion),
`RenderingContext::from_viewport` (viewport factory), and
`ViewConfigurationChangedEvent::from_changed_options` (option-set
conversion). `ContentWidgetHandle::ContentWidgetHandle` is already in the
canonical spelling. Dependency-owned constructors such as
`@scrollbar.CachedDomNode::new` are outside this refactor's constructor
denominator.

The entire current public surface of `view_layer`, current-line highlight,
decorations, margin overlays, and selections becomes private because all of
their consumers and tests become target-local.

## Complete production declaration ledger — 536 rows

Every semicolon-separated name below is one `moon ide outline` declaration.
`STAY` and `MOVE` are terminal structural dispositions. Visibility then follows
the exhaustive rule above; no listed declaration is left as a wrapper, alias,
or compatibility package solely for the old package graph.

### Existing target package — 191 declarations (86 public, 105 nonpublic)

| Source and target file | Current public / nonpublic | Complete declaration list | Terminal disposition |
|---|---:|---|---|
| `part_fingerprints.mbt` → `view_part.mbt` | 7 / 3 | `PartFingerprint`; `PartFingerprint::to_int`; `PartFingerprint::from_int`; `PartFingerprints`; `PartFingerprints::write`; `PartFingerprints::read`; `PartFingerprints::collect`; `is_document_body`; `read_data_mprt`; `parent_element` | `STAY+RENAME` to the parent plan's source-shaped core filename; privatize `write`/`read` and private helpers; retain caller-proven fingerprint API |
| `rendering_context.mbt` | 17 / 13 | `ViewRenderInput`; `RenderingContext`; `RestrictedRenderingContext`; `RenderingContext::viewport_from_input`; `RenderingContext::from_viewport`; `RenderingContext::restricted`; `RenderingContext::margin_transform`; `RenderingContext::vertical_offset_for_line`; `RenderingContext::line_height_for_line`; `RenderingContext::visible_range_for_position`; `RenderingContext::lines_visible_ranges_for_range`; `line_visible_ranges_from_raw`; `RenderingContext::content_widgets_render_context`; `HorizontalPosition`; `HorizontalPosition::new`; `LineVisibleRanges`; `LineVisibleRanges::new`; `LineVisibleRanges::first_line`; `LineVisibleRanges::last_line`; `HorizontalRange`; `HorizontalRange::new`; `HorizontalRange::from`; `HorizontalRange::to_string`; `FloatHorizontalRange`; `FloatHorizontalRange::new`; `FloatHorizontalRange::to_string`; `FloatHorizontalRange::compare`; `VisibleRanges`; `VisibleRanges::new`; `js_math_round_to_int` | `STAY`; keep `ViewRenderInput`/`HorizontalPosition`, privatize other geometry carriers after callers become local |
| `selection_measure.mbt` | 5 / 0 | `View::is_line_rendered`; `View::offset_for_column`; `View::line_width`; `View::measure_line_selection`; `View::visible_range_for_position` | `STAY+KEEP PUBLIC`; all five have root/controller callers |
| `squiggly_theme.mbt` | 1 / 4 | `computed_style_property`; `defer_call`; `optional_color`; `read_squiggly_theme_colors`; `View::apply_squiggly_theme` | `STAY`; keep only `View::apply_squiggly_theme` public |
| `view.mbt` | 16 / 3 | `View`; `View::new`; `View::install_view_zones_context`; `View::change_view_zones`; `View::should_suppress_mouse_down_on_view_zone`; `View::add_disposable`; `View::dispose`; `View::begin_view_event_batch`; `View::end_view_event_batch`; `View::with_view_event_batch`; `View::emit_view_event`; `View::emit_view_zones_changed_then`; `View::emit_view_events`; `get_editor_class_name`; `extra_editor_class_name`; `editor_browser_kind`; `empty_editor_class_name`; `View::render`; `View::get_view_parts_to_render` | `STAY`; keep externally called `View` API, privatize `with_view_event_batch`, `emit_view_events`, and unused class-name helper |
| `view_context.mbt` | 1 / 0 | `ViewContext` | `STAY+KEEP PUBLIC`; root constructs it |
| `view_event_dispatcher.mbt` | 3 / 12 | `ViewEventCollector`; `ViewEventCollector::new`; `ViewEventCollector::emit`; `ViewEventCollector::emit_many`; `ViewEventDispatcher`; `ViewEventDispatcher::new`; `ViewEventDispatcher::begin`; `ViewEventDispatcher::end`; `ViewEventDispatcher::emit_view_event_then`; `ViewEventDispatcher::emit_view_event`; `ViewEventDispatcher::emit_view_events`; `ViewEventDispatcher::enqueue`; `ViewEventDispatcher::consume`; `ViewEventDispatcher::finish_consuming`; `ViewEventDispatcher::dispose` | `STAY`; preserve signatures/control flow/collector visibility in this plan; internal dispatcher stays private |
| `view_events.mbt` | 26 / 1 | `ViewConfigurationOption`; `ViewConfigurationChangedEvent`; `ViewConfigurationChangedEvent::from_changed_options`; `ViewConfigurationChangedEvent::has_changed`; `view_configuration_options_contain`; `ViewCursorStateChangedEvent`; `ViewCursorStateChangedEvent::new`; `ViewDecorationsChangedEvent`; `ViewDecorationsChangedEvent::new`; `ViewDecorationsChangedEvent::all`; `ViewFocusChangedEvent`; `ViewFocusChangedEvent::new`; `ViewLinesChangedEvent`; `ViewLinesChangedEvent::new`; `ViewLinesDeletedEvent`; `ViewLinesDeletedEvent::new`; `ViewLinesInsertedEvent`; `ViewLinesInsertedEvent::new`; `ViewScrollChangedEvent`; `ViewScrollChangedEvent::new`; `ViewThemeChangedEvent`; `ViewThemeChangedEvent::new`; `ViewTokenChangeRange`; `ViewTokenChangeRange::new`; `ViewTokensChangedEvent`; `ViewTokensChangedEvent::new`; `ViewEvent` | `STAY`; keep crossing event types and root-called constructors, privatize target-only constructors/helpers |
| `view_lifecycle_handles.mbt` | 0 / 14 | `ViewEventHandlerHandle`; `ViewPartHandle`; `handle_view_event_batch`; `ViewEventHandlerHandle::handle_view_events`; `ViewEventHandlerHandle::on_view_event`; `ViewEventHandlerHandle::force_should_render`; `ViewPartHandle::dispose`; `ViewPartHandle::on_before_render`; `default_view_parts`; `default_view_event_handlers`; `ViewPartHandle::should_render`; `ViewPartHandle::prepare_render`; `ViewPartHandle::render`; `ViewPartHandle::on_did_render` | `STAY+PRIVATE` |
| `view_lines_zones_lifecycle.mbt` | 0 / 4 | `view_zones_on_view_event`; `view_zones_prepare_render`; `view_zones_render`; `view_lines_on_view_event` | `STAY+PRIVATE`; remove former package qualifiers |
| `view_overlays.mbt` → `view_overlays.mbt` | 6 / 21 | `DynamicViewOverlayHandle`; `DynamicViewOverlayHandle::prepare_render`; `DynamicViewOverlayHandle::render`; `render_result_slice`; `ViewOverlays`; `ViewOverlayLine`; `ViewOverlayLine::new`; `ViewOverlayLine::get_dom_node`; `ViewOverlayLine::set_dom_node`; `ViewOverlayLine::on_content_changed`; `ViewOverlayLine::on_tokens_changed`; `ViewOverlayLine::render_line`; `ViewOverlayLine::layout_line`; `ViewOverlays::new`; `ViewOverlays::add_dynamic_overlay`; `ViewOverlays::prepare_overlays`; `ViewOverlays::on_content_or_tokens_changed`; `ViewOverlays::on_focus_changed`; `ViewOverlays::render_focused_class`; `ViewOverlays::render_lines`; `ContentViewOverlays`; `ContentViewOverlays::new`; `ContentViewOverlays::install_content_width_reader`; `ContentViewOverlays::on_configuration_changed`; `ContentViewOverlays::get_dom_node`; `ContentViewOverlays::set_focused`; `View::install_current_line_configuration_reader` | `STAY`; shared/content overlay carriers and helpers remain here; keep only externally called `View::install_current_line_configuration_reader` public |
| `view_overlays.mbt` → `margin.mbt` | 3 / 4 | `MarginViewOverlays`; `MarginViewOverlays::new`; `MarginViewOverlays::attach_view_zones_margin`; `MarginViewOverlays::install_content_left_reader`; `MarginViewOverlays::on_configuration_changed`; `MarginViewOverlays::render_focused`; `MarginViewOverlays::get_dom_node` | `EXTRACT+PRIVATE`; source-shaped margin container/owner unit required by the parent target layout; its seven declarations are removed from the preceding row, so the package subtotal remains 191 |
| `view_overlays_lifecycle.mbt` | 0 / 19 | `current_line_scroll_changed`; `margin_view_overlays_on_view_event`; `margin_view_overlays_prepare_render`; `margin_view_overlays_render`; `prepare_current_line_margin_overlay`; `prepare_lines_decorations_overlay`; `prepare_line_numbers_overlay`; `overlay_widgets_on_view_event`; `overlay_widgets_prepare_render`; `overlay_widgets_render`; `editor_scrollbar_on_view_event`; `editor_scrollbar_prepare_render`; `editor_scrollbar_render`; `content_view_overlays_on_view_event`; `content_view_overlays_prepare_render`; `content_view_overlays_render`; `prepare_current_line_overlay`; `prepare_selections_overlay`; `prepare_decorations_overlay` | `STAY+PRIVATE`; remove all former package qualifiers |
| `view_user_input_events.mbt` | 1 / 1 | `convert_view_to_model_mouse_target`; `convert_view_to_model_view_zone_data` | `STAY`; converter remains public, zone helper private |
| `view_widgets_cursors_lifecycle.mbt` | 0 / 6 | `content_widgets_on_view_event`; `content_widgets_prepare_render`; `content_widgets_render`; `view_cursors_on_view_event`; `view_cursors_prepare_render`; `view_cursors_render` | `STAY+PRIVATE`; remove former package qualifiers |

### Recycler package — 15 declarations (4 public, 11 nonpublic)

| Source → target | Complete declaration list | Terminal disposition |
|---|---|---|
| `view_layer/view_layer_renderer.mbt` → `view/view_layer.mbt` | `RendererContext`; `ViewLayerRenderer`; `ViewLayerRenderer::new`; `ViewLayerRenderer::render`; `ViewLayerRenderer::render_untouched_lines`; `ViewLayerRenderer::insert_lines_before`; `ViewLayerRenderer::remove_lines_before`; `ViewLayerRenderer::insert_lines_after`; `ViewLayerRenderer::remove_lines_after`; `ViewLayerRenderer::finish_rendering_new_lines`; `ViewLayerRenderer::finish_rendering_invalid_lines`; `ViewLayerRenderer::finish_rendering`; `view_layer_string_builder`; `record_view_layer_mutation`; `snapshot_element_children` | `MOVE+RENAME+PRIVATE`, atomically with `view_lines`; delete child package |

### Content widgets — 59 declarations (22 public, 37 nonpublic)

| Source → target | Complete declaration list | Terminal disposition |
|---|---|---|
| `view_parts/content_widgets/content_widgets.mbt` → `view/content_widgets.mbt` | `ContentWidgetPositionPreference`; `ContentWidgetPosition`; `ContentWidgetDimension`; `ContentWidgetRenderedCoordinate`; `ContentWidgetHandle`; `ContentWidgetHandle::ContentWidgetHandle`; `WidgetRenderData`; `PositionPair`; `Widget`; `ContentWidgets`; `ContentWidgets::new`; `ContentWidgets::install_live_view_context`; `ContentWidgets::install_live_view_context_with_affinity`; `ContentWidgets::dom_node`; `ContentWidgets::overflowing_content_widgets_dom_node`; `ContentWidgets::add_widget`; `ContentWidgets::set_widget_position`; `ContentWidgets::on_configuration_changed`; `ContentWidgets::update_anchors_view_positions`; `ContentWidgets::widget_ids_snapshot`; `ContentWidgets::remove_widget`; `ContentWidgets::should_suppress_mouse_down_on_widget`; `ContentWidgetsRenderContext`; `ContentWidgets::on_before_render_widgets`; `ContentWidgets::prepare_render_widgets`; `ContentWidgets::render_widgets`; `AnchorCoordinate`; `BoxLayoutResult`; `content_widget_max_width`; `Widget::apply_max_width`; `Widget::on_configuration_changed`; `position_pair`; `Widget::set_anchor_positions`; `Widget::update_anchor_view_position`; `Widget::on_before_render`; `Widget::prepare_render_widget`; `Widget::anchors_coordinates`; `reduce_anchor_coordinates`; `layout_box_in_viewport`; `DomNodePagePosition`; `dom_node_page_position`; `layout_horizontal_segment_in_page`; `layout_box_in_page`; `Widget::render`; `double_max`; `double_min`; `js_math_round`; `safe_invoke_before_render`; `safe_invoke_after_render`; `element_contains_active_element`; `owner_document_max_width`; `owner_window_scroll_x`; `owner_window_scroll_y`; `dom_helper_window_scroll_x`; `dom_helper_window_scroll_y`; `set_style_property`; `body_client_area`; `body_client_width`; `body_client_height` | `MOVE`; preserve caller-proven widget contracts, privatize lifecycle/placement internals; resolve two private symbol collisions as listed below |

### Current-line highlight — 12 declarations (11 public, 1 nonpublic)

| Source → target | Complete declaration list | Terminal disposition |
|---|---|---|
| `view_parts/current_line_highlight/current_line_highlight.mbt` → `view/current_line_highlight.mbt` | `CurrentLineHighlightState`; `CurrentLineHighlightState::new`; `CurrentLineHighlightState::install_configuration_reader`; `CurrentLineHighlightState::on_configuration_changed`; `CurrentLineHighlightState::on_cursor_state_changed`; `CurrentLineHighlightState::read_from_selections`; `CurrentLineHighlightState::on_focus_changed`; `CurrentLineHighlightOverlay`; `CurrentLineHighlightOverlay::new`; `prepare_current_line_render`; `render_one`; `current_line_span` | `MOVE+PRIVATE`, atomically with margin package |

### Decorations — 10 declarations (5 public, 5 nonpublic)

| Source → target | Complete declaration list | Terminal disposition |
|---|---|---|
| `view_parts/decorations/decorations.mbt` → `view/decorations.mbt` | `DecorationOverlayPiece`; `filter_and_sort_overlay_decorations`; `code_unit_compare`; `compute_decoration_overlay_pieces`; `render_whole_line_decorations`; `render_normal_decorations`; `render_normal_decoration`; `DecorationsOverlay`; `DecorationsOverlay::new`; `prepare_decorations_render` | `MOVE+PRIVATE` |

### Editor scrollbar — 5 declarations (5 public)

| Source → target | Complete declaration list | Terminal disposition |
|---|---|---|
| `view_parts/editor_scrollbar/editor_scrollbar.mbt` → `view/editor_scrollbar.mbt` | `EditorScrollbar`; `EditorScrollbar::new`; `EditorScrollbar::get_dom_node`; `EditorScrollbar::content`; `EditorScrollbar::scrollable` | `MOVE`; keep type plus `content`/`scrollable` public, privatize constructor/DOM getter |

### Margin overlays — 10 declarations (9 public, 1 nonpublic)

| Source → target | Complete declaration list | Terminal disposition |
|---|---|---|
| `view_parts/margin/current_line_highlight.mbt` → `view/current_line_margin_highlight.mbt` | `CurrentLineMarginHighlightOverlay`; `CurrentLineMarginHighlightOverlay::new`; `prepare_current_line_margin_render`; `margin_current_line_span` | `MOVE+RENAME+PRIVATE`, atomically with content current-line unit |
| `view_parts/margin/line_numbers.mbt` → `view/line_numbers.mbt` | `LineNumbersOverlay`; `LineNumbersOverlay::new`; `prepare_line_numbers_render` | `MOVE+PRIVATE` |
| `view_parts/margin/lines_decorations.mbt` → `view/lines_decorations.mbt` | `LinesDecorationsOverlay`; `LinesDecorationsOverlay::new`; `prepare_lines_decorations_render` | `MOVE+PRIVATE` |

### Overlay widgets — 6 declarations (6 public)

| Source → target | Complete declaration list | Terminal disposition |
|---|---|---|
| `view_parts/overlay_widgets/overlay_widgets.mbt` → `view/overlay_widgets.mbt` | `OverlayWidgets`; `OverlayWidgets::new`; `OverlayWidgets::add_widget`; `OverlayWidgets::remove_widget`; `OverlayWidgets::get_dom_node`; `OverlayWidgets::overflowing_overlay_widgets_dom_node` | `MOVE`; keep type/add/remove public, privatize fields/constructor/node getters |

### Selections — 19 declarations (4 public, 15 nonpublic)

| Source → target | Complete declaration list | Terminal disposition |
|---|---|---|
| `view_parts/selections/selections.mbt` → `view/selections.mbt` | `SelectionsOverlay`; `SelectionsOverlay::new`; `CornerStyle`; `StyledRange`; `LineSelectionRanges`; `new_styled_range`; `prepare_selections_render`; `prepare_selections_render_from_visible_ranges`; `render_selection_lines`; `collect_line_selection_ranges`; `visible_ranges_have_gaps`; `enrich_visible_ranges_with_style`; `render_styled_line_html`; `ends_model_line`; `eol_anchor_x`; `selection_class_name`; `editor_background_class_name`; `rounded_piece_width`; `selection_piece_html` | `MOVE+PRIVATE` |

### View cursors — 13 declarations (12 public, 1 nonpublic)

| Source → target | Complete declaration list | Terminal disposition |
|---|---|---|
| `view_parts/view_cursors/view_cursors.mbt` → `view/view_cursors.mbt` | `CursorRenderData`; `ViewCursors`; `ViewCursors::new`; `ViewCursors::get_dom_node`; `cursors_layer_class`; `compute_screen_aware_size`; `device_pixel_ratio`; `prepare_cursor_render_data`; `ViewCursors::render_cursor`; `ViewCursors::on_focus_changed`; `cursor_style`; `ViewCursorRenderData`; `ViewCursors::get_last_render_data` | `MOVE`; retain `ViewCursors`, `ViewCursorRenderData`, and `get_last_render_data`; privatize remaining implementation |

### View lines — 141 declarations (53 public, 88 nonpublic)

| Source → target | Current public / nonpublic | Complete declaration list | Terminal disposition |
|---|---:|---|---|
| `view_parts/view_lines/dom_reading_context.mbt` → `view/dom_reading_context.mbt` | 6 / 2 | `DomReadingContext`; `DomReadingContext::new`; `DomReadingContext::read_client_rect`; `DomReadingContext::client_rect_delta_left`; `DomReadingContext::client_rect_scale`; `DomReadingContext::did_dom_layout`; `DomReadingContext::mark_did_dom_layout`; `element_offset_width` | `MOVE+PRIVATE` atomically with renderer/other line units |
| `view_parts/view_lines/range_util.mbt` → `view/range_util.mbt` | 0 / 21 | `DomNode`; `ClientRectList`; `HandyRangeState`; `handy_ready_range_state`; `range_util_read_horizontal_ranges`; `range_util_read_horizontal_ranges_with_state`; `create_horizontal_ranges_from_client_rects`; `merge_adjacent_ranges`; `max_safe_small_integer`; `new_handy_range_state`; `read_client_rects_with_state`; `element_child_count`; `element_child_has_first_child`; `element_child_first_child_raw`; `element_child_first_child`; `element_child_client_rects`; `dom_node_text_length`; `client_rect_list_is_null`; `client_rect_list_length`; `client_rect_left`; `client_rect_width` | `MOVE+PRIVATE` atomically with renderer/other line units |
| `view_parts/view_lines/view_line.mbt` → `view/view_line.mbt` | 16 / 30 | `VIEW_LINE_CLASS_NAME`; `ViewLineOptions`; `ViewLineOptions::new`; `ViewLineOptions::equals`; `ViewLine`; `ViewLine::new`; `ViewLine::option_snapshot`; `ViewLine::on_content_changed`; `ViewLine::on_tokens_changed`; `ViewLine::on_decorations_changed`; `ViewLine::on_options_changed`; `ViewLine::on_selection_changed`; `ViewLine::get_dom_node`; `ViewLine::set_dom_node`; `ViewLine::mapping`; `ViewLine::layout_line`; `ViewLine::render_line`; `ViewLine::get_width`; `ViewLine::get_width_is_fast`; `ViewLine::reset_cached_width`; `ViewLine::get_visible_ranges_for_range`; `ViewLine::render_input`; `ForeignElementFacts`; `RenderedViewLine`; `RenderedViewLine::new`; `create_rendered_line`; `create_normal_rendered_line`; `RenderedViewLine::get_width`; `RenderedViewLine::get_width_is_fast`; `RenderedViewLine::reset_cached_width`; `RenderedViewLine::get_visible_ranges_for_range`; `RenderedViewLine::read_visible_ranges_for_range`; `RenderedViewLine::read_pixel_offset`; `RenderedViewLine::actual_read_pixel_offset`; `RenderedViewLine::read_raw_visible_ranges_for_range`; `render_input_is_ltr`; `foreign_element_facts`; `string_is_whitespace_only`; `reading_target`; `element_has_first_child`; `element_first_child_offset_width`; `get_column_of_node_offset`; `rendered_view_line_width`; `element_text_content_length`; `count_previous_siblings`; `reading_target_offset_width` | `MOVE`; keep controller/root-test contracts named in visibility table; privatize retained-line implementation |
| `view_parts/view_lines/view_lines.mbt` → `view/view_lines.mbt` | 31 / 35 | `ViewLinesConfiguration`; `ViewLinesConfiguration::new`; `LastRenderedData`; `LastRenderedData::new`; `LastRenderedData::get_current_visible_range`; `LastRenderedData::set_current_visible_range`; `RunOnceScheduler`; `RunOnceScheduler::new`; `RunOnceScheduler::new_with_timer`; `RunOnceScheduler::is_scheduled`; `RunOnceScheduler::schedule`; `RunOnceScheduler::cancel`; `RunOnceScheduler::dispose`; `ViewLines`; `retained_view_line_factory`; `ViewLines::new`; `ViewLines::install_geometry_readers`; `ViewLines::install_live_configuration_reader`; `ViewLines::seed_configuration`; `ViewLines::on_configuration_changed`; `ViewLines::on_options_maybe_changed`; `ViewLines::get_dom_node`; `ViewLines::window_index`; `ViewLines::mapping_at`; `ViewLines::line_node_at`; `ViewLines::flush_retained_lines`; `ViewLines::on_visible_configuration_changed`; `ViewLines::on_visible_scroll_changed`; `ViewLines::on_visible_zones_changed`; `ViewLines::on_lines_changed`; `ViewLines::on_lines_deleted`; `ViewLines::on_lines_inserted`; `ViewLines::on_token_ranges_changed`; `ViewLines::on_selection_changed`; `ViewLines::on_decorations_changed`; `ViewLines::set_retained_start`; `ViewLines::sync_retained_end`; `ViewLines::remove_retained_slice`; `remove_retained_line_dom_nodes`; `remove_retained_line_dom_node`; `ViewLines::render_text`; `viewport_window`; `render_line_input_for_viewport`; `selections_on_line_for`; `ViewLines::get_position_from_dom_info`; `get_view_line_dom_node`; `ViewLines::get_line_number_for`; `ViewLines::get_line_width`; `ViewLines::reset_line_width_caches`; `ViewLines::visible_ranges_for_line_range`; `ViewLines::raw_lines_visible_ranges_for_range`; `ViewLines::raw_visible_range_for_position`; `ViewLines::update_line_widths`; `ViewLines::update_line_widths_fast`; `ViewLines::update_line_widths_slow`; `ViewLines::update_line_widths_slow_if_dom_did_layout`; `ViewLines::update_line_widths_internal`; `ViewLines::ensure_max_line_width`; `ViewLines::dispose`; `element_class_name`; `view_lines_parent_element_raw`; `has_parent_element`; `view_lines_parent_element`; `view_lines_set_timeout`; `view_lines_clear_timeout`; `view_lines_js_math_round_to_int` | `MOVE` atomically with renderer; keep caller-proven ViewLines/config/test seam, privatize lifecycle/cache helpers once local |

### View zones — 55 declarations (24 public, 31 nonpublic)

| Source → target | Complete declaration list | Terminal disposition |
|---|---|---|
| `view_parts/view_zones/view_zones.mbt` → `view/view_zones.mbt` | `ViewZone`; `ViewZone::new`; `FastViewZoneDomNode`; `FastViewZoneDomNode::new`; `FastViewZoneDomNode::set_position`; `FastViewZoneDomNode::set_top`; `FastViewZoneDomNode::set_height`; `FastViewZoneDomNode::set_display`; `FastViewZoneDomNode::set_width`; `RegisteredViewZone`; `ComputedViewZoneProps`; `ViewZonesContext`; `ViewZoneChangeAccessor`; `ViewZoneChangeAccessor::add_zone`; `ViewZoneChangeAccessor::remove_zone`; `ViewZoneChangeAccessor::layout_zone`; `ViewZoneChangeAccessor::assert_valid`; `ViewZoneChangeAccessor::invalidate`; `ViewZones`; `ViewZones::new`; `ViewZones::dom_node`; `ViewZones::margin_dom_node`; `ViewZones::install_context`; `ViewZones::dispose`; `ViewZones::force_should_render`; `ViewZones::should_render`; `ViewZones::did_render`; `ViewZones::refresh_configuration`; `ViewZones::on_configuration_changed`; `ViewZones::on_line_mapping_changed`; `ViewZones::on_lines_deleted`; `ViewZones::on_scroll_changed`; `ViewZones::on_zones_changed`; `ViewZones::on_lines_inserted`; `ViewZones::change_view_zones`; `ViewZones::recompute_whitespace_props`; `ViewZones::zone_keys_snapshot`; `ViewZones::zone_ordinal`; `ViewZones::compute_whitespace_props`; `ViewZones::add_zone`; `ViewZones::remove_zone`; `ViewZones::layout_zone`; `ViewZones::should_suppress_mouse_down_on_view_zone`; `ViewZones::height_in_pixels`; `ViewZones::min_width_in_pixels`; `ViewZones::safe_call_on_computed_height`; `ViewZones::safe_call_on_dom_node_top`; `ViewZones::report_callback_error`; `ViewZones::render`; `offscreen_absolute_top`; `double_max`; `css_pixels`; `css_pixels_double`; `set_style_property`; `remove_element` | `MOVE`; preserve public host delegate/accessor and proved test seam; privatize owner/render internals; resolve two private symbol collisions |

The production subtotal is exactly:

```text
view root 191 + view_layer 15 + content_widgets 59 + current_line 12
+ decorations 10 + editor_scrollbar 5 + margin 10 + overlay_widgets 6
+ selections 19 + view_cursors 13 + view_lines 141 + view_zones 55
= 536 declarations
```

## Collision ledger

The scan normalized every top-level type, method, function, global, and extern
across all 46 `.mbt` files. There are no test-helper collisions and no other
production collisions.

| Collision | Current owners | Source-shaped target resolution | Terminal disposition |
|---|---|---|---|
| basename `current_line_highlight.mbt` | content current-line package; margin package | content keeps `current_line_highlight.mbt`; margin becomes `current_line_margin_highlight.mbt` | `MOVE+RENAME` margin file |
| private `double_max` | `content_widgets.mbt:1015`; `view_zones.mbt:817` | `content_widget_double_max`; `view_zone_double_max` | `RENAME PRIVATE`; keep independent source-unit helpers/control flow |
| JS extern `set_style_property` | `content_widgets.mbt:1111`; `view_zones.mbt:836` | `set_content_widget_style_property`; `set_view_zone_style_property` | `RENAME PRIVATE`; keep independent JS bodies |

All 16 test basenames are unique. CSS basenames are unique, but CSS is not
flattened because the path comments are part of generated output.

## Atomic move groups and target ownership

### Mandatory atomic groups

1. `view_layer` + all four `view_parts/view_lines` production units + five
   line tests. Moving the renderer first would require the old `view_lines`
   package to import its parent while the parent still imports `view_lines`, a
   package cycle. The whole group moves together.
2. `view_parts/current_line_highlight` + all three `view_parts/margin`
   production units. Margin currently imports the current-line state; moving
   either dependency in the source order alone creates the same parent/child
   cycle. The four files move together.

### External-caller-coupled groups

- Content widgets move with manifest/qualifier updates in root `viewer`,
  hover/browser, and the browser geometry component scenario.
- View cursors move with controller's `ViewCursorRenderData` owner update.
- View lines move with controller's class constant and root viewer's config,
  geometry, and rendering test owner updates.
- View zones move with root `viewer` aliases and host constructor updates.
- Editor scrollbar and overlay widgets move with root field-method callers.
- Decorations and their wbtest move together. Selections and the other pure
  overlays have no external consumer after the target-local move.

### Final production file map

| Target file | Source responsibility |
|---|---|
| `view_part.mbt` (rename existing `part_fingerprints.mbt`) | source-shaped view-part fingerprint enum/path traversal; `view_lifecycle_handles.mbt` remains the focused local lifecycle-adapter seam |
| existing `rendering_context.mbt` | read/write rendering contexts and geometry carriers |
| existing `selection_measure.mbt` | View measurement facade |
| existing `squiggly_theme.mbt` | runtime squiggle theme |
| existing `view.mbt` | DOM construction, lifecycle, frame ordering |
| existing `view_context.mbt` | measurement/conversion capabilities |
| existing `view_event_dispatcher.mbt` | reentrant FIFO event batches |
| existing `view_events.mbt` | closed view-event union/payloads |
| existing `view_lifecycle_handles.mbt` | closed handler/part indexes |
| existing `view_lines_zones_lifecycle.mbt` | lines/zones event adapters |
| existing `view_overlays.mbt` | retained shared/content overlay rows and owners |
| existing `view_overlays_lifecycle.mbt` | overlay/scrollbar event adapters |
| existing `view_user_input_events.mbt` | mouse target conversion |
| existing `view_widgets_cursors_lifecycle.mbt` | widget/cursor event adapters |
| new `view_layer.mbt` | generic retained-row recycler |
| new `content_widgets.mbt` | content-widget contracts/placement/DOM |
| new `current_line_highlight.mbt` | content current-line overlay |
| new `current_line_margin_highlight.mbt` | margin current-line overlay |
| new `decorations.mbt` | decoration overlay computation |
| new `editor_scrollbar.mbt` | scrollbar wrapper |
| new `line_numbers.mbt` | line-number overlay |
| new `lines_decorations.mbt` | gutter decoration overlay |
| new `margin.mbt` (extract from `view_overlays.mbt`) | margin container and `MarginViewOverlays` owner cluster |
| new `overlay_widgets.mbt` | overlay-widget registry |
| new `selections.mbt` | selection overlay computation |
| new `view_cursors.mbt` | cursor state/geometry/DOM |
| new `dom_reading_context.mbt` | shared DOM geometry reads |
| new `range_util.mbt` | reusable DOM Range reads |
| new `view_line.mbt` | retained row/rendered-line strategy |
| new `view_lines.mbt` | virtualized line owner/recycler driver |
| new `view_zones.mbt` | zone owner/whitespace/DOM |

This map has 31 target production files: the 30 current files map one-for-one
except that the seven-declaration `MarginViewOverlays` owner cluster is
extracted from `view_overlays.mbt` into the parent plan's required
`margin.mbt`. Renaming `part_fingerprints.mbt` to `view_part.mbt` does not add
a file. The target therefore remains at 536 production declarations and
creates no compatibility wrapper.

## Complete test declaration ledger — 248 rows

The behavior denominator and structural-helper denominator are separate. Every
named test keeps its exact label; every helper stays beside the source unit it
exercises. No test or helper remains in a deleted package.

### Named-test behavior denominator — 118 rows

| Source | Exact test declaration | Terminal disposition |
|---|---|---|
| `viewer/browser/view/editor_class_name_wbtest.mbt:7` | `test "root class defaults include showUnused and showDeprecated" {` | `STAY NAMED TEST` |
| `viewer/browser/view/editor_class_name_wbtest.mbt:20` | `test "show_unused off drops only the showUnused class" {` | `STAY NAMED TEST` |
| `viewer/browser/view/editor_class_name_wbtest.mbt:34` | `test "show_deprecated off drops only the showDeprecated class" {` | `STAY NAMED TEST` |
| `viewer/browser/view/editor_class_name_wbtest.mbt:48` | `test "both off keeps the base classes and focus suffix" {` | `STAY NAMED TEST` |
| `viewer/browser/view/editor_class_name_wbtest.mbt:64` | `test "extra editor classes cover browser and macOS axes" {` | `STAY NAMED TEST` |
| `viewer/browser/view/rendering_context_wbtest.mbt:2` | `test "rendering geometry carriers preserve source rounding and order" {` | `STAY NAMED TEST` |
| `viewer/browser/view/rendering_context_wbtest.mbt:55` | `test "LineVisibleRanges first and last are order independent with strict ties" {` | `STAY NAMED TEST` |
| `viewer/browser/view/rendering_context_wbtest.mbt:88` | `test "RenderingContext DOM facade returns null without rendered ViewLines" {` | `STAY NAMED TEST` |
| `viewer/browser/view/rendering_context_wbtest.mbt:115` | `test "RenderingContext snapshots current viewport and forwards includeViewZones" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_events_wbtest.mbt:35` | `test "source-shaped payloads retain independent fields and array identity" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_events_wbtest.mbt:86` | `test "dispatcher gives every handler a whole batch before reentrant FIFO batch" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_events_wbtest.mbt:118` | `test "ViewZones outgoing continuation waits for reentrant internal delivery" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_events_wbtest.mbt:146` | `test "nested begin shares one collector and only outer end flushes" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_events_wbtest.mbt:166` | `test "hidden-area batch delivers mapping events before recovery scroll" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_events_wbtest.mbt:231` | `test "View dispatcher retains eight handlers in source order and gives each the full batch" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_events_wbtest.mbt:297` | `test "view-event batch visits every event and accumulates sticky dirty once" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_events_wbtest.mbt:336` | `test "dynamic overlay subsets preserve registration order and line slicing" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_events_wbtest.mbt:387` | `test "generic View batch returns a value and always closes on error" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_events_wbtest.mbt:511` | `test "ViewLines propagates changed token decoration option and selection invalidators per retained row" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_events_wbtest.mbt:717` | `test "ViewLines changed range notifies every retained row through the inclusive endpoint" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_events_wbtest.mbt:766` | `test "ViewLines option equality catches same-space font render axes" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_events_wbtest.mbt:814` | `test "ViewLines deletion reconciles start rows and removes only evicted DOM nodes" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_events_wbtest.mbt:885` | `test "ViewLines insertion shifts or recycles rows and removes displaced tail DOM" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_events_wbtest.mbt:965` | `test "ViewLines empty flush resets to one and defers ordinary DOM replacement" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_events_wbtest.mbt:1016` | `test "cursor state then focus uses new selection shape and focus returns false" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_events_wbtest.mbt:1139` | `test "ContentWidgets handlers refresh layout and reproject every mapping event" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_events_wbtest.mbt:1200` | `test "ContentWidgets and ViewZones source handler matrices" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_events_wbtest.mbt:1311` | `test "overlay aggregates, OverlayWidgets, and EditorScrollbar handler matrix" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_events_wbtest.mbt:1456` | `test "ViewLines and ViewCursors cover four scroll flags and token endpoints" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_events_wbtest.mbt:1582` | `test "current-line predicate ignores same-line column moves but tracks emptiness" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_events_wbtest.mbt:1719` | `test "View renders text before prepare and completes all prepares before writes" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_events_wbtest.mbt:1830` | `test "grouped same-line cursor over-render retains caches and performs zero DOM writes" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_lifecycle_wbtest.mbt:94` | `test "View mounts both ViewZones containers at the source relative positions" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_lifecycle_wbtest.mbt:134` | `test "View disposes ViewParts before its lifetime store exactly once" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_part_test.mbt:4` | `test "part fingerprint numeric slots round-trip" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_user_input_events_wbtest.mbt:35` | `test "convertViewToModelMouseTarget converts every target arm" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_zones_branch_matrix_wbtest.mbt:158` | `test "ViewZones maps zero, first, middle, last, and clamped model anchors" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_zones_branch_matrix_wbtest.mbt:208` | `test "ViewZones forwards every affinity at wrap and injected-text boundaries" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_zones_branch_matrix_wbtest.mbt:292` | `test "ViewZones hidden-area omitted false and true toggle exact heights" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_zones_branch_matrix_wbtest.mbt:431` | `test "ViewZones preserves raw height callbacks through retained ToInt32" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_zones_branch_matrix_wbtest.mbt:493` | `test "ViewZones layoutZone rereads geometry but retains ordinal width and nodes" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_zones_branch_matrix_wbtest.mbt:595` | `test "ViewZones derives explicit zero equal and fallback ordinals" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_zones_branch_matrix_wbtest.mbt:650` | `test "ViewZones line-height bit recomputes and unchanged layout keeps cadence" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_zones_branch_matrix_wbtest.mbt:799` | `test "ViewZones recompute freezes keys but reads future delegates live" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_zones_branch_matrix_wbtest.mbt:880` | `test "ViewZones render freezes keys, writes after callback, and reads live values" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_zones_branch_matrix_wbtest.mbt:976` | `test "panic ViewZones render exposes source stale-future-key failure" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_zones_branch_matrix_wbtest.mbt:1019` | `test "ViewZones contains computed-height throws at first middle and last" {` | `STAY NAMED TEST` |
| `viewer/browser/view/view_zones_branch_matrix_wbtest.mbt:1079` | `test "ViewZones contains DOM-top throws at first middle and last" {` | `STAY NAMED TEST` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:380` | `test "constructor and add preserve container styles and overflow mount choice" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:447` | `test "addWidget reads layout before handle getters in source constructor order" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:472` | `test "panic setWidgetPosition rejects an unknown widget id" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:489` | `test "configuration visits every retained widget and gates layout cache reads" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:604` | `test "onBefore distinguishes null and empty preference and includes viewport endpoints" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:690` | `test "mapping reprojection retains model anchors and visits widgets in key order" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:753` | `test "projection keeps original anchors while exposing clamped and hidden results" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:834` | `test "measured anchors preserve affinity, nullable preference, and per-line geometry" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:933` | `test "all position affinity values forward distinctly and only LeftOfInjectedText owns column-one zero" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:1000` | `test "anchor queries keep same-line secondary and use measured x at later affinity columns" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:1077` | `test "display ownership and read phase preserve source ordering and caches" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:1259` | `test "useDisplayNone and positionability preserve the full display scheduling matrix" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:1356` | `test "prepare snapshot continues after beforeRender removes its current widget" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:1406` | `test "render snapshot continues after afterRender removes its current widget" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:1459` | `test "panic prepare snapshot directly looks up a reentrantly removed future widget" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:1494` | `test "panic render snapshot directly looks up a reentrantly removed future widget" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:1529` | `test "focused off-viewport widgets park without hiding and hidden writes are gated" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:1611` | `test "preference traversal uses first-pass fit then second-pass first option" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:1697` | `test "empty single and mixed preferences preserve source order" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:1815` | `test "ABOVE and BELOW write visible coordinates before afterRender callbacks" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:1894` | `test "secondary anchor reduction preserves primary contact boundaries" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:1962` | `test "viewport layout clamps a nonzero scroll window at inclusive edges" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:2028` | `test "owner document supplies max width, page scroll, and paired clamps" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:2103` | `test "iOS owner visual viewport precedes inner and document client areas" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:2124` | `test "detached owner scroll helpers and page layout use explicit zero fallbacks" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:2170` | `test "page layout keeps 15px and 22px equality boundaries and wide boxes" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/decorations/decorations_wbtest.mbt:65` | `test "keeps className only and sorts by zIndex, className, range starts" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/decorations/decorations_wbtest.mbt:95` | `test "whole-line decorations clamp to the visible window as width:100% pieces" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/decorations/decorations_wbtest.mbt:123` | `test "same-class touching ranges merge into one flushed decoration" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/decorations/decorations_wbtest.mbt:147` | `test "different classes do not merge" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/decorations/decorations_wbtest.mbt:156` | `test "showIfCollapsed pulls an endColumn=1 range back to the previous line" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/decorations/decorations_wbtest.mbt:179` | `test "collapsed range widens to a centered half-width" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/decorations/decorations_wbtest.mbt:208` | `test "shouldFillLineOnLineBreak expands continuing lines to width:100%" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_cursors/view_cursors_wbtest.mbt:2` | `test "cursors_layer_class ports _getClassName's reachable arms" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_cursors/view_cursors_wbtest.mbt:16` | `test "compute_screen_aware_size snaps to the device pixel grid" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_cursors/view_cursors_wbtest.mbt:27` | `test "prepare_cursor_render_data ports the Line-style arm" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_range_wbtest.mbt:15` | `test "DomReadingContext reads delta and scale once with zero-width fallback" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_range_wbtest.mbt:48` | `test "RangeUtil reuses one Range and parks it after success and failure" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_range_wbtest.mbt:113` | `test "RangeUtil normalization clamps scales sorts and merges at exact 0.9" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_range_wbtest.mbt:158` | `test "RangeUtil endpoint branches preserve empty span and prior-span repairs" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_line_wbtest.mbt:79` | `test "ViewLine slow width cache reads once resets and marks layout" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_line_wbtest.mbt:98` | `test "ViewLine absent strategy guards width ranges and layout writes" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_line_wbtest.mbt:131` | `test "ViewLine visible ranges preserve collapsed raw and truncation branches" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_line_wbtest.mbt:190` | `test "ViewLine basic ASCII stabilization uses exact inclusive one-pixel tolerance" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_line_wbtest.mbt:244` | `test "ViewLine empty foreign-content branches distinguish none after before and both" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_line_wbtest.mbt:306` | `test "ViewLine pixel cache whitespace endpoint and prior DOM reuse" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_line_wbtest.mbt:365` | `test "ViewLine row HTML preserves direction padding class and geometry CSS" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_line_wbtest.mbt:406` | `test "panic ViewLine setDomNode rejects absent rendered strategy" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_lines_wbtest.mbt:99` | `test "LastRenderedData initializes and replaces the exact visible Range" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_lines_wbtest.mbt:107` | `test "ViewLines configuration resets widths from exact event bits" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_lines_wbtest.mbt:132` | `test "ViewLines raw multi-line query intersects rounds and adds only model newlines" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_lines_wbtest.mbt:186` | `test "ViewLines newline width skips wraps and shifts RTL left" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_lines_wbtest.mbt:249` | `test "ViewLines converter progression covers first middle final and partial windows" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_lines_wbtest.mbt:326` | `test "ViewLines range integerization keeps JavaScript negative-half rounding" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_lines_wbtest.mbt:333` | `test "ViewLines width sweep preserves one ceil monotonic and full-document reset" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_lines_wbtest.mbt:370` | `test "ViewLines scheduler debounces fires the latest callback and disposes pending work" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_lines_wbtest.mbt:404` | `test "ViewLines 200ms scheduler guards and cancel-before-slow ordering" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/render_whitespace_selection_wbtest.mbt:42` | `test "selection derivation: a selection that misses the line yields no offsets" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/render_whitespace_selection_wbtest.mbt:55` | `test "selection derivation: a partial single-line selection clips to its columns" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/render_whitespace_selection_wbtest.mbt:70` | `test "selection derivation: a non-anchor line clamps to min/max column" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/render_whitespace_selection_wbtest.mbt:87` | `test "selection derivation: an empty per-line range is dropped" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/render_whitespace_selection_wbtest.mbt:100` | `test "selection derivation: only Selection mode gathers offsets" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/retained_lines_wbtest.mbt:34` | `test "retained ViewLine consumes sticky content token decoration and option invalidators" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/retained_lines_wbtest.mbt:67` | `test "retained ViewLine selection invalidates only last-rendered Selection whitespace" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/retained_lines_wbtest.mbt:88` | `test "retained ViewLine skips writes for distinct raw whitespace widths with equal normalized identity" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/retained_lines_wbtest.mbt:114` | `test "retained line factory reads the current option snapshot on every creation" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/retained_lines_wbtest.mbt:126` | `test "ViewLineOptions equality covers every applicable source render axis" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_zones/view_zones_geometry_wbtest.mbt:135` | `test "ViewZones width gate covers below equal above and contentLeft zero nonzero" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_zones/view_zones_geometry_wbtest.mbt:162` | `test "ViewZones writes callbacks and zone geometry before container widths" {` | `MOVE NAMED TEST to viewer/browser/view` |
| `viewer/browser/view_parts/view_zones/view_zones_geometry_wbtest.mbt:202` | `test "ViewZones some to none retains both container widths" {` | `MOVE NAMED TEST to viewer/browser/view` |

### Test-helper structural denominator — 130 rows

| Source | Helper declaration | Terminal disposition |
|---|---|---|
| `viewer/browser/view/view_events_wbtest.mbt:2` | `fn view_event_test_name(event : ViewEvent) -> String {` | `STAY TEST HELPER` |
| `viewer/browser/view/view_events_wbtest.mbt:23` | `fn view_event_test_batch_name(events : Array[ViewEvent]) -> String {` | `STAY TEST HELPER` |
| `viewer/browser/view/view_events_wbtest.mbt:190` | `fn view_event_handler_test_name(handler : ViewEventHandlerHandle) -> String {` | `STAY TEST HELPER` |
| `viewer/browser/view/view_events_wbtest.mbt:204` | `fn view_event_handler_test_dirty(handler : ViewEventHandlerHandle) -> Bool {` | `STAY TEST HELPER` |
| `viewer/browser/view/view_events_wbtest.mbt:218` | `fn view_part_handle_test_name(part : ViewPartHandle) -> String {` | `STAY TEST HELPER` |
| `viewer/browser/view/view_events_wbtest.mbt:270` | `priv struct CountingViewEventHandler {` | `STAY TEST HELPER` |
| `viewer/browser/view/view_events_wbtest.mbt:277` | `fn CountingViewEventHandler::on_view_event(` | `STAY TEST HELPER` |
| `viewer/browser/view/view_events_wbtest.mbt:289` | `fn CountingViewEventHandler::force_should_render(` | `STAY TEST HELPER` |
| `viewer/browser/view/view_events_wbtest.mbt:322` | `fn dynamic_overlay_handle_test_name(` | `STAY TEST HELPER` |
| `viewer/browser/view/view_events_wbtest.mbt:376` | `suberror ViewEventBatchTestError {` | `STAY TEST HELPER` |
| `viewer/browser/view/view_events_wbtest.mbt:381` | `fn fail_view_event_batch(collector : ViewEventCollector) -> Int raise {` | `STAY TEST HELPER` |
| `viewer/browser/view/view_events_wbtest.mbt:408` | `extern "js" fn view_event_test_attribute(` | `STAY TEST HELPER` |
| `viewer/browser/view/view_events_wbtest.mbt:415` | `extern "js" fn view_event_test_attribute_write_count(` | `STAY TEST HELPER` |
| `viewer/browser/view/view_events_wbtest.mbt:422` | `extern "js" fn view_event_test_style_width(element : @rdom.Element) -> String =` | `STAY TEST HELPER` |
| `viewer/browser/view/view_events_wbtest.mbt:426` | `extern "js" fn view_event_test_style_top(element : @rdom.Element) -> String =` | `STAY TEST HELPER` |
| `viewer/browser/view/view_events_wbtest.mbt:430` | `extern "js" fn view_event_test_has_parent(` | `STAY TEST HELPER` |
| `viewer/browser/view/view_events_wbtest.mbt:437` | `extern "js" fn view_event_test_same_node(` | `STAY TEST HELPER` |
| `viewer/browser/view/view_events_wbtest.mbt:444` | `extern "js" fn view_event_test_reset_dom_metrics() -> Unit =` | `STAY TEST HELPER` |
| `viewer/browser/view/view_events_wbtest.mbt:453` | `extern "js" fn view_event_test_style_write_count() -> Int =` | `STAY TEST HELPER` |
| `viewer/browser/view/view_events_wbtest.mbt:457` | `extern "js" fn view_event_test_view_layer_mutation_count() -> Int =` | `STAY TEST HELPER` |
| `viewer/browser/view/view_events_wbtest.mbt:462` | `extern "js" fn view_event_test_clear_dom_metrics() -> Unit =` | `STAY TEST HELPER` |
| `viewer/browser/view/view_events_wbtest.mbt:466` | `fn view_event_test_line_input(` | `STAY TEST HELPER` |
| `viewer/browser/view/view_events_wbtest.mbt:498` | `fn view_event_test_retained_line(` | `STAY TEST HELPER` |
| `viewer/browser/view/view_events_wbtest.mbt:1092` | `fn view_event_test_configuration() -> ViewEvent {` | `STAY TEST HELPER` |
| `viewer/browser/view/view_events_wbtest.mbt:1099` | `fn view_event_test_scroll(` | `STAY TEST HELPER` |
| `viewer/browser/view/view_events_wbtest.mbt:1113` | `fn view_event_test_cursor(selections : Array[@core.Selection]) -> ViewEvent {` | `STAY TEST HELPER` |
| `viewer/browser/view/view_events_wbtest.mbt:1120` | `priv struct ViewEventContentWidget {` | `STAY TEST HELPER` |
| `viewer/browser/view/view_events_wbtest.mbt:1125` | `fn ViewEventContentWidget::content_widget_handle(` | `STAY TEST HELPER` |
| `viewer/browser/view/view_events_wbtest.mbt:1656` | `fn view_event_test_overlay_render_context(` | `STAY TEST HELPER` |
| `viewer/browser/view/view_events_wbtest.mbt:1803` | `fn view_event_test_seed_overlay_row(` | `STAY TEST HELPER` |
| `viewer/browser/view/view_lifecycle_wbtest.mbt:2` | `extern "js" fn install_view_lifecycle_test_browser() -> Unit =` | `STAY TEST HELPER` |
| `viewer/browser/view/view_lifecycle_wbtest.mbt:69` | `extern "js" fn restore_view_lifecycle_test_browser() -> Unit =` | `STAY TEST HELPER` |
| `viewer/browser/view/view_lifecycle_wbtest.mbt:76` | `extern "js" fn view_lifecycle_test_clear_count() -> Int =` | `STAY TEST HELPER` |
| `viewer/browser/view/view_lifecycle_wbtest.mbt:80` | `extern "js" fn view_lifecycle_test_has_parent(` | `STAY TEST HELPER` |
| `viewer/browser/view/view_lifecycle_wbtest.mbt:87` | `extern "js" fn view_lifecycle_test_child_index(` | `STAY TEST HELPER` |
| `viewer/browser/view/view_user_input_events_wbtest.mbt:2` | `fn view_user_input_test_fixture() -> (@view_model.ViewModel, @model.TextModel) {` | `STAY TEST HELPER` |
| `viewer/browser/view/view_user_input_events_wbtest.mbt:19` | `fn assert_view_user_input_position(` | `STAY TEST HELPER` |
| `viewer/browser/view/view_user_input_events_wbtest.mbt:26` | `fn assert_view_user_input_range(range : @base_common.Range) -> Unit raise {` | `STAY TEST HELPER` |
| `viewer/browser/view/view_zones_branch_matrix_wbtest.mbt:2` | `fn view_zones_branch_model(path : String, text : String) -> @model.TextModel {` | `STAY TEST HELPER` |
| `viewer/browser/view/view_zones_branch_matrix_wbtest.mbt:14` | `extern "js" fn view_zones_branch_style(` | `STAY TEST HELPER` |
| `viewer/browser/view/view_zones_branch_matrix_wbtest.mbt:21` | `priv suberror ViewZonesBranchCallbackFailure {` | `STAY TEST HELPER` |
| `viewer/browser/view/view_zones_branch_matrix_wbtest.mbt:26` | `priv struct ViewZonesBranchFixture {` | `STAY TEST HELPER` |
| `viewer/browser/view/view_zones_branch_matrix_wbtest.mbt:36` | `fn view_zones_branch_fixture_from_model(` | `STAY TEST HELPER` |
| `viewer/browser/view/view_zones_branch_matrix_wbtest.mbt:58` | `fn view_zones_branch_fixture(` | `STAY TEST HELPER` |
| `viewer/browser/view/view_zones_branch_matrix_wbtest.mbt:72` | `fn ViewZonesBranchFixture::dispose(self : ViewZonesBranchFixture) -> Unit {` | `STAY TEST HELPER` |
| `viewer/browser/view/view_zones_branch_matrix_wbtest.mbt:79` | `fn ViewZonesBranchFixture::add_zone(` | `STAY TEST HELPER` |
| `viewer/browser/view/view_zones_branch_matrix_wbtest.mbt:89` | `fn ViewZonesBranchFixture::whitespace(` | `STAY TEST HELPER` |
| `viewer/browser/view/view_zones_branch_matrix_wbtest.mbt:102` | `fn ViewZonesBranchFixture::has_whitespace(` | `STAY TEST HELPER` |
| `viewer/browser/view/view_zones_branch_matrix_wbtest.mbt:115` | `fn ViewZonesBranchFixture::add_height_zone(` | `STAY TEST HELPER` |
| `viewer/browser/view/view_zones_branch_matrix_wbtest.mbt:135` | `fn ViewZonesBranchFixture::assert_single_callback_report(` | `STAY TEST HELPER` |
| `viewer/browser/view/view_zones_branch_matrix_wbtest.mbt:146` | `fn view_zones_branch_callback_step(` | `STAY TEST HELPER` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:2` | `extern "js" fn install_content_widgets_test_browser() -> Unit =` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:71` | `extern "js" fn content_widgets_test_make_document(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:96` | `extern "js" fn content_widgets_test_set_rect(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:106` | `extern "js" fn content_widgets_test_set_active_element(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:113` | `extern "js" fn content_widgets_test_clear_active_element(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:119` | `extern "js" fn content_widgets_test_set_main_scroll(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:126` | `extern "js" fn content_widgets_test_with_ios_visual_viewport(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:172` | `extern "js" fn content_widgets_test_clear_events() -> Unit =` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:176` | `extern "js" fn content_widgets_test_log_event(event : String) -> Unit =` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:180` | `extern "js" fn content_widgets_test_events() -> Array[String] =` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:184` | `extern "js" fn content_widgets_test_clear_rect_reads() -> Unit =` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:188` | `extern "js" fn content_widgets_test_rect_reads() -> Int =` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:192` | `extern "js" fn content_widgets_test_style_property(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:199` | `extern "js" fn content_widgets_test_attribute(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:206` | `extern "js" fn content_widgets_test_parent_is(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:213` | `priv struct TestContentWidget {` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:230` | `priv struct GetterOrderWidget {` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:235` | `fn GetterOrderWidget::content_widget_handle(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:252` | `priv suberror TestWidgetCallbackError {` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:257` | `fn TestContentWidget::before_render(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:272` | `fn TestContentWidget::after_render(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:296` | `fn callback_position_name(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:308` | `fn TestContentWidget::content_widget_handle(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:334` | `fn callback_coordinate_name(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:345` | `fn new_test_content_widget(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:1342` | `fn reentrant_content_widgets_context() -> ContentWidgetsRenderContext {` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/content_widgets/content_widgets_wbtest.mbt:1882` | `fn assert_anchor_coordinate(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/decorations/decorations_wbtest.mbt:10` | `fn overlay_dec(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/decorations/decorations_wbtest.mbt:33` | `fn fake_measure(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/decorations/decorations_wbtest.mbt:48` | `fn pieces_for(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_range_wbtest.mbt:6` | `priv type RangeFixture` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_range_wbtest.mbt:9` | `extern "js" fn handy_range_create_count(state : HandyRangeState) -> Int = "(state) => state.createCount"` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_range_wbtest.mbt:12` | `extern "js" fn handy_range_detach_count(state : HandyRangeState) -> Int = "(state) => state.detachCount"` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_range_wbtest.mbt:282` | `extern "js" fn new_range_fixture(kind : String) -> RangeFixture =` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_range_wbtest.mbt:350` | `extern "js" fn range_fixture_root(fixture : RangeFixture) -> @rdom.Element = "(fixture) => fixture.root"` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_range_wbtest.mbt:353` | `extern "js" fn range_fixture_context(fixture : RangeFixture) -> @rdom.Element = "(fixture) => fixture.context"` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_range_wbtest.mbt:356` | `extern "js" fn range_fixture_end_node(fixture : RangeFixture) -> @rdom.Element = "(fixture) => fixture.endNode"` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_range_wbtest.mbt:359` | `extern "js" fn range_fixture_text_node(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_range_wbtest.mbt:365` | `extern "js" fn range_fixture_set_failure(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_range_wbtest.mbt:371` | `extern "js" fn range_fixture_context_read_count(fixture : RangeFixture) -> Int = "(fixture) => fixture.contextReadCount"` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_range_wbtest.mbt:374` | `extern "js" fn range_fixture_last_start_offset(fixture : RangeFixture) -> Int = "(fixture) => fixture.lastStartOffset"` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_range_wbtest.mbt:377` | `extern "js" fn range_fixture_last_end_offset(fixture : RangeFixture) -> Int = "(fixture) => fixture.lastEndOffset"` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_range_wbtest.mbt:380` | `extern "js" fn range_fixture_was_parked(fixture : RangeFixture) -> Bool = "(fixture) => fixture.parked"` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_range_wbtest.mbt:383` | `extern "js" fn range_rects_at_tolerance() -> ClientRectList =` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_range_wbtest.mbt:391` | `extern "js" fn range_rects_above_tolerance() -> ClientRectList =` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_range_wbtest.mbt:398` | `extern "js" fn empty_client_rects() -> ClientRectList = "() => []"` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_range_wbtest.mbt:401` | `extern "js" fn null_client_rects() -> ClientRectList = "() => null"` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_range_wbtest.mbt:404` | `extern "js" fn negative_left_client_rect() -> ClientRectList = "() => [{ left: 90, width: 4 }]"` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_line_wbtest.mbt:7` | `priv type ViewLineFixture` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_line_wbtest.mbt:10` | `fn geometry_line_input(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_line_wbtest.mbt:43` | `fn render_fixture_line(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_line_wbtest.mbt:55` | `fn mapped_fixture_line(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_line_wbtest.mbt:413` | `extern "js" fn new_view_line_fixture(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_line_wbtest.mbt:458` | `extern "js" fn view_line_fixture_line_node(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_line_wbtest.mbt:463` | `extern "js" fn view_line_fixture_context(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_line_wbtest.mbt:468` | `extern "js" fn view_line_fixture_end_node(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_line_wbtest.mbt:473` | `extern "js" fn view_line_fixture_set_width(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_line_wbtest.mbt:479` | `extern "js" fn view_line_fixture_set_first_span_width(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_line_wbtest.mbt:485` | `extern "js" fn view_line_fixture_set_content_first_child(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_line_wbtest.mbt:495` | `extern "js" fn view_line_fixture_range_read_count(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_line_wbtest.mbt:500` | `extern "js" fn view_line_fixture_style(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_lines_wbtest.mbt:5` | `fn geometry_view_lines(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_lines_wbtest.mbt:44` | `priv struct GeometryTimerTask {` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_lines_wbtest.mbt:52` | `priv struct GeometryTimerSpy {` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_lines_wbtest.mbt:59` | `fn GeometryTimerSpy::new() -> GeometryTimerSpy {` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_lines_wbtest.mbt:64` | `fn GeometryTimerSpy::set_timeout(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_lines_wbtest.mbt:76` | `fn GeometryTimerSpy::clear_timeout(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/geometry_view_lines_wbtest.mbt:89` | `fn GeometryTimerSpy::fire_active(self : GeometryTimerSpy) -> Unit {` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/render_whitespace_selection_wbtest.mbt:11` | `fn selection_line_data(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/render_whitespace_selection_wbtest.mbt:32` | `fn view_range(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_lines/retained_lines_wbtest.mbt:5` | `fn retained_line_test_input(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_zones/view_zones_geometry_wbtest.mbt:2` | `extern "js" fn install_view_zones_geometry_test_dom() -> Unit =` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_zones/view_zones_geometry_wbtest.mbt:49` | `extern "js" fn clear_view_zones_geometry_events() -> Unit =` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_zones/view_zones_geometry_wbtest.mbt:53` | `extern "js" fn record_view_zones_geometry_event(value : String) -> Unit =` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_zones/view_zones_geometry_wbtest.mbt:57` | `extern "js" fn view_zones_geometry_events() -> Array[String] =` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_zones/view_zones_geometry_wbtest.mbt:61` | `extern "js" fn view_zones_geometry_style(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_zones/view_zones_geometry_wbtest.mbt:68` | `fn geometry_event_index(events : Array[String], expected : String) -> Int {` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_zones/view_zones_geometry_wbtest.mbt:78` | `fn view_zones_geometry_fixture(` | `MOVE TEST HELPER to viewer/browser/view` |
| `viewer/browser/view_parts/view_zones/view_zones_geometry_wbtest.mbt:126` | `fn render_geometry_zone(` | `MOVE TEST HELPER to viewer/browser/view` |

Reconciliation: 118 named tests + 130 helpers = 248 test declarations.

## Machine-reconciled production declaration rows — 536 rows

This literal row appendix is the audit form of the grouped production ledger.
It uses the same MoonBit outline denominator and terminal visibility rule.

| Source | Declaration | Terminal disposition |
|---|---|---|
| `viewer/browser/view/part_fingerprints.mbt:9` | `pub(all) enum PartFingerprint {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/part_fingerprints.mbt:24` | `pub fn PartFingerprint::to_int(self : PartFingerprint) -> Int {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/part_fingerprints.mbt:41` | `pub fn PartFingerprint::from_int(value : Int) -> PartFingerprint {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/part_fingerprints.mbt:62` | `pub(all) struct PartFingerprints {}` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/part_fingerprints.mbt:65` | `pub fn PartFingerprints::write(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/part_fingerprints.mbt:73` | `pub fn PartFingerprints::read(target : @rdom.Element) -> PartFingerprint {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/part_fingerprints.mbt:82` | `pub fn PartFingerprints::collect(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/part_fingerprints.mbt:101` | `extern "js" fn is_document_body(el : @rdom.Element) -> Bool =` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/part_fingerprints.mbt:105` | `extern "js" fn read_data_mprt(el : @rdom.Element) -> Int =` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/part_fingerprints.mbt:112` | `fn parent_element(el : @rdom.Element) -> @rdom.Element? {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/rendering_context.mbt:7` | `pub(all) struct ViewRenderInput {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/rendering_context.mbt:47` | `priv struct RenderingContext {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/rendering_context.mbt:64` | `priv struct RestrictedRenderingContext {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/rendering_context.mbt:80` | `fn RenderingContext::viewport_from_input(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/rendering_context.mbt:99` | `fn RenderingContext::from_viewport(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/rendering_context.mbt:130` | `fn RenderingContext::restricted(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/rendering_context.mbt:147` | `fn RenderingContext::margin_transform(self : RenderingContext) -> String {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/rendering_context.mbt:153` | `fn RenderingContext::vertical_offset_for_line(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/rendering_context.mbt:166` | `fn RenderingContext::line_height_for_line(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/rendering_context.mbt:177` | `fn RenderingContext::visible_range_for_position(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/rendering_context.mbt:197` | `fn RenderingContext::lines_visible_ranges_for_range(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/rendering_context.mbt:212` | `fn line_visible_ranges_from_raw(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/rendering_context.mbt:230` | `fn RenderingContext::content_widgets_render_context(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/rendering_context.mbt:254` | `pub(all) struct HorizontalPosition {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/rendering_context.mbt:261` | `pub fn HorizontalPosition::new(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/rendering_context.mbt:275` | `pub(all) struct LineVisibleRanges {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/rendering_context.mbt:283` | `pub fn LineVisibleRanges::new(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/rendering_context.mbt:295` | `pub fn LineVisibleRanges::first_line(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/rendering_context.mbt:315` | `pub fn LineVisibleRanges::last_line(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/rendering_context.mbt:334` | `pub(all) struct HorizontalRange {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/rendering_context.mbt:340` | `pub fn HorizontalRange::new(left : Double, width : Double) -> HorizontalRange {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/rendering_context.mbt:345` | `pub fn HorizontalRange::from(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/rendering_context.mbt:358` | `pub fn HorizontalRange::to_string(self : HorizontalRange) -> String {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/rendering_context.mbt:364` | `pub(all) struct FloatHorizontalRange {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/rendering_context.mbt:370` | `pub fn FloatHorizontalRange::new(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/rendering_context.mbt:378` | `pub fn FloatHorizontalRange::to_string(self : FloatHorizontalRange) -> String {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/rendering_context.mbt:383` | `pub fn FloatHorizontalRange::compare(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/rendering_context.mbt:392` | `pub(all) struct VisibleRanges {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/rendering_context.mbt:398` | `pub fn VisibleRanges::new(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/rendering_context.mbt:406` | `fn js_math_round_to_int(value : Double) -> Int {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/selection_measure.mbt:5` | `pub fn View::is_line_rendered(self : View, view_line_number : Int) -> Bool {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/selection_measure.mbt:15` | `pub fn View::offset_for_column(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/selection_measure.mbt:33` | `pub fn View::line_width(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/selection_measure.mbt:50` | `pub fn View::measure_line_selection(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/selection_measure.mbt:75` | `pub fn View::visible_range_for_position(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/squiggly_theme.mbt:13` | `extern "js" fn computed_style_property(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/squiggly_theme.mbt:23` | `extern "js" fn defer_call(callback : () -> Unit) -> Unit =` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/squiggly_theme.mbt:28` | `fn optional_color(value : String) -> String? {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/squiggly_theme.mbt:37` | `fn read_squiggly_theme_colors(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/squiggly_theme.mbt:73` | `pub fn View::apply_squiggly_theme(self : View) -> Unit {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view.mbt:13` | `pub(all) struct View {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view.mbt:34` | `pub fn View::new(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view.mbt:155` | `pub fn View::install_view_zones_context(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view.mbt:171` | `pub fn View::change_view_zones(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view.mbt:180` | `pub fn View::should_suppress_mouse_down_on_view_zone(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view.mbt:190` | `pub fn View::add_disposable(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view.mbt:205` | `pub fn View::dispose(self : View) -> Unit {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view.mbt:229` | `pub fn View::begin_view_event_batch(self : View) -> ViewEventCollector {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view.mbt:234` | `pub fn View::end_view_event_batch(self : View) -> Unit {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view.mbt:241` | `pub fn[T] View::with_view_event_batch(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view.mbt:253` | `pub fn View::emit_view_event(self : View, event : ViewEvent) -> Unit {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view.mbt:264` | `pub fn View::emit_view_zones_changed_then(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view.mbt:277` | `pub fn View::emit_view_events(self : View, events : Array[ViewEvent]) -> Unit {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view.mbt:291` | `fn get_editor_class_name(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view.mbt:315` | `pub fn extra_editor_class_name(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view.mbt:332` | `extern "js" fn editor_browser_kind() -> Int =` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view.mbt:347` | `pub fn empty_editor_class_name(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view.mbt:358` | `pub fn View::render(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view.mbt:415` | `fn View::get_view_parts_to_render(self : View) -> Array[ViewPartHandle] {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_context.mbt:10` | `pub(all) struct ViewContext {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_event_dispatcher.mbt:5` | `pub(all) struct ViewEventCollector {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_event_dispatcher.mbt:10` | `fn ViewEventCollector::new() -> ViewEventCollector {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_event_dispatcher.mbt:15` | `pub fn ViewEventCollector::emit(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_event_dispatcher.mbt:23` | `pub fn ViewEventCollector::emit_many(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_event_dispatcher.mbt:36` | `priv struct ViewEventDispatcher {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_event_dispatcher.mbt:46` | `fn ViewEventDispatcher::new(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_event_dispatcher.mbt:60` | `fn ViewEventDispatcher::begin(self : ViewEventDispatcher) -> ViewEventCollector {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_event_dispatcher.mbt:73` | `fn ViewEventDispatcher::end(self : ViewEventDispatcher) -> Unit {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_event_dispatcher.mbt:94` | `fn ViewEventDispatcher::emit_view_event_then(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_event_dispatcher.mbt:107` | `fn ViewEventDispatcher::emit_view_event(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_event_dispatcher.mbt:122` | `fn ViewEventDispatcher::emit_view_events(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_event_dispatcher.mbt:140` | `fn ViewEventDispatcher::enqueue(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_event_dispatcher.mbt:158` | `fn ViewEventDispatcher::consume(self : ViewEventDispatcher) -> Unit {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_event_dispatcher.mbt:188` | `fn ViewEventDispatcher::finish_consuming(self : ViewEventDispatcher) -> Unit {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_event_dispatcher.mbt:193` | `fn ViewEventDispatcher::dispose(self : ViewEventDispatcher) -> Unit {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_events.mbt:6` | `pub(all) enum ViewConfigurationOption {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_events.mbt:32` | `pub(all) struct ViewConfigurationChangedEvent {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_events.mbt:37` | `pub fn ViewConfigurationChangedEvent::from_changed_options(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_events.mbt:50` | `pub fn ViewConfigurationChangedEvent::has_changed(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_events.mbt:58` | `fn view_configuration_options_contain(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_events.mbt:74` | `pub(all) struct ViewCursorStateChangedEvent {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_events.mbt:81` | `pub fn ViewCursorStateChangedEvent::new(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_events.mbt:93` | `pub(all) struct ViewDecorationsChangedEvent {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_events.mbt:101` | `pub fn ViewDecorationsChangedEvent::new(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_events.mbt:116` | `pub fn ViewDecorationsChangedEvent::all() -> ViewDecorationsChangedEvent {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_events.mbt:126` | `pub(all) struct ViewFocusChangedEvent {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_events.mbt:131` | `pub fn ViewFocusChangedEvent::new(is_focused : Bool) -> ViewFocusChangedEvent {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_events.mbt:138` | `pub(all) struct ViewLinesChangedEvent {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_events.mbt:144` | `pub fn ViewLinesChangedEvent::new(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_events.mbt:152` | `pub(all) struct ViewLinesDeletedEvent {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_events.mbt:158` | `pub fn ViewLinesDeletedEvent::new(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_events.mbt:166` | `pub(all) struct ViewLinesInsertedEvent {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_events.mbt:172` | `pub fn ViewLinesInsertedEvent::new(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_events.mbt:183` | `pub(all) struct ViewScrollChangedEvent {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_events.mbt:195` | `pub fn ViewScrollChangedEvent::new(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_events.mbt:218` | `pub(all) struct ViewThemeChangedEvent {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_events.mbt:223` | `pub fn ViewThemeChangedEvent::new(theme : String) -> ViewThemeChangedEvent {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_events.mbt:229` | `pub(all) struct ViewTokenChangeRange {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_events.mbt:235` | `pub fn ViewTokenChangeRange::new(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_events.mbt:243` | `pub(all) struct ViewTokensChangedEvent {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_events.mbt:248` | `pub fn ViewTokensChangedEvent::new(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_events.mbt:260` | `pub(all) enum ViewEvent {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_lifecycle_handles.mbt:6` | `priv enum ViewEventHandlerHandle {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_lifecycle_handles.mbt:20` | `priv enum ViewPartHandle {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_lifecycle_handles.mbt:33` | `fn handle_view_event_batch(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_lifecycle_handles.mbt:50` | `fn ViewEventHandlerHandle::handle_view_events(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_lifecycle_handles.mbt:60` | `fn ViewEventHandlerHandle::on_view_event(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_lifecycle_handles.mbt:79` | `fn ViewEventHandlerHandle::force_should_render(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_lifecycle_handles.mbt:98` | `fn ViewPartHandle::dispose(self : ViewPartHandle) -> Unit {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_lifecycle_handles.mbt:114` | `fn ViewPartHandle::on_before_render(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_lifecycle_handles.mbt:129` | `fn default_view_parts(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_lifecycle_handles.mbt:152` | `fn default_view_event_handlers(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_lifecycle_handles.mbt:177` | `fn ViewPartHandle::should_render(self : ViewPartHandle) -> Bool {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_lifecycle_handles.mbt:190` | `fn ViewPartHandle::prepare_render(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_lifecycle_handles.mbt:208` | `fn ViewPartHandle::render(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_lifecycle_handles.mbt:224` | `fn ViewPartHandle::on_did_render(self : ViewPartHandle) -> Unit {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_lines_zones_lifecycle.mbt:6` | `fn view_zones_on_view_event(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_lines_zones_lifecycle.mbt:25` | `fn view_zones_prepare_render(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_lines_zones_lifecycle.mbt:33` | `fn view_zones_render(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_lines_zones_lifecycle.mbt:49` | `fn view_lines_on_view_event(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:23` | `priv enum DynamicViewOverlayHandle {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:33` | `fn DynamicViewOverlayHandle::prepare_render(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:50` | `fn DynamicViewOverlayHandle::render(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:74` | `fn render_result_slice(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:90` | `pub struct ViewOverlays {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:103` | `priv struct ViewOverlayLine {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:110` | `fn ViewOverlayLine::new(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:117` | `fn ViewOverlayLine::get_dom_node(self : ViewOverlayLine) -> @rdom.Element? {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:122` | `fn ViewOverlayLine::set_dom_node(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:130` | `fn ViewOverlayLine::on_content_changed(_self : ViewOverlayLine) -> Unit {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:135` | `fn ViewOverlayLine::on_tokens_changed(_self : ViewOverlayLine) -> Unit {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:140` | `fn ViewOverlayLine::render_line(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:174` | `fn ViewOverlayLine::layout_line(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:191` | `fn ViewOverlays::new(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:210` | `fn ViewOverlays::add_dynamic_overlay(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:221` | `fn ViewOverlays::prepare_overlays(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:231` | `fn ViewOverlays::on_content_or_tokens_changed(self : ViewOverlays) -> Unit {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:240` | `fn ViewOverlays::on_focus_changed(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:251` | `fn ViewOverlays::render_focused_class(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:269` | `fn ViewOverlays::render_lines(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:308` | `pub(all) struct ContentViewOverlays {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:320` | `pub fn ContentViewOverlays::new(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:344` | `fn ContentViewOverlays::install_content_width_reader(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:354` | `fn ContentViewOverlays::on_configuration_changed(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:361` | `pub fn ContentViewOverlays::get_dom_node(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:371` | `pub fn ContentViewOverlays::set_focused(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:396` | `pub(all) struct MarginViewOverlays {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:409` | `pub fn MarginViewOverlays::new(document : @rdom.Document) -> MarginViewOverlays {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:439` | `fn MarginViewOverlays::attach_view_zones_margin(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:450` | `fn MarginViewOverlays::install_content_left_reader(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:460` | `fn MarginViewOverlays::on_configuration_changed(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:469` | `fn MarginViewOverlays::render_focused(self : MarginViewOverlays) -> Unit {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:474` | `pub fn MarginViewOverlays::get_dom_node(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays.mbt:484` | `pub fn View::install_current_line_configuration_reader(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays_lifecycle.mbt:2` | `fn current_line_scroll_changed(event : ViewScrollChangedEvent) -> Bool {` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays_lifecycle.mbt:9` | `fn margin_view_overlays_on_view_event(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays_lifecycle.mbt:63` | `fn margin_view_overlays_prepare_render(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays_lifecycle.mbt:73` | `fn margin_view_overlays_render(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays_lifecycle.mbt:106` | `fn prepare_current_line_margin_overlay(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays_lifecycle.mbt:128` | `fn prepare_lines_decorations_overlay(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays_lifecycle.mbt:156` | `fn prepare_line_numbers_overlay(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays_lifecycle.mbt:177` | `fn overlay_widgets_on_view_event(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays_lifecycle.mbt:189` | `fn overlay_widgets_prepare_render(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays_lifecycle.mbt:197` | `fn overlay_widgets_render(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays_lifecycle.mbt:207` | `fn editor_scrollbar_on_view_event(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays_lifecycle.mbt:219` | `fn editor_scrollbar_prepare_render(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays_lifecycle.mbt:227` | `fn editor_scrollbar_render(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays_lifecycle.mbt:247` | `fn content_view_overlays_on_view_event(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays_lifecycle.mbt:295` | `fn content_view_overlays_prepare_render(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays_lifecycle.mbt:306` | `fn content_view_overlays_render(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays_lifecycle.mbt:328` | `fn prepare_current_line_overlay(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays_lifecycle.mbt:354` | `fn prepare_selections_overlay(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_overlays_lifecycle.mbt:383` | `fn prepare_decorations_overlay(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_user_input_events.mbt:16` | `pub fn convert_view_to_model_mouse_target(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_user_input_events.mbt:111` | `fn convert_view_to_model_view_zone_data(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_widgets_cursors_lifecycle.mbt:12` | `fn content_widgets_on_view_event(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_widgets_cursors_lifecycle.mbt:40` | `fn content_widgets_prepare_render(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_widgets_cursors_lifecycle.mbt:51` | `fn content_widgets_render(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_widgets_cursors_lifecycle.mbt:76` | `fn view_cursors_on_view_event(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_widgets_cursors_lifecycle.mbt:140` | `fn view_cursors_prepare_render(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view/view_widgets_cursors_lifecycle.mbt:180` | `fn view_cursors_render(` | `STAY PRODUCTION; apply exhaustive visibility rule` |
| `viewer/browser/view_layer/view_layer_renderer.mbt:8` | `pub(all) struct RendererContext[T] {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_layer/view_layer_renderer.mbt:17` | `pub struct ViewLayerRenderer[T] {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_layer/view_layer_renderer.mbt:36` | `pub fn[T] ViewLayerRenderer::new(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_layer/view_layer_renderer.mbt:61` | `pub fn[T] ViewLayerRenderer::render(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_layer/view_layer_renderer.mbt:131` | `fn[T] ViewLayerRenderer::render_untouched_lines(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_layer/view_layer_renderer.mbt:151` | `fn[T] ViewLayerRenderer::insert_lines_before(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_layer/view_layer_renderer.mbt:168` | `fn[T] ViewLayerRenderer::remove_lines_before(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_layer/view_layer_renderer.mbt:188` | `fn[T] ViewLayerRenderer::insert_lines_after(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_layer/view_layer_renderer.mbt:200` | `fn[T] ViewLayerRenderer::remove_lines_after(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_layer/view_layer_renderer.mbt:221` | `fn[T] ViewLayerRenderer::finish_rendering_new_lines(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_layer/view_layer_renderer.mbt:252` | `fn[T] ViewLayerRenderer::finish_rendering_invalid_lines(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_layer/view_layer_renderer.mbt:277` | `fn[T] ViewLayerRenderer::finish_rendering(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_layer/view_layer_renderer.mbt:341` | `let view_layer_string_builder : StringBuilder = StringBuilder(size_hint=100000)` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_layer/view_layer_renderer.mbt:344` | `extern "js" fn record_view_layer_mutation(kind : String) -> Unit =` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_layer/view_layer_renderer.mbt:356` | `extern "js" fn snapshot_element_children(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:17` | `pub(all) enum ContentWidgetPositionPreference {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:28` | `pub(all) struct ContentWidgetPosition {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:38` | `pub(all) struct ContentWidgetDimension {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:46` | `pub(all) struct ContentWidgetRenderedCoordinate {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:56` | `pub struct ContentWidgetHandle {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:74` | `pub fn ContentWidgetHandle::ContentWidgetHandle(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:104` | `priv enum WidgetRenderData {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:117` | `priv struct PositionPair {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:125` | `priv struct Widget {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:154` | `pub(all) struct ContentWidgets {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:173` | `pub fn ContentWidgets::new(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:206` | `pub fn ContentWidgets::install_live_view_context(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:221` | `pub fn ContentWidgets::install_live_view_context_with_affinity(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:234` | `pub fn ContentWidgets::dom_node(self : ContentWidgets) -> @rdom.Element {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:239` | `pub fn ContentWidgets::overflowing_content_widgets_dom_node(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:249` | `pub fn ContentWidgets::add_widget(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:305` | `pub fn ContentWidgets::set_widget_position(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:353` | `pub fn ContentWidgets::on_configuration_changed(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:370` | `pub fn ContentWidgets::update_anchors_view_positions(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:386` | `fn ContentWidgets::widget_ids_snapshot(self : ContentWidgets) -> Array[String] {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:396` | `pub fn ContentWidgets::remove_widget(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:416` | `pub fn ContentWidgets::should_suppress_mouse_down_on_widget(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:431` | `pub(all) struct ContentWidgetsRenderContext {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:454` | `pub fn ContentWidgets::on_before_render_widgets(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:469` | `pub fn ContentWidgets::prepare_render_widgets(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:486` | `pub fn ContentWidgets::render_widgets(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:499` | `priv struct AnchorCoordinate {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:507` | `priv struct BoxLayoutResult {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:517` | `fn content_widget_max_width(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:527` | `fn Widget::apply_max_width(self : Widget) -> Unit {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:536` | `fn Widget::on_configuration_changed(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:554` | `fn position_pair(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:573` | `fn Widget::set_anchor_positions(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:595` | `fn Widget::update_anchor_view_position(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:613` | `fn Widget::on_before_render(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:633` | `fn Widget::prepare_render_widget(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:742` | `fn Widget::anchors_coordinates(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:788` | `fn reduce_anchor_coordinates(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:815` | `fn layout_box_in_viewport(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:850` | `priv struct DomNodePagePosition {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:857` | `fn dom_node_page_position(node : @rdom.Element) -> DomNodePagePosition {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:877` | `fn layout_horizontal_segment_in_page(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:915` | `fn layout_box_in_page(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:952` | `fn Widget::render(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:1015` | `fn double_max(left : Double, right : Double) -> Double {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:1024` | `fn double_min(left : Double, right : Double) -> Double {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:1035` | `fn js_math_round(value : Double) -> Double {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:1042` | `fn safe_invoke_before_render(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:1053` | `fn safe_invoke_after_render(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:1069` | `extern "js" fn element_contains_active_element(element : @rdom.Element) -> Bool =` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:1079` | `extern "js" fn owner_document_max_width(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:1094` | `extern "js" fn owner_window_scroll_x(element : @rdom.Element) -> Double =` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:1098` | `extern "js" fn owner_window_scroll_y(element : @rdom.Element) -> Double =` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:1102` | `extern "js" fn dom_helper_window_scroll_x(element : @rdom.Element) -> Double =` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:1106` | `extern "js" fn dom_helper_window_scroll_y(element : @rdom.Element) -> Double =` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:1111` | `extern "js" fn set_style_property(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:1121` | `fn body_client_area(node : @rdom.Element) -> (Double, Double) {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:1126` | `extern "js" fn body_client_width(node : @rdom.Element) -> Double =` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/content_widgets/content_widgets.mbt:1148` | `extern "js" fn body_client_height(node : @rdom.Element) -> Double =` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/current_line_highlight/current_line_highlight.mbt:23` | `pub(all) struct CurrentLineHighlightState {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/current_line_highlight/current_line_highlight.mbt:45` | `pub fn CurrentLineHighlightState::new() -> CurrentLineHighlightState {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/current_line_highlight/current_line_highlight.mbt:65` | `pub fn CurrentLineHighlightState::install_configuration_reader(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/current_line_highlight/current_line_highlight.mbt:83` | `pub fn CurrentLineHighlightState::on_configuration_changed(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/current_line_highlight/current_line_highlight.mbt:104` | `pub fn CurrentLineHighlightState::on_cursor_state_changed(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/current_line_highlight/current_line_highlight.mbt:115` | `pub fn CurrentLineHighlightState::read_from_selections(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/current_line_highlight/current_line_highlight.mbt:146` | `pub fn CurrentLineHighlightState::on_focus_changed(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/current_line_highlight/current_line_highlight.mbt:161` | `pub(all) struct CurrentLineHighlightOverlay {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/current_line_highlight/current_line_highlight.mbt:167` | `pub fn CurrentLineHighlightOverlay::new() -> CurrentLineHighlightOverlay {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/current_line_highlight/current_line_highlight.mbt:178` | `pub fn prepare_current_line_render(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/current_line_highlight/current_line_highlight.mbt:227` | `fn render_one(in_margin~ : Bool, exact~ : Bool, width~ : Double) -> String {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/current_line_highlight/current_line_highlight.mbt:240` | `pub fn current_line_span(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/decorations/decorations.mbt:23` | `pub(all) struct DecorationOverlayPiece {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/decorations/decorations.mbt:40` | `fn filter_and_sort_overlay_decorations(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/decorations/decorations.mbt:69` | `fn code_unit_compare(left : String, right : String) -> Int {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/decorations/decorations.mbt:88` | `pub fn compute_decoration_overlay_pieces(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/decorations/decorations.mbt:111` | `fn render_whole_line_decorations(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/decorations/decorations.mbt:147` | `fn render_normal_decorations(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/decorations/decorations.mbt:231` | `fn render_normal_decoration(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/decorations/decorations.mbt:318` | `pub(all) struct DecorationsOverlay {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/decorations/decorations.mbt:323` | `pub fn DecorationsOverlay::new() -> DecorationsOverlay {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/decorations/decorations.mbt:333` | `pub fn prepare_decorations_render(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/editor_scrollbar/editor_scrollbar.mbt:10` | `pub(all) struct EditorScrollbar {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/editor_scrollbar/editor_scrollbar.mbt:17` | `pub fn EditorScrollbar::new(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/editor_scrollbar/editor_scrollbar.mbt:43` | `pub fn EditorScrollbar::get_dom_node(self : EditorScrollbar) -> @rdom.Element {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/editor_scrollbar/editor_scrollbar.mbt:48` | `pub fn EditorScrollbar::content(self : EditorScrollbar) -> @rdom.Element {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/editor_scrollbar/editor_scrollbar.mbt:53` | `pub fn EditorScrollbar::scrollable(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/margin/current_line_highlight.mbt:14` | `pub(all) struct CurrentLineMarginHighlightOverlay {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/margin/current_line_highlight.mbt:20` | `pub fn CurrentLineMarginHighlightOverlay::new() -> CurrentLineMarginHighlightOverlay {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/margin/current_line_highlight.mbt:33` | `pub fn prepare_current_line_margin_render(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/margin/current_line_highlight.mbt:86` | `fn margin_current_line_span(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/margin/line_numbers.mbt:16` | `pub(all) struct LineNumbersOverlay {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/margin/line_numbers.mbt:21` | `pub fn LineNumbersOverlay::new() -> LineNumbersOverlay {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/margin/line_numbers.mbt:30` | `pub fn prepare_line_numbers_render(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/margin/lines_decorations.mbt:12` | `pub(all) struct LinesDecorationsOverlay {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/margin/lines_decorations.mbt:17` | `pub fn LinesDecorationsOverlay::new() -> LinesDecorationsOverlay {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/margin/lines_decorations.mbt:27` | `pub fn prepare_lines_decorations_render(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/overlay_widgets/overlay_widgets.mbt:12` | `pub(all) struct OverlayWidgets {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/overlay_widgets/overlay_widgets.mbt:20` | `pub fn OverlayWidgets::new(document : @rdom.Document) -> OverlayWidgets {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/overlay_widgets/overlay_widgets.mbt:44` | `pub fn OverlayWidgets::add_widget(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/overlay_widgets/overlay_widgets.mbt:61` | `pub fn OverlayWidgets::remove_widget(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/overlay_widgets/overlay_widgets.mbt:75` | `pub fn OverlayWidgets::get_dom_node(self : OverlayWidgets) -> @rdom.Element {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/overlay_widgets/overlay_widgets.mbt:80` | `pub fn OverlayWidgets::overflowing_overlay_widgets_dom_node(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/selections/selections.mbt:13` | `pub(all) struct SelectionsOverlay {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/selections/selections.mbt:18` | `pub fn SelectionsOverlay::new() -> SelectionsOverlay {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/selections/selections.mbt:26` | `priv enum CornerStyle {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/selections/selections.mbt:35` | `priv struct StyledRange {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/selections/selections.mbt:47` | `priv struct LineSelectionRanges {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/selections/selections.mbt:53` | `fn new_styled_range(left : Double, width : Double) -> StyledRange {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/selections/selections.mbt:73` | `pub fn prepare_selections_render(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/selections/selections.mbt:110` | `pub fn prepare_selections_render_from_visible_ranges(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/selections/selections.mbt:129` | `fn render_selection_lines(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/selections/selections.mbt:167` | `fn collect_line_selection_ranges(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/selections/selections.mbt:219` | `fn visible_ranges_have_gaps(lines : Array[LineSelectionRanges]) -> Bool {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/selections/selections.mbt:235` | `fn enrich_visible_ranges_with_style(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/selections/selections.mbt:284` | `fn render_styled_line_html(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/selections/selections.mbt:351` | `fn ends_model_line(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/selections/selections.mbt:374` | `fn eol_anchor_x(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/selections/selections.mbt:395` | `let selection_class_name = "selected-text"` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/selections/selections.mbt:400` | `let editor_background_class_name = "monaco-editor-background"` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/selections/selections.mbt:404` | `let rounded_piece_width = 10.0` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/selections/selections.mbt:409` | `fn selection_piece_html(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_cursors/view_cursors.mbt:20` | `pub(all) struct CursorRenderData {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_cursors/view_cursors.mbt:31` | `pub(all) struct ViewCursors {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_cursors/view_cursors.mbt:61` | `pub fn ViewCursors::new(document : @rdom.Document) -> ViewCursors {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_cursors/view_cursors.mbt:84` | `pub fn ViewCursors::get_dom_node(self : ViewCursors) -> @rdom.Element {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_cursors/view_cursors.mbt:94` | `pub fn cursors_layer_class(has_selection : Bool) -> String {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_cursors/view_cursors.mbt:103` | `pub fn compute_screen_aware_size(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_cursors/view_cursors.mbt:114` | `pub extern "js" fn device_pixel_ratio() -> Double =` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_cursors/view_cursors.mbt:125` | `pub fn prepare_cursor_render_data(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_cursors/view_cursors.mbt:147` | `pub fn ViewCursors::render_cursor(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_cursors/view_cursors.mbt:170` | `pub fn ViewCursors::on_focus_changed(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_cursors/view_cursors.mbt:190` | `fn cursor_style(data : CursorRenderData, visible~ : Bool) -> String {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_cursors/view_cursors.mbt:202` | `pub(all) struct ViewCursorRenderData {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_cursors/view_cursors.mbt:214` | `pub fn ViewCursors::get_last_render_data(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/dom_reading_context.mbt:9` | `pub struct DomReadingContext {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/dom_reading_context.mbt:19` | `pub fn DomReadingContext::new(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/dom_reading_context.mbt:34` | `fn DomReadingContext::read_client_rect(self : DomReadingContext) -> Unit {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/dom_reading_context.mbt:50` | `pub fn DomReadingContext::client_rect_delta_left(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/dom_reading_context.mbt:60` | `pub fn DomReadingContext::client_rect_scale(self : DomReadingContext) -> Double {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/dom_reading_context.mbt:68` | `pub fn DomReadingContext::did_dom_layout(self : DomReadingContext) -> Bool {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/dom_reading_context.mbt:73` | `pub fn DomReadingContext::mark_did_dom_layout(self : DomReadingContext) -> Unit {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/dom_reading_context.mbt:80` | `extern "js" fn element_offset_width(el : @rdom.Element) -> Double =` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/range_util.mbt:12` | `priv type DomNode` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/range_util.mbt:16` | `priv type ClientRectList` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/range_util.mbt:20` | `priv type HandyRangeState` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/range_util.mbt:23` | `let handy_ready_range_state : HandyRangeState = new_handy_range_state()` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/range_util.mbt:26` | `fn range_util_read_horizontal_ranges(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/range_util.mbt:41` | `fn range_util_read_horizontal_ranges_with_state(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/range_util.mbt:111` | `fn create_horizontal_ranges_from_client_rects(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/range_util.mbt:131` | `fn merge_adjacent_ranges(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/range_util.mbt:165` | `let max_safe_small_integer : Int = 1 << 30` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/range_util.mbt:168` | `extern "js" fn new_handy_range_state() -> HandyRangeState =` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/range_util.mbt:172` | `extern "js" fn read_client_rects_with_state(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/range_util.mbt:199` | `extern "js" fn element_child_count(element : @rdom.Element) -> Int = "(element) => element.children.length"` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/range_util.mbt:202` | `extern "js" fn element_child_has_first_child(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/range_util.mbt:208` | `extern "js" fn element_child_first_child_raw(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/range_util.mbt:214` | `fn element_child_first_child(element : @rdom.Element, index : Int) -> DomNode? {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/range_util.mbt:223` | `extern "js" fn element_child_client_rects(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/range_util.mbt:229` | `extern "js" fn dom_node_text_length(node : DomNode) -> Int = "(node) => node.textContent.length"` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/range_util.mbt:232` | `extern "js" fn client_rect_list_is_null(rects : ClientRectList) -> Bool = "(rects) => rects == null"` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/range_util.mbt:235` | `extern "js" fn client_rect_list_length(rects : ClientRectList) -> Int = "(rects) => rects.length"` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/range_util.mbt:238` | `extern "js" fn client_rect_left(rects : ClientRectList, index : Int) -> Double = "(rects, index) => rects[index].left"` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/range_util.mbt:241` | `extern "js" fn client_rect_width(rects : ClientRectList, index : Int) -> Double = "(rects, index) => rects[index].width"` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:9` | `pub const VIEW_LINE_CLASS_NAME : String = "view-line"` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:18` | `pub(all) struct ViewLineOptions {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:33` | `pub fn ViewLineOptions::new(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:62` | `fn ViewLineOptions::equals(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:72` | `pub struct ViewLine {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:83` | `pub fn ViewLine::new(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:90` | `fn ViewLine::option_snapshot(self : ViewLine) -> ViewLineOptions {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:96` | `fn ViewLine::on_content_changed(self : ViewLine) -> Unit {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:102` | `fn ViewLine::on_tokens_changed(self : ViewLine) -> Unit {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:108` | `fn ViewLine::on_decorations_changed(self : ViewLine) -> Unit {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:116` | `fn ViewLine::on_options_changed(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:128` | `fn ViewLine::on_selection_changed(self : ViewLine) -> Bool {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:139` | `pub fn ViewLine::get_dom_node(self : ViewLine) -> @rdom.Element? {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:147` | `pub fn ViewLine::set_dom_node(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:159` | `pub fn ViewLine::mapping(self : ViewLine) -> @view_layout.CharacterMapping? {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:165` | `pub fn ViewLine::layout_line(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:189` | `pub fn ViewLine::render_line(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:244` | `pub fn ViewLine::get_width(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:255` | `pub fn ViewLine::get_width_is_fast(self : ViewLine) -> Bool {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:263` | `pub fn ViewLine::reset_cached_width(self : ViewLine) -> Unit {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:274` | `pub fn ViewLine::get_visible_ranges_for_range(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:310` | `fn ViewLine::render_input(self : ViewLine) -> @view_layout.RenderLineInput? {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:315` | `priv struct ForeignElementFacts {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:321` | `priv struct RenderedViewLine {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:332` | `fn RenderedViewLine::new(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:358` | `let create_rendered_line : (` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:366` | `fn create_normal_rendered_line(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:376` | `fn RenderedViewLine::get_width(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:392` | `fn RenderedViewLine::get_width_is_fast(self : RenderedViewLine) -> Bool {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:400` | `fn RenderedViewLine::reset_cached_width(self : RenderedViewLine) -> Unit {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:412` | `fn RenderedViewLine::get_visible_ranges_for_range(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:444` | `fn RenderedViewLine::read_visible_ranges_for_range(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:469` | `fn RenderedViewLine::read_pixel_offset(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:509` | `fn RenderedViewLine::actual_read_pixel_offset(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:558` | `fn RenderedViewLine::read_raw_visible_ranges_for_range(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:583` | `fn render_input_is_ltr(input : @view_layout.RenderLineInput) -> Bool {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:588` | `fn foreign_element_facts(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:600` | `extern "js" fn string_is_whitespace_only(value : String) -> Bool =` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:604` | `extern "js" fn reading_target(line_node : @rdom.Element) -> @rdom.Element = "(lineNode) => lineNode.firstChild"` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:607` | `extern "js" fn element_has_first_child(element : @rdom.Element) -> Bool = "(element) => Boolean(element.firstChild)"` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:610` | `extern "js" fn element_first_child_offset_width(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:619` | `pub fn get_column_of_node_offset(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:637` | `pub fn rendered_view_line_width(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:652` | `extern "js" fn element_text_content_length(el : @rdom.Element) -> Int =` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:658` | `extern "js" fn count_previous_siblings(el : @rdom.Element) -> Int =` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_line.mbt:670` | `extern "js" fn reading_target_offset_width(line_node : @rdom.Element) -> Double =` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:10` | `pub(all) struct ViewLinesConfiguration {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:19` | `pub fn ViewLinesConfiguration::new(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:57` | `priv struct LastRenderedData {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:62` | `fn LastRenderedData::new() -> LastRenderedData {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:67` | `fn LastRenderedData::get_current_visible_range(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:74` | `fn LastRenderedData::set_current_visible_range(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:82` | `priv struct RunOnceScheduler {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:90` | `fn RunOnceScheduler::new(delay_ms : Int) -> RunOnceScheduler {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:100` | `fn RunOnceScheduler::new_with_timer(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:109` | `fn RunOnceScheduler::is_scheduled(self : RunOnceScheduler) -> Bool {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:114` | `fn RunOnceScheduler::schedule(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:133` | `fn RunOnceScheduler::cancel(self : RunOnceScheduler) -> Unit {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:144` | `fn RunOnceScheduler::dispose(self : RunOnceScheduler) -> Unit {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:151` | `pub(all) struct ViewLines {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:177` | `fn retained_view_line_factory(options : Ref[ViewLineOptions]) -> () -> ViewLine {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:182` | `pub fn ViewLines::new(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:222` | `pub fn ViewLines::install_geometry_readers(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:235` | `pub fn ViewLines::install_live_configuration_reader(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:244` | `fn ViewLines::seed_configuration(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:265` | `pub fn ViewLines::on_configuration_changed(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:297` | `fn ViewLines::on_options_maybe_changed(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:313` | `pub fn ViewLines::get_dom_node(self : ViewLines) -> @rdom.Element {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:320` | `fn ViewLines::window_index(self : ViewLines, view_line_number : Int) -> Int {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:332` | `pub fn ViewLines::mapping_at(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:347` | `pub fn ViewLines::line_node_at(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:364` | `pub fn ViewLines::flush_retained_lines(self : ViewLines) -> Unit {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:373` | `pub fn ViewLines::on_visible_configuration_changed(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:387` | `pub fn ViewLines::on_visible_scroll_changed(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:396` | `pub fn ViewLines::on_visible_zones_changed(self : ViewLines) -> Bool {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:408` | `pub fn ViewLines::on_lines_changed(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:434` | `pub fn ViewLines::on_lines_deleted(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:485` | `pub fn ViewLines::on_lines_inserted(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:537` | `pub fn ViewLines::on_token_ranges_changed(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:567` | `pub fn ViewLines::on_selection_changed(self : ViewLines) -> Bool {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:577` | `pub fn ViewLines::on_decorations_changed(self : ViewLines) -> Unit {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:584` | `fn ViewLines::set_retained_start(self : ViewLines, start : Int) -> Unit {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:589` | `fn ViewLines::sync_retained_end(self : ViewLines) -> Unit {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:597` | `fn ViewLines::remove_retained_slice(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:610` | `fn remove_retained_line_dom_nodes(lines : Array[ViewLine]) -> Unit {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:620` | `extern "js" fn remove_retained_line_dom_node(node : @rdom.Element) -> Unit =` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:630` | `pub fn ViewLines::render_text(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:694` | `pub fn viewport_window(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:706` | `pub fn render_line_input_for_viewport(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:747` | `fn selections_on_line_for(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:786` | `pub fn ViewLines::get_position_from_dom_info(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:824` | `fn get_view_line_dom_node(node : @rdom.Element) -> @rdom.Element? {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:839` | `fn ViewLines::get_line_number_for(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:857` | `pub fn ViewLines::get_line_width(self : ViewLines, line_number : Int) -> Double {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:873` | `pub fn ViewLines::reset_line_width_caches(self : ViewLines) -> Unit {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:881` | `pub fn ViewLines::visible_ranges_for_line_range(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:906` | `pub fn ViewLines::raw_lines_visible_ranges_for_range(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:997` | `pub fn ViewLines::raw_visible_range_for_position(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:1011` | `pub fn ViewLines::update_line_widths(self : ViewLines) -> Unit {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:1016` | `fn ViewLines::update_line_widths_fast(self : ViewLines) -> Bool {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:1021` | `fn ViewLines::update_line_widths_slow(self : ViewLines) -> Unit {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:1026` | `fn ViewLines::update_line_widths_slow_if_dom_did_layout(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:1041` | `fn ViewLines::update_line_widths_internal(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:1068` | `fn ViewLines::ensure_max_line_width(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:1083` | `pub fn ViewLines::dispose(self : ViewLines) -> Unit {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:1090` | `extern "js" fn element_class_name(el : @rdom.Element) -> String =` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:1094` | `extern "js" fn view_lines_parent_element_raw(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:1100` | `extern "js" fn has_parent_element(el : @rdom.Element) -> Bool =` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:1104` | `fn view_lines_parent_element(el : @rdom.Element) -> @rdom.Element? {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:1113` | `extern "js" fn view_lines_set_timeout(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:1119` | `extern "js" fn view_lines_clear_timeout(handle : Double) -> Unit = "(handle) => globalThis.clearTimeout(handle)"` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_lines/view_lines.mbt:1125` | `fn view_lines_js_math_round_to_int(value : Double) -> Int {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:11` | `pub(all) struct ViewZone {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:31` | `pub fn ViewZone::new(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:68` | `priv struct FastViewZoneDomNode {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:78` | `fn FastViewZoneDomNode::new(element : @rdom.Element) -> FastViewZoneDomNode {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:83` | `fn FastViewZoneDomNode::set_position(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:95` | `fn FastViewZoneDomNode::set_top(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:107` | `fn FastViewZoneDomNode::set_height(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:119` | `fn FastViewZoneDomNode::set_display(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:131` | `fn FastViewZoneDomNode::set_width(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:144` | `priv struct RegisteredViewZone {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:157` | `priv struct ComputedViewZoneProps {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:166` | `priv struct ViewZonesContext {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:177` | `pub struct ViewZoneChangeAccessor {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:186` | `pub fn ViewZoneChangeAccessor::add_zone(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:198` | `pub fn ViewZoneChangeAccessor::remove_zone(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:212` | `pub fn ViewZoneChangeAccessor::layout_zone(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:225` | `fn ViewZoneChangeAccessor::assert_valid(self : ViewZoneChangeAccessor) -> Unit {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:232` | `fn ViewZoneChangeAccessor::invalidate(self : ViewZoneChangeAccessor) -> Unit {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:239` | `pub(all) struct ViewZones {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:254` | `pub fn ViewZones::new(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:293` | `pub fn ViewZones::dom_node(self : ViewZones) -> @rdom.Element {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:298` | `pub fn ViewZones::margin_dom_node(self : ViewZones) -> @rdom.Element {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:305` | `pub fn ViewZones::install_context(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:323` | `pub fn ViewZones::dispose(self : ViewZones) -> Unit {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:334` | `pub fn ViewZones::force_should_render(self : ViewZones) -> Unit {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:341` | `pub fn ViewZones::should_render(self : ViewZones) -> Bool {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:346` | `pub fn ViewZones::did_render(self : ViewZones) -> Unit {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:351` | `fn ViewZones::refresh_configuration(self : ViewZones) -> Unit {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:362` | `pub fn ViewZones::on_configuration_changed(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:374` | `pub fn ViewZones::on_line_mapping_changed(self : ViewZones) -> Bool {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:379` | `pub fn ViewZones::on_lines_deleted(_self : ViewZones) -> Bool {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:384` | `pub fn ViewZones::on_scroll_changed(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:393` | `pub fn ViewZones::on_zones_changed(_self : ViewZones) -> Bool {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:398` | `pub fn ViewZones::on_lines_inserted(_self : ViewZones) -> Bool {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:405` | `pub fn ViewZones::change_view_zones(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:433` | `fn ViewZones::recompute_whitespace_props(self : ViewZones) -> Bool {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:469` | `fn ViewZones::zone_keys_snapshot(self : ViewZones) -> Array[String] {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:478` | `fn ViewZones::zone_ordinal(_self : ViewZones, zone : ViewZone) -> Int {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:486` | `fn ViewZones::compute_whitespace_props(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:558` | `fn ViewZones::add_zone(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:609` | `fn ViewZones::remove_zone(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:634` | `fn ViewZones::layout_zone(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:654` | `pub fn ViewZones::should_suppress_mouse_down_on_view_zone(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:665` | `fn ViewZones::height_in_pixels(_self : ViewZones, zone : ViewZone) -> Double {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:677` | `fn ViewZones::min_width_in_pixels(_self : ViewZones, zone : ViewZone) -> Double {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:682` | `fn ViewZones::safe_call_on_computed_height(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:697` | `fn ViewZones::safe_call_on_dom_node_top(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:712` | `fn ViewZones::report_callback_error(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:732` | `pub fn ViewZones::render(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:814` | `let offscreen_absolute_top : Double = -1000000.0` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:817` | `fn double_max(left : Double, right : Double) -> Double {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:826` | `fn css_pixels(value : Int) -> String {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:831` | `fn css_pixels_double(value : Double) -> String {` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:836` | `extern "js" fn set_style_property(` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |
| `viewer/browser/view_parts/view_zones/view_zones.mbt:846` | `extern "js" fn remove_element(element : @rdom.Element) -> Unit =` | `MOVE PRODUCTION to viewer/browser/view; apply exhaustive visibility rule` |

Reconciliation: 536 production rows + 248 test rows = 784 local declaration rows.

## Manifest inventory — all 12 packages

| Manifest | Non-scoped production imports | Scoped imports | Current importers | Terminal disposition |
|---|---|---|---|---|
| `viewer/browser/view/moon.pkg` | `base/common`, `platform/log`, `viewer/browser`, common `core/cursor/markers/view_layout/view_model`, `ui/scrollbar`, `rabbita/dom`; wbtest `common/model` | all ten parts + `view_layer` | root `viewer`, browser controller | `KEEP+UNION`; remove scoped imports; promote model to production |
| `viewer/browser/view_layer/moon.pkg` | `common/view_layout`, `rabbita/dom` | none | root view, view_lines | `DELETE` after atomic move |
| `view_parts/content_widgets/moon.pkg` | `base/common`, `common/model`, `rabbita/dom` | none | root view, root viewer, hover/browser, component test | `DELETE`; callers switch to `view` |
| `view_parts/current_line_highlight/moon.pkg` | common `core/view_layout/view_model` | none | root view, margin | `DELETE` after atomic move |
| `view_parts/decorations/moon.pkg` | `base/common`, `common/view_model`; wbtest `common/model` | none | root view | `DELETE` after source/test move |
| `view_parts/editor_scrollbar/moon.pkg` | common `core`, `ui/scrollbar`, `rabbita/dom` | none | root view, root viewer | `DELETE`; root viewer keeps only `view` |
| `view_parts/margin/moon.pkg` | `base/common`, common `view_layout/view_model` | current-line package | root view | `DELETE` after atomic move |
| `view_parts/overlay_widgets/moon.pkg` | `rabbita/dom` | none | root view | `DELETE` |
| `view_parts/selections/moon.pkg` | `base/common`, common `view_layout/view_model`; wbtest `common/model` | none | root view | `DELETE` |
| `view_parts/view_cursors/moon.pkg` | `base/common`, `rabbita/dom` | none | root view, browser controller | `DELETE`; controller switches to `view` |
| `view_parts/view_lines/moon.pkg` | `base/common`, root common, common `core/view_layout/view_model`, `ui/scrollbar`, `rabbita/dom` | `view_layer` | root view, root viewer, browser controller | `DELETE` after atomic move; callers switch to `view` |
| `view_parts/view_zones/moon.pkg` | `platform/log`, common `model/view_layout/view_model`, `rabbita/dom` | none | root view, root viewer | `DELETE`; root aliases switch to `view` |

All twelve manifests declare or inherit the JS-only boundary; the sole target
retains `supported_targets = "js"`. No target import points at the root
`viewer` facade, a contribution package, the reference shell, `vscode`, or
`codemirror`.

## Generated-interface inventory — all 12 interfaces

The public-declaration count is the `moon ide outline` top-level count, while
the line count is the complete generated interface including public fields and
variants.

| Interface | Lines | Public top-level declarations | Terminal disposition |
|---|---:|---:|---|
| `viewer/browser/view/pkg.generated.mbti` | 310 | 86 | `REGENERATE` as sole interface |
| `viewer/browser/view_layer/pkg.generated.mbti` | 28 | 4 | `DELETE` |
| `view_parts/content_widgets/pkg.generated.mbti` | 80 | 22 | `DELETE` |
| `view_parts/current_line_highlight/pkg.generated.mbti` | 46 | 11 | `DELETE` |
| `view_parts/decorations/pkg.generated.mbti` | 33 | 5 | `DELETE` |
| `view_parts/editor_scrollbar/pkg.generated.mbti` | 27 | 5 | `DELETE` |
| `view_parts/margin/pkg.generated.mbti` | 39 | 9 | `DELETE` |
| `view_parts/overlay_widgets/pkg.generated.mbti` | 28 | 6 | `DELETE` |
| `view_parts/selections/pkg.generated.mbti` | 26 | 4 | `DELETE` |
| `view_parts/view_cursors/pkg.generated.mbti` | 57 | 12 | `DELETE` |
| `view_parts/view_lines/pkg.generated.mbti` | 118 | 53 | `DELETE` |
| `view_parts/view_zones/pkg.generated.mbti` | 67 | 24 | `DELETE` |
| **Total** | **859** | **241** | one regenerated interface |

The regenerated interface must expose no old package-qualified part type.
Expected external owner rewrites are `@content_widgets`, `@editor_scrollbar`,
`@view_cursors`, `@view_lines`, and `@view_zones` → `@view`. The interface diff
is structural and intended; root `viewer`'s observable API names remain
unchanged.

## README inventory — all 12 contracts

| README | Contract that must survive the fold | Terminal disposition |
|---|---|---|
| root `viewer/browser/view/README.md` | fixed DOM tree, eight event consumers, seven ordinary parts, ViewLines-first frame phases, reentrant FIFO batches, disposal order, root-class/platform rules | `KEEP+FOLD` |
| `view_layer/README.md` | no-overlap reset, overlap layout, insert/remove order, one new-row batch, one invalid-row batch | `FOLD`, then delete child README |
| `content_widgets/README.md` | retained model anchors, mapping reprojection, max-width prepass, two-pass placement, owner-document geometry, reentrant key snapshots, overflow/deferred seams | `FOLD`, then delete |
| `current_line_highlight/README.md` | focus/selection/wrap predicates and content-overlay order | `FOLD`, then delete |
| `decorations/README.md` | filter/sort, whole-line pieces, same-class merge, collapsed/fill-line behavior | `FOLD`, then delete |
| `editor_scrollbar/README.md` | thin wrapper boundary; arithmetic remains in common layout/UI scrollbar | `FOLD`, then delete |
| `margin/README.md` | current-line/decorations/line-number overlay order; unsupported glyph/number modes | `FOLD`, then delete |
| `overlay_widgets/README.md` | fixed normal/overflow containers, id registry, null-position subset | `FOLD`, then delete |
| `selections/README.md` | live visible-range geometry, rounded/reverse corners, overlay order | `FOLD`, then delete |
| `view_cursors/README.md` | readonly single cursor, DPR width, focus visibility, deferred blink/style/multicursor | `FOLD`, then delete |
| `view_lines/README.md` | retained rows/recycler, line mapping, DOM Range geometry, shared scrolling rail, width scheduler, WebKit/fast/GPU deferrals | `FOLD`, then delete |
| `view_zones/README.md` | mutable delegate/accessor, whitespace mapping, content/margin node ownership, callbacks, parent margin offset | `FOLD`, then delete |

The merged README removes statements whose only purpose was explaining the old
cycle adapters, but retains every behavior invariant, source mapping, terminal
deferral, and focused test command.

## Local-to-reference source map

| Local unit(s) | Pinned Monaco/VS Code source unit(s) represented | Structural disposition |
|---|---|---|
| current `part_fingerprints.mbt` → target `view_part.mbt`; `view_lifecycle_handles.mbt` | `browser/view/viewPart.ts` | align the source-shaped fingerprint cluster with the parent core filename; keep the lifecycle adapter seam focused |
| `rendering_context.mbt`, `selection_measure.mbt` | `browser/view/renderingContext.ts` | preserve focused files in target |
| moving `view_layer_renderer.mbt` | `browser/view/viewLayer.ts` | rename target file `view_layer.mbt` |
| `view_overlays.mbt`, overlay lifecycle | `browser/view/dynamicViewOverlay.ts`, `viewOverlays.ts`, registration in `view.ts` | preserve focused files in target |
| `view_user_input_events.mbt` | `browser/view/viewUserInputEvents.ts` | preserve file |
| `view.mbt`, dispatcher/events/context/lifecycle files | `browser/view/view.ts` and local event-boundary adaptations | preserve current focused files |
| `content_widgets.mbt` | `viewParts/contentWidgets/contentWidgets.ts` plus `IContentWidget` contracts in `editorBrowser.ts` | move as one file |
| content current-line file | `viewParts/currentLineHighlight/currentLineHighlight.ts` | move as `current_line_highlight.mbt` |
| margin current-line file | same source unit's margin overlay | move as `current_line_margin_highlight.mbt` |
| `decorations.mbt` | `viewParts/decorations/decorations.ts` | move as one file |
| `editor_scrollbar.mbt` | `viewParts/editorScrollbar/editorScrollbar.ts` | move as one file |
| `line_numbers.mbt` | `viewParts/lineNumbers/lineNumbers.ts` | move unchanged basename |
| `lines_decorations.mbt` | `viewParts/linesDecorations/linesDecorations.ts` | move unchanged basename |
| margin container/owner logic currently in `view_overlays.mbt` → target `margin.mbt` | `viewParts/margin/margin.ts` | extract the seven-declaration `MarginViewOverlays` cluster; shared/content overlay rows remain in `view_overlays.mbt` |
| `overlay_widgets.mbt` | `viewParts/overlayWidgets/overlayWidgets.ts` | move as one file |
| `selections.mbt` | `viewParts/selections/selections.ts` | move as one file |
| `view_cursors.mbt` | `viewParts/viewCursors/viewCursors.ts`, `viewCursor.ts` | move as one current local unit |
| four view-line production files | `viewParts/viewLines/{domReadingContext,rangeUtil,viewLine,viewLines}.ts` | move atomically, preserve four units |
| `view_zones.mbt` | `viewParts/viewZones/viewZones.ts` | move as one file |

This companion does not claim the upstream denominator is complete; the
sibling upstream ledger accounts for unsupported view parts and every scoped
TS/CSS member with terminal `DEFERRED`/`N-A` reasons.

## CSS and non-code asset inventory

`scripts/build-web.mbtx:487-510` returns a fixed 22-entry `css_sources()`
array. `assembled_style_css()` writes a path comment, source bytes, a missing
newline if needed, and one blank line for each entry. Therefore changing a
source path changes `web/dist/style.css` bytes even if CSS content and cascade
position are identical.

The scoped entries and exact current order are:

| Global order | CSS source | Lines | Terminal disposition |
|---:|---|---:|---|
| 4 | `viewer/browser/view/codicon/codicon.css` | 55 | `KEEP PATH+ORDER` |
| 5 | `viewer/browser/view/editor.css` | 35 | `KEEP PATH+ORDER` |
| 7 | `viewer/browser/view_parts/view_lines/view_lines.css` | 46 | `KEEP PATH+ORDER` |
| 8 | `viewer/browser/view_parts/selections/view_overlays.css` | 18 | `KEEP PATH+ORDER` |
| 9 | `viewer/browser/view_parts/content_widgets/content_widgets.css` | 13 | `KEEP PATH+ORDER` |
| 10 | `viewer/browser/view_parts/overlay_widgets/overlay_widgets.css` | 13 | `KEEP PATH+ORDER` |
| 11 | `viewer/browser/view_parts/selections/selections.css` | 42 | `KEEP PATH+ORDER` |
| 12 | `viewer/browser/view_parts/current_line_highlight/current_line_highlight.css` | 55 | `KEEP PATH+ORDER` |
| 13 | `viewer/browser/view_parts/decorations/decorations.css` | 15 | `KEEP PATH+ORDER` |
| 14 | `viewer/browser/view_parts/view_cursors/view_cursors.css` | 31 | `KEEP PATH+ORDER` |
| 15 | `viewer/browser/view_parts/margin/margin.css` | 37 | `KEEP PATH+ORDER` |
| 16 | `viewer/browser/view_parts/margin/lines_decorations.css` | 7 | `KEEP PATH+ORDER` |
| 17 | `viewer/browser/view_parts/view_lines/tokens.css` | 74 | `KEEP PATH+ORDER` |
| 18 | `viewer/browser/view_parts/view_lines/markers.css` | 71 | `KEEP PATH+ORDER` |
| **Scoped total** | **14 CSS files** | **512** | exact path/order preserved |

The terminal CSS decision is to leave the twelve leaf CSS files at their
current paths in asset-only directories after deleting those directories'
MoonBit manifests, source/tests, READMEs, and interfaces. This preserves both
cascade order and the generated path comments byte-for-byte and requires no
`css_sources()` edit. `view_layer`, `editor_scrollbar`, and `view_zones` own no
CSS and can disappear as directories. The root codicon directory and
`codicon.ttf` remain; the build script also copies the font to the main target
and Monaco-oracle browser-test output.

The currently built output is 56,378 bytes with SHA-256
`bcf27861211e6731f0208a756946f9d1f2110c1e8c24bc936cbe5d5d76d66599`.
Implementation closeout must rebuild and compare bytes, not merely selectors.

## Gate A local exit reconciliation

- 12/12 manifests inventoried with terminal keep/delete/rewrite disposition.
- 12/12 READMEs inventoried with terminal fold/delete disposition.
- 12/12 generated interfaces inventoried; 241 public top-level declarations
  are covered by the exhaustive caller/visibility rule.
- 30/30 production files and 536/536 production declarations have literal
  terminal rows; the aligned target map has 31 files and the same 536
  declarations.
- 21/21 root `View::` methods have literal `KEEP PUBLIC`/`PRIVATE` rows with
  caller evidence.
- 45/45 exact primary `Type::new` declarations have a terminal conversion
  decision; distinct alternate factories are separately retained.
- 16/16 test files, 118/118 exact named tests, and 130/130 helper declarations
  have literal terminal rows.
- 14/14 CSS files and the codicon font have terminal path/order dispositions.
- All scoped and external manifest edges are accounted for.
- All basename/symbol collisions have source-shaped resolutions.
- Both package-cycle move groups and every external-caller-coupled move are
  explicit.

Review gate: **STOP FOR REVIEW. Do not move product code until the browser-view
Gate A artifacts are explicitly approved.**
