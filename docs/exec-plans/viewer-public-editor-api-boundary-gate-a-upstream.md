# Viewer Public Editor API Boundary Gate A — Upstream Ledger

Status: approved historical inventory — implementation started 2026-07-14
Date: 2026-07-14
Oracle commit: `b18492a288de038fbc7643aae6de8247029d11bd`
Parent plan: `docs/exec-plans/viewer-public-editor-api-boundary.md`

This is the upstream half of Gate A only. It changes no product code, moves no
public type, and does not authorize implementation.

## Scope closure

The oracle contains several very large editor files. This companion closes
complete declarations or exact, complete public-boundary method clusters; it
does not claim those files as full ports.

- **U01 — option declarations and registrations:** the named `IEditorOptions`
  fields at lines 147-159, 176-202, 329-365, 676-709, and 729-798 of
  `editorOptions.ts`; their complete validators/computers at 2085-2156,
  3302-3352, 3723-3740, 3931-3944, and 5527-5591; and their complete
  registrations at 6303-6343, 6370-6382, 6510, 6526-6581, 6632-6652,
  6669-6672, 6767-6796, and 6857. `tabSize` and `theme` are not members of
  this source cluster: the generated standalone declaration owns them as
  global/construction options. Every other editor option, all diff options,
  computed layout/minimap/accessibility options, suggestions, commands, and
  editing policy are excluded siblings.
- **U02 — common public denominator:** complete `IModelChangedEvent`,
  `IScrollEvent`, `IContentSizeChangedEvent`, `INewScrollPosition`,
  `ICursorState`, `IViewState`, `ICodeEditorViewState`, `ScrollType`, and
  `IEditor` at lines 117-499 of `editorCommon.ts`; complete public
  `IEditorDecorationsCollection` at 544-578 because the accepted root facade
  returns that contract; plus complete `IEditorContribution` at 583-596 because
  view state names its state map. `IEditorAction`, trigger-operation payloads,
  diff/composite editors, diff contributions, commands, and decoration render
  options are named excluded siblings.
- **U03 — complete source unit:** all 95 lines of `cursorEvents.ts`, excluding
  only imports/comments from atom counting. This closes all reason constants
  and both public event payloads.
- **U04 — browser contracts:** complete `IViewZone` and
  `IViewZoneChangeAccessor` at lines 36-121; complete content-widget descriptor
  contracts at 123-233; complete overlay-widget descriptor contracts at
  235-316; complete `IEditorMouseEvent` and `IPartialEditorMouseEvent` at
  536-543; and complete `ICodeEditor` at 606-1280 of `editorBrowser.ts`. All
  members receive rows; edit/action/undo, accessibility, telemetry,
  decoration-type, glyph-margin, internal view-model, and render-control
  siblings end `N-A` or `DEFERRED`. `IActiveCodeEditor`, diff editors, the
  already-ported `IMouseTarget` discriminated-union implementation family,
  overview rulers, and widget implementation classes are excluded siblings.
- **U05 — widget behavior:** the exact owners/aliases for disposal,
  configuration, model, cursor, layout, content-size, scroll, and view-zone
  events at lines 69-127 and 197-218; the construction fields they depend on
  at 225-269; the complete constructor at 271-408; complete
  dispose/options/service/model/value methods at 410-548;
  the complete visible geometry, selection, scroll, view-state, and
  contribution lookup cluster at 563-1088; complete layout/focus, content and
  overlay widget, view-zone, geometry, DOM, and render methods at 1472-1735;
  complete model attach/event projection and detach clusters at 1750-1921 and
  2008-2032; and `hasModel` at 2050-2052 of `codeEditorWidget.ts`. Occurrences
  of action, DnD, glyph-widget, accessibility, and context-service behavior
  inside those closed ranges receive explicit `N-A` rows. Their remaining
  implementation clusters, editing/decoration/command methods, `_createView`
  input-command wiring, banner/telemetry/context methods, and helper classes
  after `CodeEditorWidget` are excluded siblings.
- **U06 — complete standalone facade unit:** all 73 lines of `editor.api.ts`.
  Every default mutation, export, global-publication branch, and AMD contract
  is accounted.
- **U07 — complete entrypoint unit:** all 16 lines of `editor.main.ts`. Every
  side-effect import and the re-export is accounted.
- **U08 — generated public declaration clusters:** `IScrollEvent` at 523-532;
  `editor.create` at 945-952; complete `IGlobalEditorOptions`,
  `IStandaloneEditorConstructionOptions`, `IStandaloneCodeEditor`, and
  `IEditorOverrideServices` at 1286-1455; model/view/scroll/cursor types at
  2584-2668 and 3084-3169; complete public `IEditor` at 2673-2882, complete
  `IEditorDecorationsCollection` at 2887-2921, and complete
  `IEditorContribution` at 2926-2939; the scoped `IEditorOptions` members at
  3209-4128; `IEditorConstructionOptions`, `IViewZone`, and
  `IViewZoneChangeAccessor` at 5452-5554; complete content/overlay widget
  contracts at 5559-5742; complete `IEditorMouseEvent` and
  `IPartialEditorMouseEvent` at 5964-5972; and complete public `ICodeEditor` at
  6002-6447 of `monaco.d.ts`. Generated diff editor, languages, workers,
  commands/actions, editing methods, accessibility, decoration implementation,
  and unrelated option siblings are explicitly excluded below.

The scope deliberately distinguishes three similarly named service seams:

1. `CodeEditorWidget` receives VS Code platform services and exposes internal
   `invokeWithinContext`; that is not a Monaco public service contract.
2. `monaco.editor.create(..., override)` accepts the intentionally opaque
   string-keyed `IEditorOverrideServices` bag.
3. local `ViewerServices` is a typed host-capability boundary. It is a
   seam-based adaptation, not a port of the VS Code DI container or the opaque
   Monaco bag.

## Manifest and counting rule

The manifest is ordered as shown. Its canonical SHA-256 over tab-separated
`source path`, `wc -l`, and file SHA-256 rows is
`3c7c8cb5295abf8a9bf324f1a31aaac491800f8be80068d9bde371a1ded1c958`.
The eight physical files contain **20,722 lines**; only the closed clusters
above contribute ledger atoms.

| Unit | Pinned source | wc -l | SHA-256 |
|---|---|---:|---|
| U01 | `src/vs/editor/common/config/editorOptions.ts` | 6869 | `8f24aa725cbab484d78588985d7ed657efc8449d784063b2bbaa85cd8482d8f0` |
| U02 | `src/vs/editor/common/editorCommon.ts` | 783 | `86e64d099b9add7e762ad30623a21d859498b23cce4cd03ce20451e76de342ee` |
| U03 | `src/vs/editor/common/cursorEvents.ts` | 95 | `5a1375f826f617ad090628cf23eda9ce38bd4d20812b280a74161be8f493d081` |
| U04 | `src/vs/editor/browser/editorBrowser.ts` | 1538 | `27375b22639d3db492cf0dacc3e34a061601171de9692d64e554d3fbfd902429` |
| U05 | `src/vs/editor/browser/widget/codeEditor/codeEditorWidget.ts` | 2559 | `18dd294ed185a29c590df75656f18f27d0cefc8d4d778559db946d447130e5d8` |
| U06 | `src/vs/editor/editor.api.ts` | 73 | `043169bfa209fa3d5d91b8f043f2862870c9d6371560de8435e5d1cafe3133aa` |
| U07 | `src/vs/editor/editor.main.ts` | 16 | `274ffa5ec19de94c4f8bec65777b4f673005ef45a42ab79dfc849fb46fe7d528` |
| U08 | `src/vs/monaco.d.ts` | 8789 | `b654559a0e8f596b6047059bcaff8ed61b6a3c83f016f61a4877d0534627ea33` |

One row is one scoped member, overload, semantic constant, behavior-changing
branch, early exit, or independently observable DOM contract. A declaration
row does not subsume its fields; a method row does not subsume its branches.
Ordinary locals, loops, casts, final unconditional returns, and generated doc
comments are not separate atoms. Every row ends in exactly `PORTED`, `TESTED`,
`PASS`, `DEFERRED (reason)`, or `N-A (reason)`.

`TESTED` means the currently mapped behavior has a named local test; it does
not approve the current public owner. No row uses `PASS`: Gate A is an ownership
review and implementation has not started.

## Exact audit totals

The final ledger has **1,322 rows**: **101 `PORTED`**, **507 `TESTED`**,
**340 `DEFERRED (reason)`**, and **374 `N-A (reason)`**. No row is left at
`PASS` or an unterminated status.

By atom kind, the ledger contains **898 members**, **125 constants**, **127
branches**, **68 early exits**, **90 lifetime/order atoms**, and **14 DOM
contracts**. By source unit it contains U01 **107**, U02 **109**, U03 **21**,
U04 **200**, U05 **473**, U06 **42**, U07 **10**, and U08 **360** rows. The
kind, status, and unit partitions independently sum to 1,322.

## Parity ledger

### U01 — scoped editor option declarations, validators, and registrations

| Row | Source atom | Kind | Public-boundary relevance | Local mapping / evidence | Status |
|---|---|---|---|---|---|
| U01-001 | `IEditorOptions` scoped declaration (`:53-862`) | MEMBER | Structural owner of live editor options. | `ViewerOptions` currently exposes a mixed-owner snapshot. | DEFERRED (make the root snapshot opaque and move shared enums to `common/editor_api`) |
| U01-002 | `lineNumbersMinChars?` (`:147`) | MEMBER | Minimum reserved line-number digits. | `ViewerOptions.line_numbers_min_chars`; layout width tests. | TESTED |
| U01-003 | `lineDecorationsWidth?` (`:159`) | MEMBER | Reserved decoration band width, number or `ch`. | Local public field is `Int`, so only pixel input exists. | DEFERRED (the accepted public subset must state that `ch` strings are unsupported) |
| U01-004 | `readOnly?` (`:179`) | MEMBER | Monaco can toggle editability. | Viewer is readonly for interactive editing/undo/actions; retained `set_value` is host-driven whole-buffer replacement, not an editability toggle. | N-A (the target contract is readonly by construction) |
| U01-005 | `renderValidationDecorations?` (`:202`) | MEMBER | `editable`/`on`/`off` policy. | `@view_model.RenderValidationDecorations` leaks through root. | DEFERRED (move the canonical enum to `common/editor_api`) |
| U01-006 | `smoothScrolling?` (`:329`) | MEMBER | Enables animated scroll transitions. | `ViewerOptions.smooth_scrolling`. | TESTED |
| U01-007 | `wordWrap?` (`:343`) | MEMBER | Four-mode wrapping policy. | Local `soft_wrap : Bool` collapses the source modes. | DEFERRED (document the intentional boolean reduction or expose a canonical four-mode enum) |
| U01-008 | `wrappingIndent?` (`:365`) | MEMBER | Four-mode wrapped-line indentation. | `@view_model.WrappingIndent` is publicly leaked. | DEFERRED (move one canonical enum to `common/editor_api`) |
| U01-009 | `folding?` (`:679`) | MEMBER | Enables folding. | `ViewerOptions.folding`. | TESTED |
| U01-010 | `foldingHighlight?` (`:689`) | MEMBER | Folded-range highlight. | `ViewerOptions.folding_highlight`. | TESTED |
| U01-011 | `foldingMaximumRegions?` (`:699`) | MEMBER | Bounds folding regions. | `ViewerOptions.folding_maximum_regions`. | TESTED |
| U01-012 | `showFoldingControls?` (`:704`) | MEMBER | Three-mode gutter-control visibility. | Folding implementation enum leaks through root. | DEFERRED (move the canonical enum to `common/editor_api`) |
| U01-013 | `unfoldOnClickAfterEndOfLine?` (`:709`) | MEMBER | Click-after-line unfolding policy. | `ViewerOptions.unfold_on_click_after_end_of_line`. | TESTED |
| U01-014 | `renderWhitespace?` (`:729`) | MEMBER | Five-mode whitespace rendering. | `@view_layout.RenderWhitespace` leaks through root. | DEFERRED (move the canonical enum to `common/editor_api`) |
| U01-015 | `renderControlCharacters?` (`:734`) | MEMBER | Control-character rendering toggle. | `ViewerOptions.render_control_characters`. | TESTED |
| U01-016 | `renderLineHighlight?` (`:739`) | MEMBER | Four-mode current-line highlight. | `@view_layout.RenderLineHighlight` leaks through root. | DEFERRED (move the canonical enum to `common/editor_api`) |
| U01-017 | `renderLineHighlightOnlyWhenFocus?` (`:744`) | MEMBER | Focus-gated current-line highlight. | `ViewerOptions.render_line_highlight_only_when_focus`. | TESTED |
| U01-018 | `fontFamily?` (`:757`) | MEMBER | Editor font family. | `ViewerOptions.font_family`. | TESTED |
| U01-019 | `fontWeight?` (`:761`) | MEMBER | Keyword or numeric font weight. | `ViewerOptions.font_weight : String`. | PORTED |
| U01-020 | `fontSize?` (`:765`) | MEMBER | Pixel font size. | `ViewerOptions.font_size`. | TESTED |
| U01-021 | `lineHeight?` (`:769`) | MEMBER | Absolute/multiplier/auto line height. | `ViewerOptions.line_height`. | TESTED |
| U01-022 | `letterSpacing?` (`:773`) | MEMBER | Pixel letter spacing. | `ViewerOptions.letter_spacing`. | TESTED |
| U01-023 | `showUnused?` (`:777`) | MEMBER | Fade unnecessary code. | `ViewerOptions.show_unused`. | TESTED |
| U01-024 | `placeholder?` (`:788`) | MEMBER | Empty-editor placeholder. | `ViewerOptions.placeholder`. | TESTED |
| U01-025 | `showDeprecated?` (`:798`) | MEMBER | Strike deprecated code. | `ViewerOptions.show_deprecated`. | TESTED |
| U01-026 | `readOnly` registration default `false` (`:6526-6528`) | CONST | Standalone editor is editable unless requested. | No public toggle. | N-A (readonly facade deliberately removes editability configuration) |
| U01-027 | `lineNumbersMinChars` default `5` (`:6379-6382`) | CONST | Default digit reservation. | Local default matches. | TESTED |
| U01-028 | `lineNumbersMinChars` minimum `1` (`:6381`) | CONST | Validator lower bound. | Local option normalization. | TESTED |
| U01-029 | `lineNumbersMinChars` maximum `300` (`:6381`) | CONST | Validator upper bound. | Local constructor enforces only the minimum and accepts values above `300`. | DEFERRED (add the source upper-bound normalization or document the accepted wider range) |
| U01-030 | `EditorLineDecorationsWidth` default `10` (`:3304-3308`) | CONST | Pixel default. | Local default matches. | TESTED |
| U01-031 | valid `/ch$/` string branch (`:3310-3314`) | BRANCH | Stores a negative multiplier sentinel. | No string input. | N-A (local public input is integer pixels only) |
| U01-032 | numeric/clamped branch `0..1000` (`:3314-3316`) | BRANCH | Validates pixel input. | Local constructor clamps only at zero and accepts values above `1000`. | DEFERRED (add the source upper bound or document the wider integer range) |
| U01-033 | negative-multiplier compute branch (`:3319-3323`) | BRANCH | Resolves `ch` against measured half-width. | No string input. | N-A (local public input cannot create the sentinel) |
| U01-034 | nonnegative compute branch (`:3323-3325`) | BRANCH | Preserves validated pixels. | Direct local pixel width. | PORTED |
| U01-035 | `renderValidationDecorations` default `editable` (`:6562-6565`) | CONST | Default hides validation only for editable policy in readonly mode. | Local enum default maps this mode. | TESTED |
| U01-036 | validation variants `editable/on/off` (`:6564-6565`) | CONST | Closed public value set. | Local enum has the corresponding variants. | TESTED |
| U01-037 | filter `editable` branch (`:3937-3939`) | BRANCH | Defers filtering decision to readonly option. | Local marker filtering uses viewer option. | TESTED |
| U01-038 | `editable` returns `readOnly` (`:3939`) | BRANCH | Validation decorations remain in readonly editors. | Viewer is readonly-facing. | TESTED |
| U01-039 | `on` returns `false` filter (`:3941`) | BRANCH | Always retain validation decorations. | Local marker option behavior. | TESTED |
| U01-040 | `off` returns `true` filter (`:3941`) | BRANCH | Always filter validation decorations. | Local marker option behavior. | TESTED |
| U01-041 | `smoothScrolling` default `false` (`:6669-6672`) | CONST | Immediate scrolling by default. | Local default matches. | TESTED |
| U01-042 | `wordWrap` default `off` (`:6767-6770`) | CONST | No wrapping by default. | `soft_wrap=false`. | TESTED |
| U01-043 | word-wrap value set `off/on/wordWrapColumn/bounded` (`:6769-6770`) | CONST | Four source configurations. | Boolean local surface represents only off/on-width behavior. | DEFERRED (record the reduction in the reviewed public disposition) |
| U01-044 | `WrappingIndent` enum owner (`:5532-5549`) | MEMBER | Canonical computed enum. | Currently owned by view-model package. | DEFERRED (move to dependency-bottom `common/editor_api`) |
| U01-045 | `WrappingIndent.None = 0` (`:5536`) | CONST | No continuation indentation. | Local `None`. | TESTED |
| U01-046 | `WrappingIndent.Same = 1` (`:5540`) | CONST | Preserve parent indentation. | Local `Same`. | TESTED |
| U01-047 | `WrappingIndent.Indent = 2` (`:5544`) | CONST | Add one indent. | Local `Indent`. | TESTED |
| U01-048 | `WrappingIndent.DeepIndent = 3` (`:5548`) | CONST | Add two indents. | Local `DeepIndent`. | TESTED |
| U01-049 | VS Code option default `Same` (`:5554`) | CONST | Workbench default before standalone override. | Local default is currently source-shaped. | TESTED |
| U01-050 | validation `none` branch (`:5573-5575`) | BRANCH | Maps string to `None`. | Direct enum constructor. | TESTED |
| U01-051 | validation `same` branch (`:5575`) | BRANCH | Maps string to `Same`. | Direct enum constructor. | TESTED |
| U01-052 | validation `indent` branch (`:5576`) | BRANCH | Maps string to `Indent`. | Direct enum constructor. | TESTED |
| U01-053 | validation `deepIndent` branch (`:5577`) | BRANCH | Maps string to `DeepIndent`. | Direct enum constructor. | TESTED |
| U01-054 | validation fallback `Same` (`:5579`) | BRANCH | Invalid input uses workbench default. | Typed MoonBit enum makes invalid strings impossible. | N-A (closed typed input removes validation fallback) |
| U01-055 | accessibility-enabled compute branch (`:5583-5588`) | BRANCH | Forces `None` for screen-reader wrapping parity. | No public accessibility service/option. | DEFERRED (accessibility option is outside current product denominator) |
| U01-056 | normal compute returns requested value (`:5589`) | BRANCH | Preserves validated indentation. | Direct local enum. | PORTED |
| U01-057 | `folding` default `true` (`:6303-6306`) | CONST | Folding is enabled by default. | Local default matches. | TESTED |
| U01-058 | `foldingHighlight` default `true` (`:6319-6322`) | CONST | Folded ranges highlight by default. | Local default matches. | TESTED |
| U01-059 | `foldingMaximumRegions` default `5000` (`:6327-6330`) | CONST | Default region cap. | Local default matches. | TESTED |
| U01-060 | folding-region minimum `10` (`:6329`) | CONST | Validator lower bound. | Local constructor passes the requested limit through unchanged. | DEFERRED (source range normalization is absent) |
| U01-061 | folding-region maximum `65000` (`:6329`) | CONST | Must remain below source folding-range hard cap. | Local constructor passes the requested limit through unchanged. | DEFERRED (source range normalization is absent) |
| U01-062 | `showFoldingControls` default `mouseover` (`:6632-6635`) | CONST | Default visibility policy. | Local enum/default. | TESTED |
| U01-063 | folding-control value set `always/never/mouseover` (`:6634-6635`) | CONST | Closed public variants. | Local enum has all variants. | TESTED |
| U01-064 | `unfoldOnClickAfterEndOfLine` default `false` (`:6332-6334`) | CONST | Empty-tail clicks do not unfold by default. | Local default matches. | TESTED |
| U01-065 | `renderWhitespace` default `selection` (`:6567-6570`) | CONST | Selection-only default. | Local default and renderer matrix. | TESTED |
| U01-066 | whitespace value set `none/boundary/selection/trailing/all` (`:6569-6570`) | CONST | Closed public variants. | Local enum has all variants. | TESTED |
| U01-067 | `renderControlCharacters` default `true` (`:6534-6536`) | CONST | Control characters render by default. | Local default matches. | TESTED |
| U01-068 | `renderLineHighlight` default `line` (`:6544-6547`) | CONST | Content-line highlight default. | Local default mapping. | TESTED |
| U01-069 | line-highlight value set `none/gutter/line/all` (`:6546-6547`) | CONST | Closed public variants. | Local enum has all variants. | TESTED |
| U01-070 | line-highlight-focus default `false` (`:6558-6560`) | CONST | Highlight is not focus-gated by default. | Local default matches. | TESTED |
| U01-071 | `fontFamily` uses `EDITOR_FONT_DEFAULTS.fontFamily` (`:6336-6339`) | CONST | Environment-specific canonical default. | Local config derives its font default. | PORTED |
| U01-072 | font-weight minimum `1` (`:2122`) | CONST | Numeric lower bound. | Local accepts a string without equivalent validation. | DEFERRED (opaque constructor must document or implement normalization) |
| U01-073 | font-weight maximum `1000` (`:2123`) | CONST | Numeric upper bound. | Local accepts a string without equivalent validation. | DEFERRED (opaque constructor must document or implement normalization) |
| U01-074 | `normal`/`bold` validation branch (`:2150-2153`) | BRANCH | Preserves keyword values. | Local string passes through. | PORTED |
| U01-075 | numeric clamping/stringification branch (`:2154`) | BRANCH | Normalizes all other input. | Local string passes through. | DEFERRED (normalization is absent) |
| U01-076 | font-size source default (`:2091`) | CONST | Uses environment/editor font default. | Local default maps measured font info. | PORTED |
| U01-077 | font-size minimum `6` (`:2094`) | CONST | Validator lower bound. | Local `ViewerOptions` and `BareFontInfo` retain the supplied font size without this clamp. | DEFERRED (source normalization is absent) |
| U01-078 | font-size maximum `100` (`:2095`) | CONST | Validator upper bound. | Local `ViewerOptions` and `BareFontInfo` retain the supplied font size without this clamp. | DEFERRED (source normalization is absent) |
| U01-079 | font-size zero resets default (`:2102-2106`) | BRANCH | `0` is not retained. | Local `ViewerOptions` and `BareFontInfo` retain a zero font size. | DEFERRED (source zero-sentinel normalization is absent) |
| U01-080 | font-size clamp branch (`:2107`) | BRANCH | Nonzero input clamps to `6..100`. | Local `ViewerOptions` and `BareFontInfo` do not clamp the supplied font size. | DEFERRED (source range normalization is absent) |
| U01-081 | font-size compute uses measured/zoomed `env.fontInfo` (`:2109-2113`) | BRANCH | Final public computed value is environmental. | Viewer derives measured `FontInfo`. | TESTED |
| U01-082 | line-height default/auto sentinel `0` (`:3337-3343`) | CONST | Zero asks font info to compute height. | Local option supports auto/default derivation. | TESTED |
| U01-083 | line-height validation range `0..150` (`:3339-3342`) | CONST | Accepts multiplier and absolute bands. | Local line-height derivation implements zero/multiplier/absolute bands but does not clamp above `150`. | DEFERRED (source upper-bound normalization is absent) |
| U01-084 | line-height compute uses `env.fontInfo` (`:3346-3351`) | BRANCH | Applies auto/multiplier/zoom semantics before exposure. | Viewer derives measured `FontInfo`. | TESTED |
| U01-085 | letter-spacing source default (`:6370-6373`) | CONST | Uses editor font defaults. | Local default maps font config. | PORTED |
| U01-086 | letter-spacing minimum `-5` (`:6372`) | CONST | Validator lower bound. | Local `ViewerOptions` retains the supplied spacing without clamping. | DEFERRED (source range normalization is absent) |
| U01-087 | letter-spacing maximum `20` (`:6372`) | CONST | Validator upper bound. | Local `ViewerOptions` retains the supplied spacing without clamping. | DEFERRED (source range normalization is absent) |
| U01-088 | `showUnused` default `true` (`:6645-6647`) | CONST | Unnecessary-code fading enabled. | Local default matches. | TESTED |
| U01-089 | placeholder default `undefined` (`:3725-3728`) | CONST | No placeholder by default. | Local optional string default. | TESTED |
| U01-090 | placeholder `undefined` validation branch (`:3730-3733`) | BRANCH | Returns default. | Typed optional input. | PORTED |
| U01-091 | placeholder string validation branch (`:3734-3736`) | BRANCH | Preserves string. | Typed string input. | PORTED |
| U01-092 | placeholder invalid fallback (`:3737`) | BRANCH | Returns default. | Non-string input cannot type-check. | N-A (typed MoonBit input removes the dynamic fallback) |
| U01-093 | `showDeprecated` default `true` (`:6649-6651`) | CONST | Deprecated-code strike enabled. | Local default matches. | TESTED |
| U01-094 | `tabSize` absent from `IEditorOptions`/registry | MEMBER | It is a model/global construction option, not a live editor option. | Reviewed root `tab_size` remains local model/view-model configuration because `TextSnapshot` has no model options. | DEFERRED (retain the seam without claiming `IEditorOptions` ownership) |
| U01-095 | `theme` absent from `IEditorOptions`/registry | MEMBER | Standalone global/construction option. | Reviewed root theme remains standalone/global construction state behind opaque options. | DEFERRED (retain the seam without claiming `IEditorOptions` ownership) |
| U01-096 | all unlisted `IEditorOptions` fields (`:53-862`) | MEMBER | Editing, minimap, accessibility, suggestions, command, and unrelated rendering options. | Not in the accepted local denominator. | N-A (named sibling clusters are outside this readonly API plan) |
| U01-097 | font-weight suggestion values (`:2121`) | CONST | `normal`, `bold`, and decimal hundreds through `900` drive schema suggestions. | Local string input has no public schema. | N-A (editor-setting schema is outside the typed facade) |
| U01-098 | `filterValidationDecorations` (`:3936-3942`) | MEMBER | Computes whether validation decorations are filtered. | Local marker decoration policy. | TESTED |
| U01-099 | `EditorFontSize.validate` (`:2102-2108`) | MEMBER | Applies zero/default and clamp rules. | Local option normalization. | TESTED |
| U01-100 | `EditorFontSize.compute` (`:2109-2113`) | MEMBER | Returns measured/zoomed font size. | Local FontInfo derivation. | TESTED |
| U01-101 | `EditorFontWeight.validate` (`:2150-2155`) | MEMBER | Preserves keywords or clamps numeric input. | Local string currently passes through. | DEFERRED (normalization absent) |
| U01-102 | `EditorLineDecorationsWidth.validate` (`:3310-3317`) | MEMBER | Accepts `ch` strings or clamped pixels. | Local integer-only input. | DEFERRED (reviewed reduction) |
| U01-103 | `EditorLineDecorationsWidth.compute` (`:3319-3326`) | MEMBER | Resolves `ch` multiplier against font metrics. | Local pixels only. | N-A (`ch` form is not accepted) |
| U01-104 | `EditorLineHeight.compute` (`:3346-3351`) | MEMBER | Returns environmental final line height. | Local FontInfo derivation. | TESTED |
| U01-105 | `PlaceholderOption.validate` (`:3730-3738`) | MEMBER | Preserves strings and defaults other input. | Typed optional string. | PORTED |
| U01-106 | `WrappingIndentOption.validate` (`:5572-5580`) | MEMBER | Maps four strings and fallback. | Typed canonical enum target. | TESTED |
| U01-107 | `WrappingIndentOption.compute` (`:5582-5590`) | MEMBER | Applies accessibility override. | Accessibility override absent. | DEFERRED (accessibility option excluded for now) |

### U02 — common events, state, scroll, and base editor contract

