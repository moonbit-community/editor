# Inline Decorations and View Model Package Merge

Status: implementation in progress — Gate A approved; Milestones B–E complete
2026-07-14; closeout record pending
Date: 2026-07-13
Oracle commit: `vscode` submodule at
`b18492a288de038fbc7643aae6de8247029d11bd`

Gate A review artifact:
`inline-decorations-view-model-package-merge-gate-a.md`. The user explicitly
approved Gate A on 2026-07-14. Milestone B then relocated the implementation
and its 23-case reference suite without changing behavior. Milestone C removed
the cross-package traits/generics and consolidated injected-text decoration
computation on the projection-owned implementation.

## Goal

Merge `viewer/common/inline_decorations` into
`viewer/common/view_model`, place the `inlineDecorations.ts` port beside its
Monaco owner, and remove generic/public traits that exist only to cross the
current MoonBit package boundary.

The combined package is about 7,105 production lines, below the repository's
10k package target. Production should use the concrete `TextModel`,
coordinates converter, and model-decoration option types. Test doubles may
remain white-box/private; they must not force a production seam into the
generated package interface.

This is an ownership/API refactor. Existing inline-decoration behavior and
the conformance test denominator remain unchanged.

## Current Denominator

| Local package | Production lines | Current role |
|---|---:|---|
| `viewer/common/inline_decorations` | 578 | inline computers, generic model/options seams, decoration types |
| `viewer/common/view_model` | 6,527 | projection, converter, decorations, view-model lifecycle |
| Combined target | 7,105 | one multi-target view-model package |

The current inline file is pinned to the older `294fb350...` source and
contains:

- `InlineDecorationsModel`;
- `CoordinatesConverter`;
- `InlineDecorationOptions`;
- concrete implementations for local model/options types;
- inline decoration and view-model decoration types;
- inline and injected-text decoration computers;
- source deviations around token visibility and before/after decoration
  options.

The local scope is every production/test/README/manifest file under
`viewer/common/inline_decorations`, plus all imports and aliases in model,
view-model, folding, viewer, and tests.

## Phase 0: Pinned Source Scope

Read and inventory the complete current upstream files:

- `vscode/src/vs/editor/common/viewModel/inlineDecorations.ts`
- `vscode/src/vs/editor/common/viewModel/viewModelDecoration.ts`
- `vscode/src/vs/editor/test/common/viewModel/inlineDecorations.test.ts`

Also inventory the complete converter/model/decoration method clusters called
by those files in:

- `viewModelImpl.ts` and its coordinates converter;
- `viewModelDecorations.ts`;
- `textModel.ts` decoration queries/options.

Explicitly out of scope:

- adding unported decoration option fields or token visibility behavior;
- changing projection, folding, injected-text ordering, or hidden-area logic;
- redesigning the model decoration store;
- fixing upstream drift inside the relocation commit.

Existing behavior deviations remain deviations. If the new pin changes a
covered source branch, record the delta and create a separate behavior
milestone/addendum after review.

## Gate A: Inventory and Review Stop

Before moving code, produce:

1. A complete source member/constant/branch ledger for the two upstream units.
2. A test-case ledger for every upstream inline-decoration test case and local
   disposition.
3. A reference inventory for every local public trait, type, constructor, and
   helper.
4. A production-vs-test matrix for each generic parameter and trait
   implementation.
5. A current-pin diff from `294fb350...` to `b18492a...` for the scoped source
   and tests.
6. A target type map identifying which declarations become concrete, private,
   canonical aliases, or remain genuinely public.

Every source member receives a parity-ledger row with an allowed terminal
status. Record inventory and ledger counts.

**Review gate: stop here. Do not move or rewrite inline-decoration code until
the denominator and type map have been reviewed.**

## Target Ownership

Move the implementation to focused files under
`viewer/common/view_model/`:

- `inline_decorations.mbt` for `inlineDecorations.ts`;
- `view_model_decoration.mbt` for `viewModelDecoration.ts` declarations not
  already owned by `view_model_decorations.mbt`;
- `inline_decorations_reference_wbtest.mbt` for the conformance suite;
- small helper files only when they correspond to a real concept/source unit.

Production target types are concrete:

- real model reads use `@model.TextModel` or the precise package-private model
  surface already consumed by `ViewModel`;
- coordinate conversion uses the package's canonical concrete converter/type;
- real decoration options use `@model.ModelDecorationOptions`;
- real view-model decoration values use one canonical local type.

Generic traits may survive only as private test infrastructure if the
inventory proves that doing so materially preserves the upstream test shape.
No test-only generic appears in `pkg.generated.mbti`.

## Milestone B: Mechanical Relocation

1. Add the inline package's dependencies to
   `viewer/common/view_model/moon.pkg`.
2. Move production and reference-test files without logic changes.
3. Update imports and package qualifications everywhere.
4. Delete `viewer/common/inline_decorations/moon.pkg` after its final caller
   moves.
5. Run the reference suite before changing generic/type seams.

Gate:

- `moon check --target all`
- inline-decoration and view-model decoration reference tests
- `just check`

Commit the relocation separately from API simplification.

## Milestone C: Remove Cross-Package Generic Seams

1. Replace `InlineDecorationsModel` in production with direct concrete model
   reads.
2. Replace the duplicate/reduced `CoordinatesConverter` trait with the
   canonical view-model converter surface.
3. Replace `InlineDecorationOptions` in production with concrete model
   decoration options.
4. Collapse generic `ModelDecoration[O]`/context carrier types where their only
   production instantiation is the real model type.
5. Keep source test doubles inside the white-box test file or behind private
   package helpers.
6. Remove conversion functions and aliases that only bridged the old package.

Preserve source ordering for sorting, range intersection, injected-text
placement, visibility, and before/after decoration construction. Any changed
control flow requires a ledger update and branch test.

## Milestone D: Resolve the Recorded Deviations Deliberately

For each existing header deviation, choose one reviewed outcome:

- `PORTED` with the source field/branch and a failing-before test;
- `DEFERRED (reason)` because the model/token seam is still absent;
- `N-A (reason)` because the readonly product cannot produce the input.

Do not leave constant `None`/`false` implementations documented as if they
were complete source behavior. This milestone may update the deviation ledger,
but it must not silently broaden the implementation. Any real behavior port is
a separate coherent commit after the relocation/API refactor is green.

## Milestone E: API, Style, and Documentation

1. Run `moon ide analyze viewer/common/view_model` and shrink visibility.
2. Use `Type::Type` for touched primary constructors.
3. Prefer array pattern matching over `.get(0)` in newly touched local glue,
   but preserve source-shaped algorithmic loops.
4. Regenerate and review `pkg.generated.mbti`; confirm test seams disappeared.
5. Merge the inline README's current contracts, source map, deviations, and
   test commands into `viewer/common/view_model/README.md`.
6. Update architecture and reference docs; remove the obsolete package README.

## Test Matrix

The retained/ported branch matrix must cover:

- no decorations / one / overlapping / adjacent / whole-line decorations;
- regular, before, after, and letter-spacing-affecting inline types;
- injected text before/after and multiple injections at one position;
- hidden, collapsed, folded, and wrapped ranges;
- source options present/absent, including currently deferred fields;
- model-to-view conversion at line start/end and across wrapping;
- stable ordering and class-name propagation.

Required validation:

- `moon check --target all`
- inline-decoration reference tests
- view-model decoration, folding, projection, and render-line tests
- `just check`
- `just test`
- `just build`
- `just test-browser`

## Exit Criteria

- [ ] inventory rows equal scoped source members; final totals are recorded
- [ ] `viewer/common/inline_decorations` no longer exists as a package/import
- [ ] inline-decoration production code lives with `view_model`
- [ ] no public trait/generic exists solely to support a test double or old
      package boundary
- [ ] current-pin source drift is reconciled explicitly
- [ ] existing and newly ported behavior has branch-derived tests
- [ ] all deviations are terminal and justified
- [ ] closing complete-source reread finds no unaccounted member
- [ ] required validation is green

## Cross-Plan Coordination

Run `text-model-tokenization-package-merge.md` first. Both plans touch model
imports, `viewer/common/view_model/moon.pkg`, token visibility, and decoration
tests; parallel execution would make the ownership/API denominator unstable.
