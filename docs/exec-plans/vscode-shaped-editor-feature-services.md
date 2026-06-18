# VS Code-Shaped Editor Feature Services

Status: implemented in `17ae776`, with host startup log flag wiring deferred.
Date: 2026-06-16

Superseding note (2026-06-18): public language registration moved from
`LanguageFeaturesService` to `@viewer.languages.*` / `Languages`. The
`LanguageFeaturesService` examples in this historical plan describe the earlier
service split, not the current public API.

## Summary

Refactor the readonly viewer so language features, diagnostics, marker state,
hover composition, and logging follow the same architectural split as
VS Code/Monaco:

- language providers produce feature data;
- diagnostics are stored as markers;
- marker decorations attach diagnostics to rendered ranges;
- diagnostic hover is contributed by a marker hover participant;
- language hover is contributed by a markdown hover participant;
- provider and participant failures are logged through a runtime log service,
  not ignored or encoded as hover content.

This is a broad architecture refactor. Preserve the viewer's public readonly
behavior while changing the internal service shape.

Reference sources, used only as design references:

- `vscode/src/vs/editor/contrib/hover/browser/hoverContribution.ts`
- `vscode/src/vs/editor/contrib/hover/browser/markerHoverParticipant.ts`
- `vscode/src/vs/editor/contrib/hover/browser/markdownHoverParticipant.ts`
- `vscode/src/vs/platform/log/common/log.ts`
- `vscode/src/vs/platform/log/common/logService.ts`
- `vscode/test/automation/src/logger.ts`
- `vscode/test/smoke/src/main.ts`

## Target Architecture

Add explicit MoonBit services rather than a generic dependency-injection
container:

- `ViewerServices`: the object passed into `Viewer`, owning all feature-related
  services for that viewer instance.
- `LanguageFeaturesService`: owns ordered feature registries such as
  `LanguageFeatureRegistry[&HoverProvider]`.
- `MarkerService`: stores diagnostics as markers keyed by owner and document
  resource.
- `MarkerDecorationsService`: maps markers to render decorations and lets hover
  participants find markers from a hovered range.
- `HoverParticipantRegistry`: owns ordered hover participants.
- `ContentHoverComputer`: asks participants for hover parts and merges the
  result into the browser hover renderer's input model.
- `LogService`: runtime logging service passed through `ViewerServices`.

The intended shape is:

```moonbit
struct ViewerServices {
  language_features : LanguageFeaturesService
  markers : MarkerService
  marker_decorations : MarkerDecorationsService
  hover_participants : HoverParticipantRegistry
  log_service : @log.LogService
}

struct LanguageFeatureRegistry[T] {
  entries : Array[T]
}

struct LanguageFeaturesService {
  hover_provider : LanguageFeatureRegistry[&@language.HoverProvider]
  diagnostics_provider : LanguageFeatureRegistry[&@language.DiagnosticsProvider]
  document_symbol_provider : LanguageFeatureRegistry[&@language.DocumentSymbolProvider]
  semantic_tokens_provider : LanguageFeatureRegistry[&@language.SemanticTokensProvider]
  log_service : @log.LogService
}
```

Use `Viewer::Viewer(source, services? = ViewerServices::new(), ...)` so
embedders can keep a default path, while workbench and browser tests can install
real providers and logger sinks.

## Logging Model

Copy VS Code's split between runtime logging and smoke-test logging.

Runtime product code gets an FFI-free `platform/log` package:

```moonbit
pub(all) enum LogLevel {
  Off
  Trace
  Debug
  Info
  Warning
  Error
} derive(Eq, Debug)

pub(all) struct LogEntry {
  level : LogLevel
  category : String
  message : String
  details : Array[(String, String)]
}

pub(open) trait Logger {
  fn log(Self, LogEntry) -> Unit noraise
  fn flush(Self) -> Unit noraise
}
```

Required logger implementations:

- `NullLogger`: default no-op for unit tests and embedders.
- `MemoryLogger`: captures entries for assertions.
- `MultiplexLogger`: fans one entry to multiple loggers.
- `ConsoleLogger` or `HarnessLogger`: browser/workbench-side sink that bridges
  warning/error entries to the browser console or existing harness events.

