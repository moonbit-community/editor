# viewer/common/model

Immutable text snapshots, readonly editor models, guides, and mutable model
decorations. This is the viewer's reduced `vs/editor/common/model` boundary.

## Text and identity

- `TextSnapshot` normalizes every input `\r\n` pair, lone `\r`, or `\n` to one
  `\n` before storage, then derives line starts from that normalized text.
  U+FEFF is ordinary content, U+2028/U+2029 are not line breaks, and every
  other UTF-16 unit (including lone surrogates) is retained exactly once.
  `get_value`, lengths, ranges, offsets, positions, provider boundaries, and
  content events therefore all use one coherent UTF-16 coordinate system.
- Snapshots and models expose fixed `get_eol() == "\n"` and recompute
  `might_contain_non_basic_ascii` from complete stored text. There is no
  TextDefined/CRLF read preference, BOM-preservation switch, or cached builder
  metadata that can disagree with the text.
- `TextModel` adds URI, display name, language id, caller-owned host version,
  revision, lifecycle, and a `TokenizationTextModelPart`. Reads,
  position/offset conversion, range validation, and word lookup delegate to the
  current snapshot.
- Model-scoped async freshness uses physical `TextModel` identity plus the
  internal `get_version_id()` counter. URI, host version, revision, and
  decoration IDs are metadata and cannot substitute for that authority.
- `set_value` normalizes and replaces the complete snapshot in the same model,
  increments the internal version once, destroys old decorations, and fires
  the content-flush event using the old normalized range/length and new
  normalized text/EOL. There is no incremental edit/undo/redo, EOL mutation or
  preference, IME, or attachment surface. Ranges are generally clamped where
  Monaco throws, and the snapshot remains readable after `TextModel::dispose`.

## Mutable model-side state

- `delta_decorations`/`change_decorations` and the range-query APIs store regular,
  overview-ruler, and injected-text decorations in augmented interval trees.
  Decoration, token, and dispose events are part of the public model surface.
- `GuidesTextModelPart` computes indentation guides over a snapshot.
- `RangePriorityQueueImpl` is a conformance port from `textModelTokens.ts`; the
  readonly viewer has no background tokenizer that consumes it.

## Monaco map and boundary

Use the pinned `vscode/src/vs/editor/common/model/textModel.ts`,
`common/model.ts` (`IReadonlyTextBuffer`),
`model/pieceTreeTextBuffer/pieceTreeBase.ts` (`StringBuffer`/line starts),
`model/intervalTree.ts`, `model/guidesTextModelPart.ts`, and
`model/textModelTokens.ts`. The piece tree above its immutable leaf and all edit
machinery are deliberately N-A.

Production dependencies are only `base/common` and `viewer/common/model/tokens`;
the package must not import language providers, view/view-model, DOM, workspace,
server, or host effects. See `pkg.generated.mbti` for the exhaustive API and run
`moon test --target js viewer/common/model`.
