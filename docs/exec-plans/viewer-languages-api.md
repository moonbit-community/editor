# Viewer Languages API

Status: implemented (2026-06-18)
Date: 2026-06-18

Implementation note (2026-06-18): active code and current package docs now use
`@viewer.languages.*` and isolated `Languages` registries. References below to
`@viewer.register_tokenizer` and `services.language_features.*` describe the
pre-implementation state or migration notes.

## Summary

Move language capability registration behind a Monaco-shaped public
`@viewer.languages.*` API.

The current post-rename viewer API still exposes two different seams:

- tokenizers are registered through process-wide `@viewer.register_tokenizer`;
- semantic providers are registered through
  `services.language_features.register_*`.

That makes embedders learn an implementation service object before they can add
normal language behavior. Monaco's public API is clearer: language features are
registered through `monaco.languages.*`, while services remain internal. This
viewer should follow that shape while keeping the implementation MoonBit-owned.

Target public usage:

```moonbit
@viewer.languages.set_tokens_provider(
  "moonbit",
  @lang_moonbit.MoonbitTokenizer::new(),
)

@viewer.languages.register_hover_provider(selector, hover_provider)
@viewer.languages.register_diagnostics_provider(selector, diagnostics_provider)
@viewer.languages.register_document_symbol_provider(selector, symbol_provider)
@viewer.languages.register_document_semantic_tokens_provider(
  selector,
  semantic_tokens_provider,
)
@viewer.languages.register_folding_range_provider(selector, folding_provider)
@viewer.languages.register_inlay_hints_provider(selector, inlay_hints_provider)
```

The spelling has been compile-checked in this repo: a public package value can
be called as `@viewer.languages.register_hover_provider(...)` when the value's
type owns the method.

## Goals

- Make `@viewer.languages.*` the normal public registration API.
- Put tokenization and semantic language providers under one language facade.
- Keep `language` as the backend-neutral package that owns provider traits and
  payload types.
- Keep `syntax` and `syntax/lang_*` as tokenizer contracts and concrete lexer
  packages.
- Keep `ViewerServices` as an advanced composition hook for tests, isolated
  viewers, logging, markers, hover participants, and other viewer services.
- Allow embedders to use the global default language registry or create an
  isolated registry for a specific viewer.
- Return `Disposable` from every public registration, including token providers.

## Non-Goals

- Do not make the viewer editable.
- Do not add Monaco dependency injection, command services, extension host,
  contribution system, or mutable text model APIs.
- Do not move provider trait ownership from `language` into `viewer`.
- Do not move concrete tokenizer packages into `viewer`.
- Do not add a `viewer/languages` subpackage for this API. The verified target
  spelling is a public value on the `viewer` package.
- Do not keep `@viewer.register_tokenizer` as the documented API. Migrate
  current callers.
- Do not implement Monaco's full `languages.register`, `getLanguages`,
  language configuration, Monarch grammar loading, or on-language events in
  this plan.

## Target API

Add a public registry object owned by the `viewer` package:

```moonbit
pub(all) struct Languages { ... }

pub fn Languages::new() -> Languages

pub let languages : Languages = Languages::new()
```

Tokenization:

```moonbit
pub fn Languages::set_tokens_provider(
  self : Languages,
  language_id : String,
  tokenizer : &@syntax.LineTokenizer,
) -> @base_common.Disposable

fn Languages::lookup_tokens_provider(
  self : Languages,
  language_id : String,
) -> &@syntax.LineTokenizer?
```

Semantic provider registration:

```moonbit
pub fn Languages::register_hover_provider(
  self : Languages,
  selector : @language.LanguageSelector,
  provider : &@language.HoverProvider,
) -> @base_common.Disposable

pub fn Languages::register_diagnostics_provider(...)
pub fn Languages::register_document_symbol_provider(...)
pub fn Languages::register_document_semantic_tokens_provider(...)
pub fn Languages::register_folding_range_provider(...)
pub fn Languages::register_inlay_hints_provider(...)
```

The exact provider trait names and payload types remain in `language`. The
viewer package may re-export selected public language and syntax types later for
ergonomics, but that is not required for this API migration.

## Registry Semantics

`set_tokens_provider` should behave like Monaco's `setTokensProvider`:

- one active token provider per language id;
- later calls replace earlier providers for that language id;
- the returned `Disposable` only removes the provider if it is still the active
  registration for that language id;
- disposing an older registration must not remove a newer replacement.

Provider registrations remain ordered multi-provider registries:

- `register_*_provider` appends the provider to that feature's registry;
- disposed providers are skipped and eventually removed from the registry;
- hover keeps the current first-non-empty answer behavior;
- diagnostics keep per-provider owner replacement behavior;
- document symbols, semantic tokens, folding ranges, and inlay hints preserve
  their current collection semantics.

## Viewer Services Integration

`Languages` is the public registry. `ViewerServices` is the advanced dependency
bundle that chooses which registry a viewer uses.

Target constructor shape:

```moonbit
pub fn ViewerServices::new(
  languages? : Languages = languages,
  log_service? : @log.LogService = @log.LogService::new(),
) -> ViewerServices
```

`ViewerServices` should store the selected language registry:

```moonbit
pub(all) struct ViewerServices {
  languages : Languages
  markers : MarkerService
  marker_decorations : MarkerDecorationsService
  hover_participants : HoverParticipantRegistry
  log_service : @log.LogService
}
```

The existing `LanguageFeaturesService` should stop being the user-facing
registration object. It can either be removed or reduced to a private execution
adapter that combines:

- a `Languages` registry;
- the viewer's `LogService`;
- the existing async collection methods such as `hover_at`,
  `diagnostics_for_document`, `semantic_tokens_for_document`,
  `folding_ranges_for_document`, and `inlay_hints_for_document`.

The final active code should not register providers through
`services.language_features.register_*`.

## Default And Isolated Usage

Default embedder usage should be concise:

```moonbit
@viewer.languages.set_tokens_provider("moonbit", tokenizer)
@viewer.languages.register_hover_provider(selector, hover_provider)

let viewer = @viewer.Viewer::create(host, document_provider)
```

Advanced usage should allow isolation:

```moonbit
let languages = @viewer.Languages::new()
languages.set_tokens_provider("moonbit", tokenizer) |> ignore
languages.register_hover_provider(selector, hover_provider) |> ignore

let services = @viewer.ViewerServices::new(languages~)
let viewer = @viewer.Viewer::create(host, document_provider, services~)
```

The workbench may choose either style. Prefer registering workbench-specific
remote providers on `services.languages` so tests and future embedded viewers
can isolate provider state when needed. The embedded viewer example should use
`@viewer.languages.*` so the public docs show the simple path.

## Implementation Plan

### Phase 0: Baseline And API Inventory

1. Confirm the working tree is clean or record unrelated user changes.
2. Inventory current registration call sites:

   ```sh
   rg -n 'register_tokenizer|language_features\.register_|LanguageFeaturesService' \
     viewer workbench examples docs tests --glob '*.mbt' --glob '*.md'
   ```

3. Re-run the syntax probe only if the compiler version changes: create a
   temporary public `viewer.languages` value and check that
   `@viewer.languages.register_hover_provider(...)` compiles from another
   package. Remove the probe before committing.

Validation: no product changes yet.

### Phase 1: Introduce `Languages`

1. Add `viewer/languages.mbt`.
2. Move the tokenization registry state out of `viewer/registry.mbt` into
   `Languages`.
3. Move provider registry ownership out of user-facing
   `LanguageFeaturesService` into `Languages`.
4. Add the global default:

   ```moonbit
   pub let languages : Languages = Languages::new()
   ```

5. Implement all public registration methods on `Languages`.
6. Make `set_tokens_provider` return a `Disposable` with replacement-safe
   disposal semantics.

Validation:

```sh
moon check --target js viewer
moon test --target js viewer
```

### Phase 2: Rewire Viewer Feature Resolution

1. Change `ViewerServices::new` to accept `languages?`.
2. Store the selected `Languages` registry in `ViewerServices`.
3. Update tokenization lookup during render to use
   `self.services.languages.lookup_tokens_provider(...)`.
4. Update hover and document feature collection to resolve providers through the
   selected `Languages` registry.
5. Keep failure logging in the viewer/service layer so one bad provider still
   degrades to an empty result.
6. Remove or privatize the old registration methods on
   `LanguageFeaturesService` once all callers have migrated.

Validation:

```sh
moon check --target js viewer
moon test --target js viewer
```

### Phase 3: Migrate Workbench And Embedded Viewer

1. Replace `@viewer.register_tokenizer(...)` with
   `@viewer.languages.set_tokens_provider(...)` or
   `services.languages.set_tokens_provider(...)`.
2. Replace `services.language_features.register_*_provider(...)` with
   `services.languages.register_*_provider(...)`.
