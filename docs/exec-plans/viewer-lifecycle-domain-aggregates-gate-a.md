# Viewer Lifecycle-Domain Internal Aggregates — Gate A

Status: inventory ready — STOP FOR REVIEW; no product implementation has
started

Date: 2026-07-15

Parent plan: `viewer-lifecycle-domain-aggregates.md`

Product baseline: `87467b1be9a7b143434cc64e772e15d2780ca7a0`

Plan commit inspected before this artifact:
`bdd2139be5905a23df3fc7ceeaaf79915d7b2e0e`

Oracle commit: `b18492a288de038fbc7643aae6de8247029d11bd`

This is the mandatory documentation-only pre-implementation snapshot. No
MoonBit product source, test, package manifest, README, generated interface,
browser scenario, CSS, or generated web source changed while producing it.
The plan commit's parent is the product baseline above, and the only diff from
that parent before Gate A was the parent plan itself.

## Gate Result

The baseline is stable and the proposed representation is executable without a
new source-parity denominator:

- the current `Viewer` record has exactly **49** fields;
- its extracted field sequence exactly equals `VFD-001..049` in the parent
  ledger, with no missing, extra, or reordered field;
- **22** fields remain direct and **27** move into the selected owners;
- the `vscode` gitlink, checked-out submodule, five source hashes, and named
  owner clusters have not drifted;
- constructor, model attach, model detach, and render-flush control flow match
  the required traces;
- Gate A corrected one disposal-trace compression in the proposed plan so the
  retained hover resource stays at its actual cleanup slot;
- the focused pre-edit MoonBit baseline is **115/115**, the direct model-swap
  browser baseline is **1/1**, all-target warning-enabled checking passes, and
  `viewer/pkg.generated.mbti` is unchanged.

The reviewed target decisions are therefore:

1. `ModelData.browser=None` is the only model-without-real-View state.
2. `ModelBrowserData` contains the `View`, its retained `MouseHandler`, the
   rendered window, and the deferred horizontal-reveal request. `View` remains
   the handler's sole disposal owner.
3. `ViewerMount::Headless` and `Mounted(MountedViewer)` distinguish the private
   harness from the public mounted path; the placeholder root/text are one
   `PlaceholderDom` value.
4. `CursorEventDelivery::reset_model_scope` clears queued model facts without
   forcing an active `is_draining` gate to false.
5. `EditorContributions` remains the sole instance store. Content-hover
   behavior disposal runs at the existing contribution slot, the wrapper then
   becomes non-lookuppable `Disposing`, and the retained widget/scrollable is
   disposed at the current later slot before storage is cleared.
6. `Viewer::set_model` and `Viewer::dispose` remain the visible cross-domain
   orchestrators; no aggregate receives a raw `Viewer` back-reference.

Product edits remain blocked until these decisions are reviewed.

## Baseline and Pinned Source Evidence

`bdd2139` has parent `87467b1`, and
`git diff --name-status 87467b1..bdd2139` contains only
`docs/exec-plans/viewer-lifecycle-domain-aggregates.md`. Excluding that path
produces an empty product diff. Both the root and `vscode` worktrees were clean
before this Gate A document was created.

The root gitlink and the checked-out `vscode` `HEAD` are both the oracle commit
above. All hashes match the parent plan exactly:

| Source | SHA-256 |
|---|---|
| `vscode/src/vs/editor/browser/widget/codeEditor/codeEditorWidget.ts` | `18dd294ed185a29c590df75656f18f27d0cefc8d4d778559db946d447130e5d8` |
| `vscode/src/vs/editor/test/browser/testCodeEditor.ts` | `339584740ad74f23fbf4aaadbd901f899085c1241082a543d586e1d2a7ea1785` |
| `vscode/src/vs/editor/browser/widget/codeEditor/codeEditorContributions.ts` | `3cd98c20ffa0e0f691c38ecd30723240ee91536e2a542bde83e65c2d412ebb99` |
| `vscode/src/vs/editor/browser/view.ts` | `22edb04795705b7fc8675ba40d89c448a62141201f1a16b1f20d8b26e82771e2` |
| `vscode/src/vs/editor/contrib/hover/browser/contentHoverController.ts` | `2e811bcc9ca11606040a9cc127ab178eb29d7be58e6655e4a619e25534f77592` |

