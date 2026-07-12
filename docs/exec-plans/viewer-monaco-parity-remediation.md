# Viewer–Monaco Parity Remediation Program

Status: active — render-invalidation child inventory active

Date: 2026-07-10

Viewer baseline: 84326d48437bc71267f5f9b0e45395b63e7c6511

Oracle commit: b18492a288de038fbc7643aae6de8247029d11bd

This is the coordination plan for the current Viewer-versus-Monaco audit. It
does not replace or rewrite any implemented execution plan. Implemented plans
remain historical evidence; this plan and its child plans describe the new
work required by the 2026-07-10 audit.

The program follows _PORT_PLAYBOOK.md. In particular, each child plan must name
complete source units or complete method clusters, inventory every member and
behavior-changing branch, build an equal-size parity ledger, and stop for
review before product code changes.

## Outcome

Close the confirmed P1 Viewer/Monaco divergences without turning the audit into
one unreviewable cross-repository rewrite. The work is split by ownership and
source unit so that every implementation milestone can be source-reviewed,
tested, committed, and independently audited.

This program is complete only when:

- every P1 finding below is closed by an implemented child plan;
- every child inventory count equals its parity-ledger row count;
- all required behavior is proven by branch-derived tests at the lowest useful
  harness layer;
- browser geometry is measured, not inferred from green repository checks;
- every intentional reduction is written into the owning package contract;
- an independent closing audit finds no unaccounted member in the scoped
  Monaco source units.

## Program Decision Vocabulary

Audit findings and the child plans' initial decision registers use:

- REQUIRED PARITY: the readonly/product boundary does not justify the
  divergence.
- INTENTIONAL DEVIATION: the product deliberately differs; the owning README
  must state the contract and the ledger must name the seam.
- DEFERRED (reason): valid parity work that is postponed with an explicit
  dependency or product decision.
- N-A (reason): the source member cannot apply to the readonly Viewer.

These are program decisions, not member-ledger statuses. After inventory, the
real parity ledger uses only TODO while working and PORTED, TESTED, PASS,
DEFERRED (reason), or N-A (reason) as terminal statuses. The initial decision
register does not count toward the source-member denominator.

An existing local test is evidence only after its expected behavior has been
checked against the pinned source. An unreviewed or unapproved divergence
assertion is a test bug, not a compatibility contract. A reviewed
INTENTIONAL DEVIATION recorded in the owning README and parity ledger is a
product contract and belongs in an ordinary local test.

## P1 Audit Register

| ID | Finding | Initial decision | Child plan |
|---|---|---|---|
| P1-01 | Arrow/Page/Home/End keys scroll instead of performing Monaco cursor navigation and Shift selection | REQUIRED PARITY | viewer-cursor-input-events-parity.md |
| P1-02 | Mouse selection and model-content flush mutate cursor state without public cursor events | REQUIRED PARITY | viewer-cursor-input-events-parity.md |
| P1-03 | Inlay and hover async work can write stale results after content or same-URI model changes | REQUIRED PARITY | viewer-async-model-features-parity.md |
| P1-04 | Model attach clears host diagnostics and marker decorations are not removed for every detach path | REQUIRED PARITY | viewer-model-lifecycle-ownership-parity.md |
| P1-05 | Viewer.dispose leaks global subscriptions and disposes caller-owned shared services | REQUIRED PARITY | viewer-model-lifecycle-ownership-parity.md |
| P1-06 | Runtime option changes do not invalidate all affected ViewParts | REQUIRED PARITY | viewer-render-invalidation-parity.md |
| P1-07 | Horizontal extent is estimated from UTF-16 length rather than measured rendered width | REQUIRED PARITY | viewer-browser-geometry-parity.md |
| P1-08 | ContentWidget x geometry is a uniform-width estimate and decoration changes do not reposition it | REQUIRED PARITY; render invalidation is a prerequisite source cluster | viewer-browser-geometry-parity.md |
| P1-09 | ViewCursors ignores decoration changes that move rendered text | REQUIRED PARITY | viewer-render-invalidation-parity.md |
| P1-10 | ViewZone rendering overwrites host class/style and callback exceptions abort the frame | REQUIRED PARITY | viewer-view-zones-parity.md |
| P1-11 | Attaching a model synchronously tokenizes the entire document | REQUIRED non-blocking behavior; exact scheduling comes from inventory | viewer-tokenization-parity.md |
| P1-12 | CRLF value length and offset/position conversion use different coordinate systems | REQUIRED coherent buffer invariant; Gate A approved coherent LF-only storage | viewer-text-buffer-eol-parity.md |

