# Viewer Text Buffer EOL Parity

Status: inventory ready — STOP FOR REVIEW; EOL Option B approved

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

Gate A chose a coherent LF-only product seam: normalize all input to LF before
storage and derive every value, length, range, offset, position, provider range,
and content-change fact from that representation. Preserving raw CRLF offsets
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
- vscode/src/vs/editor/common/textModelEvents.ts
  - the public `IModelContentChangedEvent` fields, `ModelRawFlush`, and the raw
    event constructor facts produced by `setValue`; the complete internal
    wrapper/emitter delivery mechanics remain tokenization-owned.
- vscode/src/vs/editor/common/model/mirrorTextModel.ts
  - the complete four-field `IModelContentChange` payload produced by
    `_createContentChanged2`.
- vscode/src/vs/editor/common/model.ts
  - EndOfLinePreference, EndOfLineSequence, DefaultEndOfLine, and the complete
    read-only ITextBuffer/ITextModel methods consumed above.

### Local ownership

- viewer/common/model/text_snapshot.mbt
- viewer/common/model/text_model.mbt
- viewer/common/model/text_model_events.mbt
- viewer/common/model/text_model_reference_wbtest.mbt
- viewer/common/model/model_reference_wbtest.mbt
- viewer/common/model/text_model_test.mbt
- viewer/common/model/set_value_wbtest.mbt
- viewer/common/languages/languages.mbt
- viewer/common/languages/inlay_hints_request.mbt
- viewer/common/languages/inlay_hints_request_wbtest.mbt
- viewer/common/model/README.md
- language/inlay_hints.mbt
- viewer/public_read_api.mbt
- viewer/public_read_api_wbtest.mbt

Review-only consumers, not additional source-member owners:

- internal/shell/workbench/app.mbt constructs a model from the raw provider
  `DocumentSnapshot` and serializes `model.snapshot.text`;
- internal/shell/workspace/document.mbt deliberately remains the raw provider
  boundary. Its duplicated line-start scanner is not changed by this child;
  LF normalization begins at `TextSnapshot` construction;
- browser component scenarios that search `model.snapshot.text` consume the
  normalized offsets transitively and require regression coverage, not new
  ledger rows.

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

## Approved Policy Decision

Program Gate A approved **Option B — Coherent LF-only product seam** on
2026-07-10. The inventory must still account for every Option-A source member,
record the affected rows as reviewed intentional deviations, and prove that
all non-preference coordinate behavior remains source-faithful. Reopening the
choice requires updating the parent coordination plan and stopping for review.

### Rejected Option A — Monaco model EOL

Port the builder's EOL counting/default selection and store the chosen model
EOL. TextDefined, LF, and CRLF preferences follow the source read APIs.

### Approved Option B — Coherent LF-only product seam

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
| exact TextDefined/default-EOL semantics | INTENTIONAL DEVIATION: Gate A approved LF-only storage |
| invalid positions clamp instead of throwing | sibling inventory row; do not expand without an explicit decision |

This register is not the parity ledger and does not count toward the
source-member denominator.

## Inventory and Parity Ledger (Phases 1–2)

One row represents one declared member/property, behavior-changing branch or
early return, independently reused constant, or source-test case explicitly
required by this plan. Straight-line assignments stay on their owning member
row. Every row remains `TODO`; the proposed terminal is only a Gate B review
target and is not implementation evidence.

```text
Builder/factory (EFB + EBB)                    64
PieceTreeTextBuffer readonly unit (ETB)        76
PieceTreeBase dependency closure (PB)         109
model.ts enums/interfaces (MI)                 55
TextModel default/implementation (TMD/TM/TML) 55
content event facts (EV)                       20
provider full-range handoff (PR)                3
                                               ---
Source atoms                                   382
Named upstream test dispositions (REF)         11
                                               ---
Total ledger rows                              393

Working:  393 TODO; 0 PASS
Proposed: 169 TESTED + 27 PORTED + 28 DEFERRED + 169 N-A = 393
```

The source files are byte-pinned at the oracle commit:

| Source | Scoped lines | SHA-256 |
|---|---:|---|
| `pieceTreeTextBufferBuilder.ts` | 13–188 | `311c7c5f89cfd7a24d801370321a2bd30afedd185fba9f49e1bebbffd1c904cf` |
| `pieceTreeTextBuffer.ts` | 34–237 | `cd2a3d450443dd9fbcd073213095dd8a0895976ab7097076c4474e8da7f21c8d` |
| `pieceTreeBase.ts` | listed PB clusters below | `0bd0b699eb456f90c6c45cf61bebdc6e69181806036c537189d7ef83a874b46d` |
| `model.ts` | listed MI clusters below | `b4311925776bcf86418b284beb5c07968de12aa1ef3b6b60ebf506d28e82751a` |
| `textModel.ts` | listed TMD/TM/TML clusters below | `3ccef30b2902046ff93d99b5d9cd03ae2748785e099d123cf519aa5527d0b622` |
| `textModelEvents.ts` | 42–84, 221–235, 457–480 | `fcbcce16a492a431abe1c72f64ed819528095b7e740f49515d10283670943b59` |
| `mirrorTextModel.ts` | 12–29 | `a311bb48313769775d92891b133e845be1fbff9b1ac15663b187fad6bd5bd219` |
| `textModel.test.ts` | named REF cases below | `7ecadd74f5469bc973e1d40b9f4d1b9c7199eaecdd777c9d11bce1a331a55f98` |

### Algebraic contract

Let `N(s)` scan UTF-16 left-to-right, replacing each CRLF pair, lone CR, or LF
with exactly one LF while preserving every other code unit. Leading U+FEFF is
ordinary Viewer content under the existing public contract; `N` does not strip
it. U+2028/U+2029 are also ordinary content, not EOLs.

For every construction and `set_value(s)`:

1. `stored = snapshot.text = getValue() = N(s)` and
   `getLength() = utf16Length(stored)`.
2. `starts[0] = 0`; all remaining starts are exactly `i + 1` for each
   `stored[i] == LF`; `lineCount = starts.length = 1 + countLF(stored)`.
3. For line index `i`,
   `end(i) = starts[i+1]-1` when a next line exists, else `getLength()`;
   `lineLength(i) = end(i)-starts[i]`.
4. For every `0 <= o <= getLength()`, let
   `i = max { j | starts[j] <= o }`. Then
   `getPositionAt(o) = (i+1, o-starts[i]+1)` and
   `getOffsetAt(getPositionAt(o)) = o`, including relaxed offsets inside a
   surrogate pair.
5. For every validated range `r`,
   `getValueLengthInRange(r) = utf16Length(getValueInRange(r)) =
   getOffsetAt(r.end)-getOffsetAt(r.start)`.
6. `getOffsetAt(getFullModelRange().end) = getValueLength()` and a model-wide
   provider request receives exactly `[0, getValueLength())`.
7. A `set_value` public change carries the old full range, `rangeOffset = 0`,
   `rangeLength = oldValueLength = oldEndOffset`, `text = N(newInput)`,
   `eol = "\n"`, `isFlush = true`, and `isEolChange = false`.
8. `TextSnapshot(a).equals(TextSnapshot(b))` iff `N(a) == N(b)`; because U+FEFF
   remains content, it participates in equality.

### Fixed sibling boundaries

- Complete `_emitContentChangedEvent` control flow, internal wrapper delivery,
  and token-part notification remain tokenization-owned. This child owns only
  the payload facts passed into that member.
- Incremental edits, setEOL, undo/redo, search, mutable piece-tree operations,
  unusual-terminator removal, and piece-tree caches are excluded complete
  sibling clusters.
- `validatePosition`/`validateRange` and their established clamped readonly
  contract are consumed but not re-denominated.
- `DocumentSnapshot` stays raw at the provider boundary; normalization begins
  when its text enters `TextSnapshot`/`TextModel`.
- BOM metadata, stripping, `getBOM`, and `preserveBOM` switches are not silently
  claimed as parity: their rows are DEFERRED because the existing public
  Viewer/workbench contract retains U+FEFF as ordinary content.

Review gate: commit this 393-row documentation-only inventory and stop for
fresh independent Gate B review before any product or test edit.

### Builder/factory — EFB and EBB