Do not copy VS Code's full `ILoggerService` named-resource registry in this
refactor. The viewer only needs the `ILogService` level now. Add named logger
registration later if there is a concrete need for multiple user-visible log
files.

Provider dispatch must log before falling back:

```moonbit
match (provider.hover_at(document, offset) catch {
  _ => {
    self.log_service.warn(
      "language.hover",
      "hover provider failed",
      details=[
        ("document", document.uri.to_string()),
        ("version", document.version.to_string()),
        ("providerIndex", index.to_string()),
      ],
    )
    None
  }
}) {
  Some(hover) => ...
  None => ()
}
```

For generic checked errors, MoonBit cannot assume a printable error string. Log
structured operation context. When the boundary already has a structured error,
such as remote protocol errors, include the error code/message in `details`.

Smoke tests keep a separate Node/Playwright harness logger, matching VS Code's
`test/automation/src/logger.ts` approach:

- always write a runner log file;
- mirror to console only in verbose mode;
- wrap long async operations with start/end/duration/error logging;
- capture browser console, page errors, HTTP failures, screenshots, and traces
  as test artifacts.

Runtime logs and smoke logs meet at the host boundary:

- native/browser host accepts `logsPath` and `logLevel`;
- workbench installs a concrete logger sink;
- browser tests capture console output and existing `[readonly-editor]` events;
- provider failures should surface as logs and, for warning/error categories
  relevant to the harness, as existing `language:error` events.

Avoid duplicate error emission. Remote protocol providers currently emit
`language:error` directly; after this refactor they should log structured
protocol errors once, and the workbench logger sink should decide whether to
emit the harness event.

## Marker And Diagnostic Flow

Move diagnostics out of hover content.

- Keep diagnostics as provider output in `language`.
- Remove `HoverContent::Marker`.
- Add marker-owned data types, using language diagnostics as input:
  - marker owner, resource URI, range, severity, message, source/code when
    available;
  - marker read APIs filtered by owner/resource and optionally limited by count.
- Diagnostic providers write to `MarkerService`.
- `MarkerDecorationsService` turns markers into render decorations.
- Existing `Viewer::push_diagnostics` may remain temporarily as a compatibility
  wrapper, but it must populate `MarkerService`.

The render path should read marker decorations, not raw provider diagnostics.
This matches VS Code/Monaco's separation between marker data and editor marker
decorations.

## Hover Flow

Replace the current single hover-provider path with participants:

```moonbit
pub(all) enum HoverPart {
  MarkdownHover(
    range~ : @core.Range,
    contents~ : Array[@language.HoverContent],
    ordinal~ : Int
  )
  MarkerHover(range~ : @core.Range, marker~ : Marker)
  LoadingHover(range~ : @core.Range, message~ : String)
}

pub(open) trait HoverParticipant {
  fn ordinal(Self) -> Int noraise
  fn compute_sync(Self, HoverComputeContext) -> Array[HoverPart] noraise
  async fn compute_async(Self, HoverComputeContext) -> Array[HoverPart] noraise
}
```

Implement participants:

- `MarkerHoverParticipant`: synchronous; asks `MarkerDecorationsService` for
  markers at the hover target and returns `MarkerHover` parts.
- `MarkdownHoverParticipant`: asynchronous; calls registered hover providers
  through `LanguageFeaturesService` and returns `MarkdownHover` parts.

`ContentHoverComputer` should:

- run sync participants first so marker hover is immediately available;
- run async participants with stale-token/version checks;
- log participant/provider failures through `LogService`;
- merge parts by ordinal and range;
- preserve existing sticky hover, Escape, pointer, wheel, and copy behavior.

The browser renderer still owns markdown rendering, sanitization, DOM, CSS, and
scrolling.

## Implementation Steps

1. Add `platform/log`.
   - Add the package and update `moon.pkg` imports only where needed.
   - Keep it shared and FFI-free.
   - Add `NullLogger`, `MemoryLogger`, `MultiplexLogger`, `LogService`, and
     unit tests for level filtering and fanout.

2. Introduce viewer-owned services.
   - Add `ViewerServices::new`.
   - Move provider registries out of package-global state.
   - Keep package-level `register_*` functions temporarily as compatibility
     wrappers over the default workbench service only if needed for incremental
     migration; remove them before finishing if all call sites can be updated.

