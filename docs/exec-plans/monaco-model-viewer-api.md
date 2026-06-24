# Monaco Model Viewer API

Status: Proposed
Date: 2026-06-18

## Summary

Correct the public readonly viewer API so it follows Monaco's model boundary
instead of exposing workspace source payloads. Monaco editors are composed by
setting an `ITextModel` on an editor; language providers also receive the model.
This repo already has the matching readonly owner in `viewer/model.TextModel`
and `TextSnapshot`, but the checked-in viewer facade, viewer events, and
language provider traits still expose `workspace.DocumentSnapshot`.

The final public boundary should be:

- `workspace.DocumentSnapshot`: source-provider payload used by hosts such as
  `workbench`.
- `viewer/model.TextModel`: readonly editor model identity installed on the
  viewer and passed to semantic language providers.
- `viewer/model.TextSnapshot`: immutable text view used by tokenization,
  rendering, and pure line/range helpers.

This plan supersedes the document-boundary parts of
`document-snapshot-viewer-api.md` and `monaco-core-viewer-api-and-docs.md`.

## Problem

The living architecture now says `workspace` is a host/source-provider layer, but
the public API still leaks that layer:

- `viewer/moon.pkg` imports `moonbit-community/editor/workspace`.
- `Viewer::set_document`, `Viewer::current_document`, frame/render events, and
  internal freshness checks expose `@workspace.DocumentSnapshot`.
- `language/moon.pkg` imports `workspace`, and provider traits accept
  `@workspace.DocumentSnapshot`.
- `workbench` and `examples/embedded_viewer` are forced to pass source payloads
  directly into viewer APIs.

That is not Monaco-shaped. In Monaco, a workspace service may produce content,
but the editor and language APIs are model-based. The equivalent local mistake
is treating `DocumentSnapshot` as the editor model because it happened to have
URI, language, revision, and text fields.

## Target API

Use model terminology for the viewer facade:

```moonbit
let viewer = Viewer::create(host, options?)
let model = @model.TextModel(uri, display_name, language_id, version, revision, text)

viewer.set_model(model, view_state=PreserveAnchor)
viewer.get_model()
viewer.save_view_state()
viewer.restore_view_state(state)
viewer.clear_model()
viewer.update_options(options)
viewer.remeasure()
viewer.dispose()
```

Final public APIs should not keep `set_document` / `current_document` aliases as
compatibility shims. Migrate repo callers, tests, and docs in the same change.

Suggested concrete names:

- `Viewer::set_model(self, model : @model.TextModel, view_state? :
  ViewStatePolicy = PreserveAnchor) -> Unit`
- `Viewer::get_model(self) -> @model.TextModel?`
- `Viewer::current_model(self) -> CurrentModel?`
- `Viewer::save_view_state(self) -> ViewerViewState`
- `Viewer::restore_view_state(self, state : ViewerViewState) -> Unit`
- `Viewer::clear_model(self, view_state? : ViewStatePolicy = Reset) -> Unit`
- `Viewer::refresh_model_features(self) -> Unit`
- `Viewer::on_did_change_model(...)`, `on_did_build_frame(...)`,
  `on_did_render_model(...)`, and existing non-document events.

Event payloads should expose `TextModel` or model identity fields, not
`DocumentSnapshot`. For example:

```moonbit
pub(all) struct CurrentModel {
  uri : @base_common.Uri
  version : Int
  revision : String
  language_id : String
  display_name : String
  scroll_top : Double
  scroll_left : Double
}

pub(all) struct ViewerModelRenderedEvent {
  model : @model.TextModel
  line_count : Int
  rendered_lines : Int
  diagnostics : Array[@language.Diagnostic]
  patch_ms : Double
  fresh : Bool
}
```

## Language Provider Boundary

Move semantic providers to `TextModel`, matching Monaco's `ITextModel` provider
input. A provider usually needs URI, language id, version, and text access, so
`TextModel` is the safer public input than a bare `TextSnapshot`.

Target shape:

```moonbit
pub(open) trait HoverProvider {
  async fn provide_hover(
    Self,
    @model.TextModel,
    @base_common.Position,
    CancellationToken,
  ) -> Hover?
}

pub(open) trait DiagnosticsProvider {
  async fn provide_diagnostics(
    Self,
    @model.TextModel,
    CancellationToken,
  ) -> Array[Diagnostic]
}

pub fn LanguageSelector::matches(self, model : @model.TextModel) -> Bool
pub async fn collect_model_provider_result(..., model : @model.TextModel, ...)
```

Apply the same replacement to definition, references, document symbols,
semantic tokens, folding ranges, and inlay hints. Pure tokenizer contracts stay
snapshot-based through `viewer/model.TextSnapshot`.

## Workspace And Host Adapters

Keep `workspace` independent of viewer packages. Do not add a
`DocumentSnapshot::to_text_model` helper in `workspace`, because that would make
`workspace` depend on `viewer/model`.

