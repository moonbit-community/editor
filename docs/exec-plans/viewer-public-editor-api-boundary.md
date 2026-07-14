# Viewer Public Editor API Boundary

Status: Gate A inventory ready — STOP FOR REVIEW; no public API implementation
has started
Date: 2026-07-14
Oracle commit: `vscode` submodule at
`b18492a288de038fbc7643aae6de8247029d11bd`

## Goal

Make the root `viewer` package expose a deliberate readonly editor contract
rather than leaking types owned by view layout, view model, view parts, and
contributions.

Breaking changes are explicitly allowed for this plan. The desired result is
a smaller, canonical, Monaco-shaped API with one owner per public type. The
root package remains the external construction/operation facade; internal
shell code may import feature packages directly under the existing architecture
rule.

## Current Problems

The checked-in `viewer/pkg.generated.mbti` currently exposes or imports:

- `ViewerOptions` fields typed as `@view_model.WrappingIndent`,
  `@view_layout.RenderWhitespace`, `@view_layout.RenderLineHighlight`, and
  `@folding_browser.ShowFoldingControls`;
- `ViewerServices` fields typed as concrete marker, agent-feedback,
  quick-diff, language, and log implementations;
- `ViewZone` and `ViewZoneChangeAccessor` from the consolidated private
  `viewer/browser/view` runtime package;
- a root `CursorChangeReason` duplicating
  `viewer/common/cursor.CursorChangeReason`, plus variant-by-variant adapters;
- public contribution implementation/lifecycle types;
- the headless `Viewer::Viewer` constructor, test/telemetry hooks, and other
  surfaces whose intended consumers are not classified.

The issue is type ownership, not only visibility. Making fields private while
leaving duplicate or incorrectly filed canonical types would be incomplete.

## Phase 0: Pinned Source Scope

Use these Monaco/VS Code contracts as structural oracles:

- option declarations/registrations in
  `vscode/src/vs/editor/common/config/editorOptions.ts`;
- editor event and contribution contracts in
  `vscode/src/vs/editor/common/editorCommon.ts`;
- DOM-facing editor/widget/view-zone contracts in
  `vscode/src/vs/editor/browser/editorBrowser.ts`;
- the public method/getter/event clusters of
  `browser/widget/codeEditor/codeEditorWidget.ts`;
- the standalone export boundary in `editor.api.ts`, `editor.main.ts`, and the
  generated Monaco declarations;
- cursor reason/event ownership in the cursor event source unit.

This plan is not a full port of those very large files. The complete scoped
clusters are: readonly editor construction, options, model/view state,
selection/cursor/scroll events, view-zone API, widget contract declarations,
contribution lookup, and service contracts. The retained widget implementation
is deliberately limited to the existing unmanaged overlay subset. Positioned
overlay behavior, content-widget operations, editing, diff editor, minimap,
accessibility, and commands not present locally are explicitly `N-A` or
`DEFERRED`, not omitted.

## Gate A: Public Denominator and Review Stop

Before moving a public type, produce:

1. A machine-generated inventory of every `pub`, `pub(all)`, `pub(open)`,
   public alias, public field, and root-package method in
   `viewer/pkg.generated.mbti`.
2. `moon ide find-references` results separated into:
   - external embedding example;
   - internal workbench;
   - browser scenarios;
   - root white-box tests;
   - no local caller.
3. A public disposition table with exactly one result for every item:
   `KEEP`, `MOVE`, `ALIAS`, `OPAQUE`, `REPLACE`, or `REMOVE`, including target
   owner and migration.
4. A complete upstream cluster ledger for the source scope above.
5. A before snapshot of every checked-in generated interface affected by the
   plan.
6. A package dependency graph proving the target public contract packages sit
   below their consumers and remain multi-target where required.

Zero local usage is evidence, not automatic removal: embedders are outside the
repository. Conversely, test-only usage is not sufficient reason to keep a
root public API.

**Review gate: stop here. No public API change lands until the disposition
table and dependency graph have been reviewed.**

The completed Gate A artifact set is:

- `viewer-public-editor-api-boundary-gate-a.md` — review entrypoint, closed
  denominators, decisions, and explicit stop;
- `viewer-public-editor-api-boundary-gate-a-public.md` — every local public
  item, caller buckets, terminal disposition, owner, and migration;
- `viewer-public-editor-api-boundary-gate-a-upstream.md` — complete pinned
  upstream cluster ledger;
- `viewer-public-editor-api-boundary-gate-a-dependencies.md` — byte-exact
  generated-interface snapshots, current and target package graphs, target
  proof, and host seams.

