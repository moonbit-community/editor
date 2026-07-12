# Viewer Tokenization Parity

Status: inventory ready — STOP FOR REVIEW

Date: 2026-07-13

Oracle commit: b18492a288de038fbc7643aae6de8247029d11bd

Parent: viewer-monaco-parity-remediation.md

Finding: P1-11

Depends on: viewer-model-lifecycle-ownership-parity.md and
viewer-text-buffer-eol-parity.md

No product or test code may change until this documentation-only inventory
candidate is committed and independently approved at Gate B. Every counted row
below remains `TODO`; the terminal column is only the proposed disposition.

## Goal and Approved Boundary

Remove synchronous whole-document tokenization from model attach and port the
readonly-applicable Monaco syntactic lifecycle: passive per-line reads,
explicit/visible/background demand, carried state, invalid ranges, stores,
registry updates, exact token/font events, attached-view priority, browser
scheduling, large-file disabling, and disposal/cancellation.

Gate A approved Option B: syntactic scheduling lands in this child, while the
semantic overlay remains `DEFERRED` to
`viewer-semantic-token-acquisition-application-parity.md`. Semantic rows are
not N-A merely because Viewer is readonly. The large-file as-is collection is
separately deferred to
`viewer-large-file-view-collection-parity.md`; this child keeps projected
collections for large models as a documented P2 performance deviation while
disabling tokenization at the source thresholds.

## Gate-B Counting Rule

A counted source row owns one declared type/member/field/interface property,
source-authored callback, behavior-changing branch/loop/early return, or
independently meaningful constant. Exact named upstream tests are separate
counted rows. Every counted row has a unique ID, exact pinned source atom,
concrete local target/seam, `Status = TODO`, and one separate proposed
terminal. Local coordination rows use `LOC-*` and do not enter the
source/test denominator. There are no `PASS` rows.

## Phase 0 — Pinned Source Scope

Complete units:

- `common/model/tokens/tokenizationTextModelPart.ts`
- `common/tokenizationTextModelPart.ts`
- `common/model/tokens/tokenizerSyntaxTokenBackend.ts`
- `common/model/tokens/abstractSyntaxTokenBackend.ts` AttachedViews,
  AttachedViewState, AttachedViewImpl, AttachedViewHandler, and consumed
  AbstractSyntaxTokenBackend contract
- `common/model/textModelTokens.ts`
- `common/tokens/contiguousTokensStore.ts`
- `common/tokens/sparseTokensStore.ts`
- `common/tokenizationRegistry.ts`

Selected consumed closures:

- `common/languages.ts`: Token/TokenizationResult, IFontToken,
  EncodedTokenizationResult,
  ITokenizationSupport/IState, background contracts, registry interfaces and
  singleton; non-encoded compatibility, Tree-sitter/custom worker, and lazy
  factory arms remain explicit rows
- `common/model/textModel.ts`: token part construction/forwarding/disposal,
  attached ownership/count, and exact large-file gate
- `common/model.ts`: token/attach declarations and complete IAttachedView
- `common/model/textModelPart.ts:8-20`: inherited disposal guard closure
- `common/viewModel/viewModelImpl.ts`: visible-range producer and
  `onDidChangeTokens` conversion/dispatch clusters
- `common/viewModel.ts:48`: stabilization declaration
- `browser/widget/codeEditor/codeEditorWidget.ts:1074-1076`:
  one-time `handleInitialized` stabilization oracle
- `browser/view.ts:673-679`: restore-state stabilization oracle
- `common/viewModel/modelLineProjection.ts` and
  `common/viewModel/viewModelLines.ts`: complete token-demand clusters
- `common/textModelEvents.ts:157-183` and
  `common/model/tokens/annotations.ts:237-240,249-263`: syntactic font payload
- `common/core/ranges/lineRange.ts:51-61`: consumed `LineRange.joinMany`
- `common/model/fixedArray.ts:12-31`: consumed live get/set closure
- `common/languages/nullTokenize.ts:9-16,22-33`: `NullState` and
  `nullTokenizeEncoded`
- `common/tokens/contiguousTokensEditing.ts:8,138-143`: token-array
  sentinel/representation seam
- `base/common/async.ts:1536-1579`: complete consumed browser idle IIFE,
  cancellation, and 15 ms fallback
- `common/tokens/contiguousMultilineTokensBuilder.ts:9,21-41` and
  `common/tokens/contiguousMultilineTokens.ts:17,35-80`, including
  `getLineRange`

Exact upstream tests are inventoried from `model.modes.test.ts`,
`model.test.ts`, `textModelWithTokens.test.ts`,
`textModelTokens.test.ts`, `tokensStore.test.ts`,
`model.line.test.ts`, `modelLineProjection.test.ts`,
`viewModelImpl.test.ts`, and `cursor.test.ts`.

Exact sibling exclusions: editable incremental edit APIs beyond normalized
`set_value`; undo/paste/insertion prediction; semantic provider acquisition
and sparse application; Tree-sitter and custom verification worker
construction; lazy Promise factories; non-token projection/geometry; visual
`FontTokenDecorationsProvider`; broader Monaco view-state shape beyond the
existing scroll-only Viewer API; non-encoded `nullTokenize` at
`nullTokenize.ts:18-20`; annotation `DefinedValue`/`ISerializedAnnotation` at
`annotations.ts:242-247`; and the annotation rebase/serialization cluster
beginning at line 265. Each consumed boundary that can affect scoped behavior
still has a row or named coordination entry.

## Pinned Evidence

| Source | SHA-256 |
|---|---|
| `common/model/tokens/tokenizationTextModelPart.ts` | `0106c368ab941b0073d55aee16504b5f2dfc573a83b63fe7cdec685b296d1aa4` |
| `common/tokenizationTextModelPart.ts` | `80f706bd39e72f3feca28b601f7e1d8ff92d17e1e3744070b7ef58aaa50fe778` |
| `common/model/tokens/tokenizerSyntaxTokenBackend.ts` | `4fe354033f398254b1f6c37bef3f3484c4f418fa195bdf61c4f664fe57346fc0` |
| `common/model/tokens/abstractSyntaxTokenBackend.ts` | `f5cf9516dcdb5708c6b1d5946b64d8609412b502e91d6831bf773da6550deae3` |
| `common/model/textModelTokens.ts` | `51de38e743ab96052aa1e3bd56c99d7ed316b165cf2f0c55f7a555620aa25e58` |
| `common/languages.ts` | `1d494c67725e1d53f0b4a4b1572012ccd15dd17eaf37ae923a4b2033e531fbc5` |
| `common/tokens/contiguousTokensStore.ts` | `023d0e335d112eb2a215f79c415df38642689c61e1fd8b576278e693018de9cc` |
| `common/tokens/sparseTokensStore.ts` | `bce493e34aaf48ca9b3d783aed8546821b090c055e7ca237d20aa1dc975f7b9a` |
| `common/tokenizationRegistry.ts` | `1fad61c70c831a1f2efb66149f6aa82fc42e443e70e39a8aa6a5f80d345383b4` |
| `common/model/textModel.ts` | `3ccef30b2902046ff93d99b5d9cd03ae2748785e099d123cf519aa5527d0b622` |
| `common/model.ts` | `b4311925776bcf86418b284beb5c07968de12aa1ef3b6b60ebf506d28e82751a` |
| `common/viewModel/viewModelImpl.ts` | `b8b9f80ed51fa64c7baa4589aa99c2e2bab4eb365b025586e78d9b0db8f8e28a` |
| `common/viewModel.ts` | `5d7d8cbb89d5ee636263367ed944d2f2754559f7b556f3603c5e974fae329be5` |
| `common/viewModel/modelLineProjection.ts` | `84b084fce4509507ce7bb95f39e95b64f955b3a945249399db124bb2b4bef1f0` |
| `common/viewModel/viewModelLines.ts` | `788d3145d0cea65c1d0ebfe1b2041dbc1e4f4eb4ddb495608c0f5a54748a3262` |
| `common/textModelEvents.ts` | `fcbcce16a492a431abe1c72f64ed819528095b7e740f49515d10283670943b59` |
| `common/model/tokens/annotations.ts` | `d9a070310a5b5f919289128368ac743628ebfb67cfa0fb126492b324552d71aa` |
| `common/model/fixedArray.ts` | `0b0253e0bf4ea9075896c757d091774b5dc5a4668f5b88886536a81d441bb180` |
| `common/languages/nullTokenize.ts` | `7d43d8f4d6131b30807431bfaded83aef3691ba6beda8ba65f3df1481bc87e29` |
| `common/core/ranges/lineRange.ts` | `253dcefaf8a2fd0cf5bf088ca1e58e08391f6ab47d366da07760e7e8423497fc` |
| `common/tokens/contiguousTokensEditing.ts` | `1336d1028f6748fad47b8ef26bb0ea9e466dd9c616a83ec8064a8c2e5583cfcb` |
| `browser/widget/codeEditor/codeEditorWidget.ts` | `18dd294ed185a29c590df75656f18f27d0cefc8d4d778559db946d447130e5d8` |
| `browser/view.ts` | `22edb04795705b7fc8675ba40d89c448a62141201f1a16b1f20d8b26e82771e2` |
| `common/tokens/contiguousMultilineTokensBuilder.ts` | `28183d4240e976ad017fed7ce5faa50b4deda17bfd5bde0c0b6a0f0fdde3dd06` |
| `common/tokens/contiguousMultilineTokens.ts` | `9e49b3d20c02cd1cc4b4d9bfa130f3d493bafc7dfef0c7dcbe4458bcbbe27970` |
| `common/model/textModelPart.ts` | `e93f718eef480946d7b15e448df8719c1d7ceb5d0b57625b1976c82553923a06` |
| `base/common/async.ts` | `a045bd600b080fe0d4c695ab47f808d5466e03e62682621325abbc118e7891f0` |
| `test/common/model/model.test.ts` | `4c5568f1e8449c129bc88e4bd06a000835102f2fdd38f6a6d9373f4f574c3483` |
| `test/browser/controller/cursor.test.ts` | `73badec15dc0fbf27c06c4c5b80b0da12ccf9e8e624609570d611f96cfadba4c` |
| `test/common/model/tokensStore.test.ts` | `0c46c421b649cc3b29ffee79c7040fa0280c7798626352e35af29a270a949f1d` |
| `test/browser/viewModel/modelLineProjection.test.ts` | `91d9315d287015742f810673bac4a7195beca92aa903a6efc19fe889e271b936` |
| `test/common/model/model.line.test.ts` | `dac2f4792eca2321cbedbfb5415c308e1d1711fba048e3f2f6fbffbdd83c3b18` |
| `test/common/model/textModelTokens.test.ts` | `a77feefcdecd34dc0c322f436bc868877a6e5173a907097ab3efab89b09c5f88` |

## Phase 0 — Local Ownership

Product ownership after Gate B approval:

- `viewer/common/model/text_model.mbt` and
  `viewer/common/model/text_model_tokens.mbt`
- `viewer/common/model/tokens/{annotations,tokenization_text_model_part,abstract_syntax_token_backend,tokenizer_syntax_token_backend,text_model_tokens}.mbt`
- `viewer/common/tokens/{line_tokens,contiguous_tokens_store,contiguous_multiline_tokens,contiguous_multiline_tokens_builder}.mbt`
- `base/common/line_range.mbt`
- `syntax/tokenizer.mbt`
- `viewer/viewer.mbt`, `viewer/attach_model.mbt`,
  `viewer/view_host.mbt`, `viewer/browser_host.mbt`
- `viewer/common/view_model/{view_model,model_line_projection,view_model_lines_projected,visible_ranges,viewport_data}.mbt`
- `viewer/common/view_layout/view_lines_viewport_data.mbt`
- owning package READMEs and generated interfaces only after implementation

Required evidence destinations after approval:

- `viewer/common/model/tokens/model_modes_reference_wbtest.mbt`
- `viewer/common/model/tokens/text_model_tokens_wbtest.mbt`
- `viewer/common/tokens/contiguous_multiline_tokens_wbtest.mbt`
- `viewer/common/model/tokens/tokenizer_syntax_token_backend_wbtest.mbt`
- `viewer/common/model/tokens/abstract_syntax_token_backend_wbtest.mbt`
- `viewer/common/model/tokens/annotations_wbtest.mbt`
- `viewer/common/model/text_model_tokens_reference_test.mbt`
- `viewer/common/model/model_reference_wbtest.mbt`
- `viewer/common/tokens/tokens_store_reference_wbtest.mbt`
- `viewer/common/view_model/model_line_projection_reference_wbtest.mbt`
- `viewer/common/view_model/view_model_impl_tokenization_reference_wbtest.mbt`
- `viewer/common/view_model/set_value_flush_test.mbt`
- `viewer/cursor_tokenization_reference_wbtest.mbt`
- `viewer/restore_view_state_tokenization_wbtest.mbt`
- `viewer/browser_host_wbtest.mbt`,
  `viewer/common/view_model/viewport_data_test.mbt`, and
  `viewer/common/view_model/view_model_viewport_test.mbt`

## Reviewed Package-Cycle and Adapter Decisions

`TextModel` owns one `TokenizationModelAccess` synchronized carrier. It
contains live normalized lines (replaced before token content handling),
language id, attached count, constructor-fixed too-large fact, disposing fact,
scheduler, and unexpected-error reporter. The model/tokens backend reads only
through this carrier. It is never a frozen copied document. This is the single
reviewed package-cycle deviation from the source's concrete model reference.
Its explicit read surface is line count, line content, UTF-16 line length,
first-non-whitespace column, language id, attached state/count, too-large fact,
and disposing fact. Line content/length/whitespace queries read normalized
model lines directly; they must not route through `ViewLineData`, token reads,
or lexer work.

Do not widen public `syntax.LineTokenizer`. An internal source-shaped adapter
in `viewer/common/model/tokens` supplies raising `initial_state` and
`tokenize(line, has_eol, state)` closures. The registry wraps today's
nonraising tokenizer, ignores `has_eol` only at that reduced public seam, and
tests inject failing and has-EOL-aware internal adapters. The production
wrapper encodes raw start-offset token words; it never constructs end-offset
`LineTokens` and then reconverts them. `safe_tokenize` owns the single
start-to-end offset conversion. `onUnexpectedError`
maps to the access carrier's error reporter. The set-end-state interface shape
is tested directly; accepting custom-worker end states remains deferred.

The FFI-free scheduler contract in model/tokens exposes idle(deadline),
zero-timeout, 50 ms delay, cancellation handles, and now. Viewer supplies the browser
singleton through `onBeforeAttached` before the attached-count transition.
The first scheduler remains selected while multiple viewers in the same JS
realm are attached. Idle/zero calls return cancel handles; the default worker
stores the pending handle plus a generation. On final detach, source-order
`handleDidChangeAttached` notification runs first; that zero-attached handler
then makes the old generation inert, cancels it, and resets `_isScheduled`.
TextModel next detaches the exact view handle, and only afterward does the
caller clear the carrier scheduler. Reattach uses a fresh generation, so an
old callback cannot clear the new scheduling flag. Model disposal cancels
workers/timers.
`scheduler=None` is an explicit enqueue guard: headless models schedule no
idle, zero-timeout, or delayed work. Explicit force and a stabilized-true
visible refresh remain synchronous. Browser tests cover `requestIdleCallback`
and timeout fallback.

TextModel owns and disposes AttachedViews; the token part borrows it. Viewer
calls `onBeforeAttached` before ViewModel construction; ModelData owns the
exact returned handle. Disposal order is listeners, exact
`onBeforeDetached(handle)`, View, then ViewModel. Background attachment uses
TextModel's aggregate attached count, never AttachedViews nonemptiness.

`ContiguousMultilineTokens`, its builder, and `ContiguousTokensStore` live
together in `viewer/common/tokens`, their literal source home. The store takes
a top-level language id plus a line-length read closure; the backend supplies
those live facts through `TokenizationModelAccess`. `common/tokens` never
imports `model/tokens`, so this placement cannot create a reverse package edge.

Syntactic font payloads live below TextModel in
`viewer/common/model/tokens/annotations.mbt`, where backend producers and the
token part use one nominal type. The token part's
`on_did_change_font_tokens` exposes that exact child event to the parent-owned
visual consumer. `AN::FontTokensUpdate` is the source-shaped non-nominal
typealias for `AnnotationsUpdate[FontTokenOption?]`; TextModel adds no parent
alias, mirror, or conversion. Thus `model/tokens` never imports its parent and
the backend -> token part -> parent-consumer path preserves one payload
identity.

Backend aliases used below are exact: `A` =
`viewer/common/model/tokens/abstract_syntax_token_backend.mbt`, `B` =
`viewer/common/model/tokens/tokenizer_syntax_token_backend.mbt`, `MT` =
`viewer/common/model/tokens/text_model_tokens.mbt`, `P` =
`viewer/common/model/tokens/tokenization_text_model_part.mbt`, `M` =
`viewer/common/model/text_model_tokens.mbt`, `S` = `syntax/tokenizer.mbt`, `AN`
= `viewer/common/model/tokens/annotations.mbt`, and `CT` =
`viewer/common/tokens/{contiguous_tokens_store,contiguous_multiline_tokens,contiguous_multiline_tokens_builder}.mbt`.

## Inventory and Parity Ledger


## TPM — complete TokenizationTextModelPart implementation (82 rows)

| ID | Source atom | Transition / exact fact | Local target or seam | Status | Proposed terminal |
|---|---|---|---|---|---|
| TPM-001 | `_semanticTokens` (`tokenizationTextModelPart.ts:32`) | One sparse semantic store for the model part | Preserve `semantic_tokens_applied` and merge seam in `viewer/common/model/tokens/tokenization_text_model_part.mbt` | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md) |
| TPM-002 | `_onDidChangeLanguage` (`:34`) | Private language-change emitter | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — dynamic model-language event seam | TODO | DEFERRED (dynamic model-language ownership outside this child) |
| TPM-003 | `onDidChangeLanguage` (`:35`) | Public event paired with TPM-002 | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — `TextModel` language event exposure | TODO | DEFERRED (dynamic model-language ownership outside this child) |
| TPM-004 | `_onDidChangeLanguageConfiguration` (`:37`) | Private configuration-change emitter | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — model/language configuration seam | TODO | DEFERRED (dynamic language-configuration ownership outside this child) |
| TPM-005 | `onDidChangeLanguageConfiguration` (`:38`) | Public event paired with TPM-004 | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — model/language configuration seam | TODO | DEFERRED (dynamic language-configuration ownership outside this child) |
| TPM-006 | `_onDidChangeTokens` (`:40`) | Private token-range emitter | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — `TokenizationTextModelPart.did_change_tokens` | TODO | TESTED |
| TPM-007 | `onDidChangeTokens` (`:41`) | Public token-range event | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — `on_did_change_tokens` | TODO | TESTED |
| TPM-008 | `_onDidChangeFontTokens` (`:43`) | Registered private syntactic font-token emitter | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — model-part font-token event seam | TODO | PORTED |
| TPM-009 | `onDidChangeFontTokens` (`:44`) | Public/internal syntactic font-token event | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — model-part font-token event seam | TODO | PORTED |
| TPM-010 | `tokens` (`:46`) | Observable active syntax backend with store-owned lifetime | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — live syntactic backend field in the model part | TODO | TESTED |
| TPM-011 | `_useTreeSitter` (`:47`) | Observable backend selector | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — no local Tree-sitter selector | TODO | DEFERRED (no Tree-sitter library/backend-switch dependency) |
| TPM-012 | `_languageIdObs` (`:48`) | Mutable observable language id shared by backends | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — construction-fixed local language id | TODO | DEFERRED (dynamic model-language ownership outside this child) |
| TPM-013 | ctor property `_textModel` (`:51`) | Live model access for line/count/disposal facts | `viewer/common/model/tokens/tokenization_text_model_part.mbt` borrows the single TextModel-owned `TokenizationModelAccess` carrier | TODO | PORTED |
| TPM-014 | ctor property `_bracketPairsTextModelPart` (`:52`) | Receives token/background notifications | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — no local bracket-pair token consumer | TODO | DEFERRED (no bracket-pair token consumer contract) |
| TPM-015 | ctor property `_languageId` (`:53`) | Mutable current language id | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — `language_id` | TODO | PORTED |
| TPM-016 | ctor property `_attachedViews` (`:54`) | Visible/stabilized priority source | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — attached-view protocol introduced under TMT/VMI | TODO | TESTED |
| TPM-017 | ctor property `_languageService` (`:55`) | Provides codec and rich language identity | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — `@services.language_id_codec` plus `@syntax.tokenization_registry` | TODO | PORTED |
| TPM-018 | ctor property `_languageConfigurationService` (`:56`) | Word/configuration source | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — existing `Languages` service is not model-part wired | TODO | DEFERRED (embedded-language word/config integration absent) |
| TPM-019 | ctor property `_instantiationService` (`:57`) | Constructs Tree-sitter backend | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — direct MoonBit construction | TODO | DEFERRED (Tree-sitter backend absent) |
| TPM-020 | ctor property `_treeSitterLibraryService` (`:58`) | Reports observable language support | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — no local service | TODO | DEFERRED (Tree-sitter backend absent) |
| TPM-021 | constructor (`:50-117`) | `super`; create language/backend observables; hook backend events; initial recompute; create stores/emitters in source order | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — `TokenizationTextModelPart::new` plus backend owner | TODO | TESTED |
| TPM-022 | `_useTreeSitter` derived callback (`:64-67`) | Read language id, query `supportsLanguage(languageId, reader)` | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — backend selector seam | TODO | DEFERRED (Tree-sitter backend absent) |
| TPM-023 | `tokens` derived callback (`:69-96`) | Construct one store-owned backend, hook three event classes, return backend | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — live backend construction/reset seam | TODO | TESTED |
| TPM-024 | Tree-sitter/tokenizer branch (`:71-81`) | Tree-sitter when selector true; tokenizer backend otherwise | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — tokenizer arm implemented; Tree-sitter arm blocked | TODO | DEFERRED (Tree-sitter branch lacks provider/service dependency) |
| TPM-025 | syntax-token callback (`:83-85`) | Forward exact token event into model-part emitter | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — `_emit_model_tokens_changed_event` equivalent | TODO | TESTED |
| TPM-026 | font-token callback (`:86-90`) | Forward syntactic font event only while model is not disposing | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — backend -> model-part font-token seam | TODO | TESTED |
| TPM-027 | font callback disposing branch (`:87-89`) | `_isDisposing()==false` fires; disposing drops | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — syntactic font event plus TMT disposal guard | TODO | TESTED |
| TPM-028 | background-state callback (`:92-94`) | Notify bracket-pair part on state transition | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — background state remains exposed; bracket consumer absent | TODO | DEFERRED (no bracket-pair token consumer contract) |
| TPM-029 | recompute callback (`:99-106`) | Initial derived backend does not reset; later dynamic language/Tree-sitter recomputations reset | `viewer/common/model/tokens/tokenization_text_model_part.mbt` dynamic backend-recompute seam | TODO | DEFERRED (dynamic language/Tree-sitter backend recomputation is outside this syntactic fixed-language child) |
| TPM-030 | `hadTokens` branch (`:100-105`) | false on initial derived callback; true thereafter; later recomputation resets before retention | `viewer/common/model/tokens/tokenization_text_model_part.mbt` dynamic backend-recompute state | TODO | DEFERRED (dynamic language/Tree-sitter backend recomputation is outside this syntactic fixed-language child) |
| TPM-031 | second font-emitter assignment (`:115-116`) | Literal choice: allocate/register both source emitters, expose the second emitter after assignment, and dispose both | `viewer/common/model/tokens/tokenization_text_model_part.mbt` font-emitter construction/exposure/disposal | TODO | PORTED |
| TPM-032 | `_hasListeners` (`:119-125`) | OR language/config/token emitters; intentionally exclude font emitter | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — model `_hasListeners` token substep | TODO | TESTED |
| TPM-033 | `handleLanguageConfigurationServiceChange` (`:127-131`) | Filter change by current language | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — model-part config callback | TODO | DEFERRED (dynamic language-configuration ownership outside this child) |
| TPM-034 | `e.affects(languageId)` branch (`:128-130`) | Affected fires `{}`; unaffected does nothing | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — exact affected/unaffected axis | TODO | DEFERRED (dynamic language-configuration ownership outside this child) |
| TPM-035 | `handleDidChangeContent` (`:133-151`) | Update semantic store first, then always forward event to active syntax backend | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — local flush forwarding in `TextModel::emit_content_changed_event` and model part | TODO | TESTED |
| TPM-036 | flush branch (`:134-136`) | Flush sparse semantic tokens | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — semantic store seam | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md) |
| TPM-037 | non-flush/EOL branch (`:136-148`) | Non-EOL edits update sparse tokens; EOL-only edit skips semantic work | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — editable/semantic seam | TODO | DEFERRED (semantic store and incremental edit API absent) |
| TPM-038 | changes loop (`:137-147`) | Process every change in source order with `countEOL` facts | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — future sparse edit application | TODO | DEFERRED (semantic store and incremental edit API absent) |
| TPM-039 | empty-text ternary (`:145`) | First code unit when nonempty, otherwise `CharCode.Null` | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — future sparse edit application | TODO | DEFERRED (semantic store and incremental edit API absent) |
| TPM-040 | `handleDidChangeAttached` (`:153-155`) | Delegate attach-state transition to active backend | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — TextModel attach count -> backend scheduling | TODO | TESTED |
| TPM-041 | syntactic half of `getLineTokens` (`:160-164`) | Validate line, then passively read syntactic stored/default tokens; this member never runs the lexer | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — `viewer/common/model/tokens/tokenization_text_model_part.mbt::get_line_tokens` plus separate read/lexer counters | TODO | TESTED |
| TPM-042 | public-event half of `_emitModelTokensChangedEvent` (`:166-171`) | While live, fire the public token event after the separately owned bracket notification | `viewer/common/model/tokens/tokenization_text_model_part.mbt` exact public event/liveness guard | TODO | TESTED |
| TPM-043 | token-event disposing branch (`:167-170`) | Disposing drops both bracket and public token notifications | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — TMT disposing guard + part event | TODO | TESTED |
| TPM-044 | `validateLineNumber` (`:175-179`) | Valid domain is inclusive `1..getLineCount()` | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — replace current clamp in `get_line_tokens` | TODO | TESTED |
| TPM-045 | invalid-line branch (`:176-178`) | Below 1 or above `lineCount` throws `BugIndicatingError` | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — MoonBit panic boundary | TODO | TESTED |
| TPM-046 | `hasTokens` getter (`:181-183`) | Delegate active backend state | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — model part/backend | TODO | TESTED |
| TPM-047 | `resetTokenization` (`:185-187`) | Delegate `todo_resetTokenization` | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — reset/invalidate all syntax state | TODO | TESTED |
| TPM-048 | `backgroundTokenizationState` getter (`:189-191`) | Delegate exact backend state | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — model part public state | TODO | TESTED |
| TPM-049 | `forceTokenization` (`:193-196`) | validate one line then demand accuracy only through that line | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — change local whole-document no-argument force to per-line | TODO | TESTED |
| TPM-050 | `hasAccurateTokensForLine` (`:198-201`) | validate and query accuracy | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — model part/backend | TODO | TESTED |
| TPM-051 | `isCheapToTokenize` (`:203-206`) | validate and query heuristic | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — model part/backend | TODO | TESTED |
| TPM-052 | `tokenizeIfCheap` (`:208-211`) | validate then conditionally tokenize | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — model part/backend | TODO | TESTED |
| TPM-053 | `getTokenTypeIfInsertingCharacter` (`:213-215`) | Query hypothetical inserted character token type | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — no editable insertion commands | TODO | N-A (readonly Viewer has no insertion prediction surface) |
| TPM-054 | `tokenizeLinesAt` (`:217-219`) | Tokenize hypothetical inserted lines at boundary | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — no editable insertion commands | TODO | N-A (readonly Viewer has no inserted-lines prediction surface) |
| TPM-055 | `setSemanticTokens` (`:225-232`) | Replace sparse store, then emit full-model inclusive range | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — preserve future update seam | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md) |
| TPM-056 | semantic-applied null branch (`:229`) | `tokens!==null` controls event flag | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — existing event field contract | TODO | DEFERRED (semantic producer/update API absent) |
| TPM-057 | `hasCompleteSemanticTokens` (`:234-236`) | Delegate sparse completeness | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — future semantic query | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md) |
| TPM-058 | `hasSomeSemanticTokens` (`:238-240`) | Negate sparse emptiness | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — future semantic query | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md) |
| TPM-059 | `setPartialSemanticTokens` (`:242-259`) | If incomplete, merge partial range, validate changed range, emit exact inclusive result | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — future partial-update seam | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md) |
| TPM-060 | complete-semantic guard branch (`:243-245`) | Complete store skips partial update | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — future semantic branch matrix | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md) |
| TPM-061 | complete-semantic early return (`:244`) | Return before store mutation/event | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — future semantic branch matrix | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md) |
| TPM-062 | `getWordAtPosition` (`:265-314`) | Validate position; obtain line tokens; try right-biased language segment, then left boundary, else null | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — existing simplified `TextModel::get_word_at_position` | TODO | DEFERRED (embedded-language token/config integration absent) |
| TPM-063 | right-word acceptance branch (`:282-288`) | Non-null word must touch original unvalidated column inclusively | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — word helper integration | TODO | DEFERRED (embedded-language token/config integration absent) |
| TPM-064 | right-word early return (`:287`) | Return accepted right-biased word | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — word helper integration | TODO | DEFERRED (embedded-language token/config integration absent) |
| TPM-065 | left-boundary branch (`:291-311`) | Only when `tokenIndex>0` and right segment begins at `position.column-1` | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — embedded-language boundary integration | TODO | DEFERRED (embedded-language token/config integration absent) |
| TPM-066 | left-word acceptance branch (`:304-310`) | Left word must touch original column inclusively | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — embedded-language boundary integration | TODO | DEFERRED (embedded-language token/config integration absent) |
| TPM-067 | left-word early return (`:309`) | Return accepted left-biased word | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — embedded-language boundary integration | TODO | DEFERRED (embedded-language token/config integration absent) |
| TPM-068 | `getLanguageConfiguration` (`:316-318`) | Delegate configuration by token language id | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — `Languages.get_language_configuration` wiring | TODO | DEFERRED (model part has no language-configuration service) |
| TPM-069 | `_findLanguageBoundaries` (`:320-340`) | Read token language, default `[0,lineLength]`, scan same-language run both directions | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — token language-run helper | TODO | DEFERRED (embedded-language token/config integration absent) |
| TPM-070 | left language-run loop (`:324-327`) | Start at token index, decrement through equal language ids, retain each start offset | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — token language-run helper | TODO | DEFERRED (embedded-language token/config integration absent) |
| TPM-071 | right language-run loop (`:330-337`) | Start at token index, increment below token count through equal ids, retain each end offset | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — token language-run helper | TODO | DEFERRED (embedded-language token/config integration absent) |
| TPM-072 | `getWordUntilPosition` (`:342-352`) | Derive prefix of word through requested column | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — existing simplified local word helper | TODO | DEFERRED (depends on full TPM-062 semantics) |
| TPM-073 | no-word branch (`:344-346`) | Missing word returns empty word with start=end=requested column | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — local word helper | TODO | TESTED |
| TPM-074 | no-word early return (`:345`) | Return empty word object immediately | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — local word helper | TODO | TESTED |
| TPM-075 | `getLanguageId` (`:358-360`) | Return current language id | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — `get_language_id` | TODO | TESTED |
| TPM-076 | `getLanguageIdAtPosition` (`:362-366`) | Validate position; demand line tokens; return language id at offset `column-1` | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — line-token language metadata | TODO | DEFERRED (local tokenizer result cannot encode embedded language ids) |
| TPM-077 | `setLanguageId` (`:368-386`) | Default source is literal `api`; equality short-circuit; mutate id/observable; notify bracket then language/config emitters | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — dynamic language seam | TODO | DEFERRED (dynamic model-language ownership outside this child) |
| TPM-078 | same-language branch (`:369-372`) | Equal ids do nothing | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — dynamic language seam | TODO | DEFERRED (dynamic model-language ownership outside this child) |
| TPM-079 | same-language early return (`:371`) | Return before any mutation/request/event | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — dynamic language seam | TODO | DEFERRED (dynamic model-language ownership outside this child) |
| TPM-080 | semantic half of `getLineTokens` (`tokenizationTextModelPart.ts:163`) | Merge sparse semantic tokens over the passively read syntactic line | `viewer/common/model/tokens/tokenization_text_model_part.mbt` retained semantic merge seam | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md owns sparse store and merge) |
| TPM-081 | bracket half of `_emitModelTokensChangedEvent` (`:168`) | Notify bracket-pair token consumer before the public token event | `viewer/common/model/tokens/tokenization_text_model_part.mbt` retained bracket notification seam | TODO | DEFERRED (no bracket-pair token consumer contract) |
| TPM-082 | `TokenizationTextModelPart` class declaration (`tokenizationTextModelPart.ts:31`) | Concrete `TextModelPart` implementation of `ITokenizationTextModelPart` | `viewer/common/model/tokens/tokenization_text_model_part.mbt::TokenizationTextModelPart` | TODO | PORTED |

