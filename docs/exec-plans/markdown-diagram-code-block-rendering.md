# Markdown Diagram Code-Block Rendering

Status: proposed
Date: 2026-07-21
Upstream dependency: [`moonbit-community/diago`](https://github.com/moonbit-community/diago), at the published version selected during Gate A

## Outcome

Render the exact lowercase fenced-code language id `diago` as a diagram in
every consumer of the shared Markdown renderer:

- `diago` compiles through `Milky2018/diago` and renders SVG;
- every other fenced or indented code block keeps the current cmark or
  editor-token rendering behavior.

The implementation is a direct extension of the existing synchronous cmark
`CodeBlock` override in `internal/viewer/markdown`. It does not add a renderer
registry, public configuration, placeholders, workers, asynchronous rendering,
or a new security policy. A recognized diagram that fails to parse or render
falls through to the same ordinary-code path that the caller already uses.

The plan is complete when valid diagram fences produce inline SVG in hover,
agent-feedback, and whole-line Markdown-comment rendering; invalid diagrams and
unknown languages preserve their current source-code fallback; and the complete
JS/native and browser gates pass.

## Scope

### Selected behavior

The diagram branch runs before the optional caller-supplied
`code_block_renderer`:

```text
cmark CodeBlock
  -> exact fence id is diago
       -> Diago SVG success: emit wrapped SVG and consume the block
       -> failure: continue
  -> caller code-block renderer exists
       -> preserve the current tokenized override
  -> otherwise
       -> return false and preserve cmark's <pre><code> renderer
```

Only the fenced info-string language id selects diagram rendering. An
unlabelled or indented code block never becomes a diagram because of the active
model language. Matching remains case-sensitive and exact: only `diago` is
supported; spelling or case variants, including `uml` and `plantuml`, are
ordinary code.

The existing cmark info-string parser already extracts the first token.
Additional info-string text is ignored; this plan does not introduce
per-fence layout or theme options.

### Explicitly out of scope

- a diagram/fence renderer registry or third-party extension API;
- configurable aliases or public Viewer/Markdown options;
- lazy loading, WebAssembly adapters, Web Workers, cancellation, or async
  placeholders;
- SVG sanitization, trust modes, CSP policy, or changes to the existing browser
  Markdown URI/media policy;
- file or network imports from diagram fences;
- interactive SVG behavior, diagram editing, source maps, or click-to-source;
- automatic rerendering on theme changes;
- UML, PlantUML, Mermaid, Graphviz, or diagram languages other than `diago`;
- performance budgets or bundle splitting. Normal build output is still
  reviewed for accidental failure or obviously unreasonable growth.

## Current Baseline

`internal/viewer/markdown/markdown.mbt` owns the cmark document conversion. Its
block callback constructs one MoonBit-owned `MarkdownCodeBlock`, invokes the
optional synchronous override when present, and otherwise lets the composed
cmark HTML renderer handle the node. `MarkdownRenderFact.has_code_block` is set
before either branch.

`internal/viewer/markdown/tokenized_code_block.mbt` owns the shared lexical
code-block renderer. Hover reaches it through
`internal/viewer/contrib/hover/hover_render.mbt`; whole-line Markdown comments
pass it directly from `viewer/markdown_comments_contribution.mbt`. Agent
feedback calls the shared browser Markdown renderer without a code-block
override, so its ordinary fallback is cmark's `<pre><code>` output.

`internal/viewer/markdown` is multi-target and currently imports cmark plus the
editor tokenizer/model packages. `internal/viewer/browser/markdown` owns DOM
insertion and lifetime but does not need to change for direct synchronous SVG
output.

The reference build already assembles the three owning surface styles:

- `viewer/contrib/hover/hover.css`;
- `viewer/contrib/agent_feedback/browser/agent_feedback.css`;
- `viewer/contrib/markdown_comments/browser/markdown_comments.css`.

## Representation and Dependency Decisions

Add the reviewed published version of `Milky2018/diago` to the root `moon.mod`.
Import `Milky2018/diago` only from `internal/viewer/markdown/moon.pkg`. Do not
import it from browser contributions or the public Viewer facade.

Add one source unit, `internal/viewer/markdown/diagram_code_block.mbt`, in the
existing package. It owns private helpers with this effective contract:

```text
render_diagram_code_block(MarkdownCodeBlock) -> String?
render_diago_svg(String) -> String?
wrap_diagram_svg(String, String) -> String
```

No new public type or function is required. `render_markdown`,
`MarkdownCodeBlock`, `MarkdownRenderFact`, and `render_tokenized_code_block`
retain their signatures. Run `moon info --target all` and treat any generated
interface change beyond dependency reflection as a review failure.

### Diago

For an exact `diago` fence, call the root facade synchronously with explicit SVG
output:

```text
@diago.compile(
  source,
  options=@diago.CompileOptions::new().with_output_mode(Svg),
)
```

Use default layout, direction, and theme behavior. Do not install an import
resolver. Catch every `DiagoError` at the helper boundary and return `None` so
the original code block remains visible through the ordinary fallback.

### HTML and fallback

A successful result is emitted as:

```html
<div class="moonbit-viewer-markdown-diagram" data-diagram-language="diago">
  <svg>...</svg>
</div>
```

The wrapper and `data-diagram-language` value are generated only from the fixed
`diago` id. The SVG string is the upstream renderer result and is written
directly through the existing cmark render context. Do not add another DOM
postprocessing phase in this plan.

If diagram rendering returns `None`, reuse the current block callback control
flow rather than producing a diagram-specific error element:

- hover and whole-line Markdown comments call their existing tokenized
  renderer;
- agent feedback and any caller without an override use cmark's ordinary
  `<pre><code class="language-...">` rendering;
- `MarkdownRenderFact.has_code_block` remains `true` in all cases.

## Styling Contract

Add the same minimal wrapper behavior to the three current owning stylesheets;
do not create a new shared CSS asset or styling abstraction:

```css
.moonbit-viewer-markdown-diagram {
  max-width: 100%;
  overflow: auto;
}

.moonbit-viewer-markdown-diagram > svg {
  display: block;
  max-width: 100%;
  height: auto;
}
```

Scope each selector through the surface's existing Markdown/content root when
needed to avoid affecting unrelated host DOM. Preserve the SVG's own styling.
The whole-line Markdown size observer continues to measure the resulting
content and update its ViewZone; no new measurement mechanism is added.

## Execution Order and Milestone Commits

### Milestone 0 — dependency and target gate

- Refresh the selected published versions and their generated interfaces.
- Add the module dependency and package import.
- Prove that `internal/viewer/markdown` checks on both JS and native before
  editing the render path.
- Confirm the Diago facade still exposes synchronous `compile(...)->String`
  with SVG output.
- Review the new `moon.pkg` edges against `docs/architecture.md`.

If the dependency cannot compile for JS, do not substitute a subprocess,
remote service, npm adapter, or async Wasm design under this plan. Record the
target/API blocker and resolve it in the dependency before continuing.

Focused commands:

```sh
moon check internal/viewer/markdown --target js
moon check internal/viewer/markdown --target native
git diff --check
```

### Milestone 1 — direct diagram dispatch and multi-target tests

- Add the private diagram helper source unit.
- Construct `MarkdownCodeBlock` once in the cmark callback and try diagram
  rendering before the existing optional override.
- Preserve the old non-diagram and failure branches byte-for-byte where
  practical.
- Add focused multi-target tests for successful dispatch and fallback.
- Update `internal/viewer/markdown/README.md` with the built-in `diago` fence id,
  direct synchronous ownership, and focused commands.
- Run `moon info --target all` and review the generated interface.
- Commit the dependency, core behavior, focused tests, and owning README as one
  coherent milestone.

Required focused cases:

- `diago` produces the wrapper and SVG;
- malformed Diago source falls back through a supplied tokenized renderer;
- malformed diagram source without a supplied override falls back to cmark
  code HTML;
- an unknown fence, differently cased fence, unlabelled block, and indented
  block retain current behavior;
- successful and failed diagram attempts both report `has_code_block=true`.

Focused commands:

```sh
moon test internal/viewer/markdown --target js
moon test internal/viewer/markdown --target native
moon info --target all
git diff --check
```

### Milestone 2 — surface styling and browser proof

- Add the scoped wrapper/SVG rules to hover, agent-feedback, and
  Markdown-comment CSS.
- Extend the existing direct public-Viewer Markdown-comments component scenario
  with one Diago block. Keep the scenario user-visible and report only compact
  facts to Playwright.
- Assert that the fence becomes inline SVG, remains inside the Markdown content
  width/overflow boundary, and contributes to measured ViewZone height while the
  underlying model source remains unchanged.
- Preserve existing link, selection, source-hidden, model-flush, model-swap,
  and disposal evidence.
- Commit the CSS and browser proof as one milestone.

Focused commands:

```sh
just test-browser-component
git diff --check
```

### Milestone 3 — close contracts and validate

- Update the `internal/viewer/markdown` bullet in `docs/architecture.md` to
  record ownership of the built-in Diago adapter.
- Update `docs/harness.md` only if the component report or invocation contract
  changes.
- Review `moon.mod`, every changed `moon.pkg`, generated interfaces, and the
  production bundle output.
- Run the complete repository gates.
- Compress the landed behavior and deliberate exclusions into
  `docs/exec-plans/HISTORY.md`, then delete this active plan in the same closing
  commit.

Required final commands:

```sh
moon info --target all
just check
just test
just build
just test-browser
git diff --check
```

## Evidence Map

| Behavior or invariant | Owner | Evidence |
|---|---|---|
| exact fence-id dispatch | `internal/viewer/markdown/diagram_code_block.mbt` | JS/native focused tests |
| Diago source to SVG | `Milky2018/diago` adapter helper | focused valid/invalid Diago cases |
| diagram failure preserves source | existing code-block fallback | tokenized and cmark fallback tests |
| unknown code behavior unchanged | existing optional override/default renderer | regression cases in shared suite |
| direct SVG reaches real DOM | shared cmark/browser Markdown path | public-Viewer component test |
| diagram contributes to zone geometry | existing Markdown-comment size observer | real-browser height assertion |
| no public Viewer API change | package boundary | generated interface review |
| JS/native dependency compatibility | MoonBit build graph | focused checks plus `just check` |

## Review Gates

### Gate A — before render-path edits

- [ ] selected dependency versions and APIs are current;
- [ ] the dependency compiles through `internal/viewer/markdown` on JS and
  native;
- [ ] the direct hard-coded scope and exact fence ids remain unchanged;
- [ ] package edges preserve the existing multi-target/browser boundary;
- [ ] the worktree contains no unrelated overlapping edits.

This is an internal checkpoint. Record the result and continue unless target
compatibility or an upstream API change makes the selected direct design
impossible.

### Gate B — after core implementation

- [ ] valid Diago input emits wrapped SVG;
- [ ] invalid diagrams and ordinary code preserve the old fallback paths;
- [ ] both focused target suites pass;
- [ ] generated interfaces show no unintended API growth;
- [ ] the owning README matches the implementation.

### Exit Gate

- [ ] the three current Markdown surfaces receive the shared behavior;
- [ ] real-browser SVG and ViewZone geometry evidence is green;
- [ ] dependency and generated-interface reviews are recorded;
- [ ] `just check`, `just test`, `just build`, and `just test-browser` pass;
- [ ] durable docs and `HISTORY.md` describe the landed behavior;
- [ ] this active plan is removed after completion.
