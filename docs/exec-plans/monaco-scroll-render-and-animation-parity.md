# Monaco Scroll Render and Animation Parity

Status: proposed — inventory complete, awaiting review
Date: 2026-07-10
Oracle commit: b18492a288de038fbc7643aae6de8247029d11bd

This plan follows _PORT_PLAYBOOK.md. It addresses the measured gap in priority
order:

1. remove avoidable work from every scroll frame by moving the content rail on
   the single shared lines-content node and deduplicating retained-row writes;
2. port Monaco's Scrollable animation state machine and frame scheduling;
3. port the physical-wheel classifier and route only physical wheels through
   smooth scrolling when smoothScrolling is enabled;
4. prove behavior and frame cost against the pinned Monaco oracle.

No port code may be written until this inventory has been reviewed.

## Scope (Phase 0)

Complete source units and complete method clusters:

- vscode/src/vs/editor/browser/view.ts: the complete lines-content ownership
  cluster (field, construction, consumers, child order, and _applyLayout size).
- vscode/src/vs/base/browser/fastDomNode.ts: the complete geometry/style-cache
  cluster used by scrolling (width, height, top, left, line-height,
  layer-hinting, contain, and numberAsPixels).
- vscode/src/vs/editor/browser/viewParts/viewLines/viewLine.ts:
  ViewLine.layoutLine.
- vscode/src/vs/editor/browser/view/viewOverlays.ts: the complete
  ViewOverlayLine class.
- vscode/src/vs/editor/browser/view/viewLayer.ts:
  VisibleLinesCollection.renderLines, IRendererContext, and the complete
  ViewLayerRenderer class.
- vscode/src/vs/editor/browser/viewParts/viewLines/viewLines.ts: the
  lines-content/layer-hint fields and wiring plus the complete
  onScrollChanged and renderText methods.
- vscode/src/vs/base/common/scrollable.ts: the complete ScrollState,
  Scrollable, SmoothScrollingUpdate, IAnimation, SmoothScrollingOperation, and
  animation-helper units plus all data contracts they consume or emit.
- vscode/src/vs/base/browser/ui/scrollbar/scrollableElement.ts: the wheel
  constants, complete MouseWheelClassifierItem and MouseWheelClassifier
  classes, and complete _onMouseWheel method.
- vscode/src/vs/editor/common/viewLayout/viewLayout.ts: the complete
  EditorScrollDimensions and EditorScrollable classes and the complete
  ViewLayout smooth-scroll integration cluster.
- editorOptions.ts smoothScrolling registration and
  scrollableElement.ts resolveOptions mouseWheelSmoothScroll registration.
- Upstream scrollable.test.ts (all 5 smooth cases) and
  scrollableElement.test.ts (all 9 device traces).

Explicitly out of scope:

- ScrollbarVisibility and the scrollbar visibility/drag implementation; those
  are separate, already-ported behavior and do not change frame cadence here.
- AbstractScrollableElement methods outside _onMouseWheel, except the option
  default named above.
- ViewLines members outside the named scroll/render cluster.
- ViewLayer's RenderedLinesCollection mutation-event methods; the local
  recycler already owns equivalent line-window mutation behavior.
- inertialScroll. Its resolved default is false, the editor does not enable it,
  and it is independent of Monaco's physical-wheel smooth path.
- GPU view lines, minimap, rulers, glyph margin, scroll decoration, edit
  context, and mutable-editor input.
- Programmatic reveal animation. Existing reveal APIs remain immediate; this
  plan ports the wheel path and the underlying general Scrollable API first.

## Inventory and draft parity ledger (Phases 1–2)

Every scoped member has one row. TODO means implementation has not started.
Permanent source-only seams are marked N-A now. Branches, early returns,
constants, DOM attributes, and CSS properties are recorded in the transition
cell of their owning member.

### Priority 1 — one content rail and cached DOM writes

