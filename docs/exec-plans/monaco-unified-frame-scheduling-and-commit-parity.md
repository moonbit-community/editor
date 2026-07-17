# Monaco Unified Frame Scheduling and Commit-Frame Parity

Status: In progress (Gate A reviewed)
Date: 2026-07-17  
Behavior oracle: VS Code / Monaco revision `b18492a288de038fbc7643aae6de8247029d11bd`

## Summary

Unify Viewer rendering, smooth scrolling, and touch inertia behind one
realm-global animation-frame scheduler with Monaco-compatible queue semantics.
Replace the current scroll cadence test's state-only sampling with a trace that
correlates scroll state changes, Viewer render flushes, and the actual
`.lines-content` DOM position write in the native frame where each occurred.

This is a mixed reference port:

- The shared frame queue is an **algorithm-fidelity port** of Monaco's
  `AnimationFrameQueueItem`, `scheduleAtNextAnimationFrame`, and
  `runAtThisOrScheduleAtNextAnimationFrame` behavior. Queue selection,
  priority, cancellation, coalescing, and reentrant scheduling are part of the
  contract.
- Registering Viewer rendering, `ViewModel` smooth scrolling, and touch inertia
  with that queue is a **behavior port**. The local ownership model remains
  MoonBit-native.
- The commit-frame probe is a **behavioral conformance harness**. It compares
  observable state-to-DOM latency with the pinned Monaco source and does not
  attempt to reproduce Monaco's private test infrastructure.

The plan does not make browser refresh cadence itself the success criterion.
Ambient 60 Hz or 120 Hz sampling remains useful metadata, but the primary
contract is whether a changed scroll state is committed to the visual rail in
the same native frame, or with no more frame lag than Monaco for the same input
cell.

## Motivation

The current implementation has multiple animation-frame ownership paths:

- `viewer/browser_host.mbt` directly calls
  `globalThis.requestAnimationFrame` for `ViewModel` smooth scrolling.
- The same file has a separate current-frame/next-frame queue for Viewer
  rendering.
- `internal/viewer/browser/controller/touch_scroll_gesture.mbt` owns another
  raw `requestAnimationFrame` handle for touch inertia.

Consequently, a smooth-scroll or touch-inertia callback can update scroll
state in one native frame and enqueue the corresponding Viewer render for the
next native frame. This extra hop is not visible to a test that samples only
`Viewer::get_scroll_top()` from an unrelated `requestAnimationFrame` loop.

The current browser parity test in
`tests/browser/perf/scroll_frame_parity.spec.js` measures scroll state and
global frame timestamps. It can pass while `.lines-content` still displays the
previous position. Its mutation probe protects against expensive line rebuilds,
but it does not establish which native frame contained the state transition,
render flush, or DOM commit.

Monaco avoids this split by routing editor rendering and scroll animations
through the same DOM animation-frame coordinator. A callback that requests an
editor render while that coordinator is draining may append the render to the
current queue; a callback that schedules the next animation tick still targets
the following native frame.

## Goals

- Establish one realm-global animation-frame coordinator in `base/browser`.
- Preserve Monaco's current-queue versus next-queue behavior, descending
  priorities, cancellation, native-frame coalescing, and reentrant ordering.
- Run Viewer rendering at priority `100`, matching Monaco's editor rendering
  coordinator.
- Route `ViewModel` smooth scrolling and touch inertia through the strict-next
  scheduling operation of the same coordinator.
- Preserve existing scroll state, `ViewLayout`, scroll events, DOM ownership,
  scrollbar behavior, inertia arithmetic, and public Viewer API.
- Add a disabled-by-default internal trace for scroll state, render flush, and
  DOM commit correlation.
- Compare real `.lines-content` position commits with Monaco under physical
  wheel, immediate trackpad, and touch-inertia inputs.
- Make the browser tests deterministic enough to distinguish an actual
  one-frame render delay from host cadence noise.

## Non-goals

- Changing the touch inertia velocity estimator, threshold, or
  `-0.005 px/ms²` friction constant.
- Replacing the editor rail with browser-native scrolling.
- A full port of Monaco's `PointerHandler`, rendering coordinator, view parts,
  or DOM utilities.
