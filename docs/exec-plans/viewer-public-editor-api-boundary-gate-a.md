# Viewer Public Editor API Boundary — Gate A Review

Status: approved historical inventory — implementation started 2026-07-14

Date: 2026-07-14

Parent plan: `docs/exec-plans/viewer-public-editor-api-boundary.md`

Local baseline: recorded repository state

Oracle: checked-in `vscode` submodule

This is the review entrypoint for the parent plan's mandatory Gate A. At this
snapshot it froze inventories and migration decisions only; no MoonBit source,
package manifest, generated interface, test, or browser artifact had changed.
The user explicitly approved this Gate A on 2026-07-14. Present-tense inventory
and stop language below describe the frozen pre-implementation baseline.

## Artifact Set

- `viewer-public-editor-api-boundary-gate-a-public.md` is the complete local
  root-interface inventory, semantic caller classification, and terminal
  public disposition ledger.
- `viewer-public-editor-api-boundary-gate-a-upstream.md` is the pinned
  Monaco/VS Code source-cluster inventory and parity ledger.
- `viewer-public-editor-api-boundary-gate-a-dependencies.md` is the byte-exact
  before snapshot, current/target dependency proof, capability-operation
  inventory, and host migration ledger.
- This file reconciles those three companions into one approval contract.

The companions are normative. Counts and summaries here must agree with them;
this entrypoint does not replace their per-row evidence.

## Closed Denominators

| Gate denominator | Exact result |
|---|---:|
| root `viewer/pkg.generated.mbti` | 280 lines / 14,194 bytes / 210 public rows |
| root interface SHA-256 | `9c6b4fe4d5d57704db1d0ada58a5401d6ed55fa049b1cb9bf74b3854e62b0d75` |
| root public categories | 4 values + 18 types + 12 variants + 77 fields + 97 methods + 2 aliases |
| upstream parity ledger | 1,322 rows across 8 scoped units |
| pinned upstream physical files | 8 files / 20,722 lines |
| upstream manifest SHA-256 | `3c7c8cb5295abf8a9bf324f1a31aaac491800f8be80068d9bde371a1ded1c958` |
| changed checked-in interface snapshot | 15 files / 3,079 lines |
| changed-interface aggregate SHA-256 | `67998fe1cb033f5ccc24f0868af5470b0ea920254bd93fba07c8317aa897d11a` |
| scoped current manifests | 32 files / 341 lines / 192 literal imports |
| manifest aggregate SHA-256 | `b2ed3da539bbdb0caece11314b8f353831cb8e588bcce7311fd14491066199e2` |
| byte-identical consumer/interface sentinels | 9 files / 231 lines |
| sentinel aggregate SHA-256 | `72674e2ef87c660b3136bb3f5a8fdeda07eec6ae105d788971834a2243e380a6` |

Closeout re-ran the immutable-baseline recipes and corrected two inventory
omissions in the initial review text: `viewer/browser/controller` belongs to
the changed-interface snapshot, and the perf browser package belongs to both
the manifest and byte-identical sentinel sets. The corrected counts and hashes
above change no reviewed ownership or migration decision.

The four target packages
`viewer/common/{editor_api,agent_feedback_api,quick_diff_api}` and
`viewer/browser/testing` do not exist at the baseline. Both `moon.pkg` and
`pkg.generated.mbti` absence are frozen for each; they are not missing
snapshots.

## Gate A Corrections to the Proposed Plan

Gate A found and closes these stale or impossible assumptions:

1. The current ViewZone leak is the consolidated private
   `viewer/browser/view` package, not the deleted
   `viewer/browser/view_parts/view_zones` path.
2. A dependency-bottom `viewer/common/editor_api` cannot own complete service
   capabilities whose exact signatures use model, language, syntax, logging,
   marker, and feature DTO vocabularies. It owns canonical value contracts
   only.
3. External hosts may import root `viewer` and `viewer/common/**`, but not
   `viewer/contrib/**`. Feedback and quick-diff host contracts therefore use
   dedicated common API packages; concrete implementations remain in contrib.
4. Root `EditorMouseEvent` cannot move into `viewer/browser` under its current
   name because that package already uses the name for a raw DOM wrapper. The
   raw wrapper becomes `EditorDomMouseEvent`; the canonical hit-tested event
   receives the public `EditorMouseEvent` name.