| # | Source member | Arithmetic / transition / owned DOM | MoonBit target | Status |
|---:|---|---|---|---|
| 1 | view.ts _linesContent | sole scrolling content rail | View.editor_scrollbar.content | TODO |
| 2 | view.ts constructor createElement(div) | create before scrollbar/view lines | View::new | TODO |
| 3 | view.ts setClassName | lines-content monaco-editor-background | View::new / CSS | TODO |
| 4 | view.ts setPosition | position:absolute | View::new / CSS | TODO |
| 5 | view.ts EditorScrollbar argument | scrollbar owns the same rail | EditorScrollbar | TODO |
| 6 | view.ts ViewLines argument | ViewLines moves the same rail | ViewLines | TODO |
| 7 | view.ts append cluster | overlays, zones, lines, widgets, cursors in source order | View::new | TODO |
| 8 | view.ts _applyLayout width | 16777216 px Chrome rendering ceiling | lines-content style cache | TODO |
| 9 | view.ts _applyLayout height | 16777216 px Chrome rendering ceiling | lines-content style cache | TODO |
| 10 | FastDomNode._width | cached CSS string, initial empty | browser DOM style cache | TODO |
| 11 | FastDomNode._height | cached CSS string, initial empty | browser DOM style cache | TODO |
| 12 | FastDomNode._top | cached CSS string, initial empty | browser DOM style cache | TODO |
| 13 | FastDomNode._left | cached CSS string, initial empty | browser DOM style cache | TODO |
| 14 | FastDomNode._lineHeight | cached CSS string, initial empty | browser DOM style cache | TODO |
| 15 | FastDomNode._layerHint | cached Bool, initial false | browser DOM style cache | TODO |
| 16 | FastDomNode._contain | cached value, initial none | browser DOM style cache | TODO |
| 17 | FastDomNode constructor domNode | wrapper retains one element | browser DOM style cache | TODO |
| 18 | FastDomNode.setWidth | numberAsPixels; equal early return; style.width | cached setter | TODO |
| 19 | FastDomNode.setHeight | numberAsPixels; equal early return; style.height | cached setter | TODO |
| 20 | FastDomNode.setTop | numberAsPixels; equal early return; style.top | cached setter | TODO |
| 21 | FastDomNode.setLeft | numberAsPixels; equal early return; style.left | cached setter | TODO |
| 22 | FastDomNode.setLineHeight | numberAsPixels; equal early return; style.lineHeight | cached setter | TODO |
| 23 | FastDomNode.setLayerHinting | equal early return; translate3d(0px,0px,0px) or empty | cached setter | TODO |
| 24 | FastDomNode.setContain | equal early return; style.contain | cached setter | TODO |
| 25 | numberAsPixels | numbers gain px; strings pass through | cached setter helper | TODO |
| 26 | ViewLine.layoutLine | if DOM exists, cached top/height/line-height writes | ViewLines retained-row layout | TODO |
| 27 | ViewOverlayLine._dynamicOverlays | registration-order renderers | ViewOverlayLine | TODO |
| 28 | ViewOverlayLine._domNode | nullable cached DOM wrapper | ViewOverlayLine | TODO |
| 29 | ViewOverlayLine._renderedContent | nullable concatenated HTML cache | ViewOverlayLine | TODO |
| 30 | ViewOverlayLine constructor | retain overlays; DOM/content null | ViewOverlayLine::new | TODO |
| 31 | ViewOverlayLine.getDomNode | null early return, otherwise raw node | ViewOverlayLine::get_dom_node | TODO |
| 32 | ViewOverlayLine.setDomNode | wrap supplied node in cache | ViewOverlayLine::set_dom_node | TODO |
| 33 | ViewOverlayLine.onContentChanged | no-op | ViewOverlayLine | TODO |
| 34 | ViewOverlayLine.onTokensChanged | no-op | ViewOverlayLine | TODO |
| 35 | ViewOverlayLine.renderLine | concat in order; same-content false; emit one div with top/height/line-height | ViewOverlayLine::render_line | TODO |
| 36 | ViewOverlayLine.layoutLine | if DOM exists, cached top/height/line-height writes | ViewOverlayLine::layout_line | TODO |
| 37 | IRendererContext.rendLineNumberStart | first retained source line | local renderer context | TODO |
| 38 | IRendererContext.lines | retained line objects | local renderer context | TODO |
| 39 | IRendererContext.linesLength | logical retained length | local renderer context | TODO |
| 40 | VisibleLinesCollection.renderLines | copy context; render requested inclusive range; store result | ViewLines/ViewOverlays recycler | TODO |
| 41 | ViewLayerRenderer._ttPolicy | Trusted Types policy editorViewLayer | — | N-A (RDOM owns HTML sink) |
| 42 | ViewLayerRenderer._domNode | row container | local ViewLayerRenderer | TODO |
| 43 | ViewLayerRenderer._lineFactory | creates retained line objects | local ViewLayerRenderer | TODO |
| 44 | ViewLayerRenderer._viewportData | render input for rows | local ViewLayerRenderer | TODO |
| 45 | ViewLayerRenderer._viewContext | line-height lookup | local ViewLayerRenderer | TODO |
| 46 | ViewLayerRenderer constructor | retains the four dependencies | ViewLayerRenderer::new | TODO |
| 47 | ViewLayerRenderer.render | clone; no-overlap full reset early return; layout overlap; insert/remove before then after; finish | ViewLayerRenderer::render | TODO |
| 48 | _renderUntouchedLines | inclusive loop; layoutLine with indexed deltaTop | same-named helper | TODO |
| 49 | _insertLinesBefore | create ascending range; concat before | same-named helper | TODO |
| 50 | _removeLinesBefore | remove DOM if present; splice prefix | same-named helper | TODO |
| 51 | _insertLinesAfter | create ascending range; concat after | same-named helper | TODO |
| 52 | _removeLinesAfter | compute tail index; remove DOM; splice | same-named helper | TODO |
| 53 | _finishRenderingNewLines | policy; innerHTML if empty else insertAdjacentHTML; bind DOM backwards | same-named helper | TODO |
| 54 | _finishRenderingInvalidLines | render in detached div; replace invalid nodes in order | same-named helper | TODO |
| 55 | ViewLayerRenderer._sb | shared StringBuilder capacity 100000 | shared builder | TODO |
| 56 | _finishRendering | new pass before invalid pass; skip existing/new/unchanged via early returns | same-named helper | TODO |
| 57 | _lineHeightForLineNumber | delegate to view layout | local layout lookup | TODO |
| 58 | ViewLines._linesContent | shared rail passed by View | ViewLines.lines_content cache | TODO |
| 59 | ViewLines._canUseLayerHinting | inverse disableLayerHinting | fixed true (no option) | TODO |
| 60 | ViewLines constructor scroll wiring | retain shared rail; initialize layer-hint flag | ViewLines::new | TODO |
| 61 | ViewLines configuration layer-hint branch | refresh inverse option | — | N-A (no runtime option) |
| 62 | ViewLines.onScrollChanged | cancel horizontal reveal branches; cache width; dirty on row/axis movement | ViewPart event + reveal bookkeeping | TODO |
| 63 | ViewLines.renderText | render rows; range/size; horizontal reveal; width scheduling; Linux font check; layer hint; contain strict; top=-(current-bigDelta); left=-current | View::render + ViewLines::render_text | TODO |

