// `view_root_class` ports Monaco's `EditorClassName.compute`
// (`editorOptions.ts:1660-1690`): `showUnused`/`showDeprecated` are
// option-driven root classes, present by default and dropped when the
// corresponding option is off.

///|
test "root class defaults include showUnused and showDeprecated" {
  inspect(
    view_root_class("source-loaded"),
    content="monaco-editor moonbit-viewer readonly-editor showUnused showDeprecated source-loaded",
  )
}

///|
test "show_unused off drops only the showUnused class" {
  inspect(
    view_root_class("source-loaded", show_unused=false),
    content="monaco-editor moonbit-viewer readonly-editor showDeprecated source-loaded",
  )
}

///|
test "show_deprecated off drops only the showDeprecated class" {
  inspect(
    view_root_class("source-loaded", show_deprecated=false),
    content="monaco-editor moonbit-viewer readonly-editor showUnused source-loaded",
  )
}

///|
test "both off keeps the base classes and focus suffix" {
  inspect(
    view_root_class(
      "source-empty",
      focused=true,
      show_unused=false,
      show_deprecated=false,
    ),
    content="monaco-editor moonbit-viewer readonly-editor source-empty focused",
  )
}
