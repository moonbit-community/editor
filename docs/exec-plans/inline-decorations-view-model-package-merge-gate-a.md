# Inline Decorations and View Model Package Merge — Gate A

Status: inventory ready — STOP FOR REVIEW

Date: 2026-07-13

Parent plan: `inline-decorations-view-model-package-merge.md`

Oracle commit: `b18492a288de038fbc7643aae6de8247029d11bd`

No product code, package manifest, generated interface, test, or README has
changed. This artifact closes the parent's Gate A inventory deliverables and
records the concrete target representation proposed for review.

## Scope and Counting Rule

The complete scoped source units are:

- `vscode/src/vs/editor/common/viewModel/inlineDecorations.ts`;
- `vscode/src/vs/editor/common/viewModel/viewModelDecoration.ts`;
- `vscode/src/vs/editor/test/common/viewModel/inlineDecorations.test.ts`.

The called converter/model/decoration clusters are inventoried separately
below. They describe package/type dependencies and are not double-counted in
the two-unit source denominator.

One source row owns one top-level type/class/interface/function; class or
interface field/property/method/constructor (including parameter-properties);
enum value; behavior-changing loop/branch/early transfer; source-authored
callback; independently meaningful affinity/index literal; or complete-file
DOM/CSS disposition. An early `continue`, `break`, or `return` stays on its
owning branch row. Plain binds and straight-line assignments stay on their
owning member row.

| Scoped source | Rows | TESTED | PORTED | DEFERRED | N-A |
|---|---:|---:|---:|---:|---:|
| `inlineDecorations.ts` | 80 | 52 | 25 | 2 | 1 |
| `viewModelDecoration.ts` | 23 | 3 | 1 | 17 | 2 |
| **Total** | **103** | **55** | **26** | **19** | **3** |

There are zero `TODO`, bare `PASS`, or unclassified rows. The complete-source
reread found no unaccounted declaration, enum value, field/property/member,
constructor parameter-property, branch/loop/early transfer, callback,
meaningful constant, or owned DOM/CSS item.

## Pinned Evidence and Current-Pin Diff

| File | Lines | SHA-256 |
|---|---:|---|
| `common/viewModel/inlineDecorations.ts` | 269 | `47d0437b8d94918b9df1d6de3b5b42c2af1f54dabadaad85f03f2e0899e4b21a` |
| `common/viewModel/viewModelDecoration.ts` | 79 | `f50cc262d9cf57b1b9f6f4e7aacf49dec9cb5ca5b80084c818deb01d035b1ee1` |
| `test/common/viewModel/inlineDecorations.test.ts` | 491 | `dfa5235bd89420858c279b9dbfcc78ce8a838adf9693d374127ad0a877b8f772` |

The old pin named by the local source is
`294fb350837dbaee37b949533fead4df4e0e8971`. Git blob and SHA-256 comparison,
plus an empty `git diff --exit-code`, prove that all three scoped files are
byte-for-byte identical at the old and current pins. There is no API, branch,
constant, test, or behavioral drift to reconcile; only source citations must
move to the current oracle. The four called support units
`coordinatesConverter.ts`, `viewModelDecorations.ts`, `model.ts`, and
`model/textModel.ts` are also unchanged between those pins.

Current local baselines are 578 production lines and 974 black-box test lines:

| Local file | SHA-256 |
|---|---|
| `viewer/common/inline_decorations/inline_decorations.mbt` | `fe0c9f62720d1236681c3dcbdac92f6f810733c0b54633d1d7da6364c0641edb` |
| `viewer/common/inline_decorations/inline_decorations_reference_test.mbt` | `ca09d158c0a92a64e05eb1ef4b3e519d2122392e50b2f00db76540913ba2b8ab` |

## `inlineDecorations.ts` Parity Ledger

Test keys refer to the 23-case ledger below: `M01..M12` are model-decoration
cases and `I01..I11` are injected-text cases.

| ID | Source atom | Exact transition / current local disposition | Status |
|---|---|---|---|
| INL-001 | `InlineDecorationType` enum (`:12-17`) | Local same four-case enum. | PORTED |
| INL-002 | `Regular = 0` (`:13`) | First local variant; ordinary inline range (`M02`, `I02`). | TESTED |
| INL-003 | `Before = 1` (`:14`) | Zero-width start placement (`M04`). | TESTED |
| INL-004 | `After = 2` (`:15`) | Zero-width end placement (`M05`). | TESTED |
| INL-005 | `RegularAffectingLetterSpacing = 3` (`:16`) | Same local variant (`M03`, `I04`). | TESTED |
| INL-006 | `InlineDecoration` class (`:19-25`) | Local concrete record. | PORTED |
| INL-007 | `range` property (`:21`) | Exact ranges asserted throughout `M02-M07`, `I02-I11`. | TESTED |
| INL-008 | `inlineClassName` property (`:22`) | Exact class propagation in the same cases. | TESTED |
| INL-009 | `type` property (`:23`) | All four cases asserted. | TESTED |
| INL-010 | `InlineDecoration` constructor (`:20-24`) | Local constructor preserves argument order and values. | TESTED |
| INL-011 | `IViewDecorationsCollection` (`:30-43`) | Local generic collection; genericity exists for the package seam. | PORTED |
| INL-012 | `decorations` property (`:34`) | Empty/one/cache identity covered by `M01`, `M02`, `M10`, `M11`. | TESTED |
| INL-013 | `inlineDecorations` property (`:38`) | All `M*` grouping assertions. | TESTED |
| INL-014 | `hasVariableFonts` property (`:42`) | False/true matrix in `M01`, `M02`, `M08`. | TESTED |
| INL-015 | `IInlineDecorationsComputer` (`:45-50`) | No local trait; both concrete computers expose the method. | PORTED |
| INL-016 | interface `getInlineDecorations` (`:49`) | Both local computers are exercised by `M12` and `I01-I11`. | TESTED |
| INL-017 | `IInlineModelDecorationsComputerContext` (`:52-57`) | Local generic `InlineModelContext[O]`. | PORTED |
| INL-018 | context `getModelDecorations` callback (`:56`) | Exact `(Range,Bool,Bool)->Array` closure; real owner is `ViewModelDecorations`. | PORTED |
| INL-019 | `InlineModelDecorationsComputer` class (`:59-184`) | Local generic computer; generics are boundary/test seams. | PORTED |
| INL-020 | `_decorationsCache` field (`:61`) | Map keyed by id; identity/invalidation covered by `M10`, `M11`. | TESTED |
| INL-021 | constructor `context` parameter-property (`:64`) | Local private context field. | PORTED |
| INL-022 | constructor `model` parameter-property (`:65`) | Local private generic model; production is `@model.TextModel`. | PORTED |
| INL-023 | constructor `coordinatesConverter` parameter-property (`:66`) | Local private generic converter; production is the concrete view-model converter. | PORTED |
| INL-024 | constructor (`:63-69`) | Initializes an empty map; every `M*` case constructs it. | TESTED |
| INL-025 | `getInlineDecorations` (`:71-76`) | Model-line range -> view conversion -> `getDecorations(false,false)` -> grouped result (`M12`). | TESTED |
| INL-026 | `getDecorations` (`:78-149`) | Same callback/order/grouping; broad `M01-M09`. | TESTED |
| INL-027 | `reset` (`:151-153`) | Replaces the cache; `M11`. | TESTED |
| INL-028 | `onModelDecorationsChanged` (`:155-157`) | Delegates to `reset`; production caller exists, no direct source test. | PORTED |
| INL-029 | `onLineMappingChanged` (`:159-161`) | Delegates to `reset`; production remapping caller exists. | PORTED |
| INL-030 | `_getOrCreateViewModelDecoration` (`:163-183`) | Cache hit/miss in `M10/M11`; ordinary range path in other `M*`. | TESTED |
| INL-031 | `IInjectedTextInlineDecorationsComputerContext` (`:186-207`) | Public child context plus a duplicate private production context in `model_line_projection.mbt`. | PORTED |
| INL-032 | `getInjectionOptions` callback (`:190`) | Invoked before break traversal; option order retained (`I02-I11`). | TESTED |
| INL-033 | `getInjectionOffsets` callback (`:194`) | Missing and ordered offsets (`I01`, `I05`). | TESTED |
| INL-034 | `getBreakOffsets` callback (`:198`) | Output-line denominator (`I02`, `I06-I08`, `I11`). | TESTED |
| INL-035 | `getWrappedTextIndentLength` callback (`:202`) | Continuation-only indent (`I07`). | TESTED |
| INL-036 | `getBaseViewLineNumber` callback (`:206`) | Absolute view-line base (`I09-I11`). | TESTED |
| INL-037 | `InjectedTextInlineDecorationsComputer` class (`:209-269`) | Public test-facing copy plus a duplicate private production computer. | PORTED |
| INL-038 | constructor `context` parameter-property (`:211`) | Both local copies retain a private context. | PORTED |
| INL-039 | constructor (`:211`) | Both constructors preserve the context unchanged. | TESTED |
| INL-040 | injected `getInlineDecorations` (`:213-268`) | Complete child port; `I01-I11`. Production duplicate lacks letter-spacing reachability. | TESTED |
| INL-041 | model-line range column `1` (`:72`) | Exact `Range(line,1,line,getLineMaxColumn)`; `M12`. | TESTED |
| INL-042 | fixed query flags `false,false` (`:74`) | Exact local call; no test observes flag forwarding. | PORTED |
| INL-043 | inclusive view-line initialization loop (`:87-90`) | One empty bucket and false font flag per line; `M01`, `M07`, `M09`. | TESTED |
| INL-044 | model-decoration traversal loop (`:92-142`) | Preserves callback array order; `M06`, `M09`. | TESTED |
| INL-045 | visibility guard + `continue` (`:96-98`) | Guard exists, but local predicate is constant true. | DEFERRED (token-visibility option fields absent) |
| INL-046 | `inlineClassName` presence branch (`:105-115`) | Present/absent in `M02`, `M01`. | TESTED |
| INL-047 | letter-spacing ternary (`:106`) | True -> spacing type; false -> regular (`M02`, `M03`). | TESTED |
| INL-048 | intersection max/min and inclusive loop (`:107-114`) | Clamp then append to every intersected line; `M07`. | TESTED |
| INL-049 | regular `affectsFont` branch (`:111-113`) | False and true in `M02`, `M08`. | TESTED |
| INL-050 | `beforeContentClassName` branch (`:116-128`) | `M04`, `M06`; only the test options can currently produce it. | TESTED |
| INL-051 | before-start viewport guard (`:117`) | Inclusive start-line containment; no outside-boundary test. | PORTED |
| INL-052 | before zero-width range (`:118-123`) | Exact start position and slot; `M04`. | TESTED |
| INL-053 | before `affectsFont` branch (`:124-126`) | Implemented; no source test combines the two true values. | PORTED |
| INL-054 | `afterContentClassName` branch (`:129-141`) | Product field exists; `M05`, `M06`. | TESTED |
| INL-055 | after-end viewport guard (`:130`) | Inclusive end-line containment; no outside-boundary test. | PORTED |
| INL-056 | after zero-width range (`:131-136`) | Exact end position and slot; `M05`. | TESTED |
| INL-057 | after `affectsFont` branch (`:137-139`) | Implemented; no true-case source test. | PORTED |
| INL-058 | cache hit/miss branch (`:165-181`) | Hit reuses object; miss converts/constructs/stores by id (`M10`, `M11`). | TESTED |
| INL-059 | `isWholeLine` branch (`:170-178`) | Exact whole-line/ordinary split; no upstream inline test sets it. | PORTED |
| INL-060 | whole-line start column `1` (`:171`) | Same local literal; branch untested here. | PORTED |
| INL-061 | whole-line constants `Left,false,true` (`:171`) | Local passes `Left`, but its converter omits `allowZero=false` and `belowHiddenRanges=true`. | DEFERRED (converter flag seam absent) |
| INL-062 | whole-line end conversion `Right` (`:172`) | Same right affinity and model max column. | PORTED |
| INL-063 | ordinary range conversion `Right` (`:175-177`) | Same affinity keeps injected text before the decoration. | PORTED |
| INL-064 | missing injection offsets early `[]` (`:214-217`) | Child uses `None`; production duplicate represents none as an empty array (`I01`). | TESTED |
| INL-065 | injected accumulators start at `0` (`:219-220`) | Exact total-length/current-index state (`I05-I08`). | TESTED |
| INL-066 | output-line loop over break offsets (`:225-267`) | One output bucket per break (`I02`, `I06-I08`, `I11`). | TESTED |
| INL-067 | first/wrapped line-start ternary (`:229`) | Index 0 -> 0; later -> previous break (`I02`, `I06`). | TESTED |
| INL-068 | pending-injection `while` (`:232-265`) | Shared current index until later/split break (`I05-I08`). | TESTED |
| INL-069 | later-line guard + `break` (`:237-240`) | `start > lineEnd` leaves injection for a later line; `I08`. | TESTED |
| INL-070 | intersection guard (`:242-257`) | Strict `lineStart < injectedEnd`; `I06`. | TESTED |
| INL-071 | injected class presence branch (`:245-256`) | Present renders, absent does not (`I02`, `I03`). | TESTED |
| INL-072 | continuation-indent ternary (`:246-247`) | First line 0, later line wrapped indent (`I07`). | TESTED |
| INL-073 | clipped start max with `0` (`:248`) | Exact lower clamp (`I06`, `I07`). | TESTED |
| INL-074 | clipped end min (`:249`) | Exact upper clamp (`I06`, `I07`). | TESTED |
| INL-075 | nonempty span guard (`:250-255`) | Emit only when `start != end`; no zero-width case. | PORTED |
| INL-076 | absolute view line (`:251`) | Base view line plus output index (`I09-I11`). | TESTED |
| INL-077 | one-based columns `start+1,end+1` (`:252`) | Exact offset conversion (`I02`, `I06-I11`). | TESTED |
| INL-078 | injected letter-spacing ternary (`:253`) | Child test `I04`; canonical production options lack this field. | TESTED |
| INL-079 | consumed-vs-split transition (`:258-264`) | `end <= lineEnd` advances; otherwise reprocess next line (`I05`, `I06`). | TESTED |
| INL-080 | owned DOM/CSS/attributes | File creates data only and owns no DOM/CSS/attribute. | N-A (DOM-free source unit) |

