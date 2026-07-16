# Gate A: MoonBit-Native API and Internal-Boundary Inventory

Date: 2026-07-16
Plan: `moonbit-native-api-visibility-and-internal-boundary-refactor.md`
Git snapshot: `0122e257201043b722f0eb177f88771a9c0b965d`

This companion is the closed inventory and review artifact required by Gate A.
It is temporary active-plan material and is deleted with the detailed plan
after the completed summary is folded into `HISTORY.md`.

## Baseline and Commands

```text
moon 0.1.20260713 (75c7e1f 2026-07-13)
moonc v0.10.4+ade96c819 (2026-07-13)
moonrun 0.1.20260713 (75c7e1f 2026-07-13)
```

```sh
moon version --all
moon ide analyze
moon ide analyze --no-check
moon ide find-references <symbol> --loc <path:line> --no-check
moon test viewer/browser/controller --target js
just check
```

The first unrefreshed `moon ide analyze --no-check` reported 152 stale items
and obsolete folding declarations. A checked analyzer run refreshed semantic
state; the authoritative repeated `--no-check` result is 133 annotations
across 26 packages, matching the frozen plan baseline.

Tracked product-source counts remain:

- 295 `pub(all)` declarations;
- 10 `pub(open)` declarations;
- 64 black-box `*_test.mbt` files;
- 132 white-box `*_wbtest.mbt` files.

The public-constructor count is 96, not 94: the original regex missed generic
`Emitter::new` and `MicrotaskEmitter::new`.

## Visibility Ledger

Consumer codes:

- `EF`: external facade/example contract;
- `RV`: root `viewer`;
- `IP`: another implementation package;
- `SW`: shell/workbench;
- `BS`: browser scenario;
- `BB`: black-box test;
- `WB`: white-box test;
- `NC`: no dependent caller or same-package only;
- `EXT`: documented external provider/host contract.

