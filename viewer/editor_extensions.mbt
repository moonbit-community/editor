// Port of the registration surface of
// `vscode/src/vs/editor/browser/editorExtensions.ts` (vscode submodule
// commit 294fb350837dbaee37b949533fead4df4e0e8971): the editor-contribution
// registry (`EditorContributionRegistry`, `registerEditorContribution`,
// `codeEditorContributions.ts`'s per-editor instantiation) and the
// command + keybinding registration (`Command.register` →
// `KeybindingsRegistry.registerKeybindingRule` + `CommandsRegistry`,
// `EditorCommand.runEditorCommand`).
//
// Structural deviation: MoonBit's foreign-method rule keeps `Viewer::` glue
// in this root package
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
/// source's declared mode (content hover is `BeforeFirstInteraction`,
/// comments `AfterFirstRender`).
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
/// `CoreEditorCommand<T>` (`coreCommands.ts:38-49`) with its abstract member
/// represented by a stored closure. `precondition=None` is the source's
/// `undefined`; keybinding `kbExpr` remains a separate rule predicate.
priv struct CoreEditorCommand {
  id : String
  precondition : ((Viewer) -> Bool)?
  default_args : CursorCoreCommandArgs
  run_core_editor_command : (
    Viewer,
    @view_model.ViewModel,
    CursorCoreCommandArgs,
  ) -> Bool
}

///|
/// The heterogeneous command table stores ordinary contribution commands and
/// typed cursor core commands under their real IDs.
priv enum RegisteredEditorCommand {
  RegisteredEditor(EditorCommand)
  RegisteredCore(CoreEditorCommand)
}

///|
/// One keybinding rule (`KeybindingsRegistry.registerKeybindingRule` row):
/// a `KeyboardEvent.key` value plus the three modifier axes the viewer's
/// bindings use (`KeyMod.Alt`, `KeyMod.CtrlCmd`, `KeyMod.Shift`). The
/// rule's `when` is the command's precondition (`Command.register` ANDs
/// `kbExpr` with the precondition; the viewer's rules carry no extra
/// `kbExpr`). Chords match exactly: a rule with `alt=false` does not fire
/// while Alt is held. Monaco matches layout-independent key codes; `key` is
/// layout-transformed, so a Shift rule for a punctuation key registers both
/// the base and the shifted character (synthetic events carry the base,
/// hardware events the shifted one).
priv struct KeybindingRule {
  key : String
  alt : Bool
  ctrl_cmd : Bool
  shift : Bool
  command_id : String
  when : (Viewer) -> Bool
}

///|
/// The process-wide registry singleton
/// (`EditorContributionRegistry.INSTANCE`).
priv struct EditorContributionRegistry {
  contributions : Array[EditorContributionDescription]
  commands : Map[String, RegisteredEditorCommand]
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
  shift_keybindings? : Array[(String, Bool, Bool)] = [],
) -> Unit {
  let command : EditorCommand = { id, precondition, run }
  self.commands.set(command.id, RegisteredEditor(command))
  for binding in keybindings {
    let (key, alt, ctrl_cmd) = binding
    self.keybindings.push({
      key,
      alt,
      ctrl_cmd,
      shift: false,
      command_id: id,
      when: precondition,
    })
  }
  for binding in shift_keybindings {
    let (key, alt, ctrl_cmd) = binding
    self.keybindings.push({
      key,
      alt,
      ctrl_cmd,
      shift: true,
      command_id: id,
      when: precondition,
    })
  }
}

///|
/// `registerEditorCommand` for one source-shaped cursor core command. Command
/// preconditions and keybinding context are intentionally independent: the
/// scoped commands have undefined preconditions while their 16 primary keys
/// retain the viewer's live text-input/model gate.
fn EditorContributionRegistry::register_core_editor_command(
  self : EditorContributionRegistry,
  command : CoreEditorCommand,
  keybinding_when : (Viewer) -> Bool,
  keybindings : Array[(String, Bool, Bool)],
  shift_keybindings? : Array[(String, Bool, Bool)] = [],
) -> Unit {
  self.commands.set(command.id, RegisteredCore(command))
  for binding in keybindings {
    let (key, alt, ctrl_cmd) = binding
    self.keybindings.push({
      key,
      alt,
      ctrl_cmd,
      shift: false,
      command_id: command.id,
      when: keybinding_when,
    })
  }
  for binding in shift_keybindings {
    let (key, alt, ctrl_cmd) = binding
    self.keybindings.push({
      key,
      alt,
      ctrl_cmd,
      shift: true,
      command_id: command.id,
      when: keybinding_when,
    })
  }
}

///|
/// `CoreEditorCommand.runEditorCommand`: resolve the active view model, return
/// without one, and pass the logical empty-object fallback to the abstract
/// core member.
fn CoreEditorCommand::run_editor_command(
  self : CoreEditorCommand,
  viewer : Viewer,
  args? : CursorCoreCommandArgs,
) -> Bool {
  match self.precondition {
    Some(precondition) if !precondition(viewer) => return false
    _ => ()
  }
  guard viewer.get_view_model() is Some(view_model) else { return false }
  (self.run_core_editor_command)(
    viewer,
    view_model,
    match args {
      Some(args) => args
      None => self.default_args
    },
  )
}

///|
/// Direct `runCoreEditorCommand` routing used by `ViewController`, which
/// already owns the active view model. The command is still resolved from the
/// process-wide registration table by its source ID.
fn EditorContributionRegistry::run_core_editor_command(
  self : EditorContributionRegistry,
  viewer : Viewer,
  view_model : @view_model.ViewModel,
  id : String,
  args? : CursorCoreCommandArgs,
) -> Bool {
  match self.commands.get(id) {
    Some(RegisteredCore(command)) => {
      match command.precondition {
        Some(precondition) if !precondition(viewer) => return false
        _ => ()
      }
      (command.run_core_editor_command)(
        viewer,
        view_model,
        match args {
          Some(args) => args
          None => command.default_args
        },
      )
    }
    _ => false
  }
}

///|
/// Full editor-command routing for callers that do not already hold the view
/// model (for example the registered keyboard resolver).
fn EditorContributionRegistry::run_editor_command(
  self : EditorContributionRegistry,
  viewer : Viewer,
  id : String,
  args? : CursorCoreCommandArgs,
) -> Bool {
  match self.commands.get(id) {
    Some(RegisteredEditor(command)) =>
      if (command.precondition)(viewer) {
        (command.run)(viewer)
        true
      } else {
        false
      }
    Some(RegisteredCore(command)) => command.run_editor_command(viewer, args?)
    None => false
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
  shift~ : Bool,
) -> Bool {
  for rule in self.keybindings {
    if rule.key == key &&
      rule.alt == alt &&
      rule.ctrl_cmd == ctrl_cmd &&
      rule.shift == shift {
      if (rule.when)(viewer) && self.commands.contains(rule.command_id) {
        // A winning keybinding is handled even when its core movement reaches
        // a hard document boundary and reports no state change.
        self.run_editor_command(viewer, rule.command_id) |> ignore
        return true
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
/// (comments was the only constructor-time wiring; the hover
/// registration follows its Monaco contribution file). Cursor navigation
/// commands register last: this is the approved local substitute for Monaco's
/// keybinding weights/context expressions, so a focused hover's matching
/// EditorContrib rule resolves before the EditorCore cursor rule.
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
      register_folding_contribution(registry)
      register_hover_contribution(registry)
      register_inlay_hints_contribution(registry)
      register_quick_diff_contribution(registry)
      register_cursor_navigation_commands(registry)
      editor_registry_holder.registry = Some(registry)
      registry
    }
  }
}
