# syntax

Lexical highlighting for readonly source snapshots: Monaco's
tokenization architecture with the Monarch runtime replaced by
MoonBit's compile-time `lexmatch` lexer generator.

## Responsibilities

- Own the tokenization contracts: `HighlightTag` (stable `tok-*` CSS
  class names), `LineToken`, `TokenizerState`, and the `LineTokenizer`
  trait (Monaco's `ITokenizationSupport`/`IState` pair — line-at-a-time
  tokenization with an explicit carried state whose derived equality
  lets callers detect convergence).
- Own `TokenizerRegistry`, a plain value mapping language ids to
  tokenizers (Monaco's `TokenizationRegistry`). No global instance
  lives here; the embedding layer owns its singleton.
- Drive whole-document tokenization (`tokenize_document`): lines are
  fed through a `LineTokenizer` carrying state, line-local tokens
  convert to doc-offset `Token`s, and per-line entry states are
  recorded internally so a windowed/incremental pass later is a driver
  change, not a contract change.
- Provide the `PlainTokenizer` fallback (the generic lexer used when no
  language is registered) and `highlight()`, the registry-miss path.

## Language packages (`syntax/lang_*`)

One package per language, composed by import: `lang_moonbit`,
`lang_json`, `lang_javascript`. Grammars are compile-time code — every
rule set is a `lexmatch` compiled to a tagged DFA at build time; there
is deliberately no runtime grammar loading (no
`setMonarchTokensProvider` equivalent). Adding a language means
importing a package, or implementing `LineTokenizer` yourself.

Import rules (enforced by `scripts/check-architecture.mbtx`):
`syntax/lang_*` may import only `core` and `syntax`; only composition
layers (`workbench`, `examples/*`) may import `syntax/lang_*` —
`renderer`, `renderer/browser`, and `server` must not.

## Monarch-to-`lexmatch` translation playbook

Verified against moon 0.1.20260610. All offsets are UTF-16 code units
(the repo position convention); `lexmatch` is character-based and never
splits surrogate pairs.

- Write `with longest` (maximal munch) on every `lexmatch`. First-match
  semantics warn as deprecated even when written explicitly
  (`lexmatch_first_match`, warning 0076), and `with longest` rejects
  `if` guards — so Monarch rule-priority conflicts are resolved by rule
  order (equal-length matches tie-break to the earlier arm) or by
  adding a longer, more specific rule (see the `/**/` arm in
  `lang_javascript`).
- Monarch `@keywords` cases: bind the identifier (`"[a-z]+" as word`)
  and classify in the arm body with a `match` on the view. No `\b`
  boundary exists or is needed.
- Lookahead (`$1`-style or regex lookahead is unsupported): peek at the
  `rest` binder before choosing the tag — see `colon_follows` in
  `lang_json` for Monarch's property-name lookahead.
- Multi-line constructs (block comments, template literals): encode a
  mode stack into the `TokenizerState` string, one character per mode,
  and dispatch each step on the top mode.
- Case-insensitive keywords: `(?i:...)` scoped case-insensitivity.
- Dynamic delimiters (heredocs, Monarch `$S2` backreferences): not
  expressible as a DFA rule; hand-scan on `rest` and emit tokens
  directly.
- Pattern strings are raw regex literals (single-backslash escapes,
  validated at compile time), but `\{` inside them is parsed as string
  interpolation (unsupported) — write literal braces as classes:
  `[{]`, `[}]`. Escape `-` and `|` even inside classes (`\-`, `\|`).
  A single-character pattern binds a `Char`; multi-character patterns
  bind a `StringView`.
- Make progress unconditionally: end every rule set with a
  `(".", rest)` arm (one character, loses every longest-match tie) and
  the mandatory `_` catch-all (only reachable on empty input).
- A scripted Monarch-grammar translator is out of scope; languages are
  ported by hand from the Monaco `basic-languages` corpus or
  `codemirror/mode/` legacy stream modes.

## Boundaries

- `syntax` may depend only on `core`; `syntax/lang_*` only on `core`
  and `syntax`. No module-level state anywhere in this subtree.
- Must not depend on workspace loading, language providers, DOM,
  renderer backends, server packages, or reference submodules.
- Does not own semantic tokens or diagnostics; those belong to
  `language` and overlay on top of these tokens in the renderer.

## Checks

- Package tests: `highlight_test.mbt`, `tokenizer_test.mbt`,
  `driver_wbtest.mbt`, and golden token-stream tests in each
  `lang_*` package.
- Run `just check` for the repository-level type check.