| Row | Source atom | Kind | Public-boundary relevance | Local mapping / evidence | Status |
|---|---|---|---|---|---|
| U02-001 | `IModelChangedEvent` (`:117-126`) | MEMBER | Semantic model-swap event. | Root `ModelChangedEvent`. | DEFERRED (move the DOM-free payload to the canonical public contract owner) |
| U02-002 | `oldModelUrl` (`:121`) | MEMBER | Nullable outgoing resource. | `old_model_uri`. | TESTED |
| U02-003 | `newModelUrl` (`:125`) | MEMBER | Nullable incoming resource. | `new_model_uri`. | TESTED |
| U02-004 | `IScrollEvent` (`:130-140`) | MEMBER | Complete scroll fact. | Root `ScrollEvent`. | DEFERRED (canonical DOM-free event owner is not yet `common/editor_api`) |
| U02-005 | `scrollTop` (`:131`) | MEMBER | Current vertical offset. | `scroll_top`. | TESTED |
| U02-006 | `scrollLeft` (`:132`) | MEMBER | Current horizontal offset. | `scroll_left`. | TESTED |
| U02-007 | `scrollWidth` (`:133`) | MEMBER | Current scrollable width. | `scroll_width`. | TESTED |
| U02-008 | `scrollHeight` (`:134`) | MEMBER | Current scrollable height. | `scroll_height`. | TESTED |
| U02-009 | `scrollTopChanged` (`:136`) | MEMBER | Independent vertical-value flag. | `scroll_top_changed`. | TESTED |
| U02-010 | `scrollLeftChanged` (`:137`) | MEMBER | Independent horizontal-value flag. | `scroll_left_changed`. | TESTED |
| U02-011 | `scrollWidthChanged` (`:138`) | MEMBER | Independent width flag. | `scroll_width_changed`. | TESTED |
| U02-012 | `scrollHeightChanged` (`:139`) | MEMBER | Independent height flag. | `scroll_height_changed`. | TESTED |
| U02-013 | `IContentSizeChangedEvent` (`:142-148`) | MEMBER | Content extent fact. | Internal layout events exist; root does not expose this event. | DEFERRED (the disposition review must decide whether this semantic event is public) |
| U02-014 | `contentWidth` (`:143`) | MEMBER | Current content width. | View-layout extent. | PORTED |
| U02-015 | `contentHeight` (`:144`) | MEMBER | Current content height. | View-layout extent. | PORTED |
| U02-016 | `contentWidthChanged` (`:146`) | MEMBER | Independent width flag. | Internal event source. | TESTED |
| U02-017 | `contentHeightChanged` (`:147`) | MEMBER | Independent height flag. | Internal event source. | TESTED |
| U02-018 | `INewScrollPosition` (`:159-162`) | MEMBER | Partial scroll update. | `set_scroll_position(scroll_top?, scroll_left?)`. | DEFERRED (move the record or preserve the two optional arguments deliberately) |
| U02-019 | `scrollLeft?` (`:160`) | MEMBER | Optional horizontal update. | Optional `scroll_left`. | TESTED |
| U02-020 | `scrollTop?` (`:161`) | MEMBER | Optional vertical update. | Optional `scroll_top`. | TESTED |
| U02-021 | `ICursorState` (`:178-182`) | MEMBER | Serializable cursor state. | `ViewerViewState.selection` stores the source-shaped selection instead. | DEFERRED (local state is a deliberate reduced shape) |
| U02-022 | `inSelectionMode` (`:179`) | MEMBER | Anchor/selection-mode bit. | Direction is encoded by `Selection`; no separate bit. | N-A (closed selection shape erases this internal cursor representation) |
| U02-023 | `selectionStart` (`:180`) | MEMBER | Cursor anchor. | `Selection.selection_start`. | TESTED |
| U02-024 | `position` (`:181`) | MEMBER | Cursor active end. | `Selection.position`. | TESTED |
| U02-025 | `IViewState` (`:186-194`) | MEMBER | Serializable viewport state. | Reduced root `ViewerViewState`. | DEFERRED (public state shape and owner require disposition review) |
| U02-026 | legacy `scrollTop?` (`:188`) | MEMBER | Backward-compatible old state. | Root state has required `scroll_top`. | N-A (no compatibility requirement for the new breaking API) |
| U02-027 | legacy `scrollTopWithoutViewZones?` (`:190`) | MEMBER | Backward-compatible pre-zone offset. | No public legacy state. | N-A (no compatibility requirement for the new breaking API) |
| U02-028 | `scrollLeft` (`:191`) | MEMBER | Horizontal state. | `ViewerViewState.scroll_left`. | TESTED |
| U02-029 | `firstPosition` (`:192`) | MEMBER | Viewport anchor position. | Local save stores absolute scroll top instead. | DEFERRED (reduced state does not serialize the source anchor) |
| U02-030 | `firstPositionDeltaTop` (`:193`) | MEMBER | Intra-line anchor delta. | Local save stores absolute scroll top. | DEFERRED (reduced state does not serialize the source anchor delta) |
| U02-031 | `ICodeEditorViewState` (`:198-202`) | MEMBER | Code-editor state envelope. | Root `ViewerViewState`. | DEFERRED (opaque root state should expose only the accepted reduced contract) |
| U02-032 | `cursorState` (`:199`) | MEMBER | All cursor states. | Local state stores one selection. | DEFERRED (multi-cursor serialization is reduced) |
| U02-033 | `viewState` (`:200`) | MEMBER | Viewport state. | Local scroll fields. | DEFERRED (shape differs at the facade seam) |
| U02-034 | `contributionsState` keyed by id (`:201`) | MEMBER | Contribution-owned serializable slots. | No public contribution view-state map. | DEFERRED (keep contribution implementation/state out of the root API) |
| U02-035 | `ScrollType` (`:216-219`) | MEMBER | Scroll animation mode. | The reviewed facade exposes no public scroll enum: every public reveal and setter is fixed `Immediate`. | N-A (smooth mode remains internal to physical input/cursor scrolling) |
| U02-036 | `Smooth = 0` (`:217`) | CONST | Animated transition. | Local smooth machinery is internal to physical input/cursor scrolling; `viewer/cursor_input_wbtest.mbt` covers the at-most-one-line downgrade. | TESTED |
| U02-037 | `Immediate = 1` (`:218`) | CONST | Immediate transition. | Every reviewed public reveal and scroll setter uses immediate behavior; `viewer/reveal_wbtest.mbt` checks the immediate request. | TESTED |
| U02-038 | `IEditor` (`:224-499`) | MEMBER | Base editor facade. | Root `Viewer` is the reduced concrete facade. | DEFERRED (the reviewed denominator is intentionally smaller) |
| U02-039 | `onDidDispose` (`:229`) | MEMBER | Disposal event. | `Viewer::on_did_dispose`. | TESTED |
| U02-040 | `dispose` (`:234`) | MEMBER | Editor lifetime termination. | `Viewer::dispose`. | TESTED |
| U02-041 | `getId` (`:239`) | MEMBER | Unique instance id. | `Viewer::get_id`; the current public caller sweep finds no direct caller. | PORTED |
| U02-042 | `getEditorType` (`:245`) | MEMBER | Type discriminator without `instanceof`. | `Viewer::get_editor_type`. | PORTED |
| U02-043 | `updateOptions` (`:250`) | MEMBER | Live option snapshot update. | `Viewer::update_options`. | TESTED |
| U02-044 | internal `onVisible` (`:256`) | MEMBER | Host visibility lifecycle. | No public root method. | N-A (host shell owns visibility internally) |
| U02-045 | internal `onHide` (`:262`) | MEMBER | Host hidden lifecycle. | No public root method. | N-A (host shell owns visibility internally) |
| U02-046 | `layout` (`:273`) | MEMBER | Remeasure and optionally postpone render. | Root `layout()` has no dimension/postpone parameters. | DEFERRED (retain the reduced method only if external callers need no explicit dimension) |
| U02-047 | `focus` (`:278`) | MEMBER | Focus editor text. | `Viewer::focus`. | TESTED |
| U02-048 | `hasTextFocus` (`:283`) | MEMBER | Text-focus query. | `Viewer::has_text_focus`. | TESTED |
| U02-049 | `getSupportedActions` (`:288`) | MEMBER | Editor action enumeration. | Not public locally. | N-A (actions/commands are outside the readonly denominator) |
| U02-050 | `saveViewState` (`:293`) | MEMBER | Serialize editor state. | `Viewer::save_view_state`. | TESTED |
| U02-051 | `restoreViewState` (`:298`) | MEMBER | Restore editor state. | `Viewer::restore_view_state`; stabilization test. | TESTED |
| U02-052 | `getVisibleColumnFromPosition` (`:303`) | MEMBER | Tab-aware visible column. | Same root method. | TESTED |
| U02-053 | internal `getStatusbarColumn` (`:309`) | MEMBER | Status-bar column convention. | The public disposition removes the root method; the package-private geometry helper remains. | N-A (upstream marks this method internal) |
| U02-054 | `getPosition` (`:314`) | MEMBER | Primary cursor position. | Same root method. | TESTED |
| U02-055 | `setPosition` (`:321`) | MEMBER | Collapse to one primary cursor. | Same root method. | TESTED |
| U02-056 | `revealLine` (`:326`) | MEMBER | Simple line reveal. | Same root method. | TESTED |
| U02-057 | `revealLineInCenter` (`:331`) | MEMBER | Center line reveal. | Same root method. | TESTED |
| U02-058 | `revealLineInCenterIfOutsideViewport` (`:336`) | MEMBER | Conditional center reveal. | Same root method; the current public caller sweep finds no direct caller. | PORTED |
| U02-059 | `revealLineNearTop` (`:342`) | MEMBER | Near-top line reveal. | Same root method; the current public caller sweep finds no direct caller. | PORTED |
| U02-060 | `revealPosition` (`:347`) | MEMBER | Simple position reveal. | Same root method. | TESTED |
| U02-061 | `revealPositionInCenter` (`:352`) | MEMBER | Center position reveal. | Same root method; the current public caller sweep finds no direct caller. | PORTED |
| U02-062 | `revealPositionInCenterIfOutsideViewport` (`:357`) | MEMBER | Conditional center position reveal. | Same root method. | TESTED |
| U02-063 | `revealPositionNearTop` (`:363`) | MEMBER | Near-top position reveal. | Same root method; the current public caller sweep finds no direct caller. | PORTED |
| U02-064 | `getSelection` (`:368`) | MEMBER | Primary selection. | Same root method. | TESTED |
| U02-065 | `getSelections` (`:373`) | MEMBER | All selections. | Same root method. | TESTED |
| U02-066 | `setSelection(IRange)` overload (`:380`) | MEMBER | Range becomes forward selection. | Root accepts only concrete `Selection`. | N-A (MoonBit has no structural overload set) |
| U02-067 | `setSelection(Range)` overload (`:386`) | MEMBER | Class range becomes forward selection. | Root accepts `Selection`. | N-A (MoonBit has no class/interface overload distinction) |
| U02-068 | `setSelection(ISelection)` overload (`:392`) | MEMBER | Structural selection. | Root accepts concrete selection value. | N-A (MoonBit has one canonical selection type) |
| U02-069 | `setSelection(Selection)` overload (`:398`) | MEMBER | Concrete selection preserving direction. | `Viewer::set_selection`. | TESTED |
| U02-070 | `setSelections` (`:406`) | MEMBER | Replace all cursors. | Root method also accepts reason. | TESTED |
| U02-071 | `revealLines` (`:411`) | MEMBER | Simple multi-line reveal. | Same root method; the current public caller sweep finds no direct caller. | PORTED |
| U02-072 | `revealLinesInCenter` (`:416`) | MEMBER | Center multi-line reveal. | Same root method; the current public caller sweep finds no direct caller. | PORTED |
| U02-073 | `revealLinesInCenterIfOutsideViewport` (`:421`) | MEMBER | Conditional center multi-line reveal. | Same root method; the current public caller sweep finds no direct caller. | PORTED |
| U02-074 | `revealLinesNearTop` (`:427`) | MEMBER | Near-top multi-line reveal. | Same root method; the current public caller sweep finds no direct caller. | PORTED |
| U02-075 | `revealRange` (`:432`) | MEMBER | Simple range reveal. | Same root method. | TESTED |
| U02-076 | `revealRangeInCenter` (`:437`) | MEMBER | Center range reveal. | Same root method; the current public caller sweep finds no direct caller. | PORTED |
| U02-077 | `revealRangeAtTop` (`:442`) | MEMBER | Top-aligned range reveal. | Same root method; the current public caller sweep finds no direct caller. | PORTED |
| U02-078 | `revealRangeInCenterIfOutsideViewport` (`:447`) | MEMBER | Conditional center range reveal. | Same root method. | TESTED |
| U02-079 | `revealRangeNearTop` (`:453`) | MEMBER | Near-top range reveal. | Same root method; the current public caller sweep finds no direct caller. | PORTED |
| U02-080 | `revealRangeNearTopIfOutsideViewport` (`:459`) | MEMBER | Conditional near-top range reveal. | Same root method; the current public caller sweep finds no direct caller. | PORTED |
| U02-081 | `trigger` (`:467`) | MEMBER | Command/action dispatch. | Not public locally. | N-A (commands/actions are outside the readonly denominator) |
| U02-082 | `getModel` (`:472`) | MEMBER | Nullable attached model, including diff union here. | Root returns `TextModel?`. | DEFERRED (retain code-editor narrowing; diff models remain excluded) |
| U02-083 | `setModel` (`:482`) | MEMBER | Attach/detach model. | Root accepts `TextModel?`. | TESTED |
| U02-084 | `createDecorationsCollection` (`:489`) | MEMBER | Editor-owned decoration collection. | Same root method. | DEFERRED (decorations are outside the named readonly clusters and need disposition review) |
| U02-085 | internal `changeDecorations` (`:498`) | MEMBER | Owner-scoped decoration callback. | Not public directly. | N-A (internal accessor is not an external facade contract) |
| U02-086 | complete `IEditorAction` sibling (`:164-171`) | MEMBER | Actions and command metadata. | Not public locally. | N-A (editing/action cluster excluded) |
| U02-087 | complete `ITriggerEditorOperationEvent` sibling (`:153-157`) | MEMBER | Internal operation notification. | Not public locally. | N-A (command dispatch cluster excluded) |
| U02-088 | complete public `IEditorDecorationsCollection` (`:544-578`) | MEMBER | Editor-owned public decoration collection returned by the in-scope editor facade. | Root has the accepted reduced collection, but omits source `onDidChange` and `has`. | DEFERRED (review the two missing members while retaining the current public collection) |
| U02-089 | `IEditorContribution` (`:583-596`) | MEMBER | View-state contributor lifecycle. | Root publicly leaks `EditorContribution`. | DEFERRED (make registry/concrete contribution contracts internal) |
| U02-090 | contribution `dispose` (`:587`) | MEMBER | Editor-lifetime release. | Central contribution enum dispatch. | TESTED |
| U02-091 | optional contribution `saveViewState` (`:591`) | MEMBER | Per-id state slot producer. | Not implemented in public contribution facade. | DEFERRED (do not expose contribution state; decide internal support separately) |
| U02-092 | optional contribution `restoreViewState` (`:595`) | MEMBER | Per-id state restore. | Not implemented in public contribution facade. | DEFERRED (do not expose contribution state; decide internal support separately) |
| U02-093 | complete `IDiffEditor` sibling (`:506-522`) | MEMBER | Diff editor contract. | No local diff viewer. | N-A (diff cluster excluded) |
| U02-094 | complete `ICompositeCodeEditor` sibling (`:527-539`) | MEMBER | Active-editor multiplexing. | No local composite editor facade. | N-A (composite cluster excluded) |
| U02-095 | complete `IDiffEditorContribution` sibling (`:602-607`) | MEMBER | Diff contribution lifecycle. | No local diff editor. | N-A (diff cluster excluded) |
| U02-096 | `IEditorModel` union (`:173`) | MEMBER | Text, diff model, or diff view model at base interface. | Viewer accepts only TextModel. | DEFERRED (intentional code-editor narrowing) |
| U02-097 | `IDiffEditorViewState` (`:206-210`) | MEMBER | Diff view-state envelope. | No local diff viewer. | N-A (diff cluster excluded) |
| U02-098 | diff state `original` (`:207`) | MEMBER | Original code-editor state. | No local diff viewer. | N-A (diff cluster excluded) |
| U02-099 | diff state `modified` (`:208`) | MEMBER | Modified code-editor state. | No local diff viewer. | N-A (diff cluster excluded) |
| U02-100 | diff `modelState?` (`:209`) | MEMBER | Optional diff-model state. | No local diff viewer. | N-A (diff cluster excluded) |
| U02-101 | `IEditorViewState` union (`:214`) | MEMBER | Code-or-diff state accepted by base editor. | Viewer exposes code-only reduced state. | DEFERRED (intentional narrowing/reduction) |
| U02-102 | decoration collection `onDidChange` (`:549`) | MEMBER | Fires for external decoration mutations not caused by the collection. | No root collection event. | DEFERRED (decide whether the accepted reduced collection needs this semantic event) |
| U02-103 | decoration collection `length` (`:553`) | MEMBER | Current owned decoration count. | `EditorDecorationsCollection::length`; exercised by `viewer/quick_diff_host_wbtest.mbt`. | TESTED |
| U02-104 | decoration collection `getRange` (`:557`) | MEMBER | Nullable range lookup by collection index. | `EditorDecorationsCollection::get_range`; no direct local caller. | PORTED |
| U02-105 | decoration collection `getRanges` (`:561`) | MEMBER | All currently resolved ranges. | `EditorDecorationsCollection::get_ranges`; no direct local caller. | PORTED |
| U02-106 | decoration collection `has` (`:565`) | MEMBER | Identity-membership query for a model decoration. | No root collection method. | DEFERRED (decide whether the reduced collection needs object-identity membership) |
| U02-107 | decoration collection `set` (`:569`) | MEMBER | Replace all owned decorations and return new ids. | `EditorDecorationsCollection::set`. | PORTED |
| U02-108 | decoration collection `append` (`:573`) | MEMBER | Append owned decorations and return appended ids. | `EditorDecorationsCollection::append`; no direct local caller. | PORTED |
| U02-109 | decoration collection `clear` (`:577`) | MEMBER | Remove all collection-owned decorations. | `EditorDecorationsCollection::clear`. | PORTED |

### U03 — complete cursor event source unit

| Row | Source atom | Kind | Public-boundary relevance | Local mapping / evidence | Status |
|---|---|---|---|---|---|
| U03-001 | `CursorChangeReason` (`:12-41`) | MEMBER | One canonical reason owner for cursor facts. | Duplicate root and `common/cursor` enums plus adapters. | DEFERRED (move one enum to `common/editor_api` and delete adapters) |
| U03-002 | `NotSet = 0` (`:16`) | CONST | Unknown/default reason. | Both local enums have `NotSet`. | TESTED |
| U03-003 | `ContentFlush = 1` (`:20`) | CONST | `model.setValue` reset. | Both local enums have `ContentFlush`. | TESTED |
| U03-004 | `RecoverFromMarkers = 2` (`:24`) | CONST | External-model-change marker recovery. | Both local enums have `RecoverFromMarkers`, but the current tests only name it in an exhaustive formatter and do not emit this reason. | PORTED |
| U03-005 | `Explicit = 3` (`:28`) | CONST | Explicit user/API gesture. | Both local enums have `Explicit`. | TESTED |
| U03-006 | `Paste = 4` (`:32`) | CONST | Paste transition. | Both local enums have `Paste`. | TESTED |
| U03-007 | `Undo = 5` (`:36`) | CONST | Undo transition. | Both local enums have `Undo`. | TESTED |
| U03-008 | `Redo = 6` (`:40`) | CONST | Redo transition. | Both local enums have `Redo`. | TESTED |
| U03-009 | `ICursorPositionChangedEvent` (`:45-62`) | MEMBER | Public position fact. | Root `CursorPositionChangedEvent`. | DEFERRED (move the payload to the same canonical owner as the reason) |
| U03-010 | primary `position` (`:49`) | MEMBER | Primary cursor. | `position`. | TESTED |
| U03-011 | `secondaryPositions` (`:53`) | MEMBER | Remaining cursor positions. | `secondary_positions`. | TESTED |
| U03-012 | position `reason` (`:57`) | MEMBER | Canonical enum value. | Root duplicate enum after adapter. | DEFERRED (remove the adapter and use the canonical type directly) |
| U03-013 | position `source` (`:61`) | MEMBER | Origin string. | `source`. | TESTED |
| U03-014 | `ICursorSelectionChangedEvent` (`:66-95`) | MEMBER | Public selection fact. | Root `CursorSelectionChangedEvent`. | DEFERRED (move the payload to the same canonical owner as the reason) |
| U03-015 | primary `selection` (`:70`) | MEMBER | Primary selection. | `selection`. | TESTED |
| U03-016 | `secondarySelections` (`:74`) | MEMBER | Remaining selections. | `secondary_selections`. | TESTED |
| U03-017 | `modelVersionId` (`:78`) | MEMBER | Version of new selections. | `model_version_id`. | TESTED |
| U03-018 | nullable `oldSelections` (`:82`) | MEMBER | Previous selections or null. | Root `old_selections : Array[Selection]?` preserves `None` versus `Some([])` and cursor-transition tests exercise the distinction. | TESTED |
| U03-019 | `oldModelVersionId` (`:86`) | MEMBER | Version associated with old selections. | `old_model_version_id`. | TESTED |
| U03-020 | selection `source` (`:90`) | MEMBER | Origin string. | `source`. | TESTED |
| U03-021 | selection `reason` (`:94`) | MEMBER | Canonical enum value. | Root duplicate enum after adapter. | DEFERRED (remove the adapter and use the canonical type directly) |

### U04 — browser editor and view-zone contracts