- Broad rendering-pipeline, GPU, minimap, editing, or line-recycling work.
- Optimizing every redundant DOM setter discovered by the trace. In
  particular, the current root-class write is recorded as mutation evidence;
  changing its ownership requires a separate source-grounded decision unless
  it blocks this plan's commit-frame contract.
- Exposing frame tracing or scheduling through the public Viewer API.
- Treating a browser paint/presentation timestamp as observable. The browser
  does not expose a reliable paint event per editor mutation; this plan defines
  a real commit as the actual `.lines-content` `top` or `left` DOM write.
- Guaranteeing a particular display refresh rate in CI.

## Current Inventory

### Local scheduling paths

| Consumer | Current path | Consequence |
| --- | --- | --- |
| Viewer render | `viewer/browser_host.mbt` current/next queue via `viewer/viewer_mount.mbt` | Has useful reentrant behavior but is private to the root package and has no priority. |
| Smooth scrolling | Raw scheduler injected by `viewer/attach_model.mbt` into `ViewModel` / `Scrollable` | A scroll-state tick and Viewer render may occupy adjacent native frames. |
| Touch inertia | Raw rAF/cancel runtime in `touch_scroll_gesture.mbt` | Own lifecycle and handle type; cannot join the Viewer render's current queue. |
| Immediate wheel/trackpad | `ViewLayout::delta_scroll_now` from controller input | State changes in the input task and render is scheduled for the next native frame. |

The canonical visual rail commit is in
`internal/viewer/browser/view/view_lines.mbt`, where `ViewLines::render_text`
updates the shared `.lines-content` node's cached `top` and `left` setters.

### Evidence Map

| Behavior or invariant | Pinned source | MoonBit disposition | Planned evidence |
| --- | --- | --- | --- |
| Queue item cancellation and priority | `src/vs/base/browser/dom.ts`, `AnimationFrameQueueItem` | Algorithm-fidelity | `base/browser` white-box scheduler tests |
| Strict next-frame queue, one native rAF, descending priority | `src/vs/base/browser/dom.ts`, `scheduleAtNextAnimationFrame` and queue drain | Algorithm-fidelity | Queue/coalescing/priority tests |
| Append to current drain when already in a frame | `src/vs/base/browser/dom.ts`, `runAtThisOrScheduleAtNextAnimationFrame` | Algorithm-fidelity | Reentrant current/next queue tests |
| Editor render priority `100` | `src/vs/editor/browser/view.ts`, `EditorRenderingCoordinator` | Behavior | Mounted Viewer trace and registration test |
| `ViewModel` uses shared strict-next scheduling | `src/vs/editor/browser/widget/codeEditor/codeEditorWidget.ts` plus `src/vs/base/common/scrollable.ts` | Behavior | Smooth-scroll state/flush/commit trace |
| Touch inertia uses shared strict-next scheduling | `src/vs/base/browser/touch.ts` | Behavior; inertia arithmetic remains the existing algorithm-fidelity port | Touch lifecycle white-box tests and mobile browser trace |
| Scroll state reaches `.lines-content` in the expected frame | `src/vs/editor/browser/viewParts/viewLines/viewLines.ts`, `src/vs/base/browser/fastDomNode.ts`, Monaco editor scroll events, and DOM mutation under the pinned build | Behavioral conformance | Playwright source-relative commit-frame matrix |

This is not a full source audit. DOM utility members, unrelated animation
consumers, browser workarounds, and editor view parts not named above are
`N-A (outside the selected scheduler and scroll-commit contract)`.

### Representation Decision

Use one concrete realm-global coordinator with disposable registration handles,
not a public trait or a Viewer-owned scheduler object. The implementation set is
closed, browser module state already supplies the correct lifetime, and the
only open boundary required by tests is the injected native rAF driver around
the private queue algorithm. Viewer-local render coalescing remains owned by
Viewer; only native-frame ordering is shared.

The internal observation seam remains a Viewer-id keyed callback registry
because it is optional test instrumentation with multiple mounted producers.
It is not promoted to a product event or a scheduling abstraction.