| Package | Declaration | Location | Disposition | Consumers |
|---|---|---|---|---|
| `base/browser` | `StandardMouseEvent` | `base/browser/mouse_event.mbt:22` | `NARROW_PUBLIC` | `IP` |
| `base/common` | `OffsetRange` | `base/common/text.mbt:17` | `NARROW_PUBLIC` | `RV,IP,SW,BS,BB,WB` |
| `internal/shell/remote_protocol` | `ClientPacketDecodeResult` | `internal/shell/remote_protocol/protocol.mbt:171` | `NARROW_PUBLIC` | `SW,BB` |
| `internal/shell/remote_protocol` | `DefinitionResultPayload` | `internal/shell/remote_protocol/protocol.mbt:118` | `KEEP_ALL` | `SW,BB` |
| `internal/shell/remote_protocol` | `ProtocolError` | `internal/shell/remote_protocol/protocol.mbt:36` | `NARROW_PUBLIC` | `SW,BB,WB` |
| `internal/shell/remote_protocol` | `ProtocolNegotiation` | `internal/shell/remote_protocol/protocol.mbt:185` | `NARROW_PUBLIC` | `BB` |
| `internal/shell/remote_protocol` | `ServerPacketDecodeResult` | `internal/shell/remote_protocol/protocol.mbt:178` | `NARROW_PUBLIC` | `SW,BB` |
| `internal/shell/workspace` | `DocumentContent` | `internal/shell/workspace/filesystem.mbt:25` | `NARROW_PUBLIC` | `BB,EXT` |
| `internal/shell/workspace` | `DocumentError` | `internal/shell/workspace/document.mbt:14` | `NARROW_PUBLIC` | `SW,IP` |
| `internal/shell/workspace` | `DocumentSnapshot` | `internal/shell/workspace/document.mbt:3` | `NARROW_PUBLIC` | `SW,IP,BB,WB` |
| `internal/shell/workspace` | `FileChange` | `internal/shell/workspace/filesystem.mbt:51` | `KEEP_ALL` | `EXT` |
| `internal/shell/workspace` | `FileChangeType` | `internal/shell/workspace/filesystem.mbt:43` | `KEEP_ALL` | `EXT` |
| `internal/shell/workspace` | `FileSystemProviderError` | `internal/shell/workspace/filesystem.mbt:17` | `NARROW_PUBLIC` | `EF,SW,IP,WB` |
| `internal/shell/workspace` | `SourcePath` | `internal/shell/workspace/source.mbt:4` | `NARROW_PUBLIC` | `BB` |
| `internal/shell/workspace` | `SourcePathResult` | `internal/shell/workspace/source.mbt:26` | `NARROW_PUBLIC` | `NC` |
| `internal/shell/workspace` | `WatchOptions` | `internal/shell/workspace/filesystem.mbt:58` | `NARROW_PUBLIC` | `EXT` |
| `language` | `LanguageFilter` | `language/selectors.mbt:3` | `NARROW_PUBLIC` | `SW,BB` |
| `language` | `DefinitionProvider` | `language/providers.mbt:77` | `KEEP_OPEN` | `EXT` |
| `language` | `ReferencesProvider` | `language/providers.mbt:88` | `KEEP_OPEN` | `EXT` |
| `platform/log` | `LogService` | `platform/log/log.mbt:119` | `NARROW_PUBLIC` | `EF,RV,SW,BS,WB` |
| `platform/log` | `MemoryLogger` | `platform/log/log.mbt:53` | `NARROW_PUBLIC` | `BS,WB` |
| `platform/log` | `MultiplexLogger` | `platform/log/log.mbt:90` | `NARROW_PUBLIC` | `NC` |
| `platform/log` | `NullLogger` | `platform/log/log.mbt:31` | `NARROW_PUBLIC` | `NC` |
| `syntax` | `TokenizationChangedEvent` | `syntax/tokenizer.mbt:91` | `NARROW_PUBLIC` | `NC` |
| `tests/browser/moonbit/support` | `BrowserTestContext` | `tests/browser/moonbit/support/assert.mbt:3` | `NARROW_PUBLIC` | `BS` |
| `viewer/browser` | `CoordinatesRelativeToEditor` | `viewer/browser/editor_dom.mbt:70` | `NARROW_PUBLIC` | `IP` |
| `viewer/browser` | `EditorPagePosition` | `viewer/browser/editor_dom.mbt:59` | `NARROW_PUBLIC` | `IP` |
| `viewer/browser/config` | `CharWidthRequest` | `viewer/browser/config/char_width_reader.mbt:15` | `MAKE_PRIVATE` | `NC,WB` |
| `viewer/browser/config` | `CharWidthRequestType` | `viewer/browser/config/char_width_reader.mbt:8` | `MAKE_PRIVATE` | `NC,WB` |
| `viewer/browser/controller` | `DragScrollingDirection` | `viewer/browser/controller/drag_scrolling.mbt:24` | `MAKE_PRIVATE` | `NC` |
| `viewer/browser/controller` | `ElementPath` | `viewer/browser/controller/mouse_target.mbt:244` | `MAKE_PRIVATE` | `BB` |
| `viewer/browser/view` | `ContentWidgetRenderedCoordinate` | `viewer/browser/view/content_widgets.mbt:46` | `NARROW_PUBLIC` | `IP,WB` |
| `viewer/browser/view` | `HorizontalPosition` | `viewer/browser/view/rendering_context.mbt:249` | `NARROW_PUBLIC` | `IP,WB` |
| `viewer/browser/view` | `View` | `viewer/browser/view/view.mbt:13` | `NARROW_PUBLIC` | `RV,WB` |
| `viewer/browser/view` | `ViewCursorRenderData` | `viewer/browser/view/view_cursors.mbt:187` | `NARROW_PUBLIC` | `IP` |
| `viewer/browser/view` | `ViewLineOptions` | `viewer/browser/view/view_line.mbt:18` | `NARROW_PUBLIC` | `RV,WB` |
| `viewer/browser/view` | `ViewLinesConfiguration` | `viewer/browser/view/view_lines.mbt:10` | `NARROW_PUBLIC` | `RV,WB` |
| `viewer/common/config` | `BareFontInfo` | `viewer/common/config/font_info.mbt:110` | `NARROW_PUBLIC` | `RV,IP,BB,WB` |
| `viewer/common/config` | `EditorFontDefaults` | `viewer/common/config/font_info.mbt:74` | `NARROW_PUBLIC` | `NC` |
| `viewer/common/core` | `Selection` | `viewer/common/core/selection.mbt:21` | `NARROW_PUBLIC` | `RV,IP,BS,WB` |
| `viewer/common/cursor` | `CursorState` | `viewer/common/cursor/cursor_event_state.mbt:4` | `NARROW_PUBLIC` | `RV,IP,WB` |
| `viewer/common/cursor` | `CursorStateChange` | `viewer/common/cursor/cursor_event_state.mbt:121` | `NARROW_PUBLIC` | `IP` |
| `viewer/common/cursor` | `PartialCursorState` | `viewer/common/cursor/cursor_event_state.mbt:50` | `NARROW_PUBLIC` | `IP` |
| `viewer/common/cursor` | `PartialModelCursorState` | `viewer/common/cursor/cursor_event_state.mbt:20` | `NARROW_PUBLIC` | `WB` |
| `viewer/common/cursor` | `PartialViewCursorState` | `viewer/common/cursor/cursor_event_state.mbt:34` | `NARROW_PUBLIC` | `WB` |
| `viewer/common/cursor` | `SingleCursorState` | `viewer/common/cursor/single_cursor_state.mbt:23` | `NARROW_PUBLIC` | `RV,IP,WB` |
| `viewer/common/diff` | `DefaultLinesDiffComputer` | `viewer/common/diff/default_lines_diff_computer.mbt:35` | `NARROW_PUBLIC` | `NC` |
| `viewer/common/diff` | `DetailedLineRangeMapping` | `viewer/common/diff/range_mapping.mbt:112` | `NARROW_PUBLIC` | `IP,BB,WB` |
| `viewer/common/diff` | `LineRangeMapping` | `viewer/common/diff/range_mapping.mbt:28` | `NARROW_PUBLIC` | `NC` |
| `viewer/common/diff` | `LinesDiff` | `viewer/common/diff/lines_diff_computer.mbt:28` | `NARROW_PUBLIC` | `BB` |
| `viewer/common/diff` | `MovedText` | `viewer/common/diff/lines_diff_computer.mbt:41` | `NARROW_PUBLIC` | `NC` |
| `viewer/common/diff` | `RangeMapping` | `viewer/common/diff/range_mapping.mbt:155` | `NARROW_PUBLIC` | `BB` |
| `viewer/common/markers` | `Marker` | `viewer/common/markers/markers.mbt:255` | `NARROW_PUBLIC` | `IP,WB` |
| `viewer/common/markers` | `MarkerData` | `viewer/common/markers/markers.mbt:147` | `KEEP_ALL` | `RV,BB,WB,EXT` |
| `viewer/common/markers` | `MarkerReadOptions` | `viewer/common/markers/markers.mbt:304` | `KEEP_ALL` | `BB,WB,EXT` |
| `viewer/common/markers` | `MarkerStatistics` | `viewer/common/markers/markers.mbt:295` | `NARROW_PUBLIC` | `NC` |
| `viewer/common/markers` | `MarkerTag` | `viewer/common/markers/markers.mbt:96` | `KEEP_ALL` | `BB,WB,EXT` |
| `viewer/common/markers` | `RelatedInformation` | `viewer/common/markers/markers.mbt:134` | `KEEP_ALL` | `EXT` |
| `viewer/common/markers` | `ResourceMarker` | `viewer/common/markers/markers.mbt:245` | `KEEP_ALL` | `EXT` |
| `viewer/common/model` | `InternalModelContentChangeEvent` | `viewer/common/model/text_model_events.mbt:158` | `NARROW_PUBLIC` | `IP` |
| `viewer/common/model` | `IntervalTree` | `viewer/common/model/interval_tree.mbt:407` | `NARROW_PUBLIC` | `BB` |
| `viewer/common/model` | `ModelContentChange` | `viewer/common/model/text_model_events.mbt:127` | `NARROW_PUBLIC` | `NC` |
| `viewer/common/model` | `ModelContentChangedEvent` | `viewer/common/model/text_model_events.mbt:142` | `NARROW_PUBLIC` | `RV,BB,WB` |
| `viewer/common/model` | `ModelDecorationOptions` | `viewer/common/model/decorations.mbt:105` | `NARROW_PUBLIC` | `RV,IP,BS,BB,WB` |
| `viewer/common/model` | `ModelDecorationsChangeAccessor` | `viewer/common/model/text_model_decorations.mbt:527` | `NARROW_PUBLIC` | `IP,WB` |
| `viewer/common/model` | `ModelDecorationsChangedEvent` | `viewer/common/model/decorations.mbt:181` | `NARROW_PUBLIC` | `WB` |
| `viewer/common/model` | `ModelRawChange` | `viewer/common/model/text_model_events.mbt:55` | `NARROW_PUBLIC` | `NC` |
| `viewer/common/model` | `ModelRawContentChangedEvent` | `viewer/common/model/text_model_events.mbt:88` | `NARROW_PUBLIC` | `BB,WB` |
| `viewer/common/model` | `NodeColor` | `viewer/common/model/interval_tree.mbt:50` | `NARROW_PUBLIC` | `NC` |
| `viewer/common/model` | `TextSnapshot` | `viewer/common/model/text_snapshot.mbt:10` | `NARROW_PUBLIC` | `RV,BS,BB,WB` |
| `viewer/common/model` | `WordAtPosition` | `viewer/common/model/word_helper.mbt:15` | `NARROW_PUBLIC` | `WB` |
| `viewer/common/tokens` | `ContiguousTokensStoreChange` | `viewer/common/tokens/contiguous_tokens_store.mbt:25` | `NARROW_PUBLIC` | `WB` |
| `viewer/common/tokens` | `ContiguousTokensStoreUpdate` | `viewer/common/tokens/contiguous_tokens_store.mbt:33` | `NARROW_PUBLIC` | `IP,WB` |
| `viewer/common/tokens` | `ViewLineTokens` | `viewer/common/tokens/line_tokens.mbt:29` | `NARROW_PUBLIC` | `IP,WB` |
| `viewer/common/view_layout` | `CharacterMapping` | `viewer/common/view_layout/character_mapping.mbt:19` | `NARROW_PUBLIC` | `IP,WB` |
| `viewer/common/view_layout` | `CharacterMappingEntry` | `viewer/common/view_layout/character_mapping.mbt:11` | `NARROW_PUBLIC` | `NC` |
| `viewer/common/view_layout` | `EditorScrollDimensions` | `viewer/common/view_layout/scrollable.mbt:734` | `NARROW_PUBLIC` | `BB` |
| `viewer/common/view_layout` | `InlineDecoration` | `viewer/common/view_layout/inline_decorations.mbt:3` | `NARROW_PUBLIC` | `IP` |
| `viewer/common/view_layout` | `LineDecoration` | `viewer/common/view_layout/line_decorations.mbt:3` | `NARROW_PUBLIC` | `RV,IP,BB,WB` |
| `viewer/common/view_layout` | `LineDecorationsNormalizer` | `viewer/common/view_layout/line_decorations.mbt:84` | `NARROW_PUBLIC` | `BB` |
| `viewer/common/view_layout` | `LinePart` | `viewer/common/view_layout/line_part.mbt:28` | `NARROW_PUBLIC` | `RV,IP,BB,WB` |
| `viewer/common/view_layout` | `RenderLineInput` | `viewer/common/view_layout/view_line_renderer_input.mbt:3` | `NARROW_PUBLIC` | `RV,IP,BB,WB` |
| `viewer/common/view_layout` | `RenderLineOutput` | `viewer/common/view_layout/character_mapping.mbt:178` | `NARROW_PUBLIC` | `NC` |
| `viewer/common/view_layout` | `RenderLineOutput2` | `viewer/common/view_layout/character_mapping.mbt:185` | `NARROW_PUBLIC` | `NC` |
| `viewer/common/view_layout` | `SavedScrollState` | `viewer/common/view_layout/view_layout.mbt:32` | `NARROW_PUBLIC` | `WB` |
| `viewer/common/view_layout` | `ScrollState` | `viewer/common/view_layout/scrollable.mbt:76` | `NARROW_PUBLIC` | `RV,WB` |
| `viewer/common/view_layout` | `SmoothScrollingUpdate` | `viewer/common/view_layout/scrollable.mbt:253` | `NARROW_PUBLIC` | `NC` |
| `viewer/common/view_layout` | `Viewport` | `viewer/common/view_layout/view_layout.mbt:24` | `NARROW_PUBLIC` | `NC` |
| `viewer/common/view_model` | `CursorMoveDirection` | `viewer/common/view_model/cursor_move_commands.mbt:12` | `KEEP_ALL` | `EXT,WB` |
| `viewer/common/view_model` | `DecorationToRender` | `viewer/common/view_model/margin_decorations.mbt:15` | `NARROW_PUBLIC` | `WB` |
| `viewer/common/view_model` | `InjectedText` | `viewer/common/view_model/injected_text.mbt:3` | `NARROW_PUBLIC` | `IP,WB` |
| `viewer/common/view_model` | `ModelLineProjection` | `viewer/common/view_model/model_line_projection.mbt:18` | `NARROW_PUBLIC` | `NC` |
| `viewer/common/view_model` | `ModelLineProjectionData` | `viewer/common/view_model/model_line_projection_data.mbt:22` | `NARROW_PUBLIC` | `WB` |
| `viewer/common/view_model` | `ModelLineProjectionSegment` | `viewer/common/view_model/model_line_projection_data.mbt:6` | `NARROW_PUBLIC` | `NC` |
| `viewer/common/view_model` | `ModelTokensChangedOutgoingEvent` | `viewer/common/view_model/cursor_event_dispatcher.mbt:100` | `NARROW_PUBLIC` | `WB` |
| `viewer/common/view_model` | `ProjectedLinePart` | `viewer/common/view_model/injected_text.mbt:34` | `NARROW_PUBLIC` | `NC` |
| `viewer/common/view_model` | `ProjectedLinePartKind` | `viewer/common/view_model/injected_text.mbt:23` | `NARROW_PUBLIC` | `NC` |
| `viewer/common/view_model` | `ProjectedTextLine` | `viewer/common/view_model/injected_text.mbt:53` | `NARROW_PUBLIC` | `WB` |
| `viewer/common/view_model` | `SimpleMoveArguments` | `viewer/common/view_model/cursor_move_commands.mbt:62` | `NARROW_PUBLIC` | `RV,WB` |
| `viewer/common/view_model` | `ViewLineData` | `viewer/common/view_model/view_line_data.mbt:6` | `NARROW_PUBLIC` | `RV,BB,WB` |
| `viewer/common/view_model` | `ViewModelOptions` | `viewer/common/view_model/view_model_options.mbt:3` | `NARROW_PUBLIC` | `RV,IP,BB,WB` |
| `viewer/common/view_model` | `ViewTokensChangedRange` | `viewer/common/view_model/model_tokens_outgoing.mbt:4` | `NARROW_PUBLIC` | `WB` |
| `viewer/common/view_model` | `ViewZonesChangedEvent` | `viewer/common/view_model/cursor_event_dispatcher.mbt:79` | `NARROW_PUBLIC` | `WB` |
| `viewer/common/view_model` | `WordBreak` | `viewer/common/view_model/monospace_line_breaks_computer.mbt:20` | `KEEP_ALL` | `EXT` |
| `viewer/contrib/agent_feedback` | `SessionEditorComment` | `viewer/contrib/agent_feedback/editor_comments.mbt:15` | `NARROW_PUBLIC` | `RV,IP` |
| `viewer/contrib/folding/browser` | `FoldRange` | `viewer/contrib/folding/browser/folding_ranges.mbt:39` | `NARROW_PUBLIC` | `WB` |
| `viewer/contrib/folding/browser` | `FoldRangesOrRegions` | `viewer/contrib/folding/browser/folding_ranges.mbt:425` | `NARROW_PUBLIC` | `NC` |
| `viewer/contrib/folding/browser` | `FoldSource` | `viewer/contrib/folding/browser/folding_ranges.mbt:17` | `NARROW_PUBLIC` | `WB` |
| `viewer/contrib/folding/browser` | `FoldingModelChangeEvent` | `viewer/contrib/folding/browser/folding_model.mbt:61` | `NARROW_PUBLIC` | `NC` |
| `viewer/contrib/folding/browser` | `SelectedLines` | `viewer/contrib/folding/browser/folding.mbt:34` | `NARROW_PUBLIC` | `NC` |
| `viewer/contrib/hover` | `ComputedHover` | `viewer/contrib/hover/hover_participants.mbt:15` | `NARROW_PUBLIC` | `NC` |
| `viewer/contrib/hover` | `ContentHoverComputer` | `viewer/contrib/hover/hover_participants.mbt:299` | `NARROW_PUBLIC` | `RV,WB` |
| `viewer/contrib/hover` | `HoverAnchorType` | `viewer/contrib/hover/hover_anchor.mbt:9` | `NARROW_PUBLIC` | `NC` |
| `viewer/contrib/hover` | `HoverComputeContext` | `viewer/contrib/hover/hover_participants.mbt:27` | `NARROW_PUBLIC` | `NC` |
| `viewer/contrib/hover` | `HoverController` | `viewer/contrib/hover/hover_controller.mbt:411` | `NARROW_PUBLIC` | `RV,IP,WB` |
| `viewer/contrib/hover` | `HoverEnabled` | `viewer/contrib/hover/hover_utils.mbt:22` | `NARROW_PUBLIC` | `NC` |
| `viewer/contrib/hover` | `HoverOpState` | `viewer/contrib/hover/hover_controller.mbt:222` | `NARROW_PUBLIC` | `NC` |
| `viewer/contrib/hover` | `HoverOperation` | `viewer/contrib/hover/hover_controller.mbt:238` | `NARROW_PUBLIC` | `WB` |
| `viewer/contrib/hover` | `HoverOperationOptions` | `viewer/contrib/hover/hover_controller.mbt:107` | `NARROW_PUBLIC` | `WB` |
| `viewer/contrib/hover` | `HoverOperationStartEffect` | `viewer/contrib/hover/hover_controller.mbt:209` | `NARROW_PUBLIC` | `NC` |
| `viewer/contrib/hover` | `HoverParticipantHandle` | `viewer/contrib/hover/hover_participants.mbt:90` | `NARROW_PUBLIC` | `IP,WB` |
| `viewer/contrib/hover` | `HoverParticipantRegistry` | `viewer/contrib/hover/hover_registry.mbt:7` | `NARROW_PUBLIC` | `WB` |
| `viewer/contrib/hover` | `HoverResult` | `viewer/contrib/hover/hover_controller.mbt:198` | `NARROW_PUBLIC` | `NC` |
| `viewer/contrib/hover` | `HoverSettings` | `viewer/contrib/hover/hover_utils.mbt:90` | `NARROW_PUBLIC` | `IP,WB` |
| `viewer/contrib/hover` | `HoverTiming` | `viewer/contrib/hover/hover_controller.mbt:61` | `NARROW_PUBLIC` | `WB` |
| `viewer/contrib/hover` | `HoverView` | `viewer/contrib/hover/hover_controller.mbt:2` | `NARROW_PUBLIC` | `NC` |
| `viewer/contrib/hover` | `HoverWidgetView` | `viewer/contrib/hover/hover_controller.mbt:957` | `NARROW_PUBLIC` | `RV` |
| `viewer/contrib/hover` | `MouseCloserState` | `viewer/contrib/hover/hover_widget_geometry.mbt:102` | `NARROW_PUBLIC` | `IP,WB` |
| `viewer/contrib/hover` | `MultiCursorModifier` | `viewer/contrib/hover/hover_utils.mbt:44` | `NARROW_PUBLIC` | `NC` |
| `viewer/contrib/hover/browser` | `ContentHoverWidget` | `viewer/contrib/hover/browser/content_hover_widget.mbt:77` | `NARROW_PUBLIC` | `RV` |
| `viewer/ui/scrollbar` | `MouseWheelClassifierItem` | `viewer/ui/scrollbar/mouse_wheel_classifier.mbt:5` | `MAKE_PRIVATE` | `NC` |
| `viewer/ui/scrollbar` | `ScrollableElementDom` | `viewer/ui/scrollbar/scrollable_element.mbt:6` | `NARROW_PUBLIC` | `IP,WB` |
| `viewer/ui/scrollbar` | `StandardWheelEvent` | `viewer/ui/scrollbar/mouse_event.mbt:11` | `NARROW_PUBLIC` | `IP` |