Gate A found one dependency impossibility in the proposed service owner:
complete language, marker, feedback, quick-diff, and logging capabilities
cannot live in a dependency-bottom `common/editor_api` without importing the
model/language/syntax/log/feature vocabularies they use or duplicating those
types. The reviewed target below separates canonical bottom value contracts
from vocabulary-specific capability handles.

Gate A also closed two public-facade seams that the proposal left ambiguous.
External hosts still import only root `viewer` and `viewer/common/**`, so root
factories construct the browser-owned view-zone descriptor and unmanaged
overlay-widget handle. The full positioned/content-widget contracts are
inventoried but deferred. Removing render telemetry also does not move the
embedded example's ready signal earlier: its semantic model-change listener
schedules a native animation-frame callback after the Viewer has queued its
own flush, then rechecks the current model URI before publishing ready.

## Target Public Ownership

### Common editor contracts

Create `viewer/common/editor_api` as a small, multi-target, dependency-bottom
package for canonical public contracts needed by more than one editor tier:

- editor option enums currently owned by view layout, view model, or folding;
- cursor change reason and public cursor event payload contracts;
- other DOM-free public enums/records proven by the disposition inventory and
  expressible using only `base/common`, `viewer/common/core`, and language
  primitives.

Internal packages import these canonical types. They do not define parallel
versions and root does not translate variants.

Service capability handles do not live in `common/editor_api`. Language,
marker, and logging handles live beside their existing vocabularies in
`common/languages`, `common/markers`, and `platform/log`. External hosts may
not import `viewer/contrib/**`, so the feedback host DTO/events and callback
handle move to `common/agent_feedback_api`, while the quick-diff baseline
handle lives in `common/quick_diff_api`. Concrete implementations and UI-only
feedback projections stay under their existing contribution packages. Each
handle exposes only reviewed callbacks and contains no concrete service field.
The exact final types are `LanguageHandle`, `MarkerDecorationsHandle`,
`AgentFeedbackHandle`, `QuickDiffHandle`, and `LogHandle`. Marker construction
uses one closed `MarkerDecorationsSource`: either a caller-owned
`MarkerServiceHandle` store from which the bundle owns the decorations adapter,
or a caller-owned final decorations handle. Omission makes the bundle own both
marker defaults. `MarkerDecorationsService::new` is correspondingly replaced
with a constructor that accepts `MarkerServiceHandle`; all 17 existing
non-definition call sites derive that handle from their retained concrete
store. The two common feature handles remain opaque but are externally
constructible through exact all-callback `AgentFeedbackHandle::new` and
`QuickDiffHandle::new` constructors, so custom hosts never need a contrib
import.

### Browser editor contracts

DOM-facing interfaces belong in the existing `viewer/browser` public browser
contract package, matching Monaco's `editorBrowser.ts` role:

- the opaque unmanaged overlay-widget handle used by the retained root
  add/remove operations;
- mouse event/target contracts already owned there;
- the public view-zone description and change-accessor contract.

The mutable/rendered ViewZones implementation stays private to
`viewer/browser/view`. The root package must not expose a type from
`browser/view_parts` or the consolidated private view implementation.
Complete content-widget and positioned-overlay declarations remain in the
upstream denominator, but their operations, preference/coordinate types,
overflow flag, layout event, minimum-width callback, and explicit layout
method are deferred: the current Viewer implements and exercises only the
self-positioned (`getPosition() == null`) overlay subset.

### Root facade

The root package retains:

- opaque `Viewer`, `ViewerOptions`, and `ViewerServices` facade types;
- `Viewer::create` as the public browser constructor;
- readonly model/value/selection/scroll/reveal/layout/widget/view-zone
  operations accepted by the disposition review;
- public semantic events accepted by the disposition review.

Because the public headless constructor is removed, every publicly constructed
Viewer retains the original host container passed to `Viewer::create` and owns
and removes only its editor DOM subtree. `get_container_dom_node` therefore
becomes non-null and returns that same host before and after Viewer disposal.
`get_dom_node` remains nullable because a Viewer can have no attached
model/view.

`ViewerOptions` fields become private. It accepts canonical option enums and
derives internal `ViewModelOptions`/layout values inside the root package.

`ViewerServices` fields become private and privately aggregate these capability
handles at the host boundary. Concrete service implementations and
`viewer/contrib/**` paths do not appear in its generated interface. The
workbench and browser scenarios retain their concrete service backings, derive
handles for `ViewerServices`, and continue host-side mutation and disposal
through the retained concrete values rather than recovering them through root
public fields.
Capability records are justified here because this is a real
dependency-injection/host seam; they contain only operations proven by the
call-site inventory.

