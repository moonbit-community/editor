# view

Compatibility DOM-neutral render model.

## Responsibilities

- Preserve the older render-model API while callers move to `viewer`.
- Combine snapshots, syntax tokens, decorations, and provider results into
  readonly line/span data.
- Serialize the compatibility model to JSON.

## Boundaries

- May depend on `base/common`, `viewer/model`, `decorations`, `language`,
  `syntax`, and JSON support.
- Must stay DOM-neutral and host-neutral.
- New rendering work should prefer `viewer` unless compatibility requires
  this package.

## Checks

- Package tests live in `render_model_test.mbt`.
- Run `just check` for the repository-level type check.