Disposition reasons are contract-based:

- `KEEP_ALL` rows preserve contextual record literals, provider-emitted DTOs,
  marker input/filter values, or public command-option enums with no alternate
  constructor.
- `KEEP_OPEN` rows are documented external language-provider seams.
- `MAKE_PRIVATE` rows are same-package implementation carriers; their exposed
  constructor/helper or black-box test boundary moves with them.
- every `NARROW_PUBLIC` row has an existing constructor/factory or is produced
  only by its owning package while callers read fields or pattern-match.

## Constructor Ledger

The following 90 declarations are `CANONICALIZE_ALIAS`. Each receives one
canonical `Type::Type` implementation with `#alias(new)`, and repository
callers migrate to canonical spelling without changing parameters, defaults,
effects, validation, derivation, or ownership:

```text
base/browser/global_pointer_move_monitor.mbt:20 GlobalPointerMoveMonitor
base/browser/mouse_event.mbt:41 StandardMouseEvent
base/common/character_classifier.mbt:30 CharacterClassifier
base/common/character_classifier.mbt:81 CharacterSet
base/common/lifecycle.mbt:52 Emitter
base/common/lifecycle.mbt:138 MicrotaskEmitter
base/common/line_range.mbt:142 LineRangeSet
base/common/resources.mbt:29 ExtUri
platform/log/log.mbt:35 NullLogger
platform/log/log.mbt:60 MemoryLogger
platform/log/log.mbt:96 MultiplexLogger
platform/log/log.mbt:135 LogService
syntax/lang_javascript/lexer.mbt:21 JavascriptTokenizer
syntax/lang_json/lexer.mbt:12 JsonTokenizer
syntax/lang_moonbit/lexer.mbt:22 MoonbitTokenizer
syntax/plain.mbt:12 PlainTokenizer
syntax/tokenizer.mbt:124 TokenizationRegistry
viewer/browser/controller/mouse_handler.mbt:148 MouseHandler
viewer/browser/controller/mouse_handler.mbt:791 MouseDownState
viewer/browser/controller/mouse_target.mbt:326 HitTestContext
viewer/browser/controller/mouse_target.mbt:568 HitTestRequest
viewer/browser/controller/mouse_target.mbt:815 MouseTargetFactory
viewer/browser/editor_dom.mbt:141 EditorDomMouseEvent
viewer/browser/editor_dom.mbt:239 EditorMouseEventFactory
viewer/browser/editor_dom.mbt:341 GlobalEditorPointerMoveMonitor
viewer/common/agent_feedback_api/agent_feedback_handle.mbt:28 AgentFeedbackHandle
viewer/common/core/selection.mbt:29 Selection
viewer/common/cursor/cursor.mbt:17 Cursor
viewer/common/cursor/cursor_context.mbt:18 CursorContext
viewer/common/cursor/cursor_event_state.mbt:11 CursorState
viewer/common/cursor/cursor_event_state.mbt:26 PartialModelCursorState
viewer/common/cursor/cursor_event_state.mbt:40 PartialViewCursorState
viewer/common/cursor/cursors_controller.mbt:18 CursorsController
viewer/common/cursor/single_cursor_state.mbt:34 SingleCursorState
viewer/common/diff/default_lines_diff_computer.mbt:39 DefaultLinesDiffComputer
viewer/common/languages/languages.mbt:92 Languages
viewer/common/markers/marker_decorations_service.mbt:50 MarkerDecorationsService
viewer/common/markers/marker_service.mbt:271 MarkerService
viewer/common/markers/markers.mbt:165 MarkerData
viewer/common/markers/markers.mbt:315 MarkerReadOptions
viewer/common/model/guides_text_model_part.mbt:41 GuidesTextModelPart
viewer/common/model/interval_tree.mbt:281 IntervalNode
viewer/common/model/interval_tree.mbt:413 IntervalTree
viewer/common/quick_diff_api/quick_diff_handle.mbt:11 QuickDiffHandle
viewer/common/services/languages_registry.mbt:28 LanguageIdCodec
viewer/common/tokens/contiguous_multiline_tokens.mbt:20 ContiguousMultilineTokens
viewer/common/tokens/contiguous_multiline_tokens_builder.mbt:19 ContiguousMultilineTokensBuilder
viewer/common/tokens/contiguous_tokens_store.mbt:49 ContiguousTokensStore
viewer/common/tokens/line_tokens.mbt:45 LineTokens
viewer/common/tokens/line_tokens.mbt:186 InsertedToken
viewer/common/view_layout/character_mapping.mbt:26 CharacterMapping
viewer/common/view_layout/lines_layout.mbt:30 EditorWhitespace
viewer/common/view_layout/lines_layout.mbt:225 LinesLayout
viewer/common/view_layout/scrollable.mbt:89 ScrollState
viewer/common/view_layout/scrollable.mbt:260 SmoothScrollingUpdate
viewer/common/view_layout/scrollable.mbt:281 SmoothScrollingOperation
viewer/common/view_layout/scrollable.mbt:456 Scrollable
viewer/common/view_layout/scrollable.mbt:744 EditorScrollDimensions
viewer/common/view_layout/scrollable.mbt:781 EditorScrollable
viewer/common/view_layout/scrollbar_state.mbt:28 ScrollbarState
viewer/common/view_layout/view_layout.mbt:43 ViewLayout
viewer/common/view_model/cursor_event_dispatcher.mbt:85 ViewZonesChangedEvent
viewer/common/view_model/cursor_event_dispatcher.mbt:107 ModelTokensChangedOutgoingEvent
viewer/common/view_model/cursor_move_commands.mbt:70 SimpleMoveArguments
viewer/common/view_model/monospace_line_breaks_computer.mbt:95 MonospaceLineBreaksComputerFactory
viewer/common/view_model/view_model_lines_projected.mbt:58 ViewModelLinesFromProjectedModel
viewer/contrib/agent_feedback/agent_feedback_service.mbt:45 AgentFeedbackService
viewer/contrib/agent_feedback/browser/agent_feedback_editor_widget.mbt:71 AgentFeedbackEditorWidget
viewer/contrib/agent_feedback/browser/agent_feedback_input_widget.mbt:61 AgentFeedbackInputWidget
viewer/contrib/folding/browser/folding_decorations.mbt:169 FoldingDecorationProvider
viewer/contrib/folding/browser/folding_model.mbt:80 FoldingModel
viewer/contrib/folding/browser/folding_ranges.mbt:109 FoldingRegions
viewer/contrib/folding/browser/hidden_range_model.mbt:23 HiddenRangeModel
viewer/contrib/folding/browser/indent_range_provider.mbt:30 IndentRangeProvider
viewer/contrib/folding/browser/indent_range_provider.mbt:91 RangesCollector
viewer/contrib/hover/browser/content_hover_widget.mbt:134 ContentHoverWidget
viewer/contrib/hover/hover_anchor.mbt:29 HoverParticipantOwner
viewer/contrib/hover/hover_controller.mbt:116 HoverOperationOptions
viewer/contrib/hover/hover_controller.mbt:342 HoverDebouncer
viewer/contrib/hover/hover_participants.mbt:151 MarkerHoverParticipant
viewer/contrib/hover/hover_participants.mbt:233 MarkdownHoverParticipant
viewer/contrib/hover/hover_participants.mbt:307 ContentHoverComputer
viewer/contrib/hover/hover_registry.mbt:13 HoverParticipantRegistry
viewer/contrib/hover/hover_widget_geometry.mbt:109 MouseCloserState
viewer/contrib/quick_diff/common/quick_diff.mbt:64 QuickDiffService
viewer/services.mbt:29 ViewerServices
viewer/ui/scrollbar/cached_dom_node.mbt:41 CachedDomNode
viewer/ui/scrollbar/mouse_event.mbt:21 StandardWheelEvent
viewer/ui/scrollbar/mouse_wheel_classifier.mbt:30 MouseWheelClassifier
viewer/ui/scrollbar/scrollable_element.mbt:55 ScrollableElementDom
```