`ViewerServices::dispose` is public and idempotent. It releases only backings
created by that bundle, in marker-decorations, marker-service, then feedback
order, and never disposes caller-supplied handles or their captured backings. A
Viewer disposes only a bundle it created internally; an explicitly supplied or
shared bundle remains caller-owned until its last Viewer is disposed.

## Initial Disposition Decisions

These decisions are fixed unless Gate A finds a dependency impossibility:

| Current surface | Target |
|---|---|
| option enums in `view_layout`, `view_model`, folding | move to `common/editor_api`; one canonical type |
| root `CursorChangeReason` + cursor copy | one type in `common/editor_api`; delete adapters |
| `ViewZone` alias from private `browser/view` | public descriptor in `viewer/browser`; private registered/rendered state in `browser/view` |
| `ViewerOptions` public fields | opaque root struct with constructor/getters as justified |
| `ViewerServices` public concrete fields | opaque root struct over reviewed capability contracts |
| `EditorContribution` and instantiation modes | internal registry types; no root public fields/types |
| `Viewer::get_contribution` | remove from external facade after the single-ownership plan |
| `Viewer::Viewer` headless constructor | make private; root white-box tests can still use it |
| `Viewer::create` | keep as public construction path |
| nullable `Viewer::get_container_dom_node` | replace with a non-null return after the public headless constructor is removed |
| raw overlay `(id, Element)` add and id-only remove | root `overlay_widget(id, Element)` factory plus browser-owned opaque unmanaged handle; add/remove take the handle; positioned/content/layout APIs remain deferred |
| `debug_on_did_*` hooks | move to internal observability/testing surface or replace callers with accepted semantic events |

The full Gate A table must still account for every other public item.

## Milestone B: Introduce Canonical Common Types

1. Create `viewer/common/editor_api` with no browser/contrib/view-model/model
   implementation dependencies.
2. Move one enum family at a time, starting with cursor reason, then viewer
   option enums.
3. Update internal packages to consume the canonical type directly.
4. Delete root/internal duplicate types and variant mapping functions as soon
   as each family is migrated.
5. Port documentation and tests with the type; do not retain compatibility
   wrappers because breaking changes are allowed.

Gate after each family:

- `moon check --target all`
- relevant cursor/options/view-layout/view-model tests
- `just check`

Commit each canonical type family separately.

## Milestone C: Separate Public Browser Descriptors from Runtime State

1. Inventory every field read by the root caller, accessor, view layout, and
   rendered ViewZones part.
2. Define the public zone request/descriptor and accessor contract in
   `viewer/browser`.
3. Keep mutable ids, cached heights/styles, DOM attachment state, and render
   data private in `viewer/browser/view`.
4. Convert exactly once at the browser-view boundary; do not make the root
   facade alias its internal runtime object.
5. Update `view_zone`/`change_view_zones` callers and browser conformance tests.
6. Define an opaque browser-owned unmanaged `OverlayWidget` handle with
   immutable id and DOM node and fixed null/self-positioned placement.
7. Add root `overlay_widget(id, dom_node)` so external hosts can construct the
   inferred browser handle without importing `viewer/browser`; replace root
   add/remove signatures with handle-based operations.
8. Preserve duplicate-id last-writer behavior, unknown-removal no-op behavior,
   registration across model swaps, and disposal cleanup. Do not add a layout
   method or the deferred positioned/content-widget surface in this milestone.

Preserve callback timing, validation, ordering, suppress-mouse-down behavior,
height precedence, layout events, and DOM ownership.

## Milestone D: Make Options and Services Opaque

1. Make `ViewerOptions` fields private and expose only construction/read
   operations accepted by the disposition table.
2. Replace internal option-type imports in its public signature with canonical
   `editor_api` types.
3. Use Gate A's complete inventory of every concrete `ViewerServices`
   operation consumed by root, workbench, and contributions.
4. Define minimal opaque capability handles beside their allowed public
   vocabularies in `common/languages`, `common/markers`,
   `common/agent_feedback_api`, `common/quick_diff_api`, and `platform/log`;
   contribution packages derive them from concrete services at the
   root/workbench boundary, while the two common feature API packages expose
   exact all-callback constructors for external custom implementations.
5. Replace `MarkerDecorationsService::new(MarkerService)` with
   `MarkerDecorationsService::new(MarkerServiceHandle)` and migrate all 17
   existing callers to derive the lower handle from the concrete store they
   retain.
6. Make `ViewerServices` fields private and remove concrete contrib/browser
   implementation types from `viewer/pkg.generated.mbti`.
7. Update workbench code to create and retain feature implementations directly
   where it owns them, while the external embedding example uses only the
   public facade and reviewed public contract packages.