3. Add marker services.
   - Store markers by owner/resource.
   - Convert diagnostics provider results into marker updates.
   - Convert markers into render decorations.
   - Route `push_diagnostics` through marker updates.

4. Refactor hover to participants.
   - Add `HoverPart`, `HoverParticipant`, `HoverParticipantRegistry`, and
     `ContentHoverComputer`.
   - Move current language-hover provider behavior into
     `MarkdownHoverParticipant`.
   - Move diagnostic hover behavior into `MarkerHoverParticipant`.
   - Remove `HoverContent::Marker` and update hover rendering to render
     `MarkerHover` parts instead.

5. Wire workbench and embedders.
   - Construct `ViewerServices` in workbench startup.
   - Register the remote language client through `LanguageFeaturesService`.
   - Register syntax tokenizers through the service-owned tokenizer registry if
     this refactor moves tokenizers too; otherwise leave tokenization unchanged.
   - Install a logger sink that preserves existing browser observability events.
   - Update `examples/embedded_viewer` to pass explicit services or use
     defaults.

6. Update harness logging.
   - Add or update the JS/Playwright test logger to follow VS Code's
     `ConsoleLogger` plus `FileLogger` plus `MultiLogger` split.
   - Pass `logsPath` and `logLevel` to the native/browser host in test startup.
   - Capture browser console logs, page errors, request failures, screenshots,
     and traces as artifacts.
   - Document this in `docs/harness.md`.

7. Update docs and architecture guardrails.
   - Add `platform/log` to `docs/architecture.md`.
   - Update package READMEs for changed ownership.
   - Update `scripts/check-architecture.mbtx` so the new package is recognized
     and browser FFI still stays out of shared packages.

## MoonBit Constraints Verified

Temporary MoonBit probes confirmed:

- `LanguageFeatureRegistry[&Trait]` compiles.
- async trait-object provider dispatch compiles.
- async trait methods are implemented with `impl Trait for Type with fn ...`,
  matching current repo style.
- service constructors with optional defaults compile.
- mutable service fields only need `mut` when reassigning the field itself;
  `Array.push` does not require a mutable field.
- caught generic checked errors are not automatically printable, so log
  structured context unless the error boundary provides structured data.
- derive syntax is post-declaration: `} derive(Eq, Debug)`.

Use explicit struct fields or trailing commas in struct literals to avoid
`ambiguous_block` warnings.

## Test Plan

MoonBit unit tests:

- log level filtering, null logger, memory logger, multiplex logger;
- provider registry ordering and failure isolation;
- marker service owner/resource replace, filter, remove, and read limit;
- marker decorations from marker ranges and severities;
- hover computer merging marker and markdown parts;
- provider failure logs once and does not suppress marker hover;
- remote protocol error logs once and does not double-emit harness events.

Browser tests:

- diagnostics still render as squiggle/decorations;
- hovering a diagnostic range shows marker hover without any hover provider;
- language hover and marker hover coexist in stable order;
- a failing hover provider logs warning/error evidence while diagnostic hover
  still renders;
- existing `language:hover`, `language:diagnostics`, `language:error`,
  `moonbit:render`, `dom:mounted`, and `view:scroll` observability events remain
  stable.

Smoke/harness tests:

- runner log file is always written;
- verbose mode mirrors logs to console;
- browser console/page errors are captured;
- screenshots/traces are persisted on failure when enabled;
- `logsPath` and `logLevel` are honored by native/browser host startup.

Repository guardrails:

- `moon check --target all`
- targeted MoonBit tests for the changed packages
- relevant browser hover and diagnostics tests
- `just check`
- `git diff --check`

## Acceptance Criteria

- Diagnostics are no longer represented as `HoverContent`.
- Diagnostic hover is produced by `MarkerHoverParticipant`.
- Language hover is produced by `MarkdownHoverParticipant`.
- The viewer can be constructed with explicit `ViewerServices`.
- Provider failures are logged with operation/document/provider context.
- No provider or hover participant failure is silently swallowed.
- Workbench browser observability remains stable for automated diagnosis.
- Smoke logging follows VS Code's separate harness logger pattern.
- Shared logging code has no browser or native FFI.
- Product code still does not import from `vscode/` or `codemirror/`.
