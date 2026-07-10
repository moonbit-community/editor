// The quick-diff feature's registration — the role of
// `vscode/src/vs/workbench/contrib/scm/browser/quickDiff.contribution.ts`
// plus `QuickDiffWorkbenchController`'s editor tracking (vscode submodule
// commit 294fb350), reduced to the editor-contribution registry: the
// controller upstream watches the editor service and attaches a
// `QuickDiffDecorator` per (resource, editor); the viewer's registry
// already instantiates per editor, so the contribution body IS the
// decorator wiring. The controller's configuration surface
// (`scm.diffDecorations*`) is N-A (defaults are baked into
// `quick_diff.css`); the peek widget and its actions are not ported.

///|
fn register_quick_diff_contribution(
  registry : EditorContributionRegistry,
) -> Unit {
  registry.register_editor_contribution("quickDiff.decorator", Eager, viewer => {
    let collection = viewer.create_decorations_collection()
    let listeners : Array[@base_common.Disposable] = []
    // `QuickDiffWorkbenchController.onEditorsChanged` re-evaluates the
    // decorator when an editor's model changes.
    listeners.push(
      viewer.on_did_change_model(_ => viewer.quick_diff_update(collection)),
    )
    // `QuickDiffModel`'s recompute on modified-side content changes
    // (`onDidChangeContent` → `triggerDiff`): a `set_value` flush both
    // changes the diff input and destroys the collection's decorations, so
    // the decorator re-runs against the new snapshot.
    listeners.push(
      viewer.on_did_change_model_content(_ => {
        viewer.quick_diff_update(collection)
      }),
    )
    // `QuickDiffModel`'s recompute on quick-diff (provider/original) changes,
    // scoped to this editor's resource.
    listeners.push(
      viewer.services.quick_diff.on_did_change_original(resource => {
        match viewer.get_model() {
          Some(model) =>
            if model.uri.to_string() == resource.to_string() {
              viewer.quick_diff_update(collection)
            }
          None => ()
        }
      }),
    )
    viewer.quick_diff_update(collection)
    {
      id: "quickDiff.decorator",
      dispose: () => {
        collection.clear()
        for listener in listeners {
          listener.dispose()
        }
      },
    }
  })
}
