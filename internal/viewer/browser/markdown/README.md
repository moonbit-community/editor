# internal/viewer/browser/markdown

JS-only DOM and lifetime ownership for shared Markdown rendering.

`render_markdown` converts through `internal/viewer/markdown`, postprocesses the
result in an inert template, and then replaces the children of an explicit
reusable target (or a newly created `div`). Links and images are resolved and
sanitized before insertion. Action-handler links never retain native
navigation; native links are limited to HTTP, HTTPS, and mailto. Images are
removed by default and, when enabled, are limited to HTTP(S).

The returned `RenderedMarkdown.dispose` removes all listeners and makes late
load callbacks inert. Rendering into the same explicit target first disposes
the target's previous renderer-owned lifetime, while leaving the caller-owned
target itself in place.

Run the focused JS suite with:

```sh
moon test internal/viewer/browser/markdown --target js
```