## ITM — complete public tokenization-model-part interface (21 rows)

| ID | Source atom | Contract | Local target or seam | Status | Proposed terminal |
|---|---|---|---|---|---|
| ITM-001 | `hasTokens` (`tokenizationTextModelPart.ts:15`) | Readonly boolean | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — `has_tokens` | TODO | TESTED |
| ITM-002 | `setSemanticTokens` (`:21`) | Full semantic replacement | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — future semantic update seam | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md) |
| ITM-003 | `setPartialSemanticTokens` (`:27`) | Partial semantic merge; interface admits `null` | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — future semantic update seam | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md) |
| ITM-004 | `hasCompleteSemanticTokens` (`:32`) | Completeness query | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — future semantic query | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md) |
| ITM-005 | `hasSomeSemanticTokens` (`:37`) | Nonempty query | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — future semantic query | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md) |
| ITM-006 | `resetTokenization` (`:43`) | Flush all tokenization state | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — reset/invalidation | TODO | TESTED |
| ITM-007 | `forceTokenization(lineNumber)` (`:49`) | Make one line accurate | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — per-line demand | TODO | TESTED |
| ITM-008 | `tokenizeIfCheap` (`:56`) | Heuristic conditional demand | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — backend heuristic | TODO | TESTED |
| ITM-009 | `hasAccurateTokensForLine` (`:62`) | Accuracy query | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — backend state | TODO | TESTED |
| ITM-010 | `isCheapToTokenize` (`:69`) | Cost query | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — backend state | TODO | TESTED |
| ITM-011 | `getLineTokens` (`:76`) | Potentially inaccurate line read | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — central read seam | TODO | TESTED |
| ITM-012 | `getTokenTypeIfInsertingCharacter` (`:83`) | Hypothetical insertion token type | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — no editable insertion surface | TODO | N-A (readonly Viewer) |
| ITM-013 | `tokenizeLinesAt` (`:89`) | Hypothetical inserted-lines tokens | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — no editable insertion surface | TODO | N-A (readonly Viewer) |
| ITM-014 | `getLanguageId` (`:91`) | Current language id | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — local model part | TODO | TESTED |
| ITM-015 | `getLanguageIdAtPosition` (`:92`) | Embedded token language id | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — line-token metadata | TODO | DEFERRED (local tokenizer result cannot encode embedded language ids) |
| ITM-016 | `setLanguageId` (`:94`) | Dynamic model language | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — no current model mutation surface | TODO | DEFERRED (dynamic model-language ownership outside this child) |
| ITM-017 | `backgroundTokenizationState` (`:96`) | Expose progress/completion state | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — model part/backend | TODO | TESTED |
| ITM-018 | `BackgroundTokenizationState.InProgress=1` (`:100`) | Exact enum value 1 | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — MoonBit enum/state | TODO | TESTED |
| ITM-019 | `BackgroundTokenizationState.Completed=2` (`:101`) | Exact enum value 2 | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — MoonBit enum/state | TODO | TESTED |
| ITM-020 | `ITokenizationTextModelPart` interface declaration (`tokenizationTextModelPart.ts:14-97`) | Declares the complete public tokenization-model-part contract | `viewer/common/model/tokens/tokenization_text_model_part.mbt` public model-part surface | TODO | PORTED |
| ITM-021 | `BackgroundTokenizationState` enum declaration (`:99-102`) | Declares the exact two-state background lifecycle type | `viewer/common/model/tokens/tokenization_text_model_part.mbt::BackgroundTokenizationState` | TODO | PORTED |

## LAN — languages.ts selected contracts/exposure (58 rows)

| ID | Source atom | Contract | Local target or seam | Status | Proposed terminal |
|---|---|---|---|---|---|
| LAN-001 | `backgroundTokenizerShouldOnlyVerifyTokens?` (`languages.ts:121`) | Optional debug verifier flag | `syntax/tokenizer.mbt` / internal model-tokens adapter — no second verifier backend | TODO | DEFERRED (background verifier backend absent) |
| LAN-002 | `ITokenizationSupport.getInitialState` (`:123`) | Produce initial carried state | `syntax/tokenizer.mbt` / internal model-tokens adapter — `LineTokenizer.initial_state` | TODO | TESTED |
| LAN-003 | `ITokenizationSupport.tokenize` (`:125`) | Non-encoded token result with `hasEOL` and cloned input state | `syntax/tokenizer.mbt` / internal model-tokens adapter — local lexer has encoded-production path only | TODO | DEFERRED (non-encoded compatibility result absent) |
| LAN-004 | `ITokenizationSupport.tokenizeEncoded` (`languages.ts:127`) | Internal adapter receives `hasEOL`; registry wrapper ignores it only when calling the reduced public nonraising tokenizer | `syntax/tokenizer.mbt` wrapper + `viewer/common/model/tokens/line_tokens_encoder.mbt::encode_raw_start_offsets`; has-EOL-aware injected adapter test | TODO | TESTED |
| LAN-005 | `ITokenizationSupport.createBackgroundTokenizer?` (`:132`) | Optional custom background tokenizer/store | `syntax/tokenizer.mbt` / internal model-tokens adapter — default local scheduler only | TODO | DEFERRED (custom background tokenizer contract absent) |
| LAN-006 | `IState.clone` (`:173`) | Clone state before tokenization | `syntax/tokenizer.mbt` / internal model-tokens adapter — immutable `TokenizerState` value copy/adaptor | TODO | PORTED |
| LAN-007 | `IState.equals` (`:174`) | Convergence equality | `syntax/tokenizer.mbt` / internal model-tokens adapter — derived `Eq` on `TokenizerState` | TODO | TESTED |
| LAN-008 | exported `TokenizationRegistry` singleton (`:2600`) | One process-wide registry implementing the separately scoped registry contract | `syntax/tokenizer.mbt` / internal model-tokens adapter — `@syntax.tokenization_registry` (`syntax/tokenizer.mbt:174`) | TODO | PORTED |
| LAN-009 | `IFontToken.startIndex` (`languages.ts:72`) | Inclusive token-font start index | `syntax/tokenizer.mbt` / internal model-tokens adapter — syntactic encoded-result font contract | TODO | PORTED |
| LAN-010 | `IFontToken.endIndex` (`:73`) | Token-font end index | `syntax/tokenizer.mbt` / internal model-tokens adapter — syntactic encoded-result font contract | TODO | PORTED |
| LAN-011 | `IFontToken.fontFamily` (`:74`) | Nullable family override | `syntax/tokenizer.mbt` / internal model-tokens adapter — syntactic encoded-result font contract | TODO | PORTED |
| LAN-012 | `IFontToken.fontSizeMultiplier` (`:75`) | Nullable size multiplier | `syntax/tokenizer.mbt` / internal model-tokens adapter — syntactic encoded-result font contract | TODO | PORTED |
| LAN-013 | `IFontToken.lineHeightMultiplier` (`:76`) | Nullable height multiplier | `syntax/tokenizer.mbt` / internal model-tokens adapter — syntactic encoded-result font contract | TODO | PORTED |
| LAN-014 | `EncodedTokenizationResult._encodedTokenizationResultBrand` (`:83`) | TypeScript nominal brand initialized `undefined` | `syntax/tokenizer.mbt` / internal model-tokens adapter — no MoonBit nominal-brand field | TODO | N-A (type-system-only brand) |
| LAN-015 | `EncodedTokenizationResult.tokens` (`:92`) | Binary two-word token array | `syntax/tokenizer.mbt` / internal model-tokens adapter — encoded line-token result/adapter | TODO | TESTED |
| LAN-016 | `EncodedTokenizationResult.fontInfo` (`:93`) | Per-token syntactic font facts | `syntax/tokenizer.mbt` / internal model-tokens adapter — encoded-result/backend store contract | TODO | TESTED |
| LAN-017 | `EncodedTokenizationResult.endState` (`:94`) | State passed to following line | `syntax/tokenizer.mbt` / internal model-tokens adapter — `TokenizerState` result | TODO | TESTED |
| LAN-018 | `EncodedTokenizationResult` constructor (`:85-96`) | Bundle `tokens`, `fontInfo`, and `endState` without side effects | `syntax/tokenizer.mbt` / internal model-tokens adapter — MoonBit encoded-result adapter | TODO | PORTED |
| LAN-019 | `IBackgroundTokenizer.requestTokens` (`:145`) | Ask custom worker to set `[startLineNumber,endLineNumberExclusive)` again | `syntax/tokenizer.mbt` / internal model-tokens adapter — active background backend request seam | TODO | TESTED |
| LAN-020 | `IBackgroundTokenizer.reportMismatchingTokens?` (`:147`) | Optional verifier mismatch callback | `syntax/tokenizer.mbt` / internal model-tokens adapter — no second verifier backend | TODO | DEFERRED (background verifier backend absent) |
| LAN-021 | `IBackgroundTokenizationStore.setTokens` (`:154`) | Apply contiguous multiline token batches | `syntax/tokenizer.mbt` / internal model-tokens adapter — syntactic store update seam | TODO | TESTED |
| LAN-022 | `IBackgroundTokenizationStore.setFontInfo` (`:156`) | Apply syntactic font-token changes | `syntax/tokenizer.mbt` / internal model-tokens adapter — backend store/event contract | TODO | TESTED |
| LAN-023 | `IBackgroundTokenizationStore.setEndState` (`:158`) | Commit one line end state | `syntax/tokenizer.mbt` / internal model-tokens adapter — state store/backend | TODO | TESTED |
| LAN-024 | `IBackgroundTokenizationStore.backgroundTokenizationFinished` (`:164`) | Publish completion for now | `syntax/tokenizer.mbt` / internal model-tokens adapter — background state transition/event | TODO | TESTED |
| LAN-025 | `ITokenizationSupportChangedEvent.changedLanguages` (`:2504`) | Exact affected language-id array | `syntax/tokenizer.mbt` / internal model-tokens adapter — existing local registry event | TODO | TESTED |
| LAN-026 | `ITokenizationSupportChangedEvent.changedColorMap` (`:2505`) | Whether binary token color map changed | `syntax/tokenizer.mbt` / internal model-tokens adapter — registry change-event/color-map seam | TODO | TESTED |
| LAN-027 | `ILazyTokenizationSupport.tokenizationSupport` (`:2512`) | Promise of support or null | `syntax/tokenizer.mbt` / internal model-tokens adapter — no public lazy-factory/Promise support API | TODO | N-A (registry exposes only synchronous support registration) |
| LAN-028 | `ITokenizationRegistry.onDidChange` (`:2552`) | Event for registration/removal/change or color map | `syntax/tokenizer.mbt` / internal model-tokens adapter — `TokenizationRegistry.on_did_change` | TODO | TESTED |
| LAN-029 | `ITokenizationRegistry.handleChange` (`:2558`) | Fire change for explicit embedded-language ids | `syntax/tokenizer.mbt` / internal model-tokens adapter — add exact registry method or source-shaped adapter | TODO | TESTED |
| LAN-030 | `ITokenizationRegistry.register` (`:2563`) | Register support and return disposable | `syntax/tokenizer.mbt` / internal model-tokens adapter — existing local registry | TODO | TESTED |
| LAN-031 | `ITokenizationRegistry.registerFactory` (`:2568`) | Register lazy support factory | `syntax/tokenizer.mbt` / internal model-tokens adapter — no public lazy-factory/Promise support API | TODO | N-A (registry exposes only synchronous support registration) |
| LAN-032 | `ITokenizationRegistry.getOrCreate` (`:2574`) | Resolve support/factory or null | `syntax/tokenizer.mbt` / internal model-tokens adapter — no public lazy-factory/Promise support API | TODO | N-A (registry exposes only synchronous support registration) |
| LAN-033 | `ITokenizationRegistry.get` (`:2580`) | Synchronous support or null | `syntax/tokenizer.mbt` / internal model-tokens adapter — existing local registry | TODO | TESTED |
| LAN-034 | `ITokenizationRegistry.isResolved` (`:2585`) | False only while a factory is pending | `syntax/tokenizer.mbt` / internal model-tokens adapter — fixed true in registry with no factories | TODO | PORTED |
| LAN-035 | `ITokenizationRegistry.setColorMap` (`:2590`) | Replace encoded token color map and emit `changedColorMap=true` | `syntax/tokenizer.mbt` / internal model-tokens adapter — registry/color-map owner shared with complete registry inventory | TODO | TESTED |
| LAN-036 | `ITokenizationRegistry.getColorMap` (`:2592`) | Current map or null | `syntax/tokenizer.mbt` / internal model-tokens adapter — registry/color-map owner shared with complete registry inventory | TODO | TESTED |
| LAN-037 | `ITokenizationRegistry.getDefaultBackground` (`:2594`) | Background from the current map/theme contract or null | `syntax/tokenizer.mbt` / internal model-tokens adapter — registry/color-map owner shared with complete registry inventory | TODO | TESTED |
| LAN-038 | `Token` class declaration (`languages.ts:40-53`) | Declares the non-encoded compatibility token carrier | `syntax/tokenizer.mbt` / internal model-tokens adapter — non-encoded compatibility carrier | TODO | DEFERRED (non-encoded compatibility result absent) |
| LAN-039 | `Token._tokenBrand` (`:41`) | TypeScript-only nominal brand initialized `undefined` | No MoonBit runtime or nominal-brand field | TODO | N-A (type-system-only brand) |
| LAN-040 | `Token.offset` constructor property (`:44`) | Zero-based token start offset | `syntax/tokenizer.mbt` / internal model-tokens adapter — non-encoded token field | TODO | DEFERRED (non-encoded compatibility result absent) |
| LAN-041 | `Token.type` constructor property (`:45`) | Token scope/type string | `syntax/tokenizer.mbt` / internal model-tokens adapter — non-encoded token field | TODO | DEFERRED (non-encoded compatibility result absent) |
| LAN-042 | `Token.language` constructor property (`:46`) | Token language-id string | `syntax/tokenizer.mbt` / internal model-tokens adapter — non-encoded token field | TODO | DEFERRED (non-encoded compatibility result absent) |
| LAN-043 | `Token` constructor (`:43-48`) | Retains offset, type, and language without transformation | `syntax/tokenizer.mbt` / internal model-tokens adapter — non-encoded token construction | TODO | DEFERRED (non-encoded compatibility result absent) |
| LAN-044 | `Token.toString` (`:50-52`) | Returns `(<offset>, <type>)`; language is intentionally omitted | `syntax/tokenizer.mbt` / internal model-tokens adapter — non-encoded diagnostic representation | TODO | DEFERRED (non-encoded compatibility result absent) |
| LAN-045 | `TokenizationResult` class declaration (`:58-66`) | Declares the non-encoded tokens/end-state result carrier | `syntax/tokenizer.mbt` / internal model-tokens adapter — non-encoded compatibility result | TODO | DEFERRED (non-encoded compatibility result absent) |
| LAN-046 | `TokenizationResult._tokenizationResultBrand` (`:59`) | TypeScript-only nominal brand initialized `undefined` | No MoonBit runtime or nominal-brand field | TODO | N-A (type-system-only brand) |
| LAN-047 | `TokenizationResult.tokens` constructor property (`:62`) | Ordered non-encoded `Token[]` result | `syntax/tokenizer.mbt` / internal model-tokens adapter — non-encoded result field | TODO | DEFERRED (non-encoded compatibility result absent) |
| LAN-048 | `TokenizationResult.endState` constructor property (`:63`) | State carried to the following line | `syntax/tokenizer.mbt` / internal model-tokens adapter — non-encoded result field | TODO | DEFERRED (non-encoded compatibility result absent) |
| LAN-049 | `TokenizationResult` constructor (`:61-65`) | Retains tokens and end state without transformation | `syntax/tokenizer.mbt` / internal model-tokens adapter — non-encoded result construction | TODO | DEFERRED (non-encoded compatibility result absent) |
| LAN-050 | `IFontToken` interface declaration (`:71-77`) | Declares the encoded-result syntactic font annotation carrier | `viewer/common/model/tokens/text_model_tokens.mbt` internal font-token carrier | TODO | PORTED |
| LAN-051 | `EncodedTokenizationResult` class declaration (`:82-97`) | Declares encoded words, font information, and end-state result | `viewer/common/model/tokens/text_model_tokens.mbt` internal encoded-result carrier | TODO | PORTED |
| LAN-052 | `ITokenizationSupport` interface declaration (`:116-133`) | Declares initial-state, encoded/non-encoded tokenization, and optional background support | `viewer/common/model/tokens/text_model_tokens.mbt::InternalTokenizationSupportAdapter`; individual unsupported members remain separately deferred | TODO | PORTED |
| LAN-053 | `IBackgroundTokenizer` interface declaration (`:138-148`) | Declares request, optional mismatch reporting, and disposal contract | `viewer/common/model/tokens/text_model_tokens.mbt` background-tokenizer protocol/default worker | TODO | PORTED |
| LAN-054 | `IBackgroundTokenizationStore` interface declaration (`:153-165`) | Declares token/font/state application and completion callbacks | `viewer/common/model/tokens/tokenizer_syntax_token_backend.mbt::BackgroundTokenizationStore` | TODO | PORTED |
| LAN-055 | `IState` interface declaration (`:172-175`) | Declares clone/equality state-carriage contract | `syntax/tokenizer.mbt::TokenizerState` plus internal adapter | TODO | PORTED |
| LAN-056 | `ITokenizationSupportChangedEvent` interface declaration (`:2503-2506`) | Declares changed-language and changed-color-map event payload | `syntax/tokenizer.mbt::TokenizationChangedEvent` | TODO | PORTED |
| LAN-057 | `ILazyTokenizationSupport` interface declaration (`:2511-2513`) | Declares Promise-valued lazy support | `syntax/tokenizer.mbt` has no public lazy-provider API | TODO | N-A (registry exposes only synchronous support registration) |
| LAN-058 | `ITokenizationRegistry` interface declaration (`:2545-2595`) | Declares registry/event/color-map surface; individual lazy members retain their N-A rows | `syntax/tokenizer.mbt::TokenizationRegistry` source-shaped synchronous adaptation | TODO | PORTED |

## TMT — TextModel construction/content/attach/disposal closure (58 rows)

| ID | Source atom | Transition / exact fact | Local target or seam | Status | Proposed terminal |
|---|---|---|---|---|---|
| TMT-001 | `LARGE_FILE_SIZE_THRESHOLD=20*1024*1024` (`textModel.ts:189`) | Exact UTF-16 value-length threshold | `viewer/common/model/text_model.mbt` — model tokenization policy constant | TODO | PORTED |
| TMT-002 | `LARGE_FILE_LINE_COUNT_THRESHOLD=300*1000` (`:190`) | Exact logical-line threshold | `viewer/common/model/text_model.mbt` — model tokenization policy constant | TODO | PORTED |
| TMT-003 | `onDidChangeLanguage` getter (`:228`) | Forward model event from token part | `viewer/common/model/text_model.mbt` — dynamic language event seam | TODO | DEFERRED (dynamic model-language ownership outside this child) |
| TMT-004 | `onDidChangeLanguageConfiguration` getter (`:229`) | Forward model event from token part | `viewer/common/model/text_model.mbt` — configuration event seam | TODO | DEFERRED (dynamic language-configuration ownership outside this child) |
| TMT-005 | `onDidChangeTokens` getter (`:230`) | Forward model event from token part | `viewer/common/model/text_model.mbt` — `TextModel::on_did_change_tokens` | TODO | TESTED |
| TMT-006 | `_onDidChangeAttached` (`:235`) | Emitter fires only first-attach/last-detach | `viewer/common/model/text_model.mbt` — add model attached emitter | TODO | TESTED |
| TMT-007 | `onDidChangeAttached` getter (`:236`) | Public event view of TMT-006 | `viewer/common/model/text_model.mbt` — model attached event | TODO | TESTED |
| TMT-008 | `_attachedEditorCount` (`:253,326`) | Starts 0; counts attached views | `viewer/common/model/text_model.mbt` — add model attached count | TODO | TESTED |
| TMT-009 | `__isDisposing` (`:260,375`) | Initializes false; guards token/content events during disposal | `viewer/common/model/text_model.mbt` — existing `TextModel.is_disposing` | TODO | PORTED |
| TMT-010 | `_isDisposing()` (`:261`) | Internal reader used by token callbacks | `viewer/common/model/text_model.mbt` — callback/read seam | TODO | PORTED |
| TMT-011 | `_isTooLargeForTokenization` (`:269`) | Constructor-fixed; never changes after construction | `viewer/common/model/text_model.mbt` — add fixed model fact | TODO | TESTED |
| TMT-012 | `_fontTokenDecorationsProvider` (`:290`) | Owns token-derived font/height decorations | `viewer/common/model/text_model.mbt` — no local visual provider | TODO | DEFERRED (no visual FontTokenDecorationsProvider contract) |
| TMT-013 | `_tokenizationTextModelPart` (`:293`) | Owned model part | `viewer/common/model/text_model.mbt` — existing `TextModel.tokenization` | TODO | PORTED |
| TMT-014 | `tokenization` getter (`:294`) | Public interface view of part | `viewer/common/model/text_model.mbt` — existing public field/API | TODO | PORTED |
| TMT-015 | `_attachedViews` (`:302`) | TextModel owns/registers/disposes the manager; token part borrows it and returned handles remain caller-owned | `viewer/common/model/text_model.mbt` manager owner plus borrowed access in token part | TODO | TESTED |
| TMT-016 | constructor token-size inputs (`:332-334`) | `bufferLineCount`; full value length from `Range(1,1,last,lastLength+1)` with text-defined EOL | `viewer/common/model/text_model.mbt` — normalized snapshot line count/value length | TODO | PORTED |
| TMT-017 | `largeFileOptimizations` true arm (`:338-343`) | Compute tokenization flag once, before part construction | `viewer/common/model/text_model.mbt` — Viewer has fixed-enabled safety policy | TODO | TESTED |
| TMT-018 | size-or-line threshold branch (`:339-342`) | Disable tokenization iff value length `>` 20 Mi units OR line count `>` 300K; equality stays enabled | `viewer/common/model/text_model.mbt` — exact boundary matrix | TODO | TESTED |
| TMT-019 | `largeFileOptimizations` false arm (`:345-346`) | Force tokenization flag false regardless of size | `viewer/common/model/text_model.mbt` — no local opt-out option; document fixed-enabled seam | TODO | N-A (Viewer exposes no large-file-optimization opt-out) |
| TMT-020 | constructor language selection (`:352`) | String directly or selection.languageId | `viewer/common/model/text_model.mbt` — construction language id | TODO | PORTED |
| TMT-021 | language-selection callback (`:353-355`) | Non-string selection subscribes and calls `_setLanguage` | `viewer/common/model/text_model.mbt` — no live selection object | TODO | DEFERRED (dynamic model-language ownership outside this child) |
| TMT-022 | token-part assignment/construction (`textModel.ts:360-361,363-365`) | Construct and own the token part with live model access, construction language id, and borrowed AttachedViews | `viewer/common/model/text_model.mbt` — `TextModel::TextModel` constructs the live backend/part using `TokenizationModelAccess`, language id, and its owned AttachedViews | TODO | TESTED |
| TMT-023 | font-token provider construction (`:366`) | Register provider immediately after token part | `viewer/common/model/text_model.mbt` — no local visual provider | TODO | DEFERRED (no visual FontTokenDecorationsProvider contract) |
| TMT-024 | line-height callback (`:393-398`) | Deferred decoration emit around font-token line-height notification | `viewer/common/model/text_model.mbt` — no local visual provider | TODO | DEFERRED (no visual FontTokenDecorationsProvider contract) |
| TMT-025 | font callback (`:399-404`) | Deferred decoration emit around font-token font notification | `viewer/common/model/text_model.mbt` — no local visual provider | TODO | DEFERRED (no visual FontTokenDecorationsProvider contract) |
| TMT-026 | rich-language request (`:406`) | Request features for construction language after subscriptions | `viewer/common/model/text_model.mbt` — local syntax registry is explicit | TODO | DEFERRED (no rich-language lazy request service) |
| TMT-027 | language-configuration callback (`:408-411`) | Source-owned callback forwards bracket first, token part second | `viewer/common/model/text_model.mbt` — token-part config seam | TODO | DEFERRED (dynamic language-configuration ownership outside this child) |
| TMT-028 | `dispose` token subcluster (`:414-421`) | `isDisposing=true` -> willDispose -> token part dispose -> isDisposed -> super/buffer dispose -> `isDisposing=false`; token owner must keep relative order | `viewer/common/model/text_model.mbt` — existing `TextModel::dispose`; buffer tail excluded | TODO | TESTED |
| TMT-029 | `_hasListeners` token substep (`:430-440`, specifically `:434`) | Include token-part external listeners in model listener result | `viewer/common/model/text_model.mbt` — model listener query seam | TODO | TESTED |
| TMT-030 | `_emitContentChangedEvent` dispatcher/order (`:467-482`) | Guard; tokenization first; retained bracket/font seams; wrap event; optional result selection; view-model delivery; public emitter, exact order | `viewer/common/model/text_model.mbt` — test the tokenization/view/public order here; bracket/font content consumers are split below | TODO | TESTED |
| TMT-031 | disposing branch (`:468-471`) | When disposing, emit nothing | `viewer/common/model/text_model.mbt` — existing `is_disposing` guard | TODO | TESTED |
| TMT-032 | disposing early return (`:470`) | Return before every part/view/public callback | `viewer/common/model/text_model.mbt` — existing early return | TODO | TESTED |
| TMT-033 | `resultingSelection` branch (`:477-479`) | Non-null edit result is installed before view-model loop | `viewer/common/model/text_model.mbt` — no editable operation supplies a result selection; flush cursor is handled by frozen cursor spine | TODO | N-A (readonly set-value caller always uses default null) |
| TMT-034 | `onBeforeAttached` (`:607-614`) | Viewer installs/selects scheduler first; TextModel increments count, emits first-attach backend/model notification, then attaches and returns one manager handle | `viewer/common/model/text_model.mbt` — `viewer/common/model/text_model.mbt::on_before_attached` called by `viewer/attach_model.mbt` before ViewModel construction | TODO | TESTED |
| TMT-035 | first-attach branch (`:609-612`) | Fire only on transition `0 -> 1` | `viewer/common/model/text_model.mbt` — attach count transition matrix | TODO | TESTED |
| TMT-036 | `onBeforeDetached` (`:616-623`) | Decrement; on final transition notify backend/model first, whose zero-attached handler invalidates/cancels the worker generation; then detach the exact manager handle; caller clears the carrier scheduler afterward | `viewer/common/model/text_model.mbt` — `viewer/common/model/text_model.mbt::on_before_detached`; `ModelData::dispose` invokes it after listeners and before View/ViewModel disposal | TODO | TESTED |
| TMT-037 | last-detach branch (`:618-621`) | Fire only on transition `1 -> 0` | `viewer/common/model/text_model.mbt` — attach count transition matrix | TODO | TESTED |
| TMT-038 | `isAttachedToEditor` (`:625-627`) | `count > 0` | `viewer/common/model/text_model.mbt` — background scheduling guard | TODO | TESTED |
| TMT-039 | `getAttachedEditorCount` (`:629-631`) | Return exact count | `viewer/common/model/text_model.mbt` — multiple-view recovery/priority fact | TODO | TESTED |
| TMT-040 | `isTooLargeForTokenization` (`:637-639`) | Return constructor-fixed flag | `viewer/common/model/text_model.mbt` — backend reset/constructor guard | TODO | TESTED |
| TMT-041 | `ITextModel.isTooLargeForTokenization` (`model.ts:974`) | Interface declaration consumed by tokenizer backend | `viewer/common/model/text_model.mbt` — model public/internal contract | TODO | PORTED |
| TMT-042 | `ITextModel.onBeforeAttached` (`model.ts:1380`) | Return `IAttachedView` handle | `viewer/common/model/text_model.mbt` — model attach contract | TODO | PORTED |
| TMT-043 | `ITextModel.onBeforeDetached` (`model.ts:1385`) | Consume exact handle | `viewer/common/model/text_model.mbt` — model detach contract | TODO | PORTED |
| TMT-044 | `ITextModel.isAttachedToEditor` (`model.ts:1390`) | Attached boolean contract | `viewer/common/model/text_model.mbt` — scheduler guard contract | TODO | PORTED |
| TMT-045 | `ITextModel.getAttachedEditorCount` (`model.ts:1396`) | Exact count contract | `viewer/common/model/text_model.mbt` — multi-view contract | TODO | PORTED |
| TMT-046 | `IAttachedView.setVisibleLines` member (`model.ts:1452`) | Method accepts a range-array carrier and stabilization fact | `viewer/common/model/text_model.mbt` — `viewer/common/model/tokens/abstract_syntax_token_backend.mbt::AttachedViewImpl::set_visible_lines` | TODO | PORTED |
| TMT-047 | `ITextModel.onDidChangeLanguage` (`model.ts:1349`) | Language-change event declaration matching TMT-003 | `viewer/common/model/text_model.mbt` — dynamic language event seam | TODO | DEFERRED (dynamic model-language ownership outside this child) |
| TMT-048 | `ITextModel.onDidChangeLanguageConfiguration` (`model.ts:1354`) | Language-configuration event declaration matching TMT-004 | `viewer/common/model/text_model.mbt` — dynamic configuration event seam | TODO | DEFERRED (dynamic language-configuration ownership outside this child) |
| TMT-049 | `ITextModel.onDidChangeTokens` (`model.ts:1360`) | Token-change event declaration matching TMT-005 | `viewer/common/model/text_model.mbt` — model token event contract | TODO | PORTED |
| TMT-050 | `ITextModel.onDidChangeAttached` (`model.ts:1365`) | First-attach/last-detach event declaration matching TMT-006/007 | `viewer/common/model/text_model.mbt` — model attached event contract | TODO | PORTED |
| TMT-051 | `ITextModel.tokenization` (`model.ts:1433`) | Interface exposes `ITokenizationTextModelPart` | `viewer/common/model/text_model.mbt` — model token-part contract | TODO | PORTED |
| TMT-052 | `IAttachedView.setVisibleLines.visibleLines[].startLineNumber` (`model.ts:1452`) | Inclusive model start field | `viewer/common/model/tokens/abstract_syntax_token_backend.mbt::VisibleLineRange.start_line_number` | TODO | PORTED |
| TMT-053 | `IAttachedView.setVisibleLines.visibleLines[].endLineNumber` (`model.ts:1452`) | Inclusive model end field | `viewer/common/model/tokens/abstract_syntax_token_backend.mbt::VisibleLineRange.end_line_number` | TODO | PORTED |
| TMT-054 | `IAttachedView.setVisibleLines.stabilized` (`model.ts:1452`) | True means immediate refresh; false means 50 ms debounce | `viewer/common/model/tokens/abstract_syntax_token_backend.mbt::AttachedViewState.stabilized` | TODO | TESTED |
| TMT-055 | `_bracketPairs.handleDidChangeContent(change)` (`textModel.ts:473`) | Bracket-pair content consumer runs after tokenization and before font/content event wrapping | `viewer/common/model/text_model.mbt` retained ordering seam | TODO | DEFERRED (no bracket-pair content consumer contract) |
| TMT-056 | `_fontTokenDecorationsProvider.handleDidChangeContent(change)` (`textModel.ts:474`) | Visual font-decoration consumer runs after bracket pairs and before content event wrapping | `viewer/common/model/text_model.mbt` retained ordering seam | TODO | DEFERRED (no visual FontTokenDecorationsProvider contract) |
| TMT-057 | bracket-specific prerequisite/order and constructor argument (`textModel.ts:357-362`) | Source constructs the bracket part before tokenization and passes that exact part as the second token-part argument | `viewer/common/model/text_model.mbt` retained bracket-argument/order seam; no local bracket-pair token consumer exists | TODO | DEFERRED (no bracket-pair token consumer contract) |
| TMT-058 | `IAttachedView` interface declaration (`model.ts:1446-1453`) | Declares the exact visible-range/stabilization handle contract returned by model attachment | `viewer/common/model/tokens/abstract_syntax_token_backend.mbt` attached-view handle/protocol | TODO | PORTED |