## Child Plans and Landing Order

| Order | Child plan | Primary ownership | Depends on | Status |
|---:|---|---|---|---|
| 1 | viewer-model-lifecycle-ownership-parity.md | Viewer, ModelData, MarkerDecorationsService, external subscriptions | none | implemented |
| 2 | viewer-async-model-features-parity.md | inlay/hover request lifecycle and model freshness | lifecycle plan | implemented |
| 3 | viewer-cursor-input-events-parity.md | cursor state/event spine and readonly keyboard commands | lifecycle plan | implemented |
| 4 | viewer-render-invalidation-parity.md | View events and ViewPart dirtiness | lifecycle and async plans | inventory in progress |
| 5 | viewer-browser-geometry-parity.md | ViewLines width, ContentWidgets coordinates, renderer font facts, layout extent | invalidation plan | proposed |
| 6 | viewer-view-zones-parity.md | ViewZone API/layout/DOM/callback/model lifecycle | lifecycle, invalidation, and geometry plans | proposed |
| 7 | viewer-text-buffer-eol-parity.md | TextSnapshot and TextModel read/coordinate boundary | none; land before later provider-surface work | proposed |
| 8 | viewer-tokenization-parity.md | syntactic-token scheduling/store integration and attach behavior | lifecycle and EOL plans | proposed |

The order is intentional. Several plans touch viewer/viewer.mbt,
viewer/attach_model.mbt, or viewer/browser/view/view_part.mbt. Do not execute
overlapping plans in parallel worktrees and then merge them mechanically.

## Cross-Plan Source Ownership

Shared files do not permit duplicate ledger ownership. Use these non-overlapping
method clusters:

| Shared source/local area | Owning child plan |
|---|---|
| codeEditorWidget attach/detach/dispose and ModelData lifetime | model lifecycle |
| codeEditorWidget cursor event forwarding and cursor API methods | cursor/input events |
| codeEditorWidget updateOptions notification | render invalidation |
| codeEditorWidget changeViewZones/accessor transaction | ViewZones |
| TextModel value/range/offset/EOL plus setValue buffer/event construction | text-buffer EOL |
| TextModel version/request freshness methods | async model features |
| TextModel _emitContentChangedEvent token forwarding plus token-part construction/disposal | tokenization |
| ViewLines event handlers | render invalidation |
| ViewLines width measurement and max-width feedback | browser geometry |
| ContentWidgets event handlers and dirty-state transitions | render invalidation |
| ContentWidgets validation, visible ranges, placement, and focus preservation | browser geometry |
| ViewLayout general scroll/content dimensions | browser geometry |
| ViewZone-owned min-width/container-width writes | ViewZones, consuming geometry's extent contract |
| LinesLayout/ViewLayout zone insertion, ordering, and zone viewport data | ViewZones |
| ViewModelEventDispatcher cursor outgoing events | cursor/input events |
| ViewModelEventDispatcher configuration/decorations events | render invalidation |
| ViewModelEventDispatcher ViewZonesChanged event | ViewZones |
| Viewer/attach_model resource lifetime | model lifecycle |
| Viewer/attach_model async request creation/cancellation | async model features |

Each child inventory must list its excluded sibling clusters using this table.
If a member cannot be assigned unambiguously, stop and update this coordination
plan before creating duplicate ledger rows.

## Status Protocol

Child plans use these states:

- proposed — Phase 0 drafted; inventory pending
- inventory ready — STOP FOR REVIEW
- approved for implementation
- in progress
- implemented
- superseded

Once a child reaches implemented it becomes immutable historical evidence.
The portfolio remains active until every child closes and the P1 re-audit is
complete.

## Program Gates

### Gate A — Classification Review

Approved 2026-07-10:

- The P1 register decisions remain as written. Readonly is a capability seam
  for text mutation, multi-cursor editing, and editable-only commands; it is
  not a reason to replace Monaco navigation, ownership, cancellation,
  geometry, callback, buffer-coherence, or bounded-work behavior.
