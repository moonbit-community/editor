# Viewer Public Editor API Boundary — Gate A Dependency and Interface Snapshots

Status: inventory ready — STOP FOR REVIEW; no public API implementation has started

Date: 2026-07-14

Parent plan: `docs/exec-plans/viewer-public-editor-api-boundary.md`

Oracle commit: `vscode` submodule at
`b18492a288de038fbc7643aae6de8247029d11bd`

Local baseline: repository `HEAD`
`e5beb1c8cd5c9d5b2fbfbfca55025438b17e1ca3`

This companion freezes the generated-interface and package-dependency half of
Gate A. It changes no product source, `moon.pkg`, or `pkg.generated.mbti` file.
The immutable Git objects named below are the complete byte snapshots; the
embedded blocks are exact excerpts for the ownership-moving signatures.

## Closed Denominators

- Eight checked-in interfaces must change for the fixed option/cursor,
  view-zone, and overlay-widget ownership moves: root `viewer`;
  `common/{cursor,view_layout,view_model}`;
  root `common`; folding browser; public browser contracts; and private browser
  view.
- Capability extraction changes five existing concrete owner/adapter
  interfaces in `common/{languages,markers}`, `contrib/{agent_feedback,
  quick_diff/common}`, and `platform/log`. The DOM-free hover package is also a
  direct changed consumer because its public participant service records and
  constructors currently expose `Languages`, `MarkerDecorationsService`, and
  `LogService`.
- The complete changed-interface snapshot is **14 files / 2,869 lines**. The
  SHA-256 of the ordered `shasum -a 256` output is
  `be2194c4fe6006e939100b37b7a09e81942cc3d42e867b8d12e781312321dab4`.
- Eight byte-identical consumer sentinels add **8 files / 218 lines** but are
  not part of that aggregate: the agent-feedback browser projection, embedded
  example, workbench, and five browser-scenario interfaces. Their
  implementation imports/call sites move without changing their exported
  interface. The ordered sentinel hash is
  `206020d81b7252744f963a095408654eb1648358846c6e75c81fd559007fca09`.
- The closed manifest graph and caller-migration set is **31 present
  `moon.pkg` files / 325 lines / 184 literal import rows**, including test-mode
  rows. Its ordered manifest hash is
  `aaed208c0cea2de008912f026e8f2f78dd3ac86685acb356d4ef9e57694db988`.
- Four target packages are absent at the baseline: JS-only
  `viewer/browser/testing` and multi-target
  `viewer/common/{editor_api,agent_feedback_api,quick_diff_api}`. For each,
  both `moon.pkg` and `pkg.generated.mbti` are absent. Their absence is part of
  the snapshot, not an omitted file.

## Byte-Exact Generated-Interface Snapshot

The fixed ownership decisions force rows 1-6 and 8-9. The adjusted capability
seam forces the five owner/adapter rows 10-14 and changes the public hover
consumer at row 7.

| Ordered row | Checked-in interface | Lines | SHA-256 | Expected ownership delta |
|---:|---|---:|---|---|
| 1 | `viewer/pkg.generated.mbti` | 280 | `9c6b4fe4d5d57704db1d0ada58a5401d6ed55fa049b1cb9bf74b3854e62b0d75` | remove root duplicate/options/contribution/view-implementation/concrete-service leaks; retarget overlay widgets to the browser handle |
| 2 | `viewer/common/cursor/pkg.generated.mbti` | 129 | `bc333350fd3fccefdd73945ea0a6c976aea46dfa7837b5de64906c6f9d945c0f` | consume canonical cursor reason |
| 3 | `viewer/common/view_layout/pkg.generated.mbti` | 559 | `792a8029fb3f07a219b57ab549c219e86e32d07f772b7ab4d41368b5d25ac1a8` | consume canonical render enums |
| 4 | `viewer/common/view_model/pkg.generated.mbti` | 383 | `1a8045267c25d97c078716c58c15e08576927499804dc7fbecedea885ea6386c` | consume cursor/render/wrapping/validation contracts |
| 5 | `viewer/common/pkg.generated.mbti` | 23 | `957599b7e879d1a3700d4bd4c0ff21b2124e5af93df910705ddf960f8e091a40` | public line-render helper accepts canonical whitespace enum |
| 6 | `viewer/contrib/folding/browser/pkg.generated.mbti` | 208 | `2c6b8993578f04d31a2877a39ad863599f66a25177cde915d928b53dfe2eb43f` | consume canonical folding-control enum |
| 7 | `viewer/contrib/hover/pkg.generated.mbti` | 326 | `25f946d03e3aa40d4d0679000d0e22b7fc2fadd7a009e5caac35b48985fcff26` | replace concrete language/marker/log participant inputs with capability handles |
| 8 | `viewer/browser/pkg.generated.mbti` | 158 | `e0fe21017c33a82509afcd48aed28d0bb023158cb484ea785de754ed7373319c` | gain public DOM-facing zone descriptor/accessor and unmanaged overlay-widget contracts |
| 9 | `viewer/browser/view/pkg.generated.mbti` | 356 | `0100e5068fabb111e52f85b833b57e4547e91b628bca4def03003e6945b81e75` | lose public zone descriptor/accessor ownership; consume browser/editor-api/log capability contracts |
| 10 | `viewer/common/languages/pkg.generated.mbti` | 57 | `0c520ba65545dfe75e233fe1e0891492d0197ed39d6300c25c9af081db4636e1` | own `LanguageHandle` beside the concrete registry |
| 11 | `viewer/common/markers/pkg.generated.mbti` | 165 | `ef59732a20e5e6c0ce64110677493584479f05b765c72f727e418a905b911c81` | own `MarkerServiceHandle`, `MarkerDecorationsHandle`, and their closed source union beside concrete marker services |
| 12 | `viewer/contrib/agent_feedback/pkg.generated.mbti` | 121 | `2ec18e58c798101a7711776f72d248b439a0552139cf3e600f3e98535235275c` | consume common host DTOs/`AgentFeedbackHandle` and retain the concrete service plus UI projection |
| 13 | `viewer/contrib/quick_diff/common/pkg.generated.mbti` | 33 | `614979b1fe0f9ce7cf6daba38133f153b888771d31e34be0c053d269ff17f100` | adapt the concrete baseline store to common `QuickDiffHandle` |
| 14 | `platform/log/pkg.generated.mbti` | 71 | `834b2ea0f7a29ed8fb2be26ad0f094ffa76d8fa311ec0a4e20c133681b7af15f` | own `LogHandle` beside `LogService` |

Consumer sentinels:

| Ordered row | Interface | Lines | SHA-256 | Closing expectation |
|---:|---|---:|---|---|
| 1 | `viewer/contrib/agent_feedback/browser/pkg.generated.mbti` | 121 | `97710dce497713b716886101dcd743ca2759266523cc3e54a5a1803c1d69cd3e` | byte-identical UI interface over contrib-owned `SessionEditorComment` |
| 2 | `internal/shell/examples/embedded_viewer/pkg.generated.mbti` | 13 | `fec90ce92b4326cafc3a95b8292b2a9ae7da207c06cb81f89492af237190fb4f` | byte-identical empty executable interface |
| 3 | `internal/shell/workbench/pkg.generated.mbti` | 18 | `c5f1da099ae9a6bbbf2924b301c5c74edb34c8134f326682fb2815879661832b` | byte-identical three-function shell interface |
| 4 | `tests/browser/moonbit/agent_feedback/pkg.generated.mbti` | 13 | `a553bba742fa68316e23be51092266808047d0cfb2f0f291d72fdc2361e5ed37` | byte-identical executable interface |
| 5 | `tests/browser/moonbit/component/pkg.generated.mbti` | 14 | `1551125b2eb5aa841a05873e2312afed53cfb0d37990bc5da3fe19f2d352b676` | byte-identical executable interface and private fixture error |
| 6 | `tests/browser/moonbit/model_swap/pkg.generated.mbti` | 13 | `cc317d28c8b2549b88b821e92efbf49539b86bc0bd2c41d21f55327b829672f4` | byte-identical executable interface |
| 7 | `tests/browser/moonbit/quick_diff/pkg.generated.mbti` | 13 | `f7c29983588e3cb8e52143bf4de3de470fb4e70c4fbeefd1c2281f53265a2f44` | byte-identical executable interface |
| 8 | `tests/browser/moonbit/set_value/pkg.generated.mbti` | 13 | `76486fbea33c153f5e9a3095eafb3567b4420c4ae813742d63719f6411a508f5` | byte-identical executable interface |

The complete files can be reproduced without trusting the working tree:

```zsh
BASE=e5beb1c8cd5c9d5b2fbfbfca55025438b17e1ca3
files=(
  viewer/pkg.generated.mbti
  viewer/common/cursor/pkg.generated.mbti
  viewer/common/view_layout/pkg.generated.mbti
  viewer/common/view_model/pkg.generated.mbti
  viewer/common/pkg.generated.mbti
  viewer/contrib/folding/browser/pkg.generated.mbti
  viewer/contrib/hover/pkg.generated.mbti
  viewer/browser/pkg.generated.mbti
  viewer/browser/view/pkg.generated.mbti
  viewer/common/languages/pkg.generated.mbti
  viewer/common/markers/pkg.generated.mbti
  viewer/contrib/agent_feedback/pkg.generated.mbti
  viewer/contrib/quick_diff/common/pkg.generated.mbti
  platform/log/pkg.generated.mbti
)
for p in "${files[@]}"; do
  git show "$BASE:$p" | wc -l
  git show "$BASE:$p" | shasum -a 256
done
for p in "${files[@]}"; do
  h=$(git show "$BASE:$p" | shasum -a 256 | awk '{print $1}')
  printf '%s  %s\n' "$h" "$p"
done | shasum -a 256
sentinels=(
  viewer/contrib/agent_feedback/browser/pkg.generated.mbti
  internal/shell/examples/embedded_viewer/pkg.generated.mbti
  internal/shell/workbench/pkg.generated.mbti
  tests/browser/moonbit/agent_feedback/pkg.generated.mbti
  tests/browser/moonbit/component/pkg.generated.mbti
  tests/browser/moonbit/model_swap/pkg.generated.mbti
  tests/browser/moonbit/quick_diff/pkg.generated.mbti
  tests/browser/moonbit/set_value/pkg.generated.mbti
)
for p in "${sentinels[@]}"; do
  h=$(git show "$BASE:$p" | shasum -a 256 | awk '{print $1}')
  printf '%s  %s\n' "$h" "$p"
done | shasum -a 256
absent=(
  viewer/browser/testing
  viewer/common/editor_api
  viewer/common/agent_feedback_api
  viewer/common/quick_diff_api
)
for d in "${absent[@]}"; do
  ! git cat-file -e "$BASE:$d/moon.pkg" 2>/dev/null
  ! git cat-file -e "$BASE:$d/pkg.generated.mbti" 2>/dev/null
done
```