Priority-1 member count: 63; ledger rows: 63.

### Priority 2 — Scrollable animation state machine

| # | Source member | Arithmetic / transition | MoonBit target | Status |
|---:|---|---|---|---|
| 64 | ScrollState._scrollStateBrand | TypeScript nominal brand | — | N-A (language seam) |
| 65 | ScrollState._forceIntegerValues | constructor-owned flag | Scrollable.force_integer_values | TODO |
| 66 | ScrollState.rawScrollLeft | pre-validation input | ScrollState.raw_scroll_left | TODO |
| 67 | ScrollState.rawScrollTop | pre-validation input | ScrollState.raw_scroll_top | TODO |
| 68 | ScrollState.width | validated viewport width | ScrollState.width | TODO |
| 69 | ScrollState.scrollWidth | content width | ScrollState.scroll_width | TODO |
| 70 | ScrollState.scrollLeft | clamped position | ScrollState.scroll_left | TODO |
| 71 | ScrollState.height | validated viewport height | ScrollState.height | TODO |
| 72 | ScrollState.scrollHeight | content height | ScrollState.scroll_height | TODO |
| 73 | ScrollState.scrollTop | clamped position | ScrollState.scroll_top | TODO |
| 74 | ScrollState constructor | optional integer truncation; capture raw; floor width/height at 0; clamp far edge then 0 | ScrollState::new | TODO |
| 75 | ScrollState.equals | compare raw and all six validated fields | ScrollState::equals | TODO |
| 76 | withScrollDimensions | optional values; choose raw/current positions by flag | with_scroll_dimensions | TODO |
| 77 | withScrollPosition | optional axes fall back to raw axes | with_scroll_position | TODO |
| 78 | createScrollEvent | old/new values plus six changed flags and inSmoothScrolling | ScrollChange/ScrollEvent | TODO |
| 79 | ScrollEvent.inSmoothScrolling | animation-frame marker | ScrollChange.in_smooth_scrolling | TODO |
| 80 | ScrollEvent.oldWidth | previous width | ScrollChange | TODO |
| 81 | ScrollEvent.oldScrollWidth | previous scroll width | ScrollChange | TODO |
| 82 | ScrollEvent.oldScrollLeft | previous left | ScrollChange | TODO |
| 83 | ScrollEvent.width | new width | ScrollChange | TODO |
| 84 | ScrollEvent.scrollWidth | new scroll width | ScrollChange | TODO |
| 85 | ScrollEvent.scrollLeft | new left | ScrollChange | TODO |
| 86 | ScrollEvent.oldHeight | previous height | ScrollChange | TODO |
| 87 | ScrollEvent.oldScrollHeight | previous scroll height | ScrollChange | TODO |
| 88 | ScrollEvent.oldScrollTop | previous top | ScrollChange | TODO |
| 89 | ScrollEvent.height | new height | ScrollChange | TODO |
| 90 | ScrollEvent.scrollHeight | new scroll height | ScrollChange | TODO |
| 91 | ScrollEvent.scrollTop | new top | ScrollChange | TODO |
| 92 | ScrollEvent.widthChanged | exact inequality | ScrollChange | TODO |
| 93 | ScrollEvent.scrollWidthChanged | exact inequality | ScrollChange | TODO |
| 94 | ScrollEvent.scrollLeftChanged | exact inequality | ScrollChange | TODO |
| 95 | ScrollEvent.heightChanged | exact inequality | ScrollChange | TODO |
| 96 | ScrollEvent.scrollHeightChanged | exact inequality | ScrollChange | TODO |
| 97 | ScrollEvent.scrollTopChanged | exact inequality | ScrollChange | TODO |
| 98 | IScrollDimensions.width | readonly number | ScrollDimensions.width | TODO |
| 99 | IScrollDimensions.scrollWidth | readonly number | ScrollDimensions.scroll_width | TODO |
| 100 | IScrollDimensions.height | readonly number | ScrollDimensions.height | TODO |
| 101 | IScrollDimensions.scrollHeight | readonly number | ScrollDimensions.scroll_height | TODO |
| 102 | INewScrollDimensions.width | optional update | ScrollDimensionsUpdate | TODO |
| 103 | INewScrollDimensions.scrollWidth | optional update | ScrollDimensionsUpdate | TODO |
| 104 | INewScrollDimensions.height | optional update | ScrollDimensionsUpdate | TODO |
| 105 | INewScrollDimensions.scrollHeight | optional update | ScrollDimensionsUpdate | TODO |
| 106 | IScrollPosition.scrollLeft | readonly number | ScrollPosition.scroll_left | TODO |
| 107 | IScrollPosition.scrollTop | readonly number | ScrollPosition.scroll_top | TODO |
| 108 | ISmoothScrollPosition.scrollLeft | animation axis | SmoothScrollPosition | TODO |
| 109 | ISmoothScrollPosition.scrollTop | animation axis | SmoothScrollPosition | TODO |
| 110 | ISmoothScrollPosition.width | target viewport width | SmoothScrollPosition | TODO |
| 111 | ISmoothScrollPosition.height | target viewport height | SmoothScrollPosition | TODO |
| 112 | INewScrollPosition.scrollLeft | optional update | ScrollPositionUpdate | TODO |
| 113 | INewScrollPosition.scrollTop | optional update | ScrollPositionUpdate | TODO |
| 114 | IScrollableOptions.forceIntegerValues | required Bool | Scrollable::new | TODO |
| 115 | IScrollableOptions.smoothScrollDuration | required milliseconds | Scrollable::new | TODO |
| 116 | IScrollableOptions.scheduleAtNextAnimationFrame | callback returns disposable | injected scheduler closure | TODO |
| 117 | Scrollable._scrollableBrand | TypeScript nominal brand | — | N-A (language seam) |
| 118 | Scrollable._smoothScrollDuration | mutable milliseconds | Scrollable.smooth_scroll_duration | TODO |
| 119 | Scrollable._scheduleAtNextAnimationFrame | retained scheduler | Scrollable scheduler closure | TODO |
| 120 | Scrollable._state | current ScrollState | Scrollable.state | TODO |
| 121 | Scrollable._smoothScrolling | nullable operation | Scrollable.smooth_scrolling | TODO |
| 122 | Scrollable._onScroll | emitter | returned ScrollChange callback seam | TODO |
| 123 | Scrollable.onScroll | public event | Viewer apply-scroll subscription | TODO |
| 124 | Scrollable constructor | duration/scheduler; zero state; no operation | Scrollable::new | TODO |
| 125 | Scrollable.dispose | dispose operation if present; clear; super | Scrollable::dispose | TODO |
| 126 | setSmoothScrollDuration | direct assignment | set_smooth_scroll_duration | TODO |
| 127 | validateScrollPosition | state.withScrollPosition | validate_scroll_position | TODO |
| 128 | getScrollDimensions | current state | dimensions | TODO |
| 129 | setScrollDimensions | derive state; set with smooth marker; revalidate outstanding target | set_dimensions | TODO |
| 130 | getFutureScrollPosition | operation.to else state | future_position | TODO |
| 131 | getCurrentScrollPosition | current state | current_position | TODO |
| 132 | setScrollPositionNow | derive; dispose/cancel pending; set non-smooth | set_position_now | TODO |
| 133 | setScrollPositionSmooth | duration-0 fallback; combine missing axes; same-target early return; reuse/combine; schedule guarded frame | set_position_smooth | TODO |
| 134 | hasPendingScrollAnimation | Bool(operation) | has_pending_scroll_animation | TODO |
| 135 | _performSmoothScrolling | missing early return; tick/set; cancellation guard; done dispose; otherwise guarded reschedule | perform_smooth_scrolling | TODO |
| 136 | _setState | equals early return; assign; emit event | change_to / event callback | TODO |
| 137 | SmoothScrollingUpdate.scrollLeft | interpolated/final axis | SmoothScrollingUpdate.scroll_left | TODO |
| 138 | SmoothScrollingUpdate.scrollTop | interpolated/final axis | SmoothScrollingUpdate.scroll_top | TODO |
| 139 | SmoothScrollingUpdate.isDone | completion flag | SmoothScrollingUpdate.is_done | TODO |
| 140 | SmoothScrollingUpdate constructor | retain three values | SmoothScrollingUpdate::new | TODO |
| 141 | IAnimation call signature | completion Double to position Double | (Double) -> Double | TODO |
| 142 | createEaseOutCubic | delta=to-from; from+delta*easeOut | create_ease_out_cubic | TODO |
| 143 | createComposed | completion<cut branch; normalize each segment | create_composed | TODO |
| 144 | easeInCubic | t cubed | ease_in_cubic | TODO |
| 145 | easeOutCubic | 1-easeIn(1-t) | ease_out_cubic | TODO |
| 146 | SmoothScrollingOperation.from | immutable start position | operation.from | TODO |
| 147 | SmoothScrollingOperation.to | mutable validated target | operation.to | TODO |
| 148 | SmoothScrollingOperation.duration | immutable milliseconds | operation.duration | TODO |
| 149 | SmoothScrollingOperation.startTime | immutable epoch milliseconds | operation.start_time | TODO |
| 150 | animationFrameDisposable | nullable scheduled-frame cancellation | cancellation closure/handle | TODO |
| 151 | scrollLeft animation | initialized function | operation.scroll_left | TODO |
| 152 | scrollTop animation | initialized function | operation.scroll_top | TODO |
| 153 | SmoothScrollingOperation constructor | retain; null handle; initialize both axes | SmoothScrollingOperation::new | TODO |
| 154 | _initAnimations | width for X; height for Y | init_animations | TODO |
| 155 | _initAnimation | if distance>2.5 viewport, 0.75 stops and cut 0.33; direction branch; else ease-out | init_animation | TODO |
| 156 | dispose | cancel non-null frame and clear | dispose | TODO |
| 157 | acceptScrollDimensions | clamp target through new state; rebuild curves | accept_scroll_dimensions | TODO |
| 158 | tick | _tick(Date.now()) | tick | TODO |
| 159 | _tick | completion=(now-start)/duration; <1 interpolate; else exact target/done | tick_at | TODO |
| 160 | combine | restart via start(from,to,duration) | combine | TODO |
| 161 | start | duration+10; startTime=now-10; construct | start | TODO |

