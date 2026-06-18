# Viewer Package Namespace Rename

Status: proposed
Date: 2026-06-18

Superseding note (2026-06-18): language registration now uses
`@viewer.languages.set_tokens_provider(...)` and
`@viewer.languages.register_*_provider(...)`. Examples below with
`@viewer.register_tokenizer(...)` or `@viewer.languages.register_tokenizer(...)`
are historical naming-plan context, not the current API.

## Summary

Rename the public readonly viewer package family from implementation-oriented
`renderer/*` names to a product-oriented `viewer/*` namespace.

The current package names were useful while aligning the implementation with
Monaco's `editor/common` and `editor/browser` layers, but they now leak the
wrong mental model to embedders:

- `renderer/browser` sounds like a browser backend detail, while it is the
  public embeddable viewer API.
- `renderer` sounds like a rendering subsystem, while it also owns the common
  viewer model spine, viewport data, layout state, hit testing, and render-line
  contracts.

The target public shape is:

```moonbit
@viewer.Viewer(...)
@viewer.register_tokenizer(...)
```

If a later API facade adds Monaco-shaped language registration, that should
read:

```moonbit
@viewer.languages.register_tokenizer(...)
@viewer.languages.register_hover_provider(...)
```

This plan is a naming and package-boundary migration. It should not change
readonly viewer behavior.

## Supersedes

This plan supersedes the naming decisions in these implemented plans without
rewriting them:

- `monaco-role-aligned-viewer-architecture.md`, which mapped
  `vscode/src/vs/editor/common/*` to `renderer/*` and
  `vscode/src/vs/editor/browser/*` to `renderer/browser/*`.
- `monaco-renderer-model-structure.md`, which kept `renderer/browser` as the
  public embeddable surface.

Those files remain historical evidence. The new architecture docs should point
to this plan once the rename lands.

## Target Package Shape

Move the current package family as follows:

| Current package | Target package | Role |
| --- | --- | --- |
| `renderer/browser` | `viewer` | Public embeddable readonly viewer API; DOM view, input, widgets, services, tokenization registry |
| `renderer` | `viewer/common` | DOM-free viewer common layer and compatibility helpers |
| `renderer/core` | `viewer/core` | Position, range, and coordinate primitives |
| `renderer/model` | `viewer/model` | Readonly `TextModel` and `TextSnapshot` |
| `renderer/view_model` | `viewer/view_model` | Tokenized document, render frames, projections, folding, injected text, selection |
| `renderer/view_layout` | `viewer/view_layout` | Scroll, viewport, layout, view-zone geometry, scrollbar arithmetic |
| `renderer/view_line_renderer` | `viewer/view_line_renderer` | DOM-free render-line input/output and character mapping |

The top-level `viewer` package is the former browser viewer because it is the
package embedders should import. Do not create `viewer/browser` as the public
entry point unless a later backend split creates multiple concrete hosts.

The existing legacy `view` package is out of scope for this rename. Leave it in
place unless a separate cleanup plan removes or replaces it.

## Naming Rules

- Use `viewer` for the product namespace and public embedding API.
- Keep `Viewer` as the public facade type.
- Keep render-domain type names such as `RenderFrame`, `RenderLineInput`, and
  `RenderLineOutput2` where they describe real render data, not package
  identity.
- Keep DOM class names such as `.moonbit-viewer` and Monaco structural classes
  unchanged unless a test or doc still exposes the old package name.
- Use explicit import aliases where the default alias would be too generic:
  - import `baozhiyuan/editor/viewer` as `@viewer`;
  - import `baozhiyuan/editor/viewer/common` as `@viewer_common` when a caller
    needs the common-layer compatibility package;
  - keep focused aliases such as `@core`, `@model`, `@view_model`,
    `@view_layout`, and `@view_line_renderer` for internal packages when they
    stay unambiguous.
- Do not keep old `renderer/*` packages as forwarding shims. Migrate callers,
  docs, tests, examples, and architecture checks in the same change.

## Non-Goals

- Do not change readonly viewer behavior.
- Do not make the viewer editable.
- Do not add Monaco dependency injection, command services, extension host,
  workbench services, or editable model APIs.
