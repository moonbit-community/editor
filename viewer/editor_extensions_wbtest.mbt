// Contribution/command registry checks (deviations-closeout Track D): the
// registered features instantiate per `Viewer` through the registry and
// dispose with it; the keybinding table gates on live preconditions.

///|
test "contributions instantiate centrally in the reviewed order and expose every typed variant" {
  let viewer = Viewer::Viewer()
  let expected = [
    "agentFeedback.editorInputContribution",
    "agentFeedback.editorWidgetContribution",
    @folding_browser.FOLDING_CONTROLLER_ID,
    "editor.contrib.contentHover",
    "quickDiff.decorator",
  ]
  let actual : Array[String] = []
  for id, entry in viewer.contributions {
    actual.push(id)
    match (id, entry.instance) {
      ("agentFeedback.editorInputContribution", AgentFeedbackInput(_)) => ()
      ("agentFeedback.editorWidgetContribution", AgentFeedbackWidget(_)) => ()
      (@folding_browser.FOLDING_CONTROLLER_ID, Folding(_)) => ()
      ("editor.contrib.contentHover", ContentHover(_)) => ()
      ("quickDiff.decorator", QuickDiff(_)) => ()
      _ => fail("contribution id and concrete variant diverged: " + id)
    }
  }
  assert_eq(actual, expected)
  for id in expected {
    guard viewer.get_contribution(id) is Some(contribution) else {
      fail("missing known contribution: " + id)
    }
    assert_eq(contribution.id, id)
  }
  assert_true(viewer.get_contribution("editor.contrib.unknown") is None)
  assert_true(viewer.agent_feedback_input_contribution() is Some(_))
  assert_true(viewer.agent_feedback_widget_contribution() is Some(_))
  assert_true(viewer.folding_controller() is Some(_))
  assert_true(viewer.content_hover_controller() is Some(_))
  assert_true(viewer.quick_diff_contribution() is Some(_))

  // Every typed accessor validates both its fixed id and the enum variant.
  // Temporarily put a valid but mismatched payload under quick diff's id.
  let quick_diff_entry = viewer.contributions["quickDiff.decorator"]
  let hover = viewer.content_hover_controller().unwrap()
  viewer.contributions["quickDiff.decorator"] = EditorContributionEntry(
    "quickDiff.decorator",
    ContentHover(hover),
  )
  assert_true(viewer.quick_diff_contribution() is None)
  viewer.contributions["quickDiff.decorator"] = quick_diff_entry

  viewer.dispose()
  for id in expected {
    assert_true(viewer.get_contribution(id) is None)
  }
}

///|
test "duplicate contribution ids are first-wins before later side effects" {
  let first_constructed = Ref(0)
  let first_initialized = Ref(0)
  let first_disposed = Ref(0)
  let second_constructed = Ref(0)
  let second_initialized = Ref(0)
  let second_disposed = Ref(0)
  let registry : EditorContributionRegistry = {
    contributions: [],
    commands: Map([]),
    keybindings: [],
  }
  registry.register_editor_contribution(
    "test.duplicate",
    Eager,
    viewer => {
      first_constructed.val += 1
      let state = QuickDiffContributionState(
        viewer.create_decorations_collection(),
      )
      state.listeners.push(
        @base_common.Disposable::from(() => first_disposed.val += 1),
      )
      QuickDiff(state)
    },
    _viewer => {
      first_initialized.val += 1
      []
    },
  )
  registry.register_editor_contribution(
    "test.duplicate",
    Eager,
    viewer => {
      second_constructed.val += 1
      let state = QuickDiffContributionState(
        viewer.create_decorations_collection(),
      )
      state.listeners.push(
        @base_common.Disposable::from(() => second_disposed.val += 1),
      )
      QuickDiff(state)
    },
    _viewer => {
      second_initialized.val += 1
      []
    },
  )
  assert_eq(registry.contributions.length(), 1)
  let viewer = Viewer::Viewer()
  registry.instantiate_all(viewer)
  // Re-initializing through another registry pass is also first-wins against
  // the already-installed Viewer row.
  registry.instantiate_all(viewer)
  assert_eq(first_constructed.val, 1)
  assert_eq(first_initialized.val, 1)
  assert_eq(second_constructed.val, 0)
  assert_eq(second_initialized.val, 0)
  guard viewer.get_contribution("test.duplicate") is Some(contribution) else {
    fail("first duplicate row was not installed")
  }
  (contribution.dispose)()
  (contribution.dispose)()
  assert_eq(first_disposed.val, 1)
  assert_eq(second_disposed.val, 0)
  viewer.dispose()
  viewer.dispose()
  assert_eq(first_disposed.val, 1)
  assert_eq(second_disposed.val, 0)
  assert_true(viewer.get_contribution("test.duplicate") is None)
}

