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