The remaining six terminal dispositions are:

| Declaration | Location | Disposition | Reason |
|---|---|---|---|
| `CharWidthRequest::new` | `viewer/browser/config/char_width_reader.mbt:22` | superseded by `MAKE_PRIVATE` | Milestone C made the request type, enum, helper, and constructor package-private. |
| `DragScrolling::new` | `viewer/browser/controller/drag_scrolling.mbt:61` | superseded by `MAKE_PRIVATE` | Milestone C made the direction enum private, so its exposing constructor also became private. |
| `CancellationToken::new` | `language/cancellation.mbt:55` | `KEEP_ALTERNATE` | Documented directly cancellable compatibility path; source ownership is `CancellationTokenSource(...)`. |
| `PrefixSumComputer::new` | `viewer/common/view_layout/prefix_sum_computer.mbt:26` | `VIEW_PRIMARY_COMPAT` | Canonical constructor accepts `ArrayView[Int]`; old `Array[Int]` signature remains a wrapper. |
| `ConstantTimePrefixSumComputer::new` | `viewer/common/view_layout/prefix_sum_computer.mbt:210` | `VIEW_PRIMARY_COMPAT` | Same owned-copy compatibility contract. |
| `BrowserTestContext::new` | `tests/browser/moonbit/support/assert.mbt:11` | `TEST_SUPPORT` | Public only to browser scenario packages; canonicalize in the test-support batch after product constructors. |