## `viewModelDecoration.ts` Parity Ledger

| ID | Source atom | Exact transition / current local disposition | Status |
|---|---|---|---|
| VMD-001 | `ViewModelDecoration` class (`:10-20`) | Local generic record; target is a canonical concrete view-model type. | PORTED |
| VMD-002 | `_viewModelDecorationBrand` (`:11`) | TypeScript nominal brand with no runtime read/write. | N-A (TypeScript type-system seam) |
| VMD-003 | `range` field (`:13`) | Exact converted ranges asserted in `M02-M07`, cache identity in `M10/M11`. | TESTED |
| VMD-004 | `options` field (`:14`) | Consumed for inline/before/after entries in `M02-M08`. | TESTED |
| VMD-005 | constructor (`:16-19`) | Retains exact range/options. | TESTED |
| VMD-006 | `isModelDecorationVisible` (`:22-32`) | Local helper always returns true. | DEFERRED (hide option fields absent) |
| VMD-007 | `isModelDecorationInComment` (`:34-40`) | No local function; requires comment-token range scan. | DEFERRED (same seam) |
| VMD-008 | comment predicate callback (`:38`) | Exact equality with `StandardTokenType.Comment` is absent. | DEFERRED (same seam) |
| VMD-009 | `isModelDecorationInString` (`:42-48`) | No local function; requires string-token range scan. | DEFERRED (same seam) |
| VMD-010 | string predicate callback (`:46`) | Exact equality with `StandardTokenType.String` is absent. | DEFERRED (same seam) |
| VMD-011 | private `testTokensInRange` (`:55-78`) | Token primitives now exist, but option fields and reviewed behavior do not. | DEFERRED (same seam) |
| VMD-012 | comment-hide guard + early false (`:23-25`) | First guard has priority; local negative path unreachable. | DEFERRED (same seam) |
| VMD-013 | string-hide guard + early false (`:27-29`) | Runs after comment guard; local negative path unreachable. | DEFERRED (same seam) |
| VMD-014 | inclusive line loop (`:56-76`) | Scan every line in the range in order. | DEFERRED (same seam) |
| VMD-015 | first-line token-index ternary (`:58-61`) | First line starts at containing token, later lines at index 0. | DEFERRED (same seam) |
| VMD-016 | 1-based to 0-based start (`:61`) | `findTokenIndexAtOffset(startColumn - 1)`; later fallback 0. | DEFERRED (same seam) |
| VMD-017 | per-line token loop (`:62-75`) | Continue while index is below token count. | DEFERRED (same seam) |
| VMD-018 | end-line-only cutoff guard (`:63`) | Start-offset cutoff runs only on the final line. | DEFERRED (same seam) |
| VMD-019 | end cutoff + `break` (`:64-67`) | Stop only when token start is strictly beyond `endColumn - 1`. | DEFERRED (same seam) |
| VMD-020 | callback-false early return (`:70-73`) | First rejected token aborts the complete scan. | DEFERRED (same seam) |
| VMD-021 | token-index advance (`:74`) | Increment once after every accepted token. | DEFERRED (same seam) |
| VMD-022 | successful fallthrough true (`:77`) | Empty/no-rejected scan returns true. | DEFERRED (same seam) |
| VMD-023 | owned DOM/CSS/attributes | File owns no DOM/CSS/attribute. | N-A (DOM-free source unit) |

## Upstream Test-Case Ledger

The upstream test unit has exactly 23 named cases and the local reference file
has the same 23 names. Both local targets are green:

```text
moon test --target js viewer/common/inline_decorations
Total tests: 23, passed: 23, failed: 0.

moon test --target native viewer/common/inline_decorations
Total tests: 23, passed: 23, failed: 0.
```

The upstream helper `createModelDecoration` (`:14-21`) is ported at local
`:9-15`. The disposable leak guards at upstream `:25` and `:268` are N-A:
the MoonBit mini-model/converter fixtures allocate no disposable editor
resources and expose no disposal contract. Suite adapters and these guards are
structural inventory, not extra test-case rows.