The two hash commands print the changed-interface and sentinel hashes above. A
reviewer who wants
materialized snapshots can redirect each `git show "$BASE:$p"` into a scratch
directory; no extra checked-in snapshot file is necessary because the baseline
commit and per-file hashes identify every byte.

## Exact Signature Blocks

These are literal slices from the baseline objects. They are not rewritten
pseudocode. Full-file hashes above remain authoritative for lines outside the
ownership clusters.

### Root leaks — `viewer/pkg.generated.mbti`

Lines 1-70:

```text
// Generated using `moon info`, DON'T EDIT IT
package "moonbit-community/editor/viewer"

import {
  "moonbit-community/editor/language",
  "moonbit-community/editor/platform/log",
  "moonbit-community/editor/viewer/browser/view",
  "moonbit-community/editor/viewer/common/config",
  "moonbit-community/editor/viewer/common/core",
  "moonbit-community/editor/viewer/common/languages",
  "moonbit-community/editor/viewer/common/markers",
  "moonbit-community/editor/viewer/common/model",
  "moonbit-community/editor/viewer/common/view_layout",
  "moonbit-community/editor/viewer/common/view_model",
  "moonbit-community/editor/viewer/contrib/agent_feedback",
  "moonbit-community/rabbita/dom",
  "moonbitlang/core/debug",
}

// Values
pub fn debug_on_did_build_view_model(Viewer, (ViewerViewModelBuiltEvent) -> Unit) -> @moonbit-community/editor/base/common.Disposable

pub fn debug_on_did_render_model(Viewer, (ViewerModelRenderedEvent) -> Unit) -> @moonbit-community/editor/base/common.Disposable

pub fn debug_on_did_resolve_hover(Viewer, (ViewerHoverResolvedEvent) -> Unit) -> @moonbit-community/editor/base/common.Disposable

pub fn view_zone(Int, @dom.Element, after_column? : Int, after_column_affinity? : @model.PositionAffinity, show_in_hidden_areas? : Bool, ordinal? : Int, suppress_mouse_down? : Bool, height_in_lines? : Double, height_in_px? : Double, min_width_in_px? : Double, margin_dom_node? : @dom.Element, on_dom_node_top? : (Double) -> Unit raise, on_computed_height? : (Double) -> Unit raise) -> @view.ViewZone

// Errors

// Types and methods
pub(all) enum CursorChangeReason {
  NotSet
  ContentFlush
  RecoverFromMarkers
  Explicit
  Paste
  Undo
  Redo
} derive(Eq, @debug.Debug)

pub(all) struct CursorPositionChangedEvent {
  position : @moonbit-community/editor/base/common.Position
  secondary_positions : Array[@moonbit-community/editor/base/common.Position]
  reason : CursorChangeReason
  source : String
} derive(@debug.Debug)

pub(all) struct CursorSelectionChangedEvent {
  selection : @core.Selection
  secondary_selections : Array[@core.Selection]
  model_version_id : Int
  old_selections : Array[@core.Selection]?
  old_model_version_id : Int
  source : String
  reason : CursorChangeReason
} derive(@debug.Debug)

pub(all) struct EditorContribution {
  id : String
  dispose : () -> Unit
}

pub(all) enum EditorContributionInstantiation {
  Eager
  AfterFirstRender
  BeforeFirstInteraction
  Eventually
  Lazy
} derive(Eq, @debug.Debug)
```

Lines 114-129:

```text
pub struct Viewer {
  // private fields
}
pub fn Viewer::Viewer(services? : ViewerServices, options? : ViewerOptions) -> Self
pub fn Viewer::add_overlay_widget(Self, String, @dom.Element) -> Unit
pub fn Viewer::change_view_zones(Self, (@view.ViewZoneChangeAccessor) -> Unit raise) -> Unit
pub fn Viewer::create(@dom.Element, services? : ViewerServices, options? : ViewerOptions) -> Self
pub fn Viewer::create_decorations_collection(Self, decorations? : Array[@model.ModelDeltaDecoration]) -> EditorDecorationsCollection
pub fn Viewer::delta_decorations(Self, Array[String], Array[@model.ModelDeltaDecoration]) -> Array[String]
pub fn Viewer::dispose(Self) -> Unit
pub fn Viewer::focus(Self) -> Unit
pub fn Viewer::get_bottom_for_line_number(Self, Int, include_view_zones? : Bool) -> Double
pub fn Viewer::get_container_dom_node(Self) -> @dom.Element?
pub fn Viewer::get_content_height(Self) -> Double
pub fn Viewer::get_content_width(Self) -> Double
pub fn Viewer::get_contribution(Self, String) -> EditorContribution?
```

Lines 218-258:

```text
pub(all) struct ViewerOptions {
  soft_wrap : Bool
  tab_size : Int
  wrapping_indent : @view_model.WrappingIndent
  render_whitespace : @view_layout.RenderWhitespace
  render_control_characters : Bool
  render_line_highlight : @view_layout.RenderLineHighlight
  render_line_highlight_only_when_focus : Bool
  render_validation_decorations : @view_model.RenderValidationDecorations
  theme : String
  placeholder : String
  line_decorations_width : Int
  line_numbers_min_chars : Int
  folding : Bool
  show_folding_controls : @moonbit-community/editor/viewer/contrib/folding/browser.ShowFoldingControls
  folding_highlight : Bool
  folding_maximum_regions : Int
  unfold_on_click_after_end_of_line : Bool
  smooth_scrolling : Bool
  show_unused : Bool
  show_deprecated : Bool
  font_family : String
  font_weight : String
  font_size : Double
  line_height : Double
  letter_spacing : Double
} derive(Eq, @debug.Debug)
pub fn ViewerOptions::ViewerOptions(soft_wrap? : Bool, tab_size? : Int, wrapping_indent? : @view_model.WrappingIndent, render_whitespace? : @view_layout.RenderWhitespace, render_control_characters? : Bool, render_line_highlight? : @view_layout.RenderLineHighlight, render_line_highlight_only_when_focus? : Bool, render_validation_decorations? : @view_model.RenderValidationDecorations, theme? : String, placeholder? : String, line_decorations_width? : Int, line_numbers_min_chars? : Int, folding? : Bool, show_folding_controls? : @moonbit-community/editor/viewer/contrib/folding/browser.ShowFoldingControls, folding_highlight? : Bool, folding_maximum_regions? : Int, unfold_on_click_after_end_of_line? : Bool, smooth_scrolling? : Bool, show_unused? : Bool, show_deprecated? : Bool, font_family? : String, font_weight? : String, font_size? : Double, line_height? : Double, letter_spacing? : Double) -> Self
pub fn ViewerOptions::default() -> Self
pub fn ViewerOptions::soft_wrap_column_for_content_width(Self, Double, Double) -> Int
pub fn ViewerOptions::view_model_options(Self, Int, font_info~ : @config.FontInfo, editor_id? : Int) -> @view_model.ViewModelOptions

pub(all) struct ViewerServices {
  languages : @languages.Languages
  markers : @markers.MarkerService
  marker_decorations : @markers.MarkerDecorationsService
  agent_feedback : @agent_feedback.AgentFeedbackService
  quick_diff : @moonbit-community/editor/viewer/contrib/quick_diff/common.QuickDiffService
  log_service : @log.LogService
}
pub fn ViewerServices::new(languages? : @languages.Languages, log_service? : @log.LogService) -> Self
```

Lines 274-277:

```text
// Type aliases
pub using @view {type ViewZone}

pub using @view {type ViewZoneChangeAccessor}
```

### Canonical-value owners before the move

`viewer/common/cursor/pkg.generated.mbti:26-34,55-83`:

```text
pub(all) enum CursorChangeReason {
  NotSet
  ContentFlush
  RecoverFromMarkers
  Explicit
  Paste
  Undo
  Redo
} derive(Eq, @debug.Debug)
```

```text
pub(all) struct CursorStateChange {
  old_selections : Array[@core.Selection]?
  selections : Array[@core.Selection]
  old_model_version_id : Int
  model_version_id : Int
  source : String
  reason : CursorChangeReason
  reached_max_cursor_count : Bool
  has_outgoing_event : Bool
} derive(@debug.Debug)

pub struct CursorsController {
  model : @model.TextModel
  mut known_model_version_id : Int
  mut context : CursorContext
  mut cursor : Cursor
  mut is_handling : Bool
}
pub fn CursorsController::get_model_selection(Self) -> @core.Selection
pub fn CursorsController::get_primary_cursor_state(Self) -> CursorState
pub fn CursorsController::get_view_selection(Self) -> @core.Selection
pub fn CursorsController::model_state(Self) -> SingleCursorState
pub fn CursorsController::move_to(Self, @common.Position, Bool, source? : String, reason? : CursorChangeReason) -> CursorStateChange?
pub fn CursorsController::new(@model.TextModel, CursorContext) -> Self
pub fn CursorsController::on_model_content_changed(Self, @model.InternalModelContentChangeEvent) -> CursorStateChange?
pub fn CursorsController::set_context(Self, CursorContext) -> Unit
pub fn CursorsController::set_cursor_state(Self, PartialCursorState?, source? : String, reason? : CursorChangeReason) -> CursorStateChange?
pub fn CursorsController::set_model_cursor_state(Self, SingleCursorState, source? : String, reason? : CursorChangeReason) -> CursorStateChange?
pub fn CursorsController::set_view_cursor_state(Self, SingleCursorState, source? : String, reason? : CursorChangeReason) -> CursorStateChange?
```

`viewer/common/view_layout/pkg.generated.mbti:18-20,235-240,258,266,279-285`:

```text
pub fn should_render_line_highlight_in_content(RenderLineHighlight, Bool, Bool, Bool) -> Bool

pub fn should_render_line_highlight_in_margin(RenderLineHighlight, Bool, Bool) -> Bool
```