- Do not introduce `@viewer.languages.*` in this package rename unless the
  implementation intentionally takes on the separate public API facade work.
- Do not create compatibility packages that re-export the old `renderer/*`
  paths.
- Do not rename every type containing "render"; only rename package paths and
  user-facing docs where "renderer" or "browser" describes the wrong layer.

## Dependency Direction

The renamed graph should preserve the current dependency boundaries:

```text
web -> workbench
workbench -> viewer, widgets/file_tree, remote_protocol, syntax/lang_*

viewer -> viewer/common, viewer/core, viewer/model,
          viewer/view_line_renderer, viewer/view_layout, viewer/view_model,
          workspace, language, syntax, decorations, platform/log

viewer/common -> viewer/view_line_renderer, viewer/view_layout,
                 viewer/view_model, decorations
viewer/view_layout -> viewer/view_model, viewer/view_line_renderer,
                      viewer/core, viewer/model, syntax, decorations, language
viewer/view_model -> viewer/view_line_renderer, viewer/core,
                     viewer/model, syntax, decorations, language
viewer/view_line_renderer -> viewer/core, syntax
viewer/model -> base/common, viewer/core

widgets/file_tree -> workspace
workspace -> base/common
language -> base/common, workspace
syntax/decorations -> viewer/core
remote_protocol/server/workbench/widgets -> base/common, workspace, language
syntax/lang_* -> syntax, viewer/core, viewer/model
platform/log -> no product packages
```

`viewer`, as the browser-backed embeddable package, remains JavaScript-only.
The `viewer/common`, `viewer/core`, `viewer/model`, `viewer/view_model`,
`viewer/view_layout`, and `viewer/view_line_renderer` packages remain
target-neutral, DOM-free, and FFI-free.

## Implementation Plan

### Phase 0: Baseline And Rename Inventory

1. Confirm the working tree is clean or record unrelated user changes.
2. Run an inventory before moving files:

   ```sh
   rg -n 'renderer/browser|baozhiyuan/editor/renderer|@browser|@renderer' \
     --glob 'moon.pkg' --glob '*.mbt' --glob '*.mbtx' --glob '*.md'
   ```

3. Review `docs/architecture.md`, all `renderer/**/README.md` files,
   `examples/embedded_viewer`, `workbench`, `web`, `tests/browser`, and
   `scripts/check-architecture.mbtx`.
4. Keep this phase behavior-free. The output is the exact list of imports,
   docs, generated interfaces, and tests that must move.

Validation: no code changes yet.

### Phase 1: Move Common Viewer Packages

1. Move directories:

   ```text
   renderer/core -> viewer/core
   renderer/model -> viewer/model
   renderer/view_model -> viewer/view_model
   renderer/view_layout -> viewer/view_layout
   renderer/view_line_renderer -> viewer/view_line_renderer
   renderer -> viewer/common
   ```

2. Update `moon.pkg` import paths for all moved packages and callers.
3. Use explicit aliases for `viewer/common` imports so call sites do not become
   `@common`.
4. Update package-local README titles and boundary sections.
5. Update references in tests and generated interface files only through the
   normal MoonBit workflow. Do not hand-edit generated `.mbti` files except as
   output from `moon info`.

Validation:

```sh
moon check --target all
moon test --target native viewer/core viewer/model viewer/view_model \
  viewer/view_layout viewer/view_line_renderer viewer/common
moon test --target js viewer/core viewer/model viewer/view_model \
  viewer/view_layout viewer/view_line_renderer viewer/common
```

### Phase 2: Promote The Public Viewer Package

1. Move `renderer/browser` to `viewer`.
2. Update all imports from `baozhiyuan/editor/renderer/browser` to
   `baozhiyuan/editor/viewer`.
3. Update aliases from `@browser` to `@viewer`.
4. Keep the public `Viewer` constructor, events, services, widgets,
   tokenization registry, DOM ownership, and lifecycle behavior in this package.
5. Keep `viewer/moon.pkg` JavaScript-only.
6. Do not create `renderer/browser` or `viewer/browser` forwarding packages.

Validation:

```sh
moon check --target js
moon test --target js viewer
moon test --target js examples/embedded_viewer
```

### Phase 3: Update Architecture Guardrails

1. Update `scripts/check-architecture.mbtx`:
   - replace product root `renderer` with `viewer`;
   - replace common package detection with `viewer/common` and
     `viewer/*` common-layer packages;
   - replace browser package detection with the top-level `viewer` package;
   - update forbidden imports from `baozhiyuan/editor/renderer/browser` to
     `baozhiyuan/editor/viewer`;
   - update `syntax/lang_*` allowed imports to `viewer/core`, `viewer/model`,
     and `syntax`.
2. Preserve the rule that common packages cannot import browser effects,
   workbench, widgets, transport, server, or Rabbita browser packages.
3. Preserve the rule that only composition layers import concrete
   `syntax/lang_*` packages.

Validation:

```sh
just check
```

### Phase 4: Update Docs, Examples, And Harness Text

1. Update `docs/architecture.md` so the public embedding surface is
   `viewer`, not `renderer/browser`.
2. Update all package READMEs under `viewer/**`.
3. Update `docs/references/monaco.md` and any Monaco layer maps that describe
   the active package graph.
4. Update `examples/embedded_viewer` docs and imports so the sample teaches
   `@viewer`.
5. Update browser test names, comments, and observability docs only where they
   mention package paths. Keep DOM selectors stable unless they still encode
   old package names.
6. Leave implemented exec plans unchanged except for adding a clearly dated
   superseding note if the file already uses a living addendum pattern. Prefer
   linking from current architecture docs instead of rewriting history.

Validation:

```sh
rg -n 'renderer/browser|baozhiyuan/editor/renderer|@browser|@renderer' \
  --glob 'moon.pkg' --glob '*.mbt' --glob '*.mbtx' --glob '*.md'
```

Expected result: no active-code or current-doc references remain, except
historical references inside implemented exec plans and reference notes that
explicitly explain the old name.

### Phase 5: Regenerate Interfaces And Run Full Checks

1. Run formatting and interface generation:

   ```sh
   moon fmt
   moon info
   ```

2. Review generated `.mbti` diffs. The expected API change is package path and
   alias movement, not behavior or type-shape changes.
3. Run repository checks:

   ```sh
   just check
   just test
   just test-browser
   ```

4. If browser test startup is flaky, split the failure into server startup vs
   app behavior with a real GET/browser probe before changing product code.

## Migration Notes

- External embedders will need to change imports from
  `baozhiyuan/editor/renderer/browser` to `baozhiyuan/editor/viewer`.
- Internal common-layer imports move from `baozhiyuan/editor/renderer/...` to
  `baozhiyuan/editor/viewer/...`.
- Calls currently written as `@browser.Viewer`, `@browser.register_tokenizer`,
  or `@browser.ViewerServices` become `@viewer.Viewer`,
  `@viewer.register_tokenizer`, and `@viewer.ViewerServices`.
- This plan intentionally does not preserve `@browser`. The old name is the
  problem being removed.

## Risks

- Generated interface diffs may be large because package paths are part of the
  public surface. Review them for accidental type or behavior changes.
- `viewer/common` can become a vague dumping ground if future work treats it as
  a generic utility package. Keep it limited to the existing DOM-free viewer
  common layer and continue promoting stable subsystems into focused packages.
- Search-based updates can miss Markdown code blocks and test fixture strings.
  The validation `rg` command is part of the exit criteria.
- The top-level `viewer` package is JavaScript-only while `viewer/*` common
  packages are target-neutral. The architecture checker must enforce this
  distinction.

## Exit Criteria

- Embedders import `baozhiyuan/editor/viewer` and use `@viewer`.
- No active product package imports `baozhiyuan/editor/renderer` or
  `baozhiyuan/editor/renderer/browser`.
- `docs/architecture.md` describes `viewer` as the public embeddable readonly
  viewer API.
- Architecture guardrails enforce the renamed package graph.
- The embedded viewer example builds and runs against `@viewer`.
- `moon info` has regenerated public interfaces for the renamed packages.
- `just check`, `just test`, and `just test-browser` pass.