Host packages perform the adaptation:

- `workbench` reads `workspace.DocumentSnapshot`, maps it to `TextModel`, and
  calls `viewer.set_model`.
- `examples/embedded_viewer` can skip `DocumentSnapshot` entirely for documents
  and create `TextModel` directly from its in-memory map.
- Any remote/provider revision string remains source metadata on `TextModel`.
  The model `version` is the freshness guard and should increment whenever the
  host installs new content for the same URI. Workbench can keep a small
  URI/revision-to-version tracker during the migration.

## Implementation Phases

### Phase 1: Tighten Model Construction

- Review `viewer/model.TextModel` fields and constructor docs so host authors
  understand `version` as the editor-model freshness guard and `revision` as
  optional source metadata.
- Add small model helper methods only if they remove duplicated host adapter
  code without importing `workspace` into `viewer/model`.
- Add focused tests for `TextModel` identity/version behavior if current tests do
  not cover the intended guard.

Exit criteria:

- `viewer/model` remains host-neutral and does not import `workspace`.
- The public model docs explain how hosts choose `version`.

### Phase 2: Migrate `language` To Models

- Replace `@workspace.DocumentSnapshot` with `@model.TextModel` in provider
  traits, selectors, folding/inlay provider contracts, and provider aggregation.
- Update `language/moon.pkg` to import `viewer/model` and remove `workspace`.
- Update language tests and generated `.mbti`.

Exit criteria:

- `language/moon.pkg` has no `workspace` import.
- `language/pkg.generated.mbti` has no `@workspace.DocumentSnapshot`.
- Provider selector tests cover language id, scheme, and pattern matching using
  `TextModel`.

### Phase 3: Migrate Viewer Facade And Events

- Rename the facade from document terminology to model terminology:
  `set_model`, `get_model` / `current_model`, `save_view_state`,
  `clear_model`, and `refresh_model_features`.
- Change viewer state, pending render payloads, freshness checks, frame events,
  render events, diagnostics events, hover participants, and registries to use
  `TextModel` / `TextSnapshot`.
- Remove `source_document` storage from `Viewer`; keep only model identity.
- Update render/cache code so tokenization and view-model construction consume
  `model.snapshot`.
- Update `viewer/moon.pkg` to remove `workspace`.

Exit criteria:

- `viewer/moon.pkg` has no `workspace` import.
- `rg -n "@workspace.DocumentSnapshot|DocumentSnapshot|set_document|current_document|on_did_render_document|on_did_open_document" viewer language`
  has no production API hits.
- Viewer events expose model identity, not source-provider payloads.

### Phase 4: Migrate Hosts And Examples

- Update `workbench` active-document flow to adapt source payloads to
  `TextModel`, then call `viewer.set_model`.
- Update watch refresh and auto-open flows to preserve current behavior while
  incrementing model versions correctly.
- Update `examples/embedded_viewer` to construct `TextModel` directly from
  in-memory documents.
- Update harness/browser observability names only where they describe public
  viewer lifecycle. If a harness event remains named `document` for historical
  browser compatibility, document it as harness vocabulary rather than viewer
  API vocabulary.

Exit criteria:

- Workbench and embedded viewer use the same public model API.
- Source-provider payloads are confined to host/provider packages.
- Existing open, scroll, hover, diagnostics, refresh, and file-switch behavior is
  unchanged.

### Phase 5: Guardrails And Docs

- Extend `scripts/check-architecture.mbtx` so `viewer/moon.pkg` and
  `language/moon.pkg` must not import `moonbit-community/editor/workspace`.
- Update `viewer/README.md`, `language/README.md`, `workbench/README.md`,
  `examples/embedded_viewer/README.md`, and `docs/architecture.md` after the API
  migration lands, removing the temporary implementation notes added before this
  plan.
- Regenerate or refresh generated package interfaces if the repo expects them to
  be checked in.

Exit criteria:

- `rg -n "temporary .*DocumentSnapshot|set_document|current_document|on_did_render_document" docs viewer/README.md language/README.md workbench/README.md examples/embedded_viewer/README.md`
  returns no stale target-architecture wording.
- Architecture checks reject future `viewer` or `language` dependencies on
  `workspace`.

## Validation

Run these after implementation:

```sh
moon check
moon test --target js language
moon test --target js viewer
moon test --target js workbench
moon test --target js examples/embedded_viewer
just check
just test
just test-browser
git diff --check
```

For the API boundary specifically, run:

```sh
rg -n "moonbit-community/editor/workspace" viewer/moon.pkg language/moon.pkg
rg -n "@workspace.DocumentSnapshot|DocumentSnapshot" viewer language
rg -n "set_document|current_document|on_did_render_document|on_did_open_document" viewer language workbench examples/embedded_viewer
```

The first two scans should be empty for `viewer` and `language`. The last scan
should be empty except for deliberately historical docs or migration notes that
are removed before closing the plan.