## VMI — visible-range priority and token-event conversion closure (24 rows)

| ID | Source atom | Transition / exact fact | Local target or seam | Status | Proposed terminal |
|---|---|---|---|---|---|
| VMI-001 | ctor property `_attachedView` (`viewModelImpl.ts:78`) | ViewModel holds/uses the borrowed exact handle; ModelData alone owns attach/detach lifetime | `viewer/common/view_model/view_model.mbt` borrowed field populated from `viewer/viewer.mbt::ModelData` | TODO | PORTED |
| VMI-002 | `viewLayout.onDidScroll` callback visible-range substep (`:128-131`) | ViewModel owns/registers this listener during construction and publishes false before the later root Viewer apply-scroll/render listener | `viewer/common/view_model/view_model.mbt` constructor-owned ViewLayout subscription | TODO | TESTED |
| VMI-003 | `scrollTopChanged` branch (`:129-131`) | Only vertical scroll recomputes priority; horizontal-only scroll does not | `viewer/common/view_model/view_model.mbt` — local `ScrollEvent.scroll_top_changed` axis | TODO | TESTED |
| VMI-004 | complete `getModelVisibleRanges` (`:222-232`) | Read partial viewport start/end; use min/max columns; convert view range through hidden/projection mapping | `viewer/common/view_model/view_model.mbt` — new local ViewModel helper using `ViewLayout.get_lines_viewport_data` and converter | TODO | TESTED |
| VMI-005 | complete `visibleLinesStabilized` (`:234-237`) | Recompute model ranges and call true only from source initialization/restore producers | `viewer/common/view_model/view_model.mbt`; local caller is one-time post-initial View/layout setup, never generic render | TODO | TESTED |
| VMI-006 | complete `_handleVisibleLinesChanged` (`:239-242`) | Recompute model ranges and call false for ordinary scroll/content/layout changes | `viewer/common/view_model/view_model.mbt`; constructor scroll listener and content-mapping tail | TODO | TESTED |
| VMI-007 | content-change tail call (`:456`) | After configuration line counts/recovery, publish current visible ranges as unstable | `viewer/common/view_model/view_model.mbt` — replace local explicit attached-view N-A at `view_model.mbt:248` | TODO | TESTED |
| VMI-008 | complete `_toModelVisibleRanges` (`:655-698`) | Convert view range to model, subtract hidden areas in order, return visible segments | `viewer/common/view_model/view_model.mbt` — local coordinates converter + hidden-area union | TODO | TESTED |
| VMI-009 | no-hidden branch (`:659-661`) | Empty hidden list returns singleton converted range | `viewer/common/view_model/view_model.mbt` — visible priority hidden-area matrix | TODO | TESTED |
| VMI-010 | no-hidden early return (`:660`) | Return before allocation/scan | `viewer/common/view_model/view_model.mbt` — visible priority hidden-area matrix | TODO | TESTED |
| VMI-011 | hidden-area loop (`:669-688`) | Scan every sorted hidden range; carry next visible start as `hiddenEnd+1`, column 1 | `viewer/common/view_model/view_model.mbt` — visible priority hidden-area matrix | TODO | TESTED |
| VMI-012 | hidden-before branch (`:673-675`) | Hidden end before current start continues | `viewer/common/view_model/view_model.mbt` — hidden-area boundary matrix | TODO | TESTED |
| VMI-013 | hidden-after branch (`:676-678`) | Hidden start after visible end continues | `viewer/common/view_model/view_model.mbt` — hidden-area boundary matrix | TODO | TESTED |
| VMI-014 | visible-gap branch (`:680-685`) | If current start precedes hidden start, append through `hiddenStart-1` at model max column | `viewer/common/view_model/view_model.mbt` — hidden-area gap matrix | TODO | TESTED |
| VMI-015 | trailing-visible branch (`:690-695`) | Append tail when start line precedes end, or same line with start column `<` end column | `viewer/common/view_model/view_model.mbt` — empty/equal/boundary tail matrix | TODO | TESTED |
| VMI-016 | `IViewModel.visibleLinesStabilized` (`viewModel.ts:48`) | Interface declaration | `viewer/common/view_model/view_model.mbt` — local ViewModel method/public internal seam | TODO | PORTED |
| VMI-017 | model `onDidChangeTokens` registered callback (`viewModelImpl.ts:510-523`) | Convert exact model token ranges and dispatch view event before outgoing event; never force or re-warm tokenization from the listener | `viewer/common/view_model/view_model.mbt` constructor token subscription; remove the current `viewer/viewer.mbt::retokenize_current_model` listener path | TODO | TESTED |
| VMI-018 | token-range loop (`:512-520`) | Preserve source range order and one output slot per input range | `viewer/common/view_model/view_model.mbt` token-range conversion loop | TODO | TESTED |
| VMI-019 | start-position conversion (`:514`) | Convert `(fromLineNumber,1)` through the currently valid projection | `viewer/common/view_model/view_model.mbt` converter; old/new projection-domain test | TODO | TESTED |
| VMI-020 | end-position conversion (`:515`) | Convert `(toLineNumber,getLineMaxColumn(toLineNumber))` through the current projection | `viewer/common/view_model/view_model.mbt` converter; old/new projection-domain test | TODO | TESTED |
| VMI-021 | view-range `fromLineNumber` payload (`:516-518`) | Store the converted start line exactly | `viewer/common/view_model/view_model.mbt::ViewTokensChangedRange.from_line_number` | TODO | PORTED |
| VMI-022 | view-range `toLineNumber` payload (`:516-519`) | Store the converted end line exactly | `viewer/common/view_model/view_model.mbt::ViewTokensChangedRange.to_line_number` | TODO | PORTED |
| VMI-023 | single-view token event dispatch (`:521`) | Emit converted ranges to render consumers first | `viewer/common/view_model/view_model.mbt` view-event dispatcher | TODO | TESTED |
| VMI-024 | outgoing model-token event dispatch (`:522`) | Emit original model event after the view event | `viewer/common/view_model/view_model.mbt` outgoing dispatcher | TODO | TESTED |

## STB — stabilized-true producer/oracle closure

| ID | Source atom | Exact behavior | Local target or seam | Status | Proposed terminal |
|---|---|---|---|---|---|
| STB-001 | `CodeEditorWidget.handleInitialized` (`codeEditorWidget.ts:1074-1076`) | Initialization hook owns the ordinary one-time stabilized-true call | `viewer/viewer.mbt` one-time post-initial View/layout setup | TODO | TESTED |
| STB-002 | optional `_getViewModel()?.visibleLinesStabilized()` (`:1075`) | Present ViewModel receives true once; absent model is no-op | `viewer/viewer.mbt` initialized/absent-model branch test | TODO | TESTED |
| STB-003 | `View.restoreState` (`view.ts:673-679`) | Restore both scroll axes immediately, then publish stabilized true | `viewer/viewer.mbt::Viewer::restore_view_state`; `viewer/restore_view_state_tokenization_wbtest.mbt` records scroll delivery before the stabilized-true visible-range update | TODO | TESTED |
| STB-004 | restore `setScrollPosition(..., ScrollType.Immediate)` (`:674-677`) | Both axes commit synchronously before stabilization | Existing `Viewer::restore_view_state` -> `ViewLayout::scroll_to` -> `Scrollable::set_position_now`; assert the scroll position/event is already current when the true update runs | TODO | TESTED |
| STB-005 | restore `visibleLinesStabilized()` call (`:678`) | The restore path is the second allowed stabilized-true producer | Add `view_model.visible_lines_stabilized()` after the successful `Some(state)` scroll; prove exactly one true update with ranges computed from the restored viewport | TODO | TESTED |

## UTM — scoped upstream-test dispositions (23 counted rows)

Pinned test hashes:

- `test/common/model/model.modes.test.ts`: `5b36d602af53516ea3e04a4b254cb574a0998a241d1dc45f22402636b1dbc598`
- `test/common/model/textModelWithTokens.test.ts`: `32d3c44edfa1512a9ec5e1259a162c15f1b42d29e72c71329ef089ad5c8e7a41`
- `test/browser/viewModel/viewModelImpl.test.ts`: `4bb107efe4cb43025de86de3473cc3d149f6d64aafe690343d9d6ea38e459a79`
- `test/browser/viewModel/testViewModel.ts`: `8302286127070f92bd506c724671da94cffbc2af43caa938eba31459391698b1`
- `test/common/model/model.test.ts`: `4c5568f1e8449c129bc88e4bd06a000835102f2fdd38f6a6d9373f4f574c3483`
- `test/browser/controller/cursor.test.ts`: `73badec15dc0fbf27c06c4c5b80b0da12ccf9e8e624609570d611f96cfadba4c`

Each row is one exact named upstream `test(...)`. Store/backend test files are
owned by their respective complete-source inventory groups and are not
duplicated here. `testViewModel.ts:15-35` is only a constructor fixture: its
`setVisibleLines` callback is empty, so it is dependency evidence, not a test
row or parity authority.

| ID | Exact upstream test (pinned file:line) | Authority / local target | Status | Proposed terminal |
|---|---|---|---|---|
| UTM-001 | `model calls syntax highlighter 1` (`model.modes.test.ts:62-65`) | `viewer/common/model/tokens/model_modes_reference_wbtest.mbt` — Force line 1 tokenizes exactly line 1; port exact label/path/pin | TODO | TESTED |
| UTM-002 | `model calls syntax highlighter 2` (`:67-73`) | `viewer/common/model/tokens/model_modes_reference_wbtest.mbt` — Force line 2 propagates through 1-2; repeat does no work; port exact label/path/pin | TODO | TESTED |
| UTM-003 | `model caches states` (`:75-93`) | `viewer/common/model/tokens/model_modes_reference_wbtest.mbt` — Sequential per-line demand and stable-state cache; port exact label/path/pin | TODO | TESTED |
| UTM-004 | `model invalidates states for one line insert` (`:95-105`) | `viewer/common/model/tokens/model_modes_reference_wbtest.mbt` — Editable single-line insert | TODO | N-A (readonly Viewer has no incremental edit API) |
| UTM-005 | `model invalidates states for many lines insert` (`:107-118`) | `viewer/common/model/tokens/model_modes_reference_wbtest.mbt` — Editable multiline insert | TODO | N-A (readonly Viewer has no incremental edit API) |
| UTM-006 | `model invalidates states for one new line` (`:120-128`) | `viewer/common/model/tokens/model_modes_reference_wbtest.mbt` — Editable newline plus follow-up insert | TODO | N-A (readonly Viewer has no incremental edit API) |
| UTM-007 | `model invalidates states for one line delete` (`:130-144`) | `viewer/common/model/tokens/model_modes_reference_wbtest.mbt` — Editable same-line delete convergence | TODO | N-A (readonly Viewer has no incremental edit API) |
| UTM-008 | `model invalidates states for many lines delete` (`:146-156`) | `viewer/common/model/tokens/model_modes_reference_wbtest.mbt` — Editable multiline delete convergence | TODO | N-A (readonly Viewer has no incremental edit API) |
| UTM-009 | `getTokensForInvalidLines one text insert` (`model.modes.test.ts:217-223`) | `viewer/common/model/tokens/model_modes_reference_wbtest.mbt` — Editable invalid suffix from one insert | TODO | N-A (readonly Viewer has no incremental edit API) |
| UTM-010 | `getTokensForInvalidLines two text insert` (`:225-235`) | `viewer/common/model/tokens/model_modes_reference_wbtest.mbt` — Editable two-range insert | TODO | N-A (readonly Viewer has no incremental edit API) |
| UTM-011 | `getTokensForInvalidLines one multi-line text insert, one small text insert` (`:237-244`) | `viewer/common/model/tokens/model_modes_reference_wbtest.mbt` — Editable multi-edit invalid queue | TODO | N-A (readonly Viewer has no incremental edit API) |
| UTM-012 | `getTokensForInvalidLines one delete text` (`:246-252`) | `viewer/common/model/tokens/model_modes_reference_wbtest.mbt` — Editable same-line deletion | TODO | N-A (readonly Viewer has no incremental edit API) |
| UTM-013 | `getTokensForInvalidLines one line delete text` (`:254-260`) | `viewer/common/model/tokens/model_modes_reference_wbtest.mbt` — Editable line-boundary deletion | TODO | N-A (readonly Viewer has no incremental edit API) |
| UTM-014 | `getTokensForInvalidLines multiple lines delete text` (`:262-268`) | `viewer/common/model/tokens/model_modes_reference_wbtest.mbt` — Editable multiline deletion | TODO | N-A (readonly Viewer has no incremental edit API) |
| UTM-015 | `microsoft/monaco-editor#122: Unhandled Exception: TypeError: Unable to get property 'replace' of undefined or null reference` (`textModelWithTokens.test.ts:548-620`) | `viewer/common/model/tokens/text_model_with_tokens_reference_wbtest.mbt` — Dynamic language changes reset state and expose temporary default tokens | TODO | DEFERRED (dynamic model-language dependency; TPM-077-079) |
| UTM-016 | `issue #63822: Wrong embedded language detected for empty lines` (`:674-709`) | `viewer/common/model/tokens/text_model_with_tokens_reference_wbtest.mbt` — `getLanguageIdAtPosition` reads encoded embedded language | TODO | DEFERRED (local tokenizer result cannot encode embedded language ids) |
| UTM-017 | `issue #44805: No visible lines via API call` (`viewModelImpl.test.ts:119-130`) | `viewer/common/view_model/view_model_impl_tokenization_reference_wbtest.mbt` — Hidden-area conversion yields a valid visible result; port exact label/path/pin | TODO | TESTED |
| UTM-018 | `issue #44805: No visible lines via undoing` (`:132-150`) | `viewer/common/view_model/view_model_impl_tokenization_reference_wbtest.mbt` — Hidden areas after editable undo | TODO | N-A (readonly Viewer has no undo API) |
| UTM-019 | `view models react first to model changes` (`viewModelImpl.test.ts:92-117`) | Two attached editors receive model-first content delivery before hostile public listener mutation; adapt with nested `set_value` and exact range validity. Exact local target: `viewer/common/view_model/view_model_impl_tokenization_reference_wbtest.mbt` | TODO | TESTED |
| UTM-020 | `issue #46314: ViewModel is out of sync with Model!` (`cursor.test.ts:2822-2851`) | Two Viewers share one model; cursor callback invokes `tokenize_if_cheap(1)` during `set_value` without stale projection or eager sweep. Exact local target: `viewer/cursor_tokenization_reference_wbtest.mbt` | TODO | TESTED |
| UTM-021 | `Get word at position` (`model.test.ts:439-455`) | Move the exact named case from ordinary `word_helper_wbtest.mbt` into quality-compliant `viewer/common/model/model_reference_wbtest.mbt`, which cites the full source path and oracle commit; keep only non-reference helper coverage in the former file. | TODO | TESTED |
| UTM-022 | `getWordAtPosition at embedded language boundaries` (`model.test.ts:457-474`) | Embedded token-language boundary word selection. Exact local target: `viewer/common/model/tokens/text_model_with_tokens_reference_wbtest.mbt` | TODO | DEFERRED (embedded-language token/config integration absent) |
| UTM-023 | `issue #61296: VS code freezes when editing CSS file with emoji` (`model.test.ts:476-500`) | Emoji/word-pattern progress under dynamic language configuration. Exact local target: `viewer/common/model/tokens/text_model_with_tokens_reference_wbtest.mbt` | TODO | DEFERRED (dynamic language configuration and embedded word integration absent) |

Coordination-only upstream tests, excluded from this group's denominator:
`tokensStore.test.ts` belongs to the semantic/store group;
`textModelTokens.test.ts` belongs to the backend/state/queue group. No pinned
test directly asserts first/last attach notifications, exact-handle detach,
stabilized true/false, or large-file threshold equality, so those require
ordinary local branch-derived tests rather than invented `*_reference_*` names.


## TMP — inherited TextModelPart lifecycle closure

| ID | Source atom | Exact behavior | Local target or seam | Status | Proposed terminal |
|---|---|---|---|---|---|
| TMP-001 | `TextModelPart extends Disposable` (`textModelPart.ts:8`) | Tokenization part inherits registered-resource disposal | `viewer/common/model/tokens/tokenization_text_model_part.mbt` owned disposable group | TODO | PORTED |
| TMP-002 | `_isDisposed=false` (`:9`) | Guard starts live | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — token part disposed flag | TODO | PORTED |
| TMP-003 | override `dispose` (`:11-14`) | Dispose registered resources then mark disposed | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — token part disposal member | TODO | TESTED |
| TMP-004 | `super.dispose()` ordering (`:12`) | Retire both font emitters, token/backend events, subscriptions, workers, and timers before disposed flag | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — token part owned-disposable order | TODO | TESTED |
| TMP-005 | `_isDisposed=true` (`:13`) | Terminal flag follows resource disposal | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — token part disposed flag | TODO | TESTED |
| TMP-006 | `assertNotDisposed` (`:15-19`) | Public/internal guarded work checks lifetime | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — token part guard helper | TODO | PORTED |
| TMP-007 | disposed branch (`:16-18`) | Live continues; disposed enters throw arm | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — token part live/disposed branch test | TODO | TESTED |
| TMP-008 | disposed throw (`:17`) | Exact inert/failure boundary after disposal | `viewer/common/model/tokens/tokenization_text_model_part.mbt` — MoonBit panic/error boundary plus inert scheduled-callback tests | TODO | TESTED |

## FNT — consumed syntactic font payload closure

| ID | Source atom | Exact behavior | Local target or seam | Status | Proposed terminal |
|---|---|---|---|---|---|
| FNT-001 | `IFontTokenOption` (`textModelEvents.ts:157-170`) | Optional syntactic font option carrier | `AN::FontTokenOption`; token-part/backend events use this exact child type | TODO | PORTED |
| FNT-002 | `fontFamily?` (`:161`) | Optional family override | `AN::FontTokenOption.font_family` | TODO | PORTED |
| FNT-003 | `fontSizeMultiplier?` (`:165`) | Optional size multiplier | `AN::FontTokenOption.font_size_multiplier` | TODO | PORTED |
| FNT-004 | `lineHeightMultiplier?` (`:169`) | Optional line-height multiplier | `AN::FontTokenOption.line_height_multiplier` | TODO | PORTED |
| FNT-005 | `IModelFontTokensChangedEvent` (`:176-178`) | Model font-token event carrier | `AN::ModelFontTokensChangedEvent`; `TokenizationTextModelPart::on_did_change_font_tokens` exposes this exact child event to the parent-owned consumer | TODO | PORTED |
| FNT-006 | event `changes` (`:177`) | Preserve exact annotations update | `AN::ModelFontTokensChangedEvent.changes`; backend event test | TODO | TESTED |
| FNT-007 | `FontTokensUpdate` alias (`:183`) | `AnnotationsUpdate<FontTokenOption?>` value contract | `AN::FontTokensUpdate` is an exact non-nominal typealias for `AN::AnnotationsUpdate[AN::FontTokenOption?]`; backend and token part preserve the same value | TODO | PORTED |
| FNT-008 | `IAnnotationUpdate<T>` (`annotations.ts:237-240`) | Range plus optional annotation item | `AN::AnnotationUpdate` | TODO | PORTED |
| FNT-009 | annotation `range` (`:238`) | Exact half-open offset range | `AN::AnnotationUpdate.range` | TODO | TESTED |
| FNT-010 | annotation `annotation` (`:239`) | Present sets; absent clears | `AN::AnnotationUpdate.annotation` | TODO | TESTED |
| FNT-011 | `AnnotationsUpdate<T>` class (`:249`) | Ordered update collection | `AN::AnnotationsUpdate` | TODO | PORTED |
| FNT-012 | static `create` (`:251-253`) | Wrap caller order without transformation | `AN::AnnotationsUpdate::create` | TODO | TESTED |
| FNT-013 | private `_annotations` (`:255`) | Store exact update array | `AN::AnnotationsUpdate.annotations` private storage | TODO | PORTED |
| FNT-014 | private constructor (`:257-259`) | Retain caller array | `AN::AnnotationsUpdate::new` | TODO | TESTED |
| FNT-015 | `annotations` getter (`:261-263`) | Return stored updates | `AN::AnnotationsUpdate::annotations` | TODO | TESTED |

## LRG — consumed LineRange.joinMany closure

| ID | Source atom | Exact behavior | Local target or seam | Status | Proposed terminal |
|---|---|---|---|---|---|
| LRG-001 | `LineRange.joinMany` (`lineRange.ts:51-60`) | Join arrays of sorted ranges | `base/common/line_range.mbt` — `base/common/line_range.mbt::LineRange::join_many` | TODO | PORTED |
| LRG-002 | empty-input branch (`:52-54`) | Zero arrays return empty | `base/common/line_range.mbt` — `LineRange::join_many` empty branch | TODO | TESTED |
| LRG-003 | empty early return (`:53`) | Return before constructing a set | `base/common/line_range.mbt` — empty branch test | TODO | TESTED |
| LRG-004 | first-array initialization (`:55`) | Copy first array into initial set | `base/common/line_range.mbt` — first-array/copy-order test | TODO | TESTED |
| LRG-005 | remaining-arrays loop (`:56-58`) | Union each remaining sorted array in order | `base/common/line_range.mbt` — disjoint/overlap/adjacent/multiple matrix | TODO | TESTED |
| LRG-006 | result ranges (`:59`) | Return normalized set ranges | `base/common/line_range.mbt` — exact output-range test | TODO | TESTED |

## FAX — consumed live FixedArray get/set closure

| ID | Source atom | Exact behavior | Local target or seam | Status | Proposed terminal |
|---|---|---|---|---|---|
| FAX-001 | `FixedArray<T>` (`fixedArray.ts:12-31`) | Dense default-filled state storage | `viewer/common/model/tokens/text_model_tokens.mbt` — `viewer/common/model/tokens/text_model_tokens.mbt::FixedArray` | TODO | PORTED |
| FAX-002 | `_store=[]` (`:13`) | Physical storage starts empty | `viewer/common/model/tokens/text_model_tokens.mbt` — `FixedArray.store` | TODO | PORTED |
| FAX-003 | constructor `_default` (`:15-17`) | Retain fill/read fallback value | `viewer/common/model/tokens/text_model_tokens.mbt` — `FixedArray.default` | TODO | PORTED |
| FAX-004 | `get` member (`:19-24`) | Read stored value or default | `viewer/common/model/tokens/text_model_tokens.mbt` — `FixedArray::get` | TODO | TESTED |
| FAX-005 | in-range branch (`:20-23`) | In range returns stored; otherwise returns default | `viewer/common/model/tokens/text_model_tokens.mbt` — in/out boundary test | TODO | TESTED |
| FAX-006 | `set` member (`:26-31`) | Fill holes then set target | `viewer/common/model/tokens/text_model_tokens.mbt` — `FixedArray::set` | TODO | TESTED |
| FAX-007 | fill loop (`:27-29`) | Append default until index exists | `viewer/common/model/tokens/text_model_tokens.mbt` — zero/one/many-hole test | TODO | TESTED |
| FAX-008 | target assignment (`:30`) | Overwrite exact requested slot after fill | `viewer/common/model/tokens/text_model_tokens.mbt` — overwrite/boundary test | TODO | TESTED |

## NUL — consumed nullTokenizeEncoded closure

| ID | Source atom | Exact behavior | Local target or seam | Status | Proposed terminal |
|---|---|---|---|---|---|
| NUL-001 | `nullTokenizeEncoded` (`nullTokenize.ts:22-33`) | Construct one fallback encoded token result | `viewer/common/model/tokens/line_tokens_encoder.mbt` — internal model/tokens null-token adapter | TODO | PORTED |
| NUL-002 | `Uint32Array(2)` (`:23`) | Exact two-word representation | `viewer/common/model/tokens/line_tokens_encoder.mbt` — MoonBit two-word UInt array | TODO | PORTED |
| NUL-003 | first word `0` (`:24`) | Token start offset is zero | `viewer/common/model/tokens/line_tokens_encoder.mbt` — fallback token offset | TODO | TESTED |
| NUL-004 | language-id metadata component (`:26`) | Encode requested language id | `viewer/common/model/tokens/line_tokens_encoder.mbt` — local language-id codec | TODO | TESTED |
| NUL-005 | `StandardTokenType.Other` component (`:27`) | Exact default token type | `viewer/common/model/tokens/line_tokens_encoder.mbt` — encoded attributes | TODO | TESTED |
| NUL-006 | `FontStyle.None` component (`:28`) | Exact default font style | `viewer/common/model/tokens/line_tokens_encoder.mbt` — encoded attributes | TODO | TESTED |
| NUL-007 | default foreground component (`:29`) | Exact default foreground | `viewer/common/model/tokens/line_tokens_encoder.mbt` — encoded attributes/theme seam | TODO | TESTED |
| NUL-008 | default background component (`:30`) | Exact default background | `viewer/common/model/tokens/line_tokens_encoder.mbt` — encoded attributes/theme seam | TODO | TESTED |
| NUL-009 | unsigned `>>>0` composition (`:31`) | Preserve 32-bit metadata bits | `viewer/common/model/tokens/line_tokens_encoder.mbt` — MoonBit UInt metadata | TODO | TESTED |
| NUL-010 | null-state ternary/result (`:33`) | Null uses NullState; present preserves state; font info is empty | `viewer/common/model/tokens/line_tokens_encoder.mbt` — internal adapter result matrix | TODO | TESTED |
| NUL-011 | exported `NullState` anonymous `IState` singleton declaration (`nullTokenize.ts:9-16`) | One canonical stateless tokenizer state | `viewer/common/model/tokens/line_tokens_encoder.mbt` internal canonical null-state value | TODO | PORTED |
| NUL-012 | `NullState.clone` member declaration (`:10-12`) | Exposes the stateless clone contract | Internal null-state adapter clone member | TODO | PORTED |
| NUL-013 | `NullState.equals` member declaration (`:13-15`) | Exposes the null-state equality contract | Internal null-state adapter equality member | TODO | PORTED |
| NUL-014 | singleton identity semantics (`:11,14`) | Clone returns the canonical state; equality succeeds only for the canonical source state, adapted to the canonical immutable MoonBit value | `viewer/common/model/tokens/text_model_tokens_wbtest.mbt` same/different-state and clone-identity matrix | TODO | TESTED |

## CTE — consumed ContiguousTokensEditing representation seam

| ID | Source atom | Exact behavior | Local target or seam | Status | Proposed terminal |
|---|---|---|---|---|---|
| CTE-001 | `EMPTY_LINE_TOKENS` (`contiguousTokensEditing.ts:8`) | Distinct compact empty-line sentinel | `viewer/common/tokens/contiguous_tokens_store.mbt` sentinel | TODO | PORTED |
| CTE-002 | `toUint32Array` (`:138-143`) | Normalize typed-array/buffer representation | `viewer/common/tokens/contiguous_tokens_store.mbt` Array<UInt> representation seam | TODO | N-A (MoonBit has one owned UInt-array representation) |
| CTE-003 | already-Uint32Array branch (`:139-140`) | Return same typed array | `viewer/common/tokens/contiguous_tokens_store.mbt` — same one-representation seam | TODO | N-A (MoonBit has no typed-array versus ArrayBuffer split) |
| CTE-004 | ArrayBuffer branch (`:141-142`) | Create a typed view over buffer | `viewer/common/tokens/contiguous_tokens_store.mbt` — same one-representation seam | TODO | N-A (MoonBit has no typed-array versus ArrayBuffer split) |

## BIA — consumed browser idle adapter closure

| ID | Source atom | Exact behavior | Local target or seam | Status | Proposed terminal |
|---|---|---|---|---|---|
| BIA-001 | global idle adapter IIFE (`async.ts:1536-1579`) | Select one process/browser idle implementation and publish global wrapper | `viewer/browser_host.mbt` — `viewer/browser_host.mbt::TokenizationScheduler` singleton | TODO | PORTED |
| BIA-002 | `safeGlobal=globalThis` (`:1537`) | Feature detection and global wrapper share realm | `viewer/browser_host.mbt` — browser-host JS adapter | TODO | PORTED |
| BIA-003 | missing request/cancel decision (`:1538`) | Fallback if either idle API function is absent | `viewer/browser_host.mbt` — requestIdleCallback/cancel matrix | TODO | TESTED |
| BIA-004 | fallback `_runWhenIdle` callback (`:1539-1562`) | Install timeout-backed adapter | `viewer/browser_host.mbt` — browser-host fallback constructor | TODO | PORTED |
| BIA-005 | `setTimeout0` callback (`:1540-1552`) | Schedule fallback work asynchronously | `viewer/browser_host.mbt` — browser-host zero-timeout adapter | TODO | TESTED |
| BIA-006 | fallback disposed branch (`:1541-1543`) | Disposed callback does no work | `viewer/browser_host.mbt` — fallback cancel test | TODO | TESTED |
| BIA-007 | fallback disposed early return (`:1542`) | Return before deadline/runner | `viewer/browser_host.mbt` — inert-callback test | TODO | TESTED |
| BIA-008 | fallback frame constant/end (`:1544`) | Deadline end is `Date.now()+15` exactly | `viewer/browser_host.mbt` — deterministic clock 14/15/16 ms matrix | TODO | TESTED |
| BIA-009 | fallback `didTimeout=true` (`:1545-1547`) | Synthetic deadline reports timeout | `viewer/browser_host.mbt` — deadline payload test | TODO | TESTED |
| BIA-010 | fallback `timeRemaining` (`:1547-1549`) | Return `max(0,end-now)` | `viewer/browser_host.mbt` — before/equal/after test | TODO | TESTED |
| BIA-011 | frozen deadline runner (`:1551`) | Invoke runner with frozen deadline | `viewer/browser_host.mbt` — browser adapter payload test | TODO | TESTED |
| BIA-012 | fallback `disposed=false` (`:1553`) | Per-handle liveness starts true-for-work | `viewer/browser_host.mbt` — cancel-handle state | TODO | PORTED |
| BIA-013 | fallback disposable object (`:1554-1561`) | Return cancellation handle | `viewer/browser_host.mbt` — scheduler idle cancel handle | TODO | PORTED |
| BIA-014 | fallback `dispose` (`:1555-1560`) | Dispose marks handle inert | `viewer/browser_host.mbt` — cancellation test | TODO | TESTED |
| BIA-015 | repeated fallback dispose branch (`:1556-1558`) | Second dispose returns without mutation | `viewer/browser_host.mbt` — idempotent-cancel test | TODO | TESTED |
| BIA-016 | fallback mark disposed (`:1559`) | First dispose flips liveness | `viewer/browser_host.mbt` — cancellation ordering test | TODO | TESTED |
| BIA-017 | native-idle adapter (`:1563-1576`) | Use requestIdleCallback when both functions exist | `viewer/browser_host.mbt` — browser-host native adapter | TODO | PORTED |
| BIA-018 | `requestIdleCallback` call/handle (`:1565`) | Retain numeric handle for cancellation | `viewer/browser_host.mbt` — scheduler idle cancel handle | TODO | TESTED |
| BIA-019 | numeric-timeout option branch (`:1565`) | Pass `{timeout}` only for numeric timeout; otherwise undefined | `viewer/browser_host.mbt` — absent/present timeout test | TODO | TESTED |
| BIA-020 | native disposable callback (`:1566-1575`) | Idempotently cancel exact handle | `viewer/browser_host.mbt` — browser-host native cancel handle | TODO | TESTED |
| BIA-021 | repeated native dispose branch (`:1569-1571`) | Second dispose returns before cancellation | `viewer/browser_host.mbt` — idempotent cancel test | TODO | TESTED |
| BIA-022 | mark disposed then `cancelIdleCallback(handle)` (`:1572-1573`) | Preserve exact cancellation order/identity | `viewer/browser_host.mbt` — browser adapter trace test | TODO | TESTED |
| BIA-023 | `runWhenGlobalIdle` wrapper (`:1578`) | Bind selected adapter to globalThis and forward timeout | `viewer/browser_host.mbt` — browser singleton wrapper test | TODO | TESTED |