- Text-buffer EOL policy is **Option B — coherent LF-only product seam**. The
  current Viewer read API commits to normalized LF and exposes no EOL
  preference. Gate A therefore chooses to bring snapshot storage and
  coordinates into that read contract. Construction and `set_value` must
  normalize every input EOL form to LF before storing text or deriving
  offsets. Raw CRLF/CR indices may not survive behind LF-returning reads.
  Every affected Monaco EOL-selection/preference member still receives an
  intentional-deviation ledger row and contract/test evidence.
- Tokenization semantic policy is **Option B — syntactic scheduling now,
  semantic overlay deferred**. Readonly does not make semantic highlighting
  N-A, but this repository has no semantic-token value/legend/provider
  contract, language registry, host/protocol/backend acquisition path,
  model-version cancellation pipeline, theme-to-sparse-metadata encoder, or
  full/partial sparse-token update seam. A separately approved semantic-token
  acquisition/application plan must own those dependencies and include
  `sparseMultilineTokens.ts` in its source denominator. This child preserves
  the existing `ModelTokensChangedEvent.semantic_tokens_applied` field and
  centralized `get_line_tokens` access boundary; full/partial semantic update
  APIs and sparse types remain future-plan work. Every semantic source row
  still needs a concrete DEFERRED reason.
- P1-04 remains REQUIRED PARITY, but its lifecycle inventory must distinguish
  Monaco's model-service add/remove lifetime from an editor attach/detach.
  Shared `ViewerServices` cannot be made correct by mechanically deleting a
  URI-keyed marker owner whenever one Viewer detaches; the approved design must
  account for model identity and shared registrations. Release that Viewer's
  model registration on every detach/dispose path; dispose the per-model
  marker owner only when the final registration for that model identity is
  released.

Before any child implementation:

- carry these approved decisions into the child inventory and equal-size
  ledger;
- do not reopen them during implementation without updating this coordination
  plan and stopping for another classification review.

### Gate B — Inventory Review

For one child plan at a time:

1. Complete Phase 0 and Phase 1 in the child document.
2. Record every member, constant, branch, early return, DOM/CSS property, and
   source-owned callback.
3. Record the member count and create exactly that many ledger rows.
4. Commit the documentation-only inventory milestone.
5. Stop. A reviewer must approve the denominator before product edits.

### Gate C — Implementation

After inventory approval:

- add or correct branch-derived tests;
- port source structure, ordering, constants, and timing behavior;
- commit each coherent green milestone;
- do not absorb adjacent P2 work unless it is an inventoried sibling member of
  the same complete source unit;
- record all such sibling rows as PORTED, TESTED, DEFERRED, or N-A rather than
  silently omitting them.

### Gate D — Independent Review

Use a fresh task that begins in read-only review mode. It must reconcile:

- pinned Monaco source;
- approved inventory and ledger;
- actual product diff;
- test matrix and observed evidence.

The implementer does not self-certify 1:1 completion. Any missing row, invented
arithmetic, changed branch order, untested configuration, or unsupported PASS
returns the child plan to implementation.

### Gate E — Closeout

For each child:

- run the required focused package tests and any exact upstream reference tests;
- run just check, just test, just build, and just test-browser before declaring
  cross-package/browser-visible work complete;
- update owning package READMEs, generated public contracts when applicable,
  docs/architecture.md or docs/harness.md only where the landed contract
  changes;
- record done/deferred/N-A totals and the closing whole-source reread;
- mark the plan implemented and then treat it as immutable history.

## Test-Authority Audit

The following expectations must not be used as oracles until reconciled:

- viewer/set_value_api_wbtest.mbt documents that attach clears markers.
- viewer/common/model/text_model_test.mbt treats URI plus host version as a
  sufficient freshness identity even when the model instance/revision changes.
- tests/browser/component/model_swap.spec.js and
  tests/browser/moonbit/model_swap currently describe ViewZones as surviving
  model replacement.
- viewer/common/languages/languages_registry_wbtest.mbt fixes oldest-provider
  first behavior; it belongs to the P2 provider backlog, not to a future
  Monaco-parity proof.
- reveal tests that require immediate movement belong to the P2 state/reveal
  backlog and are not evidence for Monaco default reveal semantics.

Tests that merely omit the failing axis are also insufficient. The child plans
must add the missing matrices for pointer/flush cursor events, out-of-order
async results, shared-service disposal, runtime option mutation, dynamic inline
decorations, complex rendered widths, throwing ViewZone callbacks, CRLF
round-trips, and bounded tokenization work.