| ID | Exact upstream test and lines | Behavior / local disposition | Status |
|---|---|---|---|
| M01 | `no decorations` (`:27-41`) | Empty ungrouped list, one empty line bucket, font false; local `:231-244`. | TESTED |
| M02 | `inline class name decoration on a single line` (`:43-62`) | One exact `Regular` range/class, retained ungrouped value, font false; local `:247-279`. | TESTED |
| M03 | `inlineClassName with affectsLetterSpacing` (`:64-82`) | True selects `RegularAffectingLetterSpacing`; local `:282-313`. | TESTED |
| M04 | `beforeContentClassName decoration` (`:84-101`) | Zero-width `Before` at source start; local `:316-346`. | TESTED |
| M05 | `afterContentClassName decoration` (`:103-120`) | Zero-width `After` at source end; local `:349-379`. | TESTED |
| M06 | `all decoration types combined` (`:122-145`) | `Regular`, `Before`, `After` in exact source order/ranges; local `:382-424`. | TESTED |
| M07 | `decoration spanning multiple lines` (`:147-167`) | Same value in all three intersected buckets; local `:427-458`. | TESTED |
| M08 | `decoration with affectsFont sets hasVariableFonts` (`:169-185`) | True marks the intersected line; local `:461-484`. | TESTED |
| M09 | `multiple decorations on different lines` (`:187-209`) | Two decorations distribute to their respective lines in order; local `:487-532`. | TESTED |
| M10 | `decoration cache is used for same decoration id` (`:211-226`) | Repeated query returns the same physical object; local `:535-555`. | TESTED |
| M11 | `reset clears decoration cache` (`:228-244`) | Reset makes the next value physically distinct; local `:558-579`. | TESTED |
| M12 | `getInlineDecorations returns inline decorations for a model line` (`:246-263`) | Convenience entry constructs the full line range; local `:582-612`. | TESTED |
| I01 | `no injections returns empty` (`:270-281`) | Null offsets take immediate empty return; local `:617-634`. | TESTED |
| I02 | `single injection with inlineClassName on a single output line` (`:283-299`) | Interior content maps to exact 1-based view columns; local `:637-664`. | TESTED |
| I03 | `injection without inlineClassName produces no inline decorations` (`:301-317`) | Output bucket exists but stays empty; local `:667-683`. | TESTED |
| I04 | `injection with inlineClassNameAffectsLetterSpacing` (`:319-335`) | True selects spacing-affecting type; local `:686-714`. | TESTED |
| I05 | `multiple injections on a single output line` (`:337-357`) | Prior injected length shifts later injection; order retained; local `:717-753`. | TESTED |
| I06 | `injection spanning across wrapped lines` (`:359-381`) | Clip, reprocess, and use base view lines 5/6; local `:756-795`. | TESTED |
| I07 | `injection with wrappedTextIndentLength on wrapped lines` (`:383-402`) | First line no indent, continuation gets four columns; local `:798-834`. | TESTED |
| I08 | `injection starting in later wrapped line` (`:404-424`) | First bucket empty; later line gets exact range; local `:837-868`. | TESTED |
| I09 | `base view line number offsets correctly` (`:426-442`) | Base line 10 shifts result; local `:871-898`. | TESTED |
| I10 | `range uses view line number, not model line number` (`:444-466`) | Model line 3 produces view line 7; local `:901-933`. | TESTED |
| I11 | `range uses view line number on wrapped lines, not model line number` (`:468-490`) | Model line 2 produces view lines 5/6; local `:936-974`. | TESTED |

Test denominator: **23 rows = 23 TESTED**.

### Behavior Variables and Matrix Gaps

The source suite covers zero/one/two decorations; one/two/three-line
topologies; regular/before/after/all-three ordering; letter spacing; font false
and true for a regular entry; cache miss/hit/reset; null/one/two injection
offsets; missing/present class; start/interior/later-line positions; accumulated
injected length; one/two output lines; contained/crossing/later spans; indent 0/4;
base lines 1/5/7/10; and fully-consumed versus reprocessed injections.

The complete branch-derived implementation matrix must additionally cover or
retain an explicit terminal disposition for:

- overlapping, adjacent, and same-line multiple model decorations;
- `isWholeLine=true`, including hidden/folded/collapsed projection and the
  missing `allowZero=false, belowHiddenRanges=true` converter switches;
- `hideInCommentTokens` and `hideInStringTokens` token scans;
- before/after entries outside the viewport and with `affectsFont=true`;
- true minimap-only and margin-only filters;
- projected/wrapped/non-identity conversion, line-start/end boundaries;
- `onModelDecorationsChanged` and `onLineMappingChanged` invalidation;
- same-position injections, empty injected text, empty break offsets,
  exact `injectedStart == lineEnd`, and zero-width clipped suppression;
- the invariant that present offsets imply present, equally sized options.

## Direct Called-Cluster Inventory

These ledgers cover the complete converter/model/decoration clusters mandated by
the parent plan. They are a separate support denominator and do not enlarge the
103-row two-unit denominator. Rows use the same terminal statuses as the primary
ledger. The relevant `ViewModelImpl` ownership/call-site slice is listed after
the source-member tables; unrelated cursor, layout, and rendering behavior is
outside this ownership refactor.

### Coordinate-Converter Interface and Projected Implementation

| ID | Upstream member / branch | Current local disposition | Status |
|---|---|---|---|
| CC-000 | `ICoordinatesConverter` declaration (`coordinatesConverter.ts:10`) | Local ownership is the closed `view_model.CoordinatesConverter` enum, not an open interface. | PORTED |
| CC-001 | `ICoordinatesConverter.convertViewPositionToModelPosition` (`coordinatesConverter.ts:12`) | Concrete converter delegates to the projected collection. | TESTED |
| CC-002 | `convertViewRangeToModelRange` (`:13`) | Concrete converter delegates to the projected collection. | TESTED |
| CC-003 | `validateViewPosition` (`:14`) | The readonly local converter has no separately exposed validation operation; callers validate through the projected/model conversion. | DEFERRED (canonical converter member is absent) |
| CC-004 | `validateViewRange` (`:15`) | Same ownership decision as `CC-003`. | DEFERRED (canonical converter member is absent) |
| CC-005 | `convertModelPositionToViewPosition`, including affinity, allow-zero, and below-hidden switches (`:18-22`) | Projected collection owns all switches; the concrete converter currently exposes affinity only. `INL-061` records the child call-site gap. | DEFERRED (canonical converter omits two source switches) |
| CC-006 | `convertModelRangeToViewRange`, empty-range affinity only (`:23-26`) | Concrete converter delegates to the projected collection. | TESTED |
| CC-007 | `modelPositionIsVisible` (`:27`) | Concrete converter delegates to line visibility; column is deliberately unobserved locally. | TESTED |
| CC-008 | `getModelLineViewLineCount` (`:28`) | Not exposed by the local converter and not called by the scoped inline-decoration path. | DEFERRED (canonical converter member is absent) |
| CC-009 | `getViewLineNumberOfModelPosition` (`:29`) | Not exposed by the local converter and not called by the scoped inline-decoration path. | DEFERRED (canonical converter member is absent) |
| PM-001 | projected position-conversion signature and defaults (`viewModelLines.ts:848`) | Local projected collection retains affinity, `allow_zero_line_number=false`, and `below_hidden_ranges=false`. | TESTED |
| PM-002 | validate input position and read normalized line/column (`:850-852`) | Ported; the local implementation additionally clamps to committed projections for the documented synchronous flush seam. | TESTED |
| PM-003 | initialize zero-based line index and changed flag (`:854`) | Source order preserved. | TESTED |
| PM-004 | below-hidden traversal walks forward and marks change (`:855-859`) | Source loop and ordering preserved. | TESTED |
| PM-005 | default hidden traversal walks backward and marks change (`:860-865`) | Source loop and ordering preserved. | TESTED |
| PM-006 | no visible line above: return `(allowZero ? 0 : 1, 1)` (`:866-871`) | Branch is exercised at both Boolean outcomes; the scoped inline caller still never supplies these whole-line switches. | TESTED |
| PM-007 | compute view-line delta from projected prefix sum (`:872`) | Port uses the local prefix-sum representation. | TESTED |
| PM-008 | changed line below hidden range maps the next visible line at model column 1 (`:874-877`) | Source branch is exercised by hidden-area conversion tests. | TESTED |
| PM-009 | changed line above hidden range maps the previous visible line at its max column (`:878-880`) | Source branch preserved. | TESTED |
| PM-010 | unchanged line maps the original normalized column (`:881-883`) | Source branch preserved. | TESTED |
| PM-011 | return computed position (`:885-886`) | Direct expression return locally. | TESTED |
| PM-012 | range-conversion signature and default `Left` affinity (`:889-892`) | Local optional affinity resolves to `Left`. | TESTED |
| PM-013 | empty range converts one position with caller/default affinity (`:893-895`) | Source control flow preserved. | TESTED |
| PM-014 | non-empty range converts start with `Right`, end with `Left`, then constructs the range (`:896-900`) | Source control flow and constants preserved. | TESTED |
| VM-001 | projected view-position conversion signature (`viewModelLines.ts:834`) | Local projected collection owns the same two integer inputs. | TESTED |
| VM-002 | resolve view-line metadata (`:835`) | Local `get_view_line_info` selects the same model line and wrapped-line index. | TESTED |
| VM-003 | map the wrapped view column through the selected projection (`:837`) | Same projection lookup and argument order. | TESTED |
| VM-004 | validate and return the resulting model position (`:839`) | Canonical model validation remains the final step. | TESTED |
| VM-005 | projected view-range conversion signature (`:842`) | Local projected collection owns the same range input. | TESTED |
| VM-006 | convert the range start through view-position conversion (`:843`) | Same call and ordering. | TESTED |
| VM-007 | convert the range end through view-position conversion (`:844`) | Same call and ordering. | TESTED |
| VM-008 | construct the model range from converted endpoints (`:845`) | Same endpoint fields and order. | TESTED |
| CW-001 | projected `CoordinatesConverter` class (`viewModelLines.ts:1073`) | Local closed enum is the concrete owner. | PORTED |
| CW-002 | `_lines` field (`:1074`) | Stored as the enum's `Projected(lines)` payload. | PORTED |
| CW-003 | constructor assigns `_lines` (`:1076-1078`) | Enum construction stores the same projected collection and is checked by the closed-converter construction test. | TESTED |
| CW-004 | wrapper `convertViewPositionToModelPosition` (`:1082-1084`) | Concrete enum delegates to the projected collection. | TESTED |
| CW-005 | wrapper `convertViewRangeToModelRange` (`:1086-1088`) | Concrete enum delegates to the projected collection. | TESTED |
| CW-006 | wrapper `validateViewPosition` (`:1090-1092`) | No local wrapper member. | DEFERRED (canonical converter member is absent) |
| CW-007 | wrapper `validateViewRange` (`:1094-1096`) | No local wrapper member. | DEFERRED (canonical converter member is absent) |
| CW-008 | wrapper model-position conversion forwards affinity, allow-zero, and below-hidden (`:1100-1102`) | Local wrapper forwards affinity; switches remain on the projected collection and are not exposed through the reduced child trait. | DEFERRED (wrapper does not expose the full source signature) |
| CW-009 | wrapper model-range conversion forwards affinity (`:1104-1106`) | Direct local delegation. | TESTED |
| CW-010 | wrapper model-position visibility (`:1108-1110`) | Local delegation observes line visibility. | TESTED |
| CW-011 | wrapper model-line view-line count (`:1112-1114`) | No local wrapper member. | DEFERRED (canonical converter member is absent) |
| CW-012 | wrapper view-line number of model position (`:1116-1118`) | No local wrapper member. | DEFERRED (canonical converter member is absent) |

