# Viewer Tokenization Parity

Status: proposed — Phase 0 drafted; inventory pending; semantic Option B approved

Date: 2026-07-10

Oracle commit: b18492a288de038fbc7643aae6de8247029d11bd

Parent: viewer-monaco-parity-remediation.md

Finding: P1-11

Depends on: viewer-model-lifecycle-ownership-parity.md and
viewer-text-buffer-eol-parity.md

No product code may be changed until the syntactic and semantic source-unit
inventories, equal-size ledgers, and semantic-overlay decision are committed
and reviewed.

## Goal

Remove synchronous whole-document tokenization from model attach. Port the
readonly-applicable Monaco syntactic tokenization lifecycle: per-line demand,
state propagation, invalid-line tracking, visible/priority work, background
scheduling, registry changes, token-store updates, and token-change events.

The adjacent semantic-token overlay is currently absent. Because
TokenizationTextModelPart merges syntactic and semantic tokens in the source,
the inventory must account for SparseTokensStore and every merge branch; Gate A
approved explicit DEFERRED rows owned by a future semantic-token plan.

## Scope (Phase 0)

### Pinned Monaco source

- vscode/src/vs/editor/common/model/tokens/tokenizationTextModelPart.ts
  - complete source unit.
- vscode/src/vs/editor/common/model/tokens/tokenizerSyntaxTokenBackend.ts
  - complete source unit.
- vscode/src/vs/editor/common/model/tokens/abstractSyntaxTokenBackend.ts
  - complete AttachedViews, AttachedViewState, AttachedViewImpl, and
    AttachedViewHandler units that drive visible-range priority.
- vscode/src/vs/editor/common/model/textModelTokens.ts
  - complete TokenizerWithStateStore, invalid-line/range queue, and background
    tokenization clusters consumed by the backend.
- vscode/src/vs/editor/common/tokens/contiguousTokensStore.ts
  - complete syntactic line-token store.
- vscode/src/vs/editor/common/tokens/sparseTokensStore.ts
  - complete semantic store and syntactic/semantic merge contract; actual
    semantic-provider acquisition may be deferred only after inventory.
- vscode/src/vs/editor/common/tokenizationRegistry.ts
  - complete registry get/register/change/color-map contract used by the
    scoped part.
- vscode/src/vs/editor/common/tokenizationTextModelPart.ts
  - complete public tokenization-model-part interface.
- vscode/src/vs/editor/common/languages.ts
  - ITokenizationSupport and IState contracts plus TokenizationRegistry
    exposure only; name excluded language-provider siblings.
- vscode/src/vs/editor/common/model/textModel.ts
  - tokenization-part construction, the complete _emitContentChangedEvent
    forwarding member, attach-view priority, and token-part disposal clusters
    only. setValue, _createContentChanged2, _setValueFromTextBuffer, buffer
    representation, and event-length arithmetic belong to the EOL plan.
- vscode/src/vs/editor/common/viewModel/modelLineProjection.ts
  - ModelLineProjection getViewLineData/getViewLinesData token-demand call
    sites only; projection geometry is an excluded sibling.
- vscode/src/vs/editor/common/viewModel/viewModelLines.ts
  - identity/projected ViewModelLines getViewLineData/getViewLinesData
    token-demand call sites only; line mapping is an excluded sibling.

### Local ownership

- viewer/attach_model.mbt
- viewer/common/model/text_model.mbt
- viewer/common/model/text_model_tokens.mbt
- viewer/common/model/text_model_tokens_reference_test.mbt
- viewer/common/model/tokens/tokenization_text_model_part.mbt
- viewer/common/model/tokens/tokenization_text_model_part_wbtest.mbt
- viewer/common/model/tokens/line_tokens_encoder.mbt
- viewer/common/tokens/line_tokens.mbt
- viewer/common/view_model/view_model.mbt
- viewer/common/view_model/model_line_projection.mbt
- viewer/common/view_model/view_model_lines_projected.mbt
- syntax/tokenizer.mbt
- viewer/common/model/tokens/README.md
- viewer/common/tokens/README.md

Inventory every eager/lazy read, forceTokenization call, tokenizer state,
invalid range, priority/visible range, background callback, scheduling guard,
registry change, reset, token-store mutation, semantic merge, event range,
dispose path, and fallback for missing tokenization support.

### Explicitly out of scope

- implementing language grammars or changing tokenizer output semantics;
- token theme/color-map visual design beyond registry contracts required by
  tokenization;
- hover fenced-code tokenization;
- editable incremental edit APIs beyond the set_value full-flush behavior
  exposed by TextModel;
- wall-clock performance budgets without a documented stable environment.

codeEditorWidget._attachModel is a read-only dependency oracle for the absence
of eager whole-model tokenization. Its member ledger belongs to the lifecycle
plan and must not be duplicated here. The local syntax registry currently lives
in syntax/tokenizer.mbt; do not invent a second tokenization_registry module.

## Approved Semantic Decision

Program Gate A approved **Option B — Syntactic scheduling now, semantic overlay
deferred** on 2026-07-10. The inventory must still enumerate every semantic
store/merge/event member and preserve source-shaped update seams. The future
dependency is a separately approved semantic-token acquisition/application
plan owning value and legend types, provider and `Languages` registration,
host/protocol/backend acquisition, model-version cancellation, theme-to-sparse
metadata encoding, `SparseMultilineTokens`, `SparseTokensStore`, and full plus
partial update APIs. Reopening the choice requires updating the parent plan and
stopping for review.

