# MoonBit-Native API, Visibility, and Internal-Boundary Refactor

Status: in progress
Date: 2026-07-16
Toolchain baseline: `moon 0.1.20260713`, `moonc v0.10.4`
Oracle: current checkout; checked-in `vscode` only for already-ported behavior

## Goal

Use current MoonBit language and tooling capabilities to make the repository's
existing architecture mechanically clearer without changing readonly editor
behavior:

1. replace package-level `MouseTarget` factory functions with private local
   methods on the foreign `viewer/browser.MouseTarget` type;
2. narrow representation visibility where callers need a type or constructor,
   but do not need `pub(all)` construction/mutation rights;
3. enforce the documented external facade with MoonBit `internal` package
   paths for implementation-only browser, contribution, and testing packages;
4. make `Type::Type` the canonical primary-constructor spelling while
   preserving compatible `Type::new` callers;
5. use `ArrayView` at selected read-only input boundaries that copy rather than
   retain their inputs.

This is a representation, package-boundary, and API-hygiene refactor. It must
not change rendering, hit testing, cursor behavior, event ordering, hover
freshness, folding, tokenization, scrolling, widget geometry, protocol data,
or host ownership.

## Current Baseline

The audit that produced this plan found:

- 295 `pub(all)` declarations and 10 `pub(open)` declarations;
- 133 `moon ide analyze --no-check` annotations saying that `(all)` or `(open)`
  can be removed, across 26 packages;
- 94 public `Type::new` declarations across product and test-support source;
- 64 black-box `*_test.mbt` files and 132 white-box `*_wbtest.mbt` files;
- one established canonical-constructor compatibility pattern:
  `CancellationTokenSource::CancellationTokenSource` with `#alias(new)`;
- only one production `ArrayView` input today, in native command-line parsing;
- a green `just check` baseline.

The analyzer suggestions are evidence, not instructions. Local usage counts do
not include third-party embedders, and a public declaration may be a deliberate
contract even when the repository has no caller.

The largest current groups of visibility suggestions are:

| Package | Analyzer annotations |
|---|---:|
| `viewer/contrib/hover` | 19 |
| `viewer/common/view_model` | 16 |
| `viewer/common/view_layout` | 14 |
| `viewer/common/model` | 12 |
| `internal/shell/workspace` | 9 |
| `viewer/common/markers` | 7 |
| `viewer/common/diff` | 6 |
| `viewer/common/cursor` | 6 |
| `viewer/browser/view` | 6 |
| `viewer/contrib/folding/browser` | 5 |
| `internal/shell/remote_protocol` | 5 |
| `platform/log` | 4 |
| all remaining packages | 24 |

Regenerate these numbers at Gate A. They are a frozen planning baseline, not an
exit target.

## Scope and Port Mode

This plan is not a new Monaco or CodeMirror feature port and does not claim a
full source audit.

- Overall mode: behavior preservation.
- `viewer/browser/controller/mouse_target.mbt`: algorithm-fidelity
  preservation. Keep its branch order, constants, early returns, DOM
  fingerprints, target details, and coordinate arithmetic unchanged while
  changing only local declaration/call form.
- Browser view/controller, hover, folding, quick-diff, agent-feedback, and
  scrollbar package moves: algorithm-fidelity preservation for existing event,
  lifecycle, timing, geometry, and ownership clusters. Moving a file is not
  permission to reshape its algorithm.
- Visibility, constructors, and `ArrayView`: MoonBit-native representation/API
  work. Upstream TypeScript visibility, class layout, and constructor spelling
  are not contracts.

## Fixed Target Decisions

The following decisions are part of this plan and do not require rediscovery:

1. Root `viewer` remains the external browser facade.
2. `viewer/browser` remains public because it owns public editor mouse events,
   target values, `ViewZone`, its opaque accessor, and `OverlayWidget`.
3. `viewer/common/**`, `language`, `syntax`, `base/**`, and `platform/log`
   retain their current package paths. Individual declarations may be narrowed
   only through the reviewed visibility ledger.
4. Concrete browser runtime, contribution implementation, scrollbar, and
   testing packages move below the module-root `internal/viewer/**` boundary.
5. Existing CSS/font asset paths remain unchanged. Directories that become
   asset-only must not regain a `moon.pkg`.
6. Genuine external extension traits stay `pub(open)`, even if the analyzer
   reports no current outside implementation.