Coordinate-converter support denominator: **44 rows** = interface declaration
and 9 members, 14 model-to-view rows, 8 view-to-model rows, and wrapper
class/field/constructor plus 9 delegates.

### `ViewModelDecorations` Owner and Lifecycle

| ID | Upstream member / branch | Current local disposition | Status |
|---|---|---|---|
| VD-001 | `ViewModelDecorations` class (`viewModelDecorations.ts:16`) | Local concrete owner remains `view_model.ViewModelDecorations`. | PORTED |
| VD-002 | `editorId` field (`:18`) | Captured as the constructor's concrete owner id. | PORTED |
| VD-003 | `configuration` field (`:19`) | Reduced locally to the validation filter captured at provider construction; font filtering remains unavailable. | DEFERRED (font-decoration/configuration seam is absent) |
| VD-004 | `_linesCollection` field (`:20`) | Concrete projected lines value is captured by the context closure. | PORTED |
| VD-005 | `_inlineDecorationsComputer` field (`:22`) | Current field owns the child computer; target field owns the moved concrete computer. | PORTED |
| VD-006 | cached collection field (`:24`) | One optional cached collection is retained. | PORTED |
| VD-007 | cached view-range field (`:25`) | One optional exact range key is retained. | PORTED |
| VD-008 | constructor parameters and owner/configuration/lines assignments (`:27-30`) | Same concrete inputs modulo the documented configuration reduction. | PORTED |
| VD-009 | context closure forwards range, editor id, validation/font filters, minimap and margin flags (`:31-33`) | Local closure forwards every available value; font is constantly false and minimap reaches only an absent provider. | DEFERRED (font and minimap provider seams are absent) |
| VD-010 | construct the inline computer with context, model, and converter (`:34`) | Same ownership edge; generics disappear after merge. | PORTED |
| VD-011 | initialize both cache slots to null (`:35-36`) | Both local option fields initialize to `None`. | PORTED |
| VD-012 | `_clearCachedModelDecorationsResolver` clears both slots (`:39-42`) | Private local helper preserves assignment order; host invalidation tests observe the cleared cache. | TESTED |
| VD-013 | `dispose` resets the computer then clears cache (`:44-47`) | Local readonly lifecycle folds the identical body into `reset`. | N-A (identical body is owned by reset; no separate local lifecycle) |
| VD-014 | `reset` resets computer then clears cache (`:49-52`) | Source order preserved. | PORTED |
| VD-015 | model-decoration change notifies computer then clears cache (`:54-57`) | Source order preserved and exercised through root decoration-change invalidation tests. | TESTED |
| VD-016 | line-mapping change notifies computer then clears cache (`:59-63`) | Source order preserved, including clear after notification. | PORTED |
| VD-017 | minimap range query uses `(true,false)` and returns decorations (`:65-67`) | No local public method; minimap provider/view part is outside the current product. | DEFERRED (minimap view part is absent) |
| VD-018 | viewport query begins with cached-value existence (`:69-70`) | Local cache-valid flag begins with the same test. | PORTED |
| VD-019 | exact range equality gates cache reuse (`:71`) | Local option equality preserves exact-range identity semantics. | PORTED |
| VD-020 | cache miss computes decorations with `(false,false)` (`:72-73`) | Local private helper calls the computer with the same constants. | PORTED |
| VD-021 | cache miss stores the exact input range (`:74`) | Source order preserved after collection storage. | PORTED |
| VD-022 | viewport query returns the known non-null cached collection (`:76`) | Local unwrap occurs after the same dominance condition. | PORTED |
| VD-023 | per-line query builds min/max-column range (`:79-80`) | Local method uses projected min/max columns. | PORTED |
| VD-024 | per-line query forwards optional minimap/margin flags (`:79-82`) | Method is ported but currently has no local caller. | PORTED |
| VD-025 | DOM/CSS/attributes owned by this source class | None. | N-A (common-layer data/lifecycle class owns no DOM or CSS) |

`ViewModelDecorations` support denominator: **25 rows**.

### Hidden-Line-Aware View-Range Decoration Query

| ID | Upstream member / branch | Current local disposition | Status |
|---|---|---|---|
| HQ-001 | `getDecorationsInRange` signature and six filters (`viewModelLines.ts:923`) | Local helper carries owner, validation, minimap, and margin; font filtering is constantly false. | DEFERRED (font-decoration seam is absent) |
| HQ-002 | convert view start and end to model positions (`:924-925`) | Same converter calls and order. | PORTED |
| HQ-003 | fast-path line-span comparison (`:927-928`) | Exact inequality preserved. | PORTED |
| HQ-004 | fast path expands start to column 1 for wrapped whole-line decorations (`:929-930`) | Exact range construction preserved. | PORTED |
| HQ-005 | fast path forwards owner and all available filters (`:930`) | Validation and margin are forwarded; minimap/font have no local providers. | DEFERRED (minimap/font providers are absent) |
| HQ-006 | split-path result, start/end indices, and nullable request start (`:933-937`) | Same state and zero-based indices. | PORTED |
| HQ-007 | inclusive scan over every model line in the converted span (`:938-939`) | Same inclusive bounds. | PORTED |
| HQ-008 | visible line opens a request only when none is active (`:940-944`) | Same merge behavior and early condition. | PORTED |
| HQ-009 | first request uses model-start column; later requests use column 1 (`:943`) | Exact conditional constant preserved. | PORTED |
| HQ-010 | invisible line flushes an active request to the preceding line's max column (`:945-950`) | Same flush boundary and state reset. | PORTED |
| HQ-011 | split flush forwards owner/validation/minimap but intentionally drops margin (`:949`) | Local preserves the source's margin drop but cannot forward source font/minimap provider reach. | DEFERRED (font/minimap providers are absent) |
| HQ-012 | trailing active request flushes through model end and clears state (`:955-958`) | Same range, state transition, and source margin drop. | PORTED |
| HQ-013 | trailing flush forwards source font/minimap filters while still dropping margin (`:956`) | Local cannot forward either provider-specific filter. | DEFERRED (font/minimap providers are absent) |
| HQ-014 | sort first compares ranges by starts (`:960-962,970-972`) | Local uses the canonical range-start comparator. | PORTED |
| HQ-015 | equal starts sort ids lexicographically with three-way result (`:962-969`) | Local helper explicitly uses code-unit lexicographic comparison; no direct tie-order test exists. | PORTED |
| HQ-016 | initialize dedup output, length, and nullable previous-id sentinel (`:974-977`) | Local uses `""` instead of source `null`; canonical ids are always generated as `<namespace>;<n>` (`text_model_decorations.mbt:917-919`), so the sentinel cannot equal a real id. | PORTED |
| HQ-017 | repeated adjacent id is skipped (`:978-983`) | Same early `continue`. | PORTED |
| HQ-018 | new id becomes previous and is appended in order (`:984-985`) | Boundary conversion is the only current extra work. | PORTED |
| HQ-019 | return deduplicated result (`:988`) | Same final value. | PORTED |

Hidden-aware query support denominator: **19 rows**.

### Text-Model Decoration Query