## Harness Policy

Use docs/harness.md and docs/quality.md:

- MoonBit package tests for deterministic model, cursor, layout, event,
  cancellation, and tokenization state. Use reference filenames only when an
  actual upstream suite/test is ported with its original label, source path,
  and current pin.
- Headless Viewer tests for model/view-model/cursor/layout integration without
  DOM measurement.
- Browser component tests for public Viewer behavior and measured DOM geometry.
- Browser smoke tests only for real user gestures and workbench/embed behavior.
- Perf tests as evidence unless a deterministic budget and environment are
  explicitly documented.

For browser geometry, a pinned local Monaco fixture may be used only as
non-gating diagnostic evidence to discover and compare measured facts. Pass or
fail comes from pinned source/ported branches plus deterministic local
offsetWidth, DOM Range, computed-style, callback-sequence, and reachability
invariants. Cross-fixture pixel equality and screenshots do not establish
parity.

## P2 Backlog Boundary

This program does not authorize a general P2 cleanup. Provider scoring and
aggregation, full ViewZone API shape, quick diff scheduling, reveal/view-state
parity, syntax folding, agent-feedback storage, scrollbar platform tails,
shadow/iframe support, semantic-token overlay, and visual/theme tails remain in
the audit backlog unless a complete source unit in a P1 child requires an
explicit PORTED/DEFERRED/N-A decision.

After all P1 children close, perform a fresh audit against the then-current
Viewer HEAD and the same pinned oracle before creating P2 execution plans.

## Agent Handoff Contract

The first task for each child plan is:

> Complete Phase 0–2 inventory and parity-ledger work in this plan. Read every
> named source unit. Do not edit product code. Commit the documentation-only
> milestone and stop for review.

Only after approval should a new task receive:

> Implement the approved child plan through its exit gate. Preserve source
> control flow, commit each validated milestone, and do not expand scope.

The independent closing task is:

> Audit the implementation against the pinned source, approved ledger, diff,
> and test matrix. Report discrepancies before making fixes.

## Decision and Execution Log

- 2026-07-10: created the portfolio and eight child plan shells from the P1
  audit. No product implementation or Phase-1 source-member inventory has
  started.
- 2026-07-10: Gate A approved all P1 classifications, coherent LF-only EOL
  storage (EOL Option B), and deferred semantic overlay with source-shaped
  seams (tokenization Option B). The lifecycle inventory must resolve shared
  marker-service registration ownership before implementation.
- 2026-07-10: the lifecycle child is implemented and frozen. Its 427-row
  ledger closes as 146 TESTED, 91 PORTED, 153 DEFERRED, and 37 N-A, with zero
  TODO/PASS. Two independent closing audits found and drove fixes for duplicate
  marker multiplicity, finalization/dispose ordering, evidence precision, and
  malformed rows. Final gates pass: check, JS 880/880, native 690/690, build,
  and browser 41/41. The portfolio proceeds to the async-model-features child.
- 2026-07-10: async inventory commit `5721b8e` was rejected at Gate B. Its 581
  rows were mechanically contiguous but umbrella rows compressed declared
  members/branches/CSS facts and two derived notes were counted as source.
  No product/test file changed.
- 2026-07-10: corrected inventory commit `811e1a2` was also rejected at Gate B.
  Its 759 rows still compressed nested callbacks, interface/object properties,
  DOM/CSS/custom properties, and exact arithmetic. No product/test file changed.
- 2026-07-10: third inventory commit `d34b20a` was rejected at Gate B. Its
  924 rows split source-owned callbacks and CSS facts, but also counted
  straight-line statement ordering and property arithmetic separately from the
  owning member/property, contrary to the uniform atom rule. No product/test
  file changed.
- 2026-07-10: normalized async-model-features inventory commit `e108586` has
  810/810 TODO rows: 232 inlay-controller, 49 inlay-fragment, 448 hover, and
  81 model-version/cancellation members, plus the separate 87-row current-
  MoonBit ownership/test-authority audit and branch-derived matrix. Independent
  full and split cross-checks found zero missing/duplicate rows and approved the
  exhaustive target map: 373 planned TESTED, 7 PORTED, 345 DEFERRED, and 85
  N-A. At that milestone Gate B passed and async product/test implementation
  was authorized.