| Row | Source atom | Kind | Public-boundary relevance | Local mapping / evidence | Status |
|---|---|---|---|---|---|
| U04-001 | `IViewZone` (`:36-100`) | MEMBER | Public DOM-facing zone descriptor. | Root aliases private `@view.ViewZone`. | DEFERRED (define descriptor in `viewer/browser` and keep rendered state private) |
| U04-002 | `afterLineNumber` (`:41`) | MEMBER | Model line anchor; zero means before first line. | Local field. | TESTED |
| U04-003 | zero-anchor contract (`:38-40`) | CONST | `0` is a semantic before-first-line sentinel. | View-zone branch matrix. | TESTED |
| U04-004 | optional `afterColumn` (`:47`) | MEMBER | Wrapped-line anchor, default max column. | Local optional field. | TESTED |
| U04-005 | max-column fallback (`:43-45`) | BRANCH | Missing column anchors after the line. | Local normalization. | TESTED |
| U04-006 | optional `afterColumnAffinity` (`:51`) | MEMBER | Chooses a view column when projection is ambiguous. | Local optional affinity. | TESTED |
| U04-007 | affinity default `none` (`:49-51`) | CONST | Default projection side. | Local default. | TESTED |
| U04-008 | `showInHiddenAreas?` (`:55`) | MEMBER | Allows zones on hidden model lines. | Local field. | TESTED |
| U04-009 | `ordinal?` (`:60`) | MEMBER | Stable same-anchor tie-breaker. | Local field. | TESTED |
| U04-010 | ordinal fallback `afterColumn` else `10000` (`:57-60`) | BRANCH | Defines source ordering when omitted. | Local zone normalization. | TESTED |
| U04-011 | `suppressMouseDown?` (`:66`) | MEMBER | Installs DOM cancellation behavior. | Local field. | TESTED |
| U04-012 | suppress default `false` (`:62-66`) | CONST | Zones do not cancel by default. | Local default. | TESTED |
| U04-013 | suppress DOM listener calls `preventDefault` (`:62-64`) | DOM | Owned node receives a mousedown listener. | View-zones DOM branch tests. | TESTED |
| U04-014 | `heightInLines?` (`:72`) | MEMBER | Height in line units. | Local field. | TESTED |
| U04-015 | `heightInPx?` (`:78`) | MEMBER | Height in pixels. | Local field. | TESTED |
| U04-016 | pixel height wins; neither defaults to one line (`:68-78`) | BRANCH | Complete height precedence contract. | Local normalization and view-layout tests. | TESTED |
| U04-017 | `minWidthInPx?` (`:83`) | MEMBER | Zone can widen scroll extent. | Local field. | TESTED |
| U04-018 | min-width affects scroll-width DOM layout (`:80-83`) | DOM | Zone width participates in horizontal extent. | View-layout whitespace min-width tests. | TESTED |
| U04-019 | `domNode` (`:87`) | MEMBER | Required content DOM owner. | Local element field. | DEFERRED (move the public descriptor owner to `viewer/browser`) |
| U04-020 | `marginDomNode?` (`:91`) | MEMBER | Optional margin DOM owner. | Local optional element. | DEFERRED (move the public descriptor owner to `viewer/browser`) |
| U04-021 | `onDomNodeTop?` (`:95`) | MEMBER | Scroll-relative top callback. | Local callback. | TESTED |
| U04-022 | `onComputedHeight?` (`:99`) | MEMBER | Computed pixel-height callback. | Local callback. | TESTED |
| U04-023 | `IViewZoneChangeAccessor` (`:104-121`) | MEMBER | Transaction-scoped zone mutation facade. | Root exposes private view accessor type. | DEFERRED (define browser contract and keep implementation private) |
| U04-024 | `addZone` (`:110`) | MEMBER | Adds and returns unique id. | Local accessor. | TESTED |
| U04-025 | `removeZone` (`:115`) | MEMBER | Removes by id. | Local accessor. | TESTED |
| U04-026 | `layoutZone` (`:120`) | MEMBER | Rescans mutable line/column placement. | Local accessor. | TESTED |
| U04-027 | `ICodeEditor` (`:606-1280`) | MEMBER | Full browser code-editor contract. | Root `Viewer` is a reviewed subset. | DEFERRED (retain only accepted facade members) |
| U04-028 | internal `isSimpleWidget` (`:611`) | MEMBER | Distinguishes simple input widget. | No public root query. | N-A (internal construction detail) |
| U04-029 | internal `contextMenuId` (`:616`) | MEMBER | Context-menu service key. | No public root query. | N-A (commands/menu cluster excluded) |
| U04-030 | internal `contextKeyService` (`:621`) | MEMBER | Scoped context service. | No public root service locator. | N-A (full DI/context-key seam is forbidden by the target plan) |
| U04-031 | `onDidChangeModelContent` (`:626`) | MEMBER | Semantic model-content event. | Same root event. | TESTED |
| U04-032 | `onDidChangeModelLanguage` (`:631`) | MEMBER | Language-change event. | No root event. | DEFERRED (public semantic-event disposition required) |
| U04-033 | `onDidChangeModelLanguageConfiguration` (`:636`) | MEMBER | Language-config event. | No root event. | N-A (language configuration implementation event is outside denominator) |
| U04-034 | `onDidChangeModelOptions` (`:641`) | MEMBER | Model-option event. | No root event. | DEFERRED (tab-size host capability may justify a semantic event) |
| U04-035 | `onDidChangeConfiguration` (`:646`) | MEMBER | Live editor-option event. | Internal option invalidation only. | DEFERRED (decide whether opaque options require a public event) |
| U04-036 | `onDidChangeCursorPosition` (`:651`) | MEMBER | Public cursor-position event. | Same root event. | DEFERRED (canonical payload/reason owner is pending) |
| U04-037 | `onDidChangeCursorSelection` (`:656`) | MEMBER | Public cursor-selection event. | Same root event. | DEFERRED (canonical payload/reason owner is pending) |
| U04-038 | `onWillChangeModel` (`:661`) | MEMBER | Pre-detach semantic event. | Not public locally. | DEFERRED (current facade exposes only post-change) |
| U04-039 | `onDidChangeModel` (`:666`) | MEMBER | Post-attach semantic event. | Same root event. | TESTED |
| U04-040 | `onDidChangeModelDecorations` (`:671`) | MEMBER | Decoration-change event. | Internal only. | N-A (decoration implementation event excluded from readonly denominator) |
| U04-041 | internal `onDidChangeModelTokens` (`:676`) | MEMBER | Token-change event. | Internal renderer event. | N-A (token implementation event excluded) |
| U04-042 | `onDidFocusEditorText` (`:681`) | MEMBER | Text-focus event. | Root has query but no public event. | DEFERRED (semantic-event disposition required) |
| U04-043 | `onDidBlurEditorText` (`:686`) | MEMBER | Text-blur event. | Root has query but no public event. | DEFERRED (semantic-event disposition required) |
| U04-044 | `onDidFocusEditorWidget` (`:691`) | MEMBER | Whole-widget focus event. | No root event. | DEFERRED (semantic-event disposition required) |
| U04-045 | `onDidBlurEditorWidget` (`:696`) | MEMBER | Whole-widget blur event. | No root event. | DEFERRED (semantic-event disposition required) |
| U04-046 | internal `onWillType` (`:702`) | MEMBER | Pre-type event. | No root event. | N-A (editing cluster excluded) |
| U04-047 | internal `onDidType` (`:708`) | MEMBER | Post-type event. | No root event. | N-A (editing cluster excluded) |
| U04-048 | `inComposition` (`:712`) | MEMBER | IME composition state. | Internal input state only. | N-A (editing/input cluster excluded from facade) |
| U04-049 | `onDidCompositionStart` (`:716`) | MEMBER | IME start event. | Internal input event. | N-A (editing/input cluster excluded) |
| U04-050 | `onDidCompositionEnd` (`:720`) | MEMBER | IME end event. | Internal input event. | N-A (editing/input cluster excluded) |
| U04-051 | `onDidAttemptReadOnlyEdit` (`:725`) | MEMBER | Failed edit event. | No public root event. | N-A (readonly facade does not expose edit attempts) |
| U04-052 | `onDidPaste` (`:730`) | MEMBER | Paste event. | Internal input event. | N-A (editing/input cluster excluded) |
| U04-053 | internal `onWillCopy` (`:736`) | MEMBER | Clipboard pre-copy event. | Internal clipboard handler. | N-A (clipboard cluster excluded) |
| U04-054 | internal `onWillCut` (`:742`) | MEMBER | Clipboard pre-cut event. | Internal clipboard handler. | N-A (clipboard/editing cluster excluded) |
| U04-055 | internal `onWillPaste` (`:748`) | MEMBER | Clipboard pre-paste event. | Internal clipboard handler. | N-A (clipboard/editing cluster excluded) |
| U04-056 | `onMouseUp` (`:753`) | MEMBER | Public pointer event. | Same root event. | TESTED |
| U04-057 | `onMouseDown` (`:758`) | MEMBER | Public pointer event. | Same root event. | TESTED |
| U04-058 | internal `onMouseDrag` (`:764`) | MEMBER | Drag event. | Internal pointer path. | N-A (not in current public denominator) |
| U04-059 | internal `onMouseDrop` (`:770`) | MEMBER | Drop event. | Internal pointer path. | N-A (not in current public denominator) |
| U04-060 | internal `onMouseDropCanceled` (`:776`) | MEMBER | Canceled-drop event. | Internal pointer path. | N-A (not in current public denominator) |
| U04-061 | internal `onDropIntoEditor` (`:782`) | MEMBER | Content-drop event. | Internal pointer/editing path. | N-A (editing cluster excluded) |
| U04-062 | `onContextMenu` (`:787`) | MEMBER | Public context-menu pointer event. | No root event. | N-A (commands/menu cluster excluded) |
| U04-063 | `onMouseMove` (`:792`) | MEMBER | Public pointer event. | Same root event. | TESTED |
| U04-064 | `onMouseLeave` (`:797`) | MEMBER | Public partial pointer event. | Same root event. | TESTED |
| U04-065 | internal `onMouseWheel` (`:803`) | MEMBER | Wheel event. | Internal scroll host. | N-A (raw browser event excluded from semantic facade) |
| U04-066 | `onKeyUp` (`:808`) | MEMBER | Public keyboard event upstream. | Internal keybinding host. | N-A (commands/input cluster excluded) |
| U04-067 | `onKeyDown` (`:813`) | MEMBER | Public keyboard event upstream. | Internal keybinding host. | N-A (commands/input cluster excluded) |
| U04-068 | `onDidLayoutChange` (`:818`) | MEMBER | Layout-info event. | Internal layout invalidation. | DEFERRED (semantic-event disposition required) |
| U04-069 | `onDidContentSizeChange` (`:823`) | MEMBER | Content-extent event. | Internal event. | DEFERRED (semantic-event disposition required) |
| U04-070 | `onDidScrollChange` (`:828`) | MEMBER | Semantic scroll event. | Same root event. | DEFERRED (canonical payload owner pending) |
| U04-071 | `onDidChangeHiddenAreas` (`:834`) | MEMBER | Folding/hidden-area event. | Internal event. | N-A (implementation event excluded from facade) |
| U04-072 | internal `onWillTriggerEditorOperationEvent` (`:840`) | MEMBER | Command dispatch event. | No root event. | N-A (commands cluster excluded) |
| U04-073 | `onBeginUpdate` (`:849`) | MEMBER | Multi-event transaction bracket. | Internal root delivery machinery. | N-A (implementation event excluded from external facade) |
| U04-074 | `onEndUpdate` (`:854`) | MEMBER | Matching transaction close. | Internal root delivery machinery. | N-A (implementation event excluded from external facade) |
| U04-075 | `onDidChangeViewZones` (`:856`) | MEMBER | Semantic zone-layout event. | Same root event. | TESTED |
| U04-076 | typed `saveViewState` (`:861`) | MEMBER | Code-editor state snapshot. | Root reduced state. | TESTED |
| U04-077 | typed `restoreViewState` (`:866`) | MEMBER | Code-editor state restore. | Root reduced state. | TESTED |
| U04-078 | `hasWidgetFocus` (`:871`) | MEMBER | Text-or-widget focus query. | Same root method; the current public caller sweep finds no direct caller. | PORTED |
| U04-079 | `getContribution<T>` (`:878`) | MEMBER | Public string lookup leaks contribution types. | Same root lookup currently. | DEFERRED (remove from external facade after single-ownership plan) |
| U04-080 | internal `invokeWithinContext` (`:884`) | MEMBER | Executes with VS Code service locator. | No local equivalent. | N-A (target explicitly forbids a general service locator) |
| U04-081 | typed `getModel` (`:889`) | MEMBER | Nullable text model. | Same root method. | TESTED |
| U04-082 | typed `setModel` (`:899`) | MEMBER | Attach/detach text model. | Same root method. | TESTED |
| U04-083 | `getOptions` (`:904`) | MEMBER | Complete computed option set. | Root returns raw `ViewerOptions`. | DEFERRED (opaque facade needs reviewed getters, not leaked computed implementation) |
| U04-084 | generic `getOption` (`:909`) | MEMBER | Single computed option by enum id. | No root method. | N-A (full source option registry is not ported) |
| U04-085 | `getRawOptions` (`:914`) | MEMBER | Unvalidated configuration snapshot. | Root `get_options` returns its snapshot. | DEFERRED (opaque facade should expose only reviewed read operations) |
| U04-086 | internal `getOverflowWidgetsDomNode` (`:919`) | MEMBER | External overflow DOM host. | No root getter. | N-A (construction/DOM implementation detail) |
| U04-087 | internal `getConfiguredWordAtPosition` (`:924`) | MEMBER | Word operation helper. | Internal hover/cursor helper. | N-A (not an external facade contract) |
| U04-088 | internal `onDidChangeLineHeight` (`:931`) | MEMBER | Decoration-driven line-height event. | Internal renderer event. | N-A (not an external facade contract) |
| U04-089 | internal `onDidChangeFont` (`:938`) | MEMBER | Model font event. | Internal renderer event. | N-A (not an external facade contract) |
| U04-090 | `getValue` (`:944`) | MEMBER | Read current model text with EOL/BOM options. | Root returns text without options. | DEFERRED (retain reduced getter and document omitted BOM/EOL controls) |
| U04-091 | `setValue` (`:950`) | MEMBER | Replace model contents. | Retained root method is host-driven whole-buffer replacement; `viewer/set_value_api_wbtest.mbt` covers the public operation without exposing interactive editing, undo, or actions. | TESTED |
| U04-092 | `getContentWidth` (`:956`) | MEMBER | Un-erased content width. | Same root method. | TESTED |
| U04-093 | `getScrollWidth` (`:960`) | MEMBER | Viewport scroll width. | Same root method. | TESTED |
| U04-094 | `getScrollLeft` (`:964`) | MEMBER | Horizontal offset. | Same root method. | TESTED |
| U04-095 | `getContentHeight` (`:970`) | MEMBER | Un-erased content height. | Same root method. | TESTED |
| U04-096 | `getScrollHeight` (`:974`) | MEMBER | Viewport scroll height. | Same root method. | TESTED |
| U04-097 | `getScrollTop` (`:978`) | MEMBER | Vertical offset. | Same root method. | TESTED |
| U04-098 | `setScrollLeft` (`:983`) | MEMBER | Horizontal scroll command with optional mode. | Reviewed root method deliberately fixes `Immediate` and exposes no public `ScrollType`. | DEFERRED (accepted signature reduction; smooth mode remains internal) |
| U04-099 | `setScrollTop` (`:987`) | MEMBER | Vertical scroll command with optional mode. | Reviewed root method deliberately fixes `Immediate` and exposes no public `ScrollType`. | DEFERRED (accepted signature reduction; smooth mode remains internal) |
| U04-100 | `setScrollPosition` (`:991`) | MEMBER | Partial two-axis scroll command. | Same capability via optional args. | TESTED |
| U04-101 | `hasPendingScrollAnimation` (`:995`) | MEMBER | Animation-state query. | Not public locally. | N-A (implementation state is not required by accepted facade) |
| U04-102 | `getAction` (`:1002`) | MEMBER | String action lookup. | No root method. | N-A (actions/commands excluded) |
| U04-103 | `executeCommand` (`:1010`) | MEMBER | Editing command. | No root method. | N-A (editing/commands excluded) |
| U04-104 | `pushUndoStop` (`:1015`) | MEMBER | Undo-stack mutation. | No root method. | N-A (editing/undo excluded) |
| U04-105 | `popUndoStop` (`:1020`) | MEMBER | Undo-stack mutation. | No root method. | N-A (editing/undo excluded) |
| U04-106 | public `executeEdits` overload (`:1029`) | MEMBER | Editing operation. | No root method. | N-A (editing excluded) |
| U04-107 | internal `executeEdits` overload (`:1031`) | MEMBER | Typed edit-source operation. | No root method. | N-A (editing excluded) |
| U04-108 | internal `edit` (`:1036`) | MEMBER | Text edit. | No root method. | N-A (editing excluded) |
| U04-109 | `executeCommands` (`:1043`) | MEMBER | Multi-command editing. | No root method. | N-A (editing/commands excluded) |
| U04-110 | `revealAllCursors` (`:1048`) | MEMBER | Reveal every cursor. | No public root method. | DEFERRED (multi-cursor denominator includes selections but lacks this source method) |
| U04-111 | internal `_getViewModel` (`:1053`) | MEMBER | Exposes implementation. | Root debug/test code currently leaks view-model facts. | N-A (private implementation must not cross facade) |
| U04-112 | `getLineDecorations` (`:1058`) | MEMBER | Read owner-filtered decorations. | Same root method; `viewer/test_viewer_wbtest.mbt` exercises owner filtering. | TESTED |
| U04-113 | `getDecorationsInRange` (`:1063`) | MEMBER | Read range decorations. | Same root method; `viewer/test_viewer_wbtest.mbt` exercises range filtering. | TESTED |
| U04-114 | `getFontSizeAtPosition` (`:1069`) | MEMBER | Computed font-size query. | No root method. | N-A (not in accepted denominator) |
| U04-115 | deprecated `deltaDecorations` (`:1076`) | MEMBER | Owner-scoped decoration replacement. | Same root method; `viewer/test_viewer_wbtest.mbt` exercises owner-scoped replacement. | TESTED |
| U04-116 | `removeDecorations` (`:1081`) | MEMBER | Remove decoration ids. | Same root method; root and browser decoration tests exercise removal. | TESTED |
| U04-117 | internal `setDecorationsByType` (`:1086`) | MEMBER | Type-registered decoration update. | Internal feature host. | N-A (implementation API excluded) |
| U04-118 | internal `setDecorationsByTypeFast` (`:1091`) | MEMBER | Fast typed-decoration update. | Internal feature host. | N-A (implementation API excluded) |
| U04-119 | internal `removeDecorationsByType` (`:1096`) | MEMBER | Type-owned decoration cleanup. | Internal feature host. | N-A (implementation API excluded) |
| U04-120 | `getLayoutInfo` (`:1101`) | MEMBER | Computed layout snapshot. | Same root method. | TESTED |
| U04-121 | `getVisibleRanges` (`:1107`) | MEMBER | Visible model ranges. | Same root method. | TESTED |
| U04-122 | internal `getVisibleRangesPlusViewportAboveBelow` (`:1112`) | MEMBER | Overscanned visible ranges. | The public disposition removes the root method; root white-box code keeps a package-private helper. | N-A (upstream marks this method internal) |
| U04-123 | internal `getWhitespaces` (`:1118`) | MEMBER | Runtime view-zone whitespace state. | Not public root. | N-A (rendered zone state stays private) |
| U04-124 | `getTopForLineNumber` (`:1123`) | MEMBER | Vertical line top, optionally zones. | Same root method. | TESTED |
| U04-125 | `getBottomForLineNumber` (`:1128`) | MEMBER | Vertical line bottom. | Root also exposes optional zone inclusion. | DEFERRED (local signature is broader and needs disposition) |
| U04-126 | `getTopForPosition` (`:1133`) | MEMBER | Vertical position top. | Same root method. | TESTED |
| U04-127 | `getLineHeightForPosition` (`:1138`) | MEMBER | Projected line height. | Same root method. | TESTED |
| U04-128 | internal `setHiddenAreas` (`:1145`) | MEMBER | Per-source hidden ranges. | The public disposition removes the root method; folding and white-box hosts retain private access. | N-A (upstream marks this method internal) |
| U04-129 | internal `setAriaOptions` (`:1151`) | MEMBER | Accessibility DOM state. | No root method. | N-A (accessibility cluster excluded) |
| U04-130 | `writeScreenReaderContent` (`:1156`) | MEMBER | Screen-reader output. | No root method. | N-A (accessibility cluster excluded) |
| U04-131 | internal `getTelemetryData` (`:1161`) | MEMBER | Telemetry implementation data. | Debug telemetry hooks exist separately. | N-A (telemetry implementation must not cross facade) |
| U04-132 | `getContainerDomNode` (`:1166`) | MEMBER | Editor host DOM. | Reviewed target retains the original browser host and returns non-null `Element` before and after disposal; private headless construction must not call it. | DEFERRED (implement the reviewed browser-host invariant) |
| U04-133 | `getDomNode` (`:1171`) | MEMBER | Active view DOM. | Same root method. | TESTED |
| U04-134 | `addContentWidget` (`:1176`) | MEMBER | Add public content widget contract. | No current root implementation or caller; external hosts remain root/common-only. | DEFERRED (the reviewed target does not add the full content-widget API) |
| U04-135 | `layoutContentWidget` (`:1181`) | MEMBER | Re-read content-widget position. | No current root implementation or caller; external hosts remain root/common-only. | DEFERRED (the reviewed target does not add the full content-widget API) |
| U04-136 | `removeContentWidget` (`:1185`) | MEMBER | Remove content widget. | No current root implementation or caller; external hosts remain root/common-only. | DEFERRED (the reviewed target does not add the full content-widget API) |
| U04-137 | `addOverlayWidget` (`:1190`) | MEMBER | Add public overlay widget contract. | Reviewed reduction: root `overlay_widget(id, node)` creates a browser-owned opaque handle and root add accepts that handle. | DEFERRED (replace the raw id/node pair with the reviewed immutable handle) |
| U04-138 | `layoutOverlayWidget` (`:1195`) | MEMBER | Re-read overlay position. | No current root implementation or caller; the reviewed handle is self-positioned and external hosts remain root/common-only. | DEFERRED (the reviewed target adds no explicit overlay layout operation) |
| U04-139 | `removeOverlayWidget` (`:1199`) | MEMBER | Remove overlay widget. | Reviewed reduction: root remove accepts the same opaque `OverlayWidget` handle rather than an id. | DEFERRED (align removal with the reviewed immutable handle) |
| U04-140 | `addGlyphMarginWidget` (`:1204`) | MEMBER | Add glyph widget. | No public root method. | N-A (glyph-margin widget cluster excluded) |
| U04-141 | `layoutGlyphMarginWidget` (`:1209`) | MEMBER | Relayout glyph widget. | No public root method. | N-A (glyph-margin widget cluster excluded) |
| U04-142 | `removeGlyphMarginWidget` (`:1213`) | MEMBER | Remove glyph widget. | No public root method. | N-A (glyph-margin widget cluster excluded) |
| U04-143 | `changeViewZones` (`:1218`) | MEMBER | Transactional zone mutation. | Same root method with private accessor type. | DEFERRED (switch signature to public browser accessor) |
| U04-144 | `getOffsetForColumn` (`:1225`) | MEMBER | Rendered horizontal offset. | Same root method. | TESTED |
| U04-145 | `getWidthOfLine` (`:1227`) | MEMBER | Rendered line width. | Same root method. | TESTED |
| U04-146 | internal `resetLineWidthCaches` (`:1233`) | MEMBER | Visibility-cache maintenance. | Internal view host. | N-A (implementation method excluded) |
| U04-147 | `render` (`:1238`) | MEMBER | Immediate render. | Internal root view host. | N-A (implementation method excluded from facade) |
| U04-148 | `renderAsync` (`:1243`) | MEMBER | Animation-frame render. | Internal root view host. | N-A (implementation method excluded from facade) |
| U04-149 | `getTargetAtClientPoint` (`:1251`) | MEMBER | Browser hit-test result. | Internal mouse host. | N-A (mouse target implementation is not accepted facade data) |
| U04-150 | `getScrolledVisiblePosition` (`:1260`) | MEMBER | Scroll-relative geometry. | Same root method. | TESTED |
| U04-151 | `applyFontInfo` (`:1265`) | MEMBER | Apply editor font CSS to target DOM. | No root method. | N-A (DOM styling helper excluded) |
| U04-152 | internal `hasModel` type guard (`:1271`) | MEMBER | Narrows to active editor. | The public disposition removes the root bool query; private state and test observability replace callers. | N-A (upstream-internal narrowing is not an external facade contract) |
| U04-153 | `setBanner` (`:1273`) | MEMBER | Own a banner DOM node/reserved height. | No root method. | N-A (banner DOM cluster excluded) |
| U04-154 | optional `handleInitialized` (`:1279`) | MEMBER | Host post-model/state/options hook. | Internal viewer initialization. | N-A (host lifecycle implementation excluded) |
| U04-155 | complete `IActiveCodeEditor` sibling (`:1285-1314`) | MEMBER | Non-null type-narrowed editor. | No public subtype. | N-A (implementation narrowing excluded) |
| U04-156 | diff-editor contract siblings (`:1319-1538`) | MEMBER | Diff and multi-file diff surfaces. | No local diff viewer. | N-A (diff cluster excluded) |
| U04-157 | `ContentWidgetPositionPreference` (`:126-139`) | MEMBER | Closed placement preference for public content widgets. | No current root content-widget implementation or caller; external hosts remain root/common-only. | DEFERRED (the reviewed target does not add the full content-widget API) |
| U04-158 | content preference `EXACT = 0` (`:130`) | CONST | Place exactly at the anchor position. | Private runtime has the branch, but the full content-widget facade has no current root caller. | DEFERRED (external hosts remain root/common-only) |
| U04-159 | content preference `ABOVE = 1` (`:134`) | CONST | Prefer placement above the anchor. | Private runtime has the branch, but the full content-widget facade has no current root caller. | DEFERRED (external hosts remain root/common-only) |
| U04-160 | content preference `BELOW = 2` (`:138`) | CONST | Prefer placement below the anchor. | Private runtime has the branch, but the full content-widget facade has no current root caller. | DEFERRED (external hosts remain root/common-only) |
| U04-161 | `IContentWidgetPosition` (`:143-173`) | MEMBER | Public content-widget placement descriptor. | No current root content-widget implementation or caller; external hosts remain root/common-only. | DEFERRED (the reviewed target does not expose this descriptor) |
| U04-162 | content `position` (`:155`) | MEMBER | Nullable primary model anchor. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U04-163 | content `secondaryPosition?` (`:162`) | MEMBER | Optional same-line secondary anchor. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U04-164 | content `preference` (`:166`) | MEMBER | Ordered placement preferences. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U04-165 | content `positionAffinity?` (`:172`) | MEMBER | Chooses a view position for ambiguous projection. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U04-166 | `IContentWidget` (`:177-218`) | MEMBER | Public content-widget callback/DOM contract. | No current root content-widget implementation or caller; external hosts remain root/common-only. | DEFERRED (the reviewed target does not add the full content-widget API) |
| U04-167 | content `allowEditorOverflow?` (`:181`) | MEMBER | Allows the widget outside the editor view DOM. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U04-168 | content `useDisplayNone?` (`:187`) | MEMBER | Hides off-screen widgets with `display:none`. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U04-169 | content `suppressMouseDown?` (`:192`) | MEMBER | Cancels widget mousedown default behavior. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U04-170 | content `getId` (`:196`) | MEMBER | Stable widget-map identity. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U04-171 | content `getDomNode` (`:200`) | MEMBER | Required widget DOM node. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U04-172 | content `getPosition` (`:205`) | MEMBER | Nullable live placement query. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U04-173 | content `beforeRender?` (`:211`) | MEMBER | Optional pre-layout dimension callback. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U04-174 | content `afterRender?` (`:217`) | MEMBER | Optional selected-placement/coordinate callback. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U04-175 | `IContentWidgetRenderedCoordinate` (`:223-233`) | MEMBER | Observable post-render coordinate payload. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U04-176 | rendered content `top` (`:227`) | MEMBER | Top relative to editor content. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U04-177 | rendered content `left` (`:232`) | MEMBER | Left relative to editor content. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U04-178 | `OverlayWidgetPositionPreference` (`:238-253`) | MEMBER | Closed corner/center placement preference. | The reviewed `OverlayWidget` reduction is self-positioned and fixes `getPosition` to null. | DEFERRED (no current root implementation/caller needs positioned overlays; external hosts remain root/common-only) |
| U04-179 | overlay preference `TOP_RIGHT_CORNER = 0` (`:242`) | CONST | Top-right placement. | The reviewed handle is self-positioned and exposes no preference enum. | DEFERRED (no current root implementation/caller; external hosts remain root/common-only) |
| U04-180 | overlay preference `BOTTOM_RIGHT_CORNER = 1` (`:247`) | CONST | Bottom-right placement. | The reviewed handle is self-positioned and exposes no preference enum. | DEFERRED (no current root implementation/caller; external hosts remain root/common-only) |
| U04-181 | overlay preference `TOP_CENTER = 2` (`:252`) | CONST | Top-center placement. | The reviewed handle is self-positioned and exposes no preference enum. | DEFERRED (no current root implementation/caller; external hosts remain root/common-only) |
| U04-182 | `IOverlayWidgetPositionCoordinates` (`:259-268`) | MEMBER | Explicit editor-relative overlay coordinates. | The reviewed handle is self-positioned and exposes no coordinate descriptor. | DEFERRED (no current root implementation/caller; external hosts remain root/common-only) |
| U04-183 | overlay coordinate `top` (`:263`) | MEMBER | Editor-relative top. | The reviewed handle is self-positioned and exposes no coordinate descriptor. | DEFERRED (no current root implementation/caller; external hosts remain root/common-only) |
| U04-184 | overlay coordinate `left` (`:267`) | MEMBER | Editor-relative left. | The reviewed handle is self-positioned and exposes no coordinate descriptor. | DEFERRED (no current root implementation/caller; external hosts remain root/common-only) |
| U04-185 | `IOverlayWidgetPosition` (`:275-286`) | MEMBER | Preferred or explicit overlay placement descriptor. | The reviewed handle fixes `getPosition` to null/self-positioned and exposes no position descriptor. | DEFERRED (no current root implementation/caller; external hosts remain root/common-only) |
| U04-186 | overlay `preference` (`:279`) | MEMBER | Enum, explicit coordinates, or host-positioned null. | Reviewed reduction selects only the null/self-positioned branch. | DEFERRED (positioned preferences have no current root implementation/caller) |
| U04-187 | overlay `stackOrdinal?` (`:285`) | MEMBER | Stable stack ordering for shared preferences. | The reviewed self-positioned handle exposes no stack ordinal. | DEFERRED (no current root implementation/caller; external hosts remain root/common-only) |
| U04-188 | `IOverlayWidget` (`:290-316`) | MEMBER | Public overlay-widget callback/DOM contract. | Reviewed target is a browser-owned opaque unmanaged `OverlayWidget` handle with immutable id/node and fixed null position. | DEFERRED (implement only the reviewed reduced handle, not the complete callback contract) |
| U04-189 | overlay `onDidLayout?` (`:294`) | MEMBER | Optional widget-owned layout invalidation event. | The reviewed unmanaged handle owns no layout event. | DEFERRED (no current root implementation/caller; external hosts remain root/common-only) |
| U04-190 | overlay `allowEditorOverflow?` (`:298`) | MEMBER | Allows rendering outside the view DOM. | The reviewed unmanaged handle exposes no overflow preference. | DEFERRED (no current root implementation/caller; external hosts remain root/common-only) |
| U04-191 | overlay `getId` (`:302`) | MEMBER | Stable widget-map identity. | Root `overlay_widget(id, node)` stores immutable identity in the opaque browser-owned handle. | DEFERRED (implement the reviewed handle factory and accessor) |
| U04-192 | overlay `getDomNode` (`:306`) | MEMBER | Required overlay DOM node. | Root `overlay_widget(id, node)` stores the immutable DOM node in the opaque browser-owned handle. | DEFERRED (implement the reviewed handle factory and accessor) |
| U04-193 | overlay `getPosition` (`:311`) | MEMBER | Nullable live placement query. | Reviewed handle has fixed null position, making every overlay self-positioned. | DEFERRED (accepted seam reduction; no positioned-overlay caller exists) |
| U04-194 | overlay `getMinContentWidthInPx?` (`:315`) | MEMBER | Optional contribution to editor scroll width. | The reviewed unmanaged handle exposes no minimum-width callback. | DEFERRED (no current root implementation/caller; external hosts remain root/common-only) |
| U04-195 | `IEditorMouseEvent` (`:536-539`) | MEMBER | Public hit-tested editor mouse event. | Root has the pair but owns it at the wrong package. | DEFERRED (move the canonical wrapper to `viewer/browser`) |
| U04-196 | full mouse `event` (`:537`) | MEMBER | Raw browser mouse event. | Root wraps current `viewer/browser.EditorMouseEvent`; that raw type becomes `EditorDomMouseEvent`. | DEFERRED (rename the raw event while moving the hit-tested wrapper) |
| U04-197 | full mouse `target` (`:538`) | MEMBER | Required hit-test target. | Existing browser `MouseTarget` is the mapped union. | DEFERRED (move the wrapper without duplicating the target type) |
| U04-198 | `IPartialEditorMouseEvent` (`:540-543`) | MEMBER | Public mouse event whose hit target may be absent. | Root has the pair but owns it at the wrong package. | DEFERRED (move the canonical wrapper to `viewer/browser`) |
| U04-199 | partial mouse `event` (`:541`) | MEMBER | Raw browser mouse event. | Root wraps the raw event that becomes `EditorDomMouseEvent`. | DEFERRED (rename the raw event while moving the hit-tested wrapper) |
| U04-200 | partial mouse nullable `target` (`:542`) | MEMBER | Hit-test target may be null. | Root `PartialEditorMouseEvent.target : MouseTarget?` preserves the distinction. | DEFERRED (move the wrapper without an adapter) |

### U05 — `CodeEditorWidget` public-boundary behavior