| ID | Upstream member / branch | Current local disposition | Status |
|---|---|---|---|
| TQ-001 | `getDecorationsInRange` signature and defaults (`textModel.ts:1826`) | Local query retains owner, validation, font, and margin defaults; minimap is omitted because only an absent provider consumes it. | DEFERRED (minimap provider is absent) |
| TQ-002 | validate the requested range (`:1827`) | Canonical model validation is called first. | PORTED |
| TQ-003 | query the interval tree with owner, validation, font, and margin filters (`:1829`) | Local private implementation receives the same tree filters. | PORTED |
| TQ-004 | append bracket/decoration-provider results, forwarding minimap (`:1830`) | Provider does not exist locally. | N-A (bracket/decoration provider is out of scope) |
| TQ-005 | append font-token provider results, forwarding minimap (`:1831`) | Provider does not exist locally. | N-A (font-token decoration provider is out of scope) |
| TQ-006 | return merged results in tree/provider/font-provider order (`:1832`) | Tree result order is retained; absent provider contributions cannot reorder it. | PORTED |
| TQ-007 | `_getDecorationsInRange` computes start/end buffer offsets (`:1880-1882`) | Local tree query computes the equivalent interval bounds. | PORTED |
| TQ-008 | interval-tree query forwards owner, validation, font, and margin (`:1883`) | Canonical local tree query owns these filters. | PORTED |

Text-model query support denominator: **8 rows**.

### Canonical Model Decoration and Line Geometry

| ID | Upstream member / branch | Current local disposition | Status |
|---|---|---|---|
| MD-001 | `IModelDecoration` declaration (`model.ts:387`) | Canonical local value is `@model.ModelDecoration`; the child generic copy is boundary glue. | PORTED |
| MD-002 | readonly `id` field (`:391`) | Canonical local ids drive cache identity, sorting, and deduplication. | PORTED |
| MD-003 | readonly `ownerId` field (`:395`) | Canonical local `owner_id` is forwarded through query filters. | PORTED |
| MD-004 | readonly `range` field (`:399`) | Canonical local range is converted to view coordinates. | PORTED |
| MD-005 | readonly `options` field (`:403`) | Canonical local options become the concrete target input. | PORTED |
| LM-001 | `TextModel.getLineMaxColumn` declaration (`textModel.ts:897`) | Local model delegates to its snapshot. | PORTED |
| LM-002 | assert that the model is not disposed (`:898`) | Local model has no disposal assertion/state. | DEFERRED (model-liveness guard is absent) |
| LM-003 | reject line numbers outside `1..lineCount` with `BugIndicatingError` (`:899-901`) | Local snapshot line access clamps into its line range instead of throwing. | DEFERRED (invalid-line failure contract differs) |
| LM-004 | return buffer line length plus one (`:902`) | Local snapshot computes the same UTF-16 line length plus one for valid lines. | TESTED |

Canonical model support denominator: **9 rows**.

### Option Normalization

The interface fields consumed by the scoped algorithms are
`model.ts:192,270,274,278,282,297,303,309` plus injected-text
`model.ts:329-360`. The counted cluster is the complete outer normalization
surface that creates those values: `ModelDecorationInjectedTextOptions`,
`ModelDecorationOptions`, `_normalizeOptions`, and their directly called shared
class-name primitive and line-height constant. Nested overview/minimap/glyph
option objects remain separate existing owners; MO-021..023 inventory the
conditional call edges because the scoped inline algorithm consumes only the
already-normalized outer fields, never their theme-resolution methods.

| ID | Upstream member / normalization branch | Current local disposition | Status |
|---|---|---|---|
| ON-001 | `LINE_HEIGHT_CEILING = 300` (`textModel.ts:127`) | No local constant because canonical options lack line height. | DEFERRED (line-height decoration seam is absent) |
| ON-002 | `cleanClassName` helper (`:2355`) | Canonical local model owns `clean_class_name`. | PORTED |
| ON-003 | replace every non-ASCII-alphanumeric/`-`/`_` code unit with a space (`:2356`) | Local loop preserves the same accepted characters and replacement; canonical normalization tests cover it. | TESTED |
| IO-001 | `ModelDecorationInjectedTextOptions` class (`textModel.ts:2454`) | Local canonical model type is a plain value, not a normalized wrapper. | PORTED |
| IO-002 | static `from` member (`:2455`) | Local has no normalized wrapper identity layer. | N-A (no normalized wrapper type locally) |
| IO-003 | `from` returns an already-normalized instance early (`:2456-2458`) | Canonical local values need no runtime wrapper check. | N-A (MoonBit type boundary is already normalized) |
| IO-004 | `from` constructs a wrapper for raw options (`:2459`) | Local canonical constructor is used directly at producer boundaries. | PORTED |
| IO-005 | `content`, defaulting falsy input to empty (`:2462,2470`) | Content is carried; local producers must supply it explicitly. | PORTED |
| IO-006 | `tokens`, defaulting nullish input to null (`:2463,2471`) | Token arrays on injected text are not represented. | DEFERRED (injected-text token seam is absent) |
| IO-007 | `inlineClassName`, defaulting falsy input to null (`:2464,2472`) | Canonical local optional class is carried. | PORTED |
| IO-008 | letter-spacing flag, defaulting falsy input to false (`:2465,2473`) | The canonical model type lacks the flag; the current child test-only type carries it. | DEFERRED (canonical injected-text option field is absent) |
| IO-009 | `attachedData`, defaulting falsy input to null (`:2466,2474`) | Local model reduces attachment data to `attached_index`. | PORTED |
| IO-010 | `cursorStops`, defaulting falsy input to null (`:2467,2475`) | Readonly projection always uses the source default behavior. | DEFERRED (cursor-stop option is absent) |
| IO-011 | private constructor owns all six assignments (`:2469-2476`) | Local `InjectedTextOptions::InjectedTextOptions` is the single constructor. | PORTED |
| MO-001 | `ModelDecorationOptions` class (`:2479`) | Canonical local `@model.ModelDecorationOptions` remains the target concrete type. | PORTED |
| MO-002 | static `EMPTY`, initialized through `register` (`:2481,2566`) | No shared empty singleton is required by the scoped path. | N-A (not called by the scoped algorithms) |
| MO-003 | `register` constructs normalized options (`:2483-2485`) | Local constructor is the single normalization entry point. | PORTED |
| MO-004 | `createDynamic` constructs normalized options (`:2487-2489`) | Collapsed into the same local constructor. | PORTED |
| MO-005 | `description` copied (`:2490,2528`) | Local field and default are retained. | PORTED |
| MO-006 | `blockClassName` cleaned or null (`:2491,2529`) | Not represented locally. | N-A (block decorations are outside the scoped product) |
| MO-007 | `blockIsAfterEnd` nullish-defaulted (`:2492,2531`) | Not represented locally. | N-A (block decorations are outside the scoped product) |
| MO-008 | `blockDoesNotCollapse` nullish-defaulted (`:2493,2530`) | Not represented locally. | N-A (block decorations are outside the scoped product) |
| MO-009 | `blockPadding` nullish-defaulted (`:2494,2532`) | Not represented locally. | N-A (block decorations are outside the scoped product) |
| MO-010 | `stickiness` defaults to always-grow (`:2495,2533`) | Local constructor has the same default. | PORTED |
| MO-011 | `zIndex` defaults to zero (`:2496,2534`) | Local constructor has the same default. | PORTED |
| MO-012 | `className` cleaned or null (`:2497,2535`) | Local required string uses empty for absent and cleans it. | PORTED |
| MO-013 | `shouldFillLineOnLineBreak` nullish-defaulted (`:2498,2536`) | Local Boolean defaults false. | PORTED |
| MO-014 | `hoverMessage` defaults null (`:2499,2537`) | Local reduced string message is optional. | PORTED |
| MO-015 | `glyphMarginHoverMessage` defaults null (`:2500,2538`) | Not represented locally. | N-A (no scoped consumer) |
| MO-016 | `isWholeLine` defaults false (`:2501,2540`) | Local field and default are retained. | PORTED |
| MO-017 | `lineHeight` clamps to ceiling or null (`:2502,2541`) | Not represented locally. | DEFERRED (line-height decoration seam is absent) |
| MO-018 | `fontSize` defaults null (`:2503,2542`) | Not represented locally. | DEFERRED (font-decoration seam is absent) |
| MO-019 | `showIfCollapsed` defaults false (`:2504,2544`) | Local field and default are retained. | PORTED |
| MO-020 | `collapseOnReplaceEdit` defaults false (`:2505,2545`) | Local field and default are retained. | PORTED |
| MO-021 | `overviewRuler` normalizes nested options or null (`:2506,2546`) | Local reduced color/lane value is carried. | PORTED |
| MO-022 | `minimap` normalizes nested options or null (`:2507,2547`) | Local reduced color/position value is carried. | PORTED |
| MO-023 | `glyphMargin` conditional nested normalization (`:2508,2548`) | Lane options are not represented. | DEFERRED (glyph-margin lane options are absent) |
| MO-024 | `glyphMarginClassName` cleaned or null (`:2509,2549`) | Local optional class is cleaned. | PORTED |
| MO-025 | `linesDecorationsClassName` cleaned or null (`:2510,2550`) | Local optional class is cleaned. | PORTED |
| MO-026 | `lineNumberClassName` cleaned or null (`:2511,2551`) | Not represented locally. | N-A (no scoped consumer) |
| MO-027 | `lineNumberHoverMessage` defaults null (`:2512,2539`) | Not represented locally. | N-A (no scoped consumer) |
| MO-028 | `linesDecorationsTooltip` HTML-encodes or null (`:2513,2552`) | Not represented locally. | N-A (no scoped consumer) |
| MO-029 | `firstLineDecorationClassName` cleaned or null (`:2514,2553`) | Local optional class is cleaned. | PORTED |
| MO-030 | `marginClassName` cleaned or null (`:2515,2554`) | Local optional class is cleaned. | PORTED |
| MO-031 | `inlineClassName` cleaned or null (`:2516,2555`) | Local optional class is cleaned. | TESTED |
| MO-032 | letter-spacing flag defaults false (`:2517,2556`) | Local Boolean and default are retained; canonical-option default has no direct assertion. | PORTED |
| MO-033 | `beforeContentClassName` cleaned or null (`:2518,2557`) | Canonical local options lack the field. | DEFERRED (option field is absent) |
| MO-034 | `afterContentClassName` cleaned or null (`:2519,2558`) | Local optional class is cleaned and folding produces it. | PORTED |
| MO-035 | `after` injected text normalizes through `from` or null (`:2520,2559`) | Local canonical injected option is carried directly. | PORTED |
| MO-036 | `before` injected text normalizes through `from` or null (`:2521,2560`) | Local canonical injected option is carried directly. | PORTED |
| MO-037 | `hideInCommentTokens` nullish-defaults false (`:2522,2561`) | Canonical local options lack the field. | DEFERRED (option field is absent) |
| MO-038 | `hideInStringTokens` nullish-defaults false (`:2523,2562`) | Canonical local options lack the field. | DEFERRED (option field is absent) |
| MO-039 | `affectsFont` derives from size/family/weight/style (`:2524,2543`) | Canonical local options lack all four font inputs and the derived field. | DEFERRED (font-decoration seam is absent) |
| MO-040 | `textDirection` nullish-defaults null (`:2525,2563`) | Not represented locally. | DEFERRED (text-direction option is absent) |
| MO-041 | private constructor performs the normalization in source assignment order (`:2527-2564`) | Local constructor preserves its supported subset's assignment order and defaults. | PORTED |
| NO-001 | `_normalizeOptions` helper declaration (`:2578`) | Local mutation boundary accepts the canonical normalized option type directly. | PORTED |
| NO-002 | already-normalized `ModelDecorationOptions` returns early (`:2579-2581`) | Runtime raw-versus-normalized identity is unnecessary at the typed local boundary. | N-A (all local inputs are canonical options) |
| NO-003 | raw options fall back to `createDynamic` (`:2582`) | Local producers call the single canonical constructor before mutation. | PORTED |