### Behavioral Deviations

No intentional deviation is planned within the selected queue-ordering and
scroll-commit contract. MoonBit representation, one coordinator per JavaScript
realm rather than Monaco's explicit per-window map, and internal trace plumbing
are non-observable representation differences for the supported single-realm
runtime.

The Gate A source review retained three pre-existing touch-port deviations:
zero-duration velocity windows do not start inertia, the stopped zero-delta
callback is not forwarded, and touch cancellation/per-View teardown is
stronger than Monaco's process-global Gesture lifetime. They remain outside
this scheduler rewrite's arithmetic scope and are covered by the existing
touch lifecycle tests.

Multiple browser windows sharing one JavaScript module instance are
`DEFERRED (the current Viewer host does not expose that ownership shape)`.
Exception isolation is handled as the explicit `N-A`/FFI review in the design
below. Refresh rates unavailable in CI are deferred as test-environment cells,
not behavioral deviations.

## Design

### 1. Realm-global frame coordinator in `base/browser`

Add a focused implementation in the `base/browser` package. Browser JavaScript
module state is already scoped to a realm; one concrete scheduler therefore
models Monaco's per-window coordinator for the editor's current single-window
runtime without adding a Viewer-owned instance.

Expose only the cross-package operations required by consumers:

```moonbit
pub fn schedule_at_next_animation_frame(
  callback : () -> Unit,
  priority? : Int = 0,
) -> Disposable

pub fn run_at_this_or_schedule_at_next_animation_frame(
  callback : () -> Unit,
  priority? : Int = 0,
) -> Disposable
```

The exact names may follow existing `base/browser` naming conventions, but the
semantics must remain distinct:

- `schedule_at_next_animation_frame` always enters the next queue, including
  when called from a callback in the current drain.
- `run_at_this_or_schedule_at_next_animation_frame` appends to the current
  queue only while that queue is draining; otherwise it enters the next queue.
- Enqueuing the first next item requests exactly one native rAF.
- Items run by descending priority. Items appended to the current queue are
  included in the next priority sort before execution continues.
- Disposing an item before execution marks it canceled and its callback is
  skipped. Disposal is idempotent.
- A strict-next callback scheduled while draining cannot execute in the same
  native frame.
- Empty or fully canceled queues do not create duplicate native requests.

Keep the production scheduler concrete, but separate the queue algorithm from
the native rAF boundary so white-box tests can inject a deterministic request
and drain clock. Do not add an abstract scheduler interface to unrelated
packages.

Because these operations cross package boundaries,
`base/browser/pkg.generated.mbti` is expected to change. No `moon.pkg`
dependency edge should change: the root Viewer and controller packages already
depend on `@base_browser`. `viewer/pkg.generated.mbti` and the public Viewer API
must remain unchanged.

MoonBit callbacks in this path are non-raising, so Monaco's exception isolation
inside a queue drain is `N-A (the local callback type does not expose a
throwing contract)`. If the JS FFI can still surface an exception, record the
observed behavior and either contain it at the FFI boundary or explicitly
defer it rather than silently changing the queue guarantees.

### 2. Register all scroll/render consumers with the shared coordinator

Replace the root-private scheduler in `viewer/browser_host.mbt` with calls to
`@base_browser`.

- `Viewer::schedule_render` continues to coalesce Viewer-local dirty state, but
  its frame callback is registered with
  `run_at_this_or_schedule_at_next_animation_frame(..., priority=100)`.
- The scheduler passed when constructing the `ViewModel` and `Scrollable` uses
  `schedule_at_next_animation_frame`. Each smooth-scroll tick therefore remains
  a strict next-frame animation step.
- The touch runtime schedules inertia ticks with the same strict-next operation
  and stores a `Disposable` instead of a raw numeric rAF handle. Starting a new
  touch, `touchcancel`, model replacement, or Viewer disposal disposes the
  pending item.
- Immediate trackpad input remains immediate state mutation followed by the
  normal render request. It is not converted into a synthetic animation.

The critical ordering for an animation-driven scroll becomes:

```text
native frame N drain
  smooth/touch tick (strict-next item)
    -> ViewLayout state and internal View scroll event
    -> Viewer render request (priority 100, current queue)
  Viewer render flush
    -> ViewLines writes .lines-content top/left
  next smooth/touch tick remains queued for native frame N+1
```

This ordering removes the avoidable animation-tick-to-render frame hop while
preserving one animation-state step per native frame.

Two Viewer instances in the same realm share the native request and priority
queue, but retain their own dirty flags, render callbacks, testing traces, and
disposal lifetimes. A disposed Viewer cancels only its queued item.

### 3. Internal state/flush/commit observability

Extend `internal/viewer/browser/testing` with a Viewer-id keyed,
disabled-by-default scroll-frame observation seam. Keep it internal and avoid
allocating observation records when no listener is installed.

The minimum local phases are:

- `StateCommitted`: an accepted scroll state change in
  `Viewer::apply_scroll_change`, after the new state is visible and before the
  render is requested.
- `RenderStarted`: immediately before `View::render` in
  `Viewer::flush_render`.
- `RenderFinished`: immediately after `View::render` returns.

Each observation contains the Viewer id, phase, `scroll_top`, and
`scroll_left`. The browser component scenario subscribes through
`@viewer_testing` and forwards observations to the page probe. The test probe
adds a continuously increasing native-rAF frame id and `performance.now()` at
the moment it receives each observation.

The DOM commit is intentionally observed outside MoonBit. Install a
`MutationObserver` on the mounted `.lines-content` style and record a commit
when its effective `top` or `left` value changes. The same page-level frame-id
clock timestamps the mutation. This proves that the render reached the actual
rail node and avoids declaring success from an internal method call alone.

For Monaco, collect:

- state through `editor.onDidScrollChange`;
- real commit through a `MutationObserver` on Monaco's `.lines-content`;
- frame id and time through the same probe algorithm used for the local Viewer.

The probe must preserve duplicate and coalesced observations in raw output.
Analysis groups by effective `(scroll_top, scroll_left)` position and reports
whether multiple state changes were intentionally coalesced into one visual
commit. It must not silently drop a state with no corresponding commit.

### 4. Define the commit-frame metrics

For each effective scroll position, compute:

- `stateFrame`: frame id at the accepted state transition;
- `renderStartFrame` and `renderFinishFrame` for the local Viewer;
- `commitFrame`: frame id of the first `.lines-content` top/left mutation that
  reflects that position;
- `stateToCommitLag = commitFrame - stateFrame`;
- commits per distinct position and unmatched states/commits;
- source-relative lag: local result minus Monaco result for the same matrix
  cell.

Frame ids are advanced by a page-owned recursive rAF callback installed before
input begins. Because rAF callbacks in one native frame share a timestamp but
have registration order, the probe also records timestamps and sequence
numbers. The analysis treats events with the same rAF timestamp as the same
native frame even if the counter callback runs before or after a scheduler
callback. Tests must not infer an extra frame solely from JavaScript callback
ordering inside one timestamp.

For programmatic or input-task state changes that occur between rAF callbacks,
the source-relative comparison is authoritative. For animation-driven smooth
scroll and touch inertia, the unified queue has the stronger local contract:
state, render start/end, and matching DOM commit have zero native-frame lag.

Ambient rAF interval, p50/p95 frame duration, and dropped-frame ratios remain
diagnostic output. They do not substitute for the phase correlation above.

## Acceptance Criteria

### Scheduler algorithm

- Multiple strict-next registrations before a frame request produce one native
  rAF and all eligible callbacks execute once.
- `run_at_this_or_schedule_at_next_animation_frame` called outside a drain runs
  in the next native frame.
- The same operation called during a drain can execute in the current native
  frame.
- Strict-next registration during a drain executes only in the following
  native frame.
- Callbacks execute by descending priority, including callbacks appended
  reentrantly to the current queue.
- Cancellation before execution, repeated disposal, cancellation during a
  drain, and a queue containing only canceled items are deterministic and do
  not cause duplicate native requests.