8. Update every browser scenario that mutates or disposes a concrete service
   to retain that backing explicitly, derive only its read/callback handle into
   `ViewerServices`, and perform host operations through the backing.

Do not introduce a general service locator or reproduce VS Code's full DI
container. The target is explicit, typed, minimal capabilities.

## Milestone E: Shrink the Root Facade

Apply the reviewed disposition table mechanically:

1. remove public contribution registry types and `get_contribution` after the
   single-ownership plan is complete;
2. make the headless constructor private and keep it for root white-box tests;
3. relocate/remove debug observability hooks and update workbench/example/test
   callers. The embedded example listens to `on_did_change_model`, filters the
   selected URI, schedules one native animation frame after the already-queued
   Viewer flush, rechecks the current URI, then sets the active item and ready
   status;
4. remove test-only public helpers where white-box access suffices;
5. retain external APIs with no local caller only when the disposition review
   ties them to the accepted readonly Monaco contract;
6. make `get_container_dom_node` non-null while retaining nullable
   `get_dom_node`;
7. update examples to demonstrate the intended public construction and service
   boundary.

No deprecation aliases are required. Breaking changes should fail loudly at
all in-repository callers and be migrated in the same milestone.

## Milestone F: Generated API and Architecture Gates

1. Regenerate every affected `pkg.generated.mbti` with `moon info`.
2. Diff the root interface against the Gate A snapshot and annotate each
   change with its disposition row.
3. Extend `scripts/check-architecture.mbtx` so the root generated interface
   cannot reference:
   - `viewer/browser/view` or former `view_parts` implementation types;
   - `viewer/contrib/**` implementation types;
   - duplicate public option/cursor types.
4. Update `docs/architecture.md`, package READMEs, embedding documentation, and
   source maps.
5. Add compile-only external-consumer fixtures proving the supported facade
   and rejecting internal-type imports where the architecture policy requires.

## API and Behavior Test Matrix

Required API cases:

- default and explicitly configured options;
- all public option enum variants;
- default services and custom language/marker/feature capabilities;
- public cursor/model/scroll events with the canonical reason type;
- immediate public reveal/scroll setters versus enabled, disabled, and
  one-line-downgraded internal smooth movement;
- host-driven whole-buffer `set_value` without exposing interactive editing,
  actions, or undo/redo;
- unmanaged overlay widgets and view zones through browser contracts, including
  root factories usable under the external root/common-only import rule;
- the same non-null container before/after disposal and nullable model/view DOM;
- external embedded viewer construction without internal imports;
- embedded readiness only after the queued Viewer DOM flush, including a stale
  model-swap callback case;
- internal workbench construction with feature implementations;
- headless white-box tests without a public headless constructor;
- absence of contribution/debug/internal view types in the root interface.

Required validation:

- `moon check --target all`
- `moon info --target all` and reviewed interface diffs
- `just check`
- `just test`
- `just build`
- `just test-browser`
- embedded-viewer and workbench startup/browser scenarios

## Exit Criteria

- [ ] every original root public item has a reviewed disposition row
- [ ] source-cluster ledger rows equal scoped source members
- [ ] root generated interface contains no view implementation or contribution
      implementation types
- [ ] every public option/event/service type has one canonical owner
- [ ] duplicate `CursorChangeReason` and mapping functions are gone
- [ ] public ViewZone contract is separate from private runtime/render state
- [ ] the unmanaged overlay handle is browser-owned and externally constructible
      through the root factory; deferred widget members remain unimplemented
- [ ] `ViewerOptions` and `ViewerServices` are opaque
- [ ] `get_container_dom_node` is non-null and `get_dom_node` remains nullable
- [ ] headless/test/contribution internals are absent from the external facade
- [ ] embedded example uses only supported public packages
- [ ] architecture checks enforce the new boundary
- [ ] all intentional breaking changes are documented in the plan's closing
      API diff
- [ ] all deviations are recorded and seam-based
- [ ] closing complete-source reread finds no unaccounted member
- [ ] required validation is green

## Cross-Plan Coordination

Execute after:

1. `browser-view-package-consolidation.md`, so public browser contracts are
   separated from the final private view implementation rather than from
   soon-to-be-deleted packages;
2. `editor-contribution-single-ownership.md`, so the public contribution
   facade is removed after typed internal lookup exists;
3. the model/token and inline-decoration package merges when they touch the
   same canonical types or generated interfaces.

Do not run API milestones in parallel. They share `viewer/moon.pkg`,
`viewer/pkg.generated.mbti`, `viewer/viewer.mbt`, options/services/events,
architecture checks, workbench construction, and browser scenario packages.
