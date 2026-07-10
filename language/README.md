# language

Backend-neutral contracts for readonly language features.

## Surface and behavior

- Result DTOs: `Hover`/`HoverContent`, `Diagnostic`, `Location`,
  `DocumentSymbol`, and `InlayHint`. Their `Position` and `Range` values use the
  repository's 1-based UTF-16 convention.
- Async provider traits: `HoverProvider`, `DefinitionProvider`,
  `ReferencesProvider`, `DocumentSymbolProvider`, and `InlayHintsProvider`.
  Providers receive a readonly `TextModel` and a cooperative
  `CancellationToken`.
- `LanguageSelector` matches by language id, filter, or selector list. Filters
  combine optional language, URI scheme, and path pattern checks. Pattern matching
  is deliberately simpler than Monaco scoring: it strips one leading `/` from the
  URI path and supports an exact match or one `*` prefix/suffix wildcard.

`Diagnostic` is only a shared data shape; diagnostics enter the viewer through
`viewer/common/markers`. There is currently no diagnostic-provider or
semantic-token contract. Definition and reference traits exist for host/protocol
use, but `viewer/common/languages` does not currently register them.

## Boundaries and Monaco map

This package depends only on `base/common` and `viewer/common/model`. It must not
import registries, DOM/browser code, transport, native hosts, servers, or
`internal/shell`. Hosts adapt wire/backend payloads before calling these traits.

The shapes follow the relevant interfaces in `vs/editor/common/languages.ts`; this
package is the contract layer, not Monaco's `LanguageFeaturesService`. See
`pkg.generated.mbti` for the complete API and run
`moon test --target js language` for focused coverage.