Option-normalization support denominator: **58 rows**.

### Relevant `ViewModelImpl` Ownership and Calls

| ID | Upstream ownership / call site | Current local disposition | Status |
|---|---|---|---|
| VI-001 | `_lines` field (`viewModelImpl.ts:62`) | Local view model owns the projected line collection. | PORTED |
| VI-002 | coordinates-converter field (`:63`) | Local view model owns the closed concrete converter. | PORTED |
| VI-003 | decoration-provider field (`:66`) | Local view model owns the concrete decoration provider. | PORTED |
| VI-004 | choose identity/as-is versus projected lines (`:94-120`) | Local product always builds projected lines. | DEFERRED (large-file identity collection is absent) |
| VI-005 | create the converter from the selected lines collection (`:122`) | The closed `Projected` construction is directly tested. | TESTED |
| VI-006 | construct `ViewModelDecorations` with editor, model, configuration, lines, and converter (`:146`) | Same ownership edge with the documented reduced configuration. | PORTED |
| VI-007 | dispose decorations before lines (`:176`) | Local teardown has no separate provider lifecycle; reset owns the identical state clear. | N-A (no separate local dispose lifecycle) |
| VI-008 | wrapping change calls `onLineMappingChanged` (`:288`) | Local wrapping/configuration path invalidates the provider. | PORTED |
| VI-009 | readonly change calls `reset` (`:296`) | Viewer is permanently readonly; provider construction already captures that invariant. | N-A (readonly cannot change in this product) |
| VI-010 | validation-rendering change calls `reset` (`:301`) | Provider rotation is covered by the headless validation-option test. | TESTED |
| VI-011 | model flush calls `reset` (`:359`) | Local flush path invalidates decoration state. | PORTED |
| VI-012 | content remapping calls `onLineMappingChanged` (`:434`) | Local source records this as a tier-2-only branch. | DEFERRED (tier-2 content remapping seam is absent) |
| VI-013 | tab-size remapping calls `onLineMappingChanged` (`:547`) | Local option/projection path invalidates the provider. | PORTED |
| VI-014 | model-decoration event calls `onModelDecorationsChanged` before emitting events (`:562`) | Source ordering is retained and host cache-invalidation tests exercise the path. | TESTED |
| VI-015 | hidden-area remapping calls `onLineMappingChanged` (`:612`) | Local folding/hidden-area path invalidates decoration state. | PORTED |
| VI-016 | minimap read delegates to `getMinimapDecorationsInRange` (`:844-845`) | Neither the provider method nor minimap view part is present locally. | DEFERRED (minimap view part is absent) |
| VI-017 | viewport decoration read returns cached collection decorations (`:848-849`) | Live local browser/view-model callers exercise this result. | TESTED |
| VI-018 | text-direction read queries one line (`:875-877`) | Local options lack text direction and no equivalent consumer exists. | DEFERRED (text-direction option is absent) |
| VI-019 | viewport rendering reads the cached viewport collection (`:880-885`) | Local viewport-batched rendering consumes the same collection shape in tests. | TESTED |
| VI-020 | one-line rendering queries `getDecorationsOnLine` (`:888-890`) | Local renderer is viewport-batched; `get_decorations_on_line` consequently has no caller. | N-A (local rendering uses the viewport collection) |

`ViewModelImpl` support denominator: **20 rows**. Across all seven support
ledgers, the separate denominator is **183 rows = 41 TESTED + 87 PORTED + 36
DEFERRED + 19 N-A** (`44 + 25 + 19 + 8 + 9 + 58 + 20`).

Token-part and line-token primitives are the remaining leaf dependencies. They
already live in `@model`/`@tokens`; missing option fields, not token access,
block token-visibility parity. Their algorithms are owned by the completed
tokenization merge and are not duplicated into this support denominator.

## Current Local Ownership and Public API

The complete child-package file inventory is:

| Local file | Role / reviewed disposition |
|---|---|
| `README.md` | Current ownership, deviations, and test contract; merge its live facts into the view-model README at closeout |
| `inline_decorations.mbt` | 578-line production source; move/split by source owner without logic changes |
| `inline_decorations_reference_test.mbt` | 974-line black-box 23-case port; move as `*_reference_wbtest.mbt` so private seams do not widen the API |
| `moon.pkg` | Multi-target imports of `base/common` and `common/model`; delete after the last caller moves |
| `pkg.generated.mbti` | Generated 27-declaration public boundary; delete/regenerate through the merged owner |

The current package graph contains a real production path and a duplicate
test-facing injected path:

```text
view_model.ViewModelDecorations
  -> inline_decorations.InlineModelDecorationsComputer[model options,
                                                       TextModel,
                                                       CoordinatesConverter]
  -> model decoration store

view_model.model_line_projection
  -> private InjectedTextInlineDecorationsComputer (production)
  -> inline_decorations.InlineDecoration (output value only)

inline_decorations reference test
  -> public generic traits + mini model/options/converter
  -> public duplicate InjectedTextInlineDecorationsComputer

browser decoration renderer
  -> view_model public aliases
  -> generated-interface leak back to inline_decorations
```

| Package | Production lines | Black-box test lines | White-box test lines |
|---|---:|---:|---:|
| `viewer/common/inline_decorations` | 578 | 974 | 0 |
| `viewer/common/view_model` | 6,527 | 1,445 | 2,908 |
| **Combined production target** | **7,105** |  |  |

The child generated interface has exactly **27 top-level public declarations**:
10 data types, 3 open traits, 12 callables (one free helper plus 11
methods/constructors), and 2 public impls. The traits add nine public method
requirements.

### Exact Public Caller Inventory

Path shorthands in the two ledgers below are `MBTI` =
`viewer/common/inline_decorations/pkg.generated.mbti`, `ID` =
`viewer/common/inline_decorations/inline_decorations.mbt`, `IDT` = its
`inline_decorations_reference_test.mbt`, `VMD` =
`viewer/common/view_model/view_model_decorations.mbt`, `MLP` =
`viewer/common/view_model/model_line_projection.mbt`, and `VLD` =
`viewer/common/view_model/view_line_data.mbt`.

