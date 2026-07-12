// Contribution/command registry checks (deviations-closeout Track D): the
// registered features instantiate per `Viewer` through the registry and
// dispose with it; the keybinding table gates on live preconditions.

///|
test "contributions instantiate through the registry and dispose with the viewer" {
  let viewer = Viewer::Viewer()
  assert_true(
    viewer.get_contribution("agentFeedback.editorInputContribution") is Some(_),
  )
  assert_true(
    viewer.get_contribution("agentFeedback.editorWidgetContribution") is Some(_),
  )
  assert_true(viewer.get_contribution("editor.contrib.contentHover") is Some(_))
  assert_true(viewer.get_contribution("editor.contrib.unknown") is None)
  viewer.dispose()
  assert_true(
    viewer.get_contribution("agentFeedback.editorInputContribution") is None,
  )
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
