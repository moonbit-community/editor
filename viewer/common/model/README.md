# viewer/common/model

Readonly editor text model, immutable text snapshots, and model decorations.
Mirrors Monaco's `editor/common/model`.

## Responsibilities

- Own `TextSnapshot`, the immutable text buffer with cached line starts,
  UTF-16 length, line text, slicing, and offset/position conversion.
- Own `TextModel`, the URI-bearing readonly editor model with display name,
  language id, version, revision, and snapshot identity.
- Own model decorations: interval-tree storage (a port of Monaco's
  `intervalTree.ts`) behind `TextModel::delta_decorations` and the
  range-query accessors, with `DeltaDecoration` / `ModelDecorationOptions` as
  the public shapes.
- Provide the current-document URI plus version comparison used by async
  feature freshness guards.

## Boundaries

- May depend on `base/common` for `Uri`, `Position`, `Range`, and clamping.
- Must not depend on workspace providers, language providers, syntax,
  viewer, DOM, server routing, or host effects.
- Does not expose edit, undo/redo, cursor, IME, or model event APIs.

## Checks

- Local tests plus `*_reference_test.mbt` / `*_reference_wbtest.mbt`
  conformance ports of Monaco's model and interval-tree suites.
- Run `moon test --target all viewer/common/model` for focused coverage.