| ID | Source atom | Local target / current gap | Status | Proposed terminal |
|---|---|---|---|---|
| EFB-001 | factory `_chunks` capture (`builder.ts:13-16`) | Whole-string snapshot has no chunk carrier. | TODO | N-A (whole-string seam) |
| EFB-002 | factory `_bom` metadata (`:17`) | Viewer retains U+FEFF as content and has no separate BOM metadata. | TODO | DEFERRED (existing public BOM contract) |
| EFB-003 | `_cr` counter (`:18`) | No EOL selection counters. | TODO | N-A (Option B fixed LF) |
| EFB-004 | `_lf` counter (`:19`) | No EOL selection counters. | TODO | N-A (Option B fixed LF) |
| EFB-005 | `_crlf` counter (`:20`) | No EOL selection counters. | TODO | N-A (Option B fixed LF) |
| EFB-006 | `_containsRTL` fact (`:21`) | Local recomputes the observable answer. | TODO | TESTED |
| EFB-007 | `_containsUnusualLineTerminators` fact (`:22`) | Metadata surface absent; U+2028/U+2029 remain content. | TODO | N-A (metadata surface absent) |
| EFB-008 | `_isBasicASCII` fact (`:23`) | Local observable answer is computed rather than cached. | TODO | N-A (cache carrier absent) |
| EFB-009 | `_normalizeEOL` flag (`:24`) | Normalization is mandatory; no false lane. | TODO | N-A (Option B fixed LF) |
| EFB-010 | `_getEOL` total EOL count (`:27-28`) | Raw-EOL majority counting is absent. | TODO | N-A (Option B fixed LF) |
| EFB-011 | `_getEOL` total CR count (`:29`) | Raw-EOL majority counting is absent. | TODO | N-A (Option B fixed LF) |
| EFB-012 | zero-EOL default LF/CRLF branch (`:30-33`) | Viewer always chooses LF. | TODO | N-A (Option B drops default preference) |
| EFB-013 | strict CR-majority `> half` selects CRLF (`:34-37`) | Majority/tie choice is intentionally absent. | TODO | N-A (Option B fixed LF) |
| EFB-014 | fallback LF (`:38-39`) | Fixed LF outcome remains. | TODO | TESTED |
| EFB-015 | `create` derives EOL/chunks aliases (`:42-44`) | No factory object. | TODO | N-A (flat snapshot seam) |
| EFB-016 | normalization master guard (`:46`) | Mandatory normalization must run before publication. | TODO | TESTED |
| EFB-017 | CRLF-selected normalization condition (`:47`) | No CRLF model EOL. | TODO | N-A (Option B fixed LF) |
| EFB-018 | LF-selected raw CR/CRLF condition (`:48`) | Current storage remains raw; normalize it before line starts. | TODO | TESTED |
| EFB-019 | per-chunk normalization loop (`:51`) | Single input String has no chunk loop. | TODO | N-A (whole-string seam) |
| EFB-020 | `/\r\n|\r|\n/g` replacement (`:52`) | Port the observable replacement to LF. | TODO | TESTED |
| EFB-021 | recompute line starts after replacement (`:53-55`) | Current starts are raw-coordinate offsets. | TODO | TESTED |
| EFB-022 | construct buffer with text/EOL/metadata facts (`:58`) | Flat normalized snapshot is the representation seam. | TODO | PORTED |
| EFB-023 | buffer is also returned disposable (`:59`) | GC snapshot has no disposal. | TODO | N-A (lifecycle seam absent) |
| EFB-024 | `getFirstLineText` limit/split/first (`:62-64`) | No streaming-factory first-line API or consumer. | TODO | N-A (factory helper absent) |
| EBB-001 | `chunks` declaration/init (`:68,83`) | No chunk builder. | TODO | N-A (whole-string seam) |
| EBB-002 | builder `BOM` state/init (`:69,84`) | U+FEFF stays content; no separate metadata. | TODO | DEFERRED (existing public BOM contract) |
| EBB-003 | `_hasPreviousChar=false` (`:71,86`) | No streaming holdback state. | TODO | N-A (streaming absent) |
| EBB-004 | `_previousChar=0` (`:72,87`) | No streaming holdback state. | TODO | N-A (streaming absent) |
| EBB-005 | `_tmpLineStarts=[]` (`:73,88`) | One immutable scan owns a fresh array. | TODO | N-A (whole-string seam) |
| EBB-006 | `cr=0` (`:75,90`) | No majority counter. | TODO | N-A (Option B fixed LF) |
| EBB-007 | `lf=0` (`:76,91`) | No majority counter. | TODO | N-A (Option B fixed LF) |
| EBB-008 | `crlf=0` (`:77,92`) | No majority counter. | TODO | N-A (Option B fixed LF) |
| EBB-009 | `containsRTL=false` cache (`:78,93`) | Observable result is recomputed. | TODO | N-A (cache absent) |
| EBB-010 | unusual-terminator cache (`:79,94`) | Metadata API absent. | TODO | N-A (metadata surface absent) |
| EBB-011 | `isBasicASCII=true` cache (`:80,95`) | Observable result is recomputed. | TODO | N-A (cache absent) |
| EBB-012 | constructor initializes full builder state (`:82-96`) | No builder object. | TODO | N-A (whole-string seam) |
| EBB-013 | empty accepted chunk early return (`:98-101`) | Empty document still has one logical line. | TODO | TESTED |
| EBB-014 | first accepted chunk gate (`:103`) | Single input String. | TODO | N-A (streaming absent) |
| EBB-015 | first-chunk BOM detect/store/strip (`:104-107`) | Existing public/workbench behavior retains leading U+FEFF as content. | TODO | DEFERRED (existing public BOM contract) |
| EBB-016 | last UTF-16 unit extraction (`:110`) | Whole-string scan preserves the same code-unit basis. | TODO | PORTED |
| EBB-017 | trailing CR holdback discriminator (`:111`) | Mechanism is streaming-only; trailing CR outcome is tested. | TODO | N-A (streaming absent) |
| EBB-018 | high-surrogate range `0xD800..0xDBFF` (`:111`) | Chunk-boundary holdback is absent. | TODO | N-A (streaming absent) |
| EBB-019 | accept prefix and retain last unit (`:112-115`) | No cross-chunk state. | TODO | N-A (streaming absent) |
| EBB-020 | normal accept/clear/remember branch (`:116-120`) | No cross-chunk state. | TODO | N-A (streaming absent) |
| EBB-021 | `_acceptChunk1` empty/allow-empty gate (`:123-127`) | No helper; empty outcome is tested. | TODO | N-A (whole-string seam) |
| EBB-022 | prepend pending unit (`:129-131`) | No cross-chunk state. | TODO | N-A (streaming absent) |
| EBB-023 | direct `_acceptChunk2` branch (`:131-133`) | Whole input goes directly to construction. | TODO | PORTED |
| EBB-024 | create line starts then push StringBuffer (`:136-139`) | Scan normalized text, not raw text. | TODO | TESTED |
| EBB-025 | accumulate CR count (`:140`) | No majority counter. | TODO | N-A (Option B fixed LF) |
| EBB-026 | accumulate LF count (`:141`) | No majority counter. | TODO | N-A (Option B fixed LF) |
| EBB-027 | accumulate CRLF count (`:142`) | No majority counter. | TODO | N-A (Option B fixed LF) |
| EBB-028 | non-basic-ASCII branch (`:144`) | Unicode content and coordinates remain supported. | TODO | TESTED |
| EBB-029 | cache `isBasicASCII=false` (`:146`) | Local answer is computed, not cached. | TODO | N-A (cache absent) |
| EBB-030 | lazy RTL guard/detection (`:147-149`) | Observable true/false/reset behavior is retained by recomputation. | TODO | TESTED |
| EBB-031 | lazy unusual-terminator detection (`:150-152`) | Metadata API absent. | TODO | N-A (metadata surface absent) |
| EBB-032 | `finish(normalizeEOL=true)` default (`:156`) | Mandatory fixed-LF normalization. | TODO | TESTED |
| EBB-033 | `_finish` before factory capture (`:157`) | Normalize and derive starts before publishing snapshot facts. | TODO | TESTED |
| EBB-034 | factory captures complete builder facts (`:158-168`) | Flat snapshot retains text/starts; omitted facts have row-local outcomes. | TODO | PORTED |
| EBB-035 | no chunks creates one empty buffer (`:171-174`) | Empty snapshot has starts `[0]`. | TODO | TESTED |
| EBB-036 | pending-char branch clears flag (`:176-177`) | No streaming state. | TODO | N-A (streaming absent) |
| EBB-037 | append pending unit and recompute starts (`:178-182`) | Test trailing CR/high-surrogate observable outcome on final normalized text. | TODO | TESTED |
| EBB-038 | pending CR increments counter (`:183-185`) | No EOL selection count; trailing CR line outcome is tested elsewhere. | TODO | N-A (Option B fixed LF) |
| EBB-039 | prior last-chunk invariant (`:179`) | No chunk array invariant. | TODO | N-A (whole-string seam) |
| EBB-040 | recompute last chunk starts, not incremental patch (`:181`) | Derive all starts from final normalized text. | TODO | TESTED |

Proposed EFB/EBB totals: 15 TESTED / 4 PORTED / 3 DEFERRED /
42 N-A = 64.

### PieceTreeTextBuffer readonly unit — ETB