Priority-2 member count: 98; cumulative members/rows: 161/161.

### Priority 3 — wheel classification and ViewLayout integration

| # | Source member | Arithmetic / transition | MoonBit target | Status |
|---:|---|---|---|---|
| 162 | SCROLL_WHEEL_SENSITIVITY | 50 | scrollbar constant | TODO |
| 163 | SCROLL_WHEEL_SMOOTH_SCROLL_ENABLED | true | scrollbar constant | TODO |
| 164 | MouseWheelClassifierItem.timestamp | event time | item.timestamp | TODO |
| 165 | MouseWheelClassifierItem.deltaX | normalized X | item.delta_x | TODO |
| 166 | MouseWheelClassifierItem.deltaY | normalized Y | item.delta_y | TODO |
| 167 | MouseWheelClassifierItem.score | starts 0 | item.score | TODO |
| 168 | MouseWheelClassifierItem constructor | retain values; score=0 | item new | TODO |
| 169 | MouseWheelClassifier.INSTANCE | process-global singleton | classifier singleton | TODO |
| 170 | MouseWheelClassifier._capacity | 5 | classifier.capacity | TODO |
| 171 | MouseWheelClassifier._memory | ring items | classifier.memory | TODO |
| 172 | MouseWheelClassifier._front | starts -1 | classifier.front | TODO |
| 173 | MouseWheelClassifier._rear | starts -1 | classifier.rear | TODO |
| 174 | MouseWheelClassifier constructor | capacity 5; empty; front/rear -1 | classifier new | TODO |
| 175 | isPhysicalMouseWheel | empty false; weighted newest 0.5, then powers of 2; oldest gets remainder; score<=0.5 | is_physical_mouse_wheel | TODO |
| 176 | acceptStandardWheelEvent | Chrome page zoom factor branch; Date.now; delegate | accept_standard_wheel_event | TODO |
| 177 | accept | first-item branch; ring advance/drop-oldest; compute against previous | accept | TODO |
| 178 | _computeScore | both axes =>1; start .5; fractional +.25; same modulo -.5; clamp 0..1 | compute_score | TODO |
| 179 | _isAlmostInt | epsilon=Number.EPSILON*100; abs(round-value)<.01+epsilon | is_almost_int | TODO |
| 180 | AbstractScrollableElement._onMouseWheel | defaultPrevented return; classify; nonzero gate; sensitivity; predominant/flip/shift/alt branches; use future target; away-from-zero 50x rounding; validate; inertial branch deferred; changed-target gate; physical+option smooth decision; consume branches; prevent/stop | MouseHandler::handle_editor_wheel | TODO |
| 181 | EditorScrollDimensions.width | viewport width | ScrollDimensions.width | TODO |
| 182 | EditorScrollDimensions.contentWidth | content width before max | ViewLayout.content_width | TODO |
| 183 | EditorScrollDimensions.scrollWidth | max(width,contentWidth) | ScrollDimensions.scroll_width | TODO |
| 184 | EditorScrollDimensions.height | viewport height | ScrollDimensions.height | TODO |
| 185 | EditorScrollDimensions.contentHeight | content height before max | ViewLayout content height | TODO |
| 186 | EditorScrollDimensions.scrollHeight | max(height,contentHeight) | ScrollDimensions.scroll_height | TODO |
| 187 | EditorScrollDimensions constructor | truncate all; floor each input at 0; derive max extents | dimensions normalization | TODO |
| 188 | EditorScrollDimensions.equals | compare width/contentWidth/height/contentHeight | dimensions equality | TODO |
| 189 | EditorScrollable._scrollable | owned Scrollable | ViewLayout.scrollable | TODO |
| 190 | EditorScrollable._dimensions | current editor dimensions | ViewLayout dimensions | TODO |
| 191 | EditorScrollable.onDidScroll | delegated event | Viewer scroll callback | TODO |
| 192 | _onDidContentSizeChange | emitter | existing content-size event seam | TODO |
| 193 | onDidContentSizeChange | public event | existing content-size event seam | TODO |
| 194 | EditorScrollable constructor | zero dimensions; Scrollable integer=true; duration/scheduler; delegate event | ViewLayout::new | TODO |
| 195 | getScrollable | owned model | ViewLayout scrollable accessor | TODO |
| 196 | setSmoothScrollDuration | delegate | ViewLayout setter | TODO |
| 197 | validateScrollPosition | delegate | validate_scroll_position | TODO |
| 198 | getScrollDimensions | editor dimensions | dimensions | TODO |
| 199 | setScrollDimensions | equals return; update; raw positions=true; emit only content size changes | set dimensions | TODO |
| 200 | getFutureScrollPosition | delegate | future_position | TODO |
| 201 | getCurrentScrollPosition | delegate | current_position | TODO |
| 202 | setScrollPositionNow | delegate | scroll_to_now | TODO |
| 203 | setScrollPositionSmooth | delegate | scroll_to_smooth | TODO |
| 204 | hasPendingScrollAnimation | delegate | pending accessor | TODO |
| 205 | SMOOTH_SCROLLING_TIME | 125 ms | view_layout constant | TODO |
| 206 | ViewLayout._scrollable | EditorScrollable owner | ViewLayout.scrollable | TODO |
| 207 | ViewLayout.onDidScroll | delegated event | Viewer scroll event | TODO |
| 208 | ViewLayout.onDidContentSizeChange | delegated event | Viewer content-size event | TODO |
| 209 | ViewLayout constructor smooth wiring | construct duration 0; configure from option; set initial dimensions; expose events | ViewLayout::new + Viewer injection | TODO |
| 210 | ViewLayout.getScrollable | expose underlying Scrollable | accessor for wheel controller | TODO |
| 211 | _configureSmoothScrollDuration | option ? 125 : 0 | set_smooth_scrolling | TODO |
| 212 | onConfigurationChanged smooth branch | changed option => reconfigure | immutable ViewerOptions rebuild seam | TODO |
| 213 | getCurrentViewport | current position + dimensions | current viewport | TODO |
| 214 | getFutureViewport | future position + dimensions | future viewport | TODO |
| 215 | saveState | future position; subtract whitespace from top | save state | TODO |
| 216 | getCurrentScrollLeft | current position X | current accessor | TODO |
| 217 | getCurrentScrollTop | current position Y | current accessor | TODO |
| 218 | validateScrollPosition | delegate | validate | TODO |
| 219 | setScrollPosition | Immediate => now; otherwise smooth | set_scroll_position | TODO |
| 220 | hasPendingScrollAnimation | delegate | pending accessor | TODO |
| 221 | deltaScrollNow | current plus both deltas; set now | delta_scroll_now | TODO |
| 222 | editorOptions smoothScrolling | Bool default false | ViewerOptions.smooth_scrolling | TODO |
| 223 | resolveOptions mouseWheelSmoothScroll | optional Bool default true | editor scrollbar fixed true | TODO |