5. Public debug hooks have real embed, workbench, browser, and white-box
   callers. Their removal has fixed caller-specific replacements below; zero
   test value is not assumed.
6. The existing widget implementation covers only null-position/self-positioned
   overlays. Full content widgets, positioned overlays, layout events, minimum
   width, and explicit layout are inventoried but deferred; the root factory
   keeps the supported unmanaged handle constructible under the external
   root/common-only import rule.
7. Removing the public headless constructor makes the public container
   invariant non-null, including after disposal, but `get_dom_node` remains
   nullable when no model/view is attached.
8. The root does not expose `ScrollType`: public reveal and scroll-setter calls
   remain immediate, while smooth scrolling is confined to physical input and
   internal cursor requests. `tab_size` and `theme` also retain their distinct
   model/global and standalone/global ownership instead of being misclassified
   as ordinary editor-option registrations.

## Terminal Public Ownership

| Surface | Reviewed owner/result |
|---|---|
| cursor reason, cursor/model/scroll payloads, scrolled position | move to multi-target `viewer/common/editor_api` |
| wrapping, whitespace, line-highlight, validation, folding-control enums | one canonical declaration in `viewer/common/editor_api` |
| hit-tested full/partial mouse events | move to `viewer/browser`; raw DOM event renamed `EditorDomMouseEvent` |
| ViewZone descriptor/accessor | canonical public contracts in `viewer/browser`; registered/rendered state private in `viewer/browser/view` |
| root `view_zone` helper | retain with a replaced return signature targeting the browser descriptor, so external hosts need no direct browser import |
| overlay widgets | browser-owned opaque unmanaged handle; root `overlay_widget(id, node)` factory and handle-based add/remove; full positioned/content/layout API deferred |
| `Viewer` | keep opaque root facade; `Viewer::create` remains public and the headless constructor becomes private |
| container/view DOM | replace `get_container_dom_node` with non-null original-host return before/after disposal; keep `get_dom_node` nullable |
| `ViewerOptions` | opaque immutable root snapshot over canonical option types |
| `ViewerServices` | opaque root aggregate over reviewed capability handles, with explicit ownership/disposal |
| `ViewerViewState` | opaque root round-trip token |
| contribution types/lookup | remove from the root interface; central registry remains private |
| debug functions/payloads | remove from root; use semantic or internal testing seams below |
| upstream-internal geometry/state helpers | remove `get_statusbar_column`, overscanned visible ranges, `has_model`, and `set_hidden_areas` from root public API |

No compatibility alias is selected. Breaking changes are intentional and all
in-repository callers migrate in the owning milestone.

## Public Disposition Reconciliation

| Disposition | Rows |
|---|---:|
| `KEEP` | 85 |
| `MOVE` | 45 |
| `ALIAS` | 0 |
| `OPAQUE` | 36 |
| `REPLACE` | 7 |
| `REMOVE` | 37 |
| total | 210 |

The seven replacements are the root ViewZone factory, the two overlay-widget
operations, the line-only bottom query, the non-null container query, the
canonical `ViewerOptions` constructor signature, and the capability-based
`ViewerServices` constructor.

The local evidence codes are non-exclusive: `EXT` 9, `WB` 45, `BR` 95, `WT`
102, `ROOT` 148, and `NONE` 20. `NONE` is not automatic removal: public Monaco
contracts such as definition-only reveal methods remain when their upstream
role is accepted. Conversely, test-only or root-only use does not preserve an
upstream-internal helper.

## Exact Capability Handles

The final handles contain only production Viewer/contribution operations:

| Handle owner | Exact callback set |
|---|---|
| `viewer/common/languages.LanguageHandle` | `get_language_configuration`; async `hover_at` with cancellation, with logging prebound by the adapter |
| `viewer/common/markers.MarkerDecorationsHandle` | `acquire_model`; `on_did_change_marker_decorations`; `get_live_markers_for_model` |
| `viewer/common/agent_feedback_api.AgentFeedbackHandle` | `on_did_change_feedback`; `on_did_change_navigation`; `is_feedback_enabled`; `get_feedback`; `get_navigation_bearing`; `add_feedback`; `mark_feedback_submitted`; `remove_feedback`; `accept_feedback`; `set_navigation_anchor`; `update_feedback`; `add_reply` |
| `viewer/common/quick_diff_api.QuickDiffHandle` | `get_original_content`; `on_did_change_original` |
| `platform/log.LogHandle` | `error`; `warn` |

