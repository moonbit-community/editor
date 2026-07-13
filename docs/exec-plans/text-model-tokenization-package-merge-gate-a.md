# Text Model and Tokenization Package Merge — Gate A

Status: approved historical inventory — implementation completed 2026-07-13

Date: 2026-07-13

Parent plan: `text-model-tokenization-package-merge.md`

Oracle commit: `b18492a288de038fbc7643aae6de8247029d11bd`

At this Gate A snapshot, no product code, package manifest, generated interface,
test, or README had changed. The user's explicit implementation request approved
this inventory and the shared-state representation. All present-tense ownership
and the final review request below describe that frozen pre-implementation
snapshot; current ownership lives in the parent closeout and living docs.

## Counting Rule and Reused Denominator

One source row owns one declaration, field/property, behavior-changing branch
or early return, source-authored callback, or independently meaningful
constant. Exact named upstream tests are separate rows. Straight-line
assignments stay on their owning member row.

The complete tokenization behavior denominator was already inventoried,
implemented, independently reviewed, and frozen in
`viewer-tokenization-parity.md`. The scoped source files have the same SHA-256
hashes at the same pinned oracle, so this structural plan reuses those exact
terminal rows instead of copying them. The only addition is `ANI-001..079`,
which closes the parts of the complete current `annotations.ts` unit that the
behavior plan explicitly excluded.

| Scoped source/test | Reused rows | Rows | TESTED | PORTED | DEFERRED | N-A |
|---|---|---:|---:|---:|---:|---:|
| `tokenizationTextModelPart.ts` | `TPM-001..082` | 82 | 27 | 7 | 46 | 2 |
| `abstractSyntaxTokenBackend.ts` | `ASB-001..078` | 78 | 35 | 39 | 0 | 4 |
| `tokenizerSyntaxTokenBackend.ts` | `TSB-001..100` | 100 | 60 | 10 | 21 | 9 |
| `textModelTokens.ts` | `TMS-001..158` | 158 | 108 | 29 | 0 | 21 |
| `textModel.ts` ownership cluster | `TMT-001..040`, `TMT-055..057` | 43 | 21 | 8 | 12 | 2 |
| `textModelTokens.test.ts` | `TMS-REF-001..002` | 2 | 2 | 0 | 0 | 0 |
| represented cases in `model.modes.test.ts` and `textModelWithTokens.test.ts` | `UTM-001..016` | 16 | 3 | 0 | 2 | 11 |
| complete `annotations.ts` structural overlay | `ANI-001..079` below | 79 | 5 | 3 | 0 | 71 |
| **Total** |  | **558** | **261** | **96** | **81** | **120** |

There are zero `TODO` or bare `PASS` rows. The `TMT` subset is limited to the
named `textModel.ts` construction, forwarding, content, attachment, language,
and disposal cluster; `model.ts` interface rows from the frozen behavior plan
are not double-counted here. The exact test subset is the set represented by
the local reference suites; unrelated bracket-matching and indentation-guide
tests in `textModelWithTokens.test.ts` are sibling ownership, not silently
claimed tokenization rows.

### Pinned evidence

| Source | SHA-256 |
|---|---|
| `common/model/textModelTokens.ts` | `51de38e743ab96052aa1e3bd56c99d7ed316b165cf2f0c55f7a555620aa25e58` |
| `common/model/tokens/tokenizationTextModelPart.ts` | `0106c368ab941b0073d55aee16504b5f2dfc573a83b63fe7cdec685b296d1aa4` |
| `common/model/tokens/abstractSyntaxTokenBackend.ts` | `f5cf9516dcdb5708c6b1d5946b64d8609412b502e91d6831bf773da6550deae3` |
| `common/model/tokens/annotations.ts` | `d9a070310a5b5f919289128368ac743628ebfb67cfa0fb126492b324552d71aa` |
| `common/model/tokens/tokenizerSyntaxTokenBackend.ts` | `4fe354033f398254b1f6c37bef3f3484c4f418fa195bdf61c4f664fe57346fc0` |
| `common/model/textModel.ts` | `3ccef30b2902046ff93d99b5d9cd03ae2748785e099d123cf519aa5527d0b622` |
| `test/common/model/textModelTokens.test.ts` | `a77feefcdecd34dc0c322f436bc868877a6e5173a907097ab3efab89b09c5f88` |
| `test/common/model/textModelWithTokens.test.ts` | `32d3c44edfa1512a9ec5e1259a162c15f1b42d29e72c71329ef089ad5c8e7a41` |
| `test/common/model/model.modes.test.ts` | `5b36d602af53516ea3e04a4b254cb574a0998a241d1dc45f22402636b1dbc598` |