///|
test "public facade disposal retires typed lookup without removing the row early" {
  let viewer = Viewer::Viewer()
  guard viewer.get_contribution("editor.contrib.contentHover") is Some(hover) else {
    fail("missing hover contribution facade")
  }
  (hover.dispose)()
  assert_true(viewer.content_hover_controller() is None)
  assert_true(viewer.get_contribution("editor.contrib.contentHover") is Some(_))
  assert_true(viewer.contributions.contains("editor.contrib.contentHover"))
  assert_true(
    viewer.contributions["editor.contrib.contentHover"].lifecycle ==
    ContributionDisposed,
  )
  (hover.dispose)()
  viewer.dispose()
}

///|
test "viewer disposes all five real rows once in order while the map stays installed" {
  let viewer = Viewer::Viewer()
  let expected_ids = [
    "agentFeedback.editorInputContribution",
    "agentFeedback.editorWidgetContribution",
    @folding_browser.FOLDING_CONTROLLER_ID,
    "editor.contrib.contentHover",
    "quickDiff.decorator",
  ]
  let order : Array[String] = []
  let map_stayed_installed = Ref(true)
  let typed_row_stayed_available = Ref(true)
  let track = label => {
    @base_common.Disposable::from(() => {
      order.push(label)
      if viewer.contributions.length() != expected_ids.length() {
        map_stayed_installed.val = false
      }
      for id in expected_ids {
        if !viewer.contributions.contains(id) {
          map_stayed_installed.val = false
        }
      }
      let available = match label {
        "input" => viewer.agent_feedback_input_contribution() is Some(_)
        "widget" => viewer.agent_feedback_widget_contribution() is Some(_)
        "folding" => viewer.folding_controller() is Some(_)
        "hover" => viewer.content_hover_controller() is Some(_)
        "quickDiff" => viewer.quick_diff_contribution() is Some(_)
        _ => false
      }
      if !available {
        typed_row_stayed_available.val = false
      }
    })
  }
  viewer.contributions["agentFeedback.editorInputContribution"].listeners.push(
    track("input"),
  )
  viewer.contributions["agentFeedback.editorWidgetContribution"].listeners.push(
    track("widget"),
  )
  viewer.contributions[@folding_browser.FOLDING_CONTROLLER_ID].listeners.push(
    track("folding"),
  )
  viewer.content_hover_controller().unwrap().install_react_timer(track("hover"))
  viewer.quick_diff_contribution().unwrap().listeners.push(track("quickDiff"))
  viewer.dispose()
  viewer.dispose()
  assert_eq(order, ["input", "widget", "folding", "hover", "quickDiff"])
  assert_true(map_stayed_installed.val)
  assert_true(typed_row_stayed_available.val)
  assert_eq(viewer.contributions.length(), 0)
}

///|
test "two viewers retain distinct concrete contribution instances" {
  let first = Viewer::Viewer()
  let second = Viewer::Viewer()
  assert_false(
    physical_equal(
      first.agent_feedback_input_contribution().unwrap(),
      second.agent_feedback_input_contribution().unwrap(),
    ),
  )
  assert_false(
    physical_equal(
      first.agent_feedback_widget_contribution().unwrap(),
      second.agent_feedback_widget_contribution().unwrap(),
    ),
  )
  assert_false(
    physical_equal(
      first.folding_controller().unwrap(),
      second.folding_controller().unwrap(),
    ),
  )
  assert_false(
    physical_equal(
      first.content_hover_controller().unwrap(),
      second.content_hover_controller().unwrap(),
    ),
  )
  assert_false(
    physical_equal(
      first.quick_diff_contribution().unwrap(),
      second.quick_diff_contribution().unwrap(),
    ),
  )
  first.dispose()
  second.dispose()
}