3. Update `workbench/language_client.mbt`,
   `workbench/hover_fixture.mbt`, `workbench/app.mbt`, and
   `examples/embedded_viewer/main.mbt`.
4. Dispose registration handles where the existing lifetime has a natural owner.
   If startup registrations intentionally live for the process lifetime, bind
   them to `_` or pipe to `ignore` explicitly.

Validation:

```sh
moon check --target js workbench examples/embedded_viewer
moon test --target js workbench examples/embedded_viewer
```

### Phase 4: Update Docs And Public Examples

1. Update `viewer/README.md` to introduce `@viewer.languages.*` before
   `ViewerServices`.
2. Update `docs/architecture.md` so language registration is described as a
   viewer API, while provider traits remain in `language`.
3. Update `docs/references/monaco.md` to map `monaco.languages.*` to
   `@viewer.languages.*`.
4. Update implemented-plan references only by adding dated superseding notes
   where appropriate. Do not rewrite old implemented plan goals.
5. Update examples and comments that still teach `@viewer.register_tokenizer`
   or `services.language_features.register_*`.

Validation:

```sh
rg -n '@viewer\.register_tokenizer|language_features\.register_|register_tokenizer' \
  viewer workbench examples docs tests --glob '*.mbt' --glob '*.md'
```

Expected result: no active docs or code teach the old public API. Historical
exec-plan references are acceptable only when they clearly describe old state.

### Phase 5: Public Interface And Browser Validation

1. Run formatting and interface generation:

   ```sh
   moon fmt
   moon info
   ```

2. Review generated `.mbti` changes. Expected public API changes:
   - new `Languages` type;
   - new `languages` value;
   - new `Languages::*` registration methods;
   - `ViewerServices::new(languages?, log_service?)`;
   - removal or demotion of old public registration methods if the
     implementation chooses no compatibility shim.
3. Run repository checks:

   ```sh
   just check
   just test
   just test-browser
   ```

4. Browser-smoke the reference workbench and embedded viewer:
   - MoonBit highlighting works through `set_tokens_provider`;
   - hover resolves through `register_hover_provider`;
   - diagnostics, symbols, semantic tokens, folding, and inlay hints still
     render when registered.

## Tests To Add Or Update

- Add viewer package tests for `Languages::set_tokens_provider` replacement and
  disposal behavior.
- Add viewer package tests for provider registration disposal preserving order.
- Add a compile-facing test or example assertion that uses the exact public
  spelling `@viewer.languages.register_hover_provider(...)`.
- Update existing service tests to use `Languages::new()` for isolated
  registries instead of directly constructing `LanguageFeaturesService`.
- Keep browser tests focused on visible behavior, not the registry internals.

## Migration Notes

Old:

```moonbit
@viewer.register_tokenizer("moonbit", tokenizer)
services.language_features.register_hover_provider(selector, provider)
```

New:

```moonbit
@viewer.languages.set_tokens_provider("moonbit", tokenizer)
@viewer.languages.register_hover_provider(selector, provider)
```

For isolated viewers:

```moonbit
let languages = @viewer.Languages::new()
languages.set_tokens_provider("moonbit", tokenizer) |> ignore
languages.register_hover_provider(selector, provider) |> ignore
let services = @viewer.ViewerServices::new(languages~)
```

## Risks

- A global default registry is convenient but can leak state across tests.
  Tests should use `Languages::new()` and pass it through `ViewerServices`.
- Token provider disposal is easy to get wrong when a provider is replaced.
  The disposable must only clear the active registration it created.
- Moving provider registry ownership may create large generated-interface diffs.
  Review `.mbti` changes for accidental payload or trait moves.
- Workbench startup registrations are currently process-lifetime. The
  implementation should be explicit about intentionally ignored disposables.
- Documentation must not imply that `language` owns live viewer registries; it
  owns contracts, while `viewer.languages` owns runtime registration.

## Exit Criteria

- Normal embedders can register syntax highlighting and language providers
  through `@viewer.languages.*`.
- `@viewer.register_tokenizer` is no longer used by active code or current docs.
- Active code no longer registers providers through
  `services.language_features.register_*`.
- Isolated viewer tests can create `Languages::new()` and pass it through
  `ViewerServices::new(languages~)`.
- Token provider registrations return `Disposable` and dispose safely after
  replacement.
- `viewer/README.md` and `docs/architecture.md` document the new API.
- `moon info`, `just check`, `just test`, and `just test-browser` pass.