| ID | Source atom | Local target / current gap | Status | Proposed terminal |
|---|---|---|---|---|
| ETB-001 | `_pieceTree` field (`pieceTreeTextBuffer.ts:35`) | Flat snapshot has no tree. | TODO | N-A (representation seam) |
| ETB-002 | readonly `_BOM` field (`:36`) | U+FEFF remains ordinary content. | TODO | DEFERRED (existing public BOM contract) |
| ETB-003 | `_mightContainRTL` cache (`:37`) | Local answer is recomputed. | TODO | N-A (cache absent) |
| ETB-004 | unusual-terminator cache (`:38`) | Metadata API absent. | TODO | N-A (metadata surface absent) |
| ETB-005 | non-basic-ASCII cache (`:39`) | Local answer is recomputed. | TODO | N-A (cache absent) |
| ETB-006 | constructor/Disposable `super` (`:44-45`) | Immutable snapshot has no disposal. | TODO | N-A (lifecycle seam absent) |
| ETB-007 | constructor stores BOM separately (`:46`) | Viewer does not separate it. | TODO | DEFERRED (existing public BOM contract) |
| ETB-008 | invert `isBasicASCII` into might-contain flag (`:47`) | Computed getter replaces cached inversion. | TODO | N-A (cache absent) |
| ETB-009 | retain RTL/unusual flags (`:48-49`) | Computed/absent metadata seams. | TODO | N-A (cache absent) |
| ETB-010 | construct PieceTreeBase (`:50`) | Normalized text+starts is the flat carrier. | TODO | PORTED |
| ETB-011 | heterogeneous `equals` false branch (`:54-57`) | Statically typed TextSnapshot equality has no heterogeneous arm. | TODO | N-A (typed buffer seam) |
| ETB-012 | BOM mismatch false (`:58-60`) | BOM is ordinary content, not metadata. | TODO | DEFERRED (existing public BOM contract) |
| ETB-013 | EOL mismatch false (`:61-63`) | Every local snapshot has fixed LF. | TODO | N-A (Option B fixed LF) |
| ETB-014 | content equality fallback (`:64`) | Equality must compare normalized content. | TODO | TESTED |
| ETB-015 | `mightContainRTL` getter (`:66-68`) | Recomputed observable result. | TODO | TESTED |
| ETB-016 | unusual-terminator getter (`:69-71`) | API absent; separators remain content. | TODO | N-A (metadata surface absent) |
| ETB-017 | `mightContainNonBasicASCII` getter (`:75-77`) | Add computed local read and source fixtures. | TODO | TESTED |
| ETB-018 | `getBOM` (`:78-80`) | No independent BOM metadata/API. | TODO | DEFERRED (existing public BOM contract) |
| ETB-019 | `getEOL` delegates buffer (`:81-83`) | Add fixed `"\n"` read. | TODO | TESTED |
| ETB-020 | `createSnapshot(preserveBOM)` ternary (`:85-86`) | No preserve switch; BOM remains content. | TODO | DEFERRED (existing public BOM contract) |
| ETB-021 | delegate to streaming piece-tree snapshot (`:86`) | TextSnapshot is immutable but not a streaming reader. | TODO | N-A (streaming snapshot absent) |
| ETB-022 | `getOffsetAt` delegate (`:89-91`) | Must use normalized starts. | TODO | TESTED |
| ETB-023 | `getPositionAt` delegate (`:93-95`) | Must use normalized length/starts. | TODO | TESTED |
| ETB-024 | `getRangeAt` computes `end=start+length` (`:97-98`) | Local offset-range helper must preserve this arithmetic. | TODO | TESTED |
| ETB-025 | convert start then end through `getPositionAt` (`:99-100`) | Equivalent helper exists; test order/results. | TODO | TESTED |
| ETB-026 | construct Range from positions (`:101`) | Equivalent range helper exists. | TODO | TESTED |
| ETB-027 | range value default `TextDefined` (`:104`) | Preference parameter absent. | TODO | N-A (Option B fixed LF) |
| ETB-028 | empty range returns empty string (`:105-107`) | Existing early outcome. | TODO | TESTED |
| ETB-029 | resolve requested line ending (`:109`) | Fixed LF replaces preference lookup. | TODO | PORTED |
| ETB-030 | delegate range plus line ending (`:110`) | Current read normalizes late; storage/columns must first become coherent. | TODO | TESTED |
| ETB-031 | range length default `TextDefined` (`:113`) | Preference parameter absent. | TODO | N-A (Option B fixed LF) |
| ETB-032 | empty range length returns 0 (`:114-116`) | Existing outcome. | TODO | TESTED |
| ETB-033 | same-line length is endColumn-startColumn (`:118-120`) | Current materialization is equivalent; pin UTF-16 cases. | TODO | TESTED |
| ETB-034 | multiline start offset (`:122`) | Raw-coordinate bug today. | TODO | TESTED |
| ETB-035 | multiline end offset (`:123`) | Raw-coordinate bug today. | TODO | TESTED |
| ETB-036 | initialize EOL compensation to 0 (`:127`) | Fixed-LF formula eliminates variable compensation. | TODO | PORTED |
| ETB-037 | desired versus actual EOL lookup (`:128-129`) | No selector/model-EOL distinction. | TODO | N-A (Option B fixed LF) |
| ETB-038 | EOL-length mismatch branch (`:130`) | CRLF preference lane absent. | TODO | N-A (Option B fixed LF) |
| ETB-039 | `delta=desired.length-actual.length` (`:131`) | No mismatch lane. | TODO | N-A (Option B fixed LF) |
| ETB-040 | `eolCount=endLine-startLine` (`:132`) | Used only for preference compensation. | TODO | N-A (Option B fixed LF) |
| ETB-041 | compensation `delta*eolCount` (`:133`) | No mismatch lane. | TODO | N-A (Option B fixed LF) |
| ETB-042 | final offset difference plus compensation (`:136`) | Fixed-LF offset difference must equal returned value length. | TODO | TESTED |
| ETB-043 | character-count default EOL (`:139`) | Unicode-scalar count API absent; UTF-16 length is authoritative. | TODO | N-A (reduced read API) |
| ETB-044 | non-basic-ASCII discriminator (`:140`) | Character-count API absent. | TODO | N-A (reduced read API) |
| ETB-045 | character-count accumulator 0 (`:143`) | Character-count API absent. | TODO | N-A (reduced read API) |
| ETB-046 | inclusive line loop (`:145-147`) | Character-count API absent. | TODO | N-A (reduced read API) |
| ETB-047 | fetch each line content (`:148`) | Character-count API absent. | TODO | N-A (reduced read API) |
| ETB-048 | first-line offset versus 0 (`:149`) | Character-count API absent. | TODO | N-A (reduced read API) |
| ETB-049 | last-line offset versus line length (`:150`) | Character-count API absent. | TODO | N-A (reduced read API) |
| ETB-050 | inner UTF-16 loop (`:152`) | Character-count API absent. | TODO | N-A (reduced read API) |
| ETB-051 | high-surrogate counts one and skips next (`:153-155`) | Character-count API absent. | TODO | N-A (reduced read API) |
| ETB-052 | ordinary code unit counts one (`:156-158`) | Character-count API absent. | TODO | N-A (reduced read API) |
| ETB-053 | add EOL length times line span (`:162`) | Character-count API absent. | TODO | N-A (reduced read API) |
| ETB-054 | return iterative character count (`:164`) | Character-count API absent. | TODO | N-A (reduced read API) |
| ETB-055 | basic-ASCII fallback to value length (`:167`) | Character-count API absent. | TODO | N-A (reduced read API) |
| ETB-056 | `getNearestChunk` delegate (`:170-172`) | No chunks/background consumer. | TODO | N-A (flat snapshot seam) |
| ETB-057 | `getLength` (`:174-176`) | Must become normalized UTF-16 length. | TODO | TESTED |
| ETB-058 | `getLineCount` (`:178-180`) | Existing normalized-start count. | TODO | TESTED |
| ETB-059 | `getLinesContent` (`:182-184`) | Existing array read over normalized storage. | TODO | TESTED |
| ETB-060 | `getLineContent` (`:186-188`) | Existing EOL-excluding read. | TODO | TESTED |
| ETB-061 | `getLineCharCode` (`:190-192`; base `:631-653`) | Current helper panics at nonfinal EOL index and final EOF; source returns LF and 0 respectively. | TODO | TESTED |
| ETB-062 | `getCharCode(offset)` (`:194-196`) | No public local consumer. | TODO | N-A (reduced read API) |
| ETB-063 | `getLineLength` (`:198-200`) | Existing read must use normalized coordinates. | TODO | TESTED |
| ETB-064 | `getLineMinColumn` exact 1 (`:202-204`) | Existing model seam. | TODO | TESTED |
| ETB-065 | `getLineMaxColumn = length+1` (`:206-208`) | Existing model seam. | TODO | TESTED |
| ETB-066 | first-non-whitespace helper result (`:210-211`) | Existing source-derived path. | TODO | TESTED |
| ETB-067 | first result `-1` returns 0 (`:212-214`) | Existing branch. | TODO | TESTED |
| ETB-068 | first result otherwise `+1` (`:215`) | Existing branch. | TODO | TESTED |
| ETB-069 | last-non-whitespace helper result (`:218-219`) | Existing source-derived path. | TODO | TESTED |
| ETB-070 | last result `-1` returns 0 (`:220-222`) | Existing branch. | TODO | TESTED |
| ETB-071 | last result otherwise `+2` (`:223`) | Existing branch. | TODO | TESTED |
| ETB-072 | `_getEndOfLine` exhaustive switch (`:226-227`) | Preference switch absent. | TODO | N-A (Option B fixed LF) |
| ETB-073 | LF case returns `"\n"` (`:228-229`) | Fixed-LF contract. | TODO | TESTED |
| ETB-074 | CRLF case returns `"\r\n"` (`:230-231`) | Preference lane absent. | TODO | N-A (Option B fixed LF) |
| ETB-075 | TextDefined delegates `getEOL` (`:232-233`) | Model-EOL selector absent. | TODO | N-A (Option B fixed LF) |
| ETB-076 | unknown preference throws (`:234-235`) | No enum/unknown input. | TODO | N-A (typed API seam) |