Priority-3 member count: 62; whole-plan denominator and draft ledger:
223 members / 223 rows. Current status totals: TODO 219, N-A 4, PORTED 0,
TESTED 0, PASS 0, DEFERRED 0.

Review gate: stop here before implementation.

## Implementation order after review

### Milestone A — frame-work reduction

1. Give ViewLines the shared lines-content node and move top/left, layer
   hinting, and contain:strict writes to that node.
2. Remove content_transform writes from view-lines, view-zones,
   content-overlays, content-widgets, and cursors; keep only the independent
   margin vertical rail.
3. Introduce the narrow cached style wrapper and use it for lines-content,
   retained text rows, and retained overlay rows.
4. Replace the two ad-hoc recyclers with the source-ordered ViewLayerRenderer
   algorithm, including one batched new-row HTML write and one detached
   invalid-row batch.
5. Commit this milestone after checks and browser mutation/frame evidence.

### Milestone B — animation state and wheel routing

1. Port ScrollState, raw/current/future positions, the cubic animation
   operation, combine/reuse behavior, cancellation, and dimension
   revalidation into viewer/common/view_layout.
2. Inject a browser requestAnimationFrame scheduler; each animation tick
   updates model state through the existing apply_scroll path, so render
   coalescing remains one frame.
3. Add ViewerOptions.smooth_scrolling with Monaco's default false and keep the
   editor mouseWheelSmoothScroll value at Monaco's default true.
