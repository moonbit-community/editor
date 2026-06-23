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
- Provide `PlainTokenizer` and `highlight()` as explicit generic-lexer helpers.
  Viewer registry misses stay un-tokenized so the renderer uses plain/default
  text, matching Monaco's unknown-language behavior.

## Language packages (`syntax/lang_*`)

One package per language, composed by import: `lang_moonbit`,
`lang_json`, `lang_javascript`. Grammars are compile-time code — every
rule set is a `lexmatch` compiled to a tagged DFA at build time; there
is deliberately no runtime grammar loading (no
`setMonarchTokensProvider` equivalent). Adding a language means
importing a package, or implementing `LineTokenizer` yourself.

Import rules (enforced by `scripts/check-architecture.mbtx`):
`syntax/lang_*` may import only `syntax` plus `viewer/model` test support;
only composition layers (`internal/shell/workbench`,
`internal/shell/examples/*`, and browser test entrypoints) may import
`syntax/lang_*`; `viewer/common`, `viewer`, and backend policy packages must not.

## Monarch-to-`lexmatch` translation playbook

Verified against moon 0.1.20260610 and the compiler sources
(`lib/xml/typing/typer.ml`, `lib/xml/regex/` in the compiler repo). All
offsets are UTF-16 code units (the repo position convention);
`lexmatch` is character-based and never splits surrogate pairs.

- Write `with longest` (maximal munch) on every `lexmatch`. First-match
  semantics warn as deprecated even when written explicitly
  (`lexmatch_first_match`, warning 0076, on by default; the
  longest-match warning 0077 is off by default), and `with longest`
  rejects `if` guards and start-rest binders — so Monarch rule-priority
  conflicts are resolved by rule order (equal-length matches tie-break
  to the earliest arm: the TDFA keeps the smallest accept id) or by
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
  `[{]`, `[}]` (bare braces are rejected outside classes). Inside
  classes, bare `-` and `]` are rejected (`\-`, `\]`); `|` is literal.
  The escape set is strict: `\X` for an unlisted `X` is a compile
  error, not a literal `X`. A single-character pattern binds a `Char`;
  multi-character patterns bind a `StringView`.
- Make progress unconditionally: end every rule set with a
  `(".", rest)` arm (one character, loses every longest-match tie;
  `.` is the full charset including lone surrogates, so it cannot fail
  on non-empty input) and the mandatory `_` catch-all. The catch-all
  runs when no rule matches — have it consume the remaining view so
  the driver loop can never stall even if `.` semantics narrow.
- A scripted Monarch-grammar translator is out of scope; languages are
  ported by hand from the Monaco `basic-languages` corpus or
  `codemirror/mode/` legacy stream modes.

## Boundaries

- `syntax` may depend only on `base/common` and `viewer/model`;
  `syntax/lang_*` only on `syntax` plus `viewer/model` test support. No
  module-level state anywhere in this subtree.
- Must not depend on workspace loading, language providers, DOM,
  viewer backends, `internal/shell` packages, or reference submodules.
- Does not own semantic tokens or diagnostics; those belong to
  `language` and overlay on top of these tokens in the viewer.

## Checks

- Package tests: `highlight_test.mbt`, `tokenizer_test.mbt`,
  `driver_wbtest.mbt`, and golden token-stream tests in each
  `lang_*` package.
- Run `just check` for the repository-level type check.