Proposed ETB totals: 31 TESTED / 3 PORTED / 5 DEFERRED / 37 N-A = 76.

Excluded complete siblings: edit-operation interfaces (`:16-32`), content
emitter/reset (`:41-42,72-74`), setEOL (`:239-241`), applyEdits and inverse-edit
helpers (`:243-518,532-627`), search (`:520-522`), and the test-only piece-tree
escape hatch (`:527-530`).

### PieceTreeBase dependency closure — PB

Scoped lines are `16-99,116-151,268-318,355-357,395-457,605-611,
656-662,1073-1156,1325-1372`. Tree/search/edit siblings outside this closure
are excluded.

| ID | Source atom | Local target / current gap | Status | Proposed terminal |
|---|---|---|---|---|
| PB-001 | `createUintArray` copies starts into typed array (`pieceTreeBase.ts:16-25`) | MoonBit retains `Array[Int]`. | TODO | N-A (MoonBit collection seam) |
| PB-002 | last start `<65536` selects Uint16 (`:18-19`) | No typed-width specialization. | TODO | N-A (MoonBit collection seam) |
| PB-003 | otherwise Uint32 and `set(arr,0)` (`:20-24`) | No typed-width/copy branch. | TODO | N-A (MoonBit collection seam) |
| PB-004 | `LineStarts.lineStarts` (`:27-30`) | Local normalized `line_starts`. | TODO | TESTED |
| PB-005 | `LineStarts.cr` (`:30`) | No raw-EOL majority counter. | TODO | N-A (Option B fixed LF) |
| PB-006 | `LineStarts.lf` (`:31`) | Fixed LF needs no majority counter. | TODO | N-A (Option B fixed LF) |
| PB-007 | `LineStarts.crlf` (`:32`) | No raw-EOL majority counter. | TODO | N-A (Option B fixed LF) |
| PB-008 | `LineStarts.isBasicASCII` (`:33`) | Add computed observable metadata over normalized text. | TODO | TESTED |
| PB-009 | `createLineStartsFast` seeds `[0]` (`:37-39`) | Existing starts seed must follow normalization. | TODO | TESTED |
| PB-010 | UTF-16 code-unit scan (`:41-42`) | MoonBit String length/index use the same basis. | TODO | TESTED |
| PB-011 | CRLF records `i+2` and skips LF (`:44-48`) | Normalizer consumes pair once, then LF scan records normalized boundary. | TODO | TESTED |
| PB-012 | lone CR records `i+1` (`:49-52`) | Normalizer maps it to one LF. | TODO | TESTED |
| PB-013 | LF records `i+1` (`:53-55`) | Direct fixed-LF path. | TODO | TESTED |
| PB-014 | all other units create no start (`:41-56`) | Preserve U+2028/U+2029 and all ordinary content. | TODO | TESTED |
| PB-015 | readonly true returns typed copy (`:57-58`) | Immutable Array has no typed copy. | TODO | N-A (MoonBit collection seam) |
| PB-016 | readonly false returns mutable array (`:59-60`) | Edit/change-buffer lane excluded. | TODO | N-A (excluded edit lane) |
| PB-017 | `createLineStarts` clears/seeds and initializes counters/ASCII (`:64-70`) | One LF normalizer/starts/metadata construction replaces it. | TODO | PORTED |
| PB-018 | second UTF-16 scan (`:70-71`) | Same coordinate basis. | TODO | TESTED |
| PB-019 | CRLF start/skip (`:73-78`) | Recognize at normalization seam. | TODO | TESTED |
| PB-020 | `crlf++` (`:76`) | No majority counter. | TODO | N-A (Option B fixed LF) |
| PB-021 | lone-CR boundary (`:79-83`) | Normalize to one LF. | TODO | TESTED |
| PB-022 | `cr++` (`:80`) | No majority counter. | TODO | N-A (Option B fixed LF) |
| PB-023 | LF boundary (`:84-86`) | Preserve directly. | TODO | TESTED |
| PB-024 | `lf++` (`:85`) | No majority counter. | TODO | N-A (Option B fixed LF) |
| PB-025 | only non-EOL units enter ASCII guard (`:87-92`) | Metadata scan must preserve this classification. | TODO | TESTED |
| PB-026 | Tab and printable 32..126 stay basic (`:89`) | Preserve exact constants. | TODO | TESTED |
| PB-027 | any other unit flips basic false once (`:88-91`) | Cover BMP, surrogate, controls, and RTL. | TODO | TESTED |
| PB-028 | result carries starts/counters/ASCII (`:95`) | Starts/ASCII retained; counters have row-local N-A outcomes. | TODO | PORTED |
| PB-029 | scratch array clear before return (`:96-98`) | No caller-owned scratch buffer. | TODO | N-A (immutable construction seam) |
| PB-030 | `BufferCursor.line` (`:116-121`) | No piece-local cursor. | TODO | N-A (single-buffer seam) |
| PB-031 | `BufferCursor.column` (`:122-124`) | No piece-local cursor. | TODO | N-A (single-buffer seam) |
| PB-032 | `Piece.bufferIndex` (`:127-128`) | No piece tree. | TODO | N-A (single-buffer seam) |
| PB-033 | `Piece.start` (`:129`) | No piece tree. | TODO | N-A (single-buffer seam) |
| PB-034 | `Piece.end` (`:130`) | No piece tree. | TODO | N-A (single-buffer seam) |
| PB-035 | `Piece.length` (`:131`) | Whole normalized length replaces it. | TODO | N-A (single-buffer seam) |
| PB-036 | `Piece.lineFeedCnt` (`:132`) | Whole normalized starts count replaces it. | TODO | N-A (single-buffer seam) |
| PB-037 | Piece constructor retains five facts (`:134-140`) | No piece allocation. | TODO | N-A (single-buffer seam) |
| PB-038 | `StringBuffer.buffer` (`:143-144`) | Local normalized `TextSnapshot.text`. | TODO | TESTED |
| PB-039 | `StringBuffer.lineStarts` (`:145`) | Local normalized-coordinate starts. | TODO | TESTED |
| PB-040 | StringBuffer constructor couples text/starts (`:147-150`) | Snapshot constructor must derive both from one representation. | TODO | TESTED |
| PB-041 | `PieceTreeBase.root` (`:268-269`) | No RB tree. | TODO | N-A (single-buffer seam) |
| PB-042 | `_buffers` (`:270`) | One immutable text/starts pair. | TODO | N-A (single-buffer seam) |
| PB-043 | `_lineCnt` (`:271`) | Derived from normalized starts. | TODO | TESTED |
| PB-044 | `_length` (`:272`) | Normalized LF UTF-16 length. | TODO | TESTED |
| PB-045 | `_EOL` (`:273`) | Fixed LF. | TODO | TESTED |
| PB-046 | `_EOLLength` (`:274`) | Fixed 1. | TODO | TESTED |
| PB-047 | `_EOLNormalized` (`:275`) | Always true before publication. | TODO | TESTED |
| PB-048 | constructor delegates complete create (`:280-282`) | Normalize before publishing facts. | TODO | TESTED |
| PB-049 | create seeds empty root/line/length/EOL (`:284-295`) | Empty normalized snapshot is one line length 0. | TODO | TESTED |
| PB-050 | chunk loop ignores empty chunks (`:296-299`) | Empty whole input remains one line. | TODO | TESTED |
| PB-051 | absent starts invokes fast builder (`:299-301`) | Always derive starts after normalization. | TODO | TESTED |
| PB-052 | nonempty chunk derives Piece and inserts tree (`:303-312`) | Tree topology absent; whole facts covered separately. | TODO | N-A (single-buffer seam) |
| PB-053 | initialize caches then compute metadata (`:315-317`) | Direct immutable facts; topology caches absent. | TODO | N-A (single-buffer seam) |
| PB-054 | `getEOL` returns `_EOL` (`:355-357`) | Fixed LF read. | TODO | TESTED |
| PB-055 | `getLength` returns `_length` (`:605-607`) | Normalized UTF-16 length. | TODO | TESTED |
| PB-056 | `getLineCount` returns `_lineCnt` (`:609-611`) | Normalized starts count, trailing empty included. | TODO | TESTED |
| PB-057 | `getOffsetAt` initializes accumulation/traversal (`:395-400`) | Observable mapping uses normalized starts. | TODO | TESTED |
| PB-058 | left-subtree line branch (`:401-402`) | No RB topology. | TODO | N-A (single-buffer seam) |
| PB-059 | containing-piece `size_left + accumulated + column-1` (`:403-407`) | Preserve exact 1-based arithmetic globally. | TODO | TESTED |
| PB-060 | right-subtree subtract/add branch (`:408-412`) | No RB topology. | TODO | N-A (single-buffer seam) |
| PB-061 | sentinel fallthrough returns accumulated length (`:413-415`) | Public validation maps high position to normalized document end. | TODO | PORTED |
| PB-062 | `getPositionAt` member/loop returns 1-based position (`:418-457`) | Normalized array lookup preserves result. | TODO | TESTED |
| PB-063 | `Math.floor(offset)` (`:419`) | MoonBit offset is Int. | TODO | N-A (typed input seam) |
| PB-064 | `Math.max(0,offset)` (`:420`) | Preserve negative clamp. | TODO | TESTED |
| PB-065 | left-subtree size branch (`:426-429`) | No RB topology. | TODO | N-A (single-buffer seam) |
| PB-066 | containing-piece `getIndexOf` branch (`:429-432`) | Global line lookup is the structural seam. | TODO | PORTED |
| PB-067 | index-zero recomputes global start/column (`:434-438`) | Preserve exact boundary arithmetic. | TODO | TESTED |
| PB-068 | nonzero index returns remainder+1 (`:440`) | Preserve interior column arithmetic. | TODO | TESTED |
| PB-069 | right branch subtracts size/accumulates feeds (`:441-444`) | No RB topology. | TODO | N-A (single-buffer seam) |
| PB-070 | last-node high-offset clamp (`:445-449`) | Preserve clamp to final normalized position. | TODO | TESTED |
| PB-071 | non-last right traversal (`:450-452`) | No RB topology. | TODO | N-A (single-buffer seam) |
| PB-072 | empty-tree `Position(1,1)` (`:454-456`) | Empty snapshot result. | TODO | TESTED |
| PB-073 | `getLineLength` member (`:656-662`) | Derive from normalized representation, EOL excluded. | TODO | TESTED |
| PB-074 | last line is length minus start (`:657-660`) | Preserve final/trailing-empty behavior. | TODO | TESTED |
| PB-075 | non-last nextStart-currentStart-EOLLength (`:661`) | Preserve with fixed EOL length 1. | TODO | TESTED |
| PB-076 | `positionInBuffer` overloads/member (`:1073-1075`) | No piece-local cursor/sink overload. | TODO | N-A (single-buffer seam) |
| PB-077 | piece start offset plus remainder (`:1076-1082`) | No piece-local offset. | TODO | N-A (single-buffer seam) |
| PB-078 | binary-search piece line bounds (`:1084-1090`) | One global starts array. | TODO | N-A (single-buffer seam) |
| PB-079 | ToInt32/floor midpoint (`:1092-1094`) | Piece search absent. | TODO | N-A (single-buffer seam) |
| PB-080 | `mid===high` early break (`:1096-1098`) | Piece search absent. | TODO | N-A (single-buffer seam) |
| PB-081 | offset before mid moves high (`:1102-1103`) | Piece search absent. | TODO | N-A (single-buffer seam) |
| PB-082 | offset at/after stop moves low (`:1104-1105`) | Global lookup still selects later line at exact starts. | TODO | PORTED |
| PB-083 | containing interval breaks (`:1106-1108`) | Global containment is equivalent. | TODO | PORTED |
| PB-084 | sink cursor mutation returns null (`:1111-1115`) | No sink overload. | TODO | N-A (typed API seam) |
| PB-085 | otherwise allocate cursor (`:1117-1120`) | Folded into public Position. | TODO | N-A (single-buffer seam) |
| PB-086 | `getLineFeedCnt` member/CRLF-interior contract (`:1123-1125`) | Raw CRLF interiors cannot exist. | TODO | N-A (Option B fixed LF) |
| PB-087 | end column zero returns line delta (`:1126-1128`) | Piece cursor absent. | TODO | N-A (single-buffer seam) |
| PB-088 | final buffer line returns line delta (`:1130-1133`) | Piece cursor absent. | TODO | N-A (single-buffer seam) |
| PB-089 | next start > end+1 returns line delta (`:1135-1139`) | Piece cursor absent. | TODO | N-A (single-buffer seam) |
| PB-090 | previous CR identifies CRLF interior/adds one (`:1140-1147`) | Pair already normalized to LF. | TODO | N-A (Option B fixed LF) |
| PB-091 | non-CR predecessor returns ordinary delta (`:1148-1150`) | Piece cursor absent. | TODO | N-A (single-buffer seam) |
| PB-092 | `offsetInBuffer = start+column` (`:1153-1156`) | Global arithmetic is covered by PB-059. | TODO | N-A (single-buffer seam) |
| PB-093 | `computeBufferMetadata` member (`:1325-1340`) | No tree pass; derive facts directly. | TODO | N-A (single-buffer seam) |
| PB-094 | initial line count 1/length 0 (`:1328-1329`) | Preserve empty invariant. | TODO | TESTED |
| PB-095 | right-spine metadata accumulation (`:1331-1335`) | No RB topology. | TODO | N-A (single-buffer seam) |
| PB-096 | assign count/length and validate cache (`:1337-1339`) | Direct fields; observable assignments retained. | TODO | PORTED |
| PB-097 | `getIndexOf` member (`:1343-1358`) | Normalized line lookup substitutes. | TODO | N-A (single-buffer seam) |
| PB-098 | derive piece-relative line count (`:1344-1346`) | No piece-relative coordinates. | TODO | N-A (single-buffer seam) |
| PB-099 | exact node-end triggers real-LF check (`:1348-1351`) | No node boundary. | TODO | N-A (single-buffer seam) |
| PB-100 | CRLF mismatch returns index/remainder zero (`:1351-1354`) | Raw CRLF/node interior absent. | TODO | N-A (Option B fixed LF) |
| PB-101 | default returns line count/column remainder (`:1357`) | Observable mapping covered by PB-067/068. | TODO | PORTED |
| PB-102 | `getAccumulatedValue` member (`:1360-1372`) | Global starts substitute. | TODO | N-A (single-buffer seam) |
| PB-103 | negative index returns 0 (`:1361-1363`) | Piece convention absent. | TODO | N-A (single-buffer seam) |
| PB-104 | start past piece end returns remaining length (`:1364-1369`) | No piece end. | TODO | N-A (single-buffer seam) |
| PB-105 | in-piece relative next-line start (`:1370`) | Global start difference preserves observable arithmetic. | TODO | PORTED |
| PB-106 | LineStarts constructor retains five fields (`:27-34`) | Normalized construction retains starts/ASCII behavior, not EOL counters. | TODO | PORTED |
| PB-107 | `_lastChangeBufferPos` field/init (`:276,288`) | Edit-only cursor. | TODO | N-A (excluded edit lane) |
| PB-108 | `_searchCache` field/init/validation (`:277,315,1339`) | Tree search cache absent. | TODO | N-A (single-buffer seam) |
| PB-109 | `_lastVisitedLine` field/init (`:278,316`) | Line-content cache optimization absent. | TODO | N-A (cache seam) |