### Rejected Option A — Complete source-shaped tokenization part

Port SparseTokensStore integration and semantic/syntactic per-line merging in
this child, together with the minimum semantic-token update API required to
exercise the source branches.

### Approved Option B — Syntactic scheduling now, semantic overlay deferred

Port the complete syntactic backend and demand/background lifecycle. Give every
semantic member an explicit DEFERRED row naming the future provider/update
dependency. Keep event fields and data contracts source-shaped enough that the
later overlay does not require another architectural rewrite.

Option B may not mark semantic rows N-A merely because the editor is readonly;
semantic highlighting applies to readonly models.

## Initial Decision Register

| Behavior | Decision |
|---|---|
| attach_model calls force_tokenization for the whole model | REQUIRED PARITY: remove |
| first get_line_tokens tokenizes every line | REQUIRED PARITY: port line demand/state propagation |
| background/priority tokenizer is absent from the live model part | REQUIRED PARITY for readonly-applicable scheduling |
| registry change resets and retokenizes with correct event ranges | REQUIRED PARITY |
| missing tokenizer yields source-shaped default tokens | REQUIRED PARITY |
| semantic overlay is absent | DEFERRED: Gate A approved the future acquisition/application dependency |
| whole-document reprojection after token events | sibling decision; inventory exact source/local dependency before expanding |

This register is not the parity ledger and does not count toward the
source-member denominator.

## Inventory and Parity Ledger (Phases 1–2)

The inventory must distinguish:

- token demand from getLineTokens, forceTokenization(line), viewport priority,
  and background idle work;
- tokenizer state validity across previous/current/next lines;
- invalid range merging and queue ordering;
- line-token storage versus semantic sparse tokens and merged LineTokens;
- content flush, language change, tokenizer registration/change, attached-view
  change, and dispose;
- synchronous work bounds on attach and on first visible render;
- exact token-change event ranges and semanticTokensApplied flag.

Port the corresponding upstream tests one source file at a time under
docs/quality.md. Record member and ledger totals, then stop for review.

Review gate: stop after the inventory/ledger documentation commit.

## Test-Authority Corrections

- Current tokenization_text_model_part tests intentionally prove a memoized
  whole-document sweep. Those expectations are local behavior, not a Monaco
  conformance oracle.
- Existing RangePriorityQueue/textModelTokens reference tests prove data
  structures but not that the live TextModel uses them.
- A fast small-document benchmark cannot establish bounded attach work.

## Required Test Matrix (Phase 4)

Use a counting/stateful tokenizer so work is deterministic:

- attaching a model tokenizes zero lines or only the source-required initial
  demand, never all lines;
- requesting line 1, a middle line, and the final line exercises state
  propagation without tokenizing unrelated valid suffixes repeatedly;
- visible ranges move forward/backward and priority work changes accordingly;
- background work advances in bounded scheduled chunks and cancels on dispose;
- set_value invalidates the correct ranges and restarts from the correct state;
- tokenizer registration/replacement/removal affects only matching language
  models and emits exact ranges;
- missing support produces default tokens;
- long lines, many short lines, multiline tokenizer state, and thrown/failing
  support behavior;
- syntactic/semantic overlap, partial deletion, and merge cases remain the
  future semantic-token plan's matrix; this child adds contract-shape tests
  for every deferred semantic row.

Browser/perf evidence may verify responsiveness on a large fixture, but
correctness must use call counts, scheduled-step counts, and event ranges rather
than a flaky elapsed-time threshold.

## Milestones

1. Complete all scoped inventories, equal-size ledgers, upstream test map, and
   the approved Option-B source-member mapping; commit and stop.
2. Wire the existing queue/state-store structures into the live syntactic
   backend.
3. Remove attach-time whole-document force and port demand/priority/background
   scheduling.
4. Port content/registry/dispose invalidation and token-change event ranges.
5. Preserve the approved Option-B event/access boundary and record every
   semantic member as DEFERRED to the named future plan.
6. Port/rewrite tests from whole-sweep expectations to branch-derived source
   behavior.
7. Update model/tokens/token contracts and run all quality gates.
8. Independent source/ledger/diff/test review.

## Deviations (Phase 3)

Expected candidates are editable incremental edits and the approved deferred
semantic-provider acquisition. No scheduling, state, event-range, or merge row
is implicitly excused by the readonly boundary.

## Exit Gate

- [ ] inventory rows equal ledger rows for every scoped source unit
- [ ] attach does not tokenize the whole document
- [ ] per-line state propagation and invalid ranges match source behavior
- [ ] visible/priority/background work is deterministic and tested
- [ ] registry, content, and dispose transitions are covered
- [ ] every semantic row carries its approved Option-B dependency reason
- [ ] all upstream tests are ported or have explicit DEFERRED/N-A ledger rows
- [ ] all repository quality gates pass
- [ ] independent closing reread finds no unaccounted scoped member

## Execution Record

- 2026-07-10: parent Gate A approved Option B. Semantic highlighting remains
  applicable to readonly models, but acquisition/application is deferred to
  the named future dependency rather than expanded inside this P1 scheduling
  child.

Append the dated inventory approval, implementation commits, validation
results, and final ledger totals here. Freeze after implementation.