- Bounded reentrant scheduling loses no callback and executes no callback
  twice. As in Monaco, an unbounded callback that recursively uses the
  current-frame operation can keep the drain alive; animation consumers must
  use the strict-next operation for their next tick.

### Scroll and rendering behavior

- Viewer render uses shared current-or-next scheduling at priority `100`.
- Smooth scrolling and touch inertia each advance at most once per native frame
  through shared strict-next scheduling.
- For animation-driven local state changes, the matching render and
  `.lines-content` commit occur in the same native frame.
- A new touch, `touchcancel`, model switch, detach, or Viewer disposal prevents
  late inertia callbacks and late DOM commits.
- Two mounted Viewers share one realm scheduler without starvation or trace
  cross-talk.
- Public scroll events, final scroll positions, scrollbar visibility, and
  existing scroll-boundary behavior remain unchanged.

### Monaco comparison

- In every required matrix cell, local `stateToCommitLag` is no greater than
  Monaco's lag for the same source and input.
- Smooth physical-wheel and touch-inertia cells have a local maximum
  `stateToCommitLag` of zero native frames after the first accepted animation
  state.
- Immediate trackpad cells report source-relative state-to-commit lag and final
  position; they are not judged by unrelated background rAF cadence alone.
- Every distinct visually relevant state has a matching commit, or is reported
  as a coalesced state with source-equivalent behavior. Missing commits fail.
- Unexpected commits with no effective state change fail unless both local and
  Monaco demonstrate the same final normalization behavior.
- Final `scroll_top` and `scroll_left` match expected bounds and the Monaco
  direction/sign convention.
- Steady same-window scrolling performs no `innerHTML` replacement or line
  recycler batch. Attribute/style mutation counts, including root-class writes,
  are reported and may not regress relative to the pre-change local baseline.

## Test Plan

### Focused scheduler white-box tests

Add `base/browser/*_wbtest.mbt` coverage with an injected native-frame driver:

1. strict-next coalescing and FIFO ordering at equal priority;
2. descending priority across the initial queue;
3. outside-drain current-or-next behavior;
4. current-drain append and priority re-sort;
5. strict-next scheduling from the current drain;
6. cancellation before execution and cancellation by an earlier callback;
7. idempotent disposal and all-canceled queue cleanup;
8. nested current and next registrations with no lost or duplicate callback;
9. two logical consumers sharing one native request;
10. no new request after the scheduler becomes idle.

Assert frame numbers and callback order directly. Do not use wall-clock sleeps.

### Controller and lifecycle tests

Extend the touch gesture white-box suite to cover the `Disposable` scheduler
handle:

- a fresh touch disposes the pending inertia frame;
- `touchcancel`, zero-time samples, and controller disposal leave no runnable
  item;
- each completed fake frame schedules at most one following inertia frame;
- the existing sample window, velocity, friction, multi-touch, and threshold
  expectations remain unchanged.

Add mounted/root coverage for model switch, detach, and Viewer disposal while a
render or smooth-scroll item is pending. Assert no public scroll event, render
trace, or DOM mutation after disposal.

### Component and Playwright commit-frame probe

Replace the state-only success path in
`tests/browser/perf/scroll_frame_parity.spec.js` with the correlated trace.
Retain the existing cadence summary as diagnostics and retain the structural
DOM mutation checks.

The deterministic comparison matrix covers:

| Input | Path | Axes | Required modes |
| --- | --- | --- | --- |
| Physical wheel | Smooth animation | Vertical and horizontal | Smooth scrolling enabled; disabled control cell |
| Trackpad-like wheel | Immediate | Vertical and horizontal | Existing wheel classifier path |
| Touch drag and release | Immediate drag plus inertia | Vertical, horizontal, diagonal | Chromium `hasTouch` mobile viewport |

Run viewport/content positions that exercise approximately 10, 37, and 100
visible lines, including a mid-document steady window and a boundary case.
Repeat each timing cell three times and report the worst state-to-commit lag.

Use deterministic synthetic wheel dispatch for exact local/Monaco comparison,
then retain real Chromium input smoke coverage for the user path:

- CDP/Playwright wheel input for scrolling;
- Chromium touch input for drag, release, inertia, outer-page stability, and
  scrollbar fade;