Proposed PB totals: 42 TESTED / 10 PORTED / 57 N-A = 109.

`PieceTreeSearchCache` (`:199-266`) is the complete excluded topology-cache
cluster represented by PB-108. normalizeEOL/setEOL, edits, nodeAt/search, and
CRLF mutation helpers remain excluded siblings.

### model.ts enums and interfaces — MI

| ID | Source atom | Local target / current gap | Status | Proposed terminal |
|---|---|---|---|---|
| MI-001 | `EndOfLinePreference.TextDefined=0` (`model.ts:450-454`) | Selector absent; fixed LF is not a TextDefined preference API. | TODO | N-A (Option B intentional deviation) |
| MI-002 | `EndOfLinePreference.LF=1` (`:455-458`) | Sole fixed read behavior without enum exposure. | TODO | PORTED |
| MI-003 | `EndOfLinePreference.CRLF=2` (`:459-462`) | CRLF read preference absent. | TODO | N-A (Option B intentional deviation) |
| MI-004 | `DefaultEndOfLine.LF=1` (`:468-472`) | Fixed construction/storage default. | TODO | PORTED |
| MI-005 | `DefaultEndOfLine.CRLF=2` (`:473-476`) | Caller cannot select CRLF. | TODO | N-A (Option B intentional deviation) |
| MI-006 | `EndOfLineSequence.LF=0` (`:482-486`) | Fixed EOL behavior without enum exposure. | TODO | PORTED |
| MI-007 | `EndOfLineSequence.CRLF=1` (`:487-490`) | CRLF model sequence absent. | TODO | N-A (Option B intentional deviation) |
| MI-008 | `IReadonlyTextBuffer.equals` (`:1526`) | Compare normalized representation. | TODO | TESTED |
| MI-009 | `mightContainRTL` (`:1527`) | Existing computed read. | TODO | TESTED |
| MI-010 | `mightContainUnusualLineTerminators` (`:1528`) | Flag/removal service absent. | TODO | N-A (reduced metadata API) |
| MI-011 | `mightContainNonBasicASCII` (`:1530`) | Add computed read required by source fixtures. | TODO | TESTED |
| MI-012 | `getBOM` (`:1531`) | No metadata API; U+FEFF remains content. | TODO | DEFERRED (existing public BOM contract) |
| MI-013 | `getEOL` (`:1532`) | Add fixed LF read. | TODO | TESTED |
| MI-014 | buffer `getOffsetAt(line,column)` (`:1534`) | Normalize and prove UTF-16/1-based mapping. | TODO | TESTED |
| MI-015 | buffer `getPositionAt(offset)` (`:1535`) | Prove every normalized offset. | TODO | TESTED |
| MI-016 | `getRangeAt(offset,length)` (`:1536`) | Existing offset-range helper must map start and start+length. | TODO | TESTED |
| MI-017 | `getValueInRange(range,eol)` (`:1538`) | Selector removed; fixed LF behavior. | TODO | TESTED |
| MI-018 | `createSnapshot(preserveBOM)` (`:1539`) | No streaming/preserve switch. | TODO | DEFERRED (existing public BOM contract) |
| MI-019 | `getValueLengthInRange(range,eol)` (`:1540`) | Selector removed; length equals fixed-LF value. | TODO | TESTED |
| MI-020 | `getCharacterCountInRange` (`:1541`) | Unicode-scalar count API absent; coordinates are UTF-16. | TODO | N-A (reduced read API) |
| MI-021 | `getLength` (`:1542`) | Normalized LF UTF-16 length. | TODO | TESTED |
| MI-022 | `getLineCount` (`:1543`) | Normalized starts count. | TODO | TESTED |
| MI-023 | `getLinesContent` (`:1544`) | Existing line-array read. | TODO | TESTED |
| MI-024 | `getLineContent` (`:1545`) | Existing EOL-excluding read. | TODO | TESTED |
| MI-025 | `getLineCharCode` (`:1546`) | Private local helper must gain source EOL/EOF semantics. | TODO | TESTED |
| MI-026 | `getCharCode(offset)` (`:1547`) | No offset-level public consumer. | TODO | N-A (reduced read API) |
| MI-027 | `getLineLength` (`:1548`) | Normalized EOL-excluding length. | TODO | TESTED |
| MI-028 | `getLineMinColumn` (`:1549`) | Existing exact 1. | TODO | TESTED |
| MI-029 | `getLineMaxColumn` (`:1550`) | Existing length+1/full-range consumer. | TODO | TESTED |
| MI-030 | first-non-whitespace column (`:1551`) | Existing source-derived path. | TODO | TESTED |
| MI-031 | last-non-whitespace column (`:1552`) | Existing source-derived path. | TODO | TESTED |
| MI-032 | `getNearestChunk` (`:1558`) | Chunk/background consumer absent. | TODO | N-A (flat snapshot seam) |
| MI-033 | `ITextModel.mightContainRTL` (`:736`) | Existing source test surface. | TODO | TESTED |
| MI-034 | `ITextModel.mightContainNonBasicASCII` (`:755`) | Add computed model method. | TODO | TESTED |
| MI-035 | `setValue` String branch (`:785`) | Normalize before swap/events. | TODO | TESTED |
| MI-036 | `setValue` ITextSnapshot branch (`:785`) | Streaming snapshot input absent. | TODO | DEFERRED (existing String-only API) |
| MI-037 | `getValue(eol?,...)` member (`:793`) | Fixed normalized LF, no selector. | TODO | TESTED |
| MI-038 | `getValue(...,preserveBOM?)` (`:789-793`) | No switch; U+FEFF ordinary content. | TODO | DEFERRED (existing public BOM contract) |
| MI-039 | model `createSnapshot(preserveBOM?)` (`:800`) | No streaming/preserve switch. | TODO | DEFERRED (existing public BOM contract) |
| MI-040 | `getValueLength(eol?,...)` (`:805`) | Fixed-LF length equals value length. | TODO | TESTED |
| MI-041 | `getValueLength(...,preserveBOM?)` (`:805`) | No separate BOM metadata/switch. | TODO | DEFERRED (existing public BOM contract) |
| MI-042 | `getValueInRange(range,eol?)` (`:825`) | Fixed-LF range read. | TODO | TESTED |
| MI-043 | `getValueLengthInRange(range,eol?)` (`:832`) | Fixed-LF range length. | TODO | TESTED |
| MI-044 | model `getCharacterCountInRange` (`:838`) | Unicode-scalar count API absent. | TODO | N-A (reduced read API) |
| MI-045 | model `getLineCount` (`:852`) | Normalized line count. | TODO | TESTED |
| MI-046 | model `getLineContent` (`:857`) | Normalized EOL-excluding line. | TODO | TESTED |
| MI-047 | model `getLineLength` (`:868`) | Normalized EOL-excluding length. | TODO | TESTED |
| MI-048 | model `getLinesContent` (`:873`) | Source TextModelData consumer. | TODO | TESTED |
| MI-049 | model `getEOL` (`:879`) | Add fixed LF. | TODO | TESTED |
| MI-050 | model `getEndOfLineSequence` (`:884`) | Add LF-equivalent behavior without exporting enum. | TODO | TESTED |
| MI-051 | model `getLineMinColumn` (`:889`) | Existing 1. | TODO | TESTED |
| MI-052 | model `getLineMaxColumn` (`:894`) | Existing length+1. | TODO | TESTED |
| MI-053 | model `getOffsetAt` (`:943`) | Validated normalized offset. | TODO | TESTED |
| MI-054 | model `getPositionAt` (`:951`) | Normalized position with clamps. | TODO | TESTED |
| MI-055 | model `getFullModelRange` (`:956`) | Must cover the full normalized value. | TODO | TESTED |