4. Port the classifier and route physical wheels to set_position_smooth;
   trackpads/magic mice and disabled smoothScrolling go to set_position_now.
5. Commit after upstream unit-test parity and browser input traces pass.

### Milestone C — performance/conformance closure

Add deterministic mutation instrumentation and source-relative frame
measurements, rerun the complete matrix, reconcile all 223 rows, paste the
closing source reread, and commit the evidence.

## Deviations (Phase 3)

1. Package placement follows dependency direction: pure scroll state and
   curves live in viewer/common/view_layout; wheel classification and DOM
   style caching live in viewer/ui/scrollbar; requestAnimationFrame injection
   and event consumption live in viewer/browser/controller/root Viewer.
2. TypeScript Disposable becomes a cancellation closure/handle supplied by
   the browser package. It must preserve the same cancellation points and
   guarded callback order.
3. Trusted Types policy handling is N-A because all HTML writes pass through
   the vendored RDOM sink. Batching and replacement order still follow the
   source.
4. disableLayerHinting is not a Viewer option. The source's default reachable
   value is retained (layer hinting enabled); the runtime option-change branch
   is N-A.
5. Chrome page-zoom normalization will use the browser facts exposed by the
   current RDOM/FFI boundary; no replacement scoring math is allowed.
6. flipAxes, scrollYToX, and inertialScroll are constant-folded to the editor
   defaults false. The predominant-axis, non-Mac shift conversion, alt fast
   scroll, sensitivity, future-target, validation, smooth-choice, and event
   consumption branches remain live and source-ordered.