## ASB ledger — `abstractSyntaxTokenBackend.ts`

| ID | Source atom | Arithmetic / transition | Local target or seam | Status | Proposed terminal |
|---|---|---|---|---|---|
| ASB-001 | `AttachedViews` class (24) | Owns attached-view membership, visible-range aggregation, and change event. | `A::AttachedViews` | TODO | PORTED |
| ASB-002 | `_onDidChangeVisibleRanges` field (25) | Emitter payload is `{ view, state }`. | `A::AttachedViews.did_change_visible_ranges` | TODO | PORTED |
| ASB-003 | `onDidChangeVisibleRanges` field (26) | Public event alias of the private emitter. | `A::AttachedViews::on_did_change_visible_ranges` | TODO | PORTED |
| ASB-004 | `_views` field (28) | Identity set of live `AttachedViewImpl`s. | `A::AttachedViews.views` | TODO | PORTED |
| ASB-005 | `_viewsChanged` field (29) | Reactive invalidation signal for aggregate visible ranges. | `A::AttachedViews.views_changed` explicit generation/emitter seam | TODO | PORTED |
| ASB-006 | `visibleLineRanges` field (31) | Read-only aggregate of joined ranges across every attached view. | `A::AttachedViews::visible_line_ranges` | TODO | PORTED |
| ASB-007 | `AttachedViews.constructor` (33-44) | Creates a derived aggregate with identity/range equality and subscribes it to view-set changes. | `A::AttachedViews::new`; `A_wbtest` | TODO | TESTED |
| ASB-008 | derived option `owner` (35) | Associates observable diagnostics/lifetime with `this`. | `viewer/common/model/tokens/abstract_syntax_token_backend.mbt` source-shaped seam for derived option `owner` (35) | TODO | N-A (local emitter/generation seam has no observable-owner metadata) |
| ASB-009 | derived option `equalsFn` (36) | Array equality by `LineRange` identity/equality suppresses equivalent aggregate updates. | `A::AttachedViews::visible_line_ranges`; `A_wbtest` | TODO | TESTED |
| ASB-010 | derived reader callback (37-43) | Reads the invalidation generation, joins mapped per-view ranges, returns normalized aggregate. | `A::AttachedViews::recompute_visible_line_ranges`; `A_wbtest` | TODO | TESTED |
| ASB-011 | `_views.map` callback (40) | For each view, read current state and expose its `visibleLineRanges`. | `A::AttachedViews::recompute_visible_line_ranges`; `A_wbtest` | TODO | TESTED |
| ASB-012 | absent-state fallback (40) | Undefined view state contributes `[]`, never a synthetic line. | `A::AttachedViews::recompute_visible_line_ranges`; `A_wbtest` | TODO | TESTED |
| ASB-013 | `attachView` member (46-53) | Create view, add it, invalidate aggregate, and return the same handle. | `A::AttachedViews::attach_view`; `A_wbtest` | TODO | TESTED |
| ASB-014 | attached-view state callback (47-49) | Every state set fires the owner event with the same view identity and state. | `A::AttachedViews::attach_view` callback; `A_wbtest` | TODO | TESTED |
| ASB-015 | attach callback payload `view` (48) | Captured newly-created handle, not a lookup copy. | `A::AttachedViewStateChange.view` | TODO | PORTED |
| ASB-016 | attach callback payload `state` (48) | Delivers the just-committed state. | `A::AttachedViewStateChange.state` | TODO | PORTED |
| ASB-017 | `detachView` member (55-59) | Delete identity, fire undefined state, then invalidate aggregate. | `A::AttachedViews::detach_view`; `A_wbtest` | TODO | TESTED |
| ASB-018 | detach payload `view` (57) | Event preserves caller's interface handle. | `A::AttachedViewStateChange.view` | TODO | PORTED |
| ASB-019 | detach payload `state: undefined` (57) | Undefined is the explicit detach signal. | `A::AttachedViewStateChange.state=None`; `A_wbtest` | TODO | TESTED |
| ASB-020 | `AttachedViews.dispose` (61-63) | Dispose only the event emitter; view ownership is external. | `A::AttachedViews::dispose`; `A_wbtest` | TODO | TESTED |
| ASB-021 | `AttachedViewState` class (69) | Immutable visible ranges plus stabilization fact. | `A::AttachedViewState` | TODO | PORTED |
| ASB-022 | `AttachedViewState.constructor` (70-73) | Stores both caller-provided facts without normalization. | `A::AttachedViewState::new` | TODO | PORTED |
| ASB-023 | `visibleLineRanges` constructor property (71) | Read-only ordered range array. | `A::AttachedViewState.visible_line_ranges` | TODO | PORTED |
| ASB-024 | `stabilized` constructor property (72) | Selects immediate refresh versus 50 ms debounce. | `A::AttachedViewState.stabilized` | TODO | PORTED |
| ASB-025 | `AttachedViewState.equals` (75-86) | Identity, element equality, stabilization equality, then true. | `A::AttachedViewState::equals`; `A_wbtest` | TODO | TESTED |
| ASB-026 | identity early return (76-78) | Same object is equal without walking ranges. | `A::AttachedViewState::equals`; `A_wbtest` | TODO | TESTED |
| ASB-027 | range comparator callback (79) | Delegates each pair to `LineRange.equals`. | `A::AttachedViewState::equals`; `A_wbtest` | TODO | TESTED |
| ASB-028 | range-mismatch early return (79-81) | Length or element mismatch returns false before stabilization check. | `A::AttachedViewState::equals`; `A_wbtest` | TODO | TESTED |
| ASB-029 | stabilization-mismatch early return (82-84) | Equal ranges with different `stabilized` return false. | `A::AttachedViewState::equals`; `A_wbtest` | TODO | TESTED |
| ASB-030 | `AttachedViewImpl` class (89) | Private implementation of `IAttachedView`. | `A::AttachedViewImpl` | TODO | PORTED |
| ASB-031 | `_state` field (90) | Settable optional state with equality suppression. | `A::AttachedViewImpl.state_cell` | TODO | PORTED |
| ASB-032 | `state` getter (91) | Exposes the cell read-only. | `A::AttachedViewImpl::state` | TODO | PORTED |
| ASB-033 | `AttachedViewImpl.constructor` (93-97) | Builds optional state with explicit equality and initial undefined. | `A::AttachedViewImpl::new`; `A_wbtest` | TODO | TESTED |
| ASB-034 | `handleStateChange` constructor property (94) | Owner callback invoked after state commit. | `A::AttachedViewImpl.handle_state_change` | TODO | PORTED |
| ASB-035 | observable option `owner` (96) | Reactive diagnostics owner. | `viewer/common/model/tokens/abstract_syntax_token_backend.mbt` source-shaped seam for observable option `owner` (96) | TODO | N-A (local state cell has no observable-owner metadata) |
| ASB-036 | observable option `equalsFn` (96) | Optional-state equality delegates defined values to `AttachedViewState.equals`. | `A::AttachedViewImpl::set_visible_lines`; `A_wbtest` | TODO | TESTED |
| ASB-037 | optional-state comparator callback (96) | Compares two defined states through `equals`. | `A::AttachedViewImpl::set_visible_lines`; `A_wbtest` | TODO | TESTED |
| ASB-038 | `setVisibleLines` member (99-104) | Convert ranges, construct state, commit cell, then notify owner. | `A::AttachedViewImpl::set_visible_lines`; `A_wbtest` | TODO | TESTED |
| ASB-039 | visible-line mapping callback (100) | Preserve start and convert inclusive end to exclusive `LineRange`. | `A::AttachedViewImpl::set_visible_lines`; `A_wbtest` | TODO | TESTED |
| ASB-040 | inclusive-to-exclusive constant (100) | `endLineNumber + 1` exactly. | `A::AttachedViewImpl::set_visible_lines`; `A_wbtest` | TODO | TESTED |
| ASB-041 | `AttachedViewHandler` class (108) | Per-view stabilized/debounced visible-range refresh owner. | `A::AttachedViewHandler` | TODO | PORTED |
| ASB-042 | `runner` field (109) | Owned one-shot scheduler invokes `update`. | `A::AttachedViewHandler.runner` | TODO | PORTED |
| ASB-043 | runner callback (109) | Calls `update` on expiry. | `A::AttachedViewHandler::new` callback; `A_wbtest` | TODO | TESTED |
| ASB-044 | debounce delay constant (109) | Exactly 50 ms. | `A::ATTACHED_VIEW_REFRESH_DELAY_MS`; `A_wbtest` | TODO | TESTED |
| ASB-045 | `_computedLineRanges` field (111) | Last ranges actually refreshed, initially empty. | `A::AttachedViewHandler.computed_line_ranges` | TODO | PORTED |
| ASB-046 | `_lineRanges` field (112) | Latest requested ranges, initially empty. | `A::AttachedViewHandler.line_ranges` | TODO | PORTED |
| ASB-047 | `lineRanges` getter (113) | Read-only latest requested ranges. | `A::AttachedViewHandler::line_ranges` | TODO | PORTED |
| ASB-048 | `AttachedViewHandler.constructor` (115-117) | Registers refresh callback and disposable scheduler. | `A::AttachedViewHandler::new`; `A_wbtest` | TODO | TESTED |
| ASB-049 | `_refreshTokens` constructor property (115) | Callback receives no arguments and reads handler ranges. | `A::AttachedViewHandler.refresh_tokens` | TODO | PORTED |
| ASB-050 | `update` member (119-125) | Equality guard; copy latest ranges; refresh once. | `A::AttachedViewHandler::update`; `A_wbtest` | TODO | TESTED |
| ASB-051 | update comparator callback (120) | Element equality via `LineRange.equals`. | `A::AttachedViewHandler::update`; `A_wbtest` | TODO | TESTED |
| ASB-052 | unchanged-ranges early return (120-122) | Equal requested/computed arrays suppress refresh. | `A::AttachedViewHandler::update`; `A_wbtest` | TODO | TESTED |
| ASB-053 | `handleStateChange` member (127-135) | Replace latest ranges then choose immediate/debounced refresh. | `A::AttachedViewHandler::handle_state_change`; `A_wbtest` | TODO | TESTED |
| ASB-054 | `stabilized` decision (129-134) | True cancels pending and updates now; false schedules/restarts one-shot runner. | `A::AttachedViewHandler::handle_state_change`; `A_wbtest` | TODO | TESTED |
| ASB-055 | `AbstractSyntaxTokenBackend` class (138) | Shared state/events and syntactic backend contract. | `A::AbstractSyntaxTokenBackend` contract/facade | TODO | PORTED |
| ASB-056 | `_backgroundTokenizationState` abstract field (139) | Concrete mutable `InProgress/Completed` state. | `A::AbstractSyntaxTokenBackend.background_tokenization_state` | TODO | PORTED |
| ASB-057 | `backgroundTokenizationState` getter (140-142) | Returns current concrete field. | `P::background_tokenization_state`; `B_wbtest` | TODO | TESTED |
| ASB-058 | `_onDidChangeBackgroundTokenizationState` abstract field (144) | Concrete completion-state emitter. | `A::AbstractSyntaxTokenBackend.did_change_background_state` | TODO | PORTED |
| ASB-059 | `onDidChangeBackgroundTokenizationState` abstract event (146) | Internal event contract, deliberately not TextModel-public. | `P::on_did_change_background_tokenization_state` (package-private) | TODO | PORTED |
| ASB-060 | `_onDidChangeTokens` field (148) | Registered token-range emitter. | `A::AbstractSyntaxTokenBackend.did_change_tokens` | TODO | PORTED |
| ASB-061 | `onDidChangeTokens` field (150) | Internal event alias consumed by tokenization model part. | existing `P::on_did_change_tokens` | TODO | PORTED |
| ASB-062 | `_onDidChangeFontTokens` field (152) | Registered font-token update emitter. | `A::AbstractSyntaxTokenBackend.did_change_font_tokens`; routing evidence in `B_wbtest` (surface inventory supplies exact payload type) | TODO | TESTED |
| ASB-063 | `onDidChangeFontTokens` field (154) | Internal font-token event alias. | `P::on_did_change_font_tokens` (package-private); event-shape test in `B_wbtest` | TODO | TESTED |
| ASB-064 | `AbstractSyntaxTokenBackend.constructor` (156-161) | Stores codec/model access and initializes disposable base. | `A::AbstractSyntaxTokenBackend::new` | TODO | PORTED |
| ASB-065 | `_languageIdCodec` constructor property (157) | Shared codec used by stores/fallback. | `A::AbstractSyntaxTokenBackend.language_id_codec` | TODO | PORTED |
| ASB-066 | `_textModel` constructor property (158) | Read line/attach/size facts from the one synchronized live access carrier, never a copied model | `A::TokenizationModelAccess` borrowed from TextModel; no reverse model import | TODO | PORTED |
| ASB-067 | `todo_resetTokenization` abstract member (163) | Reset with optional token-change event. | `B::TokenizerSyntaxTokenBackend::reset_tokenization` | TODO | PORTED |
| ASB-068 | `handleDidChangeAttached` abstract member (165) | Restart background scheduling after attach state changes. | `B::TokenizerSyntaxTokenBackend::handle_did_change_attached` | TODO | PORTED |
| ASB-069 | `handleDidChangeContent` abstract member (167) | Flush/incremental invalidation entrypoint. | `B::TokenizerSyntaxTokenBackend::handle_did_change_content` | TODO | PORTED |
| ASB-070 | `forceTokenization` abstract member (169) | Demand-tokenize through a target line. | `P::force_tokenization(line_number)` | TODO | PORTED |
| ASB-071 | `hasAccurateTokensForLine` abstract member (171) | Accuracy query by state validity. | `P::has_accurate_tokens_for_line` | TODO | PORTED |
| ASB-072 | `isCheapToTokenize` abstract member (173) | Cheapness query with 2048-unit bound. | `P::is_cheap_to_tokenize` | TODO | PORTED |
| ASB-073 | `tokenizeIfCheap` member (175-179) | Force only when cheapness predicate succeeds. | `P::tokenize_if_cheap`; `B_wbtest` | TODO | TESTED |
| ASB-074 | cheapness decision (176-178) | False is exact no-op; true calls force once. | `P::tokenize_if_cheap`; `B_wbtest` | TODO | TESTED |
| ASB-075 | `getLineTokens` abstract member (181) | Return stored syntactic tokens for one line. | `P::get_line_tokens` | TODO | PORTED |
| ASB-076 | `getTokenTypeIfInsertingCharacter` abstract member (183) | Predict token type for hypothetical edit. | `viewer/common/model/tokens/abstract_syntax_token_backend.mbt` source-shaped seam for `getTokenTypeIfInsertingCharacter` abstract member (183) | TODO | N-A (editable-only insertion prediction; readonly public surface has no insertion command) |
| ASB-077 | `tokenizeLinesAt` abstract member (185) | Tokenize hypothetical line array from a model state. | `viewer/common/model/tokens/abstract_syntax_token_backend.mbt` source-shaped seam for `tokenizeLinesAt` abstract member (185) | TODO | N-A (editable/paste support has no readonly consumer) |
| ASB-078 | `hasTokens` abstract getter (187) | Whether syntactic store contains any tokens. | existing `P::has_tokens`; `B_wbtest` | TODO | TESTED |

## TSB ledger — `tokenizerSyntaxTokenBackend.ts`

| ID | Source atom | Arithmetic / transition | Local target or seam | Status | Proposed terminal |
|---|---|---|---|---|---|
| TSB-001 | `TokenizerSyntaxTokenBackend` class (26) | Concrete TextMate/syntactic backend over state/store/background machinery. | `B::TokenizerSyntaxTokenBackend` | TODO | PORTED |
| TSB-002 | `_tokenizer` field (27) | Optional live `TokenizerWithStateStoreAndTextModel`, initially null. | `B::TokenizerSyntaxTokenBackend.tokenizer` | TODO | PORTED |
| TSB-003 | `_backgroundTokenizationState` field (28) | Starts exactly `InProgress`. | `B::TokenizerSyntaxTokenBackend.background_tokenization_state` | TODO | PORTED |
| TSB-004 | `_onDidChangeBackgroundTokenizationState` field (29) | Registered completion-state emitter. | `B::TokenizerSyntaxTokenBackend.did_change_background_state` | TODO | PORTED |
| TSB-005 | `onDidChangeBackgroundTokenizationState` field (30) | Event alias of state emitter. | `B::TokenizerSyntaxTokenBackend::on_did_change_background_tokenization_state` | TODO | PORTED |
| TSB-006 | `_defaultBackgroundTokenizer` field (32) | Optional identity of the locally-created default worker. | `B::TokenizerSyntaxTokenBackend.default_background_tokenizer` | TODO | PORTED |
| TSB-007 | `_backgroundTokenizer` field (33) | Owned mutable disposable holding custom or default worker. | `B::TokenizerSyntaxTokenBackend.background_tokenizer` | TODO | PORTED |
| TSB-008 | `_tokens` field (35) | Contiguous syntactic token store keyed by language codec. | `B::TokenizerSyntaxTokenBackend.tokens` (store implementation owned by contiguous-store inventory) | TODO | PORTED |
| TSB-009 | `_debugBackgroundTokens` field (36) | Optional verification-only token store. | `viewer/common/model/tokens/tokenizer_syntax_token_backend.mbt` source-shaped seam for `_debugBackgroundTokens` field (36) | TODO | DEFERRED (future custom background-tokenizer verification API) |
| TSB-010 | `_debugBackgroundStates` field (37) | Optional verification-only state tracker. | `viewer/common/model/tokens/tokenizer_syntax_token_backend.mbt` source-shaped seam for `_debugBackgroundStates` field (37) | TODO | DEFERRED (same verification dependency) |
| TSB-011 | `_debugBackgroundTokenizer` field (39) | Owned verification worker disposable. | `viewer/common/model/tokens/tokenizer_syntax_token_backend.mbt` source-shaped seam for `_debugBackgroundTokenizer` field (39) | TODO | DEFERRED (same verification dependency) |
| TSB-012 | `_attachedViewStates` field (41) | Disposable map from attached-view identity to per-view handler. | `B::TokenizerSyntaxTokenBackend.attached_view_states` | TODO | PORTED |
| TSB-013 | constructor (43-73) | Initialize base, registry subscription/reset, and attached-view subscription in source order. | `B::TokenizerSyntaxTokenBackend::new`; `B_wbtest` | TODO | TESTED |
| TSB-014 | `getLanguageId` constructor property (46) | Late language-id reader used on registry/reset. | `B::TokenizerSyntaxTokenBackend.get_language_id` | TODO | PORTED |
| TSB-015 | registry-change callback (51-57) | Read current language, ignore unrelated changes, otherwise reset. | `B::TokenizerSyntaxTokenBackend::new` registry callback; `B_wbtest` | TODO | TESTED |
| TSB-016 | unrelated-language early return (53-55) | `indexOf(languageId) === -1` performs no reset/event/work. | registry callback; `B_wbtest` | TODO | TESTED |
| TSB-017 | attached-visible-range callback (61-72) | Create/update handler for state, delete+dispose handler on detach. | `B::TokenizerSyntaxTokenBackend::new` attached callback; `B_wbtest` | TODO | TESTED |
| TSB-018 | state-present decision (62-71) | Defined state enters update path; undefined enters detach disposal path. | attached callback; `B_wbtest` | TODO | TESTED |
| TSB-019 | missing-handler decision (64-67) | Reuse existing identity handler or create/store exactly one. | attached callback; `B_wbtest` | TODO | TESTED |
| TSB-020 | handler refresh callback (65) | Refreshes the handler's current line ranges, including after later state changes. | `B::TokenizerSyntaxTokenBackend::refresh_ranges`; `B_wbtest` | TODO | TESTED |
| TSB-021 | `todo_resetTokenization` member (75-183) | Flush stores; optionally announce full range; re-resolve support; replace workers; refresh visible tokens. | `B::TokenizerSyntaxTokenBackend::reset_tokenization`; `B_wbtest` | TODO | TESTED |
| TSB-022 | `fireTokenChangeEvent = true` default (75) | Public reset announces unless explicitly suppressed by a content flush. | `B::reset_tokenization(fire_token_change_event?=true)`; `B_wbtest` | TODO | TESTED |
| TSB-023 | optional debug-token flush (77) | Flush verification store only when present. | `viewer/common/model/tokens/tokenizer_syntax_token_backend.mbt` source-shaped seam for optional debug-token flush (77) | TODO | DEFERRED (verification store dependency) |
| TSB-024 | debug-state reset decision (78-80) | Existing tracker is replaced with current line count; absence remains absent. | `viewer/common/model/tokens/tokenizer_syntax_token_backend.mbt` source-shaped seam for debug-state reset decision (78-80) | TODO | DEFERRED (verification store dependency) |
| TSB-025 | fire-event decision (81-91) | True emits one full-document range; false emits nothing here. | `B::reset_tokenization`; `B_wbtest` | TODO | TESTED |
| TSB-026 | reset event `semanticTokensApplied` property (83) | Always `false` for syntactic reset. | `ModelTokensChangedEvent.semantic_tokens_applied`; `B_wbtest` | TODO | TESTED |
| TSB-027 | reset event `ranges` property (84-90) | Exactly one inclusive range. | `ModelTokensChangedEvent.ranges`; `B_wbtest` | TODO | TESTED |
| TSB-028 | reset range `fromLineNumber` property (86) | Exactly one-based line `1`. | `ModelTokensChangedRange.from_line_number`; `B_wbtest` | TODO | TESTED |
| TSB-029 | reset range `toLineNumber` property (87) | Current model line count, inclusive. | `ModelTokensChangedRange.to_line_number`; `B_wbtest` | TODO | TESTED |
| TSB-030 | `initializeTokenization` callback (93-109) | Reject too-large/missing/failing support; otherwise return support and initial state. | `B::initialize_tokenization`; `B_wbtest` | TODO | TESTED |
| TSB-031 | too-large early return (94-96) | Too-large model disables all tokenization. | surface inventory's `TM::is_too_large_for_tokenization` fact consumed by `P/B`; threshold-below/at/above matrix in `B_wbtest` | TODO | TESTED |
| TSB-032 | missing-support early return (98-100) | Registry miss yields `[null,null]`, retaining null-token fallback store behavior. | `B::initialize_tokenization`; `B_wbtest` | TODO | TESTED |
| TSB-033 | `getInitialState` catch fallback (102-107) | Internal raising adapter reports unexpected error and disables support for this reset; public LineTokenizer is unchanged | `B::InternalTokenizationSupportAdapter.initial_state` plus `TokenizationModelAccess.report_unexpected_error`; `B_wbtest` | TODO | TESTED |
| TSB-034 | support/state decision (111-116) | Both present construct fresh stateful tokenizer; otherwise `_tokenizer = null`. | `B::reset_tokenization`; `B_wbtest` | TODO | TESTED |
| TSB-035 | tokenizer-present decision (121-180) | Only a live tokenizer constructs stores/workers; missing support skips the block. | `B::reset_tokenization`; `B_wbtest` | TODO | TESTED |
| TSB-036 | background store `setTokens` callback (123-125) | Route worker token batches through backend `setTokens`. | `B::BackgroundTokenizationStore.set_tokens`; `B_wbtest` | TODO | TESTED |
| TSB-037 | background store `setFontInfo` callback (126-128) | Route worker font changes through backend font event. | source-shaped `B::BackgroundTokenizationStore.set_font_info`; callback-routing test in `B_wbtest` | TODO | TESTED |
| TSB-038 | `backgroundTokenizationFinished` callback (129-137) | Complete once, store `Completed`, and fire state event. | `B::BackgroundTokenizationStore.background_tokenization_finished`; `B_wbtest` | TODO | TESTED |
| TSB-039 | already-completed early return (130-133) | Repeated finish never transitions back/progresses or fires again. | finish callback; `B_wbtest` | TODO | TESTED |
| TSB-040 | background store `setEndState` callback (138-145) | Accept worker state only at/after first definitely invalid line. | `viewer/common/model/tokens/tokenizer_syntax_token_backend.mbt` source-shaped seam for background store `setEndState` callback (138-145) | TODO | DEFERRED (custom background provider/update API absent from `S::LineTokenizer`) |
| TSB-041 | missing-tokenizer early return in `setEndState` (139) | Late custom-worker callback after reset/dispose is ignored. | `viewer/common/model/tokens/tokenizer_syntax_token_backend.mbt` source-shaped seam for missing-tokenizer early return in `setEndState` (139) | TODO | DEFERRED (same custom worker dependency) |
| TSB-042 | worker-state acceptance decision (142-144) | Require non-null invalid frontier and `lineNumber >= frontier`; reject worker-behind-renderer states. | `viewer/common/model/tokens/tokenizer_syntax_token_backend.mbt` source-shaped seam for worker-state acceptance decision (142-144) | TODO | DEFERRED (same custom worker dependency) |
| TSB-043 | custom-background decision (148-150) | Factory present and verification-only false selects custom tokenizer. | `viewer/common/model/tokens/tokenizer_syntax_token_backend.mbt` source-shaped seam for custom-background decision (148-150) | TODO | DEFERRED (local tokenizer registry exposes no background factory) |
| TSB-044 | default-background fallback decision (151-155) | When custom worker absent and model not too large, create default worker and immediately `handleChanges`. | `B::reset_tokenization` + `MT::DefaultBackgroundTokenizer`; `B_wbtest` | TODO | TESTED |
| TSB-045 | verification-only decision (157-179) | True with factory builds debug stores/worker; else clears all three debug fields. | `viewer/common/model/tokens/tokenizer_syntax_token_backend.mbt` source-shaped seam for verification-only decision (157-179) | TODO | DEFERRED (future custom verification API; both arms must land together) |
| TSB-046 | debug store `setTokens` callback (162-164) | Write worker batches only into debug store. | `viewer/common/model/tokens/tokenizer_syntax_token_backend.mbt` source-shaped seam for debug store `setTokens` callback (162-164) | TODO | DEFERRED (verification dependency) |
| TSB-047 | optional debug-token-store decision (163) | Late callback is harmless after store cleanup. | `viewer/common/model/tokens/tokenizer_syntax_token_backend.mbt` source-shaped seam for optional debug-token-store decision (163) | TODO | DEFERRED (verification dependency) |
| TSB-048 | debug store `setFontInfo` callback (165-167) | Font updates still use live font event, not debug-only storage. | `viewer/common/model/tokens/tokenizer_syntax_token_backend.mbt` source-shaped seam for debug store `setFontInfo` callback (165-167) | TODO | DEFERRED (verification plus font-token dependencies) |
| TSB-049 | debug `backgroundTokenizationFinished` callback (168-170) | Intentional no-op. | `viewer/common/model/tokens/tokenizer_syntax_token_backend.mbt` source-shaped seam for debug `backgroundTokenizationFinished` callback (168-170) | TODO | DEFERRED (verification dependency) |
| TSB-050 | debug store `setEndState` callback (171-173) | Record background end state in debug tracker. | `viewer/common/model/tokens/tokenizer_syntax_token_backend.mbt` source-shaped seam for debug store `setEndState` callback (171-173) | TODO | DEFERRED (verification dependency) |
| TSB-051 | optional debug-state decision (172) | Late callback after cleanup is ignored. | `viewer/common/model/tokens/tokenizer_syntax_token_backend.mbt` source-shaped seam for optional debug-state decision (172) | TODO | DEFERRED (verification dependency) |
| TSB-052 | `handleDidChangeAttached` member (185-187) | Re-evaluate default work from TextModel's aggregate attached count after source-order count transition | `B::handle_did_change_attached` reads `TokenizationModelAccess.attached_count`; `B_wbtest` | TODO | TESTED |
| TSB-053 | optional default-worker decision (186) | Missing custom/no-support worker is no-op; present worker handles first/final attach transition and scheduler generation | `B::handle_did_change_attached`; `B_wbtest` | TODO | TESTED |
| TSB-054 | `handleDidChangeContent` member (189-207) | Flush reset or incremental edit-store/state update; EOL-only no-op. | `B::handle_did_change_content`; flush evidence plus explicit branch terminals TSB-055-061 | TODO | TESTED |
| TSB-055 | flush decision (190-193) | `reset_tokenization(false)` suppresses only the full-reset event; its later visible refresh may emit bounded exact visible ranges | `viewer/common/model/text_model.mbt` -> `B::reset_tokenization(false)`; `viewer/common/view_model/set_value_flush_test.mbt` proves old/new projection domains | TODO | TESTED |
| TSB-056 | non-EOL incremental decision (193-206) | Non-flush non-EOL edits enter incremental lane; EOL-only changes do nothing. | `viewer/common/model/tokens/tokenizer_syntax_token_backend.mbt` source-shaped seam for non-EOL incremental decision (193-206) | TODO | N-A (readonly model exposes only whole-buffer flush; EOL plan exposes no `setEOL`) |
| TSB-057 | incremental changes loop (194-199) | Apply every change in event order. | `viewer/common/model/tokens/tokenizer_syntax_token_backend.mbt` source-shaped seam for incremental changes loop (194-199) | TODO | N-A (incremental edit API absent) |
| TSB-058 | optional debug-token edit decision (198) | Mirror edit into verification store when present. | `viewer/common/model/tokens/tokenizer_syntax_token_backend.mbt` source-shaped seam for optional debug-token edit decision (198) | TODO | DEFERRED (verification dependency, additionally dormant without incremental edits) |
| TSB-059 | optional debug-state edit decision (200) | Update verification state tracker when present. | `viewer/common/model/tokens/tokenizer_syntax_token_backend.mbt` source-shaped seam for optional debug-state edit decision (200) | TODO | DEFERRED (verification dependency, additionally dormant without incremental edits) |
| TSB-060 | tokenizer-present incremental-state decision (202-204) | Apply changes to live state store only when support exists. | `viewer/common/model/tokens/tokenizer_syntax_token_backend.mbt` source-shaped seam for tokenizer-present incremental-state decision (202-204) | TODO | N-A (incremental edit API absent) |
| TSB-061 | optional default-worker change decision (205) | Restart default background work after incremental edits. | `viewer/common/model/tokens/tokenizer_syntax_token_backend.mbt` source-shaped seam for optional default-worker change decision (205) | TODO | N-A (incremental edit API absent; attach restart is separately TESTED) |
| TSB-062 | `setTokens` member (209-217) | Store multiline batches, fire only changed ranges, return the same change set. | `B::set_tokens`; `B_wbtest` | TODO | TESTED |
| TSB-063 | nonempty-change decision (212-214) | Empty store delta emits nothing; nonempty emits once. | `B::set_tokens`; `B_wbtest` | TODO | TESTED |
| TSB-064 | set-token event `semanticTokensApplied` property (213) | Always false. | `ModelTokensChangedEvent.semantic_tokens_applied`; `B_wbtest` | TODO | TESTED |
| TSB-065 | set-token event `ranges` property (213) | Exact store-returned inclusive ranges, no widening. | `ModelTokensChangedEvent.ranges`; `B_wbtest` | TODO | TESTED |
| TSB-066 | return object `changes` property (216) | Returns exact same changes for heuristic re-request. | `B::TokenStoreChange.changes`; `B_wbtest` | TODO | TESTED |
| TSB-067 | `setFontInfo` member (219-221) | Fire font-token event with supplied changes. | `B::set_font_info`; `B_wbtest` | TODO | TESTED |
| TSB-068 | font event `changes` property (220) | Payload preserves change array. | surface payload type + `B::set_font_info`; `B_wbtest` | TODO | TESTED |
| TSB-069 | `refreshAllVisibleLineTokens` member (223-226) | Join current handler ranges and refresh; changed stored lines may emit bounded token ranges even during a false-event flush | `B::refresh_all_visible_line_tokens`; ViewModel `:510-523` conversion proves every early range in old/new projection domains | TODO | TESTED |
| TSB-070 | attached-state map callback (224) | Extract each handler's current `line_ranges`. | `B::refresh_all_visible_line_tokens`; `B_wbtest` | TODO | TESTED |
| TSB-071 | `refreshRanges` member (228-232) | Iterate normalized line ranges and refresh each inclusive span. | `B::refresh_ranges`; `B_wbtest` | TODO | TESTED |
| TSB-072 | ranges loop (229-231) | Preserve range order; one refresh per joined range. | `B::refresh_ranges`; `B_wbtest` | TODO | TESTED |
| TSB-073 | exclusive-to-inclusive constant (230) | Pass `endLineNumberExclusive - 1`. | `B::refresh_ranges`; `B_wbtest` | TODO | TESTED |
| TSB-074 | `refreshRange` member (234-256) | Clamp, heuristic-tokenize, store, optionally request accurate replacements, check completion. | `B::refresh_range`; `B_wbtest` | TODO | TESTED |
| TSB-075 | no-tokenizer early return (235-237) | Missing support does zero heuristic/background work. | `B::refresh_range`; `B_wbtest` | TODO | TESTED |
| TSB-076 | range-clamp constant/formula (239-240) | Start clamps to `[1,lineCount]`; end clamps only to `<= lineCount`, preserving source order. | `B::refresh_range`; `B_wbtest` | TODO | TESTED |
| TSB-077 | `heuristicTokens` decision (246-253) | Accurate path stops; heuristic path re-requests every changed range. | `B::refresh_range`; `B_wbtest` | TODO | TESTED |
| TSB-078 | changed-range loop (250-252) | Re-request each exact changed interval. | `B::refresh_range`; `B_wbtest` | TODO | TESTED |
| TSB-079 | optional background-worker request decision (251) | Any installed worker receives request; absent worker is no-op. | default/absent instances in `B::refresh_range`; custom-worker construction is separately TSB-043 | TODO | TESTED |
| TSB-080 | inclusive-to-exclusive request constant (251) | Request `[fromLineNumber, toLineNumber + 1)`. | `B::refresh_range`; `B_wbtest` | TODO | TESTED |
| TSB-081 | optional default-worker completion decision (255) | Check finish only for the locally-created default worker. | `B::refresh_range`; `B_wbtest` | TODO | TESTED |
| TSB-082 | `forceTokenization` member (258-263) | Build through requested line, store result, then check default completion. | `P::force_tokenization(line_number)` / `B::force_tokenization`; `B_wbtest` | TODO | TESTED |
| TSB-083 | optional tokenizer update decision (260) | Missing support produces empty builder/store delta rather than error. | `B::force_tokenization`; `B_wbtest` | TODO | TESTED |
| TSB-084 | optional default-worker completion decision (262) | Check only when default worker exists. | `B::force_tokenization`; `B_wbtest` | TODO | TESTED |
| TSB-085 | `hasAccurateTokensForLine` member (265-270) | Missing support is accurate; otherwise delegate state frontier. | `P::has_accurate_tokens_for_line`; `B_wbtest` | TODO | TESTED |
| TSB-086 | no-tokenizer accuracy early return (266-268) | Exactly `true`. | `P::has_accurate_tokens_for_line`; `B_wbtest` | TODO | TESTED |
| TSB-087 | `isCheapToTokenize` member (272-277) | Missing support is cheap; otherwise delegate length/frontier rule. | `P::is_cheap_to_tokenize`; `B_wbtest` | TODO | TESTED |
| TSB-088 | no-tokenizer cheapness early return (273-275) | Exactly `true`. | `P::is_cheap_to_tokenize`; `B_wbtest` | TODO | TESTED |
| TSB-089 | `getLineTokens` member (279-299) | Read line text and store tokens; optionally compare debug worker result. | existing `P::get_line_tokens`; `P_wbtest` (debug decisions are separately TSB-091-093) | TODO | TESTED |
| TSB-090 | line-index conversion constant (283-284,290-291) | One-based model line maps to zero-based store index `lineNumber - 1`. | `B::get_line_tokens`; `B_wbtest` | TODO | TESTED |
| TSB-091 | debug-triple presence decision (286-297) | Compare only when debug tokens, debug states, and live tokenizer all exist. | `viewer/common/model/tokens/tokenizer_syntax_token_backend.mbt` source-shaped seam for debug-triple presence decision (286-297) | TODO | DEFERRED (verification dependency) |
| TSB-092 | both-state-frontiers decision (287) | Compare only when both workers have valid end states strictly beyond the queried line. | `viewer/common/model/tokens/tokenizer_syntax_token_backend.mbt` source-shaped seam for both-state-frontiers decision (287) | TODO | DEFERRED (verification dependency) |
| TSB-093 | mismatch/report decision (293-295) | Report only unequal tokens and a worker-provided reporter. | `viewer/common/model/tokens/tokenizer_syntax_token_backend.mbt` source-shaped seam for mismatch/report decision (293-295) | TODO | DEFERRED (verification dependency) |
| TSB-094 | `getTokenTypeIfInsertingCharacter` member (301-309) | Validate position, force its line, ask tokenizer for hypothetical insertion type. | `viewer/common/model/tokens/tokenizer_syntax_token_backend.mbt` source-shaped seam for `getTokenTypeIfInsertingCharacter` member (301-309) | TODO | N-A (editable-only insertion prediction) |
| TSB-095 | missing-tokenizer insertion early return (302-304) | Returns `StandardTokenType.Other`. | `viewer/common/model/tokens/tokenizer_syntax_token_backend.mbt` source-shaped seam for missing-tokenizer insertion early return (302-304) | TODO | N-A (same editable-only boundary) |
| TSB-096 | one-based insertion-column constant (306-308) | Validated column is consumed by downstream `column - 1` offsets. | `viewer/common/model/tokens/tokenizer_syntax_token_backend.mbt` source-shaped seam for one-based insertion-column constant (306-308) | TODO | N-A (same editable-only boundary) |
| TSB-097 | `tokenizeLinesAt` member (312-318) | Force start line then tokenize supplied hypothetical lines. | `viewer/common/model/tokens/tokenizer_syntax_token_backend.mbt` source-shaped seam for `tokenizeLinesAt` member (312-318) | TODO | N-A (editable/paste support absent) |
| TSB-098 | missing-tokenizer line-array early return (313-315) | Returns null. | `viewer/common/model/tokens/tokenizer_syntax_token_backend.mbt` source-shaped seam for missing-tokenizer line-array early return (313-315) | TODO | N-A (same editable-only boundary) |
| TSB-099 | `hasTokens` getter (320-322) | Delegate contiguous store's `hasTokens`. | existing `P::has_tokens`; `B_wbtest` | TODO | TESTED |
| TSB-100 | completed-state preservation across `todo_resetTokenization` (`tokenizerSyntaxTokenBackend.ts:75-183`; state assignment exists only at `:134-136`) | Reset does not restore `InProgress`: once completed, a reset remains completed and a later worker-finished callback takes the already-completed early return without another event | `B::reset_tokenization`; `B_wbtest` completed -> reset -> finished state/event matrix | TODO | TESTED |