```text
pub(all) enum RenderLineHighlight {
  None
  Gutter
  Line
  All
} derive(Eq, @debug.Debug)
```

```text
  render_whitespace : RenderWhitespace
```

```text
pub fn RenderLineInput::from_view_line(ViewLineRenderingData, line_decorations? : Array[LineDecoration], use_monospace_optimizations? : Bool, can_use_halfwidth_rightwards_arrow? : Bool, faux_indent_length? : Int, space_width? : Double, middot_width? : Double, wsmiddot_width? : Double, stop_rendering_line_after? : Int, render_whitespace? : RenderWhitespace, render_control_characters? : Bool, font_ligatures? : Bool, selections_on_line? : Array[@common.OffsetRange], vertical_scrollbar_size? : Double, render_new_line_when_empty? : Bool) -> Self
```

```text
pub(all) enum RenderWhitespace {
  None
  Boundary
  Selection
  Trailing
  All
} derive(Eq, @debug.Debug)
```

`viewer/common/view_model/pkg.generated.mbti:20-26,74-83,193-197,344-355,373-378`:

```text
pub fn filter_validation_decorations(RenderValidationDecorations) -> Bool

pub fn lines_decorations_to_render(Array[ViewModelDecoration]) -> Array[DecorationToRender]

pub let monospace_line_breaks_computer_factory : MonospaceLineBreaksComputerFactory

pub fn render_line_input_from_view_line_data(ViewLineData, line_decorations? : Array[@view_layout.LineDecoration], space_width? : Double, render_whitespace? : @view_layout.RenderWhitespace, render_control_characters? : Bool, vertical_scrollbar_size? : Double) -> @view_layout.RenderLineInput
```

```text
pub(all) struct CursorStateChangedEvent {
  kind : OutgoingViewModelEventKind
  old_selections : Array[@core.Selection]?
  selections : Array[@core.Selection]
  old_model_version_id : Int
  model_version_id : Int
  source : String
  reason : @cursor.CursorChangeReason
  reached_max_cursor_count : Bool
} derive(@debug.Debug)
```

```text
pub(all) enum RenderValidationDecorations {
  Editable
  On
  Off
} derive(Eq, @debug.Debug)
```

```text
pub(all) struct ViewModelOptions {
  font_info : @config.FontInfo
  soft_wrap_column : Int
  tab_size : Int
  wrapping_indent : WrappingIndent
  editor_id : Int
  render_validation_decorations : RenderValidationDecorations
} derive(Eq, @debug.Debug)
pub fn ViewModelOptions::ViewModelOptions(font_info? : @config.FontInfo, soft_wrap_column? : Int, tab_size? : Int, wrapping_indent? : WrappingIndent, editor_id? : Int, render_validation_decorations? : RenderValidationDecorations) -> Self
pub fn ViewModelOptions::is_soft_wrap_enabled(Self) -> Bool
pub fn ViewModelOptions::no_wrap() -> Self
pub fn ViewModelOptions::soft_wrap(Int, tab_size? : Int, wrapping_indent? : WrappingIndent) -> Self
```

```text
pub(all) enum WrappingIndent {
  None
  Same
  Indent
  DeepIndent
} derive(Eq, @debug.Debug)
```

The complete root-common interface is only 23 lines and is embedded verbatim:

```text
// Generated using `moon info`, DON'T EDIT IT
package "moonbit-community/editor/viewer/common"

import {
  "moonbit-community/editor/viewer/common/view_layout",
  "moonbit-community/editor/viewer/common/view_model",
}

// Values
pub fn escape_html(String) -> String

pub fn render_line_class() -> String

pub fn render_line_html(@view_model.ViewLineData, Array[@view_layout.LineDecoration], render_whitespace? : @view_layout.RenderWhitespace, render_control_characters? : Bool) -> String

// Errors

// Types and methods

// Type aliases

// Traits

```

`viewer/contrib/folding/browser/pkg.generated.mbti:84-91,199-203`:

```text
pub struct FoldingDecorationProvider {
  mut show_folding_controls : ShowFoldingControls
  mut show_folding_highlights : Bool
  // private fields
}
pub fn FoldingDecorationProvider::access(Self) -> FoldingDecorationAccess
pub fn FoldingDecorationProvider::new(@model.TextModel, owner_id? : Int) -> Self
pub fn FoldingDecorationProvider::update_options(Self, show_folding_controls~ : ShowFoldingControls, show_folding_highlights~ : Bool) -> Unit
```

```text
pub(all) enum ShowFoldingControls {
  Always
  Never
  Mouseover
} derive(Eq, @debug.Debug)
```

### Browser contract/runtime split before the move

`viewer/browser/pkg.generated.mbti:1-18` has no `ViewZone` or
`ViewZoneChangeAccessor` declaration:

```text
// Generated using `moon info`, DON'T EDIT IT
package "moonbit-community/editor/viewer/browser"

import {
  "moonbit-community/editor/base/common",
  "moonbit-community/editor/viewer/common/view_model",
  "moonbit-community/rabbita/dom",
  "moonbitlang/core/debug",
}

// Values
pub fn create_coordinates_relative_to_editor(@dom.Element, EditorPagePosition, PageCoordinates) -> CoordinatesRelativeToEditor

pub fn create_editor_page_position(@dom.Element) -> EditorPagePosition

// Errors

// Types and methods
```

`viewer/browser/view/pkg.generated.mbti:323-351` owns both the public delegate
and the accessor together with the runtime `ViewZones` implementation:

```text
pub(all) struct ViewZone {
  mut after_line_number : Int
  mut after_column : Int?
  mut after_column_affinity : @model.PositionAffinity?
  mut show_in_hidden_areas : Bool?
  mut ordinal : Int?
  mut suppress_mouse_down : Bool?
  mut height_in_lines : Double?
  mut height_in_px : Double?
  mut min_width_in_px : Double?
  mut dom_node : @dom.Element
  mut margin_dom_node : @dom.Element?
  mut on_dom_node_top : ((Double) -> Unit raise)?
  mut on_computed_height : ((Double) -> Unit raise)?
}
pub fn ViewZone::ViewZone(Int, @dom.Element, after_column? : Int, after_column_affinity? : @model.PositionAffinity, show_in_hidden_areas? : Bool, ordinal? : Int, suppress_mouse_down? : Bool, height_in_lines? : Double, height_in_px? : Double, min_width_in_px? : Double, margin_dom_node? : @dom.Element, on_dom_node_top? : (Double) -> Unit raise, on_computed_height? : (Double) -> Unit raise) -> Self

pub struct ViewZoneChangeAccessor {
  // private fields
}
pub fn ViewZoneChangeAccessor::add_zone(Self, ViewZone) -> String
pub fn ViewZoneChangeAccessor::layout_zone(Self, String) -> Unit
pub fn ViewZoneChangeAccessor::remove_zone(Self, String) -> Unit

pub struct ViewZones {
  // private fields
}
pub fn ViewZones::did_render(Self) -> Unit
pub fn ViewZones::should_render(Self) -> Bool
```

The accessor cannot move verbatim: its source fields are a private `ViewZones`,
a `@view_layout.WhitespaceChangeAccessor`, a changed ref, and a validity flag.
Moving that struct into `viewer/browser` would require `browser ->
browser/view`, while `browser/view` already imports `browser`, creating the
forbidden two-node cycle. The target public accessor must therefore be an
opaque browser-owned callback handle; `browser/view` supplies the callbacks
that close over its private runtime owner.

### Concrete service vocabulary before capability extraction

`viewer/common/languages/pkg.generated.mbti:1-12,40-52`:

```text
// Generated using `moon info`, DON'T EDIT IT
package "moonbit-community/editor/viewer/common/languages"

import {
  "moonbit-community/editor/base/common",
  "moonbit-community/editor/language",
  "moonbit-community/editor/platform/log",
  "moonbit-community/editor/syntax",
  "moonbit-community/editor/viewer/common/model",
  "moonbit-community/editor/viewer/common/services",
  "moonbit-community/editor/viewer/common/tokens",
}
```

```text
type LanguageFeatureRegistry[T]

pub struct Languages {
  // private fields
}
pub async fn Languages::document_symbols(Self, @model.TextModel, @log.LogService) -> Array[@language.DocumentSymbol] noraise
pub fn Languages::get_language_configuration(Self, String) -> LanguageConfiguration
pub async fn Languages::hover_at(Self, @model.TextModel, Int, @log.LogService, token? : @language.CancellationToken) -> @language.Hover? noraise
pub fn Languages::new() -> Self
pub fn Languages::register_document_symbol_provider(Self, @language.LanguageSelector, &@language.DocumentSymbolProvider) -> @common.Disposable
pub fn Languages::register_hover_provider(Self, @language.LanguageSelector, &@language.HoverProvider) -> @common.Disposable
pub fn Languages::set_language_configuration(Self, String, LanguageConfiguration) -> Unit
pub fn Languages::set_tokens_provider(Self, String, &@syntax.LineTokenizer) -> @common.Disposable
```

`viewer/common/markers/pkg.generated.mbti:1-9,67-79,90-109`:

```text
// Generated using `moon info`, DON'T EDIT IT
package "moonbit-community/editor/viewer/common/markers"

import {
  "moonbit-community/editor/base/common",
  "moonbit-community/editor/language",
  "moonbit-community/editor/viewer/common/model",
  "moonbitlang/core/debug",
}
```

```text
pub struct MarkerDecorationsService {
  // private fields
}
pub fn MarkerDecorationsService::acquire_model(Self, @model.TextModel) -> @common.Disposable
pub fn MarkerDecorationsService::add_marker_suppression(Self, @common.Uri, @common.Range) -> @common.Disposable
pub fn MarkerDecorationsService::dispose(Self) -> Unit
pub fn MarkerDecorationsService::get_live_markers(Self, @common.Uri) -> Array[(@common.Range, Marker)]
pub fn MarkerDecorationsService::get_live_markers_for_model(Self, @model.TextModel) -> Array[(@common.Range, Marker)]
pub fn MarkerDecorationsService::get_marker(Self, @common.Uri, String) -> Marker?
pub fn MarkerDecorationsService::new(MarkerService) -> Self
pub fn MarkerDecorationsService::on_did_change_marker_decorations(Self, (@model.TextModel) -> Unit) -> @common.Disposable
pub fn MarkerDecorationsService::on_model_added(Self, @model.TextModel) -> Unit
pub fn MarkerDecorationsService::on_model_removed(Self, @model.TextModel) -> Unit
```

