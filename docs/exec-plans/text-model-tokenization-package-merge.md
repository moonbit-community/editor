# Text Model and Tokenization Package Merge

Status: inventory ready — STOP FOR REVIEW; no implementation has started
Date: 2026-07-13
Oracle commit: `vscode` submodule at
`b18492a288de038fbc7643aae6de8247029d11bd`

Gate A review artifact:
`text-model-tokenization-package-merge-gate-a.md`. Product code and package
manifests remain unchanged pending review approval.

## Goal

Merge `viewer/common/model/tokens` into `viewer/common/model`, restore
`TextModel` as the direct owner of its tokenization model part, and remove the
closure-based package-cycle carrier.

The current split is not a product boundary. It separates Monaco source units
that live together under `editor/common/model`, creates a compatibility alias
in the parent package, and forces live model facts through
`TokenizationModelAccess`. The merged package is about 7,317 production lines,
below the repository's 10k package target.

Behavior, token timing, event order, attachment lifetime, scheduling, and
token arrays must remain unchanged. Any upstream behavior drift discovered
during inventory becomes a separate parity plan rather than an unreviewed part
of this relocation.

## Current Denominator

| Local package | Production lines | Relevant seam |
|---|---:|---|
| `viewer/common/model` | 4,605 | `TextModel`, snapshot, decorations, model parts |
| `viewer/common/model/tokens` | 2,712 | tokenization part, stores, backends, scheduler |
| Combined target | 7,317 | one multi-target model package |

The local scope includes:

- every production and test file under `viewer/common/model/tokens/`;
- `viewer/common/model/tokens/tokenization_access.mbt` and every
  constructor/caller of `TokenizationModelAccess`;
- `viewer/common/model/text_model_tokens.mbt`, currently a compatibility
  re-export for `RangePriorityQueueImpl`;
- model construction, content-change, attach/detach, language-change,
  scheduling, token-event, and disposal call sites;
- all package manifests importing `viewer/common/model/tokens`.

## Phase 0: Pinned Source Scope

Read and inventory these complete current upstream units:

- `vscode/src/vs/editor/common/model/textModelTokens.ts`
- `vscode/src/vs/editor/common/model/tokens/tokenizationTextModelPart.ts`
- `vscode/src/vs/editor/common/model/tokens/abstractSyntaxTokenBackend.ts`
- `vscode/src/vs/editor/common/model/tokens/annotations.ts`
- `vscode/src/vs/editor/common/model/tokens/tokenizerSyntaxTokenBackend.ts`

Also inventory the complete tokenization-ownership method cluster in
`textModel.ts`: fields/construction, language changes, content flush/change,
attach/detach, background tokenization, token events, and disposal. Explicitly
exclude the editing, search, decoration, undo/redo, and text-buffer sibling
clusters except where a tokenization call crosses them.

Inventory upstream tests represented by the local reference suites, including
`textModelTokens.test.ts`, `textModelWithTokens.test.ts`, and
`model.modes.test.ts`.

## Gate A: Inventory and Review Stop

Before changing a manifest or moving a file, deliver:

1. A complete upstream parity ledger for the scoped units and method cluster.
2. A local ownership graph showing `TextModel`, `TokenizationTextModelPart`,
   scheduler, stores, backends, events, and syntax-token consumers.
3. A field-by-field inventory of `TokenizationModelAccess`: producer,
   consumers, update/freshness requirement, and target direct access.
4. A constructor-order spike explaining how MoonBit will represent the
   `TextModel`/tokenization-part relationship without a closure bundle or
   partially initialized object.
5. A caller inventory for every public declaration in the token package,
   separated into production, white-box tests, black-box tests, and no caller.
6. An exact before/after package dependency graph for all targets.

The constructor-order decision must choose one source-aligned MoonBit shape:

- pass the owning `TextModel` explicitly to part operations; or
- use a package-private shared model state owned by both types.

A late-bound optional back-reference is allowed only if the other two shapes
cannot preserve construction and disposal invariants, and it must be recorded
as a type-system deviation. Replacing ten closures with a differently named
closure record is not an acceptable result.

**Review gate: stop here. Implementation begins only after the inventory,
ledger, and ownership representation are reviewed.**

## Target Ownership and Layout

All moved source units become focused files directly under
`viewer/common/model/`, retaining their source names:

- `text_model_tokens.mbt`
- `tokenization_text_model_part.mbt`
- `abstract_syntax_token_backend.mbt`
- `tokenizer_syntax_token_backend.mbt`
- `tokenization_annotations.mbt`
- token store/queue/helper files already owned by the tokenization cluster
- the existing model/snapshot/decorations files remain separate

There is one `viewer/common/model/moon.pkg`; it remains multi-target and must
not acquire browser/DOM/JS-only dependencies.

`TokenizationScheduler` remains a host-neutral model contract unless the
inventory proves a better existing owner. The browser host may still construct
the scheduler, but the model package owns the scheduling interface it consumes.

## Milestone B: Mechanical Package Merge

1. Extend `viewer/common/model/moon.pkg` with the union of token-package
   dependencies, preserving target-specific test imports.
2. Move production files without changing logic or visibility.
3. Move the associated tests with their source units.
4. Update all imports and package qualifications across syntax, viewer,
   view-model, and tests.
5. Delete `viewer/common/model/tokens/moon.pkg` and its generated interface
   once no caller references it.

Gate:

- `moon check --target all`
- targeted model/token reference tests
- `just check`

Commit this behavior-neutral relocation before changing model access.

## Milestone C: Restore Direct Model Ownership

1. Replace every `TokenizationModelAccess` query with package-private direct
   access through the reviewed representation.
2. Preserve query timing: facts that were formerly closures must still be read
   at the source-equivalent moment, not snapshotted early.
3. Preserve source ordering for content changes, invalidation, background
   token work, token events, attachment count, and disposal.
4. Remove the access carrier and its constructor.
5. Remove `RangePriorityQueueImpl`'s parent-package compatibility alias; its
   implementation now already has the canonical package name.
6. Update source comments so they describe current ownership rather than the
   deleted cycle.

Every changed logic line remains source-cited or receives a concrete entry in
`Deviations`. Package convenience is not a sufficient deviation.

## Milestone D: API and MoonBit Cleanup

After behavior is green:

1. Run `moon ide analyze viewer/common/model` and
   `moon ide find-references` for every formerly public token helper.
2. Make stores, queues, accessors, event helpers, and backend glue private when
   no downstream production package requires them.
3. Keep public only the actual model/tokenizer contracts used below or outside
   the package.
4. Rename touched primary constructors to `Type::Type`; keep `new` only for a
   distinct alternate construction path.
5. Replace simple indexing loops or `.get(0)` branches only when the change is
   source-equivalent and does not obscure a parity ledger row.
6. Regenerate and review `pkg.generated.mbti`.

Do not combine this cleanup with new tokenization behavior.

## Milestone E: Tests and Documentation

1. Keep upstream reference tests in the merged package and preserve their
   oracle/source citations.
2. Add or retain tests proving live reads across:
   - content replacement before flush handling;
   - language changes;
   - attach/detach count transitions;
   - too-large/disposed guards;
   - idle, zero-timeout, and delayed scheduling;
   - invalid range queues and background completion;
   - token events reaching the view model.
3. Update `viewer/common/model/README.md` with the merged ownership and test
   commands; remove the obsolete token-package README.
4. Update `docs/architecture.md` and the relevant source map.

Required validation:

- `moon check --target all`
- targeted model and tokenization suites on every supported target
- `just check`
- `just test`
- `just build`
- `just test-browser`

## Exit Criteria

- [ ] inventory rows equal scoped source members; final totals are recorded
- [ ] `viewer/common/model/tokens` no longer exists as a package or import
- [ ] `TokenizationModelAccess` and its closure fields are gone
- [ ] `RangePriorityQueueImpl` has one canonical definition/name
- [ ] `TextModel` owns and drives tokenization directly through the reviewed
      MoonBit representation
- [ ] event, scheduling, freshness, attach/detach, and disposal order match the
      source ledger
- [ ] no public API exists solely because of the former package boundary
- [ ] all deviations are recorded and seam-based
- [ ] closing complete-source reread finds no unaccounted member
- [ ] required validation is green

## Cross-Plan Coordination

Execute this plan before
`inline-decorations-view-model-package-merge.md`, because both edit
`viewer/common/view_model/moon.pkg` and model-facing imports. Do not run it in
parallel with tokenization parity work or any change to `TextModel`
construction/content/disposal paths.