## Complete `annotations.ts` Overlay

The local product consumes only the ordered `AnnotationsUpdate<T>` payload for
syntactic font-token events. It has no mutable annotated-string owner,
incremental edit API, worker serialization transport, or deserialization
boundary. Those complete sibling clusters remain explicit N-A rows; they are
not absent from the denominator.

| ID | Source atom | Exact transition / local disposition | Status |
|---|---|---|---|
| ANI-001 | `IAnnotation<T>` (`annotations.ts:10-13`) | Mutable annotated-string value contract has no local owner. | N-A (no local annotated-string store) |
| ANI-002 | `IAnnotation.range` (`:11`) | Half-open stored annotation range. | N-A (same seam) |
| ANI-003 | `IAnnotation.annotation` (`:12`) | Required stored value, unlike an optional update. | N-A (same seam) |
| ANI-004 | `IAnnotatedString<T>` (`:15-37`) | Complete mutable annotated-string interface. | N-A (no local annotated-string store) |
| ANI-005 | `setAnnotations` (`:20`) | Apply ordered non-overlapping updates. | N-A (same seam) |
| ANI-006 | `getAnnotationsIntersecting` (`:24`) | Query intersecting stored annotations. | N-A (same seam) |
| ANI-007 | `getAllAnnotations` (`:28`) | Test-facing snapshot of all stored annotations. | N-A (same seam) |
| ANI-008 | `applyEdit` (`:33`) | Rebase annotations through a string edit. | N-A (readonly model has no incremental edit API) |
| ANI-009 | `clone` (`:37`) | Shallow cloned mutable store. | N-A (no local annotated-string store) |
| ANI-010 | `AnnotatedString<T>` class (`:40`) | Concrete mutable implementation. | N-A (no local annotated-string store) |
| ANI-011 | `_annotations` field (`:45`) | Ordered, non-intersecting contiguous array, initially empty. | N-A (same seam) |
| ANI-012 | constructor/default (`:47-49`) | Retains caller array; default is `[]`. | N-A (same seam) |
| ANI-013 | `setAnnotations` member (`:56-67`) | Replaces/removes every update in order. | N-A (same seam) |
| ANI-014 | update loop (`:57-66`) | Preserve caller update order. | N-A (same seam) |
| ANI-015 | start-index lookup (`:58`) | Compute first intersecting slot from update start. | N-A (same seam) |
| ANI-016 | end-index lookup (`:59`) | Compute exclusive final intersecting slot from update end. | N-A (same seam) |
| ANI-017 | present/undefined decision (`:60-65`) | Present value replaces; undefined removes. | N-A (same seam) |
| ANI-018 | present splice (`:61`) | Replace the intersecting span with one exact update. | N-A (same seam) |
| ANI-019 | undefined splice (`:63`) | Remove the intersecting span without insertion. | N-A (same seam) |
| ANI-020 | `getAnnotationsIntersecting` (`:71-75`) | Slice from computed start through exclusive end. | N-A (same seam) |
| ANI-021 | query slice bounds (`:72-74`) | Use range start/endExclusive without widening. | N-A (same seam) |
| ANI-022 | `_getStartIndexOfIntersectingAnnotation` (`:77-99`) | Binary-search left intersection boundary. | N-A (same seam) |
| ANI-023 | start binary-search callback (`:79-81`) | Compare annotation start minus requested offset. | N-A (same seam) |
| ANI-024 | exact-start decision (`:83-90`) | Nonnegative result selects exact insertion slot. | N-A (same seam) |
| ANI-025 | touching-left branch (`:85-89`) | If candidate end equals offset, decrement start index. | N-A (same seam) |
| ANI-026 | negative-search arm (`:90-97`) | Inspect the prior candidate after insertion-point encoding. | N-A (same seam) |
| ANI-027 | containing-candidate branch (`:91-93`) | Reuse prior index iff `start <= offset < endExclusive`. | N-A (same seam) |
| ANI-028 | start insertion fallback (`:94-95`) | Otherwise use decoded insertion index. | N-A (same seam) |
| ANI-029 | `_getEndIndexOfIntersectingAnnotation` (`:101-123`) | Binary-search right intersection boundary. | N-A (same seam) |
| ANI-030 | end binary-search callback (`:103-105`) | Compare annotation endExclusive minus offset. | N-A (same seam) |
| ANI-031 | exact-end decision (`:107-114`) | Nonnegative result starts at exact index plus one. | N-A (same seam) |
| ANI-032 | touching-right branch (`:109-113`) | If next start equals offset, increment exclusive end. | N-A (same seam) |
| ANI-033 | negative end-search arm (`:114-121`) | Inspect decoded candidate to the right. | N-A (same seam) |
| ANI-034 | right-candidate branch (`:115-117`) | Include iff `start <= offset <= endExclusive`. | N-A (same seam) |
| ANI-035 | end insertion fallback (`:118-119`) | Otherwise use decoded insertion index. | N-A (same seam) |
| ANI-036 | `getAllAnnotations` (`:128-130`) | Return a shallow array copy. | N-A (same seam) |
| ANI-037 | `applyEdit` member (`:137-227`) | Full annotation rebase algorithm. | N-A (readonly model has no incremental edit API) |
| ANI-038 | initial array copy (`:138`) | Work on a snapshot before replacing owner state. | N-A (same edit seam) |
| ANI-039 | replacement loop (`:146-210`) | Apply replacements in source order with cumulative offset. | N-A (same edit seam) |
| ANI-040 | before-edit loop missing-item break (`:147-152`) | Stop when no annotations remain. | N-A (same edit seam) |
| ANI-041 | before-edit overlap break (`:153-156`) | Stop shifting once range end reaches edit start. | N-A (same edit seam) |
| ANI-042 | shifted-before empty decision (`:157-163`) | Nonempty goes final; empty goes deleted. | N-A (same edit seam) |
| ANI-043 | intersecting loop missing-item break (`:167-171`) | Stop when no annotations remain. | N-A (same edit seam) |
| ANI-044 | nonintersecting break (`:172-175`) | Stop at first range not touching replacement. | N-A (same edit seam) |
| ANI-045 | intersecting collection (`:176-177`) | Shift and append each intersecting annotation. | N-A (same edit seam) |
| ANI-046 | reverse intersecting loop (`:180-207`) | Requeue from right to left to preserve source order. | N-A (same edit seam) |
| ANI-047 | `shouldExtend` decision (`:184-185`) | Only first true overlap absorbs inserted text. | N-A (same edit seam) |
| ANI-048 | overlap shrink/grow formula (`:186-188`) | Subtract overlap and conditionally add inserted length. | N-A (same edit seam) |
| ANI-049 | ahead-of-edit shift (`:190-194`) | Positive start delta moves range left to edit start. | N-A (same edit seam) |
| ANI-050 | nonextended inserted-text shift (`:196-199`) | Nonextended range at/after edit start moves after new text. | N-A (same edit seam) |
| ANI-051 | double-count compensation (`:201-206`) | Remove current edit delta before unshifting. | N-A (same edit seam) |
| ANI-052 | cumulative offset (`:209`) | Add `newText.length - replaceRange.length`. | N-A (same edit seam) |
| ANI-053 | trailing loop/missing-item break (`:212-216`) | Drain remaining annotations until empty. | N-A (same edit seam) |
| ANI-054 | shifted-trailing empty decision (`:217-223`) | Nonempty goes final; empty goes deleted. | N-A (same edit seam) |
| ANI-055 | commit and return (`:225-226`) | Replace owner array, return deleted annotations. | N-A (same edit seam) |
| ANI-056 | `clone` member (`:232-234`) | Construct from a shallow array copy. | N-A (no local annotated-string store) |
| ANI-057 | `IAnnotationUpdate<T>` (`:237-240`) | Range plus optional set/remove value; frozen `FNT-008`. | PORTED |
| ANI-058 | update `range` (`:238`) | Preserve exact half-open range; frozen `FNT-009`. | TESTED |
| ANI-059 | update `annotation` (`:239`) | `Some` sets, `None` clears; frozen `FNT-010`. | TESTED |
| ANI-060 | `DefinedValue` (`:242`) | Serialization value bound. | N-A (no worker serialization transport) |
| ANI-061 | `ISerializedAnnotation` (`:244-247`) | Serialized range/value contract. | N-A (same serialization seam) |
| ANI-062 | serialized `range.start/endExclusive` (`:245`) | Two exact integer endpoints. | N-A (same serialization seam) |
| ANI-063 | serialized optional `annotation` (`:246`) | Undefined carries removal. | N-A (same serialization seam) |
| ANI-064 | `AnnotationsUpdate<T>` class (`:249`) | Ordered update collection; frozen `FNT-011`. | PORTED |
| ANI-065 | static `create` (`:251-253`) | Wrap exact caller order; frozen `FNT-012`. | TESTED |
| ANI-066 | `_annotations` field (`:255`) | Private exact array; frozen `FNT-013`. | PORTED |
| ANI-067 | private constructor (`:257-259`) | Retain caller array; frozen `FNT-014`. | TESTED |
| ANI-068 | `annotations` getter (`:261-263`) | Return stored updates; frozen `FNT-015`. | TESTED |
| ANI-069 | `rebase` member (`:265-269`) | Build mutable store, apply edit, read all updates. | N-A (readonly model has no incremental edit API) |
| ANI-070 | rebase call sequence (`:266-268`) | Construct -> apply -> replace in exact order. | N-A (same edit seam) |
| ANI-071 | `serialize` member (`:271-279`) | Map updates through a caller serializer. | N-A (no worker serialization transport) |
| ANI-072 | serialize map callback (`:272-278`) | Preserve ordered update count and ranges. | N-A (same serialization seam) |
| ANI-073 | serialize missing-value branch (`:274-276`) | Undefined bypasses caller serializer. | N-A (same serialization seam) |
| ANI-074 | serialize present-value branch (`:277`) | Invoke serializer exactly once. | N-A (same serialization seam) |
| ANI-075 | static `deserialize` (`:281-290`) | Reconstruct update collection from serialized values. | N-A (no worker serialization transport) |
| ANI-076 | deserialize map callback (`:282-288`) | Preserve order and rebuild exact `OffsetRange`. | N-A (same serialization seam) |
| ANI-077 | deserialize missing-value branch (`:284-286`) | Undefined bypasses caller deserializer. | N-A (same serialization seam) |
| ANI-078 | deserialize present-value branch (`:287`) | Invoke deserializer exactly once. | N-A (same serialization seam) |
| ANI-079 | deserialize result (`:289`) | Construct update collection from mapped array. | N-A (same serialization seam) |