```text
pub struct MarkerService {
  did_change_markers : @common.MicrotaskEmitter[Array[@common.Uri]]
  data : DoubleResourceMap
  filtered_resources : Map[String, Array[String]]
  mut stats : MarkerStats?
}
pub fn MarkerService::change_all(Self, String, Array[ResourceMarker]) -> Unit
pub fn MarkerService::change_one(Self, String, @common.Uri, Array[MarkerData]) -> Unit
pub fn MarkerService::clear_resource(Self, @common.Uri) -> Unit
pub fn MarkerService::diagnostics_for_resource(Self, @common.Uri) -> Array[@language.Diagnostic]
pub fn MarkerService::dispose(Self) -> Unit
pub fn MarkerService::install_resource_filter(Self, @common.Uri, String) -> @common.Disposable
pub fn MarkerService::markers_for_resource(Self, @common.Uri, limit? : Int) -> Array[Marker]
pub fn MarkerService::new(schedule? : (() -> Unit) -> Unit) -> Self
pub fn MarkerService::on_did_change_markers(Self, (Array[@common.Uri]) -> Unit) -> @common.Disposable
pub fn MarkerService::read(Self, MarkerReadOptions) -> Array[Marker]
pub fn MarkerService::remove(Self, String, Array[@common.Uri]) -> Unit
pub fn MarkerService::remove_owner_resource(Self, String, @common.Uri) -> Unit
pub fn MarkerService::set_diagnostics(Self, String, @common.Uri, Array[@language.Diagnostic]) -> Unit
pub fn MarkerService::statistics(Self) -> MarkerStatistics
```

`viewer/contrib/agent_feedback/pkg.generated.mbti:23-41,58-90` proves that
the service callbacks carry feature-owned DTOs, not only URI primitives:

```text
pub(all) struct AgentFeedback {
  id : String
  text : String
  resource : @common.Uri
  range : @common.Range
  kind : AgentFeedbackKind
  replies : Array[String]
  state : AgentFeedbackState
} derive(@debug.Debug)

pub(all) struct AgentFeedbackAddedEvent {
  feedback : AgentFeedback
  has_existing_feedback_for_file : Bool
} derive(@debug.Debug)

pub(all) struct AgentFeedbackChangeEvent {
  resource : @common.Uri
  feedback_items : Array[AgentFeedback]
} derive(@debug.Debug)
```

```text
pub struct AgentFeedbackService {
  did_change_feedback : @common.Emitter[AgentFeedbackChangeEvent]
  did_change_navigation : @common.Emitter[@common.Uri]
  did_add_feedback : @common.Emitter[AgentFeedbackAddedEvent]
  did_add_reply : @common.Emitter[AgentFeedbackReplyAddedEvent]
  did_submit_feedback : @common.Emitter[AgentFeedbackSubmittedEvent]
  items_by_resource : Map[String, Array[AgentFeedback]]
  navigation_anchor_by_resource : Map[String, String]
  enabled_resources : Map[String, Bool]
  mut next_feedback_handle : Int
}
pub fn AgentFeedbackService::accept_feedback(Self, @common.Uri, String) -> Unit
pub fn AgentFeedbackService::add_feedback(Self, @common.Uri, @common.Range, String, kind? : AgentFeedbackKind, state? : AgentFeedbackState) -> AgentFeedback
pub fn AgentFeedbackService::add_reply(Self, @common.Uri, String, String) -> Unit
pub fn AgentFeedbackService::clear_feedback(Self, @common.Uri) -> Unit
pub fn AgentFeedbackService::dispose(Self) -> Unit
pub fn AgentFeedbackService::get_feedback(Self, @common.Uri) -> Array[AgentFeedback]
pub fn AgentFeedbackService::get_navigation_bearing(Self, @common.Uri, Array[String]) -> AgentFeedbackNavigationBearing
pub fn AgentFeedbackService::get_next_navigable_item(Self, @common.Uri, Array[String], next~ : Bool) -> String?
pub fn AgentFeedbackService::is_feedback_enabled(Self, @common.Uri) -> Bool
pub fn AgentFeedbackService::mark_feedback_submitted(Self, @common.Uri) -> Unit
pub fn AgentFeedbackService::new() -> Self
pub fn AgentFeedbackService::on_did_add_feedback(Self, (AgentFeedbackAddedEvent) -> Unit) -> @common.Disposable
pub fn AgentFeedbackService::on_did_add_reply(Self, (AgentFeedbackReplyAddedEvent) -> Unit) -> @common.Disposable
pub fn AgentFeedbackService::on_did_change_feedback(Self, (AgentFeedbackChangeEvent) -> Unit) -> @common.Disposable
pub fn AgentFeedbackService::on_did_change_navigation(Self, (@common.Uri) -> Unit) -> @common.Disposable
pub fn AgentFeedbackService::on_did_submit_feedback(Self, (AgentFeedbackSubmittedEvent) -> Unit) -> @common.Disposable
pub fn AgentFeedbackService::remove_feedback(Self, @common.Uri, String) -> Unit
pub fn AgentFeedbackService::set_feedback_enabled(Self, @common.Uri, Bool) -> Unit
pub fn AgentFeedbackService::set_feedback_items(Self, @common.Uri, Array[AgentFeedback]) -> Unit
pub fn AgentFeedbackService::set_feedback_resolved(Self, @common.Uri, String, Bool) -> Unit
pub fn AgentFeedbackService::set_navigation_anchor(Self, @common.Uri, String?) -> Unit
pub fn AgentFeedbackService::update_feedback(Self, @common.Uri, String, String) -> Unit
```

The complete 33-line quick-diff interface is short; its service seam uses only
bottom URI/string/disposable vocabulary even though the implementation package
also owns diff behavior:

```text
// Generated using `moon info`, DON'T EDIT IT
package "moonbit-community/editor/viewer/contrib/quick_diff/common"

import {
  "moonbit-community/editor/viewer/common/diff",
  "moonbitlang/core/debug",
}

// Values
pub fn get_change_type(@diff.Change) -> ChangeType

// Errors

// Types and methods
pub(all) enum ChangeType {
  Modify
  Add
  Delete
} derive(Eq, @debug.Debug)
pub impl Show for ChangeType

pub struct QuickDiffService {
  // private fields
}
pub fn QuickDiffService::get_original_content(Self, @moonbit-community/editor/base/common.Uri) -> String?
pub fn QuickDiffService::new() -> Self
pub fn QuickDiffService::on_did_change_original(Self, (@moonbit-community/editor/base/common.Uri) -> Unit) -> @moonbit-community/editor/base/common.Disposable
pub fn QuickDiffService::set_original_content(Self, @moonbit-community/editor/base/common.Uri, String?) -> Unit

// Type aliases

// Traits

```

`platform/log/pkg.generated.mbti:14-43,67-70`:

```text
pub(all) struct LogEntry {
  level : LogLevel
  category : String
  message : String
  details : Array[(String, String)]
} derive(Eq, @debug.Debug)

pub(all) enum LogLevel {
  Off
  Trace
  Debug
  Info
  Warning
  Error
} derive(Eq, @debug.Debug)
pub fn LogLevel::is_warning_or_error(Self) -> Bool
pub fn LogLevel::label(Self) -> String

pub(all) struct LogService {
  level : LogLevel
  logger : &Logger
}
pub fn LogService::debug(Self, String, String, details? : Array[(String, String)]) -> Unit
pub fn LogService::error(Self, String, String, details? : Array[(String, String)]) -> Unit
pub fn LogService::flush(Self) -> Unit
pub fn LogService::info(Self, String, String, details? : Array[(String, String)]) -> Unit
pub fn LogService::log(Self, LogEntry) -> Unit
pub fn LogService::new(level? : LogLevel, logger? : &Logger) -> Self
pub fn LogService::trace(Self, String, String, details? : Array[(String, String)]) -> Unit
pub fn LogService::warn(Self, String, String, details? : Array[(String, String)]) -> Unit
```

```text
pub(open) trait Logger {
  fn log(Self, LogEntry) -> Unit
  fn flush(Self) -> Unit
}
```

`viewer/contrib/hover/pkg.generated.mbti:225-236,295-305` is the direct public
consumer omitted by the original service-owner count:

```text
pub(all) struct HoverParticipantRegistry {
  entries : Array[(HoverParticipantServices) -> HoverParticipantHandle]
}
pub fn HoverParticipantRegistry::build_all(Self, HoverParticipantServices) -> Array[HoverParticipantHandle]
pub fn HoverParticipantRegistry::get_all(Self) -> Array[(HoverParticipantServices) -> HoverParticipantHandle]
pub fn HoverParticipantRegistry::new() -> Self
pub fn HoverParticipantRegistry::register(Self, (HoverParticipantServices) -> HoverParticipantHandle) -> Unit

pub(all) struct HoverParticipantServices {
  languages : @languages.Languages
  marker_decorations : @markers.MarkerDecorationsService
  log_service : @log.LogService
}
```

```text
pub struct MarkdownHoverParticipant {
  // private fields
}
pub fn MarkdownHoverParticipant::hover_participant_handle(Self) -> HoverParticipantHandle
pub fn MarkdownHoverParticipant::new(@languages.Languages, @log.LogService) -> Self

pub struct MarkerHoverParticipant {
  // private fields
}
pub fn MarkerHoverParticipant::hover_participant_handle(Self) -> HoverParticipantHandle
pub fn MarkerHoverParticipant::new(@markers.MarkerDecorationsService) -> Self
```

## Current Public Type-Leak Edges

The generated-interface search is closed over all checked-in `viewer/**/
pkg.generated.mbti` files. It finds the following exact owner-to-consumer
edges relevant to this dependency companion:

