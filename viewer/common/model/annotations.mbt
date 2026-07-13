///| Syntactic font annotations carried by the tokenizer backend.
///
/// Sources at `b18492a288de038fbc7643aae6de8247029d11bd`:
/// `vscode/src/vs/editor/common/textModelEvents.ts:157-183` and
/// `vscode/src/vs/editor/common/model/tokens/annotations.ts:237-263`.

///|
/// Optional presentation overrides for one syntactic token range.
#warnings("-struct_never_constructed-unused_value")
priv struct FontTokenOption {
  font_family : String?
  font_size_multiplier : Double?
  line_height_multiplier : Double?
} derive(Eq, Debug)

///|
/// One half-open annotation update. `None` removes an existing annotation.
#warnings("-struct_never_constructed-unused_value")
priv struct AnnotationUpdate[T] {
  range : @base_common.OffsetRange
  annotation : T?
} derive(Eq, Debug)

///|
/// Ordered annotation updates retained without normalization.
priv struct AnnotationsUpdate[T] {
  annotations_value : Array[AnnotationUpdate[T]]
}

///|
/// Wraps updates in caller order without copying or normalization.
#warnings("-unused_value")
fn[T] AnnotationsUpdate::create(
  annotations : Array[AnnotationUpdate[T]],
) -> AnnotationsUpdate[T] {
  { annotations_value: annotations }
}

///|
/// Returns the ordered updates supplied at construction.
#warnings("-unused_value")
fn[T] AnnotationsUpdate::annotations(
  self : AnnotationsUpdate[T],
) -> Array[AnnotationUpdate[T]] {
  self.annotations_value
}

///|
/// Source-shaped alias for syntactic font updates. `AnnotationUpdate` already
/// makes its annotation optional, so the payload type itself stays non-optional
/// and the resulting carrier has exactly one absent/remove layer.
type FontTokensUpdate = AnnotationsUpdate[FontTokenOption]

///|
/// Model-part event preserving the backend's exact annotation update value.
#warnings("-unused_field")
priv struct ModelFontTokensChangedEvent {
  changes : FontTokensUpdate
}
