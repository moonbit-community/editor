# Provider-First General LSP Plan

## Goal

Implement production LSP support without leaking LSP into the browser backend.
The editor should expose readonly language features through semantic provider
traits. The host server should hide the general LSP client/server lifecycle and
translate between semantic editor requests and a configured language server.

The first implementation step is architectural: remove the browser-visible LSP
transport as a product dependency. A production LSP client comes after that
server-owned provider boundary is in place.

## Target Shape

- `language` owns readonly feature types and provider traits:
  `HoverProvider`, `DefinitionProvider`, `DiagnosticsProvider`,
  `DocumentSymbolProvider`, and `SemanticTokensProvider`.
- `renderer/browser` or `web` implements browser-side provider adapters by
  sending semantic `remote_protocol` requests to the host server.
- `remote_protocol` carries editor-domain packets such as `Hover`,
  `Definition`, `Diagnostics`, `DocumentSymbols`, and `SemanticTokens`.
- `server` owns provider implementations for remote workspaces. Its
  LSP-backed providers call a server-private LSP client.
- `server_host_native` owns host effects: spawning a configured language server,
  stdio or socket framing, timers, process exit handling, and file access.
- The browser backend never sends raw LSP JSON-RPC and never knows whether a
  result came from LSP, a cache, static analysis, or a future provider.

This keeps LSP as an implementation detail of the host server.

## Current Architecture Issue

The current code exposes a browser LSP transport hook through
`globalThis.__readonlyEditorLspTransport`, and the Vite harness exposes a raw
browser-to-LSP bridge. That works as a prototype, but it puts LSP client
concerns in the browser path:

- browser code can issue raw LSP requests;
- browser tests fake LSP instead of semantic providers;
- `language` currently owns `LspClient` and `LspTransport`;
- `remote_protocol` can carry raw LSP packets as a normal path.

Those are the wrong dependencies for a readonly remote viewer. The production
architecture should make browser code talk only to editor-level provider
contracts.

## LSP Specification Source Of Truth

The LSP client's behavior is governed by the official Language Server Protocol
specification, not by VS Code's implementation and not by any specific language
server.

Before implementing the client, pin the target specification version and URL in
this plan or in `docs/architecture.md`. The default target should be a stable
official spec version. Draft or under-development versions may be used only when
the feature slice explicitly opts in.

Official spec references:

- Landing page: `https://microsoft.github.io/language-server-protocol/`
- Stable baseline candidate: `https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/`
- Current/draft candidate: `https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/`

The pinned specification is the source of truth for:

- base protocol framing and JSON-RPC message shapes;
- lifecycle messages: `initialize`, `initialized`, `shutdown`, and `exit`;
- request, response, notification, error, cancellation, and progress behavior;
- capability exchange and dynamic registration;
- text document synchronization;
- hover, definition, diagnostics, document symbols, semantic tokens, and other
  feature-specific params and result shapes;
- message ordering and stale-result handling rules.

VS Code references are only secondary guidance for practical client behavior
where the specification leaves room for implementation choices. Any intentional
deviation from the pinned specification must be recorded with a compatibility
reason and a test.

## VS Code Reference Points

Use the VS Code submodule as behavioral reference only:

- `vscode/extensions/css-language-features/client/src/cssClient.ts`
- `vscode/extensions/css-language-features/client/src/node/cssClientMain.ts`
- `vscode/extensions/css-language-features/client/src/browser/cssClientMain.ts`
- `vscode/extensions/json-language-features/client/src/jsonClient.ts`
- `vscode/extensions/markdown-language-features/src/client/client.ts`

Useful concepts to copy:

- explicit lifecycle: start, initialize, shutdown, stop;
- capability-driven feature enablement;
- document synchronization policy;
- request correlation, cancellation, timeout, and error handling;
- separate transport/process effects from feature provider logic.

Do not copy VS Code's browser language-client shape into this editor. In this
repo, the browser frontend should receive semantic provider results from the
host server, not run or expose the LSP client.

## Package Responsibilities

### `language`

Own backend-neutral provider contracts and result types:

- keep `Hover`, `Diagnostic`, `Location`, symbols, semantic tokens, and
  provider result types here;
- split the broad `LanguageProvider` surface into feature-specific provider
  traits where useful;
- keep deterministic demo providers for local tests and fixtures;
- remove browser/native transport concepts from the public language API once
  server-owned LSP support exists.

`language` must not import `server`, `server_host_native`, `renderer/browser`,
`dom`, or `web`.

### `remote_protocol`

Own semantic client/server packets:

- requests: `OpenDocument`, `WatchDocument`, `CloseDocument`, `Hover`,
  `Definition`, `DocumentSymbols`, `SemanticTokens`;
- responses/events: `DocumentLoaded`, `DocumentChanged`, `Diagnostics`,
  `HoverResult`, `DefinitionResult`, `DocumentSymbolsResult`,
  `SemanticTokensResult`, `Error`;
- carry URI, document version, offset/range, and request ID in editor terms;
- preserve structured provider errors.

Raw LSP packet forwarding should be removed from the normal browser path. If a
temporary debug packet remains during migration, it must be documented as
non-product behavior and deleted before accepting production LSP support.

### `renderer/browser` and `web`

Own browser-side provider adapters and UI wiring:

- adapt remote protocol requests into `language` provider trait
  implementations;
- keep JavaScript FFI in `dom` only;
- keep existing browser observability events stable, but make them semantic
  events such as `language:hover`, `language:definition`, and
  `language:diagnostics` or document any compatibility aliases;
