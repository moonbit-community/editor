# Viewer Text Buffer EOL Parity

Status: proposed — Phase 0 drafted; inventory pending; EOL Option B approved

Date: 2026-07-10

Oracle commit: b18492a288de038fbc7643aae6de8247029d11bd

Parent: viewer-monaco-parity-remediation.md

Finding: P1-12

Depends on: none. Land before provider full-range parity work.

No product code may be changed until the inventory, ledger, and explicit EOL
policy decision are committed and reviewed.

## Goal

Establish one coherent text-buffer coordinate system. Stored text, model EOL,
getValue/getValueLength, range length, getPositionAt, getOffsetAt, provider
full ranges, and content-change events must agree for LF, CRLF, CR, mixed-EOL,
and trailing-EOL input.

The plan must decide whether the readonly Viewer ports Monaco's detected/default
model EOL or deliberately normalizes all input to LF. Either choice must
normalize the internal representation coherently; preserving raw CRLF offsets
while returning LF values is not an allowed deviation.

## Scope (Phase 0)

### Pinned Monaco source

- vscode/src/vs/editor/common/model/pieceTreeTextBuffer/pieceTreeTextBufferBuilder.ts
  - complete chunk ingestion, line-start creation, EOL counting/selection, BOM,
    normalizeEOL, and finish clusters for string input.
- vscode/src/vs/editor/common/model/pieceTreeTextBuffer/pieceTreeTextBuffer.ts
  - complete read-only value/range-length/EOL/position/offset clusters.
- vscode/src/vs/editor/common/model/pieceTreeTextBuffer/pieceTreeBase.ts
  - complete line-start, line-length, getPositionAt, and getOffsetAt clusters
    consumed by the read-only buffer.
- vscode/src/vs/editor/common/model/textModel.ts
  - createTextBuffer for string input; constructor buffer facts;
    getValue, getValueLength, getValueInRange, getValueLengthInRange,
    getPositionAt, getOffsetAt, getFullModelRange, setValue,
    _createContentChanged2, and _setValueFromTextBuffer. The complete
    _emitContentChangedEvent member is excluded and owned by
    viewer-tokenization-parity.md.
- vscode/src/vs/editor/common/model.ts
  - EndOfLinePreference, EndOfLineSequence, DefaultEndOfLine, and the complete
    read-only ITextBuffer/ITextModel methods consumed above.

### Local ownership

- viewer/common/model/text_snapshot.mbt
- viewer/common/model/text_model.mbt
- viewer/common/model/text_model_events.mbt
- viewer/common/model/text_model_reference_wbtest.mbt
- viewer/common/model/set_value_wbtest.mbt
- viewer/common/languages/languages.mbt
- viewer/common/model/README.md
- language/inlay_hints.mbt

Inventory every line-start and line-end calculation, EOL exclusion/inclusion
rule, full-range calculation, normalization point, value/length preference,
position/offset clamp/validation, content-change range length, and provider
range derived from model length.

### Explicitly out of scope

- incremental edit operations, undo/redo, indentation guessing, and EOL mutation
  commands;
- streaming input unless a source member is required to explain string-input
  behavior; streaming rows may be N-A with a precise reason;
- BOM preservation in public Viewer APIs unless inventory shows the existing
  contract already exposes it;
- search and clipboard EOL preferences;
- language-provider API expansion beyond correcting its full model range.
- TextModel _emitContentChangedEvent tokenization forwarding; the tokenization
  plan owns that complete member while consuming the EOL event contract.

## Required Policy Decision

Program Gate A approved **Option B — Coherent LF-only product seam** on
2026-07-10. The inventory must still account for every Option-A source member,
record the affected rows as reviewed intentional deviations, and prove that
all non-preference coordinate behavior remains source-faithful. Reopening the
choice requires updating the parent coordination plan and stopping for review.

The inventory review must choose exactly one:

### Option A — Monaco model EOL

Port the builder's EOL counting/default selection and store the chosen model
EOL. TextDefined, LF, and CRLF preferences follow the source read APIs.

### Option B — Coherent LF-only product seam