///|
test "model removal and reattach preserve central contribution identities" {
  let viewer = Viewer::Viewer()
  let input = viewer.agent_feedback_input_contribution().unwrap()
  let widgets = viewer.agent_feedback_widget_contribution().unwrap()
  let folding = viewer.folding_controller().unwrap()
  let hover = viewer.content_hover_controller().unwrap()
  let quick_diff = viewer.quick_diff_contribution().unwrap()
  let model = test_model("alpha\nbeta")
  viewer.set_model(Some(model))
  viewer.set_model(Some(model))
  viewer.set_model(None)
  viewer.set_model(Some(model))
  assert_true(
    physical_equal(input, viewer.agent_feedback_input_contribution().unwrap()),
  )
  assert_true(
    physical_equal(
      widgets,
      viewer.agent_feedback_widget_contribution().unwrap(),
    ),
  )
  assert_true(physical_equal(folding, viewer.folding_controller().unwrap()))
  assert_true(physical_equal(hover, viewer.content_hover_controller().unwrap()))
  assert_true(
    physical_equal(quick_diff, viewer.quick_diff_contribution().unwrap()),
  )
  viewer.dispose()
  model.dispose()
}

///|
test "keybinding dispatch honors preconditions" {
  let viewer = Viewer::Viewer()
  // `editor.action.hideHover` is bound to Escape but gated on
  // `hoverVisible`; with no hover the key falls through unhandled.
  assert_false(
    editor_registry().dispatch_keybinding(
      viewer,
      "Escape",
      alt=false,
      ctrl_cmd=false,
      shift=false,
    ),
  )
  // The hover scroll cluster is gated on `hoverFocused`; without a widget
  // the chord resolves to no command.
  assert_false(
    editor_registry().dispatch_keybinding(
      viewer,
      "ArrowUp",
      alt=false,
      ctrl_cmd=false,
      shift=false,
    ),
  )
  viewer.dispose()
}

///|
test "keybinding rules match chords exactly" {
  // `pageUpHover`'s secondary is Alt+ArrowUp; an Alt+CtrlCmd+ArrowUp chord
  // matches no rule (Monaco's resolver would equally find it unbound).
  let registry = editor_registry()
  let mut alt_arrow_rules = 0
  let mut alt_ctrl_arrow_rules = 0
  for rule in registry.keybindings {
    if rule.key == "ArrowUp" && rule.alt && !rule.ctrl_cmd {
      alt_arrow_rules += 1
    }
    if rule.key == "ArrowUp" && rule.alt && rule.ctrl_cmd {
      alt_ctrl_arrow_rules += 1
    }
  }
  assert_eq(alt_arrow_rules, 1)
  assert_eq(alt_ctrl_arrow_rules, 0)
}

///|
test "cursor navigation registers exactly 16 primary rules after contributions" {
  let expected : Map[String, (String, Bool)] = {
    "cursorLeft": ("ArrowLeft", false),
    "cursorLeftSelect": ("ArrowLeft", true),
    "cursorRight": ("ArrowRight", false),
    "cursorRightSelect": ("ArrowRight", true),
    "cursorUp": ("ArrowUp", false),
    "cursorUpSelect": ("ArrowUp", true),
    "cursorPageUp": ("PageUp", false),
    "cursorPageUpSelect": ("PageUp", true),
    "cursorDown": ("ArrowDown", false),
    "cursorDownSelect": ("ArrowDown", true),
    "cursorPageDown": ("PageDown", false),
    "cursorPageDownSelect": ("PageDown", true),
    "cursorHome": ("Home", false),
    "cursorHomeSelect": ("Home", true),
    "cursorEnd": ("End", false),
    "cursorEndSelect": ("End", true),
  }
  let hover_ids : Map[String, Unit] = {
    "editor.action.scrollUpHover": (),
    "editor.action.scrollDownHover": (),
    "editor.action.scrollLeftHover": (),
    "editor.action.scrollRightHover": (),
    "editor.action.pageUpHover": (),
    "editor.action.pageDownHover": (),
    "editor.action.goToTopHover": (),
    "editor.action.goToBottomHover": (),
  }
  let registry = editor_registry()
  let mut cursor_rules = 0
  let mut first_cursor_rule = registry.keybindings.length()
  let mut last_hover_rule = -1
  for i, rule in registry.keybindings {
    match expected.get(rule.command_id) {
      Some((key, shift)) => {
        cursor_rules += 1
        first_cursor_rule = first_cursor_rule.min(i)
        assert_eq(rule.key, key)
        assert_eq(rule.shift, shift)
        assert_false(rule.alt)
        assert_false(rule.ctrl_cmd)
      }
      None => ()
    }
    if hover_ids.contains(rule.command_id) {
      last_hover_rule = i
    }
  }
  assert_eq(cursor_rules, 16)
  assert_true(last_hover_rule >= 0)
  assert_true(first_cursor_rule > last_hover_rule)
}