7. Programmatic reveal remains immediate in this increment. The general
   Scrollable API is ported so a later complete reveal-method cluster can opt
   into ScrollType.Smooth without changing the animation implementation.

## Test matrix (Phase 4)

### Upstream unit oracles

- Port all five scrollable.test.ts cases unchanged in geometry and time:
  25, 75, 100, 125, and 500 lines at 20 px with an 800 px viewport and the
  exact visible-line pairs at 0/25/50/75/100/125 ms.
- Port all nine MouseWheelClassifier device traces:
  macOS Magic Mouse, macOS trackpad, macOS Razer, Windows Arc Touch,
  SurfaceBook touchpad, Windows Razer, Windows Logitech, Windows basic mouse,
  and Linux Wayland Logitech (including its first-event boundary).
- Additional state boundaries: duration 0 fallback; same-target early return;
  missing-axis merge; reuseAnimation true/false; cancel by immediate scroll;
  cancellation from event callback; dimension shrink during animation;
  exactly 2.5 viewport versus greater; completion exactly 1.

### Render/mutation matrix

- Window relation: unchanged window, one-line overlap shift, multi-line
  overlap shift, and no-overlap jump.
- Row state: unchanged, newly entering, invalid HTML, and leaving.
- View content: plain text; dense inline/margin decorations; selection and
  current-line overlays; view zones; content widgets and cursor.