| Row | Source atom | Kind | Public-boundary relevance | Local mapping / evidence | Status |
|---|---|---|---|---|---|
| U05-001 | `CodeEditorWidget` (`:69-2085`) | MEMBER | Concrete implementation of `ICodeEditor`. | Root `Viewer` is an independent MoonBit port. | DEFERRED (ownership/API reshape must preserve the mapped behavior rows below) |
| U05-002 | DnD decoration registration (`:71-74`) | CONST | Class `dnd-target` under description `workbench-dnd-target`. | No public DnD editing API. | N-A (drop/editing cluster excluded) |
| U05-003 | `_deliveryQueue` (`:78`) | MEMBER | Shared FIFO for public event owners. | Root cursor delivery queue and event emitters. | TESTED |
| U05-004 | `_contributions` (`:79`) | MEMBER | Editor-lifetime contribution owner. | Central contribution enum/map. | TESTED |
| U05-005 | `_onDidDispose` emitter (`:81`) | MEMBER | Owns dispose listeners. | Root dispose emitter. | TESTED |
| U05-006 | public `onDidDispose` alias (`:82`) | MEMBER | Readonly subscription surface. | Root subscription method. | TESTED |
| U05-007 | `_onDidChangeModelContent` emitter (`:84`) | MEMBER | Delivery-queued content listeners. | Root model-content emitter. | TESTED |
| U05-008 | public model-content alias (`:85`) | MEMBER | Semantic content subscription. | Root subscription method. | TESTED |
| U05-009 | `_onDidChangeModelLanguage` emitter (`:87`) | MEMBER | Delivery-queued language listeners. | Internal root language handling. | DEFERRED (public event disposition unresolved) |
| U05-010 | public model-language alias (`:88`) | MEMBER | Language subscription. | No root subscription. | DEFERRED (public event disposition unresolved) |
| U05-011 | `_onDidChangeModelLanguageConfiguration` emitter (`:90`) | MEMBER | Language-config listener owner. | Internal language service. | N-A (implementation event excluded) |
| U05-012 | public language-config alias (`:91`) | MEMBER | Language-config subscription. | No root subscription. | N-A (implementation event excluded) |
| U05-013 | `_onDidChangeModelOptions` emitter (`:93`) | MEMBER | Model-option listener owner. | Internal model event. | DEFERRED (tab-size capability may justify a semantic event) |
| U05-014 | public model-options alias (`:94`) | MEMBER | Model-option subscription. | No root subscription. | DEFERRED (public event disposition unresolved) |
| U05-015 | `_onDidChangeModelDecorations` emitter (`:96`) | MEMBER | Decoration listener owner. | Internal decoration event. | N-A (decoration event excluded) |
| U05-016 | public decoration alias (`:97`) | MEMBER | Decoration subscription. | No root subscription. | N-A (decoration event excluded) |
| U05-017 | `_onDidChangeLineHeight` emitter (`:99`) | MEMBER | Line-height listener owner. | Internal renderer event. | N-A (implementation event excluded) |
| U05-018 | public line-height alias (`:100`) | MEMBER | Internal contract alias. | No root subscription. | N-A (implementation event excluded) |
| U05-019 | `_onDidChangeFont` emitter (`:102`) | MEMBER | Font listener owner. | Internal renderer event. | N-A (implementation event excluded) |
| U05-020 | public font alias (`:103`) | MEMBER | Internal contract alias. | No root subscription. | N-A (implementation event excluded) |
| U05-021 | `_onDidChangeModelTokens` emitter (`:105`) | MEMBER | Token listener owner. | Internal token renderer event. | N-A (implementation event excluded) |
| U05-022 | public model-token alias (`:106`) | MEMBER | Internal token subscription. | No root subscription. | N-A (implementation event excluded) |
| U05-023 | `_onDidChangeConfiguration` emitter (`:108`) | MEMBER | Delivery-queued option listeners. | Internal option invalidation. | DEFERRED (public event disposition unresolved) |
| U05-024 | public configuration alias (`:109`) | MEMBER | Option subscription. | No root subscription. | DEFERRED (public event disposition unresolved) |
| U05-025 | `_onWillChangeModel` emitter (`:111`) | MEMBER | Delivery-queued pre-detach listeners. | Root has internal pre-detach ordering. | DEFERRED (not currently public) |
| U05-026 | public will-change alias (`:112`) | MEMBER | Pre-model subscription. | No root subscription. | DEFERRED (public event disposition unresolved) |
| U05-027 | `_onDidChangeModel` emitter (`:114`) | MEMBER | Delivery-queued post-attach listeners. | Root model-change emitter. | TESTED |
| U05-028 | public did-change alias (`:115`) | MEMBER | Post-model subscription. | Root subscription method. | TESTED |
| U05-029 | `_onDidChangeCursorPosition` emitter (`:117`) | MEMBER | Delivery-queued position owner. | Root cursor event queue. | TESTED |
| U05-030 | public cursor-position alias (`:118`) | MEMBER | Position subscription. | Root subscription method. | DEFERRED (canonical payload owner pending) |
| U05-031 | `_onDidChangeCursorSelection` emitter (`:120`) | MEMBER | Delivery-queued selection owner. | Root cursor event queue. | TESTED |
| U05-032 | public cursor-selection alias (`:121`) | MEMBER | Selection subscription. | Root subscription method. | DEFERRED (canonical payload owner pending) |
| U05-033 | `_onDidAttemptReadOnlyEdit` interaction emitter (`:123`) | MEMBER | Forces pre-interaction contributions. | No public edit surface. | N-A (editing event excluded) |
| U05-034 | public readonly-attempt alias (`:124`) | MEMBER | Failed-edit subscription. | No root subscription. | N-A (editing event excluded) |
| U05-035 | `_onDidLayoutChange` emitter (`:126`) | MEMBER | Layout listener owner. | Internal layout event. | DEFERRED (public event disposition unresolved) |
| U05-036 | public layout alias (`:127`) | MEMBER | Layout subscription. | No root subscription. | DEFERRED (public event disposition unresolved) |
| U05-037 | `_onDidContentSizeChange` emitter (`:197`) | MEMBER | Content-extent listener owner. | Internal view event. | DEFERRED (public event disposition unresolved) |
| U05-038 | public content-size alias (`:198`) | MEMBER | Content-size subscription. | No root subscription. | DEFERRED (public event disposition unresolved) |
| U05-039 | `_onDidScrollChange` emitter (`:200`) | MEMBER | Delivery-queued scroll owner. | Root scroll emitter. | TESTED |
| U05-040 | public scroll alias (`:201`) | MEMBER | Scroll subscription. | Root subscription method. | DEFERRED (canonical payload owner pending) |
| U05-041 | `_onDidChangeViewZones` emitter (`:203`) | MEMBER | Zone-layout listener owner. | Root zone emitter. | TESTED |
| U05-042 | public view-zone alias (`:204`) | MEMBER | Zone subscription. | Root subscription method. | TESTED |
| U05-043 | `_onDidChangeHiddenAreas` emitter (`:206`) | MEMBER | Hidden-area listener owner. | Internal folding event. | N-A (implementation event excluded) |
| U05-044 | public hidden-area alias (`:207`) | MEMBER | Hidden-area subscription. | No root subscription. | N-A (implementation event excluded) |
| U05-045 | `_updateCounter = 0` (`:209`) | MEMBER | Nests event transactions. | Root cursor/event delivery machinery. | PORTED |
| U05-046 | `_onWillTriggerEditorOperationEvent` owner (`:211`) | MEMBER | Command pre-operation listener. | No root equivalent. | N-A (commands excluded) |
| U05-047 | public will-operation alias (`:212`) | MEMBER | Command subscription. | No root equivalent. | N-A (commands excluded) |
| U05-048 | `_onBeginUpdate` owner (`:214`) | MEMBER | Fires at outer transaction entry. | Internal root delivery machinery. | PORTED |
| U05-049 | public begin-update alias (`:215`) | MEMBER | Transaction subscription. | No root public event. | N-A (implementation event excluded) |
| U05-050 | `_onEndUpdate` owner (`:217`) | MEMBER | Fires at outer transaction exit. | Internal root delivery machinery. | PORTED |
| U05-051 | public end-update alias (`:218`) | MEMBER | Transaction subscription. | No root public event. | N-A (implementation event excluded) |
| U05-052 | `isSimpleWidget` getter (`:225-227`) | MEMBER | Reads configuration role. | No root public role. | N-A (internal construction role) |
| U05-053 | `contextMenuId` getter (`:229-231`) | MEMBER | Reads menu owner. | No root public menu. | N-A (menu/commands excluded) |
| U05-054 | `_telemetryData` (`:233`) | MEMBER | Borrowed construction metadata. | Debug hooks are separately leaked locally. | N-A (telemetry must not cross target facade) |
| U05-055 | `_domElement` (`:235`) | MEMBER | Required editor host DOM owner. | Browser-created Viewer host. | PORTED |
| U05-056 | `_overflowWidgetsDomNode` (`:236`) | MEMBER | Optional external DOM host. | No public root option. | N-A (standalone DOM option excluded) |
| U05-057 | `_id` (`:237`) | MEMBER | Unique numeric identity. | Viewer instance id. | TESTED |
| U05-058 | `_configuration` (`:238`) | MEMBER | Sole computed/raw option owner. | Root `ViewerOptions` plus derived view options. | DEFERRED (opaque public snapshot must not expose derived owners) |
| U05-059 | `_contributionsDisposable` (`:239`) | MEMBER | Model-attach-scoped contribution handle. | Central contribution owner. | TESTED |
| U05-060 | `_actions` (`:241`) | MEMBER | Action registry. | No public root action registry. | N-A (actions excluded) |
| U05-061 | `_modelData` (`:244`) | MEMBER | Nullable model/view owner. | Viewer model/view fields. | TESTED |
| U05-062 | `_instantiationService` (`:246`) | MEMBER | Child DI container. | No local service locator. | N-A (target forbids full DI) |
| U05-063 | `_contextKeyService` (`:247`) | MEMBER | Scoped context-key owner. | Internal keybinding state only. | N-A (service implementation excluded) |
| U05-064 | `contextKeyService` getter (`:248`) | MEMBER | Exposes scoped service internally. | No root getter. | N-A (service implementation excluded) |
| U05-065 | `_notificationService` (`:249`) | MEMBER | Warning/UI service. | No public host capability. | N-A (notification path excluded) |
| U05-066 | `_codeEditorService` (`:250`) | MEMBER | Editor registry and decoration service. | No public editor service. | N-A (service implementation excluded) |
| U05-067 | `_commandService` (`:251`) | MEMBER | Command dispatcher. | No public command service. | N-A (commands excluded) |
| U05-068 | `_themeService` (`:252`) | MEMBER | Theme implementation service. | Theme string option adapts into local renderer. | DEFERRED (typed service must not leak through `ViewerServices`) |
| U05-069 | `_userInteractionService` (`:253`) | MEMBER | Interaction notification service. | No public capability. | N-A (implementation service excluded) |
| U05-070 | `_contentWidgets` (`:255`) | MEMBER | Editor-lifetime content-widget map. | No current root content-widget implementation or caller; external hosts remain root/common-only. | DEFERRED (the reviewed target does not add the full content-widget API) |
| U05-071 | `_overlayWidgets` (`:256`) | MEMBER | Editor-lifetime overlay-widget map. | Current raw id/node storage becomes a map of browser-owned opaque unmanaged `OverlayWidget` handles. | DEFERRED (replace the raw seam with the reviewed immutable handle) |
| U05-072 | `_glyphMarginWidgets` (`:257`) | MEMBER | Glyph-widget map. | No public root API. | N-A (glyph widgets excluded) |
| U05-073 | `_decorationTypeKeysToIds` (`:262`) | MEMBER | Decoration-type ownership. | Internal feature state. | N-A (decoration implementation excluded) |
| U05-074 | `_decorationTypeSubtypes` (`:263`) | MEMBER | Dynamic subtype ownership. | Internal feature state. | N-A (decoration implementation excluded) |
| U05-075 | `_bannerDomNode = null` (`:265`) | MEMBER | Optional owned banner DOM. | No local banner. | N-A (banner excluded) |
| U05-076 | `_dropIntoEditorDecorations` (`:267`) | MEMBER | DnD indicator collection. | No public DnD editing API. | N-A (drop/editing excluded) |
| U05-077 | `inComposition = false` (`:269`) | MEMBER | IME state. | Internal input state. | N-A (editing/input excluded) |
| U05-078 | constructor (`:271-408`) | MEMBER | Builds DOM/config/services/contributions before registry publication. | `Viewer::create` plus private headless constructor. | DEFERRED (only browser construction remains public) |
| U05-079 | `willCreateCodeEditor` first (`:287`) | LIFETIME | Service observes construction before local state. | No global editor service. | N-A (registry service excluded) |
| U05-080 | clone input options (`:289`) | LIFETIME | Prevents mutation of caller object. | MoonBit value snapshot. | PORTED |
| U05-081 | retain host DOM (`:291`) | LIFETIME | Container is captured before configuration. | Viewer browser host. | PORTED |
| U05-082 | retain interaction service (`:292`) | LIFETIME | Borrowed service. | No local equivalent. | N-A (implementation service excluded) |
| U05-083 | extract overflow DOM then delete option (`:293-294`) | DOM | Separates construction-only node from raw live options. | No public local option. | N-A (construction option excluded) |
| U05-084 | increment global `EDITOR_ID` (`:295`) | LIFETIME | Monotonic instance identity. | Local id generator. | TESTED |
| U05-085 | initialize decoration maps (`:296-297`) | LIFETIME | Empty owner state before configuration events. | Internal decoration state. | N-A (decoration cluster excluded) |
| U05-086 | retain telemetry option (`:298`) | LIFETIME | Borrowed metadata. | No accepted public metadata. | N-A (telemetry excluded) |
| U05-087 | create/register configuration (`:300-302`) | LIFETIME | Configuration lifetime is editor-owned. | Viewer owns option snapshot/derived layout. | PORTED |
| U05-088 | missing simple-widget option defaults `false` (`:300`) | CONST | Real code editor by default. | Viewer is always real browser editor publicly. | N-A (no simple-widget public mode) |
| U05-089 | explicit context-menu id branch (`:301`) | BRANCH | Caller override wins. | No local menu option. | N-A (menu excluded) |
| U05-090 | default menu branches simple/editor (`:301`) | BRANCH | Role selects default menu id. | No local menu service. | N-A (menu excluded) |
| U05-091 | set `--editor-font-size` on host (`:303`) | DOM | Initial computed font size becomes CSS custom property. | Local browser host applies font info. | TESTED |
| U05-092 | own configuration listener (`:304-315`) | LIFETIME | Subscription dies with editor. | Viewer option-change hooks. | TESTED |
| U05-093 | fire configuration event first (`:305`) | LIFETIME | Public event precedes specialized reactions. | Internal option event order. | PORTED |
| U05-094 | layout-info changed branch (`:308-311`) | BRANCH | Fires layout only for that computed option. | Layout invalidation tests. | TESTED |
| U05-095 | font-size changed branch (`:312-314`) | BRANCH | Rewrites CSS variable only for font change. | Font option DOM update. | TESTED |
| U05-096 | create scoped context-key service on host (`:317`) | DOM | DOM scope owns context keys. | Internal local keybindings use concrete state. | N-A (full context service excluded) |
| U05-097 | optional context-key-values branch (`:318-322`) | BRANCH | Installs only supplied extra keys. | No public option. | N-A (context-key construction excluded) |
| U05-098 | create every supplied context key (`:319-320`) | LIFETIME | Values enter scoped service before managers. | No public option. | N-A (context-key construction excluded) |
| U05-099 | retain notification/editor/command/theme services (`:323-326`) | LIFETIME | Borrowed platform services. | Local uses explicit feature implementations internally. | N-A (these concrete services must not leak through `ViewerServices`) |
| U05-100 | own context-key managers (`:327-328`) | LIFETIME | Managers subscribe before contributions. | Internal keybinding/feature context. | N-A (implementation managers excluded) |
| U05-101 | create child instantiation service with scoped context (`:330`) | LIFETIME | Contributions resolve editor-local context. | Direct typed constructors. | N-A (no DI container) |
| U05-102 | initialize `_modelData = null` (`:332`) | LIFETIME | Editor starts detached. | Public create can be model-less. | TESTED |
| U05-103 | initialize content map empty (`:334`) | LIFETIME | Widgets may register before model attach. | No current root content-widget implementation or caller; external hosts remain root/common-only. | DEFERRED (the reviewed target does not add the full content-widget API) |
| U05-104 | initialize overlay map empty (`:335`) | LIFETIME | Widgets may register before model attach. | Local overlay map preserves this lifetime behavior; the reviewed target stores opaque handles instead of raw pairs. | PORTED |
| U05-105 | initialize glyph map empty (`:336`) | LIFETIME | Glyph widgets may pre-register. | No local public glyph widgets. | N-A (glyph widgets excluded) |
| U05-106 | supplied-contributions array branch (`:338-341`) | BRANCH | Exact caller list replaces defaults. | Local registry is fixed. | N-A (public construction does not accept contribution implementations) |
| U05-107 | default-contribution fallback (`:341-343`) | BRANCH | Uses registry snapshot. | Local central registry. | TESTED |
| U05-108 | initialize contributions before actions/DnD/publication (`:344`) | LIFETIME | Construction order is observable. | Local central construction order test. | TESTED |
| U05-109 | iterate registered editor actions (`:346`) | LIFETIME | Creates per-editor actions. | No public action registry. | N-A (actions excluded) |
| U05-110 | duplicate action-id branch (`:347-350`) | BRANCH | Reports duplicate and preserves first. | No public action registry. | N-A (actions excluded) |
| U05-111 | duplicate action `continue` (`:349`) | EXIT | Skips replacement. | No public action registry. | N-A (actions excluded) |
| U05-112 | construct/store internal action (`:351-365`) | LIFETIME | Binds DI/context then stores by id. | No public action registry. | N-A (actions excluded) |
| U05-113 | DnD enabled predicate (`:367-370`) | BRANCH | Requires not-readonly and option enabled. | Viewer is readonly-facing. | N-A (drop/editing excluded) |
| U05-114 | own `DragAndDropObserver` on host (`:372-405`) | DOM | Host DOM listener lifetime follows editor. | No public drop/editing API. | N-A (drop/editing excluded) |
| U05-115 | drag-over disabled return (`:374-376`) | EXIT | No hit test/indicator when disabled. | No local path. | N-A (drop/editing excluded) |
| U05-116 | drag-over target-position branch (`:378-381`) | BRANCH | Indicator only for positioned target. | No local path. | N-A (drop/editing excluded) |
| U05-117 | drop disabled return (`:384-386`) | EXIT | No cleanup/event when disabled. | No local path. | N-A (drop/editing excluded) |
| U05-118 | remove indicator before payload checks (`:388`) | LIFETIME | Drop always clears prior visual first. | No local path. | N-A (drop/editing excluded) |
| U05-119 | missing `dataTransfer` return (`:390-392`) | EXIT | Stops before hit test/event. | No local path. | N-A (drop/editing excluded) |
| U05-120 | drop target-position branch/fire (`:394-397`) | BRANCH | Fires only for positioned target. | No local path. | N-A (drop/editing excluded) |
| U05-121 | drag-leave clears indicator (`:399-401`) | LIFETIME | Visual owner resets on leave. | No local path. | N-A (drop/editing excluded) |
| U05-122 | drag-end clears indicator (`:402-404`) | LIFETIME | Visual owner resets on end. | No local path. | N-A (drop/editing excluded) |
| U05-123 | publish editor to service last (`:407`) | LIFETIME | Registry observes fully initialized object. | No global editor registry. | N-A (registry service excluded) |
| U05-124 | `writeScreenReaderContent` (`:410-412`) | MEMBER | Optional-view accessibility call. | No root method. | N-A (accessibility excluded) |
| U05-125 | `_createConfiguration` (`:414-416`) | MEMBER | Constructs DOM-aware computed configuration. | Root derives local option/layout values. | PORTED |
| U05-126 | `getId` (`:418-420`) | MEMBER | Type-prefixed unique id. | Root id method; the current public caller sweep finds no direct caller. | PORTED |
| U05-127 | `getEditorType` (`:422-424`) | MEMBER | Constant code-editor discriminator. | Root type method. | PORTED |
| U05-128 | `dispose` (`:426-439`) | MEMBER | Ordered editor teardown. | Root disposal lifecycle. | TESTED |
| U05-129 | remove from code-editor service first (`:427`) | LIFETIME | Registry no longer exposes dying editor. | No global registry. | N-A (registry service excluded) |
| U05-130 | clear actions (`:429`) | LIFETIME | Drops action instances before model. | No action registry. | N-A (actions excluded) |
| U05-131 | clear content-widget map (`:430`) | LIFETIME | Drops editor widget ownership. | No current root content-widget implementation or caller; external hosts remain root/common-only. | DEFERRED (the reviewed target does not add the full content-widget API) |
| U05-132 | clear overlay-widget map (`:431`) | LIFETIME | Drops overlay ownership. | Root clears registrations on dispose; replacing raw pairs with opaque handles preserves that ownership boundary. | TESTED |
| U05-133 | remove decoration types (`:433`) | LIFETIME | Global type registry cleanup before detach. | Internal decoration cleanup. | N-A (decoration implementation excluded) |
| U05-134 | detach then post-clean outgoing model (`:434`) | LIFETIME | Model/view disposal precedes owner-decoration cleanup. | Root model/dispose ordering. | TESTED |
| U05-135 | fire dispose before base-store teardown (`:436-438`) | LIFETIME | Listeners observe still-reachable contribution/base state. | Central ownership dispose tests. | TESTED |
| U05-136 | `invokeWithinContext` (`:441-443`) | MEMBER | Internal service-locator execution. | No local equivalent. | N-A (target forbids general service locator) |
| U05-137 | `updateOptions` (`:445-447`) | MEMBER | Undefined becomes empty partial update. | Root accepts full `ViewerOptions` snapshot. | DEFERRED (opaque option update semantics require explicit reviewed contract) |
| U05-138 | undefined-options fallback `{}` (`:446`) | BRANCH | Missing update is a no-op snapshot. | Typed root argument cannot be absent. | N-A (typed signature removes undefined) |
| U05-139 | `getOptions` (`:449-451`) | MEMBER | Returns computed options. | Root returns raw/mixed snapshot. | DEFERRED (expose only reviewed opaque getters) |
| U05-140 | `getOption` (`:453-455`) | MEMBER | Typed computed option lookup. | No root registry lookup. | N-A (full option registry excluded) |
| U05-141 | `getRawOptions` (`:457-459`) | MEMBER | Returns unvalidated options. | Root `get_options`. | DEFERRED (opaque facade must not expose fields directly) |
| U05-142 | `getOverflowWidgetsDomNode` (`:461-463`) | MEMBER | Returns construction-only external DOM. | No root method. | N-A (DOM implementation option excluded) |
| U05-143 | `getConfiguredWordAtPosition` (`:465-470`) | MEMBER | Config-aware word lookup. | Internal hover/cursor helper. | N-A (not an external facade method) |
| U05-144 | no-model word lookup return (`:466-468`) | EXIT | Returns null detached. | Internal helper guard. | N-A (method excluded) |
| U05-145 | `getValue` (`:472-485`) | MEMBER | Reads model text with EOL/BOM policy. | Root reduced getter. | TESTED |
| U05-146 | no-model value returns empty string (`:473-475`) | EXIT | Detached sentinel. | Public read API test. | TESTED |
| U05-147 | truthy `preserveBOM` branch (`:477`) | BRANCH | Only explicit truthy option preserves BOM. | Root exposes no BOM option. | N-A (reduced getter omits BOM control) |
| U05-148 | LF line-ending branch (`:479-480`) | BRANCH | Forces LF. | Root exposes no EOL option. | N-A (reduced getter omits EOL control) |
| U05-149 | CRLF line-ending branch (`:481-482`) | BRANCH | Forces CRLF. | Root exposes no EOL option. | N-A (reduced getter omits EOL control) |
| U05-150 | default `TextDefined` EOL (`:478-484`) | CONST | Model EOL is used absent recognized override. | Root getter uses model EOL. | TESTED |
| U05-151 | `setValue` (`:487-497`) | MEMBER | Replaces content inside update bracket. | Retained root method is host-driven whole-buffer replacement; `viewer/set_value_api_wbtest.mbt` covers the operation while interactive editing, undo, and actions remain absent. | TESTED |
| U05-152 | begin update before model guard (`:488-490`) | LIFETIME | Even detached call is bracketed. | Root content delivery barrier differs. | DEFERRED (event bracket is internal but ordering must remain equivalent) |
| U05-153 | no-model set-value return (`:490-492`) | EXIT | Detached mutation no-ops. | Root behavior. | TESTED |
| U05-154 | `finally` always ends update (`:494-496`) | LIFETIME | Balances both mutation and early return. | Root barrier/lifecycle tests. | TESTED |
| U05-155 | `getModel` (`:499-504`) | MEMBER | Nullable model getter. | Same root method. | TESTED |
| U05-156 | no-model getter return (`:500-502`) | EXIT | Returns null detached. | Public read API test. | TESTED |
| U05-157 | `setModel` (`:506-548`) | MEMBER | Ordered detach/attach transition. | Same root method. | TESTED |
| U05-158 | begin/end update `try/finally` (`:507-508`, `:545-547`) | LIFETIME | Every transition/no-op is bracketed. | Root has explicit event ordering. | DEFERRED (no public bracket event, but ordering must remain tested) |
| U05-159 | detached-to-null branch (`:510-513`) | BRANCH | Recognizes identity no-op. | Root model transition tests. | TESTED |
| U05-160 | detached-to-null return (`:512`) | EXIT | Skips events/attach. | Root behavior. | TESTED |
| U05-161 | same-model branch (`:514-517`) | BRANCH | Recognizes identity no-op. | Root behavior. | TESTED |
| U05-162 | same-model return (`:516`) | EXIT | Skips events/attach. | Root behavior. | TESTED |
| U05-163 | event old/new URLs (`:519-522`) | LIFETIME | Captures resources before detach. | Root model-change payload. | TESTED |
| U05-164 | fire will-change before focus/detach (`:523`) | LIFETIME | Pre-event sees outgoing model. | Root internal ordering. | TESTED |
| U05-165 | capture text focus before detach (`:525`) | LIFETIME | Enables restoration on new view. | Root focus transfer. | PORTED |
| U05-166 | detach then attach (`:526-527`) | LIFETIME | No simultaneous old/new model data. | Root model swap. | TESTED |
| U05-167 | attached-model branch (`:528-533`) | BRANCH | New real model/view exists. | Root attach branch. | TESTED |
| U05-168 | prior-focus branch restores focus (`:530-532`) | BRANCH | Focus survives model swap. | Root focus behavior. | PORTED |
| U05-169 | no-model branch clears both focus emitters (`:533-538`) | BRANCH | Outside observers see detached editor unfocused. | Root detach behavior. | TESTED |
| U05-170 | remove decoration types before did-change (`:540`) | LIFETIME | Old type ownership clears before public post-event. | Local decoration ordering differs by feature. | DEFERRED (decoration API is outside this plan but event order must be preserved) |
| U05-171 | fire did-change before post-detach cleanup (`:541-542`) | LIFETIME | Listeners can still observe outgoing owned decorations. | Exact local model-change ordering test. | TESTED |
| U05-172 | acquire contribution post-attach handle last (`:544`) | LIFETIME | Model-scoped contribution work starts after post-cleanup. | Central contribution model-lifecycle tests. | TESTED |
| U05-173 | `getVisibleRanges` (`:563-568`) | MEMBER | Read visible model ranges. | Same root method. | TESTED |
| U05-174 | no-model visible-ranges return `[]` (`:564-566`) | EXIT | Detached sentinel. | Public read API test. | TESTED |
| U05-175 | `getVisibleRangesPlusViewportAboveBelow` (`:570-575`) | MEMBER | Read overscanned ranges. | Same root method currently public. | DEFERRED (upstream-internal helper needs disposition) |
| U05-176 | no-model overscan return `[]` (`:571-573`) | EXIT | Detached sentinel. | Public read behavior. | TESTED |
| U05-177 | `getWhitespaces` (`:577-582`) | MEMBER | Read runtime zone whitespace. | Internal view-zone state. | N-A (runtime zone implementation stays private) |
| U05-178 | no-model whitespace return `[]` (`:578-580`) | EXIT | Detached sentinel. | Internal only. | N-A (method excluded) |
| U05-179 | `getTopForLineNumber` (`:593-598`) | MEMBER | Compute top offset, optionally zones. | Same root method. | TESTED |
| U05-180 | no-model line-top return `-1` (`:594-596`) | EXIT | Detached sentinel. | Public read API test. | TESTED |
| U05-181 | `getTopForPosition` (`:600-605`) | MEMBER | Compute position top excluding zones. | Same root method. | TESTED |
| U05-182 | no-model position-top return `-1` (`:601-603`) | EXIT | Detached sentinel. | Public read API test. | TESTED |
| U05-183 | `_getVerticalOffsetForPosition` (`:607-614`) | MEMBER | Validate model position, convert to view, query layout. | Local view-model converter/layout. | TESTED |
| U05-184 | `getBottomForLineNumber` (`:616-621`) | MEMBER | Offset after max column. | Same root method. | TESTED |
| U05-185 | no-model line-bottom return `-1` (`:617-619`) | EXIT | Detached sentinel. | Public read API test. | TESTED |
| U05-186 | max-column sentinel `Number.MAX_SAFE_INTEGER` (`:620`) | CONST | Validation clamps to line end. | Local equivalent line-end query. | TESTED |
| U05-187 | `getLineHeightForPosition` (`:623-635`) | MEMBER | Projected line height. | Same root method. | TESTED |
| U05-188 | no-model line-height return `-1` (`:624-626`) | EXIT | Detached sentinel. | Public read API test. | TESTED |
| U05-189 | visible-position branch (`:630-633`) | BRANCH | Converts and returns view-line height. | Wrapped/hidden geometry tests. | TESTED |
| U05-190 | hidden-position fallback `0` (`:634`) | BRANCH | Hidden positions have no visible height. | Hidden-area mapping tests. | TESTED |
| U05-191 | `setHiddenAreas` optional-chain (`:637-639`) | MEMBER | Detached call no-ops; live call lifts ranges. | Same root method. | TESTED |
| U05-192 | `getVisibleColumnFromPosition` (`:641-650`) | MEMBER | Tab-aware visible column. | Same root method. | TESTED |
| U05-193 | no-model visible-column returns raw column (`:642-644`) | EXIT | Detached fallback preserves caller data. | Public read API test. | TESTED |
| U05-194 | validate/use model tab size/add one (`:646-649`) | BRANCH | Converts zero-based helper output to editor column. | Local cursor-column helper. | TESTED |
| U05-195 | `getStatusbarColumn` (`:652-661`) | MEMBER | Status-bar column query. | Same root method currently public. | DEFERRED (upstream marks this internal) |
| U05-196 | no-model status column returns raw column (`:653-655`) | EXIT | Detached fallback. | Public read behavior. | TESTED |
| U05-197 | `getPosition` (`:663-668`) | MEMBER | Primary cursor position. | Same root method. | TESTED |
| U05-198 | no-model position returns `null` (`:664-666`) | EXIT | Detached sentinel. | Public read API test. | TESTED |
| U05-199 | `setPosition` default source `api` (`:670`) | MEMBER | Collapses primary selection with source metadata. | Same root method. | TESTED |
| U05-200 | no-model set-position branch (`:671-673`) | BRANCH | Detached call no-ops. | Cursor behavior test. | TESTED |
| U05-201 | no-model set-position return (`:672`) | EXIT | Skips validation/mutation. | Cursor behavior test. | TESTED |
| U05-202 | invalid-position branch (`:674-676`) | BRANCH | Rejects non-position values. | Typed MoonBit position cannot be structurally invalid. | N-A (typed input removes dynamic validation) |
| U05-203 | invalid-position throw (`:675`) | EXIT | No mutation. | Typed input. | N-A (typed input removes dynamic validation) |
| U05-204 | collapse selection and call view model (`:677-682`) | LIFETIME | Anchor and active end both equal requested position. | Cursor behavior test. | TESTED |
| U05-205 | `_sendRevealRange` (`:685-696`) | MEMBER | Validates/converts then sends source `api`. | Local reveal implementation. | TESTED |
| U05-206 | no-model reveal branch (`:686-688`) | BRANCH | Detached reveal no-ops. | Reveal behavior. | TESTED |
| U05-207 | no-model reveal return (`:687`) | EXIT | Skips validation. | Reveal behavior. | TESTED |
| U05-208 | invalid-range branch (`:689-691`) | BRANCH | Rejects malformed range. | Typed range input. | N-A (typed input removes dynamic validation) |
| U05-209 | invalid-range throw (`:690`) | EXIT | No reveal. | Typed input. | N-A (typed input removes dynamic validation) |
| U05-210 | validate model range then convert to view (`:692-693`) | LIFETIME | Clamps before projection. | Local reveal source-shape tests. | TESTED |
| U05-211 | reveal source constant `api` (`:695`) | CONST | Public calls carry stable source. | Local reveal source test. | TESTED |
| U05-212 | `revealAllCursors` (`:698-703`) | MEMBER | Reveal every cursor. | No root public wrapper. | DEFERRED (multi-cursor denominator lacks source method) |
| U05-213 | no-model all-cursors return (`:699-701`) | EXIT | Detached no-op. | Internal cursor reveal. | PORTED |
| U05-214 | `revealLine` wrapper / `Simple` (`:705-707`) | MEMBER | Default simple vertical reveal. | Root method. | TESTED |
| U05-215 | `revealLineInCenter` / `Center` (`:709-711`) | MEMBER | Center vertical reveal. | Root method. | TESTED |
| U05-216 | `revealLineInCenterIfOutsideViewport` (`:713-715`) | MEMBER | Conditional center reveal. | Root method; the current public caller sweep finds no direct caller. | PORTED |
| U05-217 | `revealLineNearTop` / `NearTop` (`:717-719`) | MEMBER | Near-top reveal. | Root method; the current public caller sweep finds no direct caller. | PORTED |
| U05-218 | line wrappers default `ScrollType.Smooth` (`:705-718`) | CONST | Public reveal methods animate by default. | Reviewed root line reveals deliberately fix `Immediate`; `smooth_scrolling` affects physical input/internal cursor smooth paths only. | DEFERRED (accepted public behavior reduction; no `ScrollType` is exposed) |
| U05-219 | `_revealLine` (`:721-732`) | MEMBER | Builds a one-column range and suppresses horizontal reveal. | Local reveal helper. | TESTED |
| U05-220 | non-number line branch (`:722-724`) | BRANCH | Dynamic API rejects malformed line. | MoonBit `Int` is typed. | N-A (typed input removes validation) |
| U05-221 | non-number line throw (`:723`) | EXIT | No reveal. | Typed input. | N-A (typed input removes validation) |
| U05-222 | line reveal horizontal flag `false` (`:726-731`) | CONST | Line reveal does not move horizontally. | Local reveal test. | TESTED |
| U05-223 | `revealPosition` / `Simple` (`:734-741`) | MEMBER | Simple position reveal with horizontal movement. | Root method. | TESTED |
| U05-224 | `revealPositionInCenter` (`:743-750`) | MEMBER | Center position reveal. | Root method; the current public caller sweep finds no direct caller. | PORTED |
| U05-225 | `revealPositionInCenterIfOutsideViewport` (`:752-759`) | MEMBER | Conditional center position reveal. | Root method. | TESTED |
| U05-226 | `revealPositionNearTop` (`:761-768`) | MEMBER | Near-top position reveal. | Root method; the current public caller sweep finds no direct caller. | PORTED |
| U05-227 | position wrappers horizontal flag `true` (`:734-768`) | CONST | Positions reveal horizontally. | Local reveal tests. | TESTED |
| U05-228 | position wrappers default `Smooth` (`:734-762`) | CONST | Public position reveals animate by default. | Reviewed root position reveals deliberately fix `Immediate`; `smooth_scrolling` affects physical input/internal cursor smooth paths only. | DEFERRED (accepted public behavior reduction; no `ScrollType` is exposed) |
| U05-229 | `_revealPosition` (`:770-781`) | MEMBER | Builds collapsed range. | Local reveal helper. | TESTED |
| U05-230 | invalid-position reveal branch (`:771-773`) | BRANCH | Rejects malformed position. | Typed input. | N-A (typed input removes validation) |
| U05-231 | invalid-position reveal throw (`:772`) | EXIT | No reveal. | Typed input. | N-A (typed input removes validation) |
| U05-232 | `getSelection` (`:783-788`) | MEMBER | Primary selection query. | Same root method. | TESTED |
| U05-233 | no-model selection returns `null` (`:784-786`) | EXIT | Detached sentinel. | Public read API test. | TESTED |
| U05-234 | `getSelections` (`:790-795`) | MEMBER | All selections query. | Same root method. | TESTED |
| U05-235 | no-model selections returns `null` (`:791-793`) | EXIT | Detached sentinel. | Public read API test. | TESTED |
| U05-236 | five `setSelection` overload declarations (`:797-802`) | MEMBER | Structural/class range and selection inputs converge. | One typed MoonBit method. | N-A (MoonBit has no overload family) |
| U05-237 | default selection source `api` (`:802`) | CONST | Stable event origin. | Root default source. | TESTED |
| U05-238 | invalid selection/range branch (`:803-808`) | BRANCH | Rejects values matching neither shape. | Typed `Selection`. | N-A (typed input removes validation) |
| U05-239 | invalid selection/range throw (`:807`) | EXIT | No mutation. | Typed input. | N-A (typed input removes validation) |
| U05-240 | selection-shape branch (`:810-812`) | BRANCH | Preserves anchor and active end. | Root takes selection directly. | TESTED |
| U05-241 | range-shape branch (`:812-821`) | BRANCH | Converts start/end into forward selection. | Caller constructs selection explicitly. | N-A (no range overload) |
| U05-242 | `_setSelectionImpl` (`:824-830`) | MEMBER | Creates canonical selection and sends one cursor. | Root selection path. | TESTED |
| U05-243 | no-model selection return (`:825-827`) | EXIT | Detached mutation no-ops. | Cursor behavior test. | TESTED |
| U05-244 | `revealLines` / `Simple` (`:832-839`) | MEMBER | Simple multi-line reveal. | Root method; the current public caller sweep finds no direct caller. | PORTED |
| U05-245 | `revealLinesInCenter` (`:841-848`) | MEMBER | Center multi-line reveal. | Root method; the current public caller sweep finds no direct caller. | PORTED |
| U05-246 | `revealLinesInCenterIfOutsideViewport` (`:850-857`) | MEMBER | Conditional center multi-line reveal. | Root method; the current public caller sweep finds no direct caller. | PORTED |
| U05-247 | `revealLinesNearTop` (`:859-866`) | MEMBER | Near-top multi-line reveal. | Root method; the current public caller sweep finds no direct caller. | PORTED |
| U05-248 | line-range wrappers default `Smooth` (`:832-860`) | CONST | Animated by default. | Reviewed root line-range reveals deliberately fix `Immediate`; `smooth_scrolling` affects physical input/internal cursor smooth paths only. | DEFERRED (accepted public behavior reduction; no `ScrollType` is exposed) |
| U05-249 | `_revealLines` (`:868-879`) | MEMBER | Builds line-start range, no horizontal reveal. | Local reveal helper. | TESTED |
| U05-250 | invalid line-pair branch (`:869-871`) | BRANCH | Rejects either non-number. | Typed integers. | N-A (typed input removes validation) |
| U05-251 | invalid line-pair throw (`:870`) | EXIT | No reveal. | Typed input. | N-A (typed input removes validation) |
| U05-252 | `revealRange` (`:881-888`) | MEMBER | Simple or centered via explicit boolean; horizontal configurable. | Root reduced method has fixed source choices. | DEFERRED (local signature omits two source parameters) |
| U05-253 | center-boolean branch (`:884`) | BRANCH | Selects `Center` versus `Simple`. | Root separate named methods. | PORTED |
| U05-254 | `revealRangeInCenter` (`:890-897`) | MEMBER | Center range reveal. | Root method; the current public caller sweep finds no direct caller. | PORTED |
| U05-255 | `revealRangeInCenterIfOutsideViewport` (`:899-906`) | MEMBER | Conditional center range reveal. | Root method. | TESTED |
| U05-256 | `revealRangeNearTop` (`:908-915`) | MEMBER | Near-top range reveal. | Root method; the current public caller sweep finds no direct caller. | PORTED |
| U05-257 | `revealRangeNearTopIfOutsideViewport` (`:917-924`) | MEMBER | Conditional near-top reveal. | Root method; the current public caller sweep finds no direct caller. | PORTED |
| U05-258 | `revealRangeAtTop` (`:926-933`) | MEMBER | Top-aligned range reveal. | Root method; the current public caller sweep finds no direct caller. | PORTED |
| U05-259 | range wrappers default `Smooth` (`:881-927`) | CONST | Animated by default. | Reviewed root range reveals deliberately fix `Immediate`; `smooth_scrolling` affects physical input/internal cursor smooth paths only. | DEFERRED (accepted public behavior reduction; no `ScrollType` is exposed) |
| U05-260 | `_revealRange` (`:935-946`) | MEMBER | Validates/lifts and delegates. | Local reveal helper. | TESTED |
| U05-261 | invalid reveal-range branch (`:936-938`) | BRANCH | Rejects malformed range. | Typed input. | N-A (typed input removes validation) |
| U05-262 | invalid reveal-range throw (`:937`) | EXIT | No reveal. | Typed input. | N-A (typed input removes validation) |
| U05-263 | `setSelections` defaults source `api`, reason `NotSet` (`:948`) | MEMBER | Replaces all cursors with metadata. | Same root method. | TESTED |
| U05-264 | no-model set-selections branch (`:949-951`) | BRANCH | Detached call no-ops. | Cursor transition test. | TESTED |
| U05-265 | no-model set-selections return (`:950`) | EXIT | Skips empty/shape validation. | Cursor transition test. | TESTED |
| U05-266 | absent-or-empty ranges branch (`:952-954`) | BRANCH | Dynamic API rejects no cursors. | Root currently treats empty as an event-free no-op. | DEFERRED (local behavior deviates from source throw) |
| U05-267 | absent-or-empty throw (`:953`) | EXIT | No mutation. | Local empty no-op test. | DEFERRED (decide and document the typed API policy) |
| U05-268 | per-selection validation branch (`:955-959`) | BRANCH | Rejects first malformed selection. | Typed array elements. | N-A (typed input removes validation) |
| U05-269 | malformed-selection throw (`:957`) | EXIT | Stops before mutation. | Typed input. | N-A (typed input removes validation) |
| U05-270 | commit selections with source/reason (`:960`) | LIFETIME | Forwards metadata unchanged. | Exact cursor transition test. | TESTED |
| U05-271 | `getContentWidth` (`:963-968`) | MEMBER | Content extent getter. | Same root method. | TESTED |
| U05-272 | no-model content-width `-1` (`:964-966`) | EXIT | Detached sentinel. | Public read API test. | TESTED |
| U05-273 | `getScrollWidth` (`:970-975`) | MEMBER | Scroll width getter. | Same root method. | TESTED |
| U05-274 | no-model scroll-width `-1` (`:971-973`) | EXIT | Detached sentinel. | Public read API test. | TESTED |
| U05-275 | `getScrollLeft` (`:976-981`) | MEMBER | Horizontal offset getter. | Same root method. | TESTED |
| U05-276 | no-model scroll-left `-1` (`:977-979`) | EXIT | Detached sentinel. | Public read API test. | TESTED |
| U05-277 | `getContentHeight` (`:983-988`) | MEMBER | Content height getter. | Same root method. | TESTED |
| U05-278 | no-model content-height `-1` (`:984-986`) | EXIT | Detached sentinel. | Public read API test. | TESTED |
| U05-279 | `getScrollHeight` (`:990-995`) | MEMBER | Scroll height getter. | Same root method. | TESTED |
| U05-280 | no-model scroll-height `-1` (`:991-993`) | EXIT | Detached sentinel. | Public read API test. | TESTED |
| U05-281 | `getScrollTop` (`:996-1001`) | MEMBER | Vertical offset getter. | Same root method. | TESTED |
| U05-282 | no-model scroll-top `-1` (`:997-999`) | EXIT | Detached sentinel. | Public read API test. | TESTED |
| U05-283 | `setScrollLeft`, default `Immediate` (`:1003-1013`) | MEMBER | Horizontal update. | Reviewed root setter fixes `Immediate` and exposes no public mode. | TESTED |
| U05-284 | no-model scroll-left branch/return (`:1004-1006`) | EXIT | Detached update no-ops. | Public read API test. | TESTED |
| U05-285 | non-number scroll-left branch (`:1007-1009`) | BRANCH | Dynamic validation. | Typed `Double`. | N-A (typed input removes validation) |
| U05-286 | non-number scroll-left throw (`:1008`) | EXIT | No update. | Typed input. | N-A (typed input removes validation) |
| U05-287 | `setScrollTop`, default `Immediate` (`:1014-1024`) | MEMBER | Vertical update. | Reviewed root setter fixes `Immediate` and exposes no public mode. | TESTED |
| U05-288 | no-model scroll-top branch/return (`:1015-1017`) | EXIT | Detached update no-ops. | Public read API test. | TESTED |
| U05-289 | non-number scroll-top branch (`:1018-1020`) | BRANCH | Dynamic validation. | Typed `Double`. | N-A (typed input removes validation) |
| U05-290 | non-number scroll-top throw (`:1019`) | EXIT | No update. | Typed input. | N-A (typed input removes validation) |
| U05-291 | `setScrollPosition`, default `Immediate` (`:1025-1030`) | MEMBER | Partial two-axis update. | Reviewed root optional-argument setter fixes `Immediate` and exposes no public mode. | TESTED |
| U05-292 | no-model scroll-position branch/return (`:1026-1028`) | EXIT | Detached update no-ops. | Public read API test. | TESTED |
| U05-293 | `hasPendingScrollAnimation` (`:1031-1036`) | MEMBER | Animation state query. | No root public method. | N-A (implementation state excluded) |
| U05-294 | no-model pending-animation returns `false` (`:1032-1034`) | EXIT | Detached sentinel. | Internal. | N-A (method excluded) |
| U05-295 | `saveViewState` (`:1038-1050`) | MEMBER | Cursor/view/contribution snapshot. | Reduced `ViewerViewState`. | TESTED |
| U05-296 | no-model save returns `null` (`:1039-1041`) | EXIT | Detached sentinel. | Public read API test. | TESTED |
| U05-297 | save contributions first (`:1042`) | LIFETIME | Contribution slots snapshot before cursor/view. | No local contribution view state. | DEFERRED (contribution state stays internal and is currently absent) |
| U05-298 | save cursor then view (`:1043-1044`) | LIFETIME | Source order is cursor before viewport. | Local state snapshot. | TESTED |
| U05-299 | return three-field state (`:1045-1049`) | LIFETIME | Complete source envelope. | Local reduced envelope. | DEFERRED (review the intentional shape reduction) |
| U05-300 | `restoreViewState` (`:1052-1072`) | MEMBER | Validated cursor/contribution/view restore. | Root reduced restore. | TESTED |
| U05-301 | no-model-or-real-view branch (`:1053-1055`) | BRANCH | Cannot restore detached/headless view. | Local no-model guard; headless tests exist. | TESTED |
| U05-302 | no-model-or-real-view return (`:1054`) | EXIT | No partial restore. | Restore no-op test. | TESTED |
| U05-303 | valid state requires cursor and view (`:1056-1057`) | BRANCH | Missing either makes whole restore a no-op. | Typed reduced state. | PORTED |
| U05-304 | cursor-array branch (`:1059-1063`) | BRANCH | Current state format. | Local single selection. | DEFERRED (multi-cursor state is reduced) |
| U05-305 | nonempty cursor-array branch (`:1060-1062`) | BRANCH | Empty array does not restore cursor. | Local optional selection. | PORTED |
| U05-306 | legacy single-cursor branch (`:1063-1066`) | BRANCH | Wraps old state into array. | No compatibility requirement. | N-A (breaking API omits legacy serialized shape) |
| U05-307 | missing contributions fallback `{}` (`:1068`) | BRANCH | Every live contribution gets an object. | No local contribution view state. | DEFERRED (internal contribution state absent) |
| U05-308 | reduce view state before view restore (`:1069-1070`) | LIFETIME | Model/view validates snapshot before DOM application. | Local restore stabilization test. | TESTED |
| U05-309 | `handleInitialized` (`:1074-1076`) | MEMBER | Marks visible lines stabilized. | Internal viewer initialization. | N-A (host lifecycle excluded) |
| U05-310 | `onVisible` (`:1078-1080`) | MEMBER | Refreshes view focus state. | Internal browser host. | N-A (host lifecycle excluded) |
| U05-311 | `onHide` (`:1082-1084`) | MEMBER | Refreshes view focus state. | Internal browser host. | N-A (host lifecycle excluded) |
| U05-312 | `getContribution<T>` (`:1086-1088`) | MEMBER | Forces/returns contribution by string id. | Root public lookup. | DEFERRED (remove from external facade) |
| U05-313 | `getLayoutInfo` (`:1472-1476`) | MEMBER | Return computed layout option. | Same root method. | TESTED |
| U05-314 | `createOverviewRuler` (`:1478-1483`) | MEMBER | Create view-owned overview ruler. | No root method. | N-A (overview-ruler implementation excluded) |
| U05-315 | no-real-view overview return `null` (`:1479-1481`) | EXIT | Detached/headless sentinel. | No local public path. | N-A (method excluded) |
| U05-316 | `getContainerDomNode` (`:1485-1487`) | MEMBER | Return construction host DOM unconditionally. | Reviewed target retains the original browser host and returns it before and after disposal; private headless construction must not call this method. | DEFERRED (implement the reviewed browser-host invariant) |
| U05-317 | `getDomNode` (`:1489-1494`) | MEMBER | Return active view DOM. | Same root method. | TESTED |
| U05-318 | no-real-view DOM return `null` (`:1490-1492`) | EXIT | Detached/headless sentinel. | Public read API. | TESTED |
| U05-319 | `delegateVerticalScrollbarPointerDown` (`:1496-1501`) | MEMBER | Forward raw pointer into view scrollbar. | Internal browser host. | N-A (raw DOM forwarding excluded) |
| U05-320 | no-real-view scrollbar return (`:1497-1499`) | EXIT | Detached/headless no-op. | Internal. | N-A (method excluded) |
| U05-321 | `delegateScrollFromMouseWheelEvent` (`:1503-1508`) | MEMBER | Forward raw wheel into view. | Internal browser host. | N-A (raw DOM forwarding excluded) |
| U05-322 | no-real-view wheel return (`:1504-1506`) | EXIT | Detached/headless no-op. | Internal. | N-A (method excluded) |
| U05-323 | `layout`, default `postponeRendering=false` (`:1510-1515`) | MEMBER | Observe container before optional immediate render. | Root `layout()`. | TESTED |
| U05-324 | not-postponed branch renders (`:1512-1514`) | BRANCH | Default synchronous render. | Local root has fixed render behavior. | PORTED |
| U05-325 | postponed branch skips render (`:1512`) | BRANCH | Caller can batch render. | Root has no parameter. | N-A (reduced facade omits postpone mode) |
| U05-326 | `focus` (`:1517-1522`) | MEMBER | Focus real view. | Same root method. | TESTED |
| U05-327 | no-real-view focus return (`:1518-1520`) | EXIT | Detached/headless no-op. | Root behavior. | TESTED |
| U05-328 | `hasTextFocus` (`:1524-1529`) | MEMBER | Query real view focus. | Same root method. | TESTED |
| U05-329 | no-real-view text-focus `false` (`:1525-1527`) | EXIT | Detached/headless sentinel. | Root behavior. | TESTED |
| U05-330 | `hasWidgetFocus` (`:1531-1536`) | MEMBER | Query whole-widget focus. | Same root method; the current public caller sweep finds no direct caller. | PORTED |
| U05-331 | no-real-view widget-focus `false` (`:1532-1534`) | EXIT | Detached/headless sentinel. | Root behavior. | TESTED |
| U05-332 | `addContentWidget` (`:1538-1553`) | MEMBER | Snapshot position, store by id, add to live view. | No current root content-widget implementation or caller; external hosts remain root/common-only. | DEFERRED (the reviewed target does not add the full content-widget API) |
| U05-333 | duplicate content-widget id branch/warning (`:1544-1546`) | BRANCH | Last widget overwrites with diagnostic. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U05-334 | store content widget before view add (`:1548-1551`) | LIFETIME | Widget survives detached state/model swaps. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U05-335 | live-real-view content add branch (`:1550-1552`) | BRANCH | DOM view receives only when present. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U05-336 | `layoutContentWidget` (`:1555-1564`) | MEMBER | Re-read position and optionally relayout. | No current root content-widget implementation or caller. | DEFERRED (the reviewed target does not add the full content-widget API) |
| U05-337 | known content-widget id branch (`:1557-1563`) | BRANCH | Unknown id is silent no-op. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U05-338 | live-real-view content layout branch (`:1560-1562`) | BRANCH | Stored position updates even while detached. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U05-339 | `removeContentWidget` (`:1566-1575`) | MEMBER | Delete owner then remove from live view. | No current root content-widget implementation or caller. | DEFERRED (the reviewed target does not add the full content-widget API) |
| U05-340 | known content-widget removal branch (`:1568-1574`) | BRANCH | Unknown id no-ops. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U05-341 | delete content owner before view removal (`:1569-1572`) | LIFETIME | Callback cannot rediscover stored widget during view removal. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U05-342 | `addOverlayWidget` (`:1577-1591`) | MEMBER | Snapshot/store/add overlay. | Reviewed root add accepts the opaque handle produced by `overlay_widget(id, node)`; the handle is self-positioned. | DEFERRED (replace the raw id/node pair with the reviewed handle) |
| U05-343 | duplicate overlay id branch/warning (`:1583-1585`) | BRANCH | Last widget overwrites with diagnostic. | Local id-keyed map already overwrites; the reduced handle keeps immutable id identity. | PORTED |
| U05-344 | store overlay before live-view add (`:1587-1589`) | LIFETIME | Overlay survives detach/model swap. | Local overlay host preserves registration; the reviewed target stores the opaque handle. | TESTED |
| U05-345 | live-real-view overlay add branch (`:1588-1590`) | BRANCH | View receives only when present. | Local overlay host preserves this branch for the opaque handle. | TESTED |
| U05-346 | `layoutOverlayWidget` (`:1593-1602`) | MEMBER | Re-read position and relayout known widget. | No current root implementation or caller; the reviewed handle fixes position to null/self-positioned and external hosts remain root/common-only. | DEFERRED (the reviewed target adds no explicit overlay layout operation) |
| U05-347 | known overlay id branch (`:1595-1601`) | BRANCH | Unknown id is silent no-op. | This branch belongs only to the omitted explicit layout operation. | DEFERRED (no current root implementation/caller; external hosts remain root/common-only) |
| U05-348 | live-real-view overlay layout branch (`:1598-1600`) | BRANCH | Stored position updates while detached. | This branch belongs only to the omitted explicit layout operation. | DEFERRED (no current root implementation/caller; external hosts remain root/common-only) |
| U05-349 | `removeOverlayWidget` (`:1604-1613`) | MEMBER | Delete owner then remove live widget. | Reviewed root remove accepts the same opaque `OverlayWidget` handle instead of an id. | DEFERRED (align removal with the reviewed immutable handle) |
| U05-350 | known overlay removal branch (`:1606-1612`) | BRANCH | Unknown id no-ops. | Local id-keyed map preserves this behavior through the handle's immutable id. | TESTED |
| U05-351 | delete overlay owner before live-view removal (`:1607-1610`) | LIFETIME | Owner map updates first. | Local overlay host preserves this order for the opaque handle. | TESTED |
| U05-352 | `addGlyphMarginWidget` (`:1615-1630`) | MEMBER | Snapshot/store/add glyph widget. | No root API. | N-A (glyph widgets excluded) |
| U05-353 | duplicate glyph id branch/warning (`:1621-1623`) | BRANCH | Last writer wins. | No root API. | N-A (glyph widgets excluded) |
| U05-354 | live-real-view glyph add branch (`:1627-1629`) | BRANCH | View receives only when present. | No root API. | N-A (glyph widgets excluded) |
| U05-355 | `layoutGlyphMarginWidget` (`:1632-1641`) | MEMBER | Re-read and relayout known glyph. | No root API. | N-A (glyph widgets excluded) |
| U05-356 | known glyph id branch (`:1634-1640`) | BRANCH | Unknown id no-ops. | No root API. | N-A (glyph widgets excluded) |
| U05-357 | live-real-view glyph layout branch (`:1637-1639`) | BRANCH | View receives only when present. | No root API. | N-A (glyph widgets excluded) |
| U05-358 | `removeGlyphMarginWidget` (`:1643-1652`) | MEMBER | Delete owner then remove from view. | No root API. | N-A (glyph widgets excluded) |
| U05-359 | known glyph removal branch (`:1645-1651`) | BRANCH | Unknown id no-ops. | No root API. | N-A (glyph widgets excluded) |
| U05-360 | live-real-view glyph removal branch (`:1648-1650`) | BRANCH | View receives only when present. | No root API. | N-A (glyph widgets excluded) |
| U05-361 | `changeViewZones` (`:1654-1659`) | MEMBER | Execute a view-scoped mutation transaction. | Same root method. | DEFERRED (public accessor owner pending) |
| U05-362 | no-real-view zone branch/return (`:1655-1657`) | EXIT | Detached/headless callback is skipped. | Exact view-event-source test. | TESTED |
| U05-363 | `getTargetAtClientPoint` (`:1661-1666`) | MEMBER | Hit-test live view. | Internal mouse host. | N-A (mouse-target API excluded) |
| U05-364 | no-real-view target `null` (`:1662-1664`) | EXIT | Detached/headless sentinel. | Internal. | N-A (method excluded) |
| U05-365 | `getScrolledVisiblePosition` (`:1668-1685`) | MEMBER | Return scroll-relative top/left/height. | Same root method. | TESTED |
| U05-366 | no-real-view scrolled-position `null` (`:1669-1671`) | EXIT | Detached/headless sentinel. | Public read API. | TESTED |
| U05-367 | validate position before geometry (`:1673`) | LIFETIME | Clamps model input. | Local geometry path. | TESTED |
| U05-368 | left includes glyph/line-number/decoration widths (`:1675-1679`) | LIFETIME | Horizontal coordinate is content-to-container transformed. | Local layout geometry tests. | TESTED |
| U05-369 | `getOffsetForColumn` (`:1687-1692`) | MEMBER | Rendered horizontal column offset. | Same root method. | TESTED |
| U05-370 | no-real-view offset `-1` (`:1688-1690`) | EXIT | Detached/headless sentinel. | Public read API. | TESTED |
| U05-371 | `getWidthOfLine` (`:1694-1699`) | MEMBER | Rendered line width. | Same root method. | TESTED |
| U05-372 | no-real-view width `-1` (`:1695-1697`) | EXIT | Detached/headless sentinel. | Public read API. | TESTED |
| U05-373 | `resetLineWidthCaches` (`:1701-1706`) | MEMBER | Clear view width caches. | Internal view host. | N-A (implementation method excluded) |
| U05-374 | no-real-view reset return (`:1702-1704`) | EXIT | Detached/headless no-op. | Internal. | N-A (method excluded) |
| U05-375 | `render`, default `forceRedraw=false` (`:1708-1715`) | MEMBER | Synchronous view render inside batched view-model events. | Internal view host. | N-A (implementation method excluded) |
| U05-376 | no-real-view render return (`:1709-1711`) | EXIT | Detached/headless no-op. | Internal. | N-A (method excluded) |
| U05-377 | synchronous render flags `true, forceRedraw` (`:1712-1714`) | CONST | Immediate render mode. | Internal local render. | N-A (method excluded) |
| U05-378 | `renderAsync`, default `forceRedraw=false` (`:1717-1724`) | MEMBER | Deferred render inside batched events. | Internal view host. | N-A (implementation method excluded) |
| U05-379 | no-real-view async-render return (`:1718-1720`) | EXIT | Detached/headless no-op. | Internal. | N-A (method excluded) |
| U05-380 | async render flags `false, forceRedraw` (`:1721-1723`) | CONST | Next-frame render mode. | Internal local render. | N-A (method excluded) |
| U05-381 | `setAriaOptions` (`:1726-1731`) | MEMBER | Forward accessibility DOM state. | No root method. | N-A (accessibility excluded) |
| U05-382 | no-real-view aria return (`:1727-1729`) | EXIT | Detached/headless no-op. | No root path. | N-A (accessibility excluded) |
| U05-383 | `applyFontInfo` (`:1733-1735`) | MEMBER | Apply current computed font to arbitrary DOM. | No root method. | N-A (DOM styling helper excluded) |
| U05-384 | `_attachModel` (`:1750-1921`) | MEMBER | Constructs model/view/event ownership. | Root attach-model path. | TESTED |
| U05-385 | null-model branch (`:1751-1754`) | BRANCH | Stores null and stops. | Root detach path. | TESTED |
| U05-386 | null-model return (`:1753`) | EXIT | No listeners/view/DOM. | Root detach path. | TESTED |
| U05-387 | initialize listener owner array (`:1756`) | LIFETIME | All model/view subscriptions share `ModelData` lifetime. | Root model-scoped disposables. | TESTED |
| U05-388 | set host `data-mode-id` (`:1758`) | DOM | Language id is reflected before view construction. | Local host language attribute. | PORTED |
| U05-389 | configure long-line and line-count facts (`:1759-1760`) | LIFETIME | Model shape enters config before view model. | Local view-model option setup. | TESTED |
| U05-390 | call `model.onBeforeAttached` (`:1762`) | LIFETIME | Model attach token precedes view-model construction. | Local model registration. | TESTED |
| U05-391 | construct `ViewModel` with DOM/monospace factories/services (`:1764-1784`) | LIFETIME | Closed model-to-view owner. | Local `ViewModel` construction. | TESTED |
| U05-392 | batch callback begins update before callback (`:1775-1778`) | LIFETIME | Outgoing facts are transaction-bracketed. | Local event dispatcher batching. | TESTED |
| U05-393 | batch callback finally ends update (`:1779-1781`) | LIFETIME | Exceptions cannot leave transaction open. | Local dispatcher cleanup. | TESTED |
| U05-394 | model-dispose listener calls `setModel(null)` (`:1786-1787`) | LIFETIME | External model destruction safely detaches. | Model disposal tests. | TESTED |
| U05-395 | own view-model outgoing-event listener (`:1789-1887`) | LIFETIME | One switch projects internal facts to public emitters. | Root view-event source. | TESTED |
| U05-396 | `ContentSizeChanged` case (`:1791-1793`) | BRANCH | Forwards same fact. | Internal content-size event. | TESTED |
| U05-397 | `FocusChanged` case (`:1794-1796`) | BRANCH | Updates boolean text-focus owner. | Root focus state. | TESTED |
| U05-398 | `WidgetFocusChanged` case (`:1797-1799`) | BRANCH | Updates boolean widget-focus owner. | Root widget focus. | TESTED |
| U05-399 | `ScrollChanged` case (`:1800-1802`) | BRANCH | Forwards complete scroll fact. | Exact four-value/four-flag test. | TESTED |
| U05-400 | `ViewZonesChanged` case (`:1803-1805`) | BRANCH | Fires semantic void event. | View-zone event tests. | TESTED |
| U05-401 | `HiddenAreasChanged` case (`:1806-1808`) | BRANCH | Fires internal hidden event. | Internal folding event. | N-A (not public facade) |
| U05-402 | `ReadOnlyEditAttempt` case (`:1809-1811`) | BRANCH | Fires failed-edit event. | No public edit surface. | N-A (editing excluded) |
| U05-403 | `CursorStateChanged` case (`:1812-1860`) | BRANCH | Projects one internal cursor fact into position then selection events. | Root cursor transition pipeline. | TESTED |
| U05-404 | reached-max-cursor branch (`:1813-1833`) | BRANCH | Prompts with configured limit/actions. | No notification service/public max-cursor warning. | N-A (notification/commands excluded) |
| U05-405 | position array preserves selection order (`:1835-1838`) | LIFETIME | Primary is index zero; secondaries retain order. | Cursor transition tests. | TESTED |
| U05-406 | position event primary field (`:1841`) | MEMBER | `positions[0]`. | Root payload. | TESTED |
| U05-407 | position event secondary field (`:1842`) | MEMBER | `positions.slice(1)`. | Root payload. | TESTED |
| U05-408 | position event reason field (`:1843`) | MEMBER | Forward unchanged. | Root adapter currently copies enum. | DEFERRED (delete adapter after canonical type move) |
| U05-409 | position event source field (`:1844`) | MEMBER | Forward unchanged. | Root payload. | TESTED |
| U05-410 | fire position before selection (`:1846-1857`) | LIFETIME | Public event order is fixed. | Exact cursor order test. | TESTED |
| U05-411 | selection event primary field (`:1849`) | MEMBER | `selections[0]`. | Root payload. | TESTED |
| U05-412 | selection event secondary field (`:1850`) | MEMBER | `selections.slice(1)`. | Root payload. | TESTED |
| U05-413 | selection event model version (`:1851`) | MEMBER | Forward new version. | Root payload. | TESTED |
| U05-414 | selection event nullable old selections (`:1852`) | MEMBER | Preserve null versus array. | Root `CursorSelectionChangedEvent.old_selections : Array[Selection]?` preserves the distinction; cursor event tests exercise `None` and populated history. | TESTED |
| U05-415 | selection event old model version (`:1853`) | MEMBER | Forward previous version. | Root payload. | TESTED |
| U05-416 | selection event source (`:1854`) | MEMBER | Forward unchanged. | Root payload. | TESTED |
| U05-417 | selection event reason (`:1855`) | MEMBER | Forward same canonical enum. | Root adapter currently copies enum. | DEFERRED (delete adapter after canonical type move) |
| U05-418 | `ModelDecorationsChanged` case (`:1861-1863`) | BRANCH | Forwards internal decoration event. | Internal only. | N-A (decoration event excluded) |
| U05-419 | `ModelLanguageChanged` case updates DOM then fires (`:1864-1867`) | BRANCH | DOM language attribute precedes public event. | Internal local language path. | DEFERRED (public event disposition unresolved) |
| U05-420 | `ModelLanguageConfigurationChanged` case (`:1868-1870`) | BRANCH | Forwards internal event. | Internal only. | N-A (event excluded) |
| U05-421 | `ModelContentChanged` case (`:1871-1873`) | BRANCH | Forwards after view model update. | Two-loop content event order test. | TESTED |
| U05-422 | `ModelOptionsChanged` case (`:1874-1876`) | BRANCH | Forwards model options. | Internal model event. | DEFERRED (public event disposition unresolved) |
| U05-423 | `ModelTokensChanged` case (`:1877-1879`) | BRANCH | Forwards token event. | Internal renderer. | N-A (event excluded) |
| U05-424 | `ModelLineHeightChanged` case (`:1880-1882`) | BRANCH | Forwards line-height event. | Internal renderer. | N-A (event excluded) |
| U05-425 | `ModelFontChangedEvent` case (`:1883-1885`) | BRANCH | Forwards font event. | Internal renderer. | N-A (event excluded) |
| U05-426 | create view and capture `hasRealView` (`:1889`) | LIFETIME | View exists before model data publication. | Root create-view path. | TESTED |
| U05-427 | real-view branch (`:1890-1918`) | BRANCH | Owns DOM/widgets/render/clipboard only for real view. | Browser versus headless split. | TESTED |
| U05-428 | append view DOM to host (`:1891`) | DOM | Active view becomes child before widgets/render. | Root browser host. | TESTED |
| U05-429 | replay stored content widgets (`:1893-1897`) | LIFETIME | Pre-attach content widgets enter new view. | No current root content-widget implementation or caller; external hosts remain root/common-only. | DEFERRED (the reviewed target does not add the full content-widget API) |
| U05-430 | replay stored overlay widgets (`:1899-1903`) | LIFETIME | Pre-attach overlays enter new view. | Local overlay host replays registrations; the reviewed target replays opaque self-positioned handles. | TESTED |
| U05-431 | replay stored glyph widgets (`:1905-1909`) | LIFETIME | Pre-attach glyphs enter new view. | No root API. | N-A (glyph widgets excluded) |
| U05-432 | initial render flags `false, true` (`:1911`) | CONST | Deferred-mode call with forced redraw. | Local initial render. | TESTED |
| U05-433 | set view DOM `data-uri` (`:1912`) | DOM | Model resource reflected after initial render. | Local browser host. | PORTED |
| U05-434 | own view clipboard forwarding listeners (`:1914-1917`) | LIFETIME | Copy/cut/paste events follow view lifetime. | Internal clipboard host. | N-A (clipboard/editing excluded) |
| U05-435 | publish `ModelData` last (`:1920`) | LIFETIME | All listeners/DOM/view state are complete before non-null owner. | Root attach ordering. | TESTED |
| U05-436 | `_postDetachModelCleanup` (`:2008-2010`) | MEMBER | Removes outgoing owner decorations after public model event. | Root exact order test. | TESTED |
| U05-437 | optional detached-model cleanup (`:2009`) | BRANCH | Null detach is safe no-op. | Root cleanup guard. | TESTED |
| U05-438 | `_detachModel` (`:2012-2032`) | MEMBER | Ordered model/view/DOM teardown. | Root detach path. | TESTED |
| U05-439 | dispose/clear contribution attach handle first (`:2013-2014`) | LIFETIME | No model-scoped contribution callback survives detach. | Central contribution tests. | TESTED |
| U05-440 | missing-model branch (`:2015-2017`) | BRANCH | Detach is idempotent. | Root behavior. | TESTED |
| U05-441 | missing-model return `null` (`:2016`) | EXIT | Skips DOM/config teardown. | Root behavior. | TESTED |
| U05-442 | capture model and conditional view DOM before dispose (`:2018-2019`) | LIFETIME | References survive `ModelData.dispose`. | Root detach ordering. | PORTED |
| U05-443 | dispose model data then set null (`:2021-2022`) | LIFETIME | Owner is unavailable before DOM cleanup. | Root detach ordering. | TESTED |
| U05-444 | remove host `data-mode-id` (`:2024`) | DOM | Detached host no longer advertises language. | Local browser host. | PORTED |
| U05-445 | owned-view-DOM containment branch/remove (`:2025-2027`) | BRANCH | Remove only if still a child. | Root DOM teardown. | TESTED |
| U05-446 | owned-banner containment branch/remove (`:2028-2030`) | BRANCH | Remove banner only if still a child. | No local banner. | N-A (banner excluded) |
| U05-447 | `hasModel` (`:2050-2052`) | MEMBER | Runtime type guard from non-null `_modelData`. | The public disposition removes the root bool query; private state and test observability replace callers. | N-A (implementation narrowing does not cross the external facade) |
| U05-448 | `_getVerticalOffsetAfterPosition` (`:584-591`) | MEMBER | Validate, project, then query offset after the view line. | Local coordinates converter/layout. | TESTED |
| U05-449 | `getTopForLineNumber` default `includeViewZones=false` (`:593`) | CONST | Ordinary line top excludes zone height at the anchor. | Local default. | TESTED |
| U05-450 | `_getVerticalOffsetForPosition` default `includeViewZones=false` (`:607`) | CONST | Internal position offset excludes zones unless requested. | Local helper default. | TESTED |
| U05-451 | `getBottomForLineNumber` default `includeViewZones=false` (`:616`) | CONST | Ordinary line bottom excludes zones unless requested. | Local default. | TESTED |
| U05-452 | `getValue` options default `null` (`:472`) | CONST | Detached option object means model-defined EOL and no BOM preservation. | Root reduced getter. | TESTED |
| U05-453 | `setModel` argument default `null` (`:506`) | CONST | Omitted model detaches. | Root requires explicit optional value. | N-A (typed MoonBit call has no omitted positional model) |
| U05-454 | `setPosition` source default `api` (`:670`) | CONST | Public cursor event origin. | Root default source. | TESTED |
| U05-455 | `revealRange` default `revealVerticalInCenter=false` (`:881`) | CONST | Base range reveal uses `Simple`. | Root named simple method. | TESTED |
| U05-456 | `revealRange` default `revealHorizontal=true` (`:881`) | CONST | Base range reveal adjusts both axes. | Root reveal behavior. | TESTED |
| U05-457 | `setSelections` source default `api` (`:948`) | CONST | Public cursor origin. | Root default source. | TESTED |
| U05-458 | `setSelections` reason default `NotSet` (`:948`) | CONST | Default cursor reason. | Root default reason. | TESTED |
| U05-459 | `setScrollLeft` default `Immediate` (`:1003`) | CONST | Setter is non-animated absent override. | Reviewed root setter is always immediate. | TESTED |
| U05-460 | `setScrollTop` default `Immediate` (`:1014`) | CONST | Setter is non-animated absent override. | Reviewed root setter is always immediate. | TESTED |
| U05-461 | `setScrollPosition` default `Immediate` (`:1025`) | CONST | Two-axis setter is non-animated absent override. | Reviewed root setter is always immediate. | TESTED |
| U05-462 | `layout` default `postponeRendering=false` (`:1510`) | CONST | Layout renders immediately by default. | Root fixed behavior. | PORTED |
| U05-463 | `render` default `forceRedraw=false` (`:1708`) | CONST | Cached render is allowed by default. | Internal renderer. | N-A (method excluded) |
| U05-464 | `renderAsync` default `forceRedraw=false` (`:1717`) | CONST | Cached deferred render is allowed by default. | Internal renderer. | N-A (method excluded) |
| U05-465 | first-column sentinel `1` for line top (`:597`) | CONST | Line geometry samples the first model column. | Local geometry. | TESTED |
| U05-466 | line reveal first-column sentinel `1` (`:727`) | CONST | Collapsed line range anchors at column one. | Local reveal. | TESTED |
| U05-467 | multi-line reveal column sentinels `1` (`:874`) | CONST | Range spans line starts without horizontal reveal. | Local reveal. | TESTED |
| U05-468 | no-model optional-chain branch in `setHiddenAreas` (`:638`) | BRANCH | Detached update silently no-ops. | Hidden-area API behavior. | TESTED |
| U05-469 | no-view-model optional-chain branch in `handleInitialized` (`:1075`) | BRANCH | Detached initialization silently no-ops. | Internal host lifecycle. | N-A (method excluded) |
| U05-470 | no-model optional-chain branch in `onVisible` (`:1079`) | BRANCH | Detached visibility notification silently no-ops. | Internal host lifecycle. | N-A (method excluded) |
| U05-471 | no-model optional-chain branch in `onHide` (`:1083`) | BRANCH | Detached hide notification silently no-ops. | Internal host lifecycle. | N-A (method excluded) |
| U05-472 | no-model optional-chain branch in `writeScreenReaderContent` (`:411`) | BRANCH | Detached accessibility write silently no-ops. | No root method. | N-A (accessibility excluded) |
| U05-473 | default `preserveBOM=false` (`:477`) | CONST | Missing/false option does not retain BOM. | Root reduced getter. | N-A (BOM policy omitted) |