Proposed MI totals: 37 TESTED / 3 PORTED / 6 DEFERRED / 9 N-A = 55.

Explicit non-row siblings are unusual-terminator reset, options/version,
buffer escape hatches, dominated-long-lines, injected text, validation/modify,
disposal/large-file/search/word/edit/decorations/tokenization, and
`ITextBuffer.setEOL/applyEdits`.

### TextModel default and implementation — TMD, TM, and TML

| ID | Source atom | Local target / current gap | Status | Proposed terminal |
|---|---|---|---|---|
| TMD-001 | `DEFAULT_CREATION_OPTIONS.defaultEOL = LF` (`textModel.ts:193-203`, fact `:199`) | Fixed Viewer construction matches LF while omitting option selection. | TODO | TESTED |
| TM-EOL-001 | `createTextBufferFactory`: builder/accept/finish (`:59-63`) | Snapshot constructor must normalize before starts. | TODO | TESTED |
| TM-EOL-002 | `createTextBuffer` String discriminant/helper (`:111-114`) | String-only mapping exists but stores raw text. | TODO | TESTED |
| TM-EOL-003 | snapshot/factory alternative branches (`:115-119`) | String-input scope. | TODO | N-A (string-input scope) |
| TM-EOL-004 | `factory.create(defaultEOL)` (`:120`) | Fixed LF ignores configurable default. | TODO | DEFERRED (approved LF-only seam) |
| TM-EOL-005 | constructor installs buffer (`:328-329`) | Installed snapshot must already be normalized. | TODO | TESTED |
| TM-EOL-006 | constructor retains buffer disposable (`:330`) | GC. | TODO | N-A (GC) |
| TM-EOL-007 | constructor reads buffer line count (`:332`) | Tokenization and public count consume normalized lines. | TODO | TESTED |
| TML-001 | constructor computes full TextDefined buffer length (`:333`) | No local large-file/sync/heap consumer; read invariants are owned separately. | TODO | N-A (large-file consumers absent) |
| TM-EOL-008 | large-file optimization/heap branches (`:335-348`) | Large-file flags absent. | TODO | N-A (unported subsystem) |
| TM-EOL-009 | resolved options including defaultEOL (`:350`) | No model EOL options. | TODO | DEFERRED (approved LF-only seam) |
| TM-EOL-010 | sync-limit fact (`:368`) | Sync threshold absent. | TODO | N-A (unported subsystem) |
| TM-EOL-011 | `getOffsetAt` disposed guard (`:770-771`) | Readonly reads survive disposal. | TODO | N-A (existing lifecycle seam) |
| TM-EOL-012 | relaxed position validation (`:772`) | Existing clamp; prove all EOL/UTF-16 boundaries. | TODO | TESTED |
| TM-EOL-013 | buffer offset delegation (`:773`) | Raw starts currently produce wrong normalized offset. | TODO | TESTED |
| TM-EOL-014 | `getPositionAt` disposed guard (`:776-777`) | Readonly reads survive disposal. | TODO | N-A (existing lifecycle seam) |
| TM-EOL-015 | clamp offset to buffer length (`:778`) | Current raw length disagrees with returned value. | TODO | TESTED |
| TM-EOL-016 | buffer position delegation (`:779`) | CRLF interior currently breaks round-trip. | TODO | TESTED |
| TM-EOL-017 | `getValue` disposed guard (`:799-800`) | Readonly reads survive disposal. | TODO | N-A (existing lifecycle seam) |
| TM-EOL-018 | heap-limit throw (`:801-803`) | Heap guard absent. | TODO | N-A (unported subsystem) |
| TM-EOL-019 | full range then `getValueInRange` (`:805-806,:812`) | Local direct snapshot read must adopt source path and one basis. | TODO | TESTED |
| TM-EOL-020 | optional getValue EOL preference (`:799,806`) | Selector absent. | TODO | DEFERRED (approved LF-only seam) |
| TM-EOL-021 | preserveBOM value branch (`:808-810`) | U+FEFF remains ordinary content; no switch. | TODO | DEFERRED (existing public BOM contract) |
| TM-EOL-022 | `getValueLength` disposed guard (`:819-820`) | Readonly reads survive disposal. | TODO | N-A (existing lifecycle seam) |
| TM-EOL-023 | full range then range length (`:821-823,:828`) | Must equal stored/value UTF-16 length. | TODO | TESTED |
| TM-EOL-024 | optional length EOL preference (`:819,822`) | Selector absent. | TODO | DEFERRED (approved LF-only seam) |
| TM-EOL-025 | preserveBOM length branch (`:824-826`) | U+FEFF remains ordinary content; no switch. | TODO | DEFERRED (existing public BOM contract) |
| TM-EOL-026 | range value disposed guard (`:831-832`) | Readonly reads survive disposal. | TODO | N-A (existing lifecycle seam) |
| TM-EOL-027 | validate range then buffer value (`:833`) | Prove CRLF/CR/mixed/trailing and invalid-clamp behavior. | TODO | TESTED |
| TM-EOL-028 | range EOL preference/default (`:831,833`) | Fixed LF. | TODO | DEFERRED (approved LF-only seam) |
| TM-EOL-029 | range-length disposed guard (`:836-837`) | Readonly reads survive disposal. | TODO | N-A (existing lifecycle seam) |
| TM-EOL-030 | validate then buffer range length (`:838`) | Must equal returned range value length. | TODO | TESTED |
| TM-EOL-031 | range-length EOL preference/default (`:836,838`) | Fixed LF. | TODO | DEFERRED (approved LF-only seam) |
| TM-EOL-032 | full-range disposed guard (`:1168-1169`) | Readonly reads survive disposal. | TODO | N-A (existing lifecycle seam) |
| TM-EOL-033 | lineCount plus final max column (`:1170-1171`) | End offset must equal normalized length. | TODO | TESTED |
| TM-EOL-034 | `setValue` disposed guard (`:484-485`) | Existing lifecycle seam permits swap while disposing and suppresses event. | TODO | N-A (existing lifecycle seam) |
| TM-EOL-035 | null/undefined rejection (`:487-489`) | String is non-nullable. | TODO | N-A (type system) |
| TM-EOL-036 | build replacement buffer (`:491`) | Normalize at the same construction point. | TODO | TESTED |
| TM-EOL-037 | ITextSnapshot input (`:484,491`) | Streaming/snapshot input absent. | TODO | N-A (String-only API) |
| TM-EOL-038 | use current defaultEOL (`:491`) | Fixed LF. | TODO | DEFERRED (approved LF-only seam) |
| TM-EOL-039 | build-before-delegate order (`:491-492`) | Preserve and test EOL transition matrix. | TODO | TESTED |
| TM-EOL-040 | `_createContentChanged2` accepts unused end position (`:495`) | Local accepted/unused parameter matches. | TODO | PORTED |
| TM-EOL-041 | singleton range/offset/length/text (`:496-502`) | Old range/length currently mix raw and LF bases. | TODO | TESTED |
| TM-EOL-042 | event EOL from new buffer (`:503`) | Fixed LF is correct under Option B. | TODO | TESTED |
| TM-EOL-043 | EOL flag/version/undo/redo/flush (`:504-508`) | Existing mapping; extend transition evidence. | TODO | TESTED |
| TM-EOL-044 | detailed-reason arrays (`:509-510`) | Editing telemetry omitted. | TODO | N-A (telemetry absent) |
| TM-EOL-045 | `_setValueFromTextBuffer` disposed guard (`:514-515`) | Existing lifecycle seam. | TODO | N-A (existing lifecycle seam) |
| TM-EOL-046 | capture old range/length/end before swap (`:516-519`) | Prove all old EOL forms use normalized basis. | TODO | TESTED |
| TM-EOL-047 | swap new buffer (`:521`) | New snapshot must already be normalized. | TODO | TESTED |
| TM-EOL-048 | dispose old/install new disposable (`:522-523`) | GC. | TODO | N-A (GC) |
| TM-EOL-049 | version bump after swap (`:524`) | Existing LF evidence; extend EOL transitions. | TODO | TESTED |
| TM-EOL-050 | destroy decorations (`:526-528`) | Existing evidence. | TODO | TESTED |
| TM-EOL-051 | clear edit history/trim state (`:530-532`) | Edit stack absent. | TODO | N-A (edit subsystem absent) |
| TM-EOL-052 | construct raw Flush/version flags (`:534-542`) | Existing contract, emitter body excluded. | TODO | TESTED |
| TM-EOL-053 | payload old range/length + new value/flags (`:543-544`) | Add full EOL-form transition matrix. | TODO | TESTED |

