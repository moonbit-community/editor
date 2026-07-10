# syntax

Stateful lexical highlighting for readonly text. It keeps Monaco's line-tokenizer
architecture but replaces runtime Monarch grammars with MoonBit `lexmatch` code.

## Runtime contract

- `LineTokenizer::tokenize_line` receives one line plus `TokenizerState` and
  returns `LineToken[]` plus the state for the next line. Token offsets are UTF-16
  code units; gaps are rendered as plain text.
- `TokenizationRegistry` registers tokenizers by language id and emits changed
  language ids. Disposing a registration removes it only while it is still the
  active registration for that language.
- `tokenization_registry` is process-wide. `Languages::set_tokens_provider`
  forwards into it; `viewer/common/model/tokens` performs the state-threaded
  whole-document sweep and binary encoding.
- `PlainTokenizer` is an explicit stateless tokenizer, not an automatic fallback.
  A registry miss is encoded by the model tokenization part as one default token
  per line.

This maps to `ITokenizationSupport`, `IState`, and `TokenizationRegistry` in
`vs/editor/common/languages.ts` and `languages/tokenizationRegistry.ts`.

## Concrete lexers

`syntax/lang_moonbit`, `lang_json`, and `lang_javascript` each expose a tokenizer
implementing `LineTokenizer`. Concrete languages are selected by hosts, examples,
or tests; reusable viewer core packages must not import them. There is no runtime
grammar-loading or `setMonarchTokensProvider` equivalent.

When translating a Monarch or CodeMirror grammar:

- Use `lexmatch ... with longest`; equal-length matches choose the earliest arm.
  Longest-match arms do not support guards, so classify a bound identifier in the
  arm body and inspect the returned remainder for lookahead (for example
  `lang_json`'s `colon_follows`).
- Carry multiline modes in `TokenizerState`; use scoped `(?i:...)` for
  case-insensitive rules. Dynamic delimiters/backreferences require a small manual
  scan because a DFA cannot encode them.
- Regex literals use strict single-backslash escapes. Write literal braces as
  `[{]`/`[}]`; escape `-` and `]` inside classes. Single-character bindings are
  `Char`, longer bindings are `StringView`.
- Guarantee progress with a final `(".", rest)` arm and the mandatory catch-all;
  the catch-all must consume the remaining view. Never split a surrogate pair at
  an emitted token boundary.

## Boundaries and checks

`syntax` may depend only on `base/common`; each `syntax/lang_*` package may depend
only on `syntax`. It owns neither diagnostics nor semantic tokens; semantic-token
overlay is not implemented. The complete API is `pkg.generated.mbti`. Run
`moon test --target js syntax` plus the relevant `syntax/lang_*` package tests.
