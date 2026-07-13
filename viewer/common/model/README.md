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
  revision, lifecycle, and a `TokenizationTextModelPart`. The token part borrows
  one live `TokenizationModelAccess` carrier, so content replacement, line
  counts, disposal state, and attached-view priority never come from a copied
  snapshot. Ordinary token reads are passive; explicit force, visible-range
  refresh, and bounded background work are the only lexer drivers. Reads,
  position/offset conversion, range validation, and word lookup delegate to the
  current snapshot.
- Model-scoped async freshness uses physical `TextModel` identity plus the
  internal `get_version_id()` counter. URI, host version, revision, and
  decoration IDs are metadata and cannot substitute for that authority.
- `set_value` normalizes and replaces the complete snapshot in the same model,
  increments the internal version once, destroys old decorations, and fires
  the content-flush event using the old normalized range/length and new
  normalized text/EOL. There is no incremental edit/undo/redo, EOL mutation or
  preference or IME. Internal `on_before_attached`/`on_before_detached` calls
  maintain exact attached-view handles and select the first available scheduler
  for an aggregate attached epoch; final detach cancels that epoch before the
  scheduler is cleared. The model-owned `on_did_change_attached` event fires
  after tokenization observes only the aggregate `0 -> 1` and `1 -> 0`
  transitions and is released with the model. Ranges are generally clamped
  where Monaco throws, and the snapshot remains readable after
  `TextModel::dispose`.

## Mutable model-side state

- `delta_decorations`/`change_decorations` and the range-query APIs store regular,
  overview-ruler, and injected-text decorations in augmented interval trees.
  Decoration, token, and dispose events are part of the public model surface.
- `GuidesTextModelPart` computes indentation guides over a snapshot.
- `RangePriorityQueueImpl` is the compatibility alias for the live queue owned
  by `viewer/common/model/tokens`. The tokenizer backend tracks invalid end
  states, prioritizes attached visible ranges, yields between bounded slices,
  and makes stale scheduled generations inert after detach or disposal.
- Model listener ownership includes the token part's external token listeners
  alongside the model's will-dispose, decoration, attached, and content
  emitters; options/line-height/font emitters remain N-A. Unexpected tokenizer
  failures are reported immediately through the package's host-neutral
  `println` seam, disable that support for the current reset, and leave the
  model live for a later reset.
- The constructor fixes the large-file tokenization decision at Monaco's
  strict `> 20 Mi` UTF-16-unit or `> 300K` line thresholds. Large models keep
  the projected view collection but return default tokens and schedule no
  background lexer work.

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
`moon test --target js viewer/common/model` and
`moon test --target native viewer/common/model`.
