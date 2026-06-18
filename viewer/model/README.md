# viewer/model

Readonly editor text model and immutable text snapshots.

## Responsibilities

- Own `TextSnapshot`, the immutable text buffer with cached line starts,
  UTF-16 length, line text, slicing, and offset/position conversion.
- Own `TextModel`, the URI-bearing readonly editor model with display name,
  language id, version, revision, and snapshot identity.
- Provide the current-document URI plus version comparison used by async feature
  freshness guards.

## Boundaries

- May depend on `base/common` for `Uri` and `viewer/core` for `Position`,
  `Range`, and clamping.
- Must not depend on workspace providers, language providers, syntax,
  viewer, DOM, server routing, or host effects.
- Does not expose edit, undo/redo, cursor, IME, or model event APIs.

## Checks

- Package tests live in `text_model_test.mbt`.
- Run `moon test viewer/model` for focused coverage.