- 2026-07-10: the async-model-features child is implemented and frozen. Product
  commit `5c2bf13` owns cancellation sources, physical-model/internal-version/
  generation request stamps, provider snapshot/liveness checks, clearable
  hover timers, and guarded inlay/hover apply boundaries. Its 810-row ledger
  closes as 331 TESTED, 7 PORTED, 371 DEFERRED, and 101 N-A, with zero
  TODO/PASS. Independent closing audits drove fixes for equal-key sort
  stability, disposal timing, concurrent partial emission, incomplete hover
  invalidation, react-timer retirement, and strict evidence dispositions.
  Final gates pass: check, JS 964/964, native 759/759, build, and browser 42/42;
  the focused async browser race also passed ten repeated runs. The portfolio
  proceeds to the cursor/input-events child.
- 2026-07-10: the normalized cursor/input-events Phase 1–2 proposal is ready
  with 799/799 TODO rows: 212 cursor state/event, 216 movement, and 371 command,
  mouse, public-API, dispatcher, and ViewModel atoms. The proposed map is 361
  TESTED, 81 PORTED, 176 DEFERRED, and 181 N-A. Frozen lifecycle ownership of
  the CodeEditorWidget cursor relay is inherited instead of duplicated. No
  product/test file changed; the portfolio stops for independent Gate B review.
- 2026-07-10: three independent reviews rejected cursor Gate B at inventory
  commit `7c0a3b3`. The docs-only amendment now has 802/802 TODO rows: 213
  cursor state/event, 218 movement, and 371 browser/public/event atoms; its
  proposed map is 337 TESTED, 71 PORTED, 213 DEFERRED, and 181 N-A. It splits
  collapsed callbacks and mixed key registrations, retires scroll/reveal
  umbrella rows, names an outgoing-only dispatcher plus reentrancy-safe FIFO,
  and makes word/validation/generic-collector deferrals explicit. No product
  or test file changed; the program stops for a fresh Gate B re-review.
- 2026-07-10: the first re-review passed the browser/public/event and most
  cursor surfaces but rejected dual-state reflow evidence: source
  `ensureValidState` consumes `validateViewRange`/`validateViewPosition`, which
  the local converter does not expose. The second amendment keeps the 802-row
  denominator and changes ONE-015, COL-009, and CUR-012 from TESTED to
  DEFERRED alongside ONE-028. The proposal is now 334 TESTED, 71 PORTED, 216
  DEFERRED, and 181 N-A; local model-side reprojection remains ordinary
  reduced-seam evidence. No product/test file changed; final Gate B review is
  still required.
- 2026-07-10: cursor Gate B passed at inventory commit `fc9a28b`. The approved
  fixed denominator is 802/802 TODO rows with 334 planned TESTED, 71 PORTED,
  216 DEFERRED, and 181 N-A; the child-plan hash is `205db5d…bdd402`.
  Independent reviews confirmed the cursor/movement and browser/event halves,
  the outgoing FIFO topology, exact 59 + 10 test authority, and both distinct
  dual-side validation call paths. Product/test implementation is authorized.
- 2026-07-12: the cursor/input-events child is implemented and frozen. Product
  commit `1525ed932acb4e2c3300a401ab2a329d1b5fdbaf`, independent-audit remediation
  commit `07d2e8a9664e068c7cf43c6a9a841274ed756630`, and contract correction commit
  `3c8b25277b3508b31eb8c146bc8f5578631bd688` close the cursor state/event
  spine, source-shaped command objects,
  readonly key and pointer gestures, exact reveal/source propagation, physical-
  model content barriers, and listener-level reentrant delivery. The 802-row
  ledger closes as 326 TESTED, 69 PORTED, 226 DEFERRED, and 181 N-A with zero
  TODO/PASS. Ten approved-map rows were downgraded during closing review: eight
  direct grapheme-dependent atoms, the absent numeric command-weight ABI, and
  fixed readonly pointer-option reads. Independent Gate D reviews found no
  remaining runtime blocker. Final gates pass: check, JS 1127/1127, native
  858/858 (Wasm has no test entry), build, and browser 54/54; an initial blank-
  page folding startup failure passed both its focused rerun and the complete
  rerun. The portfolio proceeds to the render-invalidation inventory.