Proposed TMD/TM/TML totals: 25 TESTED / 1 PORTED / 9 DEFERRED /
20 N-A = 55.

### Content-event facts — EV

| ID | Source atom | Local target / current gap | Status | Proposed terminal |
|---|---|---|---|---|
| EV-EOL-001 | `IModelContentChange.range` (`mirrorTextModel.ts:12-16`) | Old full range must share normalized basis. | TODO | TESTED |
| EV-EOL-002 | `rangeOffset` (`:17-20`) | Flush uses 0. | TODO | TESTED |
| EV-EOL-003 | `rangeLength` (`:21-24`) | Old fixed-LF value length. | TODO | TESTED |
| EV-EOL-004 | replacement `text` (`:25-28`) | New normalized full value. | TODO | TESTED |
| EV-EOL-005 | public event `changes` (`textModelEvents.ts:42-46`) | Existing field; prove singleton facts. | TODO | TESTED |
| EV-EOL-006 | public event `eol` (`:47-50`) | Fixed LF. | TODO | TESTED |
| EV-EOL-007 | public event `versionId` (`:51-54`) | Existing new-version fact. | TODO | TESTED |
| EV-EOL-008 | public event `isUndoing` (`:55-58`) | Flush false. | TODO | TESTED |
| EV-EOL-009 | public event `isRedoing` (`:59-62`) | Flush false. | TODO | TESTED |
| EV-EOL-010 | public event `isFlush` (`:63-67`) | True. | TODO | TESTED |
| EV-EOL-011 | public event `isEolChange` (`:69-72`) | Input normalization is setValue, not setEOL; false. | TODO | TESTED |
| EV-EOL-012 | `detailedReasons` (`:74-78`) | Editing telemetry omitted. | TODO | N-A (telemetry absent) |
| EV-EOL-013 | `detailedReasonsChangeLengths` (`:80-84`) | Editing telemetry omitted. | TODO | N-A (telemetry absent) |
| EV-EOL-014 | numeric `RawContentChangedType.Flush=1` (`:221-227`) | Local enum has no numeric ABI. | TODO | N-A (semantic enum) |
| EV-EOL-015 | `ModelRawFlush.changeType` (`:233-235`) | Constructor identity exists. | TODO | TESTED |
| EV-EOL-016 | raw event `changes` ctor fact (`:457-459,:475-476`) | `[Flush]`. | TODO | TESTED |
| EV-EOL-017 | raw event `versionId` (`:460-463,:477`) | New version. | TODO | TESTED |
| EV-EOL-018 | raw event `isUndoing` (`:464-467,:478`) | False. | TODO | TESTED |
| EV-EOL-019 | raw event `isRedoing` (`:468-471,:479`) | False. | TODO | TESTED |
| EV-EOL-020 | raw event `resultingSelection=null` (`:473,:480`) | Selection/incremental lane absent. | TODO | N-A (selection lane absent) |

Proposed EV totals: 16 TESTED / 4 N-A = 20. Complete
`InternalModelContentChangeEvent` and `_emitContentChangedEvent` mechanics do
not enter this denominator and remain tokenization-owned.

### Provider full-range handoff — PR

| ID | Source/consumer atom | Local target / current gap | Status | Proposed terminal |
|---|---|---|---|---|
| PR-EOL-001 | model-wide inlay passes `[model.get_full_model_range()]` (`languages.mbt:222-239`, fact `:231`) | Require real non-LF-input provider evidence. | TODO | TESTED |
| PR-EOL-002 | each Range endpoint converts to offset (`inlay_hints_request.mbt:143-156`, facts `:152-155`) | CRLF currently produces raw end 4 for LF value length 3. | TODO | TESTED |
| PR-EOL-003 | provider receives exact OffsetRange (`language/inlay_hints.mbt:35-41`; call `inlay_hints_request.mbt:162-165`) | Existing test covers only LF. | TODO | TESTED |

Proposed PR totals: 3 TESTED = 3.

### Named upstream reference-test dispositions — REF

These rows are counted because the pre-plan reference file explicitly
deferred or skipped them. A proposed `PORTED` means the named test will be
ported with the row's stated Option-B adaptation; it is not current evidence.