`diagnostics_for_resource` is recorded as a current transitional Viewer read
only. Removing the debug build/render payloads removes that read, so it is not
in the final marker handle.

Marker construction also has one lower `MarkerServiceHandle` in
`viewer/common/markers`, exposing exactly `on_did_change_markers`, `read`, and
`remove` for `MarkerDecorationsService`. The single constructor input is the
closed `MarkerDecorationsSource` enum: `MarkerStore(MarkerServiceHandle)` or
`Decorations(MarkerDecorationsHandle)`. Omission makes the bundle own both
default backings; `MarkerStore` leaves the store caller-owned and makes the
bundle own only its decorations adapter; `Decorations` leaves both backings
caller-owned. The adapter seam is constructible by definition:

```text
pub fn MarkerDecorationsService::new(MarkerServiceHandle) -> Self
```

This replaces the current concrete-store constructor. Its 17 existing
non-definition callers retain their `MarkerService` and pass
`markers.marker_service_handle()`.

The target constructor is frozen as:

```text
pub fn ViewerServices::new(
  languages? : @languages.LanguageHandle,
  markers? : @markers.MarkerDecorationsSource,
  agent_feedback? : @agent_feedback_api.AgentFeedbackHandle,
  quick_diff? : @quick_diff_api.QuickDiffHandle,
  log_service? : @log.LogHandle,
) -> Self
```

The opaque common feature handles are also constructible without importing a
contribution package. Their target constructors are frozen as:

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

Every callback is required; the constructors add no implicit no-op behavior.
The public `add_feedback` handle method keeps optional `kind?` and `state?`
parameters and forwards their normalized optional values to the callback, so
the backing remains the authority for omitted-value defaults. These handles
own no captured backing and add no disposal responsibility to
`ViewerServices`.

Provider/tokenizer registration, diagnostic publication, feedback persistence,
quick-diff baseline mutation, and explicit concrete teardown are host
operations. Workbench and browser scenarios retain concrete implementations,
derive handles, and perform those operations on the retained values; they do
not enlarge the Viewer handles.

`ViewerServices::dispose` is a new public, idempotent bundle operation. It
releases only default backings created by that bundle, in marker-decorations,
marker-service, then feedback order. It never disposes caller-supplied handles.
A Viewer disposes only a bundle it created internally; an explicitly supplied
or shared bundle remains caller-owned and is disposed after its last Viewer.
Callers still own each returned registration/subscription handle. Disposing a
bundle-owned default necessarily ends subscriptions and leases serviced by
that backing; caller-supplied backings and their handles remain untouched.

## Closed Caller Migrations

### Options

`ViewerOptions(...)` keeps named construction using canonical enums.
`get_options` returns an opaque snapshot and `update_options` accepts it.
Non-root record updates become immutable `with_*` operations for the exact
fields used by workbench/browser callers. Only `soft_wrap` and `line_height`
gain scalar getters because they are the only non-root reads. Saved snapshots
can be passed back without representation access.

`tab_size` remains local model/view-model configuration because TextSnapshot
has no model-options owner; `theme` remains standalone/global construction
state mirrored to the live DOM. Neither is presented as an ordinary editor
option registration. Public reveal and scroll setters remain immediate and do
not expose ScrollType; smooth behavior remains a physical-input/internal-cursor
policy.

### Debug and testing

- The embedded example uses the existing `Viewer::on_did_change_model`,
  filters the selected attached URI, and schedules a native animation frame
  after the Viewer has already queued its DOM flush. The callback rechecks the
  current URI, then selects the tree item and sets its existing ready status;
  stale swap callbacks do nothing. Render telemetry is not an embedding
  contract.
- Workbench and browser conformance/performance callers use the JS-only
  `viewer/browser/testing` registry keyed by the existing public
  `Viewer::get_id`; this adds no new root id API.