| Leaked/current type | Current owner | Public consumers in affected interfaces | Target owner/result |
|---|---|---|---|
| `CursorChangeReason` | duplicated in root `viewer` and `common/cursor` | root events/methods; cursor state/controller; view-model events/methods; browser-view event | one `common/editor_api` enum; no variant adapters |
| `CursorPositionChangedEvent`, `CursorSelectionChangedEvent` | root `viewer` | root event subscriptions | `common/editor_api`, because their vocabulary is base positions + `common/core.Selection` + canonical reason |
| `WrappingIndent` | `common/view_model` | view-model options/line breaking and root options | `common/editor_api` |
| `RenderValidationDecorations` | `common/view_model` | view-model filtering/options, browser-view configuration variant, root options | `common/editor_api` |
| `RenderWhitespace` | `common/view_layout` | view-layout render input, common line helper, view-model bridge, browser view, root options | `common/editor_api` |
| `RenderLineHighlight` | `common/view_layout` | view-layout helpers, browser view, root options | `common/editor_api` |
| `ShowFoldingControls` | `contrib/folding/browser` | folding decoration provider and root options | `common/editor_api`; moving it upward from a JS-only owner makes the option contract multi-target |
| `ViewZone`, `ViewZoneChangeAccessor` | `browser/view` runtime package, re-exported by root | root constructor/method/aliases and browser-view runtime | public descriptor + opaque callback accessor in `viewer/browser`; private registered/runtime state stays in `browser/view` |
| raw overlay-widget `(String, Element)` pair | root `viewer` method arguments | root feedback widget host and public add/remove surface | one opaque unmanaged `viewer/browser.OverlayWidget` handle plus a root inference factory; no parallel root widget type |
| `EditorContribution`, `EditorContributionInstantiation` | root `viewer` | root only | private registry types; remove from root generated interface |
| concrete service implementations | languages, markers, contrib feedback/quick diff, platform log | public `ViewerServices` fields/constructor; public hover/folding/view inputs | private root aggregate over vocabulary-specific handles; feedback host DTOs/handle in `common/agent_feedback_api`; quick-diff handle in `common/quick_diff_api`; no root `viewer/contrib/**` path |

### Closed overlay-widget dependency route

`viewer/browser` owns one opaque unmanaged `OverlayWidget` handle containing
an immutable id and DOM `Element`. This implementation fixes only the
null/self-positioned overlay subset already used by the Viewer: there is no
layout method and no positioned-overlay or content-widget contract. Those
larger Monaco contracts remain upstream-ledger `DEFERRED` work.

Root adds
`overlay_widget(String, @dom.Element) -> @browser.OverlayWidget` so an external
root/common-only host can construct the browser-owned handle without importing
`viewer/browser`; callback/argument inference carries the type. Root
`Viewer::add_overlay_widget` and `Viewer::remove_overlay_widget` both take that
same handle. The handle is unmanaged: removal unregisters it but does not own
or destroy the host-provided element.

This adds no target edge. Root already imports `viewer/browser`, and
`viewer/browser` already imports its DOM and lower view-model prerequisites.
The existing one-way `viewer/browser/view -> viewer/browser` dependency remains
unchanged.

Mechanical reproduction:

```sh
rg -n -P '\b(CursorChangeReason|WrappingIndent|RenderWhitespace|RenderLineHighlight|RenderValidationDecorations|ShowFoldingControls|ViewZone|ViewZoneChangeAccessor|OverlayWidget|add_overlay_widget|remove_overlay_widget)\b' \
  --glob 'pkg.generated.mbti' viewer
rg -n 'EditorContribution|ViewerOptions|ViewerServices' \
  viewer/pkg.generated.mbti
```

## Scoped Manifest and Import Inventory

The manifest set includes every current/target type owner, every changed public
capability consumer, the root facade, the external/workbench hosts, and every
browser-scenario package that currently reaches a soon-to-be-private service
field.

| Manifest | Lines | SHA-256 | Target tier |
|---|---:|---|---|
| `base/common/moon.pkg` | 8 | `ba3eef771c817e5f49448a02029e5b0e953ca133098a592c85d9154542ad111b` | multi-target bottom |
| `base/browser/moon.pkg` | 6 | `fe82f5ed32e360f64c425e14530ecb0fc3b05edbd882fbcab581553a7856bc64` | JS browser bottom |
| `platform/log/moon.pkg` | 1 | `01ba4719c80b6fe911b091a7c05124b64eeece964e09c058ef8f9805daca546b` | multi-target service vocabulary |
| `syntax/moon.pkg` | 7 | `fa4e4ae488821969e3810bf1635309dc03a2c0a23cbef7b1fcd920873581595a` | multi-target tokenizer vocabulary |
| `language/moon.pkg` | 4 | `cd2873ce91df98d167298d00d5f972793adce4d8160d9484a375bcbbcaeddfb3` | multi-target provider vocabulary above model |
| `viewer/common/services/moon.pkg` | 1 | `01ba4719c80b6fe911b091a7c05124b64eeece964e09c058ef8f9805daca546b` | multi-target bottom |
| `viewer/common/tokens/moon.pkg` | 4 | `442f32fc702b2587013d4691c7834a796eb95c8f6b5dfea9f9d7417a9ec77086` | multi-target |
| `viewer/common/diff/moon.pkg` | 4 | `466abd71815be3c12c5feaa1768738bf72e0e924e949bbb2b1088da87befd045` | multi-target |
| `viewer/common/model/moon.pkg` | 6 | `954469f5d5560bfe8172c3ac2786092784fd3314d83d5ea538418da05f2540c6` | multi-target model implementation |
| `viewer/common/core/moon.pkg` | 3 | `d88df60796c3b5dab9a5645dc7f4068449fceef76452663bbce4c506f72e4962` | multi-target selection contract |
| `viewer/common/cursor/moon.pkg` | 5 | `2101369ebb135989cc0890ba6d9be11f217d1b8560ec58e6059a969c1d9c902e` | multi-target consumer |
| `viewer/common/view_layout/moon.pkg` | 7 | `19c1d00e1b6aa06b9fe107b2ceea046a5992b05e9b0a4a5e869eedd677b938e8` | multi-target consumer |
| `viewer/common/view_model/moon.pkg` | 18 | `dffb2062067dfa95a133c6218335f20e0e0a032352121edaf08a06b5c35bf6a4` | multi-target consumer |
| `viewer/common/moon.pkg` | 10 | `26e37c1fbaa8f83696c083d9dc61f1a05c05b75faaa1d6646eb4f14002acc640` | multi-target compatibility consumer |
| `viewer/common/languages/moon.pkg` | 18 | `0416afcdbc084a64e59da505c0066075b729b5505ef82c44d8a7afd1f45bc1dd` | multi-target capability owner |
| `viewer/common/markers/moon.pkg` | 5 | `a065a7891d030830791018c0d6c9296bdddb24b888000b972de6b3fe5ec13c9c` | multi-target capability owner |
| `viewer/contrib/agent_feedback/moon.pkg` | 3 | `d88df60796c3b5dab9a5645dc7f4068449fceef76452663bbce4c506f72e4962` | multi-target concrete feedback adapter |
| `viewer/contrib/agent_feedback/browser/moon.pkg` | 9 | `f694046976a2857d4d20d1fed4de5deebde0b5cf8286698efb5dc6d939969132` | JS UI-projection consumer |
| `viewer/contrib/quick_diff/common/moon.pkg` | 4 | `6ea3d36a0d878ac1be5f47d4413b32bb805991eed56f3e1c4eab4dd1093af56a` | multi-target concrete baseline adapter |
| `viewer/contrib/folding/browser/moon.pkg` | 8 | `81ee7eca1251baedbe4e5d75ea525beae1ce865fa354f5e9a82ecded77328aed` | JS browser consumer |
| `viewer/contrib/hover/moon.pkg` | 19 | `4ece8e5420980494f7b80b3c2e7664732698fbcb2b621ad8da25c4ee05096fba` | multi-target capability consumer |
| `viewer/browser/moon.pkg` | 8 | `b32619e7a39425c84c31d43f0209cad37c18a4f1f44965d4b6a65b77bd776280` | JS public browser contracts |
| `viewer/browser/view/moon.pkg` | 16 | `00b8a700061a16b9050619a0d79426c4e3206b852db3d5310b316e1661f206b3` | JS private/runtime consumer |
| `viewer/moon.pkg` | 33 | `256404c20cc964cf6d0e3810e43c12e21f73525f67d760aa9058dc5378aefbca` | JS root facade |
| `internal/shell/examples/embedded_viewer/moon.pkg` | 20 | `01653bb6880f8c6c6352391b945a0ec811915d4eb2c3402459c6b44c81009af1` | JS external-host sentinel |
| `internal/shell/workbench/moon.pkg` | 25 | `9f2c4d398690ff1e32b71c64548a9dce77f7d4c586212f44d96fc85fa129b1f5` | JS workbench consumer |
| `tests/browser/moonbit/agent_feedback/moon.pkg` | 14 | `949a0148aa1db73fa48611a63526d005db8967ace3ee6ed9b7426e01683f8160` | JS concrete-feedback caller |
| `tests/browser/moonbit/component/moon.pkg` | 19 | `41b8c88f25c22c2a9d6060530ad2e664537f4ae5c415a8aa1290545eed3ff494` | JS language/marker/log caller |
| `tests/browser/moonbit/model_swap/moon.pkg` | 14 | `ebbca251df0fd3ae1d20d2fc5da179d69159fa14717ee428295a47be1b189739` | JS service-lifetime caller |
| `tests/browser/moonbit/quick_diff/moon.pkg` | 13 | `56764290c1d41e7658235b5e2219264baf67444a7c7c99778ca04914d2dc6db0` | JS concrete quick-diff caller |
| `tests/browser/moonbit/set_value/moon.pkg` | 13 | `56764290c1d41e7658235b5e2219264baf67444a7c7c99778ca04914d2dc6db0` | JS concrete quick-diff caller |

Current production-import adjacency (`A -> B` means `A` imports `B`; test and
white-box-only imports are omitted here but remain covered by the 184-row
manifest denominator):

