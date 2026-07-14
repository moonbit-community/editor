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
/// The concrete live contribution state stored in the per-Viewer registry.
/// The product registry is closed and statically populated, so adding a sixth
/// contribution deliberately requires exhaustive construction, typed-access,
/// and disposal updates here.
priv enum EditorContributionInstance {
  ContentHover(@hover_browser.ContentHoverController)
  Folding(@folding_browser.FoldingController)
  AgentFeedbackInput(
    @agent_feedback_browser.AgentFeedbackEditorInputContribution
  )
  AgentFeedbackWidget(
    @agent_feedback_browser.AgentFeedbackEditorWidgetContribution
  )
  QuickDiff(QuickDiffContributionState)
}

///|
/// The quick-diff decorator's per-editor state. Its collection and all three
/// subscriptions are retained by the same central contribution entry rather
/// than captured by a lifecycle-only facade closure.
priv struct QuickDiffContributionState {
  collection : EditorDecorationsCollection
  listeners : Array[@base_common.Disposable]
}

///|
fn QuickDiffContributionState::QuickDiffContributionState(
  collection : EditorDecorationsCollection,
) -> QuickDiffContributionState {
  { collection, listeners: [] }
}

///|
/// Entry lifecycle keeps the temporary public `dispose` facade idempotent and
/// makes typed lookup unavailable after teardown. `ContributionDisposing`
/// remains readable so synchronous feature cleanup can use central accessors
/// while the complete map is still installed.
priv enum EditorContributionLifecycle {
  ContributionLive
  ContributionDisposing
  ContributionDisposed
} derive(Eq)

///|
/// One live row in Monaco `CodeEditorContributions._instances`. `listeners`
/// owns the root-package subscriptions for folding and agent feedback; hover
/// owns its cancellable work directly and quick diff owns its subscriptions in
/// `QuickDiffContributionState`.
priv struct EditorContributionEntry {
  id : String
  instance : EditorContributionInstance
  listeners : Array[@base_common.Disposable]
  mut lifecycle : EditorContributionLifecycle
}

///|
fn EditorContributionEntry::EditorContributionEntry(
  id : String,
  instance : EditorContributionInstance,
) -> EditorContributionEntry {
  { id, instance, listeners: [], lifecycle: ContributionLive }
}

///|
fn EditorContributionEntry::typed_lookup_available(
  self : EditorContributionEntry,
) -> Bool {
  self.lifecycle != ContributionDisposed
}

///|
/// Direct typed lifecycle dispatch. The complete Viewer map remains installed
/// while every row tears down, so feature cleanup can still use typed central
/// accessors. The explicit lifecycle state rejects recursive/repeated teardown
/// and makes later typed lookup return `None` without removing the row before
/// the full ordered disposal pass finishes.
fn EditorContributionEntry::dispose(
  self : EditorContributionEntry,
  viewer : Viewer,
) -> Unit {
  guard self.lifecycle == ContributionLive else { return }
  self.lifecycle = ContributionDisposing
  match self.instance {
    AgentFeedbackInput(_) => {
      for listener in self.listeners {
        listener.dispose()
      }
      self.listeners.clear()
      @agent_feedback_browser.AgentFeedbackEditorInputContribution::detach(
        viewer.get_id(),
      )
    }
    AgentFeedbackWidget(controller) => {
      viewer.clear_agent_feedback_widgets_from(controller) |> ignore
      for listener in self.listeners {
        listener.dispose()
      }
      self.listeners.clear()
      @agent_feedback_browser.AgentFeedbackEditorWidgetContribution::detach(
        viewer.get_id(),
      )
    }
    Folding(controller) => {
      controller.clear_local()
      for listener in self.listeners {
        listener.dispose()
      }
      self.listeners.clear()
      @folding_browser.FoldingController::detach(viewer.get_id())
    }
    ContentHover(controller) => {
      controller.cancel_all_timers()
      controller.cancel_request()
      @hover_browser.ContentHoverController::detach(viewer.get_id())
    }
    QuickDiff(state) => {
      state.collection.clear()
      for listener in state.listeners {
        listener.dispose()
      }
      state.listeners.clear()
    }
  }
  self.lifecycle = ContributionDisposed
}

///|
/// `IEditorContributionDescription` (`editorExtensions.ts:68-72`): id + ctor
/// closure, instantiated once per `Viewer`. Construction and initialization
/// are split so the concrete entry can be installed before any synchronous
/// typed lookup made by the initializer.
priv struct EditorContributionDescription {
  id : String
  instantiation : EditorContributionInstantiation
  ctor : (Viewer) -> EditorContributionInstance
  initialize : (Viewer) -> Array[@base_common.Disposable]
}

///|
fn EditorContributionDescription::EditorContributionDescription(
  id : String,
  instantiation : EditorContributionInstantiation,
  ctor : (Viewer) -> EditorContributionInstance,
  initialize : (Viewer) -> Array[@base_common.Disposable],
) -> EditorContributionDescription {
  { id, instantiation, ctor, initialize }
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
  ctor : (Viewer) -> EditorContributionInstance,
  initialize : (Viewer) -> Array[@base_common.Disposable],
) -> Unit {
  // Monaco's description registry is first-wins. Reject the later row before
  // its constructor, initializer, listener, or dispose path can exist.
  for description in self.contributions {
    if description.id == id {
      return
    }
  }
  self.contributions.push(
    EditorContributionDescription(id, instantiation, ctor, initialize),
  )
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
) -> Unit {
  for description in self.contributions {
    // Also guard the actual per-Viewer map: callers may initialize a Viewer
    // from more than one registry, and a later description must never replace
    // a live row or run construction side effects.
    if viewer.contributions.contains(description.id) {
      continue
    }
    // Every mode instantiates eagerly (no idle/interaction schedulers
    // exist); the declared mode is carried for source fidelity only.
    ignore(description.instantiation)
    let instance = (description.ctor)(viewer)
    let entry = EditorContributionEntry(description.id, instance)
    // This insertion must precede initialization: feedback input/widgets and
    // folding synchronously resolve their typed contribution in their first
    // initialization step.
    viewer.contributions.set(description.id, entry)
    for listener in (description.initialize)(viewer) {
      entry.listeners.push(listener)
    }
  }
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
        commands: Map([]),
        keybindings: [],
      }
      register_agent_feedback_contribution(registry)
      register_folding_contribution(registry)
      register_hover_contribution(registry)
      register_quick_diff_contribution(registry)
      register_cursor_navigation_commands(registry)
      editor_registry_holder.registry = Some(registry)
      registry
    }
  }
}