- Root white-box assertions use package-private hooks.
- The testing package imports only lower browser/common vocabulary and never
  root `viewer`, so the dependency direction stays one-way.

### Internal public leaks

Root white-box callers of `get_statusbar_column`, overscanned ranges, and the
headless constructor use package-private seams. Browser `has_model` and
hidden-area test cases use named `viewer/browser/testing` entries keyed by the
same Viewer id. Contribution tests inspect the private typed registry directly.

### View zones and widgets

The root convenience factory and `Viewer::change_view_zones` remain usable
without an external direct browser import; inference supplies the callback
accessor type. The public descriptor and callback-backed accessor live in
`viewer/browser`, avoiding a `browser <-> browser/view` cycle. Raw overlay
id/element operations are replaced by root
`overlay_widget(String, Element) -> @browser.OverlayWidget` and handle-based
Viewer add/remove. The opaque browser handle has immutable id/node and fixed
null/self-positioned placement; duplicate ids remain last-writer-wins, unknown
removal is a no-op, registration survives model swaps, and disposal clears it.
Content-widget operations and positioned/overflow/layout/min-width overlay
features remain explicitly deferred.

## Dependency and Target Proof

`viewer/common/editor_api`, `agent_feedback_api`, and `quick_diff_api` omit
`supported_targets` and remain native+JS. Their allowed dependencies are
multi-target common/value packages only. DOM-bearing `viewer/browser`,
`viewer/browser/view`, `viewer/browser/testing`, root `viewer`, the embed, and
workbench remain JS-only.

The target graph is acyclic:

- canonical common API/value owners sit below cursor, layout, view-model, and
  contribution consumers;
- `viewer/browser` never imports `viewer/browser/view`; the private runtime
  imports the public callback contracts in the existing direction;
- capability owners and concrete adapters never import root `viewer`;
- root privately aggregates handles above all owners;
- workbench and browser tests remain top-tier consumers that may retain/import
  concrete feature implementations;
- external hosts keep the existing root/common-only import rule.

The dependency companion gives the complete adjacency, a valid topological
ranking, immutable hash recipes, and the nine byte-identical sentinels.

## Upstream Ledger Reconciliation

| Unit | Rows |
|---|---:|
| scoped editor options/registration | 107 |
| common editor events/state/facade | 109 |
| complete cursor-event unit | 21 |
| browser editor/view-zone/widget/mouse contracts | 200 |
| CodeEditorWidget behavior clusters | 473 |
| complete standalone API unit | 42 |
| complete editor entrypoint unit | 10 |
| generated Monaco declaration mirror | 360 |
| total | 1,322 |

| Current mapping status | Rows |
|---|---:|
| `PORTED` | 101 |
| `TESTED` | 507 |
| `PASS` | 0 |
| `DEFERRED (reason)` | 340 |
| `N-A (reason)` | 374 |

These are Gate A mapping classifications, not a parity-completion claim. The
implementation milestones must link the branch/configuration test matrix,
diff every generated interface against its disposition row, and perform the
closing source reread before any 1:1 exit claim.

## Approval Contract and Stop

Approval of this Gate A accepts:

1. all 210 local dispositions and caller migrations;
2. all 1,322 upstream rows and scoped exclusions;
3. the corrected value/capability owners, the handle-based marker-decoration
   constructor, the all-callback common feature constructors, and the
   external-import route;
4. the corrected 15-interface before snapshot, four absent target packages, 32-manifest
   dependency proof, and nine sentinels; and
5. sequential execution of parent Milestones B through F with coherent,
   validated commits and no parallel public-API milestones.

After approval, every milestone must run its scoped tests plus
`moon check --target all`, `moon info --target all`, and `just check`; the
closing gate also runs the full repository and browser matrices required by
the parent plan.

- [x] every current root public item has one terminal row
- [x] caller evidence is separated by required consumer bucket
- [x] upstream inventory rows equal the scoped denominator
- [x] affected interfaces and target-package absences are frozen
- [x] current and target dependency paths are cycle/target checked
- [x] implementation has not changed a public/generated interface
- [x] explicit approval for this Viewer public API Gate A

**Historical stop condition: satisfied by explicit user approval on
2026-07-14.**