## TMS ledger — `textModelTokens.ts`

| ID | Source atom | Arithmetic / transition | Local target or seam | Status | Proposed terminal |
|---|---|---|---|---|---|
| TMS-001 | `Constants` const enum (23-25) | Owns tokenization cost constants. | `MT` constants section | TODO | PORTED |
| TMS-002 | `CHEAP_TOKENIZATION_LENGTH_LIMIT` (24) | Exactly 2048 UTF-16 code units; comparison is strict `<`. | `MT::CHEAP_TOKENIZATION_LENGTH_LIMIT`; `MT_wbtest` at 2047/2048 | TODO | TESTED |
| TMS-003 | `TokenizerWithStateStore` class (27) | Tokenizer support plus initial/end-state tracker. | `MT::TokenizerWithStateStore` | TODO | PORTED |
| TMS-004 | `initialState` field (28) | Private initial state acquired from support. | `MT::TokenizerWithStateStore.initial_state` | TODO | PORTED |
| TMS-005 | `store` field (30) | Public tracking state store. | `MT::TokenizerWithStateStore.store` | TODO | PORTED |
| TMS-006 | constructor (32-38) | Calls support `getInitialState` and creates tracker for exact line count. | `MT::TokenizerWithStateStore::new`; `MT_wbtest` (including reset's second initial-state call) | TODO | TESTED |
| TMS-007 | `tokenizationSupport` constructor property (34) | Public support identity retained by store. | `MT::TokenizerWithStateStore.tokenization_support` | TODO | PORTED |
| TMS-008 | `getStartState` member (40-42) | Delegate line number and stored initial state. | `MT::TokenizerWithStateStore::get_start_state`; `MT_wbtest` | TODO | TESTED |
| TMS-009 | `getFirstInvalidLine` member (44-46) | Delegate tracker with initial state. | `MT::TokenizerWithStateStore::get_first_invalid_line`; `MT_wbtest` | TODO | TESTED |
| TMS-010 | `TokenizerWithStateStoreAndTextModel` class (49) | Adds line access/codec and demand/heuristic tokenization. | `MT::TokenizerWithStateStoreAndTextModel` | TODO | PORTED |
| TMS-011 | constructor (50-57) | Preserve base initialization before storing access facts. | `MT::TokenizerWithStateStoreAndTextModel::new`; `MT_wbtest` | TODO | TESTED |
| TMS-012 | `_textModel` constructor property (53) | Live line/language/attachment facts. | `P` normalized lines plus attached/large facts, consumed by `MT` (no-cycle adaptation) | TODO | PORTED |
| TMS-013 | `_languageIdCodec` constructor property (54) | Codec used by safe/fallback tokenization. | `MT::TokenizerWithStateStoreAndTextModel.language_id_codec` | TODO | PORTED |
| TMS-014 | `updateTokensUntilLine` member (59-74) | Repeatedly tokenize first invalid line through inclusive target, add tokens, commit end state. | `MT::TokenizerWithStateStoreAndTextModel::update_tokens_until_line`; `MT_wbtest` | TODO | TESTED |
| TMS-015 | `while (true)` loop (62-73) | Continues only as invalid frontier advances. | `MT::update_tokens_until_line`; `MT_wbtest` | TODO | TESTED |
| TMS-016 | invalid/beyond-target break decision (64-66) | Stop when no invalid line or first invalid line is greater than requested line. | `MT::update_tokens_until_line`; `MT_wbtest` | TODO | TESTED |
| TMS-017 | normal-line `hasEOL` constant (70) | `safeTokenize(..., true, ...)` for model lines. | `MT::update_tokens_until_line`; tokenizer call log in `MT_wbtest` | TODO | TESTED |
| TMS-018 | `getTokenTypeIfInsertingCharacter` member (77-102) | Hypothetically insert one character and classify covering token. | `viewer/common/model/tokens/text_model_tokens.mbt` source-shaped seam for `getTokenTypeIfInsertingCharacter` member (77-102) | TODO | N-A (editable-only insertion prediction; no readonly consumer) |
| TMS-019 | missing-start-state early return (80-82) | Return `StandardTokenType.Other`. | `viewer/common/model/tokens/text_model_tokens.mbt` source-shaped seam for missing-start-state early return (80-82) | TODO | N-A (same editable-only boundary) |
| TMS-020 | insertion/index constant (88-100) | Slice and lookup at `position.column - 1`. | `viewer/common/model/tokens/text_model_tokens.mbt` source-shaped seam for insertion/index constant (88-100) | TODO | N-A (same editable-only boundary) |
| TMS-021 | hypothetical-line `hasEOL` constant (94) | Tokenize synthetic line with `true`. | `viewer/common/model/tokens/text_model_tokens.mbt` source-shaped seam for hypothetical-line `hasEOL` constant (94) | TODO | N-A (same editable-only boundary) |
| TMS-022 | zero-token early return (96-98) | Empty result returns `Other` before index lookup. | `viewer/common/model/tokens/text_model_tokens.mbt` source-shaped seam for zero-token early return (96-98) | TODO | N-A (same editable-only boundary) |
| TMS-023 | `tokenizeLinesAt` member (105-122) | Start from model state and tokenize supplied lines in order. | `viewer/common/model/tokens/text_model_tokens.mbt` source-shaped seam for `tokenizeLinesAt` member (105-122) | TODO | N-A (editable/paste support absent) |
| TMS-024 | missing-start-state early return (107-109) | Return null. | `viewer/common/model/tokens/text_model_tokens.mbt` source-shaped seam for missing-start-state early return (107-109) | TODO | N-A (same editable-only boundary) |
| TMS-025 | supplied-lines loop (115-119) | Emit `LineTokens` and thread each returned end state. | `viewer/common/model/tokens/text_model_tokens.mbt` source-shaped seam for supplied-lines loop (115-119) | TODO | N-A (same editable-only boundary) |
| TMS-026 | supplied-line `hasEOL` constant (116) | Tokenize every supplied line with `true`. | `viewer/common/model/tokens/text_model_tokens.mbt` source-shaped seam for supplied-line `hasEOL` constant (116) | TODO | N-A (same editable-only boundary) |
| TMS-027 | `hasAccurateTokensForLine` member (124-127) | Accurate iff `lineNumber < firstInvalidEndStateOrMax`. | `MT::TokenizerWithStateStoreAndTextModel::has_accurate_tokens_for_line`; `MT_wbtest` | TODO | TESTED |
| TMS-028 | `isCheapToTokenize` member (129-140) | Accurate lines are cheap; first invalid short line is cheap; all others are not. | `MT::TokenizerWithStateStoreAndTextModel::is_cheap_to_tokenize`; `MT_wbtest` | TODO | TESTED |
| TMS-029 | already-accurate early return (131-133) | Strictly before frontier returns true independent of length. | `MT::is_cheap_to_tokenize`; `MT_wbtest` | TODO | TESTED |
| TMS-030 | first-invalid short-line decision (134-137) | Exactly frontier and length `< 2048` returns true. | `MT::is_cheap_to_tokenize`; `MT_wbtest` at 2047/2048 and later invalid line | TODO | TESTED |
| TMS-031 | `tokenizeHeuristically` member (145-168) | Choose no-op, accurate-forward demand, or guessed-state viewport tokenization. | `MT::TokenizerWithStateStoreAndTextModel::tokenize_heuristically`; `MT_wbtest` | TODO | TESTED |
| TMS-032 | end-before/frontier early return (146-149) | `endLineNumber <= frontier` returns `{ heuristicTokens:false }` without work. | `MT::tokenize_heuristically`; `MT_wbtest` | TODO | TESTED |
| TMS-033 | start-before/frontier decision (151-155) | `start <= frontier` tokenizes accurately through end and returns non-heuristic. | `MT::tokenize_heuristically`; `MT_wbtest` | TODO | TESTED |
| TMS-034 | heuristic range loop (160-165) | Inclusive `start..end`, add each result, thread guessed state without mutating state store. | `MT::tokenize_heuristically`; `MT_wbtest` | TODO | TESTED |
| TMS-035 | heuristic-line `hasEOL` constant (162) | Viewport lines tokenize with `true`. | tokenizer call log in `MT_wbtest` | TODO | TESTED |
| TMS-036 | `guessStartState` member (170-184) | Find indentation ancestors, choose cached or fresh state, replay ancestors without EOL. | `MT::TokenizerWithStateStoreAndTextModel::guess_start_state`; `MT_wbtest` | TODO | TESTED |
| TMS-037 | absent-initial-state decision (173-175) | No cached ancestor state calls support `getInitialState`. | `MT::guess_start_state`; `MT_wbtest` | TODO | TESTED |
| TMS-038 | relevant-lines loop (179-182) | Replay in forward order, threading state. | `MT::guess_start_state`; `MT_wbtest` | TODO | TESTED |
| TMS-039 | replay `hasEOL` constant (180) | Ancestor replay passes `false`. | tokenizer call log in `MT_wbtest` | TODO | TESTED |
| TMS-040 | `findLikelyRelevantLines` function (187-209) | Walk backward across indentation, return ordered ancestors and optional cached state. | `MT::find_likely_relevant_lines`; `MT_wbtest` | TODO | TESTED |
| TMS-041 | backward-walk loop (191-205) | Continue while current indentation is deeper than column 1 and line index remains >= 1. | `MT::find_likely_relevant_lines`; `MT_wbtest` | TODO | TESTED |
| TMS-042 | whitespace-line continue (194-196) | First-non-whitespace column `0` is ignored without changing current indentation. | `MT::find_likely_relevant_lines`; `MT_wbtest` | TODO | TESTED |
| TMS-043 | lower-indentation decision (197-204) | Only a strictly smaller non-whitespace column is relevant/pushed. | `MT::find_likely_relevant_lines`; `MT_wbtest` | TODO | TESTED |
| TMS-044 | cached-state break decision (200-203) | Optional store lookup at ancestor; truthy state stops backward search. | `MT::find_likely_relevant_lines`; `MT_wbtest` | TODO | TESTED |
| TMS-045 | nullish result fallback (208) | `null` initial state becomes absent/`None`; defined state is preserved. | `MT::find_likely_relevant_lines`; `MT_wbtest` | TODO | TESTED |
| TMS-046 | `TrackingTokenizationStateStore` class (216) | End-state storage plus invalid-line priority queue invariant. | `MT::TrackingTokenizationStateStore` | TODO | PORTED |
| TMS-047 | `_tokenizationStateStore` field (217) | Dense end-state storage. | `MT::TrackingTokenizationStateStore.tokenization_state_store` | TODO | PORTED |
| TMS-048 | `_invalidEndStatesLineNumbers` field (218) | Sorted disjoint invalid line ranges. | `MT::TrackingTokenizationStateStore.invalid_end_states_line_numbers` | TODO | PORTED |
| TMS-049 | constructor (220-222) | Seed every one-based line invalid. | `MT::TrackingTokenizationStateStore::new`; `MT_wbtest` | TODO | TESTED |
| TMS-050 | `lineCount` constructor property (220) | Mutable current line count. | `MT::TrackingTokenizationStateStore.line_count` | TODO | PORTED |
| TMS-051 | initial invalid-range constant (221) | Half-open `[1, lineCount + 1)`. | `MT::TrackingTokenizationStateStore::new`; `MT_wbtest` empty/one/many lines | TODO | TESTED |
| TMS-052 | `getEndState` member (224-226) | Delegate exact one-based line key. | `MT::TrackingTokenizationStateStore::get_end_state`; `MT_wbtest` | TODO | TESTED |
| TMS-053 | `setEndState` member (231-244) | Validate state, delete invalid marker, store state, invalidate next line only on changed nonfinal state. | `MT::TrackingTokenizationStateStore::set_end_state`; `MT_wbtest` | TODO | TESTED |
| TMS-054 | null-state throw decision (232-234) | Null/undefined state throws `BugIndicatingError`. | `viewer/common/model/tokens/text_model_tokens.mbt` source-shaped seam for null-state throw decision (232-234) | TODO | N-A (MoonBit `TokenizerState` is non-nullable; cannot construct this source-invalid input) |
| TMS-055 | changed-and-nonfinal decision (238-241) | Only changed state before final line invalidates successor. | `MT::set_end_state`; equal/changed x middle/final in `MT_wbtest` | TODO | TESTED |
| TMS-056 | successor-range constant (240) | Invalidate exactly `[lineNumber + 1, lineNumber + 2)`. | `MT::set_end_state`; `MT_wbtest` | TODO | TESTED |
| TMS-057 | `acceptChange` member (246-250) | Resize line count, dense states, and invalid queue for one edit. | `viewer/common/model/tokens/text_model_tokens.mbt` source-shaped seam for `acceptChange` member (246-250) | TODO | N-A (incremental edit API explicitly out of child scope) |
| TMS-058 | `acceptChanges` member (252-257) | Apply every content change in event order. | `viewer/common/model/tokens/text_model_tokens.mbt` source-shaped seam for `acceptChanges` member (252-257) | TODO | N-A (incremental edit API absent) |
| TMS-059 | accept-changes loop (253-256) | One `acceptChange` per change. | `viewer/common/model/tokens/text_model_tokens.mbt` source-shaped seam for accept-changes loop (253-256) | TODO | N-A (incremental edit API absent) |
| TMS-060 | edit line-count constants (254-255) | Old range end `+1`; inserted line count `eolCount + 1`. | `viewer/common/model/tokens/text_model_tokens.mbt` source-shaped seam for edit line-count constants (254-255) | TODO | N-A (incremental edit API absent) |
| TMS-061 | `invalidateEndStateRange` member (259-261) | Add exact line range to invalid queue. | `MT::TrackingTokenizationStateStore::invalidate_end_state_range`; `MT_wbtest` | TODO | TESTED |
| TMS-062 | `getFirstInvalidEndStateLineNumber` member (263) | Queue minimum or null. | `MT::TrackingTokenizationStateStore::get_first_invalid_end_state_line_number`; `MT_wbtest` | TODO | TESTED |
| TMS-063 | `getFirstInvalidEndStateLineNumberOrMax` member (265-267) | Return first invalid or numeric maximum sentinel. | `MT::TrackingTokenizationStateStore::get_first_invalid_end_state_line_number_or_max`; `MT_wbtest` | TODO | TESTED |
| TMS-064 | `MAX_SAFE_INTEGER` fallback decision/constant (266) | Empty queue falls back to `Number.MAX_SAFE_INTEGER`; queued one-based minima are never zero. | `Int::max_value()`/explicit local sentinel in `MT`; `MT_wbtest` | TODO | TESTED |
| TMS-065 | `allStatesValid` member (269) | True iff invalid queue minimum is null. | `MT::TrackingTokenizationStateStore::all_states_valid`; `MT_wbtest` | TODO | TESTED |
| TMS-066 | `getStartState` member (271-274) | Initial state for line 1; previous line end state otherwise. | `MT::TrackingTokenizationStateStore::get_start_state`; `MT_wbtest` | TODO | TESTED |
| TMS-067 | first-line early return (272) | `lineNumber === 1` returns initial state. | `MT::get_start_state`; `MT_wbtest` | TODO | TESTED |
| TMS-068 | predecessor constant (273) | Other lines read `lineNumber - 1`. | `MT::get_start_state`; `MT_wbtest` | TODO | TESTED |
| TMS-069 | `getFirstInvalidLine` member (276-287) | Resolve invalid minimum and its required start state into a pair. | `MT::TrackingTokenizationStateStore::get_first_invalid_line`; `MT_wbtest` | TODO | TESTED |
| TMS-070 | no-invalid-line early return (278-280) | Empty queue returns null. | `MT::get_first_invalid_line`; `MT_wbtest` | TODO | TESTED |
| TMS-071 | missing-start-state throw decision (282-284) | Invalid frontier without predecessor state throws bug error. | local invariant failure/abort seam in `MT::get_first_invalid_line`; `MT_wbtest` | TODO | TESTED |
| TMS-072 | result `lineNumber` property (286) | Exact invalid frontier. | `MT::FirstInvalidLine.line_number` | TODO | PORTED |
| TMS-073 | result `startState` property (286) | Exact resolved predecessor/initial state. | `MT::FirstInvalidLine.start_state` | TODO | PORTED |
| TMS-074 | `TokenizationStateStore` class (290) | Dense one-based end-state array with convergence retention. | `MT::TokenizationStateStore` | TODO | PORTED |
| TMS-075 | `_lineEndStates` field (291) | `FixedArray` default value is null. | `MT::TokenizationStateStore.line_end_states` | TODO | PORTED |
| TMS-076 | `getEndState` member (293-295) | Return state at exact line key. | `MT::TokenizationStateStore::get_end_state`; `MT_wbtest` | TODO | TESTED |
| TMS-077 | `setEndState` member (297-305) | Equality short-circuit; otherwise replace and report changed. | `MT::TokenizationStateStore::set_end_state`; `MT_wbtest` | TODO | TESTED |
| TMS-078 | equal-existing-state early return (299-301) | Existing state whose `.equals` succeeds returns false and preserves identity. | `MT::set_end_state`; `MT_wbtest` | TODO | TESTED |
| TMS-079 | `acceptChange` member (307-317) | Retain one trailing old state when old/new spans are nonempty, then replace remainder. | `viewer/common/model/tokens/text_model_tokens.mbt` source-shaped seam for `acceptChange` member (307-317) | TODO | N-A (incremental edit API absent) |
| TMS-080 | trailing-state retention decision (309-314) | If `newLineCount > 0 && oldLength > 0`, decrement both by one before replace. | `viewer/common/model/tokens/text_model_tokens.mbt` source-shaped seam for trailing-state retention decision (309-314) | TODO | N-A (incremental edit API absent) |
| TMS-081 | retention decrement constant (312-313) | Both counts decrement exactly `1`. | `viewer/common/model/tokens/text_model_tokens.mbt` source-shaped seam for retention decrement constant (312-313) | TODO | N-A (incremental edit API absent) |
| TMS-082 | `acceptChanges` member (319-324) | Apply all changes through line-count conversion. | `viewer/common/model/tokens/text_model_tokens.mbt` source-shaped seam for `acceptChanges` member (319-324) | TODO | N-A (incremental edit API absent) |
| TMS-083 | accept-changes loop (320-323) | One state-store edit per change. | `viewer/common/model/tokens/text_model_tokens.mbt` source-shaped seam for accept-changes loop (320-323) | TODO | N-A (incremental edit API absent) |
| TMS-084 | state-edit line-count constants (321-322) | Old range end `+1`; inserted count `eolCount + 1`. | `viewer/common/model/tokens/text_model_tokens.mbt` source-shaped seam for state-edit line-count constants (321-322) | TODO | N-A (incremental edit API absent) |
| TMS-085 | `RangePriorityQueue` interface (327-334) | Minimal invalid-offset priority queue contract. | `MT::RangePriorityQueue` trait/private contract | TODO | PORTED |
| TMS-086 | `min` interface getter (328) | Smallest value or null. | `MT::RangePriorityQueue::min` | TODO | PORTED |
| TMS-087 | `removeMin` interface member (329) | Remove/return smallest value or null. | `MT::RangePriorityQueue::remove_min` | TODO | PORTED |
| TMS-088 | `addRange` interface member (331) | Union a half-open range. | `MT::RangePriorityQueue::add_range` | TODO | PORTED |
| TMS-089 | `addRangeAndResize` interface member (333) | Replace/edit range and shift suffix. | `MT::RangePriorityQueue::add_range_and_resize` | TODO | PORTED |
| TMS-090 | `RangePriorityQueueImpl` class (336) | Sorted disjoint `OffsetRange` implementation. | `MT::RangePriorityQueueImpl`, re-exported by `M` | TODO | PORTED |
| TMS-091 | `_ranges` field (337) | Mutable sorted disjoint ranges, initially empty. | `MT::RangePriorityQueueImpl.ranges` | TODO | PORTED |
| TMS-092 | `getRanges` member (339-341) | Return backing array in queue order. | existing `M::RangePriorityQueueImpl::get_ranges`; queue reference test | TODO | TESTED |
| TMS-093 | `min` getter (343-348) | Empty -> null; otherwise first range start. | existing `M::RangePriorityQueueImpl::min`; expanded queue reference test | TODO | TESTED |
| TMS-094 | empty-min early return (344-346) | Exact null result. | queue reference test | TODO | TESTED |
| TMS-095 | `removeMin` member (350-361) | Empty null; remove singleton range or advance first start; return old start. | existing `M::RangePriorityQueueImpl::remove_min`; expanded queue reference test | TODO | TESTED |
| TMS-096 | empty-remove early return (351-353) | Exact null result. | queue reference test | TODO | TESTED |
| TMS-097 | singleton-range decision (355-359) | Length one shifts range out; longer range increments start. | queue reference test | TODO | TESTED |
| TMS-098 | remove/advance constant (355-358) | Singleton test `start + 1 === endExclusive`; remaining range starts `start + 1`. | queue reference test | TODO | TESTED |
| TMS-099 | `delete` member (363-381) | Find containing range; trim/remove/split around one value. | existing `M::RangePriorityQueueImpl::delete`; expanded queue reference test | TODO | TESTED |
| TMS-100 | `findIndex` callback (364) | First range whose `contains(value)` succeeds. | `M::delete`; expanded queue reference test | TODO | TESTED |
| TMS-101 | found-range decision (365-380) | `idx === -1` is no-op; found index mutates exactly one range. | `M::delete`; missing/present matrix | TODO | TESTED |
| TMS-102 | delete-at-start decision (367-373) | Start hit enters remove-or-trim arm; interior goes to end/split arm. | `M::delete`; start/interior matrix | TODO | TESTED |
| TMS-103 | singleton-at-start decision (368-372) | One-element range splices out; longer range advances start. | `M::delete`; singleton/long matrix | TODO | TESTED |
| TMS-104 | delete-at-end decision (374-378) | Interior value at last element trims end; otherwise splits into two ranges. | `M::delete`; end/middle matrix | TODO | TESTED |
| TMS-105 | delete split constant (368-377) | Right remainder starts at `value + 1`; half-open boundaries otherwise preserve `value`. | `M::delete`; expanded queue reference test | TODO | TESTED |
| TMS-106 | `addRange` member (383-385) | Delegate normalized union to `OffsetRange.addRange`. | existing `M::RangePriorityQueueImpl::add_range`; exact upstream `addRange` test | TODO | TESTED |
| TMS-107 | `addRangeAndResize` member (387-418) | Locate intersecting block, shift suffix by delta, insert/merge/delete replacement. | existing `M::RangePriorityQueueImpl::add_range_and_resize`; exact upstream test plus boundaries | TODO | TESTED |
| TMS-108 | first scan loop (389-391) | Advance while current range lies wholly before/touches edit according to source predicate. | `M::add_range_and_resize`; queue reference test | TODO | TESTED |
| TMS-109 | first-scan boundary predicate (389) | Stop when exhausted or `range.start <= current.endExclusive`; touching counts as possibly intersecting. | `M::add_range_and_resize`; touching boundaries | TODO | TESTED |
| TMS-110 | second scan loop (393-395) | Advance through every range not strictly after the edited range. | `M::add_range_and_resize`; queue reference test | TODO | TESTED |
| TMS-111 | second-scan boundary predicate (393) | Stop when exhausted or `range.endExclusive < current.start`; equality remains in candidate block. | `M::add_range_and_resize`; touching boundaries | TODO | TESTED |
| TMS-112 | suffix-shift loop (398-400) | Every range after candidate block receives `delta = newLength - range.length`. | `M::add_range_and_resize`; grow/shrink/zero matrices | TODO | TESTED |
| TMS-113 | no-intersection decision (402-417) | Equal scan indices enter pure insert; otherwise merge/replace intersecting block. | `M::add_range_and_resize`; disjoint/intersecting matrices | TODO | TESTED |
| TMS-114 | pure-insert range formula (403) | New half-open range is `[range.start, range.start + newLength)`. | `M::add_range_and_resize`; newLength zero/positive | TODO | TESTED |
| TMS-115 | pure-insert empty decision (404-406) | Empty replacement inserts nothing. | `M::add_range_and_resize`; zero-length matrix | TODO | TESTED |
| TMS-116 | merged-range formula (408-411) | `start=min(edit.start,first.start)`; `end=max(edit.end,last.end)+delta`. | `M::add_range_and_resize`; swallow/partial overlap/grow/shrink | TODO | TESTED |
| TMS-117 | merged-empty decision (412-416) | Nonempty replaces candidate block with one range; empty only deletes block. | `M::add_range_and_resize`; upstream final empty case | TODO | TESTED |
| TMS-118 | splice-count formula (413-415) | Delete exactly `idxFirstIsAfter - idxFirstMightBeIntersecting`. | `M::add_range_and_resize`; multiple-intersection matrix | TODO | TESTED |
| TMS-119 | `toString` member (420-422) | Join each range string with literal `" + "`. | `MT::RangePriorityQueueImpl::to_string`; expanded queue reference test | TODO | TESTED |
| TMS-120 | `toString` map callback (421) | Convert every range with its own `toString`. | `MT::RangePriorityQueueImpl::to_string`; expanded queue reference test | TODO | TESTED |
| TMS-121 | `safeTokenize` function (426-443) | Clone/pass state, call support when present, catch failure, null-token fallback, convert offsets. | `MT::safe_tokenize`; `MT_wbtest` | TODO | TESTED |
| TMS-122 | support-present decision (429-435) | Present attempts real tokenizer; absent skips directly to fallback. | `MT::safe_tokenize`; `MT_wbtest` | TODO | TESTED |
| TMS-123 | tokenize catch fallback (430-434) | Internal raising adapter reports the error and leaves result null for fallback; public LineTokenizer remains nonraising | `MT::safe_tokenize` + `InternalTokenizationSupportAdapter.tokenize` + carrier reporter; failing-adapter test | TODO | TESTED |
| TMS-124 | missing-result fallback decision (437-439) | Null/missing/failed support calls `nullTokenizeEncoded`. | `MT::safe_tokenize`; missing/failing support matrix | TODO | TESTED |
| TMS-125 | state-clone contract (431) | Source passes `state.clone()` so support cannot mutate caller-owned state; local immutable `TokenizerState` passes by value. | immutable-state seam at `S::TokenizerState`; `MT_wbtest` | TODO | TESTED |
| TMS-126 | end-offset conversion (`textModelTokens.ts:441`) | Convert raw start-offset encoded words to end offsets exactly once using UTF-16 `text.length` | `viewer/common/model/tokens/line_tokens_encoder.mbt::start_offsets_to_end_offsets`; forbid intermediate end-offset `LineTokens` | TODO | TESTED |
| TMS-127 | `DefaultBackgroundTokenizer` class (445) | Default idle/deadline worker over live state store. | `MT::DefaultBackgroundTokenizer` | TODO | PORTED |
| TMS-128 | `_isDisposed` field (446) | Starts false; terminal true. | `MT::DefaultBackgroundTokenizer.is_disposed` | TODO | PORTED |
| TMS-129 | constructor (448-452) | Stores tokenizer and output store. | `MT::DefaultBackgroundTokenizer::new` | TODO | PORTED |
| TMS-130 | `_tokenizerWithStateStore` constructor property (449) | Non-null live tokenizer/state owner. | `MT::DefaultBackgroundTokenizer.tokenizer_with_state_store` | TODO | PORTED |
| TMS-131 | `_backgroundTokenStore` constructor property (450) | Token batch/completion callback contract. | `MT::DefaultBackgroundTokenizer.background_token_store` | TODO | PORTED |
| TMS-132 | `dispose` member (454-456) | Set disposed, cancel/invalidate pending idle/zero handles, reset gate; every stale callback is inert | `MT::DefaultBackgroundTokenizer::dispose`; deterministic scheduler cancellation test | TODO | TESTED |
| TMS-133 | `handleChanges` member (458-460) | Begin/restart background scheduling. | `MT::DefaultBackgroundTokenizer::handle_changes`; `MT_wbtest` | TODO | TESTED |
| TMS-134 | `_isScheduled` field (462) | Coalescing flag, initially false. | `MT::DefaultBackgroundTokenizer.is_scheduled` | TODO | PORTED |
| TMS-135 | `_beginBackgroundTokenization` member (`textModelTokens.ts:463-474`) | `scheduler=None`, already-scheduled, detached, or finished returns; otherwise retain idle cancel handle/generation and only matching callback clears it | `MT::DefaultBackgroundTokenizer::begin_background_tokenization`; manual/no-scheduler and replacement tests | TODO | TESTED |
| TMS-136 | begin compound early-return decision (464-466) | Return if already scheduled OR TextModel attached count is zero OR no invalid lines; each operand independent | `MT::begin_background_tokenization`; 2x2x2 deterministic matrix | TODO | TESTED |
| TMS-137 | idle callback (469-473) | Only the matching live generation clears `_isScheduled`; stale old-scheduler callbacks cannot clear a fresh generation | `MT::TokenizationScheduler.idle` callback/generation guard | TODO | TESTED |
| TMS-138 | `_backgroundTokenizeWithDeadline` member (479-502) | Capture end time, run cancellable work slices, yield or request next idle turn. | `MT::DefaultBackgroundTokenizer::background_tokenize_with_deadline`; `MT_wbtest` | TODO | TESTED |
| TMS-139 | immediate deadline capture contract (480-482) | Read `deadline.timeRemaining()` before leaving the method. | injected deadline object; `MT_wbtest` invalid-after-return oracle | TODO | TESTED |
| TMS-140 | end-time formula (482) | `now + timeRemaining`, using source order. | injected clock; `MT_wbtest` | TODO | TESTED |
| TMS-141 | `execute` callback (484-500) | Guard; work >=1 ms; compare deadline; queue zero-timeout continuation or next idle request. | injected scheduler callback; `MT_wbtest` | TODO | TESTED |
| TMS-142 | execute compound early return (485-488) | Return if disposed OR TextModel attached count is zero OR finished; final detach/dispose callbacks are inert | `MT::background_tokenize_with_deadline`; post-schedule cancellation matrix | TODO | TESTED |
| TMS-143 | deadline decision (492-499) | `now < endTime` yields via `setTimeout0(execute)`; otherwise re-enters idle scheduling. | injected clock/scheduler; `MT_wbtest` before/equal/after boundary | TODO | TESTED |
| TMS-144 | initial execute invocation (501) | First slice runs synchronously inside the idle callback, before any zero-timeout. | `MT_wbtest` callback trace | TODO | TESTED |
| TMS-145 | `_backgroundTokenizeForAtLeast1ms` member (507-529) | Tokenize bounded invalid lines, flush one builder batch, then check completion. | `MT::DefaultBackgroundTokenizer::background_tokenize_for_at_least_1ms`; `MT_wbtest` | TODO | TESTED |
| TMS-146 | do-loop (512-525) | Attempts at least one iteration before `_hasLinesToTokenize` continuation check. | `MT::background_tokenize_for_at_least_1ms`; `MT_wbtest` | TODO | TESTED |
| TMS-147 | elapsed-time early break/magic constant (513-518) | Break only when `elapsed() > 1`, not `>= 1`. | injected monotonic clock; `MT_wbtest` at 1.0 and >1.0 | TODO | TESTED |
| TMS-148 | final-line early break (522-524) | Stop slice when tokenized line number is `>= lineCount`. | `MT::background_tokenize_for_at_least_1ms`; final-line matrix | TODO | TESTED |
| TMS-149 | do-while validity decision (525) | Continue while invalid lines remain after each iteration. | `MT::background_tokenize_for_at_least_1ms`; multi-line/state-convergence matrix | TODO | TESTED |
| TMS-150 | `_hasLinesToTokenize` member (531-536) | Defensive null check then negate state-store validity. | live-store path in `MT::DefaultBackgroundTokenizer::has_lines_to_tokenize`; null branch is separately TMS-151 | TODO | TESTED |
| TMS-151 | missing-tokenizer early return (532-534) | Returns false despite constructor's non-null property. | `viewer/common/model/tokens/text_model_tokens.mbt` source-shaped seam for missing-tokenizer early return (532-534) | TODO | N-A (source defensive branch is unreachable under both TS and local non-null constructor types) |
| TMS-152 | `_tokenizeOneInvalidLine` member (538-545) | Read first invalid, sentinel if none, otherwise update exactly through that line. | `MT::DefaultBackgroundTokenizer::tokenize_one_invalid_line`; `MT_wbtest` | TODO | TESTED |
| TMS-153 | no-invalid-line early return/constant (540-542) | Return `lineCount + 1`. | `MT::tokenize_one_invalid_line`; `MT_wbtest` | TODO | TESTED |
| TMS-154 | `checkFinished` member (547-554) | Ignore disposed worker; notify store whenever all states valid. | `MT::DefaultBackgroundTokenizer::check_finished`; `MT_wbtest` | TODO | TESTED |
| TMS-155 | disposed early return (548-550) | Suppresses completion callback after disposal. | `MT::check_finished`; `MT_wbtest` | TODO | TESTED |
| TMS-156 | all-valid completion decision (551-553) | Valid store invokes `backgroundTokenizationFinished`; invalid store does not. | `MT::check_finished`; `MT_wbtest` | TODO | TESTED |
| TMS-157 | `requestTokens` member (556-558) | Mark requested line interval invalid; scheduling remains caller-owned. | `MT::DefaultBackgroundTokenizer::request_tokens`; `MT_wbtest` | TODO | TESTED |
| TMS-158 | request half-open range contract (557) | Preserve `[startLineNumber,endLineNumberExclusive)` exactly. | `MT::request_tokens`; `MT_wbtest` | TODO | TESTED |

## TMS consumed dependency closure

The builder and multiline-token rows below are counted because `textModelTokens.ts` creates them and `ContiguousTokensStore.setMultilineTokens` consumes their exact batching/range semantics. The builder's deserialize/serialize sibling cluster (`contiguousMultilineTokensBuilder.ts:11-19,43-65`) and the multiline token's deserialize/serialize/edit clusters (`contiguousMultilineTokens.ts:18-30,82-229`) are explicitly outside this readonly in-process closure: serialization belongs to the deferred custom-worker transport, and `applyEdit` belongs to the N-A incremental edit lane. `getLineRange` (`contiguousMultilineTokens.ts:67-69`) is part of the consumed store/batch closure and is counted as TMS-DEP-019.

| ID | Source atom | Arithmetic / transition | Local target or seam | Status | Proposed terminal |
|---|---|---|---|---|---|
| TMS-DEP-001 | `ContiguousMultilineTokensBuilder` class (`...Builder.ts:9`) | In-process collector of adjacent per-line encoded tokens. | `viewer/common/tokens/{contiguous_tokens_store,contiguous_multiline_tokens,contiguous_multiline_tokens_builder}.mbt` (`CT`) — `CT::ContiguousMultilineTokensBuilder` | TODO | PORTED |
| TMS-DEP-002 | builder `_tokens` field (21) | Ordered array of contiguous batches. | `viewer/common/tokens/{contiguous_tokens_store,contiguous_multiline_tokens,contiguous_multiline_tokens_builder}.mbt` (`CT`) — `CT::ContiguousMultilineTokensBuilder.tokens` | TODO | PORTED |
| TMS-DEP-003 | builder constructor (23-25) | Starts with an empty batch array. | `viewer/common/tokens/{contiguous_tokens_store,contiguous_multiline_tokens,contiguous_multiline_tokens_builder}.mbt` (`CT`) — `CT::ContiguousMultilineTokensBuilder::new`; `viewer/common/tokens/contiguous_multiline_tokens_wbtest.mbt` | TODO | TESTED |
| TMS-DEP-004 | builder `add` member (27-37) | Append adjacent line to last batch or push a new batch. | `viewer/common/tokens/{contiguous_tokens_store,contiguous_multiline_tokens,contiguous_multiline_tokens_builder}.mbt` (`CT`) — `CT::ContiguousMultilineTokensBuilder::add`; `viewer/common/tokens/contiguous_multiline_tokens_wbtest.mbt` | TODO | TESTED |
| TMS-DEP-005 | nonempty-builder decision (28-35) | Only inspect last batch when at least one batch exists. | `viewer/common/tokens/{contiguous_tokens_store,contiguous_multiline_tokens,contiguous_multiline_tokens_builder}.mbt` (`CT`) — `CT::ContiguousMultilineTokensBuilder::add`; empty/nonempty test | TODO | TESTED |
| TMS-DEP-006 | adjacency decision (30-34) | `last.endLineNumber + 1 === lineNumber` appends and early-returns; gaps start a new batch. | `viewer/common/tokens/{contiguous_tokens_store,contiguous_multiline_tokens,contiguous_multiline_tokens_builder}.mbt` (`CT`) — `CT::ContiguousMultilineTokensBuilder::add`; adjacent/gapped/out-of-order test | TODO | TESTED |
| TMS-DEP-007 | adjacency constant (30) | Exactly one next one-based line (`end + 1`). | `viewer/common/tokens/{contiguous_tokens_store,contiguous_multiline_tokens,contiguous_multiline_tokens_builder}.mbt` (`CT`) — `CT::ContiguousMultilineTokensBuilder::add`; exact adjacency constant test | TODO | TESTED |
| TMS-DEP-008 | builder `finalize` member (39-41) | Return accumulated batches without copying/reordering. | `viewer/common/tokens/{contiguous_tokens_store,contiguous_multiline_tokens,contiguous_multiline_tokens_builder}.mbt` (`CT`) — `CT::ContiguousMultilineTokensBuilder::finalize`; `viewer/common/tokens/contiguous_multiline_tokens_wbtest.mbt` | TODO | TESTED |
| TMS-DEP-009 | `ContiguousMultilineTokens` class (`...Tokens.ts:17`) | Encoded tokens over one contiguous inclusive line interval. | `viewer/common/tokens/{contiguous_tokens_store,contiguous_multiline_tokens,contiguous_multiline_tokens_builder}.mbt` (`CT`) — `CT::ContiguousMultilineTokens` | TODO | PORTED |
| TMS-DEP-010 | `_startLineNumber` field (35) | Mutable one-based start line. | `viewer/common/tokens/{contiguous_tokens_store,contiguous_multiline_tokens,contiguous_multiline_tokens_builder}.mbt` (`CT`) — `CT::ContiguousMultilineTokens.start_line_number` | TODO | PORTED |
| TMS-DEP-011 | `_tokens` field and binary layout contract (38-46) | One line array per line; token pairs are `[endOffset,metadata]`. | `viewer/common/tokens/{contiguous_tokens_store,contiguous_multiline_tokens,contiguous_multiline_tokens_builder}.mbt` (`CT`) — `CT::ContiguousMultilineTokens.tokens` using local encoded `LineTokens` representation | TODO | PORTED |
| TMS-DEP-012 | `startLineNumber` getter (51-53) | Inclusive start. | `viewer/common/tokens/{contiguous_tokens_store,contiguous_multiline_tokens,contiguous_multiline_tokens_builder}.mbt` (`CT`) — `CT::ContiguousMultilineTokens::start_line_number`; `viewer/common/tokens/contiguous_multiline_tokens_wbtest.mbt` | TODO | TESTED |
| TMS-DEP-013 | `endLineNumber` getter (58-60) | Inclusive end from start and batch length. | `viewer/common/tokens/{contiguous_tokens_store,contiguous_multiline_tokens,contiguous_multiline_tokens_builder}.mbt` (`CT`) — `CT::ContiguousMultilineTokens::end_line_number`; `viewer/common/tokens/contiguous_multiline_tokens_wbtest.mbt` | TODO | TESTED |
| TMS-DEP-014 | inclusive-end formula (59) | `start + tokens.length - 1`, including one-line block. | `viewer/common/tokens/{contiguous_tokens_store,contiguous_multiline_tokens,contiguous_multiline_tokens_builder}.mbt` (`CT`) — `CT::end_line_number`; one/many-line matrix | TODO | TESTED |
| TMS-DEP-015 | constructor (62-65) | Preserve caller's start and ordered per-line token arrays. | `viewer/common/tokens/{contiguous_tokens_store,contiguous_multiline_tokens,contiguous_multiline_tokens_builder}.mbt` (`CT`) — `CT::ContiguousMultilineTokens::new`; `viewer/common/tokens/contiguous_multiline_tokens_wbtest.mbt` | TODO | TESTED |
| TMS-DEP-016 | `getLineTokens` member (74-76) | Return tokens at requested one-based line. | `viewer/common/tokens/{contiguous_tokens_store,contiguous_multiline_tokens,contiguous_multiline_tokens_builder}.mbt` (`CT`) — `CT::ContiguousMultilineTokens::get_line_tokens`; `viewer/common/tokens/contiguous_multiline_tokens_wbtest.mbt` | TODO | TESTED |
| TMS-DEP-017 | line-to-array index formula (75) | `lineNumber - startLineNumber`. | `viewer/common/tokens/{contiguous_tokens_store,contiguous_multiline_tokens,contiguous_multiline_tokens_builder}.mbt` (`CT`) — `CT::get_line_tokens`; first/middle/final matrix | TODO | TESTED |
| TMS-DEP-018 | `appendLineTokens` member (78-80) | Push one new final line, thereby extending inclusive end by one. | `viewer/common/tokens/{contiguous_tokens_store,contiguous_multiline_tokens,contiguous_multiline_tokens_builder}.mbt` (`CT`) — `CT::ContiguousMultilineTokens::append_line_tokens`; `viewer/common/tokens/contiguous_multiline_tokens_wbtest.mbt` | TODO | TESTED |
| TMS-DEP-019 | `ContiguousMultilineTokens.getLineRange` (`contiguousMultilineTokens.ts:67-69`) | Return half-open line range `[start,end+1)` for store batching/range evidence | `viewer/common/tokens/{contiguous_tokens_store,contiguous_multiline_tokens,contiguous_multiline_tokens_builder}.mbt` (`CT`) — `CT::ContiguousMultilineTokens::get_line_range`; common-tokens test | TODO | TESTED |

## Exact upstream test dispositions (counted)

| ID | Upstream test | Exact local evidence | Status | Proposed terminal |
|---|---|---|---|---|
| TMS-REF-001 | `textModelTokens.test.ts:15-61` — `RangePriorityQueueImpl / addRange` | Existing `viewer/common/model/text_model_tokens_reference_test.mbt` test label **`addRange`**, with the same six insertion/assertion stages. | TODO | TESTED |
| TMS-REF-002 | `textModelTokens.test.ts:63-98` — `RangePriorityQueueImpl / addRangeAndResize` | Existing `viewer/common/model/text_model_tokens_reference_test.mbt` test label **`addRangeAndResize`**, with the same four resize/assertion stages. | TODO | TESTED |


## CTS — `contiguousTokensStore.ts` complete unit (74)

| ID | Source atom | Local target / current gap | Status | Proposed terminal |
|---|---|---|---|---|
| CTS-001 | `_lineTokens` nullable per-line storage (`contiguousTokensStore.ts:20`) | `viewer/common/tokens/contiguous_tokens_store.mbt::SyntacticLineTokens` array — Use literal `Missing`, `Empty`, and `Words(Array[UInt])` variants, preserving source null/sentinel/words distinctions. | TODO | PORTED |
| CTS-002 | separate logical `_len` (`:21`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — No independent initialized-prefix length exists. | TODO | PORTED |
| CTS-003 | retained `_languageIdCodec` (`:22`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Reuse `@services.LanguageIdCodec`. | TODO | PORTED |
| CTS-004 | constructor initializes empty store/zero length/codec (`:24-28`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — No store constructor. | TODO | PORTED |
| CTS-005 | `flush` clears array and logical length (`:30-33`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Whole optional memo reset is not the source-shaped store flush. | TODO | TESTED |
| CTS-006 | `hasTokens` is physical array non-emptiness (`:35-37`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Current `has_tokens` means whole-document memo exists. | TODO | TESTED |
| CTS-007 | `getTokens` member (`:39-53`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Centralize syntactic fallback reads in the new store. | TODO | PORTED |
| CTS-008 | only read stored entry when `lineIndex < _len` (`:40-43`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Current array is complete after a sweep. | TODO | TESTED |
| CTS-009 | non-null/non-`EMPTY_LINE_TOKENS` returns stored tokens (`:45-47`) | `viewer/common/tokens/contiguous_tokens_store.mbt::get_tokens` — Only local `Words` returns stored words; `Missing` and `Empty` take fallback/sentinel paths. | TODO | TESTED |
| CTS-010 | fallback is exactly one two-word token ending at `lineText.length` with default metadata (`:49-52`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Encoder fallback exists but is produced by a document sweep. | TODO | TESTED |
| CTS-011 | static `_massageTokens` member (`:55-85`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — No store-bound normalization member. | TODO | PORTED |
| CTS-012 | nullable/buffer input conversion (`:57`) | `viewer/common/tokens/contiguous_tokens_store.mbt::SyntacticLineTokens` conversion — Convert a present buffer to words; `_massageTokens` never stores `Missing`. `Missing` is only an uninitialized store slot, `Empty` is the empty-line sentinel from CTS-013-015, and null/zero input on a nonempty line becomes the default `Words` result from CTS-016-017. | TODO | PORTED |
| CTS-013 | empty-line special branch (`:59`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Existing blank-line encoder is not store normalization. | TODO | TESTED |
| CTS-014 | empty-line language comparison only when token metadata exists (`:60-63`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Preserve a foreign embedded-language token on empty content. | TODO | TESTED |
| CTS-015 | empty line without different language returns `EMPTY_LINE_TOKENS` (`:65-67`) | Store the exact local `viewer/common/tokens/contiguous_tokens_store.mbt::SyntacticLineTokens::Empty` variant. | TODO | TESTED |
| CTS-016 | null/zero-token fallback branch (`:70`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Current encoder always manufactures data before storage. | TODO | TESTED |
| CTS-017 | fallback allocates exact end/default pair and returns it (`:71-75`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Add source-shaped default coverage. | TODO | TESTED |
| CTS-018 | last token end is forcibly rewritten to `lineTextLength` (`:77-78`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Existing encoder fills gaps but store must massage arbitrary backend output. | TODO | TESTED |
| CTS-019 | exact whole-buffer view returns raw `ArrayBuffer` pointer (`:80-83`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — MoonBit has no JS typed-array ownership/object-elision branch. | TODO | N-A (MoonBit array representation seam) |
| CTS-020 | sliced typed-array view returns the view (`:84`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Return the normalized `Array[UInt]` value; no distinct view type. | TODO | PORTED |
| CTS-021 | `_ensureLine` member (`:87-92`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Per-line store growth is absent. | TODO | PORTED |
| CTS-022 | grow through requested index with null slots and `_len++` (`:88-91`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Must preserve sparse initialized-prefix behavior. | TODO | TESTED |
| CTS-023 | `_deleteLines` member (`:94-103`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Incremental edit store mutation is outside the fixed full-flush model API. | TODO | N-A (readonly full-flush edit seam) |
| CTS-024 | zero delete-count early return (`:95-97`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Same excluded edit seam. | TODO | N-A (readonly full-flush edit seam) |
| CTS-025 | overrun delete clamps to `_len - start` (`:98-100`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Same excluded edit seam. | TODO | N-A (readonly full-flush edit seam) |
| CTS-026 | splice then decrement logical length (`:101-102`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Same excluded edit seam. | TODO | N-A (readonly full-flush edit seam) |
| CTS-027 | `_insertLines` member (`:105-115`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Incremental edit store mutation is outside the fixed full-flush model API. | TODO | N-A (readonly full-flush edit seam) |
| CTS-028 | zero insert-count early return (`:106-108`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Same excluded edit seam. | TODO | N-A (readonly full-flush edit seam) |
| CTS-029 | allocate exactly `insertCount` null entries (`:109-112`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Same excluded edit seam. | TODO | N-A (readonly full-flush edit seam) |
| CTS-030 | `arrayInsert` then grow logical length (`:113-114`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Same excluded edit seam. | TODO | N-A (readonly full-flush edit seam) |
| CTS-031 | `setTokens` member (`:117-127`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — New syntactic store setter. | TODO | PORTED |
| CTS-032 | massage -> ensure -> capture old -> write new ordering (`:118-121`) | `viewer/common/tokens/contiguous_tokens_store.mbt::set_tokens` — Preserve exact order across `Missing`, `Empty`, and `Words`; the first `Missing -> Empty` write is a change. | TODO | TESTED |
| CTS-033 | `checkEquality` branch (`:123`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Required for first-changed-line range production. | TODO | TESTED |
| CTS-034 | equality lane returns changed; unchecked lane returns false (`:123-126`) | `viewer/common/tokens/contiguous_tokens_store.mbt::set_tokens` — Equality distinguishes Missing, Empty, and Words; unchecked suffix writes return false. | TODO | TESTED |
| CTS-035 | static `_equals` member (`:129-146`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — No token-word equality helper at the store boundary. | TODO | PORTED |
| CTS-036 | either-null branch returns true only when both are null (`:130-132`) | `viewer/common/tokens/contiguous_tokens_store.mbt::_equals` — `Missing == Missing`; `Missing != Empty` and `Missing != Words`. | TODO | TESTED |
| CTS-037 | unequal word lengths return false (`:137-139`) | `viewer/common/tokens/contiguous_tokens_store.mbt::_equals` — Empty versus nonempty Words is unequal; differing Words lengths are unequal. | TODO | TESTED |
| CTS-038 | first unequal word returns false (`:140-144`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Missing. | TODO | TESTED |
| CTS-039 | equal words return true (`:145`) | `viewer/common/tokens/contiguous_tokens_store.mbt::_equals` — `Empty == Empty` (zero words), and elementwise-equal Words compare true. | TODO | TESTED |
| CTS-040 | `acceptEdit` deletes before inserting (`:150-153`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — No incremental edit API beyond full `set_value`. | TODO | N-A (readonly full-flush edit seam) |
| CTS-041 | `_acceptDeleteRange` member (`:155-185`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Excluded incremental edit helper. | TODO | N-A (readonly full-flush edit seam) |
| CTS-042 | start line beyond initialized store early return (`:157-160`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Same excluded edit seam. | TODO | N-A (readonly full-flush edit seam) |
| CTS-043 | same-line versus multiline delete branch (`:162`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Same excluded edit seam. | TODO | N-A (readonly full-flush edit seam) |
| CTS-044 | empty same-line range early return (`:163-166`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Same excluded edit seam. | TODO | N-A (readonly full-flush edit seam) |
| CTS-045 | same-line token delete and return (`:168-169`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Same excluded edit seam. | TODO | N-A (readonly full-flush edit seam) |
| CTS-046 | multiline delete trims first-line ending (`:172`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Same excluded edit seam. | TODO | N-A (readonly full-flush edit seam) |
| CTS-047 | last-line-in-store branch trims beginning; otherwise null (`:174-178`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Same excluded edit seam. | TODO | N-A (readonly full-flush edit seam) |
| CTS-048 | append last-line survivor to first-line survivor (`:180-181`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Same excluded edit seam. | TODO | N-A (readonly full-flush edit seam) |
| CTS-049 | delete middle lines with exact start/count formula (`:183-184`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Same excluded edit seam. | TODO | N-A (readonly full-flush edit seam) |
| CTS-050 | `_acceptInsertText` member (`:187-209`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Excluded incremental edit helper. | TODO | N-A (readonly full-flush edit seam) |
| CTS-051 | zero-EOL and zero-first-line-length early return (`:189-192`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Same excluded edit seam. | TODO | N-A (readonly full-flush edit seam) |
| CTS-052 | target line outside initialized store early return (`:194-197`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Same excluded edit seam. | TODO | N-A (readonly full-flush edit seam) |
| CTS-053 | zero-EOL single-line insert and return (`:199-203`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Same excluded edit seam. | TODO | N-A (readonly full-flush edit seam) |
| CTS-054 | multiline insert trims ending before inserting first-line length (`:205-206`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Same excluded edit seam. | TODO | N-A (readonly full-flush edit seam) |
| CTS-055 | insert `eolCount` null lines at one-based `position.lineNumber` (`:208`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Same excluded edit seam. | TODO | N-A (readonly full-flush edit seam) |
| CTS-056 | `setMultilineTokens` member (`contiguousTokensStore.ts:213-244`) | `viewer/common/tokens/contiguous_tokens_store.mbt::set_multiline_tokens` — Ingest batches using top-level language id plus a live line-length read closure; never import model/tokens. | TODO | PORTED |
| CTS-057 | empty chunk array returns no changes (`:214-216`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Missing. | TODO | TESTED |
| CTS-058 | outer chunk loop preserves input order (`:220-241`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Missing. | TODO | TESTED |
| CTS-059 | each chunk starts `min=0,max=0,hasChange=false` (`:222-224`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Missing exact range state. | TODO | TESTED |
| CTS-060 | inclusive line loop from element start through end (`:225`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Missing. | TODO | TESTED |
| CTS-061 | after first difference, write suffix unchecked and extend max (`:226-229`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Missing bounded equality-work behavior. | TODO | TESTED |
| CTS-062 | before first difference, write with equality checking (`:229-230`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Missing. | TODO | TESTED |
| CTS-063 | first difference sets flag and both min/max (`:231-235`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Missing. | TODO | TESTED |
| CTS-064 | changed chunk pushes one inclusive min/max range (`:238-240`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Current resets announce the whole document. | TODO | TESTED |
| CTS-065 | return `{ changes: ranges }` in chunk order (`:243`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Missing. | TODO | TESTED |
| CTS-066 | `getDefaultMetadata` member (`:247-257`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Consolidate exact source fallback metadata. | TODO | PORTED |
| CTS-067 | language id occupies `LANGUAGEID_OFFSET` (`:249`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Existing encoder packs language id. | TODO | TESTED |
| CTS-068 | standard token type is `Other` (`:250`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Existing `Plain` maps to Other. | TODO | TESTED |
| CTS-069 | font style is `None` (`:251`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Existing default matches. | TODO | TESTED |
| CTS-070 | foreground is `DefaultForeground` (`:252`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Existing default matches. | TODO | TESTED |
| CTS-071 | background is `DefaultBackground` (`:253`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Existing default matches. | TODO | TESTED |
| CTS-072 | missing grammar sets `BALANCED_BRACKETS_MASK` (`:254-255`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — Current `gap_metadata` omits this source bit. | TODO | TESTED |
| CTS-073 | final metadata coerces to unsigned 32-bit (`:256`) | `viewer/common/tokens/contiguous_tokens_store.mbt` — `UInt` representation supplies unsigned semantics; assert exact word. | TODO | TESTED |
| CTS-074 | `ContiguousTokensStore` class declaration (`contiguousTokensStore.ts:19`) | `viewer/common/tokens/contiguous_tokens_store.mbt::ContiguousTokensStore` — Declare the model-wide contiguous syntactic token store. | TODO | PORTED |

## STS — `sparseTokensStore.ts` complete unit (76)

Every row below names the missing future dependency explicitly. None is N-A.

| ID | Source atom | Local target / current gap | Status | Proposed terminal |
|---|---|---|---|---|
| STS-001 | `_pieces: SparseMultilineTokens[]` (`:19`) | `viewer-semantic-token-acquisition-application-parity.md` — No sparse piece type/store. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: SparseMultilineTokens carrier) |
| STS-002 | `_isComplete` (`:20`) | `viewer-semantic-token-acquisition-application-parity.md` — No full-versus-partial semantic result fact. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: provider completeness contract) |
| STS-003 | retained language codec (`:21`) | `viewer-semantic-token-acquisition-application-parity.md` — Merge needs the codec once sparse values exist. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: sparse merge value contract) |
| STS-004 | constructor initializes empty/incomplete store and codec (`:23-27`) | `viewer-semantic-token-acquisition-application-parity.md` — No semantic store construction. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: SparseTokensStore integration) |
| STS-005 | `flush` clears pieces and completeness (`:29-32`) | `viewer-semantic-token-acquisition-application-parity.md` — No semantic invalidation seam. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: semantic lifecycle/reset) |
| STS-006 | `isEmpty` reflects piece count (`:34-36`) | `viewer-semantic-token-acquisition-application-parity.md` — No semantic store query. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: sparse store API) |
| STS-007 | full `set` member (`:38-47`) | `viewer-semantic-token-acquisition-application-parity.md` — No full semantic update API. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: full provider-result application) |
| STS-008 | null pieces normalize to empty array (`:39`) | `viewer-semantic-token-acquisition-application-parity.md` — No nullable provider-result representation. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: full update value contract) |
| STS-009 | optional text-model validation branch (`:42`) | `viewer-semantic-token-acquisition-application-parity.md` — No semantic application/model validation bridge. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: model-version application seam) |
| STS-010 | report every invalid piece to the model (`:43-45`) | `viewer-semantic-token-acquisition-application-parity.md` — Requires sparse piece validation and host diagnostics. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: SparseMultilineTokens validation) |
| STS-011 | `setPartial` member (`:49-127`) | `viewer-semantic-token-acquisition-application-parity.md` — No range-provider partial update API. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: partial provider-result application) |
| STS-012 | nonempty replacement-pieces branch (`:53`) | `viewer-semantic-token-acquisition-application-parity.md` — No partial semantic values. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: partial sparse values) |
| STS-013 | missing first/last piece range returns original range (`:54-58`) | `viewer-semantic-token-acquisition-application-parity.md` — Requires sparse piece range contract. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: SparseMultilineTokens ranges) |
| STS-014 | replacement range expands by first and last piece ranges (`:59`) | `viewer-semantic-token-acquisition-application-parity.md` — No provider range reconciliation. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: partial update range reconciliation) |
| STS-015 | nullable insertion-position carrier (`:62`) | `viewer-semantic-token-acquisition-application-parity.md` — No ordered sparse-piece store. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: ordered piece storage) |
| STS-016 | mutable indexed traversal of existing pieces (`:63-115`) | `viewer-semantic-token-acquisition-application-parity.md` — No sparse-piece traversal. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: ordered piece storage) |
| STS-017 | piece wholly before range continues (`:65-68`) | `viewer-semantic-token-acquisition-application-parity.md` — Requires sparse range ordering. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: piece ordering) |
| STS-018 | piece wholly after range records insertion point and breaks (`:70-75`) | `viewer-semantic-token-acquisition-application-parity.md` — Requires partial-update insertion semantics. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: partial update insertion) |
| STS-019 | intersecting piece removes tokens in range (`:77-78`) | `viewer-semantic-token-acquisition-application-parity.md` — No sparse mutation operation. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: SparseMultilineTokens mutation) |
| STS-020 | emptied piece is spliced, loop indices shrink, then continue (`:80-86`) | `viewer-semantic-token-acquisition-application-parity.md` — No sparse mutation/store compaction. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: partial deletion compaction) |
| STS-021 | post-removal piece now before range continues (`:88-91`) | `viewer-semantic-token-acquisition-application-parity.md` — Requires mutated range facts. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: partial deletion ordering) |
| STS-022 | post-removal piece now after range records position and continues (`:93-97`) | `viewer-semantic-token-acquisition-application-parity.md` — Requires mutated range facts. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: partial insertion ordering) |
| STS-023 | containing piece splits around range (`:99-100`) | `viewer-semantic-token-acquisition-application-parity.md` — No sparse split API. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: SparseMultilineTokens split) |
| STS-024 | empty left split means piece is after range (`:101-105`) | `viewer-semantic-token-acquisition-application-parity.md` — Requires sparse split boundary semantics. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: partial split boundaries) |
| STS-025 | empty right split means piece is before range (`:106-109`) | `viewer-semantic-token-acquisition-application-parity.md` — Requires sparse split boundary semantics. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: partial split boundaries) |
| STS-026 | two nonempty splits replace one piece and advance indices (`:110-114`) | `viewer-semantic-token-acquisition-application-parity.md` — No split-piece storage update. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: partial split storage) |
| STS-027 | absent insertion position falls back to store end (`:117`) | `viewer-semantic-token-acquisition-application-parity.md` — No ordered sparse store. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: partial insertion position) |
| STS-028 | nonempty replacement pieces are array-inserted (`:119-121`) | `viewer-semantic-token-acquisition-application-parity.md` — No partial provider values/application. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: partial provider-result insertion) |
| STS-029 | return the possibly expanded affected range (`:126`) | `viewer-semantic-token-acquisition-application-parity.md` — No semantic affected-range event seam. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: semantic change range production) |
| STS-030 | `isComplete` getter (`:129-131`) | `viewer-semantic-token-acquisition-application-parity.md` — No completeness API. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: provider completeness contract) |
| STS-031 | `addSparseTokens` merge member (`:133-224`) | `viewer-semantic-token-acquisition-application-parity.md` — Current `get_line_tokens` returns syntactic tokens unchanged. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: syntactic/semantic merge) |
| STS-032 | empty syntactic line returns unchanged (`:134-137`) | `viewer-semantic-token-acquisition-application-parity.md` — No semantic merge path. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: empty-line merge branch) |
| STS-033 | empty sparse store returns syntactic tokens (`:141-143`) | `viewer-semantic-token-acquisition-application-parity.md` — No semantic store. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: absent-semantic fallback) |
| STS-034 | binary-search piece then request its line tokens (`:145-146`) | `viewer-semantic-token-acquisition-application-parity.md` — Requires SparseMultilineTokens lookup. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: sparse line lookup) |
| STS-035 | missing semantic tokens for line returns syntactic tokens (`:148-150`) | `viewer-semantic-token-acquisition-application-parity.md` — Requires sparse line result contract. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: missing-line fallback) |
| STS-036 | capture syntactic/semantic token counts (`:152-153`) | `viewer-semantic-token-acquisition-application-parity.md` — No paired merge inputs. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: merge inputs) |
| STS-037 | initialize `aIndex`, result words, result length, last end (`:155-158`) | `viewer-semantic-token-acquisition-application-parity.md` — No semantic merge state. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: merge state) |
| STS-038 | source-owned `emitToken` callback (`:160-167`) | `viewer-semantic-token-acquisition-application-parity.md` — No centralized merged-token emitter. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: merge emitter) |
| STS-039 | emitter drops non-increasing end offsets (`:161-163`) | `viewer-semantic-token-acquisition-application-parity.md` — Requires overlap-safe semantic merge. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: monotone end-offset invariant) |
| STS-040 | emitter updates last end and appends end/metadata pair (`:164-166`) | `viewer-semantic-token-acquisition-application-parity.md` — No merged output buffer. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: merged token encoding) |
| STS-041 | iterate every semantic token (`:169-215`) | `viewer-semantic-token-acquisition-application-parity.md` — No semantic token values. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: semantic token iteration) |
| STS-042 | clamp semantic start to syntactic text length (`:172`) | `viewer-semantic-token-acquisition-application-parity.md` — No untrusted semantic range handling. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: provider-range clamping) |
| STS-043 | clamp semantic end to syntactic text length (`:173`) | `viewer-semantic-token-acquisition-application-parity.md` — No untrusted semantic range handling. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: provider-range clamping) |
| STS-044 | read semantic metadata (`:174`) | `viewer-semantic-token-acquisition-application-parity.md` — No theme-to-sparse metadata encoder. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: semantic metadata encoding) |
| STS-045 | italic override flag contributes `ITALIC_MASK` (`:177`) | `viewer-semantic-token-acquisition-application-parity.md` — No semantic style override metadata. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: italic override encoding) |
| STS-046 | bold override flag contributes `BOLD_MASK` (`:178`) | `viewer-semantic-token-acquisition-application-parity.md` — No semantic style override metadata. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: bold override encoding) |
| STS-047 | underline override contributes `UNDERLINE_MASK` (`:179`) | `viewer-semantic-token-acquisition-application-parity.md` — No semantic style override metadata. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: underline override encoding) |
| STS-048 | strikethrough override contributes its mask (`:180`) | `viewer-semantic-token-acquisition-application-parity.md` — No semantic style override metadata. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: strikethrough override encoding) |
| STS-049 | foreground override contributes its mask (`:181`) | `viewer-semantic-token-acquisition-application-parity.md` — No legend/theme foreground encoder. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: theme-to-sparse foreground) |
| STS-050 | background override contributes its mask (`:182`) | `viewer-semantic-token-acquisition-application-parity.md` — No legend/theme background encoder. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: theme-to-sparse background) |
| STS-051 | combined semantic mask is unsigned 32-bit (`:176-183`) | `viewer-semantic-token-acquisition-application-parity.md` — No semantic metadata word. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: metadata bit contract) |
| STS-052 | syntactic preservation mask is unsigned complement (`:184`) | `viewer-semantic-token-acquisition-application-parity.md` — No merge mask. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: syntactic preservation mask) |
| STS-053 | emit every syntactic token ending before semantic start (`:186-190`) | `viewer-semantic-token-acquisition-application-parity.md` — No merge walk. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: pre-overlap merge branch) |
| STS-054 | intersecting syntactic prefix emits at semantic start (`:192-195`) | `viewer-semantic-token-acquisition-application-parity.md` — No overlap merge. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: prefix overlap branch) |
| STS-055 | syntactic tokens contained before semantic end emit merged metadata (`:197-201`) | `viewer-semantic-token-acquisition-application-parity.md` — No containment merge. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: contained-token merge branch) |
| STS-056 | remaining syntactic token branch emits merged semantic end (`:203-204`) | `viewer-semantic-token-acquisition-application-parity.md` — No overlap merge. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: active syntactic-token merge) |
| STS-057 | exact same syntactic/semantic end advances syntactic index (`:205-208`) | `viewer-semantic-token-acquisition-application-parity.md` — No equality-boundary merge branch. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: equal-end convergence) |
| STS-058 | no remaining syntactic token enters fallback branch (`:209-214`) | `viewer-semantic-token-acquisition-application-parity.md` — No malformed/out-of-range provider fallback. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: exhausted-syntactic fallback) |
| STS-059 | fallback merge index clamps `aIndex-1` into `[0,aLen-1]` (`:210`) | `viewer-semantic-token-acquisition-application-parity.md` — Requires source-shaped malformed-provider behavior. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: fallback merge index) |
| STS-060 | fallback emits semantic end using last syntactic metadata (`:212-213`) | `viewer-semantic-token-acquisition-application-parity.md` — No fallback merge. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: exhausted-syntactic merge) |
| STS-061 | emit all remaining syntactic tokens (`:217-221`) | `viewer-semantic-token-acquisition-application-parity.md` — No merge tail. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: remaining-syntactic tail) |
| STS-062 | construct merged `LineTokens` with original content/codec (`:223`) | `viewer-semantic-token-acquisition-application-parity.md` — No merged return value. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: merged LineTokens result) |
| STS-063 | static `_findFirstPieceWithLine` member (`:226-246`) | `viewer-semantic-token-acquisition-application-parity.md` — No sparse-piece lookup helper. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: sparse lookup) |
| STS-064 | binary-search bounds are `0` and `length-1` (`:227-228`) | `viewer-semantic-token-acquisition-application-parity.md` — No sparse-piece array. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: sparse lookup bounds) |
| STS-065 | loop while `low < high` (`:230`) | `viewer-semantic-token-acquisition-application-parity.md` — No sparse lookup. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: sparse lookup loop) |
| STS-066 | midpoint is lower midpoint via floor (`:231`) | `viewer-semantic-token-acquisition-application-parity.md` — No sparse lookup. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: sparse lookup arithmetic) |
| STS-067 | piece ending before line moves `low=mid+1` (`:233-234`) | `viewer-semantic-token-acquisition-application-parity.md` — No sparse lookup. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: sparse lookup before branch) |
| STS-068 | piece starting after line moves `high=mid-1` (`:235-236`) | `viewer-semantic-token-acquisition-application-parity.md` — No sparse lookup. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: sparse lookup after branch) |
| STS-069 | overlap walks backward to first containing piece (`:238-240`) | `viewer-semantic-token-acquisition-application-parity.md` — No overlapping sparse-piece support. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: first-overlap selection) |
| STS-070 | overlap returns adjusted midpoint (`:241`) | `viewer-semantic-token-acquisition-application-parity.md` — No sparse lookup. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: overlap result) |
| STS-071 | loop exit returns `low` (`:245`) | `viewer-semantic-token-acquisition-application-parity.md` — No sparse lookup. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: sparse lookup terminal) |
| STS-072 | `acceptEdit` member (`:248-259`) | `viewer-semantic-token-acquisition-application-parity.md` — Semantic pieces still need future edit/full-flush convergence rules. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: semantic edit/application lifecycle) |
| STS-073 | iterate mutable pieces (`:249-258`) | `viewer-semantic-token-acquisition-application-parity.md` — No semantic store. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: sparse edit traversal) |
| STS-074 | forward exact edit facts to each piece (`:251`) | `viewer-semantic-token-acquisition-application-parity.md` — No SparseMultilineTokens edit API. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: sparse edit transformation) |
| STS-075 | remove emptied piece and decrement index (`:253-257`) | `viewer-semantic-token-acquisition-application-parity.md` — No semantic store compaction. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: post-edit sparse compaction) |
| STS-076 | `SparseTokensStore` class declaration (`sparseTokensStore.ts:17`) | `viewer-semantic-token-acquisition-application-parity.md` — Future model-wide `SparseTokensStore` carrier. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md: SparseTokensStore integration) |