- public `view:scroll`, first visible line, and final position assertions.

Exercise 60 Hz and 120 Hz when the host/browser configuration exposes them.
Unavailable refresh rates are `DEFERRED (CI host does not expose deterministic
display cadence)`, not silently treated as covered. The frame-id contract
itself remains cadence-independent.

### Regression protection

Keep or add assertions that steady scrolling:

- mutates the shared `.lines-content` rail position rather than rebuilding line
  HTML;
- does not invoke a recycler batch while the visible content window is stable;
- does not scroll the outer document during a consumed touch gesture;
- emits the expected public scroll event values;
- preserves scrollbar show/fade timing;
- produces no late callback or mutation after teardown.

## Execution Milestones

### Gate A: Freeze the baseline and evidence map

Before product edits:

1. Record the current local and Monaco state-only cadence result for physical
   wheel, trackpad, and touch where available.
2. Add a temporary/read-only commit probe to confirm whether the current split
   scheduler produces a one-frame state-to-DOM gap.
3. Record current style/attribute, `innerHTML`, and recycler mutation counts.
4. Re-read the pinned Monaco queue and consumer call sites named in the evidence
   map and record any source difference that changes the selected contract.
5. Review the baseline against this plan. Continue automatically unless the
   source requires a public API, dependency, or behavior expansion not covered
   here.

Gate A produces evidence, not a standalone architecture-lint script.

#### Gate A review record (2026-07-17)

- The existing 12-cell physical-wheel/trackpad matrix passed at the host's
  observed 120 Hz cadence with zero dropped-frame ratio and the expected final
  positions (`50px` physical, `6px` trackpad); deterministic 60 Hz remains
  unavailable on this host.
- A temporary callback-span probe confirmed the split-scheduler defect in all
  three smooth physical-wheel viewport cells. Across three repetitions per
  cell, Monaco committed every animated state in its coordinating callback
  (`37-38` same-callback state/rail transitions), while the local Viewer
  recorded `36-39` state-only callbacks followed by the same number of
  rail-only callbacks in the next native frame.
- The steady immediate-trackpad baseline recorded `18` attribute writes and no
  `innerHTML` write per local repetition. The physical-wheel control crossed
  retained row windows and therefore retained its existing recycler evidence;
  the implementation must not increase either baseline.
- The existing mobile smoke passed for consumed drag, post-release inertia,
  outer-page stability, public scroll delivery, visible-line advance, and
  scrollbar fade.
- Pinned-source review confirmed queue selection, per-item cancellation,
  stable descending-priority execution, and one pending native request. An
  all-canceled queue still consumes its already-requested native frame, and
  recursive current-frame registration is not intrinsically bounded; the
  acceptance text above now matches those Monaco semantics.
- Gate A also confirmed that the final generated-interface review must contain
  the intended `base/browser` scheduler additions and the internal testing
  observation seam. Root `viewer`, controller, view-model, and view-layout
  interfaces and all `moon.pkg` dependency edges must remain unchanged.
- `internal/viewer/browser/controller/drag_scrolling.mbt` retains its separate
  selection-drag rAF owner and is N-A for this selected render/smooth/touch
  contract.

### Milestone A: Shared scheduler and algorithm tests

- Implement the realm-global coordinator in `base/browser`.
- Add deterministic white-box tests for queue selection, priority,
  cancellation, coalescing, and reentrancy.
- Regenerate/check `base/browser/pkg.generated.mbti` and confirm no unexpected
  package interface changes.
- Run focused `base/browser` checks and commit this milestone.

Suggested commit: `feat(browser): unify animation frame scheduling`

### Milestone B: Rewire Viewer, smooth scrolling, and touch inertia

- Remove the root-private frame queue and raw scheduler duplication.
- Register Viewer rendering at priority `100`.
- Pass shared strict-next scheduling to `ViewModel` / `Scrollable`.
- Convert touch inertia to the shared disposable registration.
- Add lifecycle, two-Viewer, and touch cancellation tests.
- Confirm `viewer/pkg.generated.mbti` is unchanged and commit this milestone.

