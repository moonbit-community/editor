///| Compatibility re-export for the queue now owned by `model/tokens`.
///
/// The live state store and default background worker reside with the grammar
/// backend in `viewer/common/model/tokens/text_model_tokens.mbt`. The parent
/// model package retains this public type name so existing queue callers keep
/// their source-compatible surface without duplicating implementation.

///|
/// Sorted disjoint invalid-line range queue.
pub type RangePriorityQueueImpl = @tokens.RangePriorityQueueImpl
