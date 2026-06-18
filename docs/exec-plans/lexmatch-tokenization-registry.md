# Monaco-Shape Tokenization with Compile-Time `lexmatch` Lexers

Status: implemented (2026-06-12).

Superseding note (2026-06-18): embedders now install tokenizers through
`@viewer.languages.set_tokens_provider(...)` or an isolated `Languages` value.
Historical mentions of `Viewer::register_tokenizer(...)` below refer to the
original tokenization-registry implementation.

Implementation notes (deviations found during Phase 0 probes, all
recorded in `syntax/README.md`):

- `with first` warns as deprecated on moon 0.1.20260610 even when
  written explicitly (warning 0076 `lexmatch_first_match`), and
  `with longest` rejects `if` guards — so every rule set uses
  `with longest`, keyword classification happens in arm bodies, and
  rule-priority conflicts resolve by tie-break order (equal-length
  matches prefer the earlier arm) or a longer specific rule.
- In pattern strings `\{` parses as (unsupported) string interpolation;
  literal braces are written as classes (`[{]`, `[}]`), and bare `-`
  and `]` are rejected inside classes (`|` is literal there). Verified
  against the compiler's regex parser sources, not just probes.
- Slicing mid-surrogate panics, so the hand-rolled plain fallback
  advances surrogate pairs whole; `lexmatch` itself is character-based
  and never splits pairs.
- `infer_language_id` defaults unknown extensions to `"moonbit"`, so
  the plain-fallback browser spec uses a `.txt` fixture
  (`docs/fixtures/project/notes.txt`).
- Language lexers coalesce contiguous same-tag lexemes so a plain
  string stays one `tok-string` span (keeps the pre-existing
  watched-file spec green).
- The third language is `lang_javascript` (also registered for
  `typescript`); regex literals lex as operators (token-history
  heuristics out of scope).

## Goal

Copy Monaco's tokenization architecture into the viewer library and replace
Monarch's runtime JS-regex engine with MoonBit's built-in compile-time
`lexmatch` lexer generator:

1. Monaco's `TokenizationRegistry`: tokenization support registered per
   language id, looked up at render time, with a plain-text fallback.
2. Monaco's `ITokenizationSupport`/`IState` contract: line-at-a-time
   tokenization with an explicit carried state whose equality lets callers
   detect convergence.
3. Monarch's grammar structure: per-language tokenizers organized as state
   machines (state stack, push/pop, keyword-cases classification) — but
   written as MoonBit code whose rules are `lexmatch` arms, so the grammar
   is compiled to a tagged DFA at build time instead of interpreted JS
   regexes at runtime.