No inventoried type already has a duplicate public `Type::Type` constructor.
`CancellationTokenSource::CancellationTokenSource` with `#alias(new)` remains
the existing compatibility pattern.

## Package-Move and Import Inventory

All reverse consumers use normal imports. The only special-scope imports owned
by a moved package are:

- controller imports `syntax` for black-box test; Milestone B changes this to
  `for "wbtest"`;
- hover imports `platform/log` and `moonbitlang/async` for wbtest.

| Current package | Interface lines | Source / test / wbtest | Reverse consumers |
|---|---:|---:|---|
| `viewer/browser/config` | 43 | `3 / 0 / 1` | `viewer` |
| `viewer/browser/controller` | 209 | `4 / 1 / 2` | `viewer` |
| `viewer/browser/testing` | 57 | `2 / 1 / 0` | `viewer`, workbench, component, perf |
| `viewer/browser/view` | 298 | `31 / 1 / 15` | `viewer`, controller, hover browser, component |
| `viewer/ui/scrollbar` | 122 | `4 / 0 / 2` | `viewer`, view, controller, hover browser |
| `viewer/contrib/agent_feedback` | 73 | `2 / 0 / 2` | `viewer`, agent-feedback browser, workbench, scenario |
| `viewer/contrib/agent_feedback/browser` | 121 | `4 / 0 / 0` | `viewer` |
| `viewer/contrib/folding/browser` | 203 | `6 / 0 / 5` | `viewer` |
| `viewer/contrib/hover` | 324 | `7 / 0 / 7` | `viewer`, hover browser |
| `viewer/contrib/hover/browser` | 131 | `3 / 0 / 2` | `viewer` |
| `viewer/contrib/quick_diff/common` | 35 | `1 / 0 / 1` | `viewer`, quick-diff browser, quick-diff/set-value scenarios |
| `viewer/contrib/quick_diff/browser` | 23 | `2 / 0 / 2` | `viewer` |