### U06 — complete `editor.api.ts` standalone facade

| Row | Source atom | Kind | Public-boundary relevance | Local mapping / evidence | Status |
|---|---|---|---|---|---|
| U06-001 | standalone `wrappingIndent` default becomes `None` (`:13-14`) | CONST | Monaco differs from VS Code's `Same`. | Local default currently follows its own Viewer snapshot. | DEFERRED (choose/document Viewer default explicitly) |
| U06-002 | standalone `glyphMargin` default becomes `false` (`:15`) | CONST | Monaco trims workbench gutter by default. | No public glyph-margin option. | N-A (glyph-margin cluster excluded) |
| U06-003 | standalone `autoIndent` default becomes `Advanced` (`:16`) | CONST | Editing policy default. | No public edit option. | N-A (editing cluster excluded) |
| U06-004 | standalone overview-ruler lanes default `2` (`:17`) | CONST | Monaco overview-ruler default. | No public overview-ruler option. | N-A (overview-ruler cluster excluded) |
| U06-005 | formatter selector chooses `formatter[0]` (`:19-21`) | BRANCH | Standalone resolves conflicts deterministically. | No formatting/editing API. | N-A (formatting cluster excluded) |
| U06-006 | create base API (`:23`) | LIFETIME | Common public values exist before editor/languages facades. | Root package directly exports its facade. | PORTED |
| U06-007 | attach editor API (`:24`) | LIFETIME | `api.editor` is the standalone editor namespace. | Root `viewer` facade. | DEFERRED (generated root boundary must be reviewed as a coherent namespace/package) |
| U06-008 | attach languages API (`:25`) | LIFETIME | `api.languages` is a sibling namespace. | Language service leaks through `ViewerServices`. | DEFERRED (language capability must be typed and opaque) |
| U06-009 | export `CancellationTokenSource` (`:26`) | MEMBER | Base API export. | Owned by base/common package, not viewer root. | N-A (unrelated standalone export) |
| U06-010 | export `Emitter` (`:27`) | MEMBER | Base API export. | Base/common disposable/event APIs. | N-A (unrelated standalone export) |
| U06-011 | export `KeyCode` (`:28`) | MEMBER | Input enum export. | Internal keybindings. | N-A (input/commands excluded) |
| U06-012 | export `KeyMod` (`:29`) | MEMBER | Modifier export. | Internal keybindings. | N-A (input/commands excluded) |
| U06-013 | export `Position` (`:30`) | MEMBER | Core public value. | Base/common public type. | PORTED |
| U06-014 | export `Range` (`:31`) | MEMBER | Core public value. | Base/common public type. | PORTED |
| U06-015 | export `Selection` (`:32`) | MEMBER | Core public value. | Common cursor/core public type. | PORTED |
| U06-016 | export `SelectionDirection` (`:33`) | MEMBER | Core direction enum. | Encoded by local selection type. | PORTED |
| U06-017 | export `MarkerSeverity` (`:34`) | MEMBER | Marker public enum. | Marker implementation currently leaks through services. | DEFERRED (capability contract may use a canonical marker value type) |
| U06-018 | export `MarkerTag` (`:35`) | MEMBER | Marker public enum. | Marker implementation currently leaks through services. | DEFERRED (capability contract may use a canonical marker value type) |
| U06-019 | export `Uri` (`:36`) | MEMBER | Core resource value. | Base URI type. | PORTED |
| U06-020 | export `Token` (`:37`) | MEMBER | Token value. | Token renderer internal. | N-A (unrelated standalone export) |
| U06-021 | export `editor` namespace (`:38`) | MEMBER | Public editor construction/operation boundary. | Root viewer package. | DEFERRED (target generated facade must contain only reviewed editor contracts) |
| U06-022 | export `languages` namespace (`:39`) | MEMBER | Public languages boundary. | Concrete Languages field leaks in services. | DEFERRED (replace with minimal capability contract) |
| U06-023 | `IFunctionWithAMD.amd?` (`:41-43`) | MEMBER | Detect AMD loader function. | No loader-global publication. | N-A (module-loader compatibility excluded) |
| U06-024 | `GlobalWithAMD.define?` (`:45-47`) | MEMBER | Optional AMD define function. | ES module/browser bundle. | N-A (module-loader compatibility excluded) |
| U06-025 | `GlobalWithAMD.require?.config` (`:47`) | MEMBER | Optional AMD configuration hook. | ES module/browser bundle. | N-A (module-loader compatibility excluded) |
| U06-026 | `GlobalWithAMD.monaco?` (`:48`) | MEMBER | Optional global API slot. | No `globalThis.viewer` API. | N-A (global publication excluded) |
| U06-027 | read Monaco environment (`:51`) | LIFETIME | Runtime decides global publication. | No local global API option. | N-A (global publication excluded) |
| U06-028 | cast `globalThis` to AMD contract (`:52`) | LIFETIME | Loader probing is centralized. | No local loader path. | N-A (module-loader compatibility excluded) |
| U06-029 | `globalAPI` branch (`:53`) | BRANCH | Explicit environment flag publishes global. | No local global API option. | N-A (global publication excluded) |
| U06-030 | AMD-function-and-flag branch (`:53`) | BRANCH | Implicit AMD environment also publishes. | No local AMD path. | N-A (module-loader compatibility excluded) |
| U06-031 | assign `globalThis.monaco = api` (`:54`) | LIFETIME | Publishes fully assembled API only. | No local global publication. | N-A (global publication excluded) |
| U06-032 | require-exists branch (`:57`) | BRANCH | Configuration only when loader object exists. | No local AMD path. | N-A (module-loader compatibility excluded) |
| U06-033 | require-config-function branch (`:57`) | BRANCH | Guards invocation separately. | No local AMD path. | N-A (module-loader compatibility excluded) |
| U06-034 | configure `ignoreDuplicateModules` (`:58-72`) | LIFETIME | AMD loader tolerates known bundled dependencies. | No local AMD path. | N-A (module-loader compatibility excluded) |
| U06-035 | ignore `vscode-languageserver-types` pair (`:60-61`) | CONST | Duplicate-module allowlist. | No local AMD path. | N-A (module-loader compatibility excluded) |
| U06-036 | ignore `vscode-languageserver-textdocument` pair (`:62-63`) | CONST | Duplicate-module allowlist. | No local AMD path. | N-A (module-loader compatibility excluded) |
| U06-037 | ignore `vscode-nls` pair (`:64-65`) | CONST | Duplicate-module allowlist. | No local AMD path. | N-A (module-loader compatibility excluded) |
| U06-038 | ignore `jsonc-parser` pair (`:66-67`) | CONST | Duplicate-module allowlist. | No local AMD path. | N-A (module-loader compatibility excluded) |
| U06-039 | ignore `vscode-uri` pair (`:68-69`) | CONST | Duplicate-module allowlist. | No local AMD path. | N-A (module-loader compatibility excluded) |
| U06-040 | ignore TypeScript basic-language module (`:70`) | CONST | Duplicate-module allowlist. | No local AMD path. | N-A (module-loader compatibility excluded) |
| U06-041 | `IFunctionWithAMD` interface (`:41-43`) | MEMBER | Owns the loader-function compatibility shape. | No loader-global publication. | N-A (module-loader compatibility excluded) |
| U06-042 | `GlobalWithAMD` interface (`:45-49`) | MEMBER | Owns the probed global loader/API shape. | No loader-global publication. | N-A (module-loader compatibility excluded) |