Highlighting stays in the frontend library: pure MoonBit, no FFI, no wasm
payload, no server dependency, identical on js and native targets. Languages
are packages composed by import (no runtime grammar loading — the
`setMonarchTokensProvider` capability is deliberately dropped, consistent
with the repository's composition-over-configuration rule). The semantic
token overlay from `language` providers remains the accuracy tier on top and
does not change.

The editor stays readonly. No protocol packet shapes change.

## Current State (verified against source)

- `syntax/highlight.mbt` is one hand-rolled whole-document lexer with 7
  `HighlightTag`s and a 13-word MoonBit-ish keyword list, applied to every
  file regardless of language. `HighlightTag::css_class` maps tags to
  `tok-*` class names.
- The only production call site is `renderer/browser/render.mbt:37`
  (`let tokens = @syntax.highlight(doc)`), feeding
  `renderer.build_frame(doc, viewport, tokens, decorations, providers)`.
- Documents already carry `language_id` everywhere: inferred in
  `workspace/source.mbt` (`infer_language_id`), present on
  `@core.DocumentSnapshot` and `RenderFrame`.
- `renderer/render_frame.mbt` slices doc-offset tokens per line
  (`spans_for_line`) and overlays semantic tokens (`overlay_semantic_tokens`,
  `sem-<type>` classes win over syntax classes). This consumer contract can
  stay unchanged.
- Token CSS lives in `app/src/style.css` (`tok-*` rules at ~416, `sem-*`
  rules declared after so semantic wins).
- The provider-registry precedent: `renderer/browser/registry.mbt` holds
  module-level `Ref` registries; the registry starts empty and the host
  registers what it has at startup. Module-level `Ref`s are confined to
  `renderer/browser` and `workbench` by convention.
- `lexmatch` verified on the pinned toolchain (moon 0.1.20260610) by probe
  programs, and against the compiler sources
  (`~/Workspace/ideas-worktrees/ideas-master`, `lib/xml/regex/README.md`,
  `lib/xml/typing/typer.ml`):
  - `lexmatch view with longest { ("regex" as m, rest) => ... }`; pattern
    forms `(regex)`, `(regex, rest)`, `(start_rest, regex, rest)`;
    sequencing by juxtaposition with nested `as` binders
    (`(("[a-z]+" as w) "=" "[0-9]+", rest)`).
  - Regex literals are raw (single-backslash escapes) and validated at
    compile time; the engine is a tagged-DFA pipeline (no backtracking).
  - Strategies: `with first` (default; ordered rule priority — Monarch
    semantics; supports `if` guards) and `with longest` (maximal munch; no
    guards, no start-rest binder).
  - Supported: classes/ranges, alternation, `* + ? {n,m}`, `(?:...)`,
    scoped case-insensitivity `(?i:...)`, POSIX classes `[[:digit:]]`
    `[[:word:]]`, Unicode literals/ranges in classes (desugared to UTF-16
    code units — matches the repo position convention).
  - Not supported: lookahead/lookbehind, `\b`, `\p{...}`, named groups in
    lex expressions, dynamic patterns (no regex interpolation).
- Monaco references (design only, no imports):
  `vscode/src/vs/editor/common/tokenizationRegistry.ts` (registry),
  `vscode/src/vs/editor/common/languages.ts:123-174` (`ITokenizationSupport`,
  `IState.clone/equals`),
  `vscode/src/vs/editor/standalone/common/monarch/` (state-machine
  semantics, ~1.9k lines; the compile half becomes unnecessary).
  Monaco's `basic-languages` grammar corpus is in the external
  monaco-editor repository (not checked in); `codemirror/legacy-modes/mode/`
  (100+ stream modes) is checked in as a second reference for porting.

## Reference Map (Monaco -> this repo)

- `TokenizationRegistry.register(languageId, support)` ->
  `syntax.TokenizerRegistry` value; singleton instance owned by
  `renderer/browser` like the existing provider registries.
- `ITokenizationSupport.getInitialState()/tokenize(line, state)` ->
  `syntax.LineTokenizer` trait.
- `IState.clone()/equals()` -> opaque `TokenizerState` with derived `Eq`
  (no `clone` needed; values are immutable).
- Monarch tokenizer states + `@keywords` cases -> per-language MoonBit
  functions, one `lexmatch` per state, keyword classification by word-set
  lookup on the bound identifier.
- `monarchCompile.ts` -> deleted from the design; the MoonBit compiler
  validates and compiles every rule at build time.
- Monaco standard token types -> widened `HighlightTag` set mapped to
  `tok-*` classes.

## Target Package Shape

- `syntax` — contracts and driver only. Still imports only `core`. No
  module-level state. Owns: `HighlightTag` (widened), `Token`,
  `TokenizerState`, `LineTokenizer` trait, `TokenizerRegistry` (a plain
  value), the line-by-line document driver, and the plain-text fallback
  tokenizer.
- `syntax/lang_moonbit`, `syntax/lang_json`, ... — one package per
  language, each importing only `core` and `syntax`. Optional by import:
  only `workbench` and `examples/embedded_viewer` (the composition layers)
  import them. `renderer/browser` must not.
- `renderer` — unchanged consumer (`build_frame` keeps taking
  `Array[@syntax.Token]`).
- `renderer/browser` — owns the singleton registry instance and the
  `Viewer::register_tokenizer(...)` embedding API, mirroring
  `register_hover_provider`; `render.mbt` resolves the tokenizer by
  `doc.language_id` with plain fallback.

## Phase 0 — Spikes

1. Compile a `lexmatch` behind a trait method in a shared package with
   `moon check --target all` / `moon build --target all` (js + native) to
   confirm no target restrictions for the generated DFA code.
2. Tokenize a 10k-line fixture on both targets; record timing. Budget:
   no worse than 2x the current generic lexer (it should be faster — DFA vs
   per-token branching is not the bottleneck; allocation is).
3. Confirm offsets/binder lengths count UTF-16 code units with non-BMP
   characters in a probe (repo position convention).
4. Pin note: `lexmatch` semantics verified on moon 0.1.20260610; first-match
   without annotation warns as deprecated, so all rule sets must write the
   strategy explicitly.

## Phase 1 — Tokenization Contracts in `syntax` (the registry copy)

1. Widen `HighlightTag` toward Monaco's standard token types: add
   `Operator`, `Delimiter`, `Type`, `Function`, `Variable`, `Constant`,
   `StringEscape`, `CommentDoc`, `Regexp`, `Tag`, `Attribute`, `Invalid`.
   Extend `css_class()` (`tok-operator`, `tok-type`, ...). Keep existing
   tags and class names stable for specs.
2. Add the line contract:
   - `TokenizerState` — opaque immutable value with `Eq` (representation:
     a `String`, like Monaco's interned Monarch stacks; languages encode
     their own stack/payload). Revisit only if profiling says so.
   - `struct LineToken { start : Int; end : Int; tag : HighlightTag }`
     (line-local offsets; no text payload).
   - `trait LineTokenizer { initial_state(Self) -> TokenizerState;
     tokenize_line(Self, line_text : String, state : TokenizerState)
     -> (Array[LineToken], TokenizerState) }`.
3. Add `TokenizerRegistry` as a plain value: `register(language_id,
   &LineTokenizer)`, `lookup(language_id) -> &LineTokenizer?`. No global
   instance in `syntax`.
4. Add the document driver: feeds lines through a `LineTokenizer` carrying
   state, converts line-local tokens to doc-offset `Array[Token]`
   (the shape `build_frame` already takes), and records per-line entry
   states (kept internal for now; enables windowed re-tokenization later
   without changing this contract — the `IState.equals` convergence idea).
5. Re-express the current generic lexer as the `plain` fallback
   `LineTokenizer` (also proves the contract).
6. Tests: a toy two-state tokenizer (block-comment-across-lines) proving
   state carry, doc-offset conversion, and entry-state equality; UTF-16
   offset test with non-BMP text.

Validation: `just check`, `just test`; no behavior change anywhere yet.

## Phase 2 — `syntax/lang_moonbit` (first real lexer, hand-written)

1. States (each one `lexmatch ... with longest` function): `Normal`,
   `InString` (with `\{` interpolation pushing back to expression state),
   `InMultilineString` (`#|` / `$|` lines), `InDocComment`. Rules: the
   full current MoonBit keyword set via identifier + word-set
   classification (the Monarch `@keywords` idiom — no `\b` needed),
   capitalized identifiers as `Type`, numeric literals (hex/oct/bin,
   underscores, floats), `//` and `///` comments, attributes/pragmas,
   operators and delimiters, escapes inside strings as `StringEscape`.
2. Register nothing yet — package exports the lexer value only.
3. Golden tests: token-stream snapshots over `docs/fixtures/project`
   sources; line-boundary cases (string interpolation spanning spans,
   multiline strings).

Validation: `just check`, `just test` (package tests).

## Phase 3 — Viewer and Workbench Wiring

1. `renderer/browser`: add the singleton `TokenizerRegistry` to
   `registry.mbt`; `Viewer::register_tokenizer(language_id, lexer)`
   mirroring the provider registration API.
2. `render.mbt`: replace `@syntax.highlight(doc)` with registry lookup by
   `doc.language_id`, driver invocation, plain fallback on miss.
3. `workbench` and `examples/embedded_viewer` register
   `syntax/lang_moonbit` at startup (the embedded example is the proof that
   highlighting needs no server).
4. `app/src/style.css`: add rules for the new `tok-*` classes; keep `sem-*`
   rules declared after so semantic colors still win.
5. Browser specs: existing specs stay green; add one asserting a
   MoonBit-specific class (e.g. `tok-type` on a capitalized identifier in
   the fixture) and one asserting plain fallback for an unregistered
   language.

Validation: `just check`, `just test`, `just test-browser`.

## Phase 4 — More Languages

1. Add `syntax/lang_json` (trivial state machine) and one C-like language
   (`syntax/lang_javascript` or `lang_c`) ported by hand from the Monarch /
   legacy-modes references, to prove the registry with multiple languages
   and the keyword-cases idiom reuse.
2. Translation playbook documented in `syntax/README.md`: longest-match by
   default; Monarch rule-order conflicts -> `with first`; lookahead ->
   peek on `rest` before emitting; case-insensitive keywords -> `(?i:...)`;
   dynamic delimiters (heredocs) -> hand scanner code on `rest`.
3. A scripted Monarch-grammar-to-MoonBit translator is explicitly out of
   scope for this plan (the corpus lives in the external monaco-editor
   repo); revisit as a follow-up plan if hand-porting becomes the
   bottleneck.

Validation: golden tests per language; `just test-browser` unchanged.

## Phase 5 — Docs and Enforcement

1. `scripts/check-architecture.mbtx`: `syntax/lang_*` may import only
   `core` and `syntax`; `renderer/browser`, `renderer`, and `server` must
   not import `syntax/lang_*`; only `workbench` and `examples/*` may.
2. Update `syntax/README.md` (contracts, registry, translation playbook),
   `renderer/browser/README.md` (tokenizer registration in the embedding
   API), `docs/architecture.md` (package map + dependency rules + the
   compile-time-grammar decision), `docs/references/monaco.md` (add
   `tokenizationRegistry.ts`, `languages.ts` tokenization section, monarch
   directory notes).

Validation: `just check` (including architecture check), full suite green.

## Cross-Cutting Decisions

- Grammars are compile-time code, not runtime data. Adding a language means
  importing a package (or implementing `LineTokenizer` yourself); there is
  deliberately no dynamic registration of grammar files.
- Whole-document tokenization is retained for now (readonly; watch updates
  re-tokenize the document). Per-line entry states are recorded by the
  driver from day one so a future windowed/incremental pass is a driver
  change, not a contract change.
- `syntax` stays free of global state; the singleton registry `Ref` lives
  in `renderer/browser` per the existing module-`Ref` rule.
- Every `lexmatch` writes its strategy explicitly (`with longest` for token
  rules unless Monarch rule-order semantics are needed, then `with first`).
- `@syntax.Token` keeps its current shape for `build_frame`; dropping its
  redundant `text` field (the renderer slices `doc.text` itself) is an
  optional follow-up cleanup, not part of this plan.
- Semantic tokens remain the accuracy tier: no change to
  `overlay_semantic_tokens`, provider traits, or protocol packets.

## Exit Criteria

- MoonBit fixtures render with the lexmatch-based lexer (visibly richer
  classes: types, operators, doc comments); unregistered languages fall
  back to plain; semantic overlays still win where present.
- `examples/embedded_viewer` shows real highlighting with no server.
- At least three languages exist as `syntax/lang_*` packages; import rules
  enforced by the architecture check.
- `just check`, `just test`, `just test-browser` green; docs updated; this
  plan marked implemented with date.