## TRG — `tokenizationRegistry.ts` complete unit (57)

The lazy-factory family is explicitly accounted as N-A because the Viewer
exports only synchronous `Languages::set_tokens_provider`; it has no
`registerTokensProviderFactory`, Promise-valued provider, or factory-lifetime
surface. The ordinary registry/change/color-map contract remains required.

| ID | Source atom | Local target / current gap | Status | Proposed terminal |
|---|---|---|---|---|
| TRG-001 | `_tokenizationSupports` language→support map (`:14`) | `syntax/tokenizer.mbt` — Local `tokenizers` map matches via registration entries. | TODO | PORTED |
| TRG-002 | `_factories` language→lazy-factory map (`:15`) | `syntax/tokenizer.mbt` — No public lazy tokens-provider factory surface. | TODO | N-A (no lazy-provider API seam) |
| TRG-003 | private change emitter (`:17`) | `syntax/tokenizer.mbt` — Local `did_change` emitter exists. | TODO | PORTED |
| TRG-004 | public `onDidChange` event property (`:18`) | `syntax/tokenizer.mbt` — Local subscription method exists; preserve event identity. | TODO | PORTED |
| TRG-005 | nullable `_colorMap` (`:20`) | `syntax/tokenizer.mbt` — Local color map is a static function/CSS, not registry state. | TODO | PORTED |
| TRG-006 | constructor initializes color map null (`:22-24`) | `syntax/tokenizer.mbt` — Registry constructor currently initializes only supports/emitter. | TODO | PORTED |
| TRG-007 | `handleChange(languageIds)` member (`:26-31`) | `syntax/tokenizer.mbt` — No direct change-announcement method. | TODO | PORTED |
| TRG-008 | change event carries exact languages and `changedColorMap=false` (`:27-30`) | `syntax/tokenizer.mbt` — Local event omits the color-map fact. | TODO | TESTED |
| TRG-009 | `register` member (`:33-43`) | `syntax/tokenizer.mbt` — Local synchronous registration exists. | TODO | PORTED |
| TRG-010 | set active support before firing language change (`:34-35`) | `syntax/tokenizer.mbt` — Local ordering matches. | TODO | TESTED |
| TRG-011 | returned disposable owns conditional removal callback (`:36-42`) | `syntax/tokenizer.mbt` — Local id-based equivalent exists. | TODO | PORTED |
| TRG-012 | stale/replaced registration dispose early-returns (`:37-39`) | `syntax/tokenizer.mbt` — Local id comparison implements this; add exact event assertion. | TODO | TESTED |
| TRG-013 | active dispose deletes then fires one language change (`:40-41`) | `syntax/tokenizer.mbt` — Current behavior exists but coverage is incomplete. | TODO | TESTED |
| TRG-014 | `get` returns active support or null (`:45-47`) | `syntax/tokenizer.mbt` — Local returns `Option`. | TODO | TESTED |
| TRG-015 | `registerFactory` member (`:49-61`) | `syntax/tokenizer.mbt` — No public lazy factory registration API. | TODO | N-A (no lazy-provider API seam) |
| TRG-016 | replacement factory is disposed before installation (`:50`) | `syntax/tokenizer.mbt` — No lazy factory surface. | TODO | N-A (no lazy-provider API seam) |
| TRG-017 | construct/store `TokenizationSupportFactoryData` (`:51-52`) | `syntax/tokenizer.mbt` — No lazy factory carrier. | TODO | N-A (no lazy-provider API seam) |
| TRG-018 | returned factory-registration disposer callback (`:53-60`) | `syntax/tokenizer.mbt` — No lazy factory lifetime. | TODO | N-A (no lazy-provider API seam) |
| TRG-019 | absent/non-current factory disposer early-return (`:54-57`) | `syntax/tokenizer.mbt` — No lazy factory identity. | TODO | N-A (no lazy-provider API seam) |
| TRG-020 | current factory delete then dispose (`:58-59`) | `syntax/tokenizer.mbt` — No lazy factory lifetime. | TODO | N-A (no lazy-provider API seam) |
| TRG-021 | async `getOrCreate` member (`:63-79`) | `syntax/tokenizer.mbt` — No Promise-valued token support API. | TODO | N-A (no lazy-provider API seam) |
| TRG-022 | already-registered support early-return (`:64-68`) | `syntax/tokenizer.mbt` — Lazy lookup API itself is absent; ordinary `get` stays TRG-014. | TODO | N-A (no lazy-provider API seam) |
| TRG-023 | missing/already-resolved factory returns null (`:70-74`) | `syntax/tokenizer.mbt` — No lazy factory resolution state. | TODO | N-A (no lazy-provider API seam) |
| TRG-024 | await factory resolution (`:76`) | `syntax/tokenizer.mbt` — No Promise-valued token support API. | TODO | N-A (no lazy-provider API seam) |
| TRG-025 | re-read support after resolution (`:78`) | `syntax/tokenizer.mbt` — No lazy factory resolution path. | TODO | N-A (no lazy-provider API seam) |
| TRG-026 | `isResolved` member (`:81-93`) | `syntax/tokenizer.mbt::is_resolved` — Preserve a synchronous fixed-true adaptation even though lazy factory creation is absent. | TODO | PORTED |
| TRG-027 | active support returns true (`:82-85`) | `syntax/tokenizer.mbt::is_resolved` — Fixed synchronous adaptation returns true for active support; add a direct true-arm test. | TODO | TESTED |
| TRG-028 | missing or already-resolved factory returns true (`:87-90`) | `syntax/tokenizer.mbt::is_resolved` — With no lazy factory API, missing support is synchronously resolved and true; add the missing-support true test. | TODO | TESTED |
| TRG-029 | unresolved factory returns false (`:92`) | `syntax/tokenizer.mbt` has no unresolved-factory state; false requires the absent lazy-factory pending state. | TODO | N-A (lazy factory API is absent) |
| TRG-030 | `setColorMap` member (`:95-101`) | `syntax/tokenizer.mbt` — Move/bridge the fixed theme map into registry state without changing theme design. | TODO | PORTED |
| TRG-031 | store supplied color map (`:96`) | `syntax/tokenizer.mbt` — Missing registry color state. | TODO | TESTED |
| TRG-032 | fire all registered languages with `changedColorMap=true` (`:97-100`) | `syntax/tokenizer.mbt` — Local event lacks color-map changes and all-language fanout. | TODO | TESTED |
| TRG-033 | `getColorMap` returns current map/null (`:103-105`) | `syntax/tokenizer.mbt` — Missing registry getter. | TODO | TESTED |
| TRG-034 | `getDefaultBackground` member (`:107-112`) | `syntax/tokenizer.mbt` — Missing; local theme uses CSS strings rather than VS Code `Color`. | TODO | PORTED |
| TRG-035 | color map exists and length exceeds `DefaultBackground` branch (`:108`) | `syntax/tokenizer.mbt` — Missing bounds branch. | TODO | TESTED |
| TRG-036 | valid map returns default-background entry (`:109`) | `syntax/tokenizer.mbt` — Port with the local color value representation. | TODO | TESTED |
| TRG-037 | absent/short map returns null (`:111`) | `syntax/tokenizer.mbt` — Missing. | TODO | TESTED |
| TRG-038 | factory data `_isDisposed=false` (`:117`) | `syntax/tokenizer.mbt` — No lazy factory carrier. | TODO | N-A (no lazy-provider API seam) |
| TRG-039 | factory data `_resolvePromise=null` (`:118`) | `syntax/tokenizer.mbt` — No lazy factory carrier. | TODO | N-A (no lazy-provider API seam) |
| TRG-040 | factory data `_isResolved=false` (`:119`) | `syntax/tokenizer.mbt` — No lazy factory carrier. | TODO | N-A (no lazy-provider API seam) |
| TRG-041 | `isResolved` getter (`:121-123`) | `syntax/tokenizer.mbt` — No lazy factory carrier. | TODO | N-A (no lazy-provider API seam) |
| TRG-042 | constructor retains registry (`:125-126`) | `syntax/tokenizer.mbt` — No lazy factory carrier. | TODO | N-A (no lazy-provider API seam) |
| TRG-043 | constructor retains language id (`:127`) | `syntax/tokenizer.mbt` — No lazy factory carrier. | TODO | N-A (no lazy-provider API seam) |
| TRG-044 | constructor retains factory (`:128`) | `syntax/tokenizer.mbt` — No lazy factory carrier. | TODO | N-A (no lazy-provider API seam) |
| TRG-045 | constructor calls `super` (`:129-131`) | `syntax/tokenizer.mbt` — MoonBit disposal is closure/GC based; class is absent. | TODO | N-A (no lazy-provider API seam) |
| TRG-046 | override `dispose` member (`:133-136`) | `syntax/tokenizer.mbt` — No lazy factory lifetime. | TODO | N-A (no lazy-provider API seam) |
| TRG-047 | set disposed before superclass disposal (`:134-135`) | `syntax/tokenizer.mbt` — No lazy factory lifetime. | TODO | N-A (no lazy-provider API seam) |
| TRG-048 | async `resolve` member (`:138-143`) | `syntax/tokenizer.mbt` — No lazy factory resolution. | TODO | N-A (no lazy-provider API seam) |
| TRG-049 | missing promise creates exactly one `_create` promise (`:139-141`) | `syntax/tokenizer.mbt` — No lazy factory resolution/deduplication. | TODO | N-A (no lazy-provider API seam) |
| TRG-050 | every caller receives shared resolve promise (`:142`) | `syntax/tokenizer.mbt` — No lazy factory resolution. | TODO | N-A (no lazy-provider API seam) |
| TRG-051 | private async `_create` member (`:145-151`) | `syntax/tokenizer.mbt` — No lazy factory resolution. | TODO | N-A (no lazy-provider API seam) |
| TRG-052 | await `factory.tokenizationSupport` (`:146`) | `syntax/tokenizer.mbt` — No Promise-valued provider. | TODO | N-A (no lazy-provider API seam) |
| TRG-053 | set resolved before checking value/disposal (`:147`) | `syntax/tokenizer.mbt` — No lazy factory state. | TODO | N-A (no lazy-provider API seam) |
| TRG-054 | only truthy value on non-disposed carrier registers (`:148`) | `syntax/tokenizer.mbt` — No lazy factory cancellation/lifetime. | TODO | N-A (no lazy-provider API seam) |
| TRG-055 | own the ordinary registration disposable (`:149`) | `syntax/tokenizer.mbt` — No lazy factory lifetime. | TODO | N-A (no lazy-provider API seam) |
| TRG-056 | `TokenizationRegistry<TSupport>` class declaration (`tokenizationRegistry.ts:12-113`) | `syntax/tokenizer.mbt::TokenizationRegistry` — Concrete generic registry implementing `ITokenizationRegistry<TSupport>`. | TODO | PORTED |
| TRG-057 | `TokenizationSupportFactoryData<TSupport>` class declaration (`:115-152`) | `syntax/tokenizer.mbt` has no lazy-provider resolution/lifetime carrier. | TODO | N-A (no lazy-provider API seam) |