| ID | Pinned upstream test | Required disposition | Status | Proposed terminal |
|---|---|---|---|---|
| REF-001 | `TextModelData.fromString / one line text` (`textModel.test.ts:97-108`) | Port exact value/lines/EOL/metadata behavior under fixed LF. | TODO | PORTED |
| REF-002 | `multiline text` (`:110-125`) | Port lines/metadata; expected model EOL adapts from CRLF to LF per Gate A. | TODO | PORTED |
| REF-003 | `Non Basic ASCII 1` (`:127-139`) | Port through computed non-basic-ASCII surface plus Unicode coordinates. | TODO | PORTED |
| REF-004 | `containsRTL 1` (`:141-153`) | Port exact. | TODO | PORTED |
| REF-005 | `containsRTL 2` (`:155-167`) | Port exact. | TODO | PORTED |
| REF-006 | `getValueLengthInRange` (`:189-218`) | Port with both raw inputs normalized to LF expectations. | TODO | PORTED |
| REF-007 | `getValueLengthInRange different EOL` (`:220-239`) | Selector-specific TextDefined/CRLF/LF assertions have no public seam; fixed-LF behavior is covered elsewhere. | TODO | DEFERRED (approved LF-only seam) |
| REF-008 | `TextModel.createSnapshot / empty file` (`:1177-1185`) | Streaming snapshot API remains absent. | TODO | DEFERRED (streaming snapshot absent) |
| REF-009 | `TextModel.createSnapshot / file with BOM` (`:1187-1194`) | Streaming/preserveBOM API and BOM stripping conflict with existing content contract. | TODO | DEFERRED (existing public BOM contract) |
| REF-010 | `TextModel.createSnapshot / regular file` (`:1196-1204`) | Streaming snapshot API remains absent. | TODO | DEFERRED (streaming snapshot absent) |
| REF-011 | `TextModel.createSnapshot / large file` (`:1206-1233`) | Streaming/chunked snapshot API remains absent. | TODO | DEFERRED (streaming snapshot absent) |

Proposed REF totals: 6 PORTED / 5 DEFERRED = 11.

Existing `model_reference_wbtest.mbt` already owns `model getValue`,
`getValueInRange`, `getValueLengthInRange`, line-separator/lonely-CR cases, and
`setValue eventing`; they provide evidence for member rows without duplicating
the test denominator. The old 294fb350 source files are byte-identical to the
pinned b18492a versions, but citations will be updated to the program oracle.

Additional branch oracles are the immutable `testLineStarts` helper,
`prefix sum for line feed / basic`, the readonly range/line-content cases, and
buffer equality/line-char-code cases in `pieceTreeTextBuffer.test.ts`.
Mutation/chunk-only setup and edit suites are N-A through their owning rows,
not claimed as complete test ports.

## Test-Authority Corrections

- `text_model_reference_wbtest.mbt` currently groups the CRLF range-length and
  TextModelData cases as DEFERRED. REF-001–007 now give each name its own
  disposition; the file's old oracle is byte-identical but its citations and
  triage must be updated to b18492a.
- `model_reference_wbtest.mbt` already contains mixed-EOL value/range/lonely-CR
  cases. They remain authority, but they do not prove storage/offset coherence.
- `text_model_test.mbt` currently asserts raw CRLF starts (`9` rather than
  normalized `8`) and must be corrected to the approved coordinate system.
- `set_value_wbtest.mbt` covers only LF→LF event facts and currently asserts
  CRLF-versus-LF snapshot inequality; both are stale under Option B.
- Tests that assert LF output alone do not validate offset/position coherence.
- `inlay_hints_request_wbtest.mbt` and `public_read_api_wbtest.mbt` use LF-only
  input and do not validate the provider/public boundary bug.

## Required Test Matrix (Phase 4)

Port upstream cases and add local invariants for:

- construction corpus: empty, one-line, LF, CRLF, CR, mixed forms, leading,
  trailing and consecutive EOLs, `CRLF`, trailing CR, `CRX`, `CRCR`, `LFCR`,
  and U+2028/U+2029 as non-EOL content;
- every source majority/default/tie and normalizeEOL true/false lane receives
  its explicit Option-B row disposition even though the local result is always
  LF;
- ASCII+Tab basic metadata; control, non-ASCII BMP, Hebrew/Arabic RTL,
  surrogate pairs, combining text, and positions beside EOL in UTF-16 units;
- for each small fixture, every offset `0..length`, every valid line/column,
  line starts, both sides of LF, trailing empty line, and approved invalid
  low/high clamps. Float/NaN behavior remains typed-input N-A;
- empty/same-line/cross-line/full/trailing ranges across getValue,
  getValueLength, getValueInRange, getValueLengthInRange, getPositionAt,
  getOffsetAt, getFullModelRange, getEOL/sequence, equality, and public reads;
- `getLineCharCode` content index, nonfinal `index==lineLength` returning LF,
  and final `index==lineLength` returning 0;
- LF/CRLF/CR/mixed set_value transitions, including pairs with the same
  normalized value and pairs with changed content; verify old range/length,
  new text, event EOL/flags, full range, and coordinates;
- leading/interior/U+FEFF-only/BOM+CRLF and set_value add/remove-BOM cases,
  freezing U+FEFF as ordinary content without claiming getBOM/preserveBOM;
- model-wide inlay and public/workbench read boundaries for CRLF, CR, mixed,
  trailing-EOL, Unicode, and BOM inputs; provider range must be exactly
  `[0, model.get_value_length())`;
- focused model/language tests on JS and native, then `just check`, `just test`,
  `just build`, and `just test-browser`.

## Milestones

1. Complete source/test inventory, ledger, invariants, and the approved
   Option-B source-member mapping; commit and stop.
2. Port the approved immutable buffer construction/EOL representation.
3. Port read/length/range/position/offset methods over that representation.
4. Correct set_value events and provider full ranges.
5. Port/re-enable upstream EOL reference cases and invariant/property tests.
6. Update model and language contracts.
7. Run focused and full quality gates.
8. Independent source/ledger/diff/test review.

## Deviations (Phase 3)

Gate A approved one product-policy deviation: no model-EOL selection and no
TextDefined/CRLF read preference. Its source mapping is EFB-003–005/009–013/
017, EBB-006–008/025–027/032/038, ETB-013/027/031/037–041/072/074–076,
PB-005–007/020/022/024/045–047/075/086/090/100, MI-001–007/017/019/
037/040/042/043/049/050, TMD-001, TM-EOL-004/009/020/024/028/031/038,
EV-EOL-006/011, and REF-002/006/007. Fixed-LF observable rows remain
TESTED/PORTED; selector/control-flow rows terminate with their stated
DEFERRED/N-A reason.

Additional pre-existing reductions are explicit rather than folded into
Option B:

- EFB-002, EBB-002/015, ETB-002/007/012/018/020, MI-012/018/038/039/041,
  TM-EOL-021/025, and REF-009 preserve the public BOM-as-content contract and
  defer separate BOM metadata/strip/preserve switches;
- typed arrays, chunk/piece topology, streaming snapshots, Unicode-scalar
  character count, edit/search/setEOL, telemetry, disposal guards, and
  large-file flags have row-local N-A/DEFERRED reasons;
- the already-reviewed clamped readonly position/range contract is consumed,
  not reopened. Only JS float/NaN input behavior is N-A due Int types.

No other product reduction is pre-approved. A new DEFERRED/N-A outcome must
update this ledger and stop for classification review.

### Inventory stop gate

- [x] 382 source atoms and 11 named test atoms have 393 unique ledger rows.
- [x] Every row is TODO with one proposed terminal; there are zero PASS rows.
- [x] Proposed totals are 169 TESTED / 27 PORTED / 28 DEFERRED / 169 N-A.
- [x] Option B and BOM/clamp/streaming reductions map to exact rows.
- [x] Algebraic invariants and source-branch behavior matrix are explicit.
- [x] Shared-file ownership and excluded sibling clusters are explicit.
- [x] No product or test file changed while building the inventory.
- [ ] Fresh independent Gate B approves completeness, boundaries,
  classifications, matrices, hashes, and combined mechanics.

## Exit Gate

- [ ] inventory rows equal ledger rows
- [ ] approved Option B is reflected in every affected source-member row
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
- 2026-07-12: Phase 1–2 inventory is ready with 393/393 TODO rows: 382 source
  atoms plus 11 named upstream test dispositions. The proposed map is 169
  TESTED, 27 PORTED, 28 DEFERRED, and 169 N-A. Three independent source passes
  covered builder/buffer, PieceTreeBase/interfaces, and TextModel/events/local
  consumers. The inventory adds the previously omitted event declarations,
  real inlay Range→OffsetRange owner, public/workbench consumers, fixed-LF
  algebra, BOM compatibility boundary, and the `getLineCharCode` EOL/EOF gap.
  No product or test file changed. Commit this documentation-only gate and
  stop for fresh independent Gate B review.

Append the dated inventory approval, implementation commits, validation
results, and final ledger totals here. Freeze after implementation.
