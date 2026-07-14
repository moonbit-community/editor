# Inline Decorations and View Model Package Merge — 2026-07-14 Test Addendum

Status: implemented and validated

Parent history: `inline-decorations-view-model-package-merge.md`

This addendum preserves the implemented parent plan as immutable history. A
requirement-level completion audit found that its exact 23-case upstream suite
was green, but several additional behavior-variable combinations listed in the
approved Gate A matrix had no direct executable evidence.

## Added Branch Matrix

`viewer/common/view_model/inline_decorations_matrix_wbtest.mbt` adds 15 focused
white-box cases without changing product code or the exact upstream test names.
They cover:

- overlapping, adjacent, and same-line model decorations, including input
  order and exact ranges;
- the reachable `isWholeLine=true` conversion to model-line minimum and maximum
  columns;
- wrapped projection at exact view-line boundaries;
- suppression of before/after endpoints outside the viewport and per-line font
  flags for in-viewport endpoints through the reviewed private option seam;
- minimap/margin flag forwarding and the reachable glyph-margin-only model
  query;
- both `onModelDecorationsChanged` and `onLineMappingChanged` cache
  invalidation paths;
- model `before` then `after` injected text at one position and direct
  same-offset accumulated injection ordering;
- production projection deriving aligned option/offset arrays from the same
  injected parts;
- empty injected text, empty break offsets, exact
  `injectedStart == lineEnd`, zero-width clipping, and next-line reprocessing;
- absent or short option arrays when offsets are present, directly exercising
  the source consumer's option-array precondition.

The exact Monaco conformance file remains
`inline_decorations_reference_wbtest.mbt` with its original 23/23 labels. The
new file is a local branch/configuration matrix, not a claim that Monaco added
15 named tests.

## Terminal Product-Seam Dispositions

The following Gate A matrix entries remain terminal rather than being relabeled
as tested product behavior:

- `DEFERRED` — hidden/folded whole-line parity requiring the absent
  `allowZero=false` and `belowHiddenRanges=true` converter switches;
- `DEFERRED` — comment/string token visibility because canonical decoration
  options have no `hideInCommentTokens` or `hideInStringTokens` fields;
- `DEFERRED` — production `beforeContentClassName`, `affectsFont`, and injected
  letter-spacing inputs. Private resolved-option tests cover their algorithms
  but do not create product reachability;
- `DEFERRED` — true minimap-only filtering because the readonly model has no
  bracket-provider merge and the reviewed view-model seam intentionally ignores
  that flag. The computer's flag forwarding is tested separately.

These are the same seam-based outcomes frozen by Gate A. Porting any of them
requires its own reviewed behavior plan.

## Validation

Validation on 2026-07-14 passed:

```text
matrix suite:             15/15 JavaScript, 15/15 native
exact upstream suite:     23/23 JavaScript, 23/23 native
complete view_model:     207/207 JavaScript, 207/207 native
just test:              1402/1402 JavaScript, 1004/1004 native
just test-browser:         82/82
```

`just check` and `just build` also passed. The only compiler diagnostics were
the three pre-existing unused fields in
`viewer/browser/view/rendering_context.mbt`. The browser suite's known missing
generated-fixture diagnostic remained non-fatal; its owning performance case
and the complete suite passed.