```text
base/browser -> base/common, rabbita/dom
syntax -> base/common
language -> base/common, viewer/common/model
viewer/common/tokens -> base/common, viewer/common/services
viewer/common/diff -> base/common, piediff
viewer/common/model -> base/common, syntax, viewer/common/services, viewer/common/tokens
viewer/common/core -> base/common
viewer/common/cursor -> base/common, viewer/common/core, viewer/common/model
viewer/common/view_layout -> base/common
viewer/common/view_model -> base/common, common/config, common/core, common/cursor, common/model, common/tokens, common/view_layout, core/json
viewer/common -> common/view_layout, common/view_model
viewer/common/languages -> base/common, language, platform/log, syntax, common/model, common/services, common/tokens
viewer/common/markers -> base/common, language, common/model
viewer/contrib/agent_feedback -> base/common
viewer/contrib/agent_feedback/browser -> base/common, contrib/agent_feedback, rabbita/dom, cmark, cmark_html
viewer/contrib/quick_diff/common -> base/common, common/diff
viewer/contrib/folding/browser -> base/common, common/core, common/languages, common/model
viewer/contrib/hover -> base/common, language, platform/log, syntax, common, common/model, common/languages, common/markers, common/services, common/view_model, cmark, cmark_html, cmark_renderer
viewer/browser -> base/browser, base/common, common/view_model, rabbita/dom
viewer/browser/view -> base/common, platform/log, browser, common, common/core, common/cursor, common/markers, common/model, common/view_layout, common/view_model, ui/scrollbar, rabbita/dom
viewer -> base/common, language, platform/log, browser, browser/config, browser/view, browser/controller, common/config, common/cursor, common/core, common/model, contrib/agent_feedback, contrib/agent_feedback/browser, contrib/folding/browser, contrib/hover, contrib/hover/browser, contrib/quick_diff/common, contrib/quick_diff/browser, common/languages, common/markers, ui/scrollbar, common/view_layout, common/view_model, rabbita/dom, rabbita/js
embedded_viewer -> base/common, viewer, common/languages, common/model, syntax/lang_moonbit, shell/file_tree, shell/workspace, rabbita, rabbita/dom, rabbita/cmd, rabbita/html, rabbita/sub
workbench -> base/common, language, platform/log, shell/remote_protocol, viewer, common/model, contrib/agent_feedback, syntax/lang_javascript, syntax/lang_json, syntax/lang_moonbit, shell/file_tree, shell/workspace, core/json, rabbita, rabbita/dom, rabbita/cmd, rabbita/html, rabbita/js, rabbita/sub, rabbita/svg, rabbita/websocket
test agent_feedback -> base/common, viewer, contrib/agent_feedback, common/model, test/support, rabbita/dom
test component -> base/common, language, platform/log, viewer, browser/view, common/languages, common/model, common/core, syntax/lang_moonbit, syntax, test/support, rabbita/dom, rabbita/js
test model_swap -> base/common, language, viewer, common/model, test/support, rabbita/dom
test quick_diff -> base/common, viewer, common/model, test/support, rabbita/dom
test set_value -> base/common, viewer, common/model, test/support, rabbita/dom
```

Reproduction from the immutable baseline object:

```zsh
BASE=e5beb1c8cd5c9d5b2fbfbfca55025438b17e1ca3
files=(
  base/common/moon.pkg base/browser/moon.pkg platform/log/moon.pkg
  syntax/moon.pkg language/moon.pkg viewer/common/services/moon.pkg
  viewer/common/tokens/moon.pkg viewer/common/diff/moon.pkg
  viewer/common/model/moon.pkg viewer/common/core/moon.pkg
  viewer/common/cursor/moon.pkg viewer/common/view_layout/moon.pkg
  viewer/common/view_model/moon.pkg viewer/common/moon.pkg
  viewer/common/languages/moon.pkg viewer/common/markers/moon.pkg
  viewer/contrib/agent_feedback/moon.pkg
  viewer/contrib/agent_feedback/browser/moon.pkg
  viewer/contrib/quick_diff/common/moon.pkg
  viewer/contrib/folding/browser/moon.pkg viewer/contrib/hover/moon.pkg
  viewer/browser/moon.pkg
  viewer/browser/view/moon.pkg viewer/moon.pkg
  internal/shell/examples/embedded_viewer/moon.pkg
  internal/shell/workbench/moon.pkg
  tests/browser/moonbit/agent_feedback/moon.pkg
  tests/browser/moonbit/component/moon.pkg
  tests/browser/moonbit/model_swap/moon.pkg
  tests/browser/moonbit/quick_diff/moon.pkg
  tests/browser/moonbit/set_value/moon.pkg
)
for f in "${files[@]}"; do
  git show "$BASE:$f"
done | wc -l
for f in "${files[@]}"; do
  git show "$BASE:$f" | sed -n '/^import {/,/^}/p' | rg '^  "'
done | wc -l
for f in "${files[@]}"; do
  h=$(git show "$BASE:$f" | shasum -a 256 | awk '{print $1}')
  printf '%s  %s\n' "$h" "$f"
done | shasum -a 256
```

## Service-Capability Dependency-Bottom Test

The generic `viewer/common/editor_api` package is dependency-bottom and
value-only. The exact operations used by production Viewer/contribution code
mention model, language, marker, feedback, and logging vocabulary, so placing
one aggregate service record in `editor_api` would either introduce upward
imports or duplicate canonical types. Gate A therefore fixes route (c):
language, marker, and log handles stay beside their allowed vocabularies;
feedback and quick-diff host contracts move to dedicated `viewer/common/**`
API packages; concrete implementations remain under their current owners.

### Exact production capability floor

The following table is exhaustive for operations that remain reachable from
root `viewer` or a production editor contribution. These operations, and only
these operations, form the private handles aggregated by `ViewerServices`.

| Handle owner | Exact operations in the final handle | Production evidence | Lifetime |
|---|---|---|---|
| `viewer/common/languages.LanguageHandle` | `get_language_configuration(String) -> LanguageConfiguration`; `async hover_at(TextModel, Int, token? : CancellationToken) -> Hover? noraise` | folding reads configuration at `viewer/contrib/folding/browser/indent_range_provider.mbt:58-63`; hover resolves at `viewer/contrib/hover/hover_participants.mbt:248-265` | the handle adapter prebinds its `LogHandle`; hover cancellation/generation owns request lifetime, so the handle returns no registration |
| `viewer/common/markers.MarkerDecorationsHandle` | `acquire_model(TextModel) -> Disposable`; `on_did_change_marker_decorations((TextModel) -> Unit) -> Disposable`; `get_live_markers_for_model(TextModel) -> Array[(Range, Marker)]` | `viewer/attach_model.mbt:61-67`; `viewer/viewer.mbt:378-389`; `viewer/contrib/hover/hover_participants.mbt:167-184` | the acquire lease is model-scoped and is disposed by `ModelData::dispose` (`viewer/viewer.mbt:176-193`); the change subscription is Viewer-lifetime (`viewer/viewer.mbt:417-435`) |
| `viewer/common/agent_feedback_api.AgentFeedbackHandle` | `on_did_change_feedback((AgentFeedbackChangeEvent) -> Unit) -> Disposable`; `on_did_change_navigation((Uri) -> Unit) -> Disposable`; `is_feedback_enabled(Uri) -> Bool`; `get_feedback(Uri) -> Array[AgentFeedback]`; `get_navigation_bearing(Uri, Array[String]) -> AgentFeedbackNavigationBearing`; `add_feedback(Uri, Range, String, kind? : AgentFeedbackKind, state? : AgentFeedbackState) -> AgentFeedback`; `mark_feedback_submitted(Uri) -> Unit`; `remove_feedback(Uri, String) -> Unit`; `accept_feedback(Uri, String) -> Unit`; `set_navigation_anchor(Uri, String?) -> Unit`; `update_feedback(Uri, String, String) -> Unit`; `add_reply(Uri, String, String) -> Unit` | input contribution calls are at `viewer/agent_feedback_host.mbt:69-86,151-154,248-250,598-604`; widget contribution calls are at `viewer/agent_feedback_widgets_host.mbt:53-75,122-124,151-173,259-265` | returned change/navigation subscriptions live in contribution listener arrays and are disposed through `viewer/editor_extensions.mbt:120-156` |
| `viewer/common/quick_diff_api.QuickDiffHandle` | `get_original_content(Uri) -> String?`; `on_did_change_original((Uri) -> Unit) -> Disposable` | `viewer/quick_diff_host.mbt:16-32`; `viewer/quick_diff_contribution.mbt:45-57` | the subscription is stored by the quick-diff contribution and disposed through `viewer/editor_extensions.mbt:151-156` |
| `platform/log.LogHandle` | `error(String, String, details? : Array[(String, String)]) -> Unit`; `warn(String, String, details? : Array[(String, String)]) -> Unit` | view-zone callback failures use `error` at `viewer/browser/view/view_zones.mbt:716-725`; the prebound language adapter uses `warn` at `viewer/common/languages/languages.mbt:153-163,207-217` | callback handle only; no registration |

`Languages::document_symbols`, provider/tokenizer registration, marker writes,
and feedback/quick-diff host mutations not listed above are not production
Viewer capabilities. In particular, `diagnostics_for_resource` is used today
only to populate the debug build/render payloads at
`viewer/attach_model.mbt:192-200,407-413` and
`viewer/view_host.mbt:108-120`. Those payloads are removed by the closed debug
migration, so `diagnostics_for_resource` is deliberately absent from the final
marker handle.

Marker construction has a second, lower adapter seam inside
`viewer/common/markers`. Its fixed public names/signatures are:

```text
pub fn MarkerService::marker_service_handle(Self) -> MarkerServiceHandle
pub fn MarkerServiceHandle::on_did_change_markers(Self, (Array[@common.Uri]) -> Unit) -> @common.Disposable
pub fn MarkerServiceHandle::read(Self, MarkerReadOptions) -> Array[Marker]
pub fn MarkerServiceHandle::remove(Self, String, Array[@common.Uri]) -> Unit
pub fn MarkerDecorationsService::new(MarkerServiceHandle) -> Self
pub fn MarkerDecorationsService::marker_decorations_handle(Self) -> MarkerDecorationsHandle
pub(all) enum MarkerDecorationsSource {
  MarkerStore(MarkerServiceHandle)
  Decorations(MarkerDecorationsHandle)
}
```

The first four declarations define the lower backing handle; their three
operations are exactly those used by
`MarkerDecorationsService` at
`viewer/common/markers/marker_decorations_service.mbt:50-68,318-322,428-430`.
The fifth declaration is the required construction bridge: it replaces the
current `MarkerDecorationsService::new(MarkerService)` signature, and all 17
existing non-definition callers retain their concrete store and pass
`markers.marker_service_handle()`. It lets `ViewerServices` create and own a
default marker-decorations backing around a caller-retained marker store.
Root/contributions still receive only the `MarkerDecorationsHandle`
three-operation surface in the production table.
`MarkerDecorationsSource` is the single closed constructor input: it prevents
ambiguous independent optional marker handles while still allowing a caller to
supply an already-adapted decoration handle.

### Concrete host-only operation table

Workbench and browser scenarios retain concrete values and perform their
policy/fixture mutations directly. They derive the narrow handles above for
`ViewerServices`; they never recover a concrete implementation from it.