### U07 — complete `editor.main.ts` entrypoint

| Row | Source atom | Kind | Public-boundary relevance | Local mapping / evidence | Status |
|---|---|---|---|---|---|
| U07-001 | side-effect import `editor.all` (`:6`) | LIFETIME | Registers complete editor/contribution set. | Local static package imports/registry. | DEFERRED (external facade must not expose registry implementation types) |
| U07-002 | side-effect import iPad keyboard (`:7`) | LIFETIME | Standalone mobile UI registration. | Not ported. | N-A (mobile accessory excluded) |
| U07-003 | side-effect import inspect tokens (`:8`) | LIFETIME | Standalone diagnostic contribution. | Not public locally. | N-A (diagnostic contribution excluded) |
| U07-004 | side-effect import standalone help (`:9`) | LIFETIME | Quick-access contribution. | Not ported. | N-A (commands/quick access excluded) |
| U07-005 | side-effect import go-to-line (`:10`) | LIFETIME | Quick-access contribution. | Not ported. | N-A (commands/quick access excluded) |
| U07-006 | side-effect import go-to-symbol (`:11`) | LIFETIME | Quick-access contribution. | Not ported. | N-A (commands/quick access excluded) |
| U07-007 | side-effect import commands quick access (`:12`) | LIFETIME | Command palette contribution. | Not ported. | N-A (commands/quick access excluded) |
| U07-008 | side-effect import reference search (`:13`) | LIFETIME | Standalone reference UI. | Not ported. | N-A (reference UI excluded) |
| U07-009 | side-effect import high-contrast toggle (`:14`) | LIFETIME | Accessibility/theme contribution. | Not ported. | N-A (accessibility command excluded) |
| U07-010 | re-export all `editor.api` (`:16`) | MEMBER | Entrypoint exposes exactly the facade after registrations. | Root package exports its generated public interface. | DEFERRED (generated API gate must prove only reviewed facade items remain) |

### U08 — generated Monaco public declaration mirror