7. `pkg.generated.mbti` is generated only by `moon info`; never edit or move
   its contents by hand.
8. Do not add an architecture-lint script for this one-time package move.
   MoonBit's `internal` import rule, manifests, generated interfaces, compile
   fixtures, and code review are the enforcement.
9. Preserve source compatibility for public `Type::new` when an exact
   `#alias(new)` is possible. Do not perform a repository-wide breaking rename.
10. Do not convert an `Array` parameter to a view when the callee retains the
    array, depends on its mutable identity, mutates it, or exposes it later.

## Contracts That Must Remain Open or Constructible

Do not mechanically narrow these families:

- `pub(open)` provider/host traits that are intentional extension points:
  `Logger`, `LineTokenizer`, language-feature providers, filesystem/document/
  workspace providers, and `ServerHost`;
- caller-constructed shared DTOs such as `Position`, `Range`, `LineRange`,
  diagnostics, hover/location/symbol data, editor events/options, protocol
  packets, and public marker/feedback values;
- the mutable, identity-retained public `viewer/browser.ViewZone` descriptor;
- public mouse-target/event detail records required for host pattern matching;
- callback handles whose constructor is the supported custom-host seam;
- arrays deliberately retained by identity, including
  `TokenizationRegistry::set_color_map`;
- mutable arrays/descriptors whose later caller mutation is observable by
  design.

An analyzer suggestion against one of these declarations must be recorded as
`KEEP_ALL` or `KEEP_OPEN` with the contract reason.

## Gate A: Closed Inventories and Internal Review

Gate A is an internal quality checkpoint. Record its results in this plan and
continue unless it reveals a material unresolved choice that changes external
API, behavior, or package scope.

Before implementation:

1. Run `moon version --all` and record the exact toolchain.
2. Run `moon ide analyze --no-check` and record every `(all) or (open) can be
   removed` item with owning package.
3. For each suggested declaration, use `moon ide find-references` at the
   declaration location and classify consumers:
   - external facade/example contract;
   - root `viewer`;
   - another implementation package;
   - shell/workbench;
   - browser scenario;
   - black-box test;
   - white-box test;
   - no local caller.
4. Give every visibility item exactly one disposition:
   - `KEEP_ALL`;
   - `KEEP_OPEN`;
   - `NARROW_PUBLIC`;
   - `SEAL_TRAIT`;
   - `MAKE_PRIVATE`;
   - `MOVE_INTERNAL_THEN_REVIEW`.
5. Inventory every public `Type::new` and give it exactly one disposition:
   - `CANONICALIZE_ALIAS`: create `Type::Type` and attach `#alias(new)`;
   - `KEEP_ALTERNATE`: `new` is not the primary construction path;
   - `VIEW_PRIMARY_COMPAT`: add an `ArrayView` primary constructor and retain an
     `Array` compatibility wrapper;
   - `TEST_SUPPORT`: public only inside an internal test-support package, then
     review after the package move.
6. Inventory every normal, black-box-test, and white-box-test import in
   `moon.pkg` for the packages in the target move table.
7. Snapshot affected `pkg.generated.mbti` files from Git and record their
   line counts. Do not create edited copies in source directories.
8. Record hashes and paths for CSS/font assets under:
   - `viewer/browser/view`;
   - `viewer/browser/view_parts`;
   - `viewer/ui/scrollbar`;
   - `viewer/contrib/**`.
9. Reread current package READMEs and `docs/architecture.md` for every proposed
   visibility or package decision. Current contract prose overrides a raw
   analyzer count.

The Gate A visibility table must include at least these high-confidence first
wave candidates:

| Declaration | Planned review |
|---|---|
| `base/common.OffsetRange` | `pub(all)` to `pub`; retain public constructor and readable fields |
| `base/browser.StandardMouseEvent` | `pub(all)` to `pub`; retain event constructor |
| `platform/log.MemoryLogger` | `pub(all)` to `pub`; retain owned constructor/query methods |
| `internal/shell/workspace.DocumentSnapshot` | `pub(all)` to `pub`; retain documented snapshot factories |
| `viewer/common/view_model.ViewModelOptions` | `pub(all)` to `pub`; retain constructor/builders |
| `viewer/contrib/hover.HoverController` | `pub(all)` to `pub`; retain explicit state-transition methods |
| `viewer/browser/controller.ElementPath` | make private after its black-box test becomes white-box |

