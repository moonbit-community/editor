# internal/shell/widgets/file_tree

Explorer-style workspace tree widget for the internal reference shell: the
`workbench/contrib/files` explorer role. It is not part of the public viewer
API.

## Behavior (the explorer contract)

- Owns a tree of `@workspace.WorkspaceStat` nodes plus per-node expansion
  state (the `ExplorerItem`/`AsyncDataTree` role).
- Directories render collapsed by default. Expanding a directory with
  unresolved children calls `provider.resolve(uri)` for exactly one level
  and caches the result on the node; cached levels expand for free.
- A failed resolve renders the folder as an empty-with-error row
  (`resolve-failed`) and is retried on the next expand.
- `set_active(uri)` is `autoReveal`: it resolves and expands the ancestor
  chain of the URI (derived from its root-relative path segments) and
  marks the node selected.
- `refresh()` re-resolves from the provider's root, replacing every cached
  node; the host calls it on (re)connect. The active file is re-revealed
  in the fresh tree.
- Opening files is an intent reported through `on_open`; the widget never
  opens documents itself (`IEditorService.openEditor` stays with the
  host).

## API

- `FileTree::FileTree(provider, on_open~)` with a
  `&@workspace.WorkspaceTreeProvider`.
- `view()` embeds the tree as a Rabbita child cell (keep it mounted).
- `refresh()` / `set_active(uri)` return commands for the host's update.

## DOM vocabulary

Rows keep the explorer selectors: `workspace-item`,
`workspace-folder`/`workspace-file`, `is-selected`, `data-workspace-id`
(holding the full URI), `data-workspace-kind`, `aria-expanded`,
`aria-selected`, `--depth` computed from tree depth, and indent guides.

## Boundaries

- May depend on internal shell `workspace` and Rabbita html/cmd/svg.
- Must not import `remote_protocol` or `viewer` — enforced by
  `scripts/check-architecture.mbtx`.

## Checks

- Expansion, reveal, and resolve-caching logic is unit-tested with an
  in-memory `WorkspaceTreeProvider` in `tree_state_wbtest.mbt`.
- Run `moon test internal/shell/widgets/file_tree --target js`.