| Row | Source atom | Kind | Public-boundary relevance | Local mapping / evidence | Status |
|---|---|---|---|---|---|
| U08-001 | generated `IScrollEvent` (`:523-532`) | MEMBER | Public declaration mirror of common scroll fact. | Root `ScrollEvent`. | DEFERRED (canonical owner pending) |
| U08-002 | generated `scrollTop` (`:524`) | MEMBER | Vertical value. | Local field. | TESTED |
| U08-003 | generated `scrollLeft` (`:525`) | MEMBER | Horizontal value. | Local field. | TESTED |
| U08-004 | generated `scrollWidth` (`:526`) | MEMBER | Scroll width. | Local field. | TESTED |
| U08-005 | generated `scrollHeight` (`:527`) | MEMBER | Scroll height. | Local field. | TESTED |
| U08-006 | generated `scrollTopChanged` (`:528`) | MEMBER | Independent change flag. | Local field. | TESTED |
| U08-007 | generated `scrollLeftChanged` (`:529`) | MEMBER | Independent change flag. | Local field. | TESTED |
| U08-008 | generated `scrollWidthChanged` (`:530`) | MEMBER | Independent change flag. | Local field. | TESTED |
| U08-009 | generated `scrollHeightChanged` (`:531`) | MEMBER | Independent change flag. | Local field. | TESTED |
| U08-010 | `monaco.editor.create(domElement, options?, override?)` (`:952`) | MEMBER | Sole standalone code-editor constructor; host must be empty and sized. | `Viewer::create(element, services?, options?)`. | DEFERRED (retain as sole public browser constructor and make headless constructor private) |
| U08-011 | `IGlobalEditorOptions` (`:1286-1354`) | MEMBER | Model/global options layered into standalone construction. | Root currently folds selected fields into `ViewerOptions`. | DEFERRED (opaque facade must document this adaptation) |
| U08-012 | global `tabSize?` (`:1292`) | MEMBER | Model indentation option, default 4. | Reviewed `tab_size` remains local model/view-model configuration because `TextSnapshot` has no model options. | DEFERRED (retain the seam without claiming `IEditorOptions` ownership) |
| U08-013 | global `insertSpaces?` (`:1298`) | MEMBER | Editing indentation option. | Not public locally. | N-A (editing policy excluded) |
| U08-014 | global `detectIndentation?` (`:1303`) | MEMBER | Model-opening detection policy. | Not public locally. | N-A (file-opening/editing policy excluded) |
| U08-015 | global `trimAutoWhitespace?` (`:1308`) | MEMBER | Editing cleanup policy. | Not public locally. | N-A (editing policy excluded) |
| U08-016 | global `largeFileOptimizations?` (`:1313`) | MEMBER | Model feature policy. | Not public locally. | N-A (outside denominator) |
| U08-017 | global `wordBasedSuggestions?` (`:1318`) | MEMBER | Suggestions policy. | Not public locally. | N-A (suggestions excluded) |
| U08-018 | global `wordBasedSuggestionsOnlySameLanguage?` (`:1322`) | MEMBER | Suggestions scope. | Not public locally. | N-A (suggestions excluded) |
| U08-019 | global `semanticHighlighting.enabled?` (`:1330`) | MEMBER | Theme/language semantic token policy. | Internal renderer. | N-A (outside public denominator) |
| U08-020 | global `stablePeek?` (`:1335`) | MEMBER | Peek UI policy. | Not ported. | N-A (peek UI excluded) |
| U08-021 | global `maxTokenizationLineLength?` (`:1340`) | MEMBER | Tokenization performance bound. | Internal token model. | N-A (implementation tuning excluded) |
| U08-022 | global `theme?` (`:1348`) | MEMBER | Standalone theme selection. | Reviewed root theme remains standalone/global construction state behind opaque options. | DEFERRED (retain the construction seam) |
| U08-023 | global `autoDetectHighContrast?` (`:1353`) | MEMBER | Accessibility/theme policy. | Not public locally. | N-A (accessibility option excluded) |
| U08-024 | `IStandaloneEditorConstructionOptions` (`:1359-1399`) | MEMBER | Combines editor, global, model, and DOM construction inputs. | Split across `Viewer::create`, `ViewerOptions`, and later `set_model`. | DEFERRED (review the reduced constructor deliberately) |
| U08-025 | construction `model?` (`:1363`) | MEMBER | Initial model; null disables auto-model. | `Viewer::create` has no model argument; caller uses `set_model`. | DEFERRED (document two-step construction or add reviewed initial-model input) |
| U08-026 | construction `value?` (`:1368`) | MEMBER | Initial auto-created model value. | Caller sets/creates a model separately. | N-A (Viewer does not auto-create a public text model) |
| U08-027 | construction `language?` (`:1373`) | MEMBER | Auto-model language. | Language comes from supplied model. | N-A (no auto-created model) |
| U08-028 | construction `theme?` (`:1381`) | MEMBER | Initial standalone theme. | Reviewed root theme remains standalone/global construction state behind opaque options. | DEFERRED (retain the construction seam) |
| U08-029 | construction `autoDetectHighContrast?` (`:1386`) | MEMBER | Accessibility/theme behavior. | Not public locally. | N-A (accessibility option excluded) |
| U08-030 | construction `accessibilityHelpUrl?` (`:1393`) | MEMBER | Help-dialog URL. | Not ported. | N-A (accessibility UI excluded) |
| U08-031 | construction `ariaContainerElement?` (`:1398`) | MEMBER | External ARIA message DOM host. | Not public locally. | N-A (accessibility DOM option excluded) |
| U08-032 | `IStandaloneCodeEditor` (`:1420-1425`) | MEMBER | Standalone-specific extension of code editor. | Root Viewer facade. | DEFERRED (retain only accepted denominator) |
| U08-033 | standalone `updateOptions` with global options (`:1421`) | MEMBER | Live update accepts editor plus global fields. | Root update accepts ViewerOptions. | DEFERRED (typed opaque snapshot must define live versus construction-only fields) |
| U08-034 | standalone `addCommand` (`:1422`) | MEMBER | Runtime command registration. | No public root method. | N-A (commands excluded) |
| U08-035 | standalone `createContextKey` (`:1423`) | MEMBER | Runtime context-key registration. | No public root method. | N-A (context service excluded) |
| U08-036 | standalone `addAction` (`:1424`) | MEMBER | Runtime action registration. | No public root method. | N-A (actions excluded) |
| U08-037 | `IEditorOverrideServices` (`:1453-1455`) | MEMBER | Opaque string-keyed service replacement seam. | Root exposes concrete typed service fields. | DEFERRED (replace with minimal typed capability records, not this opaque bag) |
| U08-038 | override `[index: string]: unknown` (`:1454`) | MEMBER | Allows arbitrary internal service identifiers. | Target forbids a service locator/open bag. | N-A (typed Viewer capabilities deliberately diverge) |
| U08-039 | generated `IModelChangedEvent` (`:2584-2593`) | MEMBER | Public model reset payload. | Root payload. | DEFERRED (canonical owner pending) |
| U08-040 | generated `oldModelUrl` (`:2588`) | MEMBER | Nullable outgoing URI. | Local field. | TESTED |
| U08-041 | generated `newModelUrl` (`:2592`) | MEMBER | Nullable incoming URI. | Local field. | TESTED |
| U08-042 | generated `IContentSizeChangedEvent` (`:2595-2600`) | MEMBER | Public extent fact. | Internal event. | DEFERRED (public event disposition unresolved) |
| U08-043 | generated `contentWidth` (`:2596`) | MEMBER | Width value. | Local layout. | PORTED |
| U08-044 | generated `contentHeight` (`:2597`) | MEMBER | Height value. | Local layout. | PORTED |
| U08-045 | generated `contentWidthChanged` (`:2598`) | MEMBER | Width flag. | Local event. | TESTED |
| U08-046 | generated `contentHeightChanged` (`:2599`) | MEMBER | Height flag. | Local event. | TESTED |
| U08-047 | generated `INewScrollPosition` (`:2602-2605`) | MEMBER | Partial scroll command. | Optional root arguments. | DEFERRED (record shape decision) |
| U08-048 | generated `scrollLeft?` (`:2603`) | MEMBER | Optional horizontal update. | Local optional arg. | TESTED |
| U08-049 | generated `scrollTop?` (`:2604`) | MEMBER | Optional vertical update. | Local optional arg. | TESTED |
| U08-050 | generated `IEditorAction` (`:2607-2614`) | MEMBER | Public action shape. | No root action API. | N-A (actions excluded) |
| U08-051 | action `id` (`:2608`) | MEMBER | Action identity. | No root action API. | N-A (actions excluded) |
| U08-052 | action `label` (`:2609`) | MEMBER | Display label. | No root action API. | N-A (actions excluded) |
| U08-053 | action `alias` (`:2610`) | MEMBER | Alternate label. | No root action API. | N-A (actions excluded) |
| U08-054 | action `metadata` (`:2611`) | MEMBER | Command metadata. | No root action API. | N-A (actions excluded) |
| U08-055 | action `isSupported` (`:2612`) | MEMBER | Context predicate. | No root action API. | N-A (actions excluded) |
| U08-056 | action `run` (`:2613`) | MEMBER | Executes action. | No root action API. | N-A (actions excluded) |
| U08-057 | generated `IEditorModel` union (`:2616`) | MEMBER | Text/diff/diff-view model union. | Viewer accepts only TextModel. | DEFERRED (code-editor narrowing is intentional; diff arms excluded) |
| U08-058 | generated `ICursorState` (`:2621-2625`) | MEMBER | Serializable cursor representation. | Reduced selection state. | DEFERRED (state reduction) |
| U08-059 | cursor `inSelectionMode` (`:2622`) | MEMBER | Internal mode bit. | Encoded by selection. | N-A (representation erased) |
| U08-060 | cursor `selectionStart` (`:2623`) | MEMBER | Anchor. | Selection anchor. | TESTED |
| U08-061 | cursor `position` (`:2624`) | MEMBER | Active end. | Selection position. | TESTED |
| U08-062 | generated `IViewState` (`:2630-2638`) | MEMBER | Serializable viewport. | Reduced root state. | DEFERRED (shape reduction) |
| U08-063 | legacy `scrollTop?` (`:2632`) | MEMBER | Old state compatibility. | No compatibility shape. | N-A (breaking API) |
| U08-064 | legacy `scrollTopWithoutViewZones?` (`:2634`) | MEMBER | Old state compatibility. | No compatibility shape. | N-A (breaking API) |
| U08-065 | view `scrollLeft` (`:2635`) | MEMBER | Horizontal state. | Local field. | TESTED |
| U08-066 | view `firstPosition` (`:2636`) | MEMBER | Viewport anchor. | Local absolute scroll. | DEFERRED (reduced state) |
| U08-067 | view `firstPositionDeltaTop` (`:2637`) | MEMBER | Anchor delta. | Local absolute scroll. | DEFERRED (reduced state) |
| U08-068 | generated `ICodeEditorViewState` (`:2643-2649`) | MEMBER | Cursor/view/contribution envelope. | Reduced root state. | DEFERRED (opaque state contract) |
| U08-069 | generated `cursorState` (`:2644`) | MEMBER | All cursors. | One selection. | DEFERRED (multi-cursor state reduction) |
| U08-070 | generated `viewState` (`:2645`) | MEMBER | Viewport state. | Scroll fields. | DEFERRED (shape reduction) |
| U08-071 | generated contribution state index (`:2646-2648`) | MEMBER | Id-to-unknown slots. | No public contribution state. | DEFERRED (keep contribution implementation state internal) |
| U08-072 | generated `IDiffEditorViewState` (`:2654-2658`) | MEMBER | Diff state envelope. | No diff viewer. | N-A (diff cluster excluded) |
| U08-073 | diff `original` state (`:2655`) | MEMBER | Original editor state. | No diff viewer. | N-A (diff cluster excluded) |
| U08-074 | diff `modified` state (`:2656`) | MEMBER | Modified editor state. | No diff viewer. | N-A (diff cluster excluded) |
| U08-075 | diff `modelState?` (`:2657`) | MEMBER | Diff model state. | No diff viewer. | N-A (diff cluster excluded) |
| U08-076 | generated `IEditorViewState` union (`:2663`) | MEMBER | Code-or-diff state. | Code viewer only. | DEFERRED (narrow to reviewed Viewer state) |
| U08-077 | generated `ScrollType` (`:2665-2668`) | MEMBER | Public scroll-mode enum. | The reviewed facade exposes no public scroll enum: every public reveal and setter is fixed `Immediate`. | N-A (smooth mode remains internal to physical input/cursor scrolling) |
| U08-078 | generated `Smooth = 0` (`:2666`) | CONST | Animated mode. | Local smooth machinery is internal to physical input/cursor scrolling; `viewer/cursor_input_wbtest.mbt` covers the at-most-one-line downgrade. | TESTED |
| U08-079 | generated `Immediate = 1` (`:2667`) | CONST | Immediate mode. | Every reviewed public reveal and scroll setter uses immediate behavior; `viewer/reveal_wbtest.mbt` checks the immediate request. | TESTED |
| U08-080 | generated `IEditor` (`:2673-2882`) | MEMBER | Public base editor surface. | Root reduced Viewer. | DEFERRED (reviewed denominator only) |
| U08-081 | generated `onDidDispose` (`:2678`) | MEMBER | Dispose subscription. | Root method. | TESTED |
| U08-082 | generated `dispose` (`:2682`) | MEMBER | Dispose editor. | Root method. | TESTED |
| U08-083 | generated `getId` (`:2686`) | MEMBER | Identity. | Root method; the current public caller sweep finds no direct caller. | PORTED |
| U08-084 | generated `getEditorType` (`:2691`) | MEMBER | Type discriminator. | Root method. | PORTED |
| U08-085 | generated `updateOptions` (`:2695`) | MEMBER | Live option update. | Root method. | DEFERRED (opaque semantics pending) |
| U08-086 | generated `layout` (`:2705`) | MEMBER | Remeasure/render. | Reduced root method. | DEFERRED (dimension/postpone omitted) |
| U08-087 | generated `focus` (`:2709`) | MEMBER | Browser focus. | Root method. | TESTED |
| U08-088 | generated `hasTextFocus` (`:2713`) | MEMBER | Focus query. | Root method. | TESTED |
| U08-089 | generated `getSupportedActions` (`:2717`) | MEMBER | Action enumeration. | No root method. | N-A (actions excluded) |
| U08-090 | generated `saveViewState` (`:2721`) | MEMBER | State snapshot. | Root method. | TESTED |
| U08-091 | generated `restoreViewState` (`:2725`) | MEMBER | State restore. | Root method. | TESTED |
| U08-092 | generated `getVisibleColumnFromPosition` (`:2729`) | MEMBER | Tab-aware column. | Root method. | TESTED |
| U08-093 | generated `getPosition` (`:2733`) | MEMBER | Primary cursor. | Root method. | TESTED |
| U08-094 | generated `setPosition` (`:2739`) | MEMBER | Collapse primary cursor. | Root method. | TESTED |
| U08-095 | generated `revealLine` (`:2743`) | MEMBER | Simple line reveal. | Root method. | TESTED |
| U08-096 | generated `revealLineInCenter` (`:2747`) | MEMBER | Center line reveal. | Root method. | TESTED |
| U08-097 | generated `revealLineInCenterIfOutsideViewport` (`:2751`) | MEMBER | Conditional center line reveal. | Root method; the current public caller sweep finds no direct caller. | PORTED |
| U08-098 | generated `revealLineNearTop` (`:2756`) | MEMBER | Near-top line reveal. | Root method; the current public caller sweep finds no direct caller. | PORTED |
| U08-099 | generated `revealPosition` (`:2760`) | MEMBER | Simple position reveal. | Root method. | TESTED |
| U08-100 | generated `revealPositionInCenter` (`:2764`) | MEMBER | Center position reveal. | Root method; the current public caller sweep finds no direct caller. | PORTED |
| U08-101 | generated `revealPositionInCenterIfOutsideViewport` (`:2768`) | MEMBER | Conditional center position reveal. | Root method. | TESTED |
| U08-102 | generated `revealPositionNearTop` (`:2773`) | MEMBER | Near-top position reveal. | Root method; the current public caller sweep finds no direct caller. | PORTED |
| U08-103 | generated `getSelection` (`:2777`) | MEMBER | Primary selection. | Root method. | TESTED |
| U08-104 | generated `getSelections` (`:2781`) | MEMBER | All selections. | Root method. | TESTED |
| U08-105 | generated `setSelection(IRange)` (`:2787`) | MEMBER | Range overload. | No overload. | N-A (typed Selection only) |
| U08-106 | generated `setSelection(Range)` (`:2793`) | MEMBER | Class-range overload. | No overload. | N-A (typed Selection only) |
| U08-107 | generated `setSelection(ISelection)` (`:2799`) | MEMBER | Structural selection overload. | No overload. | N-A (one canonical type) |
| U08-108 | generated `setSelection(Selection)` (`:2805`) | MEMBER | Concrete selection overload. | Root method. | TESTED |
| U08-109 | generated `setSelections` (`:2812`) | MEMBER | Replace all cursors. | Root method. | TESTED |
| U08-110 | generated `revealLines` (`:2816`) | MEMBER | Simple line-range reveal. | Root method; the current public caller sweep finds no direct caller. | PORTED |
| U08-111 | generated `revealLinesInCenter` (`:2820`) | MEMBER | Center line-range reveal. | Root method; the current public caller sweep finds no direct caller. | PORTED |
| U08-112 | generated `revealLinesInCenterIfOutsideViewport` (`:2824`) | MEMBER | Conditional center line-range reveal. | Root method; the current public caller sweep finds no direct caller. | PORTED |
| U08-113 | generated `revealLinesNearTop` (`:2829`) | MEMBER | Near-top line-range reveal. | Root method; the current public caller sweep finds no direct caller. | PORTED |
| U08-114 | generated `revealRange` (`:2833`) | MEMBER | Simple range reveal. | Root method. | TESTED |
| U08-115 | generated `revealRangeInCenter` (`:2837`) | MEMBER | Center range reveal. | Root method; the current public caller sweep finds no direct caller. | PORTED |
| U08-116 | generated `revealRangeAtTop` (`:2841`) | MEMBER | Top range reveal. | Root method; the current public caller sweep finds no direct caller. | PORTED |
| U08-117 | generated `revealRangeInCenterIfOutsideViewport` (`:2845`) | MEMBER | Conditional center range reveal. | Root method. | TESTED |
| U08-118 | generated `revealRangeNearTop` (`:2850`) | MEMBER | Near-top range reveal. | Root method; the current public caller sweep finds no direct caller. | PORTED |
| U08-119 | generated `revealRangeNearTopIfOutsideViewport` (`:2855`) | MEMBER | Conditional near-top range reveal. | Root method; the current public caller sweep finds no direct caller. | PORTED |
| U08-120 | generated `trigger` (`:2862`) | MEMBER | Command/action dispatch. | No root method. | N-A (commands excluded) |
| U08-121 | generated base `getModel` (`:2866`) | MEMBER | Text/diff union getter. | Root text-model getter. | DEFERRED (code-editor narrowing intentional) |
| U08-122 | generated base `setModel` (`:2875`) | MEMBER | Text/diff union setter. | Root text-model setter. | DEFERRED (code-editor narrowing intentional) |
| U08-123 | generated `createDecorationsCollection` (`:2881`) | MEMBER | Decoration collection. | Root method. | DEFERRED (decoration disposition required) |
| U08-124 | generated `IEditorContribution` (`:2926-2939`) | MEMBER | Generic lookup bound and view-state lifecycle. | Public contribution type currently leaks. | DEFERRED (remove from external facade) |
| U08-125 | generated contribution `dispose` (`:2930`) | MEMBER | Lifetime method. | Central internal contribution. | TESTED |
| U08-126 | generated contribution `saveViewState?` (`:2934`) | MEMBER | Optional state producer. | Absent locally. | DEFERRED (keep internal if implemented) |
| U08-127 | generated contribution `restoreViewState?` (`:2938`) | MEMBER | Optional state consumer. | Absent locally. | DEFERRED (keep internal if implemented) |
| U08-128 | generated `CursorChangeReason` (`:3084-3113`) | MEMBER | Public canonical reason. | Duplicate local enums. | DEFERRED (one canonical `common/editor_api` type) |
| U08-129 | generated `NotSet = 0` (`:3088`) | CONST | Default reason. | Local. | TESTED |
| U08-130 | generated `ContentFlush = 1` (`:3092`) | CONST | Model flush. | Local. | TESTED |
| U08-131 | generated `RecoverFromMarkers = 2` (`:3096`) | CONST | Marker recovery. | Local enum preserves the constant; it is named by exhaustive formatter code but the current event producers never emit it. | PORTED |
| U08-132 | generated `Explicit = 3` (`:3100`) | CONST | Explicit gesture. | Local. | TESTED |
| U08-133 | generated `Paste = 4` (`:3104`) | CONST | Paste. | Local. | TESTED |
| U08-134 | generated `Undo = 5` (`:3108`) | CONST | Undo. | Local. | TESTED |
| U08-135 | generated `Redo = 6` (`:3112`) | CONST | Redo. | Local. | TESTED |
| U08-136 | generated `ICursorPositionChangedEvent` (`:3118-3135`) | MEMBER | Public position payload. | Root payload. | DEFERRED (canonical owner pending) |
| U08-137 | generated position `position` (`:3122`) | MEMBER | Primary position. | Local. | TESTED |
| U08-138 | generated `secondaryPositions` (`:3126`) | MEMBER | Secondary positions. | Local. | TESTED |
| U08-139 | generated position `reason` (`:3130`) | MEMBER | Canonical reason. | Adapted duplicate. | DEFERRED (delete adapter) |
| U08-140 | generated position `source` (`:3134`) | MEMBER | Origin. | Local. | TESTED |
| U08-141 | generated `ICursorSelectionChangedEvent` (`:3140-3169`) | MEMBER | Public selection payload. | Root payload. | DEFERRED (canonical owner pending) |
| U08-142 | generated selection `selection` (`:3144`) | MEMBER | Primary selection. | Local. | TESTED |
| U08-143 | generated `secondarySelections` (`:3148`) | MEMBER | Secondary selections. | Local. | TESTED |
| U08-144 | generated `modelVersionId` (`:3152`) | MEMBER | New version. | Local. | TESTED |
| U08-145 | generated nullable `oldSelections` (`:3156`) | MEMBER | Null versus array preserved. | Root `CursorSelectionChangedEvent.old_selections : Array[Selection]?` preserves the distinction; cursor event tests exercise `None` and populated history. | TESTED |
| U08-146 | generated `oldModelVersionId` (`:3160`) | MEMBER | Old version. | Local. | TESTED |
| U08-147 | generated selection `source` (`:3164`) | MEMBER | Origin. | Local. | TESTED |
| U08-148 | generated selection `reason` (`:3168`) | MEMBER | Canonical reason. | Adapted duplicate. | DEFERRED (delete adapter) |
| U08-149 | generated `IEditorOptions` scoped owner (`:3209-4128`) | MEMBER | Declaration consumers compile against these field types. | Root opaque ViewerOptions target. | DEFERRED (preserve selected capability without exposing fields) |
| U08-150 | generated `lineNumbersMinChars?` (`:3302`) | MEMBER | Selected option. | Local field. | TESTED |
| U08-151 | generated `lineDecorationsWidth?` (`:3314`) | MEMBER | Number-or-`ch` option. | Local integer only. | DEFERRED (document reduction) |
| U08-152 | generated `readOnly?` (`:3334`) | MEMBER | Editable/readonly toggle. | No local toggle. | N-A (readonly by product contract) |
| U08-153 | generated `renderValidationDecorations?` (`:3357`) | MEMBER | Three-mode option. | Leaked internal enum. | DEFERRED (canonical enum move) |
| U08-154 | generated `smoothScrolling?` (`:3484`) | MEMBER | Scroll animation option. | Local field. | TESTED |
| U08-155 | generated `wordWrap?` (`:3498`) | MEMBER | Four-mode wrap option. | Boolean reduction. | DEFERRED (review reduction) |
| U08-156 | generated `wrappingIndent?` (`:3520`) | MEMBER | Four-mode indentation. | Leaked view-model enum. | DEFERRED (canonical enum move) |
| U08-157 | generated `folding?` (`:3834`) | MEMBER | Folding toggle. | Local field. | TESTED |
| U08-158 | generated `foldingHighlight?` (`:3844`) | MEMBER | Fold highlight. | Local field. | TESTED |
| U08-159 | generated `foldingMaximumRegions?` (`:3854`) | MEMBER | Region bound. | Local field. | TESTED |
| U08-160 | generated `showFoldingControls?` (`:3859`) | MEMBER | Three-mode gutter controls. | Leaked folding enum. | DEFERRED (canonical enum move) |
| U08-161 | generated `unfoldOnClickAfterEndOfLine?` (`:3864`) | MEMBER | Folding click option. | Local field. | TESTED |
| U08-162 | generated `renderWhitespace?` (`:3884`) | MEMBER | Five-mode option. | Leaked layout enum. | DEFERRED (canonical enum move) |
| U08-163 | generated `renderControlCharacters?` (`:3889`) | MEMBER | Render toggle. | Local field. | TESTED |
| U08-164 | generated `renderLineHighlight?` (`:3894`) | MEMBER | Four-mode option. | Leaked layout enum. | DEFERRED (canonical enum move) |
| U08-165 | generated focus-only line highlight (`:3899`) | MEMBER | Focus gate. | Local field. | TESTED |
| U08-166 | generated `fontFamily?` (`:3912`) | MEMBER | Font family. | Local field. | TESTED |
| U08-167 | generated `fontWeight?` (`:3916`) | MEMBER | Font weight. | Local field. | PORTED |
| U08-168 | generated `fontSize?` (`:3920`) | MEMBER | Font size. | Local field. | TESTED |
| U08-169 | generated `lineHeight?` (`:3924`) | MEMBER | Line height. | Local field. | TESTED |
| U08-170 | generated `letterSpacing?` (`:3928`) | MEMBER | Letter spacing. | Local field. | TESTED |
| U08-171 | generated `showUnused?` (`:3932`) | MEMBER | Fade unused. | Local field. | TESTED |
| U08-172 | generated `placeholder?` (`:3942`) | MEMBER | Empty placeholder. | Local field. | TESTED |
| U08-173 | generated `showDeprecated?` (`:3951`) | MEMBER | Strike deprecated. | Local field. | TESTED |
| U08-174 | all other generated `IEditorOptions` fields (`:3213-4128`) | MEMBER | Full Monaco editing/accessibility/rendering surface. | Not in local denominator. | N-A (named sibling options excluded) |
| U08-175 | generated `IEditorConstructionOptions` (`:5452-5462`) | MEMBER | DOM-aware options layered over editor options. | Root browser constructor owns DOM directly. | DEFERRED (review reduced construction seam) |
| U08-176 | construction `dimension?` (`:5456`) | MEMBER | Avoids measuring host DOM. | Root has no explicit dimension option. | N-A (reduced constructor measures host) |
| U08-177 | construction `overflowWidgetsDomNode?` (`:5461`) | MEMBER | External overflow DOM host. | Not public locally. | N-A (DOM implementation option excluded) |
| U08-178 | generated `IViewZone` (`:5468-5532`) | MEMBER | Public DOM descriptor mirror. | Root aliases private runtime type. | DEFERRED (move contract to `viewer/browser`) |
| U08-179 | generated `afterLineNumber` (`:5473`) | MEMBER | Model anchor. | Local field. | TESTED |
| U08-180 | generated zero-before-first contract (`:5470-5472`) | CONST | `0` sentinel. | Local branch matrix. | TESTED |
| U08-181 | generated `afterColumn?` (`:5479`) | MEMBER | Wrapped-line anchor. | Local field. | TESTED |
| U08-182 | generated max-column fallback (`:5475-5477`) | BRANCH | Missing column anchors at line end. | Local normalization. | TESTED |
| U08-183 | generated `afterColumnAffinity?` (`:5483`) | MEMBER | Ambiguous projection side. | Local field. | TESTED |
| U08-184 | generated affinity default none (`:5481-5483`) | CONST | Default projection policy. | Local default. | TESTED |
| U08-185 | generated `showInHiddenAreas?` (`:5487`) | MEMBER | Hidden-line policy. | Local field. | TESTED |
| U08-186 | generated `ordinal?` (`:5492`) | MEMBER | Same-anchor ordering. | Local field. | TESTED |
| U08-187 | generated ordinal fallback (`:5489-5492`) | BRANCH | Column or `10000`. | Local ordering. | TESTED |
| U08-188 | generated `suppressMouseDown?` (`:5498`) | MEMBER | DOM cancellation option. | Local field. | TESTED |
| U08-189 | generated suppress DOM `preventDefault` contract (`:5494-5496`) | DOM | Editor owns mousedown listener. | Local DOM tests. | TESTED |
| U08-190 | generated suppress default false (`:5496-5498`) | CONST | No cancellation by default. | Local default. | TESTED |
| U08-191 | generated `heightInLines?` (`:5504`) | MEMBER | Line-unit height. | Local field. | TESTED |
| U08-192 | generated `heightInPx?` (`:5510`) | MEMBER | Pixel height. | Local field. | TESTED |
| U08-193 | generated pixel precedence/one-line fallback (`:5500-5510`) | BRANCH | Complete height selection. | Local tests. | TESTED |
| U08-194 | generated `minWidthInPx?` (`:5515`) | MEMBER | Minimum width. | Local field. | TESTED |
| U08-195 | generated min-width scroll contract (`:5512-5515`) | DOM | Widens editor scroll width. | Local layout test. | TESTED |
| U08-196 | generated `domNode` (`:5519`) | MEMBER | Required content DOM. | Local field. | DEFERRED (browser contract owner pending) |
| U08-197 | generated `marginDomNode?` (`:5523`) | MEMBER | Optional margin DOM. | Local field. | DEFERRED (browser contract owner pending) |
| U08-198 | generated `onDomNodeTop?` (`:5527`) | MEMBER | Scroll-relative top callback. | Local field. | TESTED |
| U08-199 | generated `onComputedHeight?` (`:5531`) | MEMBER | Computed-height callback. | Local field. | TESTED |
| U08-200 | generated `IViewZoneChangeAccessor` (`:5537-5554`) | MEMBER | Transactional mutation facade. | Root exposes private type. | DEFERRED (browser contract owner pending) |
| U08-201 | generated `addZone` (`:5543`) | MEMBER | Add and return id. | Local accessor. | TESTED |
| U08-202 | generated `removeZone` (`:5548`) | MEMBER | Remove by id. | Local accessor. | TESTED |
| U08-203 | generated `layoutZone` (`:5553`) | MEMBER | Rescan line/column. | Local accessor. | TESTED |
| U08-204 | generated public `ICodeEditor` (`:6002-6447`) | MEMBER | Browser-independent Monaco consumer surface. | Root Viewer is a subset. | DEFERRED (generated root interface must match reviewed denominator) |
| U08-205 | generated `onDidChangeModelContent` (`:6007`) | MEMBER | Content event. | Root event. | TESTED |
| U08-206 | generated `onDidChangeModelLanguage` (`:6012`) | MEMBER | Language event. | No root event. | DEFERRED (event disposition unresolved) |
| U08-207 | generated language-config event (`:6017`) | MEMBER | Language-config event. | No root event. | N-A (implementation event excluded) |
| U08-208 | generated model-options event (`:6022`) | MEMBER | Model-option event. | No root event. | DEFERRED (event disposition unresolved) |
| U08-209 | generated configuration event (`:6027`) | MEMBER | Live option event. | Internal only. | DEFERRED (event disposition unresolved) |
| U08-210 | generated cursor-position event (`:6032`) | MEMBER | Public semantic cursor event. | Root event. | DEFERRED (canonical payload pending) |
| U08-211 | generated cursor-selection event (`:6037`) | MEMBER | Public semantic cursor event. | Root event. | DEFERRED (canonical payload pending) |
| U08-212 | generated will-change-model event (`:6042`) | MEMBER | Pre-detach event. | Not public locally. | DEFERRED (event disposition unresolved) |
| U08-213 | generated did-change-model event (`:6047`) | MEMBER | Post-attach event. | Root event. | TESTED |
| U08-214 | generated decorations event (`:6052`) | MEMBER | Decoration event. | Internal only. | N-A (decoration event excluded) |
| U08-215 | generated focus-text event (`:6057`) | MEMBER | Text focus. | No root event. | DEFERRED (event disposition unresolved) |
| U08-216 | generated blur-text event (`:6062`) | MEMBER | Text blur. | No root event. | DEFERRED (event disposition unresolved) |
| U08-217 | generated focus-widget event (`:6067`) | MEMBER | Whole-widget focus. | No root event. | DEFERRED (event disposition unresolved) |
| U08-218 | generated blur-widget event (`:6072`) | MEMBER | Whole-widget blur. | No root event. | DEFERRED (event disposition unresolved) |
| U08-219 | generated `inComposition` (`:6076`) | MEMBER | IME state. | Internal input only. | N-A (editing/input excluded) |
| U08-220 | generated composition-start event (`:6080`) | MEMBER | IME event. | Internal input only. | N-A (editing/input excluded) |
| U08-221 | generated composition-end event (`:6084`) | MEMBER | IME event. | Internal input only. | N-A (editing/input excluded) |
| U08-222 | generated readonly-edit-attempt event (`:6089`) | MEMBER | Failed edit. | No root event. | N-A (editing excluded) |
| U08-223 | generated paste event (`:6094`) | MEMBER | Paste. | Internal only. | N-A (editing excluded) |
| U08-224 | generated mouse-up event (`:6099`) | MEMBER | Pointer event. | Root event. | TESTED |
| U08-225 | generated mouse-down event (`:6104`) | MEMBER | Pointer event. | Root event. | TESTED |
| U08-226 | generated context-menu event (`:6109`) | MEMBER | Menu pointer event. | No root event. | N-A (menu/commands excluded) |
| U08-227 | generated mouse-move event (`:6114`) | MEMBER | Pointer event. | Root event. | TESTED |
| U08-228 | generated mouse-leave event (`:6119`) | MEMBER | Partial pointer event. | Root event. | TESTED |
| U08-229 | generated key-up event (`:6124`) | MEMBER | Keyboard event. | Internal only. | N-A (input/commands excluded) |
| U08-230 | generated key-down event (`:6129`) | MEMBER | Keyboard event. | Internal only. | N-A (input/commands excluded) |
| U08-231 | generated layout event (`:6134`) | MEMBER | Layout snapshot event. | Internal only. | DEFERRED (event disposition unresolved) |
| U08-232 | generated content-size event (`:6139`) | MEMBER | Extent event. | Internal only. | DEFERRED (event disposition unresolved) |
| U08-233 | generated scroll event (`:6144`) | MEMBER | Semantic scroll fact. | Root event. | DEFERRED (canonical payload pending) |
| U08-234 | generated hidden-area event (`:6149`) | MEMBER | Folding state event. | Internal only. | N-A (implementation event excluded) |
| U08-235 | generated begin-update event (`:6157`) | MEMBER | Transaction bracket. | Internal only. | N-A (implementation event excluded) |
| U08-236 | generated end-update event (`:6161`) | MEMBER | Transaction bracket. | Internal only. | N-A (implementation event excluded) |
| U08-237 | generated view-zone event (`:6162`) | MEMBER | Zone-layout event. | Root event. | TESTED |
| U08-238 | generated typed `saveViewState` (`:6166`) | MEMBER | Code state snapshot. | Root reduced state. | TESTED |
| U08-239 | generated typed `restoreViewState` (`:6170`) | MEMBER | Code state restore. | Root reduced state. | TESTED |
| U08-240 | generated `hasWidgetFocus` (`:6174`) | MEMBER | Whole-widget focus query. | Root method; the current public caller sweep finds no direct caller. | PORTED |
| U08-241 | generated `getContribution<T>` (`:6180`) | MEMBER | String lookup exposes contribution bound. | Root method currently. | DEFERRED (remove from public facade) |
| U08-242 | generated typed `getModel` (`:6184`) | MEMBER | Nullable text model. | Root method. | TESTED |
| U08-243 | generated typed `setModel` (`:6193`) | MEMBER | Attach/detach text model. | Root method. | TESTED |
| U08-244 | generated `getOptions` (`:6197`) | MEMBER | Computed option set. | Root raw snapshot. | DEFERRED (opaque getters only) |
| U08-245 | generated `getOption` (`:6201`) | MEMBER | Typed option lookup. | No root method. | N-A (full registry excluded) |
| U08-246 | generated `getRawOptions` (`:6205`) | MEMBER | Raw option snapshot. | Root getter. | DEFERRED (opaque facade) |
| U08-247 | generated `getValue` (`:6210-6213`) | MEMBER | Text getter with optional policy. | Reduced root getter. | DEFERRED (document omitted EOL/BOM policy) |
| U08-248 | inline `preserveBOM` option (`:6211`) | MEMBER | BOM policy. | Not exposed. | N-A (reduced getter) |
| U08-249 | inline `lineEnding` option (`:6212`) | MEMBER | EOL policy. | Not exposed. | N-A (reduced getter) |
| U08-250 | generated `setValue` (`:6218`) | MEMBER | Replace content. | Retained root method is host-driven whole-buffer replacement; `viewer/set_value_api_wbtest.mbt` covers the public operation without exposing interactive editing, undo, or actions. | TESTED |
| U08-251 | generated `getContentWidth` (`:6223`) | MEMBER | Content width. | Root method. | TESTED |
| U08-252 | generated `getScrollWidth` (`:6227`) | MEMBER | Scroll width. | Root method. | TESTED |
| U08-253 | generated `getScrollLeft` (`:6231`) | MEMBER | Horizontal offset. | Root method. | TESTED |
| U08-254 | generated `getContentHeight` (`:6236`) | MEMBER | Content height. | Root method. | TESTED |
| U08-255 | generated `getScrollHeight` (`:6240`) | MEMBER | Scroll height. | Root method. | TESTED |
| U08-256 | generated `getScrollTop` (`:6244`) | MEMBER | Vertical offset. | Root method. | TESTED |
| U08-257 | generated `setScrollLeft` (`:6248`) | MEMBER | Horizontal command with mode. | Reviewed root method deliberately fixes `Immediate` and exposes no public `ScrollType`. | DEFERRED (accepted signature reduction; smooth mode remains internal) |
| U08-258 | generated `setScrollTop` (`:6252`) | MEMBER | Vertical command with mode. | Reviewed root method deliberately fixes `Immediate` and exposes no public `ScrollType`. | DEFERRED (accepted signature reduction; smooth mode remains internal) |
| U08-259 | generated `setScrollPosition` (`:6256`) | MEMBER | Partial two-axis command. | Root optional args. | TESTED |
| U08-260 | generated `hasPendingScrollAnimation` (`:6260`) | MEMBER | Animation query. | No root method. | N-A (implementation state excluded) |
| U08-261 | generated `getAction` (`:6266`) | MEMBER | Action lookup. | No root method. | N-A (actions excluded) |
| U08-262 | generated `executeCommand` (`:6273`) | MEMBER | Editing command. | No root method. | N-A (editing/commands excluded) |
| U08-263 | generated `pushUndoStop` (`:6277`) | MEMBER | Undo mutation. | No root method. | N-A (editing/undo excluded) |
| U08-264 | generated `popUndoStop` (`:6281`) | MEMBER | Undo mutation. | No root method. | N-A (editing/undo excluded) |
| U08-265 | generated `executeEdits` (`:6289`) | MEMBER | Editing mutation. | No root method. | N-A (editing excluded) |
| U08-266 | generated `executeCommands` (`:6295`) | MEMBER | Editing commands. | No root method. | N-A (editing/commands excluded) |
| U08-267 | generated `revealAllCursors` (`:6299`) | MEMBER | Reveal every cursor. | No root method. | DEFERRED (multi-cursor denominator incomplete) |
| U08-268 | generated `getLineDecorations` (`:6303`) | MEMBER | Decoration query. | Root method; `viewer/test_viewer_wbtest.mbt` exercises owner filtering. | TESTED |
| U08-269 | generated `getDecorationsInRange` (`:6307`) | MEMBER | Decoration query. | Root method; `viewer/test_viewer_wbtest.mbt` exercises range filtering. | TESTED |
| U08-270 | generated `getFontSizeAtPosition` (`:6312`) | MEMBER | Font query. | No root method. | N-A (outside denominator) |
| U08-271 | generated `deltaDecorations` (`:6318`) | MEMBER | Deprecated decoration mutation. | Root method; `viewer/test_viewer_wbtest.mbt` exercises owner-scoped replacement. | TESTED |
| U08-272 | generated `removeDecorations` (`:6322`) | MEMBER | Decoration mutation. | Root method; root and browser decoration tests exercise removal. | TESTED |
| U08-273 | generated `getLayoutInfo` (`:6326`) | MEMBER | Layout snapshot. | Root method. | TESTED |
| U08-274 | generated `getVisibleRanges` (`:6331`) | MEMBER | Visible ranges. | Root method. | TESTED |
| U08-275 | generated `getTopForLineNumber` (`:6335`) | MEMBER | Line top. | Root method. | TESTED |
| U08-276 | generated `getBottomForLineNumber` (`:6339`) | MEMBER | Line bottom. | Root broader signature. | DEFERRED (signature disposition) |
| U08-277 | generated `getTopForPosition` (`:6343`) | MEMBER | Position top. | Root method. | TESTED |
| U08-278 | generated `getLineHeightForPosition` (`:6347`) | MEMBER | Projected line height. | Root method. | TESTED |
| U08-279 | generated `writeScreenReaderContent` (`:6351`) | MEMBER | Accessibility output. | No root method. | N-A (accessibility excluded) |
| U08-280 | generated `getContainerDomNode` (`:6355`) | MEMBER | Non-null host DOM. | Reviewed target retains the original browser host and returns non-null `Element` before and after disposal; private headless construction must not call it. | DEFERRED (implement the reviewed browser-host invariant) |
| U08-281 | generated `getDomNode` (`:6359`) | MEMBER | Nullable view DOM. | Root method. | TESTED |
| U08-282 | generated `addContentWidget` (`:6363`) | MEMBER | Add content widget. | No current root implementation or caller; external hosts remain root/common-only. | DEFERRED (the reviewed target does not add the full content-widget API) |
| U08-283 | generated `layoutContentWidget` (`:6368`) | MEMBER | Relayout content widget. | No current root implementation or caller; external hosts remain root/common-only. | DEFERRED (the reviewed target does not add the full content-widget API) |
| U08-284 | generated `removeContentWidget` (`:6372`) | MEMBER | Remove content widget. | No current root implementation or caller; external hosts remain root/common-only. | DEFERRED (the reviewed target does not add the full content-widget API) |
| U08-285 | generated `addOverlayWidget` (`:6376`) | MEMBER | Add overlay widget. | Reviewed root add accepts the opaque browser-owned handle produced by `overlay_widget(id, node)`. | DEFERRED (replace the raw id/node seam with the reviewed immutable handle) |
| U08-286 | generated `layoutOverlayWidget` (`:6381`) | MEMBER | Relayout overlay widget. | No current root implementation or caller; the reviewed handle is self-positioned and external hosts remain root/common-only. | DEFERRED (the reviewed target adds no explicit overlay layout operation) |
| U08-287 | generated `removeOverlayWidget` (`:6385`) | MEMBER | Remove overlay widget. | Reviewed root remove accepts the same opaque `OverlayWidget` handle rather than an id. | DEFERRED (align removal with the reviewed immutable handle) |
| U08-288 | generated `addGlyphMarginWidget` (`:6389`) | MEMBER | Add glyph widget. | No root method. | N-A (glyph widgets excluded) |
| U08-289 | generated `layoutGlyphMarginWidget` (`:6394`) | MEMBER | Relayout glyph widget. | No root method. | N-A (glyph widgets excluded) |
| U08-290 | generated `removeGlyphMarginWidget` (`:6398`) | MEMBER | Remove glyph widget. | No root method. | N-A (glyph widgets excluded) |
| U08-291 | generated `changeViewZones` (`:6402`) | MEMBER | Transactional zone change. | Root method with private type. | DEFERRED (browser contract owner pending) |
| U08-292 | generated `getOffsetForColumn` (`:6408`) | MEMBER | Rendered horizontal offset. | Root method. | TESTED |
| U08-293 | generated `getWidthOfLine` (`:6409`) | MEMBER | Rendered line width. | Root method. | TESTED |
| U08-294 | generated `render` (`:6413`) | MEMBER | Immediate render. | Internal only. | N-A (implementation method excluded) |
| U08-295 | generated `renderAsync` (`:6417`) | MEMBER | Deferred render. | Internal only. | N-A (implementation method excluded) |
| U08-296 | generated `getTargetAtClientPoint` (`:6424`) | MEMBER | Hit test. | Internal mouse host. | N-A (mouse-target API excluded) |
| U08-297 | generated `getScrolledVisiblePosition` (`:6432-6436`) | MEMBER | Scroll-relative geometry. | Root method. | TESTED |
| U08-298 | scrolled result `top` (`:6433`) | MEMBER | Relative top. | Local result field. | TESTED |
| U08-299 | scrolled result `left` (`:6434`) | MEMBER | Relative left. | Local result field. | TESTED |
| U08-300 | scrolled result `height` (`:6435`) | MEMBER | Line height. | Local result field. | TESTED |
| U08-301 | generated `applyFontInfo` (`:6440`) | MEMBER | Apply font DOM styling. | No root method. | N-A (DOM helper excluded) |
| U08-302 | generated `setBanner` (`:6441`) | MEMBER | Own banner DOM. | No root method. | N-A (banner excluded) |
| U08-303 | generated optional `handleInitialized` (`:6446`) | MEMBER | Host post-init hook. | Internal only. | N-A (host lifecycle excluded) |
| U08-304 | generated `IDiffEditor` and later diff siblings (`:6452-6517`) | MEMBER | Diff public surface. | No local diff viewer. | N-A (diff cluster excluded) |
| U08-305 | `invokeWithinContext` absent from generated `ICodeEditor` (`:6002-6447`) | MEMBER | Confirms VS Code service locator is intentionally not Monaco public API. | Target typed capabilities should likewise avoid locator exposure. | N-A (absence is the required boundary) |
| U08-306 | `create` requires an empty host DOM (`:948-950`) | DOM | Constructor owns children under the host. | Viewer browser create owns host subtree. | TESTED |
| U08-307 | `create` reads host DOM size (`:950`) | DOM | Initial layout derives from container. | Viewer layout/browser tests. | TESTED |
| U08-308 | generated `IEditorDecorationsCollection` (`:2887-2921`) | MEMBER | Complete public collection returned by generated `IEditor`. | Root has the accepted reduced collection, but omits generated `onDidChange` and `has`. | DEFERRED (review the two missing members while retaining the current public collection) |
| U08-309 | generated decoration collection `onDidChange` (`:2892`) | MEMBER | Fires for external decoration mutations not caused by the collection. | No root collection event. | DEFERRED (decide whether the accepted reduced collection needs this semantic event) |
| U08-310 | generated decoration collection `length` (`:2896`) | MEMBER | Current owned decoration count. | `EditorDecorationsCollection::length`; exercised by `viewer/quick_diff_host_wbtest.mbt`. | TESTED |
| U08-311 | generated decoration collection `getRange` (`:2900`) | MEMBER | Nullable range lookup by collection index. | `EditorDecorationsCollection::get_range`; no direct local caller. | PORTED |
| U08-312 | generated decoration collection `getRanges` (`:2904`) | MEMBER | All currently resolved ranges. | `EditorDecorationsCollection::get_ranges`; no direct local caller. | PORTED |
| U08-313 | generated decoration collection `has` (`:2908`) | MEMBER | Identity-membership query for a model decoration. | No root collection method. | DEFERRED (decide whether the reduced collection needs object-identity membership) |
| U08-314 | generated decoration collection `set` (`:2912`) | MEMBER | Replace all owned decorations and return new ids. | `EditorDecorationsCollection::set`. | PORTED |
| U08-315 | generated decoration collection `append` (`:2916`) | MEMBER | Append owned decorations and return appended ids. | `EditorDecorationsCollection::append`; no direct local caller. | PORTED |
| U08-316 | generated decoration collection `clear` (`:2920`) | MEMBER | Remove all collection-owned decorations. | `EditorDecorationsCollection::clear`. | PORTED |
| U08-317 | generated `ContentWidgetPositionPreference` (`:5559-5572`) | MEMBER | Closed placement preference for public content widgets. | No current root content-widget implementation or caller; external hosts remain root/common-only. | DEFERRED (the reviewed target does not add the full content-widget API) |
| U08-318 | generated content preference `EXACT = 0` (`:5563`) | CONST | Place exactly at the anchor position. | Private runtime has the branch, but the full content-widget facade has no current root caller. | DEFERRED (external hosts remain root/common-only) |
| U08-319 | generated content preference `ABOVE = 1` (`:5567`) | CONST | Prefer placement above the anchor. | Private runtime has the branch, but the full content-widget facade has no current root caller. | DEFERRED (external hosts remain root/common-only) |
| U08-320 | generated content preference `BELOW = 2` (`:5571`) | CONST | Prefer placement below the anchor. | Private runtime has the branch, but the full content-widget facade has no current root caller. | DEFERRED (external hosts remain root/common-only) |
| U08-321 | generated `IContentWidgetPosition` (`:5577-5606`) | MEMBER | Public content-widget placement descriptor. | No current root content-widget implementation or caller; external hosts remain root/common-only. | DEFERRED (the reviewed target does not expose this descriptor) |
| U08-322 | generated content `position` (`:5589`) | MEMBER | Nullable primary model anchor. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U08-323 | generated content `secondaryPosition?` (`:5596`) | MEMBER | Optional same-line secondary anchor. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U08-324 | generated content `preference` (`:5600`) | MEMBER | Ordered placement preferences. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U08-325 | generated content `positionAffinity?` (`:5605`) | MEMBER | Chooses a view position for ambiguous projection. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U08-326 | generated `IContentWidget` (`:5611-5650`) | MEMBER | Public content-widget callback/DOM contract. | No current root content-widget implementation or caller; external hosts remain root/common-only. | DEFERRED (the reviewed target does not add the full content-widget API) |
| U08-327 | generated content `allowEditorOverflow?` (`:5615`) | MEMBER | Allows the widget outside the editor view DOM. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U08-328 | generated content `useDisplayNone?` (`:5620`) | MEMBER | Hides off-screen widgets with `display:none`. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U08-329 | generated content `suppressMouseDown?` (`:5624`) | MEMBER | Cancels widget mousedown default behavior. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U08-330 | generated content `getId` (`:5628`) | MEMBER | Stable widget-map identity. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U08-331 | generated content `getDomNode` (`:5632`) | MEMBER | Required widget DOM node. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U08-332 | generated content `getPosition` (`:5637`) | MEMBER | Nullable live placement query. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U08-333 | generated content `beforeRender?` (`:5643`) | MEMBER | Optional pre-layout dimension callback. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U08-334 | generated content `afterRender?` (`:5649`) | MEMBER | Optional selected-placement/coordinate callback. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U08-335 | generated `IContentWidgetRenderedCoordinate` (`:5655-5664`) | MEMBER | Observable post-render coordinate payload. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U08-336 | generated rendered content `top` (`:5659`) | MEMBER | Top relative to editor content. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U08-337 | generated rendered content `left` (`:5663`) | MEMBER | Left relative to editor content. | No current root content-widget implementation or caller. | DEFERRED (external hosts remain root/common-only) |
| U08-338 | generated `OverlayWidgetPositionPreference` (`:5669-5682`) | MEMBER | Closed corner/center placement preference. | The reviewed `OverlayWidget` reduction is self-positioned and fixes `getPosition` to null. | DEFERRED (no current root implementation/caller needs positioned overlays; external hosts remain root/common-only) |
| U08-339 | generated overlay preference `TOP_RIGHT_CORNER = 0` (`:5673`) | CONST | Top-right placement. | The reviewed handle is self-positioned and exposes no preference enum. | DEFERRED (no current root implementation/caller; external hosts remain root/common-only) |
| U08-340 | generated overlay preference `BOTTOM_RIGHT_CORNER = 1` (`:5677`) | CONST | Bottom-right placement. | The reviewed handle is self-positioned and exposes no preference enum. | DEFERRED (no current root implementation/caller; external hosts remain root/common-only) |
| U08-341 | generated overlay preference `TOP_CENTER = 2` (`:5681`) | CONST | Top-center placement. | The reviewed handle is self-positioned and exposes no preference enum. | DEFERRED (no current root implementation/caller; external hosts remain root/common-only) |
| U08-342 | generated `IOverlayWidgetPositionCoordinates` (`:5687-5696`) | MEMBER | Explicit editor-relative overlay coordinates. | The reviewed handle is self-positioned and exposes no coordinate descriptor. | DEFERRED (no current root implementation/caller; external hosts remain root/common-only) |
| U08-343 | generated overlay coordinate `top` (`:5691`) | MEMBER | Editor-relative top. | The reviewed handle is self-positioned and exposes no coordinate descriptor. | DEFERRED (no current root implementation/caller; external hosts remain root/common-only) |
| U08-344 | generated overlay coordinate `left` (`:5695`) | MEMBER | Editor-relative left. | The reviewed handle is self-positioned and exposes no coordinate descriptor. | DEFERRED (no current root implementation/caller; external hosts remain root/common-only) |
| U08-345 | generated `IOverlayWidgetPosition` (`:5701-5711`) | MEMBER | Preferred or explicit overlay placement descriptor. | The reviewed handle fixes `getPosition` to null/self-positioned and exposes no position descriptor. | DEFERRED (no current root implementation/caller; external hosts remain root/common-only) |
| U08-346 | generated overlay `preference` (`:5705`) | MEMBER | Enum, explicit coordinates, or host-positioned null. | Reviewed reduction selects only the null/self-positioned branch. | DEFERRED (positioned preferences have no current root implementation/caller) |
| U08-347 | generated overlay `stackOrdinal?` (`:5710`) | MEMBER | Stable stack ordering for shared preferences. | The reviewed self-positioned handle exposes no stack ordinal. | DEFERRED (no current root implementation/caller; external hosts remain root/common-only) |
| U08-348 | generated `IOverlayWidget` (`:5716-5742`) | MEMBER | Public overlay-widget callback/DOM contract. | Reviewed target is a browser-owned opaque unmanaged `OverlayWidget` handle with immutable id/node and fixed null position. | DEFERRED (implement only the reviewed reduced handle, not the complete callback contract) |
| U08-349 | generated overlay `onDidLayout?` (`:5720`) | MEMBER | Optional widget-owned layout invalidation event. | The reviewed unmanaged handle owns no layout event. | DEFERRED (no current root implementation/caller; external hosts remain root/common-only) |
| U08-350 | generated overlay `allowEditorOverflow?` (`:5724`) | MEMBER | Allows rendering outside the view DOM. | The reviewed unmanaged handle exposes no overflow preference. | DEFERRED (no current root implementation/caller; external hosts remain root/common-only) |
| U08-351 | generated overlay `getId` (`:5728`) | MEMBER | Stable widget-map identity. | Root `overlay_widget(id, node)` stores immutable identity in the opaque browser-owned handle. | DEFERRED (implement the reviewed handle factory and accessor) |
| U08-352 | generated overlay `getDomNode` (`:5732`) | MEMBER | Required overlay DOM node. | Root `overlay_widget(id, node)` stores the immutable DOM node in the opaque browser-owned handle. | DEFERRED (implement the reviewed handle factory and accessor) |
| U08-353 | generated overlay `getPosition` (`:5737`) | MEMBER | Nullable live placement query. | Reviewed handle has fixed null position, making every overlay self-positioned. | DEFERRED (accepted seam reduction; no positioned-overlay caller exists) |
| U08-354 | generated overlay `getMinContentWidthInPx?` (`:5741`) | MEMBER | Optional contribution to editor scroll width. | The reviewed unmanaged handle exposes no minimum-width callback. | DEFERRED (no current root implementation/caller; external hosts remain root/common-only) |
| U08-355 | generated `IEditorMouseEvent` (`:5964-5967`) | MEMBER | Public hit-tested editor mouse event. | Root has the pair but owns it at the wrong package. | DEFERRED (move the canonical wrapper to `viewer/browser`) |
| U08-356 | generated full mouse `event` (`:5965`) | MEMBER | Raw browser mouse event. | Root wraps current `viewer/browser.EditorMouseEvent`; that raw type becomes `EditorDomMouseEvent`. | DEFERRED (rename the raw event while moving the hit-tested wrapper) |
| U08-357 | generated full mouse `target` (`:5966`) | MEMBER | Required hit-test target. | Existing browser `MouseTarget` is the mapped union. | DEFERRED (move the wrapper without duplicating the target type) |
| U08-358 | generated `IPartialEditorMouseEvent` (`:5969-5972`) | MEMBER | Public mouse event whose hit target may be absent. | Root has the pair but owns it at the wrong package. | DEFERRED (move the canonical wrapper to `viewer/browser`) |
| U08-359 | generated partial mouse `event` (`:5970`) | MEMBER | Raw browser mouse event. | Root wraps the raw event that becomes `EditorDomMouseEvent`. | DEFERRED (rename the raw event while moving the hit-tested wrapper) |
| U08-360 | generated partial mouse nullable `target` (`:5971`) | MEMBER | Hit-test target may be null. | Root `PartialEditorMouseEvent.target : MouseTarget?` preserves the distinction. | DEFERRED (move the wrapper without an adapter) |