## MLP — `modelLineProjection.ts` token-demand clusters (34)

| ID | Source atom | Local target / current gap | Status | Proposed terminal |
|---|---|---|---|---|
| MLP-001 | `IModelLineProjection.getViewLineData` declaration (`:30`) | `viewer/common/view_model/model_line_projection.mbt` — Local enum has only the single-line method. | TODO | PORTED |
| MLP-002 | `IModelLineProjection.getViewLinesData` declaration with `needed`/result carrier (`:31`) | `viewer/common/view_model/model_line_projection.mbt` — Batched projection API is absent. | TODO | PORTED |
| MLP-003 | `ISimpleModel.tokenization` property (`modelLineProjection.ts:42`) | `viewer/common/view_model/model_line_projection.mbt` model/tokenization carrier — Receive the tokenization-part dependency separately from its read member. | TODO | PORTED |
| MLP-004 | projected `getViewLineData` member (`:154-158`) | `viewer/common/view_model/model_line_projection.mbt` — Local single-line projected path exists but does not share a batch implementation. | TODO | PORTED |
| MLP-005 | single-line path delegates to batch with count `1`, global index `0`, and `[true]` (`:155-156`) | `viewer/common/view_model/model_line_projection.mbt` — Missing; local independently reads tokens. | TODO | TESTED |
| MLP-006 | single-line path returns batch slot zero (`:157`) | `viewer/common/view_model/model_line_projection.mbt` — Missing. | TODO | TESTED |
| MLP-007 | projected `getViewLinesData` member (`:160-188`) | `viewer/common/view_model/model_line_projection.mbt` — Missing. | TODO | PORTED |
| MLP-008 | projected batch asserts visibility before any demand (`:161`) | `viewer/common/view_model/model_line_projection.mbt` — Local hidden enum arm aborts; batch equivalent absent. | TODO | TESTED |
| MLP-009 | injected-decoration context/object and ordering (`:168,175-176`) | `viewer/common/view_model/model_line_projection.mbt` projected batch path — Construct the source-shaped context/computer and select inline decorations before the passive token read. | TODO | TESTED |
| MLP-010 | call `getLineTokens` exactly once per projected model line (`:177`) | `viewer/common/view_model/model_line_projection.mbt` — Current per-view-line reads repeat for wrapped segments. | TODO | TESTED |
| MLP-011 | splice injection tokens exactly once from that shared line-token value (`:178`) | `viewer/common/view_model/model_line_projection.mbt` — Current helper recomputes per wrapped view line. | TODO | TESTED |
| MLP-012 | iterate requested output-line interval (`:180-187`) | `viewer/common/view_model/model_line_projection.mbt` — Missing batched segment loop. | TODO | TESTED |
| MLP-013 | `needed=false` writes null and continues, but only after the one model-line demand (`:181-185`) | `viewer/common/view_model/model_line_projection.mbt` — Important source timing: projected all-false still performs one passive read for the included model line. | TODO | TESTED |
| MLP-014 | needed output uses shared tokens/decorations to build its segment (`:186`) | `viewer/common/view_model/model_line_projection.mbt` — Current path reads separately per segment. | TODO | TESTED |
| MLP-015 | `_getViewLineData` member (`:190-217`) | `viewer/common/view_model/model_line_projection.mbt::_get_view_line_data` — Source-shaped helper owns segment rendering; its branch atoms are split below. | TODO | PORTED |
| MLP-016 | identity `getViewLineData` member (`:298-310`) | `viewer/common/view_model/model_line_projection.mbt` — Local Identity enum arm exists. | TODO | PORTED |
| MLP-017 | identity line passively reads `getLineTokens` once (`:299`) | `viewer/common/view_model/model_line_projection.mbt` — Existing direct demand, but currently triggers whole-document sweep. | TODO | TESTED |
| MLP-018 | identity returns inflated demanded tokens in view-line data (`:300-309`) | `viewer/common/view_model/model_line_projection.mbt` — Existing result shape; reverify after demand backend change. | TODO | TESTED |
| MLP-019 | identity `getViewLinesData` member (`:312-318`) | `viewer/common/view_model/model_line_projection.mbt` — Missing. | TODO | PORTED |
| MLP-020 | identity `needed=false` writes null and early-returns before demand (`:313-316`) | `viewer/common/view_model/model_line_projection.mbt` — Missing; this is different from projected-line timing. | TODO | TESTED |
| MLP-021 | identity needed path delegates to `getViewLineData` (`:317`) | `viewer/common/view_model/model_line_projection.mbt` — Missing. | TODO | TESTED |
| MLP-022 | hidden `getViewLineData` throws and never demands (`:384-386`) | `viewer/common/view_model/model_line_projection.mbt` — Local Hidden arm aborts; retain no-demand behavior. | TODO | TESTED |
| MLP-023 | hidden `getViewLinesData` throws and never demands (`:388-390`) | `viewer/common/view_model/model_line_projection.mbt` — Batched hidden sentinel absent. | TODO | TESTED |
| MLP-024 | `ISimpleModel.tokenization.getLineTokens` member (`modelLineProjection.ts:43`) | `viewer/common/view_model/model_line_projection.mbt` -> token part passive read — Keep the read contract separate from tokenization-property ownership. | TODO | PORTED |
| MLP-025 | context `getInjectionOptions` callback (`:169`) | `viewer/common/view_model/model_line_projection.mbt` projection adapter — Return captured injection options. | TODO | TESTED |
| MLP-026 | context `getInjectionOffsets` callback (`:170`) | `viewer/common/view_model/model_line_projection.mbt` projection adapter — Return captured injection offsets. | TODO | TESTED |
| MLP-027 | context `getBreakOffsets` callback (`:171`) | `viewer/common/view_model/model_line_projection.mbt` projection adapter — Return line-break offsets. | TODO | TESTED |
| MLP-028 | context `getWrappedTextIndentLength` callback (`:172`) | `viewer/common/view_model/model_line_projection.mbt` projection adapter — Return wrapped-indent length. | TODO | TESTED |
| MLP-029 | context `getBaseViewLineNumber` callback (`:173`) | `viewer/common/view_model/model_line_projection.mbt` projection adapter — Return the caller's base view line. | TODO | TESTED |
| MLP-030 | decoration selection ternary (`:186`) | `viewer/common/view_model/model_line_projection.mbt` `_get_view_line_data` caller — Select decorations for the output line when the array exists, else null. | TODO | TESTED |
| MLP-031 | wrapped-indent delta branch (`:193`) | `viewer/common/view_model/model_line_projection.mbt::_get_view_line_data` — First output uses zero; later outputs use wrapped indent. | TODO | TESTED |
| MLP-032 | wrapped-segment start branch (`:195`) | `viewer/common/view_model/model_line_projection.mbt::_get_view_line_data` — First output starts at zero; later output starts at the previous break. | TODO | TESTED |
| MLP-033 | `sliceAndInflate` call (`:197`) | `viewer/common/view_model/model_line_projection.mbt::_get_view_line_data` — Pass exact start/end/delta to the shared token value; retain LineTokens slice/inflate evidence. | TODO | TESTED |
| MLP-034 | wrapped-content indent branch (`:199-202`) | `viewer/common/view_model/model_line_projection.mbt::_get_view_line_data` — Prefix spaces only for later wrapped outputs. | TODO | TESTED |

## VML — `viewModelLines.ts` projected/as-is demand clusters (24)

`ViewModelLinesFromModelAsIs` is fully accounted and DEFERRED to
`viewer-large-file-view-collection-parity.md`: local Viewer currently always
constructs `ViewModelLinesFromProjectedModel`, including large models. No-wrap local
lines still exercise the required `IdentityModelLineProjection` rows above.