## Local Ownership Graph

The current graph is:

```text
viewer/common/model.TextModel
  -> TokenizationModelAccess (ten live closure fields)
  -> model/tokens.TokenizationTextModelPart
       -> TokenizerSyntaxTokenBackend
            -> AttachedViews / AttachedViewHandler
            -> TokenizerWithStateStoreAndTextModel
                 -> TrackingTokenizationStateStore
                      -> TokenizationStateStore
                      -> RangePriorityQueueImpl
            -> DefaultBackgroundTokenizer
                 -> TokenizationScheduler
            -> common/tokens.ContiguousTokensStore and token batches

backend token/font/background events
  -> TokenizationTextModelPart
  -> TextModel
  -> common/view_model and root Viewer
```

`TextModel` owns the token part, attached-view aggregate, attachment count,
selected scheduler, disposal guard, and replacement snapshot. The token part
owns its backend and subscriptions. The backend owns stores/workers and
borrows the model facts through `TokenizationModelAccess`. `ViewModel` owns an
attached-view handle but not the aggregate or token backend.

## `TokenizationModelAccess` Field Inventory

`moon ide find-references` confirms that every reader is inside the token
package; the sole production constructor is
`viewer/common/model/text_model.mbt`. After the merge, no cross-package caller
requires this carrier.

