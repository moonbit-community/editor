# internal/viewer/markdown

Multi-target safe Markdown-to-HTML conversion shared by browser features.

The package owns the cmark boundary. `MarkdownCodeBlock` is a MoonBit value,
so callers can synchronously replace fenced-code rendering without importing
cmark types. Every conversion uses the safe HTML renderer; a conversion error
falls back to one escaped plaintext paragraph. `MarkdownRenderFact` reports
whether the input contained a code block independently of whether a caller
overrode its HTML.

Browser DOM policy, URI rewriting, listeners, target reuse, and disposal live
in `internal/viewer/browser/markdown`.

Run the focused suite on both supported targets:

```sh
moon test internal/viewer/markdown --target js
moon test internal/viewer/markdown --target native
```