| Caller tier | Concrete owner | Exact operations retained outside `ViewerServices` | Evidence |
|---|---|---|---|
| WB | `viewer/common/languages.Languages` | `register_hover_provider`, `register_document_symbol_provider`, `set_tokens_provider` | `internal/shell/workbench/language_client.mbt:11-20`; `internal/shell/workbench/app.mbt:180-197` |
| WB | `viewer/common/markers.MarkerService` | `on_did_change_markers`, `diagnostics_for_resource`, `set_diagnostics` | `internal/shell/workbench/app.mbt:140-147,454-466`; `internal/shell/workbench/language_client.mbt:69-82` |
| WB | `viewer/contrib/agent_feedback.AgentFeedbackService` | `on_did_change_feedback`, `set_feedback_enabled`, `get_feedback`, `set_feedback_items` | `internal/shell/workbench/agent_feedback.mbt:22-28,34-47,86-104` |
| WB | `platform/log.LogService` | `error` | `internal/shell/workbench/language_client.mbt:24-44` |
| WB | quick diff | none | no workbench call site exists |
| BR | `viewer/common/languages.Languages` | `set_tokens_provider`, `register_hover_provider` | `tests/browser/moonbit/component/viewer_api_scenario.mbt:87-98`; `tests/browser/moonbit/component/cursor_input_events_scenario.mbt:109`; `tests/browser/moonbit/component/render_invalidation_scenario.mbt:121,354` |
| BR | `viewer/common/markers.MarkerService` | `set_diagnostics` | `tests/browser/moonbit/component/viewer_api_scenario.mbt:47-55`; `tests/browser/moonbit/model_swap/model_swap_scenario.mbt:62-69` |
| BR | `viewer/contrib/agent_feedback.AgentFeedbackService` | `on_did_add_feedback`, `on_did_add_reply`, `on_did_change_feedback`, `on_did_submit_feedback`, `set_feedback_enabled`, `set_feedback_items` | `tests/browser/moonbit/agent_feedback/agent_feedback_scenario.mbt:33-80` |
| BR | `viewer/contrib/quick_diff/common.QuickDiffService` | `set_original_content` | `tests/browser/moonbit/quick_diff/quick_diff_scenario.mbt:48-52`; `tests/browser/moonbit/set_value/set_value_scenario.mbt:62` |

The WB `diagnostics_for_resource` read remains legal on the retained concrete
marker service. It is not evidence for adding that operation to the Viewer
handle. Likewise, the browser-only registrations and writes are fixture setup,
not production dependency injection.

### Gate A correction: split value contracts from service capabilities

`viewer/common/editor_api` remains the dependency-bottom owner only for:

- `CursorChangeReason` and public cursor event payloads;
- `WrappingIndent`, `RenderWhitespace`, `RenderLineHighlight`,
  `RenderValidationDecorations`, and `ShowFoldingControls`;
- other DOM-free records whose field types are limited to `base/common`,
  `viewer/common/core`, and language primitives accepted by the main
  disposition inventory.

Its target production manifest is therefore closed to:

```text
viewer/common/editor_api -> base/common, viewer/common/core
```

It has no `supported_targets` restriction, DOM import, model import, language/
syntax/log import, or contribution import.

The reviewed owners are closed:

| Capability | Declaration owner | Concrete/adaptation owner |
|---|---|---|
| `LanguageHandle` | `viewer/common/languages` | `Languages::language_handle` captures the selected `LogHandle` |
| `MarkerServiceHandle`, `MarkerDecorationsHandle`, `MarkerDecorationsSource` | `viewer/common/markers` | `MarkerService::marker_service_handle` produces the lower adapter handle; `MarkerDecorationsService::new(MarkerServiceHandle)` consumes it; `MarkerDecorationsService::marker_decorations_handle` produces the final Viewer handle |
| `AgentFeedbackHandle` plus its DTOs/events | `viewer/common/agent_feedback_api` | common `AgentFeedbackHandle::new` accepts the exact callback floor; `AgentFeedbackService::agent_feedback_handle` remains the contrib convenience adapter |
| `QuickDiffHandle` | `viewer/common/quick_diff_api` | common `QuickDiffHandle::new` accepts the exact callback floor; `QuickDiffService::quick_diff_handle` remains the contrib convenience adapter |
| `LogHandle` | `platform/log` | `LogService::log_handle` produces the callback handle |

`viewer/common/agent_feedback_api` owns exactly `AgentFeedback`,
`AgentFeedbackKind`, `AgentFeedbackState`, `AgentFeedbackNavigationBearing`,
`AgentFeedbackAddedEvent`, `AgentFeedbackChangeEvent`,
`AgentFeedbackReplyAddedEvent`, `AgentFeedbackSubmittedEvent`, and the callback
handle. These definitions move; they are not copied. UI-only
`SessionEditorComment` and its grouping/sort projection remain in
`viewer/contrib/agent_feedback`, so
`viewer/contrib/agent_feedback/browser` keeps its current UI contract.
`viewer/common/quick_diff_api` owns only the callback handle expressed with
`Uri`, `String?`, and `Disposable`.

The adapter and root-constructor names/signatures are fixed:

```text
pub fn Languages::language_handle(Self, @log.LogHandle) -> LanguageHandle
pub fn MarkerService::marker_service_handle(Self) -> MarkerServiceHandle
pub fn MarkerDecorationsService::new(MarkerServiceHandle) -> Self
pub fn MarkerDecorationsService::marker_decorations_handle(Self) -> MarkerDecorationsHandle
pub fn AgentFeedbackService::agent_feedback_handle(Self) -> @agent_feedback_api.AgentFeedbackHandle
pub fn QuickDiffService::quick_diff_handle(Self) -> @quick_diff_api.QuickDiffHandle
pub fn LogService::log_handle(Self) -> LogHandle

pub fn ViewerServices::new(
  languages? : @languages.LanguageHandle,
  markers? : @markers.MarkerDecorationsSource,
  agent_feedback? : @agent_feedback_api.AgentFeedbackHandle,
  quick_diff? : @quick_diff_api.QuickDiffHandle,
  log_service? : @log.LogHandle,
) -> Self
```

The two common feature handles are opaque but directly constructible. Their
exact target constructors are:

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

Every callback is required; neither constructor supplies no-op defaults or
owns captured backing state. `AgentFeedbackHandle::add_feedback` retains its
public optional `kind?` and `state?` parameters and forwards their normalized
optional values to the constructor callback, so the captured backing defines
the omitted-value defaults. The contrib service adapters call these same
constructors; they are conveniences, not the only construction route.

`markers` is one closed union, never two independent optionals:

- omitted: the bundle creates and owns both `MarkerService` and
  `MarkerDecorationsService` defaults;
- `MarkerStore(handle)`: the caller owns the marker-store backing; the bundle
  creates and owns the `MarkerDecorationsService` adapter around that handle;
- `Decorations(handle)`: the caller owns the supplied decoration backing; the
  bundle creates and owns neither marker backing.

Root `ViewerServices` becomes opaque and privately aggregates the final
handles. It creates defaults for every omitted capability and never exposes a
concrete service field. This fixes the external-host route without any
`viewer/contrib/**` path in the root generated interface.

### `ViewerServices` bundle lifecycle

`ViewerServices::dispose` is public and idempotent. It releases only default
backings created by that exact bundle, in this fixed order:

1. marker-decorations backing;
2. marker-service backing;
3. feedback backing.

It never disposes a caller-supplied handle. A `Viewer` calls bundle disposal
only when it created the bundle internally. An explicitly supplied bundle is
caller-owned and may be shared; its owner calls `dispose` only after every
sharing `Viewer` is disposed. Callers own and may idempotently dispose every
returned provider registration, subscription, and marker lease. Disposing a
bundle-owned default backing necessarily terminates subscriptions and leases
serviced by that backing; bundle disposal never touches caller-supplied
backings or their still-live handles.

`tests/browser/moonbit/model_swap/model_swap_scenario.mbt:215-217` replaces
private-field disposal after the final Viewer with `services.dispose()` for
bundle-created defaults, followed by explicit disposal of any caller-created
marker-decorations backing and then the retained `MarkerService`.
`viewer/lifecycle_ownership_wbtest.mbt` proves idempotence,
default-only release, explicit-handle non-ownership, and shared-bundle
ordering. There is no public/test factory that leaks a bundle's default
backings.

## Target Dependency Graph and Cycle Proof

The four target packages below are absent at the immutable baseline. For each
row, both `moon.pkg` and `pkg.generated.mbti` are absent; absence was checked
with `git cat-file -e "$BASE:$path"` in the closed-denominator reproduction
above.

| New package | Target class | Closed role |
|---|---|---|
| `viewer/common/editor_api` | multi-target | canonical value-only editor contracts |
| `viewer/common/agent_feedback_api` | multi-target | moved feedback host DTOs/events plus callback handle |
| `viewer/common/quick_diff_api` | multi-target | baseline callback handle |
| `viewer/browser/testing` | JS-only | Viewer-id-keyed workbench/browser observability and test controls |

The Gate A target edges are:

```text
viewer/common/editor_api -> base/common, viewer/common/core
viewer/common/agent_feedback_api -> base/common
viewer/common/quick_diff_api -> base/common

viewer/common/cursor
  -> viewer/common/editor_api + existing base/common/core/model prerequisites
viewer/common/view_layout
  -> viewer/common/editor_api + base/common
viewer/common/view_model
  -> viewer/common/editor_api + existing cursor/view-layout/model prerequisites
viewer/common
  -> viewer/common/editor_api + existing view-layout/view-model prerequisites

viewer/contrib/agent_feedback
  -> viewer/common/agent_feedback_api + base/common
viewer/contrib/agent_feedback/browser
  -> viewer/contrib/agent_feedback + viewer/common/agent_feedback_api + DOM
viewer/contrib/quick_diff/common
  -> viewer/common/quick_diff_api + viewer/common/diff + base/common
viewer/contrib/folding/browser
  -> viewer/common/editor_api + existing languages/model/core prerequisites
viewer/contrib/hover
  -> viewer/common/languages + viewer/common/markers + existing hover prerequisites

viewer/browser
  -> viewer/common/editor_api + existing base/browser/view-model/DOM prerequisites
viewer/browser/view
  -> viewer/browser + viewer/common/editor_api + existing common/runtime prerequisites
viewer/browser/testing
  -> only lower base/common, common model/core/editor_api, and log contracts as required
viewer/browser/testing -/> viewer

viewer
  -> viewer/common/{editor_api,agent_feedback_api,quick_diff_api}
  -> viewer/common/{languages,markers} + platform/log
  -> viewer/browser/{view,testing} + private concrete feature adapters

embedded_viewer
  -> viewer + permitted viewer/common contracts only
workbench
  -> viewer + viewer/browser/testing + common capability APIs
  -> concrete languages/markers/feedback/quick-diff/log owners directly
browser scenarios
  -> viewer + viewer/browser/testing + common capability APIs
  -> concrete fixture service owners directly
```