- Axis: vertical only, horizontal only, and both.
- Assert steady movement mutates only shared lines-content top/left plus
  scrollbar geometry; unchanged retained-row top/height/line-height setters
  perform no DOM write.
- Assert new rows use one batch and invalid rows use one detached batch in the
  same order as ViewLayerRenderer.

### Browser frame matrix

- Input: physical-wheel trace and trackpad trace.
- smoothScrolling: false and true.
- Refresh cadence: 60 Hz and 120 Hz where the test host exposes it.
- Viewports: 10, 37, and 100 visible lines.
- Run the local viewer and the pinned Monaco harness with the same text,
  dimensions, deltas, and decoration load for three repetitions.
- Record requestAnimationFrame timestamps, presented scroll positions,
  long-frame count, p50/p95 frame interval, style/attribute writes,
  innerHTML/insert/remove counts, and forced-layout reads.
- Acceptance is source-relative: local dropped-frame ratio and p95 interval
  must not exceed the pinned Monaco run for the same trace, and structural
  mutation assertions above must be exact.

### Repository checks

- moon fmt
- moon info
- moon check --target all --warn-list +73
- targeted moon test for viewer/common/view_layout and viewer/ui/scrollbar
- just check
- just test-browser

## Exit gate (Phase 5)

- [ ] rows == members; done/deferred/N-A totals reported
- [ ] every ported function reread side-by-side with pinned source
- [ ] all behavior branches and configuration combinations covered
- [ ] all non-source-cited logic recorded under Deviations
- [ ] closing reread of every scoped source unit pasted below
- [ ] Milestones A–C committed as coherent validated commits

## Closing source reread

Pending implementation and final reconciliation.