| ID | Kind | Declaration | Exact production callers | Exact test callers | Target disposition |
|---|---|---|---|---|---|
| API-001 | Callable | `is_model_decoration_visible` (`MBTI:11`) | Direct call at `ID:273`; no external caller. | No direct call; reached through `get_decorations` at `IDT:240,267,303,336,369,404,447,482,515,552-553,575,577`. | Private concrete helper; retain the visibility deferral at its definition. |
| API-002 | Data type | `InjectedTextContext` (`MBTI:16-22`) | Child computer field/constructor at `ID:470,476`; the live production computer uses a distinct private context at `MLP:566-572`. | Eleven literal contexts at `IDT:618,644,671,694,728,765,805,845,878,912,946`. | Consolidate into the existing private production context. |
| API-003 | Data type | `InjectedTextInlineDecorationsComputer` (`MBTI:24-26`) | No external caller; the live type at `MLP:578-580` is a distinct private declaration. | Eleven construction/use spans: `IDT:629-632,651-654,678-681,701-704,735-738,772-775,812-815,852-855,885-888,919-922,953-956`. | One private canonical computer beside model-line projection. |
| API-004 | Callable | `InjectedTextInlineDecorationsComputer::get_inline_decorations` (`MBTI:27`) | None. | `IDT:632,654,681,704,738,775,815,855,888,922,956`. | Private canonical method; preserve all eleven source tests. |
| API-005 | Callable | `InjectedTextInlineDecorationsComputer::new` (`MBTI:28`) | None. | `IDT:629,651,678,701,735,772,812,852,885,919,953`. | Private primary constructor renamed to `Type::Type`. |
| API-006 | Data type | `InjectedTextOptions` (`MBTI:30-34`) | Child context/computer only at `ID:459,509`; canonical production uses `@model.InjectedTextOptions` at `MLP:527-540,567,621`. | Context annotation at `IDT:621`; values at `IDT:639,669,688,719,723,760,800,840,873,907,941`. | Remove as a public product type; use canonical model options plus a private wbtest adapter if spacing requires it. |
| API-007 | Callable | `InjectedTextOptions::new` (`MBTI:35`) | None. | `IDT:639,669,688,719,723,760,800,840,873,907,941`. | Remove or retain only as a private wbtest-adapter constructor. |
| API-008 | Data type | `InlineDecoration` (`MBTI:37-41`) | Child values at `ID:191,234,265,288,310,333,487,492,500,559`; projection at `MLP:472,595,603,612,658,688`; renderer input at `VLD:136`. | Equality helper `IDT:205-206`; 24 constructions at `IDT:271,306,339,372,407,412,417,448,518,525,605,657,707,741,746,781,788,820,827,861,891,926,960,967`. | Package-private `view_model` value. |
| API-009 | Callable | `InlineDecoration::new` (`MBTI:42`) | `ID:288,310,333,559`; live projection call at `MLP:658`. | The 24 calls listed in API-008. | Private primary constructor renamed to `Type::Type`. |
| API-010 | Data type | `InlineDecorationType` (`MBTI:44-49`) | Stored/selected at `ID:134,142,283-286,318,341,553-556`; renderer maps it at `VLD:153,181-187`. | Expected variants at `IDT:274,309,342,375,410,415,420,451,521,528,608,660,710,744,749,784,791,823,830,864,894,929,963,970`. | Package-private `view_model` enum. |
| API-011 | Data type | `InlineModelContext[O]` (`MBTI:51-53`) | Computer field/constructor at `ID:209,218`; one production context at `VMD:101-114`. | Twelve contexts at `IDT:234,250,285,319,352,385,430,464,490,546,569,585`. | Concrete private context returning canonical model decorations. |
| API-012 | Data type | `InlineModelDecorationsComputer[O,M,C]` (`MBTI:55-57`) | Field/construction/calls at `VMD:82-86,116-118,136,145,154,192,202`. | Twelve constructions at `IDT:237,264,300,333,366,401,444,479,512,549,572,599`, followed by API-013/014/018 calls. | Concrete package-private computer with no type parameters. |
| API-013 | Callable | `InlineModelDecorationsComputer::get_decorations` (`MBTI:58`) | Child wrapper `ID:244`; view-model paths `VMD:192,202`. | `IDT:240,267,303,336,369,404,447,482,515,552,553,575,577`. | Private concrete method. |
| API-014 | Callable | `InlineModelDecorationsComputer::get_inline_decorations` (`MBTI:59`) | None outside its declaration. | One call at `IDT:602`. | Private test-retained method. |
| API-015 | Callable | `InlineModelDecorationsComputer::new` (`MBTI:60`) | `VMD:116-118`. | `IDT:237,264,300,333,366,401,444,479,512,549,572,599`. | Private primary constructor renamed to `Type::Type`. |
| API-016 | Callable | `InlineModelDecorationsComputer::on_line_mapping_changed` (`MBTI:61`) | `VMD:154`. | None. | Private lifecycle method. |
| API-017 | Callable | `InlineModelDecorationsComputer::on_model_decorations_changed` (`MBTI:62`) | `VMD:145`. | None. | Private lifecycle method. |
| API-018 | Callable | `InlineModelDecorationsComputer::reset` (`MBTI:63`) | `VMD:136`; called internally by API-016/API-017 at `ID:373,381`. | Cache-identity reset at `IDT:576`. | Private lifecycle method. |
| API-019 | Data type | `ModelDecoration[O]` (`MBTI:65-70`) | Child signatures at `ID:180,200,392`; boundary copies at `VMD:220,316,355`. | Helper return at `IDT:13`; calls at `IDT:253,288,322,355,388,433,467,493,501,538,561,588`. | Delete; pass canonical `@model.ModelDecoration` directly. |
| API-020 | Data type | `ViewDecorationsCollection[O]` (`MBTI:72-76`) | Child result `ID:258`; alias/cache/returns `VMD:29-31,87,164,185,201`; `VLD:198-207`; `viewport_data.mbt:55-85`; overlay reads `view_overlays_lifecycle.mbt:135-138,391-394`. | Child assertions `IDT:241-243,268-278,304,337,370,405,453,483,516,554,578`; downstream tests `view_model_viewport_test.mbt:109-114`, root `test_viewer_wbtest.mbt:224-252`, and `view_event_sources_wbtest.mbt:332,340`. | Concrete non-generic public `view_model.ViewDecorationsCollection`. |
| API-021 | Data type | `ViewModelDecoration[O]` (`MBTI:78-81`) | Child cache/result `ID:190,212,264,393,430`; alias `VMD:24-26`; consumers `margin_decorations.mbt:29` and browser `decorations.mbt:41-42,89,112,148,334`. | Cache identity `IDT:554,578`; explicit values `margin_decorations_wbtest.mbt:22,31` and browser `decorations_wbtest.mbt:17,49`; option reads `view_model_viewport_test.mbt:112` and root `test_viewer_wbtest.mbt:252`. | Concrete non-generic public `view_model.ViewModelDecoration`. |
| API-022 | Callable | `ViewModelDecoration::new` (`MBTI:82`) | Only `ID:430`. | No direct call; reached through nonempty `get_decorations` cases. | Private primary constructor renamed to `Type::Type`. |
| API-023 | Open trait | `CoordinatesConverter` (`MBTI:87-90`) | Generic constraints `ID:230,252,389`; only production impl `VMD:61-76`. | Only test impl `IDT:101-118`. | Delete; call concrete `view_model.CoordinatesConverter`. |
| API-024 | Open trait | `InlineDecorationOptions` (`MBTI:92-99`) | Generic constraints `ID:228,250,387`; canonical impl `ID:78-117`. | Only alternate impl `IDT:160-199`. | Delete from production/API; use concrete fields/private resolved test inputs. |
| API-025 | Public impl | `impl InlineDecorationOptions for @model.ModelDecorationOptions` (`MBTI:100`) | Dispatch at `ID:281,283,299,306,323,329,346,400`. | None; suite uses its private impl at `IDT:160-199`. | Delete; use direct canonical reads and explicit deferred constants. |
| API-026 | Open trait | `InlineDecorationsModel` (`MBTI:102-104`) | Generic constraints `ID:229,251,388`; canonical impl `ID:68-73`. | One test impl `IDT:51-56`. | Delete; use concrete `@model.TextModel`. |
| API-027 | Public impl | `impl InlineDecorationsModel for @model.TextModel` (`MBTI:105`) | Dispatch at `ID:239,412`. | None; tests dispatch to `TestTextModel` at `IDT:51-56`. | Delete; call snapshot line geometry directly. |

Every nested public trait requirement is also independently inventoried:

| ID | Trait method requirement | Exact dispatch sites | Production implementation | Test implementation | Target disposition |
|---|---|---|---|---|---|
| TM-001 | `CoordinatesConverter::convert_model_position_to_view_position` (`MBTI:88`) | `ID:405-408,409-415` | `VMD:61-67` | `IDT:101-108` | Direct concrete position conversion; preserve `Left`/`Right`, with `allowZero`/`belowHiddenRanges` still explicitly deferred at this child call boundary. |
| TM-002 | `CoordinatesConverter::convert_model_range_to_view_range` (`MBTI:89`) | `ID:241-243,425-428` | `VMD:70-76` | `IDT:111-118` | Direct concrete range conversion. |
| TM-003 | `InlineDecorationOptions::inline_class_name` (`MBTI:93`) | `ID:281` | `ID:78-82` | `IDT:160-164` | Direct canonical field; private resolved wbtest input. |
| TM-004 | `inline_class_name_affects_letter_spacing` (`MBTI:94`) | `ID:283` | `ID:85-89` | `IDT:167-171` | Direct canonical field. |
| TM-005 | `before_content_class_name` (`MBTI:95`) | `ID:306` | Constant `None`, `ID:92-96` | `IDT:174-178` | Remove public seam; production reach remains deferred. |
| TM-006 | `after_content_class_name` (`MBTI:96`) | `ID:329` | `ID:99-103` | `IDT:181-185` | Direct canonical field. |
| TM-007 | `affects_font` (`MBTI:97`) | `ID:299,323,346` | Constant `false`, `ID:106-110` | `IDT:188-192` | Remove public seam; production reach remains deferred. |
| TM-008 | `is_whole_line` (`MBTI:98`) | `ID:400` | `ID:113-117` | `IDT:195-199` | Direct canonical field. |
| TM-009 | `InlineDecorationsModel::get_line_max_column` (`MBTI:103`) | `ID:239,412` | `ID:68-73` | `IDT:51-56` | Direct snapshot line geometry; private test-model helper only. |