The ranking below contracts unchanged external libraries and unchanged
implementation-only packages into the lowest rank above their prerequisites.
It proves every new or redirected Gate A edge above points strictly downward;
unchanged manifest edges remain covered by the frozen current adjacency table.

| Rank | Relevant packages after the move |
|---:|---|
| 0 | `base/common`, `viewer/common/services`, `platform/log` |
| 1 | `base/browser`, `viewer/common/core`, `syntax`, `viewer/common/tokens`, `viewer/common/diff`, `viewer/common/agent_feedback_api`, `viewer/common/quick_diff_api` |
| 2 | `viewer/common/editor_api`, `viewer/common/model`, `viewer/contrib/agent_feedback`, `viewer/contrib/quick_diff/common` |
| 3 | `language`, `viewer/common/cursor`, `viewer/common/view_layout`, `viewer/contrib/agent_feedback/browser` |
| 4 | `viewer/common/languages`, `viewer/common/markers`, `viewer/common/view_model` |
| 5 | `viewer/common`, `viewer/browser`, `viewer/browser/testing`, `viewer/contrib/folding/browser` |
| 6 | `viewer/browser/view`, `viewer/contrib/hover` |
| 7 | unchanged JS feature/browser adapters consumed by root |
| 8 | root `viewer` |
| 9 | embedded host, workbench, and browser scenario executables |

The important absence/cycle facts are:

- `editor_api` has no capability-owner, model, language, log, DOM, or contrib
  import;
- both new feature API packages are lower than their contrib implementations,
  so no `viewer/common/** -> viewer/contrib/**` edge exists;
- `viewer/browser` never imports `viewer/browser/view`; its public accessor is
  callback-backed, so the existing `browser/view -> browser` edge stays one
  way;
- `viewer/browser/testing` never imports root `viewer`; root publishes into the
  lower Viewer-id-keyed registry, while WB/BR subscribe to it directly;
- no service/capability owner imports root `viewer`; root aggregates handles
  only at rank 8;
- external hosts receive custom feedback/quick-diff injection through allowed
  `viewer/common/**` contracts by calling the frozen all-callback
  `AgentFeedbackHandle::new` / `QuickDiffHandle::new` constructors, not contrib
  imports.

## Target and Host Constraints

### Multi-target proof

- `viewer/common/{core,cursor,view_layout,view_model,languages,markers}` and
  the current DOM-free contrib service packages omit `supported_targets`, so
  `moon check --target all` checks them on native as well as JS.
- New `viewer/common/{editor_api,agent_feedback_api,quick_diff_api}` must also
  omit `supported_targets`; each declared dependency is multi-target.
- Moving `ShowFoldingControls` out of JS-only folding browser removes a target
  restriction from the public option enum; it does not pull a browser edge
  into common code.
- New `viewer/browser/testing` must declare `supported_targets = "js"`, like
  `viewer/browser`, `viewer/browser/view`, root `viewer`, the embedded example,
  the workbench, and browser scenarios. DOM-facing `ViewZone` stays in this JS
  tier even though the testing registry itself is callback-backed.
- `scripts/check-architecture.mbtx` already rejects JS-only
  `viewer/common/**` packages and requires `viewer/browser/**` packages to be
  JS-only. It must additionally preserve the external-host ban on
  `viewer/browser/testing` and the package's ban on importing root `viewer`.

### External embedded example

Current path:

```text
internal/shell/examples/embedded_viewer
  -> viewer
  -> viewer/common/{languages,model}
```

The example calls `Viewer::create`, `ViewerOptions`, and the root render debug
hook. It does not construct `ViewerServices` or read a concrete service field.
The target keeps it on root/default services and replaces readiness with the
reviewed filtered `Viewer::on_did_change_model` path. It may import
`viewer/common/editor_api` for canonical option/event values. If an external
host chooses custom services, it may import the three common capability API
packages and pass handles into `ViewerServices`; feedback and quick-diff never
require a contrib import. It must not import `viewer/browser/testing`,
`viewer/browser/view`, or a contribution implementation.

The current architecture guard permits external-host stand-ins to import only
root `viewer` and `viewer/common/**`; it does not permit a direct
`viewer/browser` import. The reviewed no-policy-change route is fixed: retain
the root `view_zone` convenience factory returning the canonical
browser-owned descriptor, add the root `overlay_widget` factory returning the
opaque browser-owned unmanaged handle, and let inference supply browser types
at root method boundaries. There is no external-import-guard exception in
this Gate A.

### Internal workbench

Current path:

```text
internal/shell/workbench
  -> viewer
  -> viewer/contrib/agent_feedback
```

It currently reaches `languages`, `markers`, `agent_feedback`,
`quick_diff`, and `log_service` through public `ViewerServices` fields. That is
the leak being removed. The target path is:

```text
internal/shell/workbench
  -> viewer + viewer/browser/testing
  -> viewer/common/{editor_api,agent_feedback_api,quick_diff_api}
  -> viewer/common/{languages,markers,model}
  -> viewer/contrib/{agent_feedback,quick_diff/common}
  -> platform/log + language/syntax provider packages
```

The workbench creates and retains the concrete bundle, derives capability
handles for the opaque root service aggregate, and continues host mutations
through its retained concrete values. This is allowed by
`is_workbench_tier`; no public facade backdoor is needed. Its former root debug
subscriptions move to the Viewer-id-keyed `viewer/browser/testing` registry.

### Browser scenarios

The affected BR executables retain concrete service instances for fixture
setup and import the matching common API packages only to derive handles.
Debug observations, `has_model`, and private geometry/folding controls use
`viewer/browser/testing`, keyed by the already-public `Viewer::get_id`; they do
not regain root debug methods.

| BR package | Retained concrete backing and host action | Closing ownership |
|---|---|---|
| `agent_feedback` | retain `AgentFeedbackService`, derive the common feedback handle, then perform add/reply/change/submit/enable/item fixture operations on the concrete value | dispose listener registrations, then the Viewer/bundle defaults, then the caller-owned feedback backing |
| `component` | each scenario retains the `Languages`, `MarkerService`, or log backing needed for its provider/tokenizer/diagnostic setup and derives only the reviewed Viewer handles | dispose returned provider/tokenizer registrations and each caller-owned disposable backing after its Viewer; bundle defaults remain `services.dispose()`'s responsibility |
| `model_swap` | retain `MarkerService`, pass `MarkerStore(markers.marker_service_handle())` so the bundle creates the default decoration backing, and publish swap diagnostics on the concrete marker value | after the final sharing Viewer, call `services.dispose()` for bundle-owned decorations/other defaults, then explicitly dispose the retained marker service |
| `quick_diff` | retain `QuickDiffService`, derive the common quick-diff handle, and set the original on the concrete value | dispose the Viewer and bundle defaults; the current backing owns no separate disposable resource |
| `set_value` | retain `QuickDiffService`, derive the common quick-diff handle, and set the original on the concrete value | dispose the Viewer and bundle defaults; the current backing owns no separate disposable resource |

No caller-supplied backing is reclassified as bundle-owned merely because its
handle is passed to `ViewerServices`. All eight executable/UI
`pkg.generated.mbti` sentinels remain byte-identical even when these JS-only
manifests and call sites change.

## Dependency Gate Reconciliation

- [x] 14/14 changed checked-in interfaces total 2,869 lines and have full
      SHA-256s plus ordered aggregate
      `be2194c4fe6006e939100b37b7a09e81942cc3d42e867b8d12e781312321dab4`.
- [x] all eight byte-identical executable/UI sentinels total 218 lines and have
      ordered aggregate
      `206020d81b7252744f963a095408654eb1648358846c6e75c81fd559007fca09`.
- [x] both `moon.pkg` and `pkg.generated.mbti` absence is recorded for all four
      new packages: `editor_api`, `agent_feedback_api`, `quick_diff_api`, and
      JS-only `browser/testing`.
- [x] 31/31 scoped manifests total 325 lines and 184 literal import rows, with
      ordered aggregate
      `aaed208c0cea2de008912f026e8f2f78dd3ac86685acb356d4ef9e57694db988`.
- [x] every current option/cursor/view-zone owner-to-public-consumer edge is
      recorded.
- [x] the browser contract/runtime split avoids the direct
      `browser <-> browser/view` cycle by using a browser-owned callback
      accessor handle.
- [x] the browser-owned opaque unmanaged overlay-widget handle, root inference
      factory, null/self-positioned subset, and upstream-deferred larger widget
      contracts are closed without adding a graph edge.
- [x] exact production operations are separated from WB/BR concrete host-only
      operations; named lower/final marker handles and their single closed
      source union are explicit; the decorations constructor consumes the
      lower handle, while transitional diagnostics reads are excluded from the
      final Viewer marker handle.
- [x] reviewed route (c) moves feedback DTOs/handle and the quick-diff handle
      to dedicated common APIs, with no root generated `viewer/contrib/**`
      path and no duplicate DTOs; exact public all-callback constructors make
      both opaque handles externally implementable.
- [x] opaque `ViewerServices` has an idempotent default-only disposal contract,
      explicit shared-bundle ownership, and fixed teardown order.
- [x] the target graph, topological ranks, and absence set include
      `viewer/browser/testing`; common contracts remain multi-target and every
      browser package remains JS-only.
- [x] external embed, internal workbench, and browser-scenario dependency paths
      are explicit, including caller-owned BR backing disposal, and preserve
      the external-import guard.
- [ ] public/generated-interface implementation — **STOP FOR REVIEW**.

Review gate: do not create any of the four absent packages, move a type, edit a
manifest/generated interface, or change the embed, workbench, or browser
scenario callers until this dependency companion and the complete Public API
Gate A artifact set are explicitly approved together.