| Live fact | Producer/update point | Current consumers | Freshness/order requirement | Reviewed target |
|---|---|---|---|---|
| line count | `tokenization_snapshot`, replaced before flush delivery | validation, reset ranges, default worker, refresh clamps | read after replacement snapshot is installed | `TokenizationModelState.snapshot` direct read |
| line content | same replacement snapshot | stateful tokenization, heuristics, line-token reads | never snapshot a line array; read at demand time | state direct read |
| line length | same replacement snapshot | strict 2048 cheapness test, token-store callback | UTF-16 length at call time | state direct read |
| first non-whitespace column | same replacement snapshot | backward likely-relevant-line scan | read each scanned line at call time | state direct read |
| language id | normalized constructor value | registry filtering, fallback encoding, token reads | fixed for the current readonly language seam | immutable state field |
| attached count | increment/decrement in `on_before_attached/detached` | idle scheduling guards | source-order post-transition reads | mutable state field |
| too-large flag | strict constructor thresholds | tokenization initialization | constructor-fixed forever | immutable state field |
| disposing flag | true before will-dispose/token-part disposal; false last | token/font/content event guards | event guards see true throughout disposal | mutable state field |
| selected scheduler | first non-None scheduler in attached epoch; clear after final detach | idle, zero-timeout, delayed work and clock | late install wakes work; final detach cancels before clear | mutable state field |
| unexpected-error reporter | host-neutral constructor closure plus optional test observer | support initialization and tokenization catch paths | report synchronously at catch site | immutable callback field |