The closing owner-cluster reread found the same source facts:

- `CodeEditorWidget` still has direct emitters plus shared delivery-queue,
  configuration, contribution, and model owners, while `setModel`, attach, and
  detach remain explicit root orchestration;
- `TestCodeEditor::_createView` still returns a no-real-View result;
- `CodeEditorContributions._instances` remains the one instance store while
  `_pending` stores descriptions only;
- `View` owns pointer-handler/render-frame lifecycle; and
- `ContentHoverController` lazily owns and disposes its content widget.

Reproduction:

```sh
git rev-parse HEAD HEAD^
git diff --name-status 87467b1be9a7b143434cc64e772e15d2780ca7a0..HEAD
git -C vscode rev-parse HEAD
git ls-tree HEAD vscode
shasum -a 256 \
  vscode/src/vs/editor/browser/widget/codeEditor/codeEditorWidget.ts \
  vscode/src/vs/editor/test/browser/testCodeEditor.ts \
  vscode/src/vs/editor/browser/widget/codeEditor/codeEditorContributions.ts \
  vscode/src/vs/editor/browser/view.ts \
  vscode/src/vs/editor/contrib/hover/browser/contentHoverController.ts
```

## Complete Viewer Field Reconciliation

The field extractor counts only top-level `priv` declarations between
`pub struct Viewer {` and its closing brace. Comparing that sequence with the
field names extracted from the VFD table produced an empty `diff`:

```sh
awk '
  /^pub struct Viewer \{/ { in_viewer=1; next }
  in_viewer && /^}/ { exit }
  in_viewer && /^  priv / {
    line=$0
    sub(/^  priv (mut )?/, "", line)
    sub(/ :.*/, "", line)
    count += 1
    printf "%02d %s\n", count, line
  }
  END { printf "COUNT=%d\n", count }
' viewer/viewer.mbt

diff -u \
  <(awk '/^pub struct Viewer \{/ { v=1; next } v && /^}/ { exit }
     v && /^  priv / { x=$0; sub(/^  priv (mut )?/, "", x);
     sub(/ :.*/, "", x); print x }' viewer/viewer.mbt) \
  <(sed -n 's/^| VFD-[0-9][0-9][0-9] | `\([^`]*\)` |.*$/\1/p' \
     docs/exec-plans/viewer-lifecycle-domain-aggregates.md)
```

The exact disposition denominator is:

| Owner after implementation | VFD rows | Fields | Count |
|---|---|---|---:|
| direct `Viewer` | 001–005, 007–010, 015–023, 038, 043–045 | services/provenance, global gate/stores, public/testing emitters, scroll baseline, overlay registry, render-publication facts, editor id | 22 |
| `EditorConfigurationState` | 006, 029–034, 042 | options, font, measured box, model/view counts, wrap column, measure request | 8 |
| `CursorEventDelivery` | 011–014 | queue, drain gate, barrier depth, completed versions | 4 |
| `ViewerModelSlot` | 024–025 | current `ModelData`, generation | 2 |
| nested `ModelBrowserData` | 026, 046, 048 | rendered window, mouse handler, horizontal reveal | 3 |
| nested `ContentHoverContributionState` | 027–028, 040–041 | widget, widget view, timeout scheduler, async launcher | 4 |
| `ViewerMount` / `MountedViewer` / `PlaceholderDom` | 035–037, 039, 047 | container, placeholder pair, render frame, focus | 5 |
| `EditorContributions` | 049 | sole contribution instance map | 1 |
| **Total** | **VFD-001..049** | **49 unique source fields** | **49** |

There are no new fields to assign. `ModelData.view` is outside the 49-field
denominator because it is already nested; Milestone D replaces that one nested
field with `browser : ModelBrowserData?`.

## Moving-Field Reader and Writer Inventory

`moon ide outline viewer/viewer.mbt`, `moon ide peek-def Viewer` at the record,
and location-qualified `moon ide find-references` were used before the `rg`
audit. The reference counts below include the declaration and constructor
entry. The file column is the complete semantic file set relative to
`viewer/`; every file not named in the mutation column is a reader or a
white-box direct observer.

| Field | Semantic refs | Complete files | Mutation sites |
|---|---:|---|---|
| `options` | 67 | `viewer.mbt`, `attach_model.mbt`, `input.mbt`, `view_host.mbt`, `decorations_api.mbt`, `public_read_api.mbt`, `folding_host.mbt`, `folding_contribution.mbt`, `agent_feedback_host.mbt`, `agent_feedback_host_wbtest.mbt`, `layout_content_width_wbtest.mbt`, `render_whitespace_options_wbtest.mbt`, `view_event_sources_wbtest.mbt` | constructor and `Viewer::update_options`; `layout_content_width_wbtest` and `view_event_sources_wbtest` directly seed it |
| `cursor_delivery_queue` | 13 | `viewer.mbt`, `cursor_event_delivery.mbt`, `cursor_transition_wbtest.mbt` | constructor; enqueue/remove/reset in `cursor_event_delivery.mbt:37-129` |
| `cursor_delivery_is_draining` | 5 | `viewer.mbt`, `cursor_event_delivery.mbt` | constructor; set on drain entry/exit at `:73-120`; reset deliberately does not write it |
| `cursor_content_barrier_depth` | 9 | `viewer.mbt`, `cursor_event_delivery.mbt`, `cursor_transition_wbtest.mbt` | constructor; recompute/reset at `:21-29,126-129` |
| `cursor_completed_content_versions` | 10 | same three files | constructor; push/remove/reset at `cursor_event_delivery.mbt:54-65,85-94,126-129` |
| `model_data` | 18 | `viewer.mbt`, `attach_model.mbt`, `view_host.mbt`, `view_zones_host.mbt`, `hidden_areas_event_order_wbtest.mbt` | constructor; complete install at `attach_model.mbt:172-178`; clear at `viewer.mbt:719`; one white-box test temporarily replaces it |
| `model_data_generation` | 8 | `viewer.mbt`, `attach_model.mbt`, `set_value_api_wbtest.mbt` | constructor; increment at attach `:11` and detach `viewer.mbt:689`; test reads no-op stability |
| `rendered_window` | 10 | `viewer.mbt`, `attach_model.mbt`, `view_host.mbt`, `set_value_api_wbtest.mbt` | set by `synced_window`; invalidated on attach/line mapping/detach/dispose; one white-box test seeds it |
| `content_hover_widget` | 15 | `viewer.mbt`, `attach_model.mbt`, `content_hover_widget_host.mbt`, `controller_host.mbt`, `editor_events.mbt`, `hover_contribution.mbt` | lazy creation at `content_hover_widget_host.mbt:131-164`; final clear at `viewer.mbt:928-932` |
| `hover_widget_view` | 6 | `viewer.mbt`, `content_hover_widget_host.mbt` | equality-gated sync at `content_hover_widget_host.mbt:26-48`; final clear at `viewer.mbt:933` |
| `font_info` | 40 | `viewer.mbt`, `attach_model.mbt`, `input.mbt`, `view_host.mbt`, `controller_host.mbt`, `content_hover_widget_host.mbt`, `editor_events.mbt`, `public_read_api.mbt`, `selection.mbt`, `agent_feedback_widgets_host.mbt`, `render_whitespace_options_wbtest.mbt`, `view_event_sources_wbtest.mbt` | estimated in constructor; refreshed at `input.mbt:126-142`; `view_event_sources_wbtest` replaces it |
| `measured_content_width` | 21 | `viewer.mbt`, `attach_model.mbt`, `input.mbt`, `layout_content_width.mbt`, `public_read_api.mbt`, `test_viewer_wbtest.mbt`, `layout_content_width_wbtest.mbt` | writes at `input.mbt:196`, `layout_content_width.mbt:28`, and the two white-box test seams |
| `measured_height` | 10 | `viewer.mbt`, `attach_model.mbt`, `input.mbt`, `layout_content_width.mbt`, `public_read_api.mbt`, `test_viewer_wbtest.mbt`, `layout_content_width_wbtest.mbt` | writes at `input.mbt:201` and the two white-box test seams |
| `layout_model_line_count` | 20 | `viewer.mbt`, `attach_model.mbt`, `input.mbt`, `view_event_sources_wbtest.mbt` | attach, options/measure/line-mapping commits, detach reset |
| `layout_line_count` | 17 | same four files | attach, options/measure/line-mapping commits, detach reset |
| `soft_wrap_column` | 16 | `viewer.mbt`, `attach_model.mbt`, `input.mbt`, `view_host.mbt`, `test_viewer_wbtest.mbt` | option/measure commits and package-private headless helper |
| `container` | 13 | `viewer.mbt`, `attach_model.mbt`, `view_host.mbt`, `content_hover_widget_host.mbt`, `lifecycle_ownership_wbtest.mbt` | initialized `None`, written once by private `attach`, deliberately retained after disposal |
| `placeholder_element` | 10 | `viewer.mbt`, `attach_model.mbt`, `view_host.mbt`, `lifecycle_ownership_wbtest.mbt` | paired creation in `attach`; cleared in `dispose` |
| `placeholder_text` | 5 | `viewer.mbt`, `view_host.mbt` | paired creation in `attach`; cleared in `dispose` |
| `render_frame` | 10 | `viewer.mbt`, `view_host.mbt`, `public_read_api.mbt`, `lifecycle_ownership_wbtest.mbt` | coalesced schedule/callback clear and explicit cancellation |
| `hover_schedule_timeout` | 7 | `viewer.mbt`, `editor_events.mbt` | production constructor plus deterministic test-host replacement |
| `hover_launch_async_task` | 4 | `viewer.mbt`, `editor_events.mbt` | production constructor plus deterministic test-host replacement |
| `measure_requested` | 17 | `viewer.mbt`, `attach_model.mbt`, `input.mbt`, `layout_content_width.mbt`, `view_host.mbt`, `lifecycle_ownership_wbtest.mbt`, `view_event_sources_wbtest.mbt` | set by attach/options/layout/font/content-width paths; consumed by render; cleared on disposal |
| `mouse_handler` | 8 | `viewer.mbt`, `input.mbt`, `attach_model.mbt`, `controller_host.mbt`, `content_hover_widget_host.mbt` | installed by `hook_view_input`; cleared on detach/disposal |
| `editor_has_focus` | 11 | `viewer.mbt`, `input.mbt`, `view_host.mbt` | focus/blur listeners, no-model replacement reset, disposal reset |
| `horizontal_reveal_request` | 39 | `viewer.mbt`, `reveal.mbt`, `reveal_wbtest.mbt`, `cursor_input_wbtest.mbt`, `cursor_command_shape_wbtest.mbt` | arm/consume/cancel in `reveal.mbt:363-461`; detach/disposal reset; direct white-box branch probes |
| `contributions` | 42 | `viewer.mbt`, `editor_extensions.mbt`, `agent_feedback_host.mbt`, `agent_feedback_widgets_host.mbt`, `editor_events.mbt`, `folding_host.mbt`, `quick_diff_contribution.mbt`, `agent_feedback_host_wbtest.mbt`, `editor_extensions_wbtest.mbt`, `folding_host_wbtest.mbt`, `lifecycle_ownership_wbtest.mbt`, `quick_diff_host_wbtest.mbt` | central insertion at `editor_extensions.mbt:422-448`; ordered disposal/current clear at `viewer.mbt:917-920`; white-box tests inject/listen through the actual map |

The complete semantic count is **451 references** across the 27 moving fields.
The direct test coupling is intentional current evidence, not a reason to
widen the new owners. Milestones B–F must migrate these tests to semantic
package-private helpers or to the private owning aggregate:

- `cursor_transition_wbtest` reads queue/barrier/completed-version internals;
- `hidden_areas_event_order_wbtest` temporarily replaces `model_data`;
- `set_value_api_wbtest` reads generation and seeds the rendered window;
- configuration/render white-box tests directly seed options, font, geometry,
  line counts, wrap, or measure-request facts;
- lifecycle tests read container/placeholder/render-frame/contribution state;
- reveal/cursor tests directly inspect the horizontal reveal request; and
- contribution tests directly install listeners or temporary entries in the
  one real central map.

No ordinary external package can access these fields; `Viewer` remains opaque
in `viewer/pkg.generated.mbti`.

## Current and Required Lifecycle Traces

### Private headless construction

Current source order (`viewer/viewer.mbt:234-321`) is already the required
order:

1. resolve borrowed-vs-owned services;
2. derive estimated `FontInfo` from the chosen options;
3. allocate every field with model `None`, container `None`, no frame, empty
   cursor state, and empty contribution map;
4. install the Viewer-lifetime marker-decoration subscription;
5. construct and initialize all contributions once;
6. install the testing registration; and
7. return without DOM, browser `View`, `MouseHandler`, or rAF work.

The target replaces the field groupings only. `with_test_viewer` continues to
install a real model/ViewModel with `ModelData.browser=None`.

### Public mount

Current `Viewer::create` constructs first and calls private `attach`
(`viewer/viewer.mbt:394-401`). `attach` (`:574-604`) rejects disposed/already
attached state, retains the host, creates and mounts the placeholder root/text
pair, subscribes to font measurement, marks measurement pending, and schedules
one root frame. The target one-way `Headless -> Mounted` transition preserves
that order while making the pair atomic.

### Model attach

Current `Viewer::attach_model` (`viewer/attach_model.mbt:10-195`) matches the
required trace exactly:

1. increment and capture the generation;
2. append decoration, marker-lease, content, and will-dispose listeners;
3. acquire the attached-view handle;
4. build the ViewModel;
5. commit model/view line counts;
6. append cursor, view-zone, and token listeners guarded by the captured
   generation, plus the layout listener whose lifetime is bounded by the same
   listener store;
7. create a browser View only when a container exists;
8. hook input and rebind/remount persistent hover and overlay widgets;
9. install one complete `ModelData`;
10. emit/flush initialization facts, mark the pending render/measure, and
    schedule the frame.

Milestone D changes step 7's result from `View?` to `ModelBrowserData?` and
makes `hook_view_input` return the registered handler. It must not move step 9
earlier.

### Model detach and replacement

`Viewer::set_model` captures text focus, detaches, attaches, restores or clears
focus, fires `did_change_model`, then sweeps outgoing owner decorations
(`viewer/viewer.mbt:629-679`). Current detach (`:687-748`) is:

1. guard/capture the complete outgoing `ModelData`;
2. increment generation;
3. cancel the root frame;
4. clear cursor model facts while leaving the active drain gate untouched;
5. cancel mouse selection;
6. reset hover, feedback input, and feedback widget state;
7. dispose listeners -> attached-view lease -> View -> ViewModel;
8. clear `model_data` only after disposal;
9. reset model/view line counts;
10. remove the outgoing View DOM and restore the placeholder when not
    disposing;
11. clear the handler, rendered window, and horizontal reveal request.

The target nests step 11 inside the dropped browser bundle. It must not use an
early `take()` or clear the generation/drain gate differently.

For `set_model(None)`, the root schedules placeholder rendering immediately
after detach and before focus normalization and `did_change_model`
(`viewer/viewer.mbt:655-672`); that ordering remains explicit in the target
transaction.

### Render scheduling and flush

Current scheduling (`viewer/view_host.mbt:175-188`) returns when disposed,
already scheduled, or headless, then clears the frame slot before calling the
flush. Current flush (`:66-150`) branches:

1. disposed -> return;
2. no `ModelData` -> render the mounted placeholder and return;
3. `ModelData.view=None` -> return without DOM work;
4. consume a measure request, render the View, sync the rendered window, flush
   horizontal reveal, publish pending-render facts, and publish dirty scroll
   facts.

The target expresses the scheduling guard through `ViewerMount` and the third
branch through `ModelData.browser`; publication remains root orchestration.

### Viewer disposal and Gate A correction

The proposed plan originally placed all direct render-publication clearing
before retained hover-resource disposal. That did not match current source.
Current `Viewer::dispose` (`viewer/viewer.mbt:890-960`) performs:

1. idempotency guard and `disposed=true`;
2. cancel frame;
3. clear overlay registration;
4. silently detach and sweep owner decorations;
5. remove the mounted placeholder while retaining the caller host;
6. fire `did_dispose` while contribution and lifetime state is reachable;
7. dispose contribution behavior and clear today's map;
8. dispose Viewer-lifetime subscriptions;
9. clear placeholder, mouse/focus, and `last_scroll_event` state;
10. dispose the hover widget scrollable and clear widget/view cache;
11. clear pending-render, rendered-window, reveal, measure, and scroll facts;
12. dispose emitters, testing registration, and default-owned services.

The parent plan now preserves steps 8–11. The target wrapper cannot clear its
map at current step 7 because the hover widget moves into its content-hover
entry. Instead it marks the wrapper `Disposing` and non-lookuppable there,
performs the same behavior disposal, preserves the current lifetime and mount
clears, disposes the retained widget at current step 10, clears the
contribution widget/cache and storage there, and then clears the remaining
post-hover render facts. Public callbacks cannot observe entries in the
intermediate state, and no second map is introduced.

## Pre-Edit Characterization Baseline

The focused commands and exact counts are recorded below. They were run before
any product edit. Browser coverage is limited to the direct model-swap scenario
because Gate A is documentation-only; the full browser gate remains required
after implementation.

| Command | Result |
|---|---:|
| `moon test viewer/editor_extensions_wbtest.mbt --target js` | 9/9 |
| `moon test viewer/async_model_features_wbtest.mbt --target js` | 10/10 |
| `moon test viewer/test_viewer_wbtest.mbt --target js` | 11/11 |
| `moon test viewer/set_value_api_wbtest.mbt --target js` | 7/7 |
| `moon test viewer/reveal_wbtest.mbt --target js` | 11/11 |
| `moon test viewer/cursor_input_wbtest.mbt --target js` | 12/12 |
| `moon test viewer/lifecycle_ownership_wbtest.mbt --target js` | 10/10 |
| `moon test viewer/cursor_transition_wbtest.mbt --target js` | 17/17 |
| `moon test viewer/cursor_behavior_wbtest.mbt --target js` | 12/12 |
| `moon test viewer --target js --filter '*hover*'` | 9/9 |
| `moon test viewer --target js --filter '*configuration*'` | 2/2 |
| `moon test viewer --target js --filter '*layout*'` | 5/5 |
| **MoonBit total** | **115/115** |
| `READONLY_EDITOR_BASE_URL=http://127.0.0.1:5187 ./node_modules/.bin/playwright test tests/browser/component/model_swap.spec.js` | **1/1** |

The filter rows overlap some named-file coverage; the total records successful
command-level test invocations, not unique test declarations.

The warning-enabled all-target check and architecture guard also pass:

```sh
moon check --target all --warn-list +73
moon run --target native scripts/check-architecture.mbtx
```

The only warning-enabled diagnostics are the three pre-existing unused fields
in `viewer/browser/view/rendering_context.mbt`; there are no errors.
`git diff --check` also passes. `just check` was not used for this read-only
characterization because it runs `moon fmt`; its non-formatting check and
architecture portions were run separately. The full `just check` remains a
required implementation gate.

## Generated Interface Baseline

`viewer/pkg.generated.mbti` has SHA-256
`6f1aba10c05f08fd1e3f61f829c69226d75e97b2608f6de30db1c5f7b6c46bac`.
It describes `Viewer` as an opaque public struct and contains none of the
planned private owners. The interface diff is clean; before the Gate A commit,
status contains only the parent-plan update and this artifact:

```sh
git diff --exit-code -- viewer/pkg.generated.mbti
git status --short
```

Milestone G must rerun `moon info --target js` and prove this exact public
surface remains unchanged.

## Review Checklist

- [x] product baseline and plan-only delta verified;
- [x] oracle gitlink/submodule and all five source hashes verified;
- [x] all 49 fields equal all 49 VFD rows in exact order;
- [x] 22 direct and 27 moving field dispositions reconcile;
- [x] all 27 moving fields have complete semantic reference counts, file sets,
      writer sites, and direct white-box coupling recorded;
- [x] headless/mounted and `ModelData.browser` representations fixed;
- [x] cursor reset keeps an active drain gate;
- [x] content-hover uses one central state with two-phase disposal;
- [x] current constructor, mount, attach, detach, render, and disposal traces
      recorded against the target;
- [x] focused characterization and API baselines are green;
- [ ] product implementation — **STOP FOR REVIEW**.

Milestone B is not authorized until the reviewer approves this artifact.
