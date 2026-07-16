///|
/// Test/workbench telemetry emitted after a viewer prepares model content for
/// rendering. `model` is the stable model handle; the remaining fields are
/// passive counts and timings rather than mutable implementation state.
pub(all) struct ViewModelBuiltObservation {
  model : @model.TextModel
  line_count : Int
  token_count : Int
  tokenize_ms : Double
  build_ms : Double
} derive(Debug)

///|
/// Test/workbench telemetry emitted after a viewer patches model content into
/// the DOM. Diagnostics remain owned by the marker service and deliberately do
/// not cross this testing boundary.
pub(all) struct ModelRenderedObservation {
  model : @model.TextModel
  line_count : Int
  rendered_lines : Int
  patch_ms : Double
  fresh : Bool
} derive(Debug)

///|
/// Test/workbench telemetry emitted when one hover resolution completes.
pub(all) struct HoverResolvedObservation {
  ok : Bool
  revision : String
} derive(Debug, Eq)