## Constructor-Order Representation Spike

Decision proposed for review: use the plan's second allowed shape, one
package-private shared model state owned by `TextModel` and borrowed by the
tokenization part.

```moonbit nocheck
priv struct TokenizationModelState {
  snapshot : Ref[TextSnapshot]
  language_id : String
  attached_count : Ref[Int]
  too_large : Bool
  disposing : Ref[Bool]
  scheduler : Ref[TokenizationScheduler?]
  report_unexpected_error : (String) -> Unit
}
```

Construction order is acyclic:

1. Normalize the text and compute the constructor-fixed large-file fact.
2. Construct `TokenizationModelState` and `AttachedViews`.
3. Construct `TokenizationTextModelPart(state, attached_views)` and its
   backend.
4. Construct `TextModel` with the same state, part, and attached-view owner.

`TextModel.snapshot` remains the public model fact during this plan. On
`set_value`, it and `state.snapshot` are replaced before token content
handling, preserving the current live-read ordering. Attachment, scheduler,
and disposal methods mutate the shared state at their existing source-order
points. Token code reads state fields directly. There is no partial
`TextModel`, optional late back-reference, model-id lookup, closure bundle, or
second source of mutable ownership.

The state is not a renamed `TokenizationModelAccess`: it has no query closures,
no public methods, no generated-interface surface, and no package-boundary
purpose. It is the minimum construction-safe representation of the facts that
the source backend reads from its owning `TextModel`.

## Public Caller Inventory

The exact pre-change public denominator is the 221 `pub`/public-field lines in
`viewer/common/model/tokens/pkg.generated.mbti` (SHA-256
`384bfdf37ed40ce86e5e5b9021abd007749b0376e65b14b43575e0156fca5f84`).
The table below accounts for every contiguous interface range. Exceptions are
named explicitly; every unlisted declaration in a row has only package-local
production callers or no caller. The evidence commands were
`moon ide analyze viewer/common/model/tokens` and targeted
`moon ide find-references` for every nonzero external cluster.