Totals: 69 production files, 3 black-box tests, 39 white-box tests, 12
manifests, and 1,639 generated-interface lines.

No target directory exists yet. All current consumers are under the allowed
module-root prefix `moonbit-community/editor`, so `internal/viewer/**` admits
current module consumers and rejects outside modules as intended. It does not
enforce the viewer-common dependency direction inside this module; manifests,
interfaces, `moon check`, and review remain authoritative for that rule.

Dependency-safe order:

```text
F1: config, testing, scrollbar -> view -> controller
F2: agent_feedback -> agent_feedback/browser
    hover -> hover/browser
    quick_diff/common -> quick_diff/browser
    folding/browser is independent
```

## Asset Hash Inventory

| SHA-256 | Path |
|---|---|
| `dce03fd97747a5fc3514142d41a274e53c0a12d27466cf36995d533bf835a8e7` | `viewer/browser/view/codicon/codicon.css` |
| `ea575c690f1df0c1483f4cce209ebcdfb404b1ac4f2e486cb022eb6e848ae98f` | `viewer/browser/view/codicon/codicon.ttf` |
| `e60b301444996ccb8ef7a3f3899fa9c5947553e0e03d8d7f9adb7e88752b2a9a` | `viewer/browser/view/editor.css` |
| `bf087c560d6448461cb9d5542bb5c47d613434a43c7d81fce0bb1bbe9e32a593` | `viewer/browser/view_parts/content_widgets/content_widgets.css` |
| `ca8168e586d081f6e57009066ffc3baf9fa71d4d7bf18c6f36e7cfa58532649e` | `viewer/browser/view_parts/current_line_highlight/current_line_highlight.css` |
| `e89338f1f398b6d93f3fa9a6e234600b010fb05c445fd383d950d5d6b13d1689` | `viewer/browser/view_parts/decorations/decorations.css` |
| `f0c22830763933b564a3d82ffb59b3e7c149214ecee0fbd3bccdce4cafb92ba4` | `viewer/browser/view_parts/margin/lines_decorations.css` |
| `e422fa0d3a4aac1782c0e8bc1c70fb6dfe8f097a32f71b01b4621f48a62cd249` | `viewer/browser/view_parts/margin/margin.css` |
| `00cc017770869d9e03efc0341d73a86737364bb8e4a595d4f6e34d7b69025ea1` | `viewer/browser/view_parts/overlay_widgets/overlay_widgets.css` |
| `7f7beaf3d3832d3c588354b900135568b9caa71b3913489672c045648c3fed8c` | `viewer/browser/view_parts/selections/selections.css` |
| `a3c3962e09b1eadb68bc22fc7c407526b05e1dc10217e66b21f72f7e3d258fbc` | `viewer/browser/view_parts/selections/view_overlays.css` |
| `468224a34805fd6c0f38d7556fa3991da3a7ccf4d6f5884b15f49238027bcf94` | `viewer/browser/view_parts/view_cursors/view_cursors.css` |
| `a60eb675dfd545c514f798b90a219da0de072b122e755fa49497080ed5fe6be0` | `viewer/browser/view_parts/view_lines/markers.css` |
| `1ce97292a60d80b22e648f42e46c213413fe71c59ab8a19cb2d58f147d00709e` | `viewer/browser/view_parts/view_lines/tokens.css` |
| `9d2f8f659e9fb5b13bcd15c9bc738945b44a4d8810335b94b24ef2e0b7ecf7f6` | `viewer/browser/view_parts/view_lines/view_lines.css` |
| `ccf12b47a4be3bab40718917b490b8ff86a9f90bdc1f277c514c4144cd55a7e8` | `viewer/contrib/agent_feedback/browser/agent_feedback.css` |
| `6e72cfe012de66d03a6999d3cf439b0abef2a330a52bd4beddb3821d945fd2fe` | `viewer/contrib/folding/browser/folding.css` |
| `7d7b82fdbd55ab0df2025da391d117b84e4ee84a6bb1efe48b7c775290e7315f` | `viewer/contrib/hover/hover.css` |
| `d990259749755c8073c29eefc3a37094f7394427e9804320e6c5555a9a1154cd` | `viewer/contrib/quick_diff/browser/quick_diff.css` |
| `fce9dda0e21c2213497244dcd8e5af5d2c9058e70388fcf351686b3fd7fb9f68` | `viewer/ui/scrollbar/scrollable_element.css` |

## ArrayView Review

Required landed slice:

- `PrefixSumComputer(ArrayView[Int])` and
  `ConstantTimePrefixSumComputer(ArrayView[Int])` own `to_owned()` copies;
- existing `Type::new(Array[Int])` methods remain wrappers through `values[:]`;
- tests cover empty, whole, non-zero-offset slice, and source mutation.

Terminal additional-candidate dispositions:

- `DEFERRED (compatibility)`: public path `join`/`resolve` variants,
  `Uri::join_path`, `ExtUri::join_path`, free `join_path`,
  `LineRange::join_many`, public token/layout search helpers;
- `N-A (ownership)`: `TokenizationRegistry::set_color_map`,
  `LineRangeSet::new`, `ContiguousMultilineTokens::new`, `LineTokens::new`,
  mutable output/buffer helpers;
- `LANDED`: private `join_range`,
  `find_first_idx_monotonous_or_arr_len`, `find_last_idx_monotonous`,
  `find_last_monotonous`, `join_line_ranges`, `line_range_arrays_equal`,
  `normalize_injected_text`, `resolve_injection_options`, and
  `normalize_line_ranges`.

## Gate A Decision

There is no material blocker. Proceed through the plan without a review stop.
