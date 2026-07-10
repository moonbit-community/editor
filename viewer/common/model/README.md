# viewer/common/model

Immutable text snapshots, readonly editor models, guides, and mutable model
decorations. This is the viewer's reduced `vs/editor/common/model` boundary.

## Text and identity

- `TextSnapshot` stores raw text plus line starts. It recognizes `\n`, lone `\r`,
  and `\r\n` as line breaks; line reads exclude the terminator, while `get_value`
  and `get_value_in_range` normalize returned line breaks to `\n`. Raw offset
  helpers and `get_length` still use the original UTF-16 text.
- `TextModel` adds URI, display name, language id, version, revision, lifecycle,
  and a `TokenizationTextModelPart`. Reads, position/offset conversion, range
  validation, and word lookup delegate to the snapshot.
- `same_identity_and_version` compares serialized URI plus model version;
  `revision` is host metadata, not part of that freshness guard.
- Content is never edited in place: a host installs new text as a new model.
  There is no edit/undo/redo, EOL option, IME, attachment, or content-change event.
  Ranges are generally clamped where Monaco throws, and the immutable snapshot
  remains readable after `TextModel::dispose`.

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