The fixed first-wave entries may still be blocked if semantic references prove
that external struct-literal construction is an intentional contract not
covered by an existing constructor.

### Gate A Result

Gate A completed on 2026-07-16 with no material unresolved scope, API, or
behavior choice. The complete reviewed ledgers, semantic consumer
classifications, constructor inventory, package/import snapshots, generated
interface line counts, and asset hashes are recorded in
`moonbit-native-api-visibility-and-internal-boundary-refactor-gate-a.md`.

The authoritative baseline required one checked analyzer run before the
requested `--no-check` snapshot. An unrefreshed `moon ide analyze --no-check`
reported 152 stale items, including obsolete folding declarations. After
`moon ide analyze`, the repeated `moon ide analyze --no-check` result was the
planned 133 annotations across 26 packages.

Reviewed terminal visibility dispositions:

| Disposition | Count |
|---|---:|
| `NARROW_PUBLIC` | 116 |
| `KEEP_ALL` | 10 |
| `KEEP_OPEN` | 2 |
| `MAKE_PRIVATE` | 5 |
| `SEAL_TRAIT` | 0 |
| `MOVE_INTERNAL_THEN_REVIEW` | 0 |

The constructor regex in the frozen baseline missed generic declarations.
The current checkout has 96 public `Type::new` declarations:

| Disposition | Count |
|---|---:|
| `CANONICALIZE_ALIAS` | 92 |
| `KEEP_ALTERNATE` | 1 |
| `VIEW_PRIMARY_COMPAT` | 2 |
| `TEST_SUPPORT` | 1 |

The move inventory covers 69 production files, 3 black-box tests, 39
white-box tests, 12 manifests/interfaces, 1,639 generated-interface lines, and
20 CSS/font assets. All current consumers are inside
`moonbit-community/editor`, so module-root `internal/viewer/**` accepts current
root, workbench, and scenario consumers while closing the packages to outside
modules. The baseline `just check` and the focused controller tests were green.

## Target Internal Package Map

Move MoonBit source, `moon.pkg`, generated interface, and package-contract
README to the following targets:

| Current package | Target package |
|---|---|
| `viewer/browser/config` | `internal/viewer/browser/config` |
| `viewer/browser/controller` | `internal/viewer/browser/controller` |
| `viewer/browser/testing` | `internal/viewer/browser/testing` |
| `viewer/browser/view` | `internal/viewer/browser/view` |
| `viewer/ui/scrollbar` | `internal/viewer/ui/scrollbar` |
| `viewer/contrib/agent_feedback` | `internal/viewer/contrib/agent_feedback` |
| `viewer/contrib/agent_feedback/browser` | `internal/viewer/contrib/agent_feedback/browser` |
| `viewer/contrib/folding/browser` | `internal/viewer/contrib/folding/browser` |
| `viewer/contrib/hover` | `internal/viewer/contrib/hover` |
| `viewer/contrib/hover/browser` | `internal/viewer/contrib/hover/browser` |
| `viewer/contrib/quick_diff/common` | `internal/viewer/contrib/quick_diff/common` |
| `viewer/contrib/quick_diff/browser` | `internal/viewer/contrib/quick_diff/browser` |

Keep the following paths as asset locations even after their MoonBit packages
move:

- `viewer/browser/view/**.css` and `viewer/browser/view/codicon/**`;
- `viewer/browser/view_parts/**`;
- `viewer/ui/scrollbar/scrollable_element.css`;
- `viewer/contrib/agent_feedback/browser/agent_feedback.css`;
- `viewer/contrib/folding/browser/folding.css`;
- `viewer/contrib/hover/hover.css`;
- `viewer/contrib/quick_diff/browser/quick_diff.css`.

Move the implementation README content beside the target package and leave a
small asset-ownership README at an old path when the directory would otherwise
be ambiguous.

## Milestone B: Foreign Local Methods and Test Boundary

Use the current MoonBit local-method syntax, which is identical to ordinary
method syntax except that the method is not `pub`:

```moonbit
fn @editor_browser.MouseTarget::create_unknown(...) -> @editor_browser.MouseTarget {
  ...
}
```

Apply this to the nine package-level factories in
`viewer/browser/controller/mouse_target.mbt`:

- `create_unknown`;
- `create_margin`;
- `create_view_zone`;
- `create_content_text`;
- `create_content_empty`;
- `create_content_widget`;
- `create_scrollbar`;
- `create_overlay_widget`;
- `create_outside_editor`.

Required work:

1. Replace the stale source comment saying MoonBit forbids methods on foreign
   types.
2. Make all nine factories private local static methods on
   `@editor_browser.MouseTarget`.
3. Update only their call spelling. Do not change parameters, constructed enum
   arms, default ranges, unwrap sites, or target details.
4. Rename `mouse_target_test.mbt` to `mouse_target_wbtest.mbt`.
5. Make `ElementPath` private and make
   `get_mouse_column_static`/`hit_test_get_zone_at_coord` private if semantic
   references confirm that their only consumers are the converted white-box
   test.
6. Update `moon.pkg` test import scopes required by the file-mode change.
7. Run `moon info` and confirm that the nine factories, `ElementPath`, and
   test-only helpers disappear from the package interface.

Focused evidence:

- the complete controller package test suite;
- exact existing mouse-target test names and expectations unchanged;
- `moon ide analyze --no-check viewer/browser/controller`;
- reviewed `pkg.generated.mbti` diff showing only intended removals.

Commit this milestone separately.

## Milestone C: Visibility and Trait-Openness Review

Process packages in dependency order so lower contracts stabilize before their
consumers:

1. `base/common`, `base/browser`, `language`, `syntax`, `platform/log`;
2. `viewer/common/{core,config,editor_api,services,tokens,diff,model,cursor,view_layout,view_model,languages,markers,*_api}`;
3. implementation packages that will later move under `internal/viewer`;
4. `internal/shell/{workspace,remote_protocol,server,...}`;
5. browser test support.

For each ledger row:

- change `pub(all) struct/enum` to `pub struct/enum` when external packages need
  the type, fields, or pattern matching but construction is already supplied by
  an explicit constructor/factory;
- add a narrow constructor only when reviewed callers need construction and no
  valid constructor exists;
- use `priv` or ordinary package-private declarations only when every
  cross-package consumer has been removed or replaced;
- seal a trait only when repository contracts say implementations are closed;
- never retain `pub(all)` merely because another implementation package uses a
  struct literal—prefer a constructor or narrow accessor unless caller mutation
  is the contract;
- do not hide fields that are documented read contracts without providing an
  equivalent getter.

After every package cluster:

1. run `moon check --target all` for the changed packages and direct consumers;
2. run focused JS/native tests at the lowest relevant layer;
3. run `moon info` and review every interface diff;
4. rerun `moon ide analyze --no-check` and update ledger dispositions;
5. commit the coherent cluster.

There is no required numeric reduction target. Completion means every original
analyzer annotation has a reviewed terminal disposition and no declaration is
narrowed solely to improve a count.

## Milestone D: Canonical Primary Constructors

For every `CANONICALIZE_ALIAS` ledger item:

1. implement the primary constructor as `Type::Type(...) -> Type`;
2. place `#alias(new)` on that constructor when the old and new signatures are
   identical;
3. migrate in-repository source to constructor syntax (`Type(...)`) or the
   canonical method, leaving `Type::new` as compatibility rather than the
   preferred spelling;
4. preserve validation, normalization, hidden-field derivation, defaults,
   errors, effects, target support, and ownership;
5. confirm the generated interface records the alias;
6. add no duplicate constructor when a canonical `Type::Type` already exists.

Examples in scope include primary constructors for logger implementations,
registries, marker services, browser controllers, view-layout helpers, cursor
owners, hover/folding owners, and internal test-support values.

Do not rename alternate factories such as `empty`, `from_*`, `with_*`,
`cancelled`, or source-specific construction modes into the primary
constructor. A `new` that is genuinely an alternate construction path receives
`KEEP_ALTERNATE` with a reason.

Split commits by dependency tier:

1. foundations/language/syntax/log;
2. viewer common;
3. browser/contribution implementations and test support.

Validate each tier with targeted tests, `moon info`, and `just check`.

## Milestone E: Read-Only Sequence Views

Land a concrete, compatibility-preserving `ArrayView` slice for:

- `PrefixSumComputer`;
- `ConstantTimePrefixSumComputer`.

Target API:

1. the canonical `Type::Type` constructor accepts `ArrayView[Int]`;
2. it creates owned internal storage with `to_owned()` or an equivalent exact
   copy;
