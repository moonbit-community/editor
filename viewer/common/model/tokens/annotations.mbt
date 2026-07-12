///| Syntactic font annotations carried by the tokenizer backend.
///
/// Sources at `b18492a288de038fbc7643aae6de8247029d11bd`:
/// `vscode/src/vs/editor/common/textModelEvents.ts:157-183` and
/// `vscode/src/vs/editor/common/model/tokens/annotations.ts:237-263`.

///|
/// Optional presentation overrides for one syntactic token range.
pub(all) struct FontTokenOption {
  font_family : String?
  font_size_multiplier : Double?
  line_height_multiplier : Double?
} derive(Eq, Debug)

///|
/// One half-open annotation update. `None` removes an existing annotation.
pub(all) struct AnnotationUpdate[T] {
  range : @base_common.OffsetRange
  annotation : T?
} derive(Eq, Debug)

///|
/// Ordered annotation updates retained without normalization.
pub struct AnnotationsUpdate[T] {
  priv annotations_value : Array[AnnotationUpdate[T]]
}

///|
/// Wraps updates in caller order without copying or normalization.
pub fn[T] AnnotationsUpdate::create(
  annotations : Array[AnnotationUpdate[T]],
) -> AnnotationsUpdate[T] {
  { annotations_value: annotations }
}

///|
/// Returns the ordered updates supplied at construction.
pub fn[T] AnnotationsUpdate::annotations(
  self : AnnotationsUpdate[T],
) -> Array[AnnotationUpdate[T]] {
  self.annotations_value
}

///|
/// Source-shaped alias for optional syntactic font updates.
pub type FontTokensUpdate = AnnotationsUpdate[FontTokenOption?]

///|
/// Model-part event preserving the backend's exact annotation update value.
pub(all) struct ModelFontTokensChangedEvent {
  changes : FontTokensUpdate
}