## Deviations and target implications

- **Readonly is a facade scope, not source `readOnly`.** Monaco exposes an
  editable editor plus a `readOnly` option. The target Viewer intentionally
  excludes edit commands, undo, actions, paste, and command registration, but
  retains `set_value` as host-driven whole-buffer replacement. That operation
  does not reopen interactive editing, undo, or actions; the Viewer is not a
  literal port of Monaco's configurable `readOnly` mode.
- **`tabSize` and `theme` have different upstream owners.** `tabSize` is in
  `IGlobalEditorOptions` and affects the model; `theme` is global/standalone
  construction state. Neither is an `editorOptions.ts` registration in U01.
  Root `tab_size` remains local model/view-model configuration because
  `TextSnapshot` has no model-options surface; root theme remains
  standalone/global construction state. Opaque options adapt both without
  claiming `IEditorOptions` ownership.
- **Typed MoonBit deliberately erases dynamic TypeScript validation and
  overloads.** Rows for invalid object shapes, non-number arguments, and the
  four `setSelection` structural/class overloads are `N-A`; this is not missing
  runtime behavior. Numeric range clamping and semantic defaults remain real
  behavior and are not erased by typing.
- **Service topology is a seam adaptation.** VS Code's constructor injection
  and internal `invokeWithinContext` are not Monaco public API. Monaco's public
  override bag is opaque and open-ended. The target `ViewerServices` instead
  needs closed, minimal language/marker/feature capability records proven by
  local call sites. It must not reproduce either a string-keyed override bag or
  a general service locator.
- **View state is currently reduced.** Monaco stores all cursor states, an
  anchor-based viewport state, and per-contribution state. Viewer stores a
  smaller selection/scroll snapshot. Breaking compatibility is allowed, but
  the public state must be opaque or documented as a reduced Viewer state; it
  cannot reuse the Monaco name while silently claiming the source shape.
- **Cursor selection nullability is already aligned.** Source
  `oldSelections` distinguishes `null` from `[]`; root
  `CursorSelectionChangedEvent.old_selections` is optional and its tests cover
  `None` plus populated history. Moving the payload to `common/editor_api`
  preserves that shape without an adapter.
- **Public scrolling is deliberately immediate.** Source reveal methods
  default to `Smooth`, setters default to `Immediate`, and both accept
  `ScrollType`. The reviewed Viewer exposes no public scroll enum: all public
  `reveal_*` and `set_scroll_*` methods fix `Immediate`. `smooth_scrolling`
  affects only physical-input/internal-cursor smooth paths, including their
  at-most-one-line downgrade.
- **Widget support is an explicit narrow seam.** Monaco exposes complete
  content, overlay, and glyph widget triplets. Full content widgets and glyph
  widgets are not accepted target APIs. The overlay target is only a
  browser-owned opaque unmanaged `OverlayWidget` handle created by root
  `overlay_widget(id, node)`, with immutable id/node and `getPosition` fixed to
  null/self-positioned; root add/remove accept the handle. Positioned overlay
  preferences/coordinates, overflow, layout events, minimum width, and
  `layoutOverlayWidget` remain `DEFERRED`: no current root implementation or
  caller needs them and external hosts remain root/common-only.
- **The construction host outlives disposal.** Public
  `get_container_dom_node` returns the original non-null browser host before
  and after disposal. The host is retained rather than cleared; the private
  headless construction seam must not call the browser-only method.
- **View zones are public descriptors, not rendered objects.** All source and
  generated fields, default/precedence rules, callbacks, and DOM contracts are
  accounted. The new `viewer/browser` type may be a MoonBit-shaped descriptor,
  but mutable ids, cached height, attached DOM state, and render data remain
  private to the view implementation.
- **Contribution lookup is upstream-public but target-private.** Both browser
  and generated contracts expose generic string lookup, and view state names
  contribution slots. The single-ownership plan provides typed internal
  lookup; after it lands, root `EditorContribution`, instantiation modes, and
  `Viewer::get_contribution` are removed without compatibility aliases.
- **Generated declarations are an independent contract.** U08 intentionally
  repeats source declarations. A source implementation being correct does not
  prove the generated MoonBit interface is clean; the final API gate must diff
  and compile-test the external consumer surface.

## Branch-derived validation obligations

Implementation must link exact tests for these axes; repository-green checks
alone do not establish parity:

- default options and every accepted enum variant, plus invalid/boundary
  numeric normalization where the typed constructor still accepts numbers;
- distinct `wordWrap` boolean reduction, standalone `WrappingIndent.None`
  default, model `tabSize`, and construction-only theme handling;
- default services and custom language/marker/agent-feedback/quick-diff
  capabilities without concrete implementation types in generated root API,
  including custom common feature handles built through the frozen
  all-callback constructors and marker decorations built from
  `MarkerServiceHandle`;
- public browser construction with an empty/sized DOM host, non-null original
  host lookup before and after disposal, and a private headless white-box path
  that never calls the browser-only lookup;
- no model, initial attach, detached-to-null no-op, same-model no-op, model
  swap, model removal, external model disposal, and Viewer disposal, including
  will/did event and outgoing-decoration ordering;
- cursor position-before-selection delivery, primary/secondary ordering,
  canonical reason/source propagation, model versions, nullable old
  selections, reentrancy, and content-flush ordering;
- all detached getter sentinels; independent scroll values/flags; partial
  one-axis and two-axis updates; public fixed-`Immediate` reveal/setter paths;
  physical-input/internal-cursor smooth paths with the at-most-one-line
  downgrade; wrapped and hidden geometry; and reveal branch matrices;
- save/restore with no model, missing cursor/view state, empty and nonempty
  cursor state, reduced viewport state, contribution-state omission, and
  visible-line stabilization after restore;
- view-zone zero/first/middle/last anchors, hidden lines, affinities, ordinal
  ties, pixel/line/default height precedence, min width, callback timing,
  suppress-mousedown `preventDefault`, layout/remove unknown ids, and callback
  skipping without a real view;
- reduced overlay handles: immutable factory id/node, fixed null/self-position,
  add before attach, add live, duplicate id, remove unknown/known handle,
  model-swap replay, detach, and disposal, while exporting no content-widget or
  explicit overlay-layout API; and
- compile-only external-consumer fixtures proving the public constructor,
  options, event, service, reduced overlay-handle, and zone contracts while
  rejecting the headless constructor, contribution types/lookup, view
  implementation types, concrete feature services, debug hooks, DI access,
  commands, interactive editing, content/glyph widgets, positioned overlay
  contracts and layout, and diff APIs.

## Closing audit

- [x] `vscode` HEAD equals
      `b18492a288de038fbc7643aae6de8247029d11bd`.
- [x] All eight manifest files were read at the pinned commit and their line
      counts/file hashes were recorded.
- [x] U03, U06, and U07 are complete source units; every meaningful member,
      constant, branch, exit, and lifetime atom has a row.
- [x] Every large-file cluster is bounded by exact ranges and all excluded
      sibling families are named.
- [x] Every scoped option declaration is paired with its registration/default
      or complete validator/computer behavior; `tabSize` and `theme` are mapped
      to their actual generated standalone owner.
- [x] Every `IEditor`, `ICodeEditor`, editor-decoration-collection, view-zone,
      content/overlay-widget declaration, mouse-event wrapper,
      service-override, construction, cursor-event, and standalone export
      member in scope has a stable row.
- [x] Widget implementation branches include detached sentinels, validation
      exits, model transition ordering, event projection, DOM ownership,
      widget replay, view-zone callback suppression, and teardown.
- [x] Generated declarations were audited independently of their source
      declarations.
- [x] Mechanical validation found 1,322 unique, gap-free row ids, no invalid
      terminal status, and three reconciled partitions (unit, kind, status).
- [x] `git diff --check` is clean for this companion.

**Historical review gate:** no public API, type owner, option/service facade,
widget or view-zone contract, contribution visibility, or generated interface
changed from this ledger until the user explicitly approved Gate A on
2026-07-14.