3. the existing public `Type::new(Array[Int])` remains as a compatibility
   wrapper because its signature cannot be represented by `#alias(new)`;
4. internal callers prefer the view-based primary constructor.

Add focused tests for:

- an empty view;
- a complete array view;
- a non-zero-offset slice;
- mutation of the source array after construction, proving the computer owns a
  copy;
- existing insertion/removal/cache invalidation behavior.

Review, but do not automatically migrate, these additional candidates:

- path `join`/`resolve` helpers;
- `LineRange::join_many`;
- pure private normalization/search helpers.

Record `N-A (ownership)`, `DEFERRED (compatibility)`, or a landed change for
each reviewed candidate. In particular:

- do not change `TokenizationRegistry::set_color_map`, whose retained array
  identity is explicitly tested;
- do not use a view where the callee stores the view beyond the call unless the
  lifetime and later structural mutation semantics are deliberately reviewed;
- do not introduce broad public `Array`-to-`ArrayView` signature churn merely
  for stylistic uniformity.

Commit the prefix-sum slice separately.

## Milestone F: Move Implementation Packages Under `internal/viewer`

Execute the target package map in dependency-safe groups.

### F1: Browser runtime

Move:

- browser config;
- browser view;
- scrollbar;
- browser controller;
- browser testing.

Update:

- root `viewer` imports;
- internal browser-package imports;
- workbench and browser-scenario imports;
- `scripts/build-web.mbtx` package build paths where present;
- package READMEs and generated interfaces.

Keep `viewer/browser` public and keep every CSS/font asset at its current path.
Run browser view/controller/scrollbar tests and the component suite before
continuing.

### F2: Contributions

Move:

- hover common/browser;
- folding browser;
- agent-feedback common/browser;
- quick-diff common/browser.

Update root Viewer, workbench, scenario, and cross-contribution imports. Public
host DTO/callback packages remain at:

- `viewer/common/agent_feedback_api`;
- `viewer/common/quick_diff_api`;
- other existing public common capability owners.

Do not leave type aliases or wrapper packages at the old contribution paths:
that would preserve the external import surface the move is intended to close.
Compatibility is provided by the root/common handles, not by aliases to
implementation packages.

### F3: Package and asset audit

After both groups:

1. confirm no old implementation directory contains `moon.pkg`,
   `pkg.generated.mbti`, or `.mbt` production/test source;
2. confirm all expected asset paths and hashes remain present;
3. confirm product code imports no old implementation package name;
4. confirm root `viewer/pkg.generated.mbti` still references only
   `viewer/browser`, public common/capability packages, base/log, and Rabbita
   DOM contracts;
5. compile the embedded example using only the supported facade/common imports;
6. run `moon check --target all` to exercise MoonBit's internal-package rules.

Commit browser runtime and contribution moves as separate validated
milestones. Do not mix unrelated behavior changes into either move.

## Milestone G: Documentation, Generated Interfaces, and Closeout

Update current contracts after the code lands:

- `docs/architecture.md`: replace old implementation package paths with
  `internal/viewer/**`, while retaining public `viewer/browser` and
  `viewer/common/**` ownership;
- affected package READMEs: visibility, constructors, internal ownership, and
  exact focused commands;
- `docs/harness.md`: update test/package paths only where the move changes
  commands or fixture ownership;
- `docs/quality.md`: change only if required checks or public-interface review
  instructions actually change;
- source comments that currently justify free functions or package exposure
  with outdated MoonBit limitations.

Regenerate interfaces:

```sh
moon info
moon info --target all
```

Review:

- every removed/added declaration against the Gate A ledger;
- every `#alias(new)` annotation;
- every moved package identity/import list;
- root facade imports;
- absence of stale generated interfaces at old paths;
- no unintended error/effect changes.

After final validation, record results in this plan, fold the completed summary
into `docs/exec-plans/HISTORY.md`, and delete this detailed active plan as
required by `docs/exec-plans/README.md`.

## Evidence Map

