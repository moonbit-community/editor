# viewer/common/inline_decorations

Faithful 1:1 port of Monaco's `common/viewModel/inlineDecorations.ts` — the
inline-decoration computers that map model decorations and injected text into
per-view-line `InlineDecoration`s. Part of the live decoration pipeline:
`viewer/common/view_model`'s `ViewModelDecorations` wraps
`InlineModelDecorationsComputer`.

## Responsibilities

- `InlineDecorationType` / `InlineDecoration` / `ViewModelDecoration` /
  `ViewDecorationsCollection`: the view-coordinate decoration shapes.
- `InlineModelDecorationsComputer`: resolves a model's decorations into view
  coordinates and groups them per view line (regular + before/after content +
  `affectsFont`), with a per-decoration-id `ViewModelDecoration` cache and the
  `on_model_decorations_changed` / `on_line_mapping_changed` invalidation
  hooks.
- `InjectedTextInlineDecorationsComputer`: computes inline decorations for a
  line's injected text, split across wrapped output lines.
- The seams the computers are generic over: the `InlineDecorationsModel`,
  `CoordinatesConverter`, and `InlineDecorationOptions` traits, with the
  `viewer/common/model` impls provided here.

## Why its own package

Monaco declares `InlineDecorationType` inside `inlineDecorations.ts`, and its
`ViewModelDecoration`/`InlineDecoration` names collide with simplified types
`viewer/common/view_model` already had. Keeping the faithful Monaco names here
avoids that collision; `view_model` re-exports them via `pub type` aliases.

## Conformance

- `inline_decorations_reference_test.mbt` ports all 23 cases of
  `inlineDecorations.test.ts`, preserving the upstream test names.
- Deviation: `is_model_decoration_visible`'s
  `hideInCommentTokens`/`hideInStringTokens` paths need a tokenization seam
  this readonly port does not carry; no upstream case sets those flags.

## Boundaries

- May depend on `base/common` and `viewer/common/model` only. Must not declare
  FFI; builds on `js` and `native`.

## Checks

- Run `moon test --target all viewer/common/inline_decorations`.