Suggested commit: `refactor(viewer): share render and scroll frame queue`

### Milestone C: Real commit-frame conformance tests

- Add the internal Viewer-id keyed state/render observation seam.
- Extend the component scenario to forward observations to JavaScript.
- Observe `.lines-content` position mutations for both local Viewer and Monaco.
- Replace state-only pass/fail criteria with the source-relative
  state/flush/commit analysis.
- Run the deterministic matrix and real wheel/touch smoke.
- Update architecture, harness, browser-test, Viewer, and controller docs to
  describe scheduler ownership and what a commit-frame test proves.
- Commit the harness and documentation milestone.

Suggested commit: `test(scroll): verify real DOM commit frames`

### Final validation

Run, in order:

1. focused `base/browser`, Viewer root, controller, and component scenario
   checks;
2. `moon info --target all` for touched packages and inspect all generated
   `.mbti` changes;
3. `just test-browser-perf`;
4. `just test-browser-smoke`;
5. `just check`;
6. `just test`;
7. `just build`;
8. `just test-browser`.

Failures caused by missing display cadence may defer only that cadence cell;
they may not defer the scheduler white-box contract, state/flush/commit trace,
or default Chromium comparison.

After implementation and validation, compress the durable decisions and source
evidence into `docs/exec-plans/HISTORY.md`, update owning package READMEs, and
remove this active plan.

## Documentation Updates

- `docs/architecture.md`: make `base/browser` the owner of realm-global frame
  coordination and document the allowed dependency direction.
- `docs/harness.md` and `tests/browser/README.md`: distinguish state sampling,
  DOM commit-frame testing, and ambient cadence diagnostics.
- `viewer/README.md`: describe Viewer render registration and priority without
  exposing a public scheduler API.
- `internal/viewer/browser/controller/README.md`: state that touch inertia uses
  the shared strict-next frame queue.
- `docs/references/monaco.md`: add the pinned scheduler, editor rendering, and
  touch consumer source locations if they are not already mapped.

## Risks and Controls

- **Reentrant infinite work in one frame:** preserve Monaco's explicit queue
  semantics, test nested scheduling, and ensure animation ticks use strict-next
  rather than current-queue scheduling.
- **Global queue cross-talk:** key observations and cancellation by Viewer while
  sharing only the realm's native request. Test two mounted Viewers.
- **Probe perturbs timing:** keep observation disabled by default, avoid record
  allocation without listeners, and compare probe-on local/Monaco runs with the
  same page-level clock.
- **MutationObserver delivery is microtask-based:** correlate the changed
  effective rail values and the rAF timestamp/sequence, not observer callback
  ordering alone. Add a direct test fixture proving the frame classifier.
- **Synthetic input hides browser behavior:** use it only for deterministic
  comparison and retain real wheel/touch smoke for the user path.
- **Refresh-rate flakiness:** make frame identity and source-relative lag the
  acceptance metric; report elapsed time and cadence separately.
- **Scope creep from incidental DOM writes:** report redundant writes and block
  regressions, but require a separate evidence-backed plan for unrelated view
  invalidation changes.

## Completion Checklist

- [ ] Gate A baseline and pinned-source evidence are recorded.
- [ ] One `base/browser` coordinator owns current and next frame queues.
- [ ] Queue semantics have deterministic white-box coverage.
- [ ] Viewer render uses priority `100` on the shared current/next queue.
- [ ] Smooth scroll and touch inertia use the shared strict-next queue.
- [ ] Pending work is canceled on all relevant lifecycle exits.
- [ ] Internal state/render observation is disabled by default and Viewer-id
      isolated.
- [ ] Local and Monaco `.lines-content` commits use the same frame classifier.
- [ ] Browser acceptance is based on state-to-real-commit lag, not state-only
      sampling.
- [ ] Structural mutation and public scroll behavior regressions remain covered.
- [ ] Required MoonBit and browser suites pass.
- [ ] Generated interface review shows only the intended `base/browser`
      additions and internal testing observation seam; the public Viewer and
      other touched consumer interfaces remain unchanged.
- [ ] Documentation and execution-plan history are updated.