| Interface lines | Current caller classification | Merge/API target |
|---|---|---|
| 12-56 constants/theme/encoders | production: `default_token_color_map` -> `viewer/selection.mbt`; `line_tokens_from_lexer_tokens` -> hover; white-box: `tag_to_metadata`; all others package-local/no external caller | keep the two downstream functions public; make implementation/test-only helpers private after relocation |
| 61-69 `AbstractSyntaxTokenBackend` | package-local production only; no external consumer | private implementation |
| 71-80 annotation update types | package-local production and token white-box tests only | private unless required by a retained public font-event signature |
| 82-89 `AttachedViewHandler` | package-local production only | private implementation |
| 91-96 `AttachedViewImpl` | production: model attach API, `ViewModel`, root viewer; `set_visible_lines` from `common/view_model`; white-box tests also read `state` | retain the downstream handle/method surface; private `state`/`same` if caller migration proves unnecessary |
| 98-108 attached state/change carriers | package-local production; white-box tests and root restore-state wbtest read state | private production carrier; test-only inspection moves to white-box seams |
| 110-118 `AttachedViews` | production only from current parent model package plus token internals; token wbtests | private after packages merge |
| 120-123 background state enum | package-local production and token wbtests | private unless a retained public token-part method still exposes it |
| 125-143 background stores/workers | package-local production and token wbtests | private implementation |
| 145-184 encoded/state/helper carriers | package-local production; `InternalTokenizationSupportAdapter::new` and result fields are white-box-only | private; keep no test seam in generated API |
| 186-188 font-token event | package-local production only | private unless retained public listener requires the payload |
| 190-198 token event/range | production: `TextModel`, `viewer/attach_model.mbt`, `common/view_model/{cursor_event_dispatcher,model_tokens_outgoing}`; white-box tests in model/view-model/token packages | retain as the model/view-model event contract |
| 200-210 range queue | black-box conformance only through the current parent alias; internal token production | make private and move the reference suite to white-box ownership; remove parent alias |
| 212-214 token-store change | package-local production only | private implementation |
| 216-220 idle deadline | production: root browser host and default worker; white-box schedulers | retain public because root JS host supplies the scheduler |
| 222-235 `TokenizationModelAccess` | production constructor in current parent model; all readers package-local; token wbtests construct doubles | remove entirely; replace with private shared state and move doubles to package-private helpers |
| 237-244 scheduler | production: root browser host and model attachment; token/model white-box tests | retain public host-neutral scheduling contract |
| 246-251 raw state store | package-local production only | private implementation |
| 253-275 token model part | production: parent `TextModel`, view-model line projection, selection HTML; black-box model/viewer tests and token wbtests | retain only downstream-used part methods public; constructor/lifecycle/backend glue becomes private after merge |
| 277-300 concrete tokenizer backend | package-local production and token wbtests | private implementation |
| 302-336 stateful tokenizer/store types | package-local production and token wbtests | private implementation |
| 338-341 visible-line request | production: `common/view_model/visible_token_ranges.mbt`; token tests | retain as downstream attach contract until the later public API plan decides canonical ownership |
| 344 font-update alias | package-local production only | private implementation |

There is no ordinary external black-box consumer other than the range-queue
reference suite and black-box tests that exercise token-part behavior through
`TextModel`. No declaration is kept public solely because a white-box double
currently lives across the package boundary.

## Before/After Package Dependency Graph

All packages remain multi-target. No browser, DOM, JS-only, contribution, or
shell dependency moves into the model package.

```text
BEFORE
  common/model
    -> base/common
    -> common/model/tokens
         -> base/common
         -> syntax
         -> common/services
         -> common/tokens -> base/common + common/services

  common/view_model -> common/model + common/model/tokens
  root viewer       -> common/model + common/model/tokens
  contrib/hover     -> common/model + common/model/tokens

AFTER
  common/model
    -> base/common
    -> syntax
    -> common/services
    -> common/tokens -> base/common + common/services

  common/view_model -> common/model
  root viewer       -> common/model
  contrib/hover     -> common/model
```

The union introduces no cycle: `syntax`, `common/services`, and
`common/tokens` do not import `common/model`. Current test-mode imports remain
available in the merged manifest; package-local reference/white-box tests move
with their source files.

## Mechanical Move and Collision Inventory

The token package has these production source units, all with unique target
names: `abstract_syntax_token_backend.mbt`, `annotations.mbt`,
`line_tokens_encoder.mbt`, `text_model_tokens.mbt`, `token_theme.mbt`,
`tokenization_access.mbt`, `tokenization_text_model_part.mbt`, and
`tokenizer_syntax_token_backend.mbt`.

One collision is intentional:

- parent `viewer/common/model/text_model_tokens.mbt` is only the
  `RangePriorityQueueImpl` compatibility alias;
- child `viewer/common/model/tokens/text_model_tokens.mbt` is the canonical
  implementation and takes the parent filename;
- the alias file disappears in the mechanical merge rather than being
  renamed or wrapped.

All associated `_wbtest.mbt` files have unique names. The parent black-box
`text_model_tokens_reference_test.mbt` becomes the source-adjacent white-box
reference suite when the queue visibility is reduced.

## Review Decision Requested

Approve or reject the package-private `TokenizationModelState` shape and the
caller/visibility targets above. On approval, Milestone B begins with a
behavior-neutral file/manifest move and a separate green commit before the
closure carrier is removed. Until then, the repository remains at Gate A.
