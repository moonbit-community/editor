///|
/// Monaco's `renderWhitespace` option. The renderer owns the behavior while
/// this dependency-bottom package owns the public value contract.
pub(all) enum RenderWhitespace {
  None
  Boundary
  Selection
  Trailing
  All
} derive(Eq, Debug)

///|
/// Monaco's `renderLineHighlight` option.
pub(all) enum RenderLineHighlight {
  None
  Gutter
  Line
  All
} derive(Eq, Debug)

///|
/// Monaco's `WrappingIndent` option (`config/editorOptions.ts`). `None` is
/// flush-left, `Same` retains the model line's indentation, and
/// `Indent`/`DeepIndent` add one/two tab stops.
pub(all) enum WrappingIndent {
  None
  Same
  Indent
  DeepIndent
} derive(Eq, Debug)
