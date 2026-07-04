// Port of the registration surface of
// `vscode/src/vs/editor/browser/editorExtensions.ts` (vscode submodule
// commit 294fb350837dbaee37b949533fead4df4e0e8971): the editor-contribution
// registry (`EditorContributionRegistry`, `registerEditorContribution`,
// `codeEditorContributions.ts`'s per-editor instantiation) and the
// command + keybinding registration (`Command.register` →
// `KeybindingsRegistry.registerKeybindingRule` + `CommandsRegistry`,
// `EditorCommand.runEditorCommand`).
//
// Structural deviation (deviations-closeout Track D, recorded up front):
// MoonBit's foreign-method rule keeps `Viewer::` glue in this root package
// and there is no DI/services collection to port, so the registry inverts
// *dispatch and lifecycle* (who instantiates contributions, who routes
// commands/keys) — not file placement. The `*_host.mbt` files stay here as
// the contribution ctors this registry instantiates, preconditions are live
// predicates over the `Viewer` instead of `ContextKeyExpression`s, and
// registration happens in one initializer (`build_editor_registry`) because
// MoonBit has no import-time side effects.

///|
/// `EditorContributionInstantiation` (`editorExtensions.ts:34-65`). The
/// readonly viewer has no idle scheduler, interaction tracker, or on-demand
/// `getContribution`, so every mode instantiates eagerly at `Viewer`
/// construction; the deferred modes exist so a registration can carry its
/// source's declared mode (folding is `Eager`, content hover
/// `BeforeFirstInteraction`, comments `AfterFirstRender`).
pub(all) enum EditorContributionInstantiation {
  Eager
  AfterFirstRender
  BeforeFirstInteraction
  Eventually
  Lazy
} derive(Eq, Debug)

///|
/// A live per-editor contribution instance — `IEditorContribution` reduced
/// to its lifecycle member (no view-state save/restore in the viewer).
pub(all) struct EditorContribution {
  id : String
  dispose : () -> Unit
}

///|
/// `IEditorContributionDescription` (`editorExtensions.ts:68-72`): id + ctor
/// closure, instantiated once per `Viewer`.
priv struct EditorContributionDescription {
  id : String
  instantiation : EditorContributionInstantiation
  ctor : (Viewer) -> EditorContribution
}

///|
/// `EditorCommand` (`editorExtensions.ts:104-183,270+`) reduced: id, the
/// precondition (`ContextKeyExpression` → live predicate over the viewer),
/// and the run body (`runEditorCommand` bound to the owning editor).
priv struct EditorCommand {
  id : String
  precondition : (Viewer) -> Bool
  run : (Viewer) -> Unit
}

///|
/// One keybinding rule (`KeybindingsRegistry.registerKeybindingRule` row):
/// a `KeyboardEvent.key` value plus the two modifier axes the viewer's
/// bindings use (`KeyMod.Alt`, `KeyMod.CtrlCmd`). The rule's `when` is the
/// command's precondition (`Command.register` ANDs `kbExpr` with the
/// precondition; the viewer's rules carry no extra `kbExpr`). Chords match
/// exactly: a rule with `alt=false` does not fire while Alt is held.
priv struct KeybindingRule {
  key : String
  alt : Bool
  ctrl_cmd : Bool
  command_id : String
}

///|
/// The process-wide registry singleton
/// (`EditorContributionRegistry.INSTANCE`).
priv struct EditorContributionRegistry {
  contributions : Array[EditorContributionDescription]
  commands : Map[String, EditorCommand]
  keybindings : Array[KeybindingRule]
}

///|
/// `registerEditorContribution` (`editorExtensions.ts:552-554`).
fn EditorContributionRegistry::register_editor_contribution(
  self : EditorContributionRegistry,
  id : String,
  instantiation : EditorContributionInstantiation,
  ctor : (Viewer) -> EditorContribution,
) -> Unit {
  self.contributions.push({ id, instantiation, ctor })
}

///|
/// `registerEditorCommand` + the keybinding rows of `Command.register`
/// (`editorExtensions.ts:528-531`, `:124-156`).
fn EditorContributionRegistry::register_editor_command(
  self : EditorContributionRegistry,
  id : String,
  precondition : (Viewer) -> Bool,
  run : (Viewer) -> Unit,
  keybindings : Array[(String, Bool, Bool)],
) -> Unit {
  let command : EditorCommand = { id, precondition, run }
  self.commands.set(command.id, command)
  for binding in keybindings {
    let (key, alt, ctrl_cmd) = binding
    self.keybindings.push({ key, alt, ctrl_cmd, command_id: id })
  }
}

///|
/// Per-editor instantiation (`codeEditorContributions.ts` over
/// `codeEditorWidget.ts:344`): every registered contribution is constructed
/// for this viewer, in registration order (= the hand-wiring construction
/// order the registry replaced), keyed by id like the source's `_instances`
/// map. Instances live until `Viewer::dispose`; `set_model` does not
/// re-create them, matching the source.
fn EditorContributionRegistry::instantiate_all(
  self : EditorContributionRegistry,
  viewer : Viewer,
) -> Map[String, EditorContribution] {
  let instances : Map[String, EditorContribution] = {}
  for description in self.contributions {
    // Every mode instantiates eagerly (no idle/interaction schedulers
    // exist); the declared mode is carried for source fidelity only.
    ignore(description.instantiation)
    instances.set(description.id, (description.ctor)(viewer))
  }
  instances
}

///|
/// The keybinding-service resolution step, reduced: exact chord match, then
/// the command's precondition, then run. Returns whether a command handled
/// the key (callers `preventDefault` on `true`).
fn EditorContributionRegistry::dispatch_keybinding(
  self : EditorContributionRegistry,
  viewer : Viewer,
  key : String,
  alt~ : Bool,
  ctrl_cmd~ : Bool,
) -> Bool {
  for rule in self.keybindings {
    if rule.key == key && rule.alt == alt && rule.ctrl_cmd == ctrl_cmd {
      match self.commands.get(rule.command_id) {
        Some(command) =>
          if (command.precondition)(viewer) {
            (command.run)(viewer)
            return true
          }
        None => ()
      }
    }
  }
  false
}

///|
priv struct EditorRegistryHolder {
  mut registry : EditorContributionRegistry?
}

///|
/// Backing cell for the singleton: built on first use rather than in a
/// global initializer — the registered ctor/run closures reach `Viewer`
/// methods whose dispatch consults the registry back, which MoonBit's
/// toplevel-definition cycle check would reject as an initializer cycle.
let editor_registry_holder : EditorRegistryHolder = { registry: None }

///|
/// The singleton (`EditorContributionRegistry.INSTANCE`), populated once.
/// Registration order preserves the construction order the hand-wiring had
/// (comments was the only constructor-time wiring; hover and folding
/// registrations follow their Monaco contribution files).
fn editor_registry() -> EditorContributionRegistry {
  match editor_registry_holder.registry {
    Some(registry) => registry
    None => {
      let registry : EditorContributionRegistry = {
        contributions: [],
        commands: {},
        keybindings: [],
      }
      register_agent_feedback_contribution(registry)
      register_hover_contribution(registry)
      register_folding_contribution(registry)
      editor_registry_holder.registry = Some(registry)
      registry
    }
  }
}