- avoid any direct language-server process, raw LSP JSON-RPC, or `LspTransport`
  dependency.

### `server`

Own host-server language feature routing:

- resolve and cache readonly source documents;
- manage open/close/watch state;
- receive semantic remote protocol requests;
- dispatch requests to provider implementations;
- implement LSP-backed providers that call the hidden server LSP client;
- drop stale results by URI and document version before responding.

### `server_host_native`

Own native effects:

- spawn and supervise a configured language-server process;
- parse and write LSP transport frames;
- provide timers and cancellation hooks;
- surface process stderr, exit, and restart events to `server`;
- keep process effects outside `server` policy and outside `language`.

## Implementation Phases

1. Provider Contracts

   Update `language` around semantic feature providers:

   - define feature-specific provider traits for hover, definition,
     diagnostics, document symbols, and semantic tokens;
   - keep shared result types backend-neutral;
   - update `language/README.md` so it no longer claims ownership of host LSP
     transport as the target architecture;
   - keep existing `LspClient` temporarily if needed, but mark it as migration
     code rather than browser-facing architecture.

2. Semantic Remote Protocol

   Make remote protocol the browser/server language-feature boundary:

   - add or harden semantic packets for hover, definition, diagnostics,
     document symbols, and semantic tokens;
   - include URI, document version, and offset/range in requests;
   - return semantic `language` result payloads, not raw LSP responses;
   - add encode/decode tests for each packet and error case;
   - demote or remove raw `Lsp` packets from product flow.

3. Browser Remote Providers

   Replace browser LSP usage with semantic remote providers:

   - implement browser-side provider adapters that satisfy `language` traits by
     calling `remote_protocol`;
   - update `web` to use those providers for hover, definition, diagnostics,
     symbols, and semantic tokens;
   - remove dependence on `globalThis.__readonlyEditorLspTransport` from
     product browser wiring;
   - update Playwright tests to fake remote protocol provider responses instead
     of fake LSP transport responses.

4. Server Provider Router

   Route semantic language-feature requests in `server`:

   - map `readonly-remote://workspace/...` URIs to validated root-relative
     files;
   - ensure the source document is open/synced before feature requests;
   - dispatch hover and definition to provider traits;
   - publish diagnostics as semantic protocol events;
   - reject stale or unsafe requests with structured protocol errors.

5. Server-Owned General LSP Client

   Implement the production LSP client as a hidden, server-owned, general LSP
   abstraction:

   - explicit states: `Idle`, `Initializing`, `Ready`, `Failed`, `Stopping`,
     `Stopped`;
   - request table keyed by JSON-RPC ID, with method, URI, version,
     cancellation, and timeout metadata;
   - capability parsing from `initialize`;
   - full document sync first, with incremental sync only if it becomes
     necessary and server-supported;
   - `shutdown` and `exit`;
   - transport close/error handling that clears pending requests without
     corrupting open document state.

6. LSP Feature Conversion

   Convert LSP responses inside server-owned providers:

   - diagnostics: severity, message, source, code, tags, related information
     where the domain model supports them;
   - hover: strings, marked strings, markup content, arrays, empty results, and
     fallback ranges;
   - definition: `Location`, `Location[]`, `LocationLink[]`, external URIs, and
     target selection ranges;
   - document symbols: flat and hierarchical responses;
   - semantic tokens: legend handling and token array decoding into
     renderer-neutral semantic decorations.

7. Transport and Host Hardening

   Move real LSP transport hardening to `server_host_native`:

   - robust stdio frame parser for partial headers and batched messages;
   - socket transport support only if a concrete server integration needs it;
   - process stderr capture and structured error reporting;
   - request cancellation and timeout support;
   - process restart policy;
   - deterministic fake host for unit tests.

8. Remove Browser LSP Bridge

   Once semantic remote providers and server-owned LSP pass smoke tests:

   - remove product use of `globalThis.__readonlyEditorLspTransport`;
   - remove or rename `/__readonly_editor_lsp` so the harness exposes the host
     server protocol instead of raw LSP;
   - update `docs/harness.md` observability and setup commands;
   - ensure browser tests assert semantic provider behavior, not LSP transport
     details.

## Validation

Unit tests:

- `language` tests for provider traits, demo providers, and result conversion
  helpers that remain backend-neutral.
- `remote_protocol` tests for semantic feature packets and structured errors.
- `server` tests for semantic request routing, stale version rejection, provider
  dispatch, and hidden LSP-client error paths.
- `server_host_native` tests for unavailable process behavior and fake framed
  message transport.

Browser tests:

- fake remote protocol provider tests for diagnostics, hover, definition,
  document changes, errors, and stale versions;
- real host-server smoke test against a standards-compliant language server;
- remote URI smoke coverage for
  `readonly-remote://workspace/docs/fixtures/demo.mbt`.

Required checks:

```sh
just check
just test
just build
just test-browser
```

For large server/LSP slices, also run:

```sh
moon check --target all
moon build --target all
moon test language
moon test remote_protocol
moon test server
```

## Acceptance Criteria

- Browser product code has no direct LSP transport or raw JSON-RPC dependency.
- Language features are exposed through semantic provider traits in `language`.
- The browser backend implements providers by calling the host server through
  `remote_protocol`.
- The host server owns general LSP client lifecycle and language-server
  interaction.
- Hover, definition, diagnostics, document symbols, and semantic tokens are
  version-safe and capability-gated.
- Transport failures produce structured provider errors and do not crash
  rendering.
- No product package imports from `vscode/`, `codemirror/`, browser code from
  shared packages, or JavaScript FFI outside `dom`.
