# viewer/inline_decorations

Faithful 1:1 port of Monaco's `common/viewModel/inlineDecorations.ts` — the
inline-decoration computers that map model decorations and injected text into
per-view-line `InlineDecoration`s.

This package is current conformance/support code, not part of the live viewer
rendering import chain. The production view-model path has its own projected
line and injected-text representation; wire this package into that path only as
an explicit integration change.

## Responsibilities

- `InlineDecorationType` / `InlineDecoration` (line/column `Range`,
  `inline_class_name`, type).
- `InlineModelDecorationsComputer`: resolves a model's decorations into view
  coordinates and groups them per view line (regular + before/after content +
  `affectsFont`), with a per-decoration-id `ViewModelDecoration` cache.
- `InjectedTextInlineDecorationsComputer`: computes inline decorations for a
  line's injected text, split across wrapped output lines.
- Minimal collaborators the suite needs: `ViewModelDecoration` +
  `is_model_decoration_visible` (`viewModelDecoration.ts`),
  `IdentityCoordinatesConverter` (`coordinatesConverter.ts`), and a
  `createTextModel`-style `TextModel`.

## Why its own package

Monaco declares `InlineDecorationType` inside `inlineDecorations.ts`, and its
`ViewModelDecoration`/`InlineDecoration` names collide with `viewer/view_model`,
which already has a *simplified* `ViewModelDecoration` (`{range, kind,
class_name}`) and reuses the renderer's column-span `InlineDecoration`. Keeping
the faithful Monaco names here avoids that collision and keeps the port
self-contained (depends only on `base/common`).

## Conformance

- `inline_decorations_reference_test.mbt` ports all 23 cases of
  `inlineDecorations.test.ts` (`suite('InlineModelDecorationsComputer')` 12 +
  `suite('InjectedTextInlineDecorationsComputer')` 11), preserving the upstream
  test names.

### Deviations (none exercised by the suite)

- `is_model_decoration_visible` always returns `true`: the
  `hideInCommentTokens`/`hideInStringTokens` paths need a tokenization seam this
  readonly port does not carry, and no upstream case sets those flags.
- `TextModel` line lengths use `String::length()` (UTF-16 code units, matching
  Monaco) over a `\n`-split model; the fixtures are single-`\n`, ASCII text.

## Boundaries

- May depend on `base/common`.
- Must not depend on `viewer/common`, `viewer`, `web`, server, transport, or
  host packages. Must not declare FFI.

## Checks

- Run `moon test --target js viewer/inline_decorations` and
  `moon test --target native viewer/inline_decorations`.