Normalize all incoming text to LF at buffer construction and set_value, store
only LF line starts, and document that the Viewer has no TextDefined/CRLF
preference. Every value, length, offset, position, range, and event uses the
normalized representation.

Option B is an INTENTIONAL DEVIATION and requires a source-member ledger row,
README contract, and reference tests showing that only EOL preference differs.
It may not retain raw CRLF indices.

## Initial Decision Register

| Behavior | Decision |
|---|---|
| get_length counts raw CRLF while get_value emits LF | REQUIRED coherent invariant |
| getPositionAt/getOffsetAt use a different length basis from getValueLength | REQUIRED coherent invariant |
| provider full range can stop before the final content | REQUIRED PARITY |
| content-change range_length/eol disagree with stored buffer | REQUIRED coherent invariant |
| exact TextDefined/default-EOL semantics | DECISION REQUIRED: Option A or B |
| invalid positions clamp instead of throwing | sibling inventory row; do not expand without an explicit decision |

This register is not the parity ledger and does not count toward the
source-member denominator.

## Inventory and Parity Ledger (Phases 1–2)

Port the corresponding upstream reference-test denominator as part of the
inventory. The current reference file explicitly defers EOL preference cases;
list each deferred upstream test by name and assign it a planned PORTED,
DEFERRED, or N-A ledger row.

Required invariants must be written algebraically in the plan before code:

- getValueLength(preference) equals the UTF-16 length of getValue(preference);
- getOffsetAt(getPositionAt(offset)) round-trips every valid logical offset,
  with source-defined behavior at EOL interiors/boundaries;
- full range length equals the text returned for that range under the same EOL
  preference;
- set_value change-event old/new ranges and lengths use the chosen buffer
  representation.

Review gate: stop after inventory, ledger, invariant list, and Option A/B
decision are committed.

## Test-Authority Corrections

- viewer/common/model/text_model_reference_wbtest.mbt currently marks the CRLF
  getValueLengthInRange and TextModelData cases DEFERRED. They are the primary
  missing evidence for this plan.
- Tests that assert LF output alone do not validate offset/position coherence.
- Provider tests using LF-only input do not validate the full-range bug.

## Required Test Matrix (Phase 4)

Port upstream cases and add local invariants for:

- empty, one-line, LF, CRLF, CR, mixed LF/CRLF/CR, and trailing EOL;
- majority/default-EOL ties if Option A is selected;
- non-ASCII BMP, surrogate pairs, combining text, and positions beside EOL;
- every offset from zero through document length for small fixtures;
- every valid line/column boundary and invalid inputs according to the approved
  validation contract;
- getValue, getValueLength, getValueInRange, getValueLengthInRange,
  getPositionAt, getOffsetAt, getFullModelRange, and provider full range;
- set_value transitions between different EOL forms and content-change events.

## Milestones

1. Complete source/test inventory, ledger, invariants, and Option A/B proposal;
   commit and stop.
2. Port the approved immutable buffer construction/EOL representation.
3. Port read/length/range/position/offset methods over that representation.
4. Correct set_value events and provider full ranges.
5. Port/re-enable upstream EOL reference cases and invariant/property tests.
6. Update model and language contracts.
7. Run focused and full quality gates.
8. Independent source/ledger/diff/test review.

## Deviations (Phase 3)

No deviation is approved yet. Option B, if chosen, must be recorded here with
the exact source members affected and proof that all remaining coordinate
behavior is source-faithful.

## Exit Gate

- [ ] inventory rows equal ledger rows
- [ ] Option A or B is explicitly approved
- [ ] value length and returned value always agree
- [ ] offset/position/range invariants cover every EOL form
- [ ] provider full range reaches the complete document
- [ ] set_value event facts use the approved representation
- [ ] upstream EOL reference cases are accounted for by name
- [ ] all repository quality gates pass
- [ ] independent closing reread finds no unaccounted scoped member

## Execution Record

- 2026-07-10: parent Gate A approved Option B. The current public contracts
  expose normalized LF reads and no EOL preference; construction and
  `set_value` must normalize before storing text or deriving coordinates.

Append the dated inventory approval, implementation commits, validation
results, and final ledger totals here. Freeze after implementation.
