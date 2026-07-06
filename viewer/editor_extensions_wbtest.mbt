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