| Behavior or invariant | Source/local owner | Planned disposition | Evidence |
|---|---|---|---|
| Mouse targets preserve exact enum arm, range, detail, and coordinate behavior | `viewer/browser/controller/mouse_target.mbt` | declaration/call-form refactor only | unchanged focused tests; controller package tests |
| Controller implementation helpers are absent from public interface | controller generated interface | private local methods/white-box helpers | `moon info` diff; `moon ide analyze` |
| Public DTOs remain constructible through supported constructors/factories | affected common/browser/language packages | narrow representation, not capability | black-box package tests; embedded compile; interface review |
| Genuine extension traits remain externally implementable | language/syntax/log/workspace/server contracts | retain `pub(open)` | README/architecture review; interface diff |
| Existing `Type::new` callers continue compiling | all constructor-ledger packages | canonical constructor plus alias/wrapper | package checks; generated alias review |
| Prefix-sum constructors do not retain caller storage | `viewer/common/view_layout` | `ArrayView` primary plus owned copy | slice and source-mutation tests |
| Root facade exposes no implementation package | `viewer/pkg.generated.mbti` | internal package move | generated-interface import review |
| Embedded/public construction remains supported | embedded viewer | root/common/browser-contract imports only | embedded build and browser smoke |
| Browser behavior survives package moves | view/controller/scrollbar/contributions | move without algorithm change | focused MoonBit tests and Playwright component/smoke |
| CSS/font ownership and emitted asset paths remain stable | existing asset directories and build script | assets stay in place | before/after path/hash inventory; `just build` |

## Test Matrix

### MoonBit semantic/API tests

- black-box tests for public base/language/syntax/log/common contracts;
- white-box controller mouse-target tests after file-mode conversion;
- view-model/model/view-layout tests on both JS and native targets;
- hover/folding/quick-diff/agent-feedback package tests at their moved paths;
- generated-interface diffs after every visibility/constructor cluster.

### Headless and mounted Viewer tests

- model attach/swap/disposal;
- cursor and event ordering;
- view-event source and lifecycle ownership;
- hover request freshness and cancellation;
- folding hidden-area synchronization;
- quick-diff and feedback contribution ownership.

### Browser tests

- component geometry and mouse targeting;
- ViewZones and content-widget placement;
- hover rendering and async model features;
- folding, quick diff, feedback, whitespace, selection, reveal, and model swap;
- workbench and embedded smoke;
- asset loading, including codicon and owner-adjacent CSS.

## Required Validation

Use focused checks after each milestone and the complete matrix before
closeout:

```sh
moon check --target all
moon info
moon info --target all
just check
just test
just build
just test-browser
git diff --check
```

Do not treat green repository checks as proof of a specific visibility or
behavior claim; connect each ledger row to its focused compile/test/interface
evidence.

## Milestone Commit Policy

Commit each coherent, validated milestone without waiting for approval:

1. foreign local methods and controller test boundary;
2. visibility clusters by dependency tier;
3. constructor clusters by dependency tier;
4. prefix-sum `ArrayView` constructors;
5. internal browser-runtime package move;
6. internal contribution package move;
7. documentation/generated-interface closeout.

Do not amend, squash, reset, or rewrite these commits without explicit
approval.

## Exit Criteria

- [ ] Gate A records every analyzer annotation and public `Type::new` with one terminal disposition
- [ ] all nine MouseTarget factories are private local methods
- [ ] controller test-only helpers are absent from its generated interface
- [ ] every original visibility suggestion is narrowed or explicitly retained with a contract reason
- [ ] no genuine external extension trait is accidentally sealed
- [ ] primary constructors use `Type::Type` where applicable
- [ ] compatible `Type::new` callers remain supported
- [ ] prefix-sum primary constructors accept `ArrayView` and own a copy
- [ ] implementation packages live under `internal/viewer/**`
- [ ] public `viewer/browser` and public common/capability packages retain their intended paths
- [ ] old implementation paths contain assets only and no MoonBit package/source
- [ ] CSS/font asset paths and hashes are unchanged
- [ ] root generated interface contains no `internal/viewer/**` implementation type
- [ ] embedded viewer and workbench compile and run through supported boundaries
- [ ] focused behavior/API evidence is green
- [ ] all required repository checks are green

## Explicit Deferred Work

This plan does not:

- internalize `viewer/common/view_model`, `viewer/common/view_layout`,
  `viewer/common/model`, or other common packages;
- redesign the root Viewer API;
- add new editor features or close existing Monaco behavior deferrals;
- convert every `Array` parameter to a view;
- remove all compatibility `new` spellings;
- add a general module/export linter;
- change async runtime structure, error effects, cancellation behavior, or
  provider scheduling;
- change CSS layout, DOM ownership, package target support, or emitted asset
  ordering.
