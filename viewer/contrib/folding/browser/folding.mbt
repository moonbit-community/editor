// Port of `vscode/src/vs/editor/contrib/folding/browser/folding.ts` (vscode
// submodule commit 294fb350837dbaee37b949533fead4df4e0e8971): the contracts
// other folding files consume — `RangeProvider`, `FoldingLimitReporter`,
// `SelectedLines`, `toSelectedLines` — and the `FoldingController`'s state.
//
// Structural deviation (the foreign-method rule, like the hover contrib):
// the controller's *state* lives here in a per-editor instance table, while
// the event-handler bodies that need the editor (`onModelChanged`,
// `onHiddenRangesChanges`, the mouse handlers, the actions) are `Viewer::`
// glue in the root package (`viewer/folding_host.mbt` /
// `viewer/folding_contribution.mbt`).
//
// Omissions: the syntax range provider (`SyntaxRangeProvider` — no folding
// range providers in the language registry yet), view-state save/restore
// (`FoldingStateMemento`), `foldingImportsByDefault` (needs provider kinds),
// and the update `Delayer`/debounce (the viewer computes synchronously).

///|
/// A source of folding regions — Monaco's `RangeProvider` (`folding.ts`).
/// The viewer computes synchronously, so `compute` takes no cancellation
/// token and returns no promise.
pub(open) trait RangeProvider {
  fn id(Self) -> String
  fn compute(Self) -> FoldingRegions
  fn dispose(Self) -> Unit
}

///|
/// Receives how many ranges a provider computed and whether the limit
/// truncated them — Monaco's `FoldingLimitReporter` (`folding.ts`). `update`
/// takes the computed count and the applied limit, `None` standing for the
/// source's `false` ("not limited").
pub(all) struct FoldingLimitReporter {
  limit : () -> Int
  update : (Int, Int?) -> Unit
}

///|
/// The selection probe `sanitizeAndMerge` consults to keep a shrunk region
/// expanded while the user is editing inside it — Monaco's `SelectedLines`
/// (`folding.ts`): whether any selection starts within the given inclusive
/// line range.
pub(all) struct SelectedLines {
  starts_inside : (Int, Int) -> Bool
}

///|
/// `toSelectedLines` (`folding.ts:591`).
pub fn to_selected_lines(selections : Array[@core.Selection]) -> SelectedLines {
  if selections.length() == 0 {
    return { starts_inside: (_start_line, _end_line) => false }
  }
  {
    starts_inside: (start_line, end_line) => {
      for s in selections {
        let line = s.start().line_number
        if line >= start_line && line <= end_line {
          return true
        }
      }
      false
    },
  }
}

///|
/// `FoldingController.ID` (`folding.ts:70`).
pub const FOLDING_CONTROLLER_ID : String = "editor.contrib.folding"

///|
/// The controller's `mouseDownInfo` (`folding.ts:112`).
pub(all) struct FoldingMouseDownInfo {
  line_number : Int
  icon_clicked : Bool
}

///|
/// The per-editor folding state — the fields of Monaco's `FoldingController`
/// (`folding.ts:68`). The editor-facing behavior lives in the root package's
/// `Viewer::` glue (see the header).
pub(all) struct FoldingController {
  mut folding_model : FoldingModel?
  mut hidden_range_model : HiddenRangeModel?
  mut folding_decoration_provider : FoldingDecorationProvider?
  mut range_provider : IndentRangeProvider?
  mut mouse_down_info : FoldingMouseDownInfo?
  /// The model-scoped subscriptions of `localToDispose`.
  local_to_dispose : Array[@base_common.Disposable]
}

///|
/// Per-editor controller instances keyed by the viewer's id — the instance
/// half of `registerEditorContribution` (the hover contrib's pattern).
let folding_instances : Map[String, FoldingController] = {}

///|
/// Creates and registers this editor's controller.
pub fn FoldingController::attach(editor_id : String) -> FoldingController {
  let controller : FoldingController = {
    folding_model: None,
    hidden_range_model: None,
    folding_decoration_provider: None,
    range_provider: None,
    mouse_down_info: None,
    local_to_dispose: [],
  }
  folding_instances[editor_id] = controller
  controller
}

///|
/// `FoldingController.get(editor)` (`folding.ts:72`).
pub fn FoldingController::get(editor_id : String) -> FoldingController? {
  folding_instances.get(editor_id)
}

///|
/// Drops this editor's controller.
pub fn FoldingController::detach(editor_id : String) -> Unit {
  folding_instances.remove(editor_id)
}

///|
/// Clears the model-scoped state — `localToDispose.clear()` plus the inline
/// dispose block of `onModelChanged` (`folding.ts:255-270`), in the store's
/// insertion order: the models first (the hidden-range model's dispose
/// fires an empty range set through the still-live listener, clearing the
/// editor's hidden areas), then the subscriptions.
pub fn FoldingController::clear_local(self : FoldingController) -> Unit {
  match self.folding_model {
    Some(folding_model) => folding_model.dispose()
    None => ()
  }
  self.folding_model = None
  match self.hidden_range_model {
    Some(hidden_range_model) => hidden_range_model.dispose()
    None => ()
  }
  self.hidden_range_model = None
  for disposable in self.local_to_dispose {
    disposable.dispose()
  }
  self.local_to_dispose.clear()
  match self.range_provider {
    Some(provider) => provider.dispose()
    None => ()
  }
  self.range_provider = None
  self.folding_decoration_provider = None
  self.mouse_down_info = None
}
