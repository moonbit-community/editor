// The editor-side half of `vscode/src/vs/workbench/contrib/scm/browser/
// quickDiffDecorator.ts` (checked-in vscode submodule): what
// `QuickDiffDecorator` does with its `codeEditor` — own a decorations
// collection and refill it from the quick-diff changes. Per the
// foreign-method rule the `Viewer`-touching body lives here as `Viewer::`
// glue; the pure pieces (change computation, decoration construction) live
// in `viewer/contrib/quick_diff/` and are called from this file.

///|
/// Recomputes the quick-diff gutter decorations for the current model. The
/// source splits this across `QuickDiffModel`'s throttled recompute and
/// `QuickDiffDecorator.onDidChange`; the viewer's models are immutable and
/// the service stores one original per resource, so both collapse into one
/// synchronous pass: no model, or no stored original for it, clears the
/// collection (the decorator disposal path upstream).
fn Viewer::quick_diff_update(
  self : Viewer,
  collection : EditorDecorationsCollection,
) -> Unit {
  match self.get_model() {
    Some(model) =>
      match self.services.quick_diff.get_original_content(model.uri) {
        Some(original) => {
          let changes = @quick_diff_browser.compute_changes(
            @base_common.split_lines(original),
            model.get_lines_content(),
          )
          collection.set(@quick_diff_browser.changes_to_decorations(changes))
          |> ignore
        }
        None => collection.set([]) |> ignore
      }
    None => collection.set([]) |> ignore
  }
}