| ID | Source atom | Local target / current gap | Status | Proposed terminal |
|---|---|---|---|---|
| VML-001 | `IViewModelLines.getViewLineData` declaration (`:45`) | `viewer/common/view_model/view_model_lines_projected.mbt` — Local projected collection exposes the single-line method. | TODO | PORTED |
| VML-002 | `IViewModelLines.getViewLinesData` declaration (`:46`) | `viewer/common/view_model/view_model_lines_projected.mbt` — Missing batched public collection method. | TODO | PORTED |
| VML-003 | projected collection `getViewLineData` member (`:757-761`) | `viewer/common/view_model/view_model_lines_projected.mbt` — Local method exists. | TODO | PORTED |
| VML-004 | map view line to model line/wrapped index (`:758`) | `viewer/common/view_model/view_model_lines_projected.mbt` — Local `get_view_line_info` matches. | TODO | TESTED |
| VML-005 | compute base view line from prefix sum (`:759`) | `viewer/common/view_model/view_model_lines_projected.mbt` — Local single-line method omits base because current projection helper does not need it. | TODO | PORTED |
| VML-006 | delegate exact model/wrapped/base tuple to projection (`:760`) | `viewer/common/view_model/view_model_lines_projected.mbt` — Local delegates without batch/base sharing. | TODO | TESTED |
| VML-007 | projected collection `getViewLinesData` member (`:763-798`) | `viewer/common/view_model/view_model_lines_projected.mbt` — Missing. | TODO | PORTED |
| VML-008 | clamp requested start/end view lines (`:765-766`) | `viewer/common/view_model/view_model_lines_projected.mbt` — Local viewport caller clamps separately; method-level source contract absent. | TODO | TESTED |
| VML-009 | map clamped start to prefix index/remainder (`:768-771`) | `viewer/common/view_model/view_model_lines_projected.mbt` — Missing batch start mapping. | TODO | TESTED |
| VML-010 | iterate model lines from mapped start to model line count (`:773-775`) | `viewer/common/view_model/view_model_lines_projected.mbt` — Missing. | TODO | TESTED |
| VML-011 | invisible projection continues without token demand (`:776-778`) | `viewer/common/view_model/view_model_lines_projected.mbt` — Missing batch hidden-line gate. | TODO | TESTED |
| VML-012 | derive first wrapped index and remaining view-line count (`:779-780`) | `viewer/common/view_model/view_model_lines_projected.mbt` — Missing. | TODO | TESTED |
| VML-013 | end-window overflow marks last line and truncates count (`:782-786`) | `viewer/common/view_model/view_model_lines_projected.mbt` — Missing. | TODO | TESTED |
| VML-014 | delegate per-model-line batch with base/global indices and the shared `needed` vector (`:787-788`) | `viewer/common/view_model/view_model_lines_projected.mbt` — Missing; current viewport loops single reads. | TODO | TESTED |
| VML-015 | advance view count and break after last model line (`:790-794`) | `viewer/common/view_model/view_model_lines_projected.mbt` — Missing exact termination. | TODO | TESTED |
| VML-016 | return result preserving requested slots/nulls (`:797`) | `viewer/common/view_model/view_model_lines_projected.mbt` — Missing. | TODO | TESTED |
| VML-017 | as-is `getViewLineData` member (`:1228-1240`) | `viewer/common/view_model/view_model_lines_projected.mbt` — No `ViewModelLinesFromModelAsIs` construction path. | TODO | DEFERRED (viewer-large-file-view-collection-parity.md owns the as-is collection; projected large models are the reviewed P2 deviation) |
| VML-018 | as-is direct `getLineTokens(viewLineNumber)` demand (`:1229`) | `viewer/common/view_model/view_model_lines_projected.mbt` — Same absent collection seam. | TODO | DEFERRED (viewer-large-file-view-collection-parity.md owns the as-is collection; projected large models are the reviewed P2 deviation) |
| VML-019 | as-is view data carries line content/inflated tokens (`:1230-1239`) | `viewer/common/view_model/view_model_lines_projected.mbt` — Same absent collection seam. | TODO | DEFERRED (viewer-large-file-view-collection-parity.md owns the as-is collection; projected large models are the reviewed P2 deviation) |
| VML-020 | as-is `getViewLinesData` member (`:1242-1254`) | `viewer/common/view_model/view_model_lines_projected.mbt` — Same absent collection seam. | TODO | DEFERRED (viewer-large-file-view-collection-parity.md owns the as-is collection; projected large models are the reviewed P2 deviation) |
| VML-021 | clamp both endpoints to model line count (`:1243-1245`) | `viewer/common/view_model/view_model_lines_projected.mbt` — Same absent collection seam. | TODO | DEFERRED (viewer-large-file-view-collection-parity.md owns the as-is collection; projected large models are the reviewed P2 deviation) |
| VML-022 | inclusive requested-line loop (`:1247-1251`) | `viewer/common/view_model/view_model_lines_projected.mbt` — Same absent collection seam. | TODO | DEFERRED (viewer-large-file-view-collection-parity.md owns the as-is collection; projected large models are the reviewed P2 deviation) |
| VML-023 | `needed=false` yields null without demand; true calls single-line path (`:1249-1250`) | `viewer/common/view_model/view_model_lines_projected.mbt` — Same absent collection seam. | TODO | DEFERRED (viewer-large-file-view-collection-parity.md owns the as-is collection; projected large models are the reviewed P2 deviation) |
| VML-024 | return result with null slots (`:1253`) | `viewer/common/view_model/view_model_lines_projected.mbt` — Same absent collection seam. | TODO | DEFERRED (viewer-large-file-view-collection-parity.md owns the as-is collection; projected large models are the reviewed P2 deviation) |


### `tokensStore.test.ts` exact named cases (counted REF rows)

| ID | Upstream test (`line`) | Required disposition | Status | Proposed terminal |
|---|---|---|---|---|
| REF-001 | `issue #86303 - color shifting between different tokens` (`:118-132`) | `viewer/common/tokens/tokens_store_reference_wbtest.mbt` — Future semantic edit adjustment; CTS incremental edit lane is independently N-A. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md) |
| REF-002 | `deleting a newline` (`:134-147`) | `viewer/common/tokens/tokens_store_reference_wbtest.mbt` — Future semantic edit adjustment; CTS incremental edit lane is independently N-A. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md) |
| REF-003 | `inserting a newline` (`:149-162`) | `viewer/common/tokens/tokens_store_reference_wbtest.mbt` — Future semantic edit adjustment; CTS incremental edit lane is independently N-A. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md) |
| REF-004 | `deleting a newline 2` (`:164-177`) | `viewer/common/tokens/tokens_store_reference_wbtest.mbt` — Future semantic edit adjustment; CTS incremental edit lane is independently N-A. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md) |
| REF-005 | `issue #179268: a complex edit` (`:179-209`) | `viewer/common/tokens/tokens_store_reference_wbtest.mbt` — Future semantic edit adjustment; CTS incremental edit lane is independently N-A. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md) |
| REF-006 | `issue #91936: Semantic token color highlighting fails on line with selected text` (`:211-252`) | `viewer/common/tokens/tokens_store_reference_wbtest.mbt` — Full syntactic/semantic merge-mask matrix. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md) |
| REF-007 | `issue #147944: Language id "vs.editor.nullLanguage" is not configured nor known` (`:254-269`) | `viewer/common/tokens/tokens_store_reference_wbtest.mbt` — Sparse zero-length/unknown-language handling. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md) |
| REF-008 | `partial tokens 1` (`:271-312`) | `viewer/common/tokens/tokens_store_reference_wbtest.mbt` — Partial-update ordering. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md) |
| REF-009 | `partial tokens 2` (`:314-354`) | `viewer/common/tokens/tokens_store_reference_wbtest.mbt` — Partial-update ordering. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md) |
| REF-010 | `partial tokens 3` (`:356-382`) | `viewer/common/tokens/tokens_store_reference_wbtest.mbt` — Partial-update split. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md) |
| REF-011 | `issue #94133: Semantic colors stick around when using (only) range provider` (`:384-400`) | `viewer/common/tokens/tokens_store_reference_wbtest.mbt` — Empty partial replacement. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md) |
| REF-012 | `bug` (`:402-449`) | `viewer/common/tokens/tokens_store_reference_wbtest.mbt` — Large partial-update reproduction with overlapping partial ranges. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md) |
| REF-013 | `issue #95949: Identifiers are colored in bold when targetting keywords` (`:452-496`) | `viewer/common/tokens/tokens_store_reference_wbtest.mbt` — Per-field semantic masks. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md) |
| REF-014 | `BUG: setPartial with startLineNumber > 1 and token removal creates invalid state` (`:499-525`) | `viewer/common/tokens/tokens_store_reference_wbtest.mbt` — Empty-piece compaction. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md) |
| REF-015 | `BUG: setPartial with split that creates empty first piece with invalid line numbers` (`:527-548`) | `viewer/common/tokens/tokens_store_reference_wbtest.mbt` — Empty split boundary. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md) |
| REF-016 | `addSparseTokens skips overlapping semantic tokens that produce backward endOffsets` (`:550-596`) | `viewer/common/tokens/tokens_store_reference_wbtest.mbt` — Monotone merged end offsets. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md) |
| REF-017 | `piece with startLineNumber 0 and endLineNumber -1 after encompassing deletion` (`:598-634`) | `viewer/common/tokens/tokens_store_reference_wbtest.mbt` — Encompassing deletion/compaction. | TODO | DEFERRED (viewer-semantic-token-acquisition-application-parity.md) |

### `modelLineProjection.test.ts` exact named cases (counted REF rows)

| ID | Upstream test (`line`) | Required disposition | Status | Proposed terminal |
|---|---|---|---|---|
| REF-018 | `getViewLinesData - no wrapping` (`:436-568`) | `viewer/common/view_model/model_line_projection_reference_wbtest.mbt` — Port including hidden-area rerun and exact per-line demand counts. | TODO | TESTED |
| REF-019 | `getViewLinesData - with wrapping` (`:570-741`) | `viewer/common/view_model/model_line_projection_reference_wbtest.mbt` — Port asserting one passive read per projected model line, not per wrapped output. | TODO | TESTED |
| REF-020 | `getViewLinesData - with wrapping and injected text` (`:743-940`) | `viewer/common/view_model/model_line_projection_reference_wbtest.mbt` — Port injected-token merge/slice results and one shared passive read. | TODO | TESTED |

### `model.line.test.ts` exact token-edit cases (counted REF rows)

`getIndentLevel` (`:58`) is an exact non-token sibling exclusion. Every test
in the `ModelLinesTokens` suite is counted below; each freezes incremental
`applyEdits` behavior that the normalized full-flush Viewer does not expose.

| ID | Upstream test (`line`) | Required disposition | Status | Proposed terminal |
|---|---|---|---|---|
| REF-021 | `single delete 1` (`:201-213`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental CTS delete behavior. | TODO | N-A (readonly full-flush edit seam) |
| REF-022 | `single delete 2` (`:215-227`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental CTS delete behavior. | TODO | N-A (readonly full-flush edit seam) |
| REF-023 | `single delete 3` (`:229-241`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental CTS delete behavior. | TODO | N-A (readonly full-flush edit seam) |
| REF-024 | `single delete 4` (`:243-255`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental CTS delete behavior. | TODO | N-A (readonly full-flush edit seam) |
| REF-025 | `single delete 5` (`:257-269`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental CTS delete behavior. | TODO | N-A (readonly full-flush edit seam) |
| REF-026 | `multi delete 6` (`:271-289`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental CTS multiline delete behavior. | TODO | N-A (readonly full-flush edit seam) |
| REF-027 | `multi delete 7` (`:291-309`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental CTS multiline delete behavior. | TODO | N-A (readonly full-flush edit seam) |
| REF-028 | `multi delete 8` (`:311-329`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental CTS multiline delete behavior. | TODO | N-A (readonly full-flush edit seam) |
| REF-029 | `multi delete 9` (`:331-349`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental CTS multiline delete behavior. | TODO | N-A (readonly full-flush edit seam) |
| REF-030 | `single insert 1` (`:351-363`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental CTS single-line insert behavior. | TODO | N-A (readonly full-flush edit seam) |
| REF-031 | `single insert 2` (`:365-377`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental CTS single-line insert behavior. | TODO | N-A (readonly full-flush edit seam) |
| REF-032 | `single insert 3` (`:379-391`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental CTS single-line insert behavior. | TODO | N-A (readonly full-flush edit seam) |
| REF-033 | `single insert 4` (`:393-405`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental CTS single-line insert behavior. | TODO | N-A (readonly full-flush edit seam) |
| REF-034 | `single insert 5` (`:407-419`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental CTS single-line insert behavior. | TODO | N-A (readonly full-flush edit seam) |
| REF-035 | `multi insert 6` (`:421-436`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental CTS multiline insert behavior. | TODO | N-A (readonly full-flush edit seam) |
| REF-036 | `multi insert 7` (`:438-453`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental CTS multiline insert behavior. | TODO | N-A (readonly full-flush edit seam) |
| REF-037 | `multi insert 8` (`:455-470`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental CTS multiline insert behavior. | TODO | N-A (readonly full-flush edit seam) |
| REF-038 | `multi insert 9` (`:472-493`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental CTS multiline insert behavior. | TODO | N-A (readonly full-flush edit seam) |
| REF-039 | `insertion on empty line` (`:512-538`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental empty-line store edit behavior. | TODO | N-A (readonly full-flush edit seam) |
| REF-040 | `updates tokens on insertion 1` (`:540-560`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental token-offset adjustment. | TODO | N-A (readonly full-flush edit seam) |
| REF-041 | `updates tokens on insertion 2` (`:562-582`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental token-offset adjustment. | TODO | N-A (readonly full-flush edit seam) |
| REF-042 | `updates tokens on insertion 3` (`:584-604`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental token-offset adjustment. | TODO | N-A (readonly full-flush edit seam) |
| REF-043 | `updates tokens on insertion 4` (`:606-626`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental token-offset adjustment. | TODO | N-A (readonly full-flush edit seam) |
| REF-044 | `updates tokens on insertion 5` (`:628-648`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental token-offset adjustment. | TODO | N-A (readonly full-flush edit seam) |
| REF-045 | `updates tokens on insertion 6` (`:650-670`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental token-offset adjustment. | TODO | N-A (readonly full-flush edit seam) |
| REF-046 | `updates tokens on insertion 7` (`:672-692`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental token-offset adjustment. | TODO | N-A (readonly full-flush edit seam) |
| REF-047 | `updates tokens on insertion 8` (`:694-714`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental token-offset adjustment. | TODO | N-A (readonly full-flush edit seam) |
| REF-048 | `updates tokens on insertion 9` (`:716-736`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental token-offset adjustment. | TODO | N-A (readonly full-flush edit seam) |
| REF-049 | `updates tokens on insertion 10` (`:738-752`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental token-offset adjustment. | TODO | N-A (readonly full-flush edit seam) |
| REF-050 | `delete second token 2` (`:754-773`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental token deletion. | TODO | N-A (readonly full-flush edit seam) |
| REF-051 | `insert right before second token` (`:775-795`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental boundary insertion. | TODO | N-A (readonly full-flush edit seam) |
| REF-052 | `delete first char` (`:797-817`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental token deletion. | TODO | N-A (readonly full-flush edit seam) |
| REF-053 | `delete 2nd and 3rd chars` (`:819-839`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental token deletion. | TODO | N-A (readonly full-flush edit seam) |
| REF-054 | `delete first token` (`:841-860`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental whole-token deletion. | TODO | N-A (readonly full-flush edit seam) |
| REF-055 | `delete second token` (`:862-881`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental whole-token deletion. | TODO | N-A (readonly full-flush edit seam) |
| REF-056 | `delete second token + a bit of the third one` (`:883-902`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental cross-token deletion. | TODO | N-A (readonly full-flush edit seam) |
| REF-057 | `delete second and third token` (`:904-922`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental multi-token deletion. | TODO | N-A (readonly full-flush edit seam) |
| REF-058 | `delete everything` (`:924-942`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental full-line deletion. | TODO | N-A (readonly full-flush edit seam) |
| REF-059 | `noop` (`:944-964`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental no-op edit. | TODO | N-A (readonly full-flush edit seam) |
| REF-060 | `equivalent to deleting first two chars` (`:966-986`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental replacement/deletion equivalence. | TODO | N-A (readonly full-flush edit seam) |
| REF-061 | `equivalent to deleting from 5 to the end` (`:988-1006`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental replacement/deletion equivalence. | TODO | N-A (readonly full-flush edit seam) |
| REF-062 | `updates tokens on replace 1` (`:1008-1031`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental multi-edit replacement. | TODO | N-A (readonly full-flush edit seam) |
| REF-063 | `updates tokens on replace 2` (`:1033-1060`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental multi-edit replacement. | TODO | N-A (readonly full-flush edit seam) |
| REF-064 | `split at the beginning` (`:1082-1097`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental newline split. | TODO | N-A (readonly full-flush edit seam) |
| REF-065 | `split at the end` (`:1099-1116`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental newline split. | TODO | N-A (readonly full-flush edit seam) |
| REF-066 | `split inthe middle 1` (`:1118-1133`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental newline split. | TODO | N-A (readonly full-flush edit seam) |
| REF-067 | `split inthe middle 2` (`:1135-1151`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental newline split. | TODO | N-A (readonly full-flush edit seam) |
| REF-068 | `append empty 1` (`:1173-1190`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental newline deletion/append. | TODO | N-A (readonly full-flush edit seam) |
| REF-069 | `append empty 2` (`:1192-1209`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental newline deletion/append. | TODO | N-A (readonly full-flush edit seam) |
| REF-070 | `append 1` (`:1211-1235`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental newline deletion/append. | TODO | N-A (readonly full-flush edit seam) |
| REF-071 | `append 2` (`:1237-1255`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental newline deletion/append. | TODO | N-A (readonly full-flush edit seam) |
| REF-072 | `append 3` (`:1257-1275`) | `viewer/common/model/model_line_reference_wbtest.mbt` explicit `SKIPPED` evidence — Incremental newline deletion/append. | TODO | N-A (readonly full-flush edit seam) |

Preserve the source test setup's explicit
`forceTokenization(model.getLineCount())` (`:355-356`): it is a caller-owned
force through the final line, not the implicit attach-time/no-argument sweep
this child removes. Clear tokenizer and token-store read counters after that
setup before asserting passive projection reads. The upstream helper
deliberately breaks after the first `needed` mask (`:419-430`), which means it
exercises only all-true. The local port must add all-false and
alternating/sparse masks to take MLP-013/020 and VML-011/023.

There is no direct pinned unit suite for `tokenizationRegistry.ts`; its branch
coverage must be derived from TRG rows. Existing local queue tests named
`addRange` and `addRangeAndResize` remain useful, but prove only the detached
data structure, not live scheduling.



## Mechanical Reconciliation

| Class | Rows |
|---|---:|
| Source atoms | 946 |
| Exact upstream tests | 97 |
| **Total counted ledger** | **1043** |

| Proposed terminal | Rows |
|---|---:|
| TESTED | 465 |
| PORTED | 201 |
| DEFERRED | 206 |
| N-A | 171 |
| **Total** | **1043** |

Prefix audit:

| Prefix | Rows |
|---|---:|
| ASB | 78 |
| BIA | 23 |
| CTE | 4 |
| CTS | 74 |
| FAX | 8 |
| FNT | 15 |
| ITM | 21 |
| LAN | 58 |
| LRG | 6 |
| MLP | 34 |
| NUL | 14 |
| REF | 72 |
| STB | 5 |
| STS | 76 |
| TMP | 8 |
| TMS | 158 |
| TMS-DEP | 19 |
| TMS-REF | 2 |
| TMT | 58 |
| TPM | 82 |
| TRG | 57 |
| TSB | 100 |
| UTM | 23 |
| VMI | 24 |
| VML | 24 |

All 1043 counted rows are TODO. There are zero PASS rows and no duplicate IDs. Local LOC rows are excluded.

## Local Coordination Rows (not counted)

| ID | Required post-approval correction | Exact destination | Status |
|---|---|---|---|
| LOC-001 | Remove attach-time whole-document force and make token_count count stored tokens without demand. | `viewer/attach_model.mbt`; `viewer/common/model/tokens/tokenization_text_model_part.mbt` | TODO |
| LOC-002 | Replace whole-document memo tests with passive-read, explicit-force, visible/background call counters. | `viewer/common/model/tokens/tokenization_text_model_part_wbtest.mbt`; `viewer/common/view_model/view_model_tokens_test.mbt` | TODO |
| LOC-003 | Remove stale-projection clamp only after exact early visible-range conversion is proved in both projection domains. | `viewer/common/view_model/view_model_lines_projected.mbt`; `viewer/common/view_model/set_value_flush_test.mbt` | TODO |
| LOC-004 | Raw UTF-16 code-unit slicing for encoder input preserves frozen EOL seam at D800/DBFF/DC00/DFFF, valid-pair halves, FEFF, and BMP boundaries. | `viewer/common/model/tokens/line_tokens_encoder.mbt` | TODO |
| LOC-005 | Raw UTF-16 token content/slice operations preserve the same matrix. | `viewer/common/tokens/line_tokens.mbt` | TODO |
| LOC-006 | Correct guide header: tokenization is passive on read and explicit/visible/background work owns lexer calls. | `viewer/common/model/tokens/README.md` | TODO |
| LOC-007 | Correct compatibility header and ownership after moving live queue/state implementation to model/tokens. | `viewer/common/model/text_model_tokens.mbt` | TODO |
| LOC-008 | Correct the model-line reference header to cite full path `vscode/src/vs/editor/test/common/model/model.line.test.ts` and oracle commit `b18492a288de038fbc7643aae6de8247029d11bd`; explicitly `SKIPPED`-name all 52 incremental cases because readonly Viewer has no incremental `applyEdits` seam and manually injected `ManualTokenizationSupport` remains deferred, rather than claiming background tokenization is absent. Keep the projection reference as a separate destination. | `viewer/common/model/model_line_reference_wbtest.mbt`; `viewer/common/view_model/model_line_projection_reference_wbtest.mbt` | TODO |
| LOC-009 | Place the syntactic font carrier in model/tokens, preserve the source `FontTokensUpdate` typealias there, and expose the exact same option/update/event values through the token-part event consumed by the parent; no duplicate parent carrier, alias, or conversion. Visual FontTokenDecorationsProvider stays deferred. | `viewer/common/model/tokens/annotations.mbt`; backend/token-part/annotation tests | TODO |
| LOC-010 | Keep large models on projected collection while disabling tokenization; document P2 deviation. | `viewer/common/view_model/README.md`; `viewer-large-file-view-collection-parity.md` | TODO |
| LOC-011 | Scheduler replacement seam: idle/zero handles plus generation cancel old queues, reset `_isScheduled`, and prevent stale callbacks from clearing fresh state. | `viewer/common/model/tokens/text_model_tokens.mbt`; `viewer/browser_host.mbt` | TODO |
| LOC-012 | Common-tokens batch/store placement takes top-level language id plus line-length closure; common/tokens never imports model/tokens. | `viewer/common/tokens/{contiguous_tokens_store,contiguous_multiline_tokens,contiguous_multiline_tokens_builder}.mbt` | TODO |
| LOC-013 | Reroute `ViewModel::get_line_content/get_line_length` away from token-reading `get_view_line_data` to non-token content/length paths; assert both token-store reads and lexer calls stay zero. | `viewer/common/view_model/view_model.mbt`; `viewer/common/view_model/view_model_tokens_test.mbt` | TODO |
| LOC-014 | Add raw start-offset word encoder; public registry wrapper does not construct end-offset LineTokens before TMS-126. | `viewer/common/model/tokens/line_tokens_encoder.mbt` | TODO |
| LOC-015 | `scheduler=None` enqueues no idle/zero/delayed work while explicit force and stabilized-true refresh remain synchronous; reattach with a scheduler starts a fresh generation. | `viewer/common/model/tokens/text_model_tokens.mbt` | TODO |
| LOC-016 | Correct the queue reference header to cite oracle commit `b18492a288de038fbc7643aae6de8247029d11bd` and full source path `vscode/src/vs/editor/test/common/model/textModelTokens.test.ts`. | `viewer/common/model/text_model_tokens_reference_test.mbt` | TODO |
| LOC-017 | Correct the guide reference header: only #133 and #11856 are bracket suites; #122 is tokenization and #63822 is embedded-language behavior. | `viewer/common/model/guides_text_model_part_reference_test.mbt` | TODO |
| LOC-018 | Move the exact `Get word at position` conformance case into `model_reference_wbtest.mbt`, citing `vscode/src/vs/editor/test/common/model/model.test.ts` at `b18492a288de038fbc7643aae6de8247029d11bd`; reclassify `word_helper_wbtest.mbt` as ordinary local coverage and remove the duplicate conformance claim. | `viewer/common/model/model_reference_wbtest.mbt`; `viewer/common/model/word_helper_wbtest.mbt` | TODO |

## Deviations Approved for Gate-B Review

- **Package cycle:** one TextModel-owned synchronized `TokenizationModelAccess`
  carrier replaces the source concrete-model reference; it is live, not copied.
- **Literal common-tokens placement:** store, multiline batch, and builder stay
  in `viewer/common/tokens`; the backend passes language/line-length access,
  and common/tokens never imports model/tokens.
- **Font carrier placement:** backend-owned annotation/event types live in
  `model/tokens`; the token part exposes the same nominal child event directly
  to the parent-owned consumer. The source-shaped `FontTokensUpdate` typealias
  stays inside the child package. This avoids a reverse package edge,
  cross-package aliasing, and payload conversion. Only the visual decoration
  consumer remains deferred.
- **Scheduler replacement safety:** unlike the source's process-global
  scheduler, Viewer may attach/detach scheduler-bearing hosts. Cancel handles,
  generation guards, and explicit `scheduler=None` prevent old queues from
  pinning or clearing new scheduling state while preserving source work order.
- **Reduced tokenizer API:** public `syntax.LineTokenizer` remains nonraising
  and has no has-EOL parameter. Only the internal adapter is source-shaped; the
  production wrapper ignores has-EOL at the public seam and emits raw
  start-offset words for one conversion.
- **Large-file collection:** tokenization disables at exact source thresholds,
  but the projected view collection remains until
  `viewer-large-file-view-collection-parity.md`.
- **Restore adaptation:** Viewer already has an optional, scroll-only
  `ViewerViewState`. This child ports only the source `View.restoreState`
  immediate-scroll-then-stabilized substep for `Some`; broader Monaco
  view-state capture/restore remains outside scope.
- **Semantic overlay:** every sparse/merge row remains deferred to
  `viewer-semantic-token-acquisition-application-parity.md`.
- **Representation:** `Missing | Empty | Words(Array[UInt])` preserves the
  observable source storage states; typed-array versus ArrayBuffer identity is
  N-A. Raw UTF-16 slicing follows the frozen EOL child.
- **Font emitter:** allocate/register both literal source emitters, expose the
  second, and dispose both. The visual decoration provider remains deferred.

## Required Behavior Matrix

- Passive read: `get_line_tokens` returns stored/default tokens and never
  invokes the lexer. Separate counters prove read calls versus lexer calls.
  Explicit `force_tokenization(line)` (including `tokenize_if_cheap`'s cheap
  true arm), stabilized/debounced visible refresh, and background callbacks
  are the only lexer drivers. The pinned
  modelLineProjection setup may explicitly force through the final line before
  counters are cleared; the read assertions then prove zero new lexer calls.
- Flush: `reset_tokenization(false)` suppresses only the full-reset event.
  A bounded `refreshAllVisibleLineTokens` may emit exact visible ranges before
  ViewModel content delivery. On growth, those events stay inside old visible
  ranges and therefore the old projection domain; on shrink, refreshed ranges
  clamp to the new line count and are valid in both domains. Prove those facts
  before removing the local projection clamp.
- Lifecycle: `0->1->2->1->0`, two disjoint/overlapping viewers, exact handle,
  scheduler install before first transition, first-scheduler retention,
  final-detach inert callback, scheduler clear after detach, and model-dispose
  cancellation. Test attached-count and AttachedViews aggregate invalidation
  independently on attach, visible-state change, and detach.
- Stabilization: ViewModel-owned scroll and content-mapping changes publish
  false; a generic render by itself publishes neither state. True occurs at
  one-time post-first-render initialization and after
  `Viewer::restore_view_state(Some(state))`. Restore commits both axes
  synchronously, its scroll-driven false/update completes first, then exactly
  one true update uses the restored viewport. `None` and absent-model restores
  remain no-ops and emit neither false nor true. Repeated renders never send
  true.
- Demand/state: line 0/1/middle/final/count+1; invalid/accurate; cheap boundary
  2047/2048; in-progress/completed/reset; completed -> reset remains completed
  and a repeated finish is silent; same/different carried states;
  double initial-state acquisition; missing/failing support; hasEOL true/false;
  direct setEndState interface-shape evidence; raw start offsets converted once;
  error reporting; and no widening of public LineTokenizer.
- Refresh clamping: start below 1, start above line count, end above line
  count, reversed start/end, and empty/equal boundaries; preserve the source's
  asymmetric start/end clamp order.
- Large file: size and line-count threshold-1/equal/+1 with OR combinations;
  flag remains constructor-fixed across smaller/equal/larger `set_value`;
  disabled models stay projected, produce defaults, and start no scheduler;
  `scheduler=None` enqueues nothing across attach/detach/reattach while
  explicit force and stabilized-true visible refresh remain synchronous.
- Visible scheduling: ViewModel-owned scroll callback publishes false before root apply-scroll/render; 50 ms unstable debounce versus immediate stable update;
  forward/backward, joined/overlap/disjoint ranges; idle deadline, strict
  timeRemaining/now branches, 1 ms slice, zero-timeout yield, 15 ms idle
  fallback, cancel handles, generation replacement, requestIdleCallback/cancel and
  timeout fallback.
- Store/registry: `Missing | Empty | Words(Array[UInt])`; first Missing->Empty changes, repeated Empty->Empty is equal; missing/default metadata,
  setMultiline changed-range aggregation, completed/reset, ordinary
  register/replace/remove/stale disposer, matching/nonmatching languages,
  synchronous fixed-true isResolved, color map/default background, and attached
  aggregate invalidation.
- Projection: Identity/Projected/Injected/Hidden, single/batch, all-true,
  all-false, first/last/alternating/sparse needed masks; five injection-context
  callbacks; decoration selection; wrapped indent/start/slice branches; one
  passive read per projected model line and zero lexer work.
- Font: absent/empty/nonempty fontInfo, annotation create/store/getter,
  one/many/removal updates with exact half-open offsets,
  family/size/line-height fields, backend setFontInfo, exact model event,
  live/disposal guard, duplicate-emitter allocation/exposure/disposal, and no
  visual decoration provider.
- Raw UTF-16: D800, DBFF, DC00, DFFF, each half of valid pairs, FEFF, ordinary
  BMP, empty and end boundaries through encoder and LineTokens slicing.
- Cancellation: cancel before first callback, detach/dispose while scheduled,
  old-generation callback after final detach and after reattach, callback after
  model dispose, repeated finish, reset/replacement while queued, and exact
  no-event/no-work assertions. `scheduler=None` enqueues nothing but does not
  disable synchronous explicit/stable work. A stale callback cannot clear a
  new generation's `_isScheduled` flag.
- Semantic rows require retained contract-shape evidence only; the future plan
  owns provider/merge behavior tests rather than impossible tests in this
  child.

## Cross-Plan Handoffs

This child completes frozen lifecycle CEW-086
(`ModelData.attachedView`, `codeEditorWidget.ts:2130`) and the
`model.onBeforeDetached(attachedView)` substep of CEW-088
(`:2134-2141`) without rewriting that historical ledger. It owns the borrowed
stable/unstable producer and exact-handle wiring. The parent coordination table
records the transfer. It also owns the existing scroll-only
`Viewer::restore_view_state` immediate-scroll-then-stabilized substep; broader
view-state shape stays in the P2 backlog.

## Milestones

1. Commit this documentation-only inventory and stop.
2. Obtain independent Gate-B approval; do not edit product/test code earlier.
3. Land access carrier, stores/backend, passive demand, scheduler, attached
   protocol, events, font payload, and projection demand in coherent commits.
4. Port exact tests and branch matrices; update contracts/generated interfaces.
5. Run targeted JS/native tests, `just check`, full JS/native tests,
   `just build`, and Chromium browser tests.
6. Complete independent Gate-D source/ledger/test/boundary audit and freeze.

## Exit Gate

- [ ] independent Gate B approves every source/test row, count, hash, target,
  terminal proposal, deviation, and handoff
- [ ] no product/test edit predates Gate-B approval
- [ ] passive reads never invoke lexer work
- [ ] visible/background scheduling is bounded and cancellation-safe
- [ ] attach/dispose ordering and multi-view ownership match the reviewed seam
- [ ] flush event ranges are valid in old and new projection domains
- [ ] semantic and large-file-collection dependencies remain explicit
- [ ] all quality gates and independent closing audits pass
- [ ] final ledger has zero TODO/PASS and is frozen

## Execution Record

- 2026-07-10: Gate A approved Option B: syntactic scheduling now; semantic
  acquisition/application deferred to the named future plan.
- 2026-07-13: corrected documentation-only Gate-B candidate prepared after
  three independent REJECT audits. It merges the complete surface, backend,
  store/registry/view-demand inventories; adds missing lifecycle, font,
  dependency, stabilization, projection, UTF-16, scheduler, and exact upstream
  test closure. The mechanically fixed denominator is 1008 rows = 911 source atoms + 97 exact upstream tests; proposed terminals are 460 TESTED / 184 PORTED / 194 DEFERRED / 170 N-A. Every counted row remains TODO. No product or test file
  changed. Status is inventory ready — STOP FOR REVIEW; Gate B has not passed.
- 2026-07-13: the first formal Gate-B round REJECTED the candidate for missing
  declared-type atoms, incomplete exact test ranges/SKIPPED destinations,
  false restore-state N-A classification, a font-carrier reverse package edge,
  bracket-construction ambiguity, incomplete NullState/non-encoded closure,
  and reset-state wording. The corrected candidate now has 1043 TODO rows =
  946 source atoms + 97 exact upstream tests, with proposed terminals 465
  TESTED / 201 PORTED / 206 DEFERRED / 171 N-A. All 72 REF rows name complete
  source ranges, and model-line N-A cases have explicit SKIPPED authorities.
  No product or test file changed; Gate B has not passed and requires a fresh
  independent review.