Count proof: API-002/003/006/008/010/011/012/019/020/021 are **10 data
types**; API-023/024/026 are **3 open traits**; API-001/004/005/007/009/013-
018/022 are **12 callables**; and API-025/027 are **2 public impls**. Thus the
top-level interface denominator is **27 = 10 + 3 + 12 + 2**, plus the separate
**9 = 2 + 6 + 1** trait requirements TM-001..TM-009.

`ViewDecorationsCollection` has no downstream textual type spelling because the
alias is inferred from `get_decorations_viewport_data`, but it is real public
data. Browser production reads its `decorations` field in
`viewer/browser/view/view_overlays_lifecycle.mbt:137,393`; view-model viewport
construction and root/view-model tests also consume the result. By contrast,
`ViewModelDecorations::get_decorations_on_line` has no caller anywhere.

## Production-vs-Test Generic Matrix

| Parameter/seam | Production instantiation | Black-box instantiation | White-box instantiation |
|---|---|---|---|
| `O : InlineDecorationOptions` | `@model.ModelDecorationOptions` | Private test `ModelDecorationOptions` | None |
| `M : InlineDecorationsModel` | `@model.TextModel` | Private `TestTextModel` | None |
| `C : CoordinatesConverter` | Concrete `@view_model.CoordinatesConverter` | Private `IdentityCoordinatesConverter` | None |

The only production triple is:

```text
InlineModelDecorationsComputer[
  @model.ModelDecorationOptions,
  @model.TextModel,
  @view_model.CoordinatesConverter
]
```

Every alternate implementation exists solely for the current black-box suite.
The injected-text path has a second representation split:

| Role | Type | Fields |
|---|---|---|
| Actual production projection | `@model.InjectedTextOptions` | `content`, `inline_class_name`, `attached_index` |
| Public but production-dead child computer | child `InjectedTextOptions` | `content`, `inline_class_name`, `inline_class_name_affects_letter_spacing` |

The production projection already owns its private computer/context in
`model_line_projection.mbt`, with integration evidence in
`model_line_projection_reference_wbtest.mbt`. The public child computer is
called only by its black-box reference suite.

## Current and Target Dependency Graphs

No package here declares `supported_targets`; the graph applies to JS, native,
wasm-gc, and all-target checking.

```text
current:

inline_decorations production
  -> base/common
  -> common/model

view_model production
  -> base/common + common/{config,core,cursor,model,tokens,view_layout}
  -> common/inline_decorations
  -> core/json

view_model test/wbtest
  -> production graph
  -> syntax

target:

view_model production
  -> base/common + common/{config,core,cursor,model,tokens,view_layout}
  -> core/json

view_model test/wbtest
  -> production graph
  -> syntax
  -> moved inline reference suite (white-box)
```

Only `viewer/common/view_model/moon.pkg` directly imports the child. Today its
public aliases cause downstream generated interfaces to import the child even
when source manifests name only `view_model`. After the merge, delete the child
manifest, remove the one view-model import, and regenerate concrete
view-model-owned signatures; no new production or target-specific dependency
is required.

## Target Type Map

| Current declaration | Reviewed target |
|---|---|
| `InlineDecorationsModel` | Remove; production reads concrete `@model.TextModel` |
| reduced `CoordinatesConverter` trait | Remove; call the existing concrete local enum directly |
| `InlineDecorationOptions` | Remove from production/API |
| `ModelDecoration[O]` | Remove; use canonical `@model.ModelDecoration` |
| `InlineModelContext[O]` | Concrete package-private context returning canonical model decorations |
| `InlineModelDecorationsComputer[O,M,C]` | Concrete package-private computer |
| generic `ViewModelDecoration[O]` plus alias | Concrete public `view_model.ViewModelDecoration` containing canonical options |
| generic `ViewDecorationsCollection[O]` plus alias | Concrete public `view_model.ViewDecorationsCollection` |
| `InlineDecoration` / `InlineDecorationType` | Package-private view-model values |
| `is_model_decoration_visible` | Private helper with deferred hide branches stated at the definition |
| duplicate injected computer/context | One canonical private implementation beside model-line projection |
| child `InjectedTextOptions` | No public product type; canonical model option, with a private wbtest adapter only if required to retain the source test shape |
| retained primary constructors | `Type::Type`; alternate factories keep descriptive names |

The three source branches whose inputs are absent from canonical production
options—before-content, affects-font, and injected letter spacing—must not
force a public abstraction to survive. A private, non-generic wbtest adapter or
resolved-input helper may keep the exact upstream cases executable, but the
plan closeout must distinguish that algorithm evidence from production
reachability.

## Mechanical Collision Inventory

The move cannot compile as a literal filename copy because the destination
already owns related names. The behavior-neutral relocation milestone must
apply explicit structural renames before API simplification:

1. The moved `CoordinatesConverter` trait collides with the destination's
   canonical concrete enum. Give the moved trait a temporary inline-specific
   name for the mechanical commit, then remove it in the concrete cleanup.
2. Moved generic `ViewModelDecoration` and `ViewDecorationsCollection` collide
   with current public aliases of the same names. Preserve the aliases during
   relocation by temporarily naming the generic definitions, then replace both
   layers with concrete canonical types in Milestone C.
3. `InjectedTextInlineDecorationsComputer` and its context already exist
   privately in `model_line_projection.mbt`. Use a temporary reference/legacy
   name in the relocation commit; consolidate only after the 23-case baseline
   is green.

These are name-only MoonBit package-collision seams. They do not authorize a
control-flow, ordering, constant, or test-denominator change in the mechanical
commit.

Other collision and liveness constraints are:

- `view_layout` owns a distinct renderer `InlineDecoration`/enum over
  line-local `OffsetRange`; after the merge, renderer construction and enum
  cases must be explicitly `@view_layout`-qualified.
- Cache identity is observable: `M10` requires physical object reuse by id.
- Child no-injection uses `None`; production uses an empty array. Consolidation
  must preserve the reviewed early return and callback order.
- Folding produces `after_content_class_name="inline-folded"` and whole-line
  options; both production paths must remain live after trait removal.
- The boundary-only `to_inline_model_decorations` copy must disappear without
  changing hidden-range splitting, sort order, or duplicate elimination.

## Existing Deviations and Proposed Terminal Outcomes

| Source behavior | Current reality | Proposed outcome in this ownership plan |
|---|---|---|
| Comment/string visibility (`VMD-006..022`, `INL-045`) | Token primitives now exist after the model merge, but `hideInCommentTokens`/`hideInStringTokens` option fields and producers do not | `DEFERRED` by this plan's explicit behavior scope; keep the source rows and do not describe constant true as complete parity |
| Whole-line `allowZero=false, belowHiddenRanges=true` (`INL-061`) | Canonical converter exposes affinity only; hidden handling is owned by projection | `DEFERRED`; preserve current conversion and name the missing switches |
| `beforeContentClassName` production reach | Algorithm is tested through the mini options type; canonical model options lack the field | `DEFERRED` for product reach; retain test evidence privately without a public trait |
| `affectsFont` production reach | Algorithm is tested through the mini options type; canonical options lack font fields | `DEFERRED` for product reach; retain private branch evidence |
| injected letter-spacing production reach | Child duplicate passes `I04`; canonical production options have no spacing flag and emit `Regular` | `DEFERRED` for product reach; do not claim the child-only test proves the live path |
| `ViewModelDecorations` validation/font filter timing | Filters are captured at construction; the provider rotates on option changes | Preserve the existing cited seam; no change in this relocation |
| minimap-only view-model query | Query method is unimplemented/deferred with the minimap view part | Preserve the explicit deferral |
| view-model `dispose` | Folded into `reset`; both source bodies are identical for retained state | Preserve as the existing lifecycle reduction |
| projected position-conversion flush clamp | Local conversion validates against the new snapshot, then clamps the line into the still-committed projection array during the synchronous `set_value` notification window | `PORTED` seam; retain the narrow clamp and its existing regression evidence, without changing normal conversion control flow |
| `getLineMaxColumn` liveness/invalid-line contract | Local model has no disposal assertion and its snapshot clamps invalid lines where the source throws | `DEFERRED`; scoped callers provide valid live lines, but do not claim the guard/failure behavior is ported |
| hidden-query previous-id sentinel | Source starts with `null`; local starts with `""` | `PORTED` equivalent under the canonical nonempty `<namespace>;<n>` id invariant; retain the invariant citation beside the loop |

There is no current-pin drift and therefore no drift addendum. Adding any of
the missing option fields or visibility behavior is a separate, reviewed
behavior milestone, not part of the relocation/API cleanup.

## Gate A Review Decision Requested

Approve or revise these five decisions before any product or manifest edit:

1. One concrete production computer uses `TextModel`, the canonical converter,
   canonical model decorations/options, and no public generic trait.
2. Only concrete `ViewModelDecoration` and `ViewDecorationsCollection` remain
   public from the moved cluster; all computers, contexts, inline values, and
   helpers become package-private.
3. The duplicate injected computer is consolidated onto the existing live
   projection owner after a behavior-neutral relocation baseline; private
   wbtest adapters may retain source cases that production options cannot form.
4. The five behavior gaps above stay explicitly deferred; this package move
   does not add option fields, token visibility, or converter switches.
5. The mechanical milestone may use temporary collision-only names, followed
   by the separately committed concrete/API cleanup; source control flow and
   the 23-case denominator remain unchanged throughout.

**Review gate: stop here. Do not move, rename, or rewrite product code until
this inventory, target map, collision protocol, and deviation outcomes are
reviewed.**
