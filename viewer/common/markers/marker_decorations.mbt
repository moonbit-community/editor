// Per-model marker decorations ported from the inner `MarkerDecorations` class,
// vscode/src/vs/editor/common/services/markerDecorationsService.ts:132
//
// Decoration plan Phase 3: the class now stores through the model's
// interval-tree decoration storage (`model.delta_decorations`), replacing the
// prior synthetic-id array (the plan-D3 deferral this migration closes).

///|
/// Per-model marker decorations, `MarkerDecorations`
/// (`markerDecorationsService.ts:132`). The `BidirectionalMap<IMarker, id>` is
/// an entry list keyed by structural marker equality (Monaco compares marker
/// references, which are stable when unchanged, so structural equality is
/// observationally equivalent).
struct MarkerDecorations {
  model : @model.TextModel
  mut entries : Array[(Marker, String)]
}

///|
/// Builds an empty per-model decoration map bound to `model`.
fn MarkerDecorations::new(model : @model.TextModel) -> MarkerDecorations {
  { model, entries: [] }
}

///|
/// The ctor's dispose hook (`markerDecorationsService.ts:140-143`): remove
/// this owner's decorations from the model and clear the map.
fn MarkerDecorations::dispose(self : MarkerDecorations) -> Unit {
  let _ = self.model.delta_decorations(self.entries.map(e => e.1), [])
  self.entries = []
}

///|
/// `update` (`markerDecorationsService.ts:146`): `diffSets` over the current
/// and new marker sets; early-return `false` when nothing changed
/// (load-bearing — it stops the change event, hence any re-render loop);
/// otherwise `deltaDecorations` the removed ids against the added markers'
/// (range, options) pairs and record the returned ids.
fn MarkerDecorations::update(
  self : MarkerDecorations,
  markers : Array[Marker],
) -> Bool {
  // We use the fact that marker instances are not recreated when different
  // owners update. So we can compare (structurally) to find out what changed
  // since the last update.
  let current = self.entries.map(e => e.0)
  let added = markers.filter(m => !current.contains(m))
  let removed = current.filter(m => !markers.contains(m))
  if added.length() == 0 && removed.length() == 0 {
    return false
  }
  let old_ids : Array[String] = []
  for entry in self.entries {
    if removed.contains(entry.0) {
      old_ids.push(entry.1)
    }
  }
  let new_decorations : Array[@model.DeltaDecoration] = added.map(marker => {
    let range = create_decoration_range(self.model.snapshot, marker)
    { range, options: create_decoration_option(marker) }
  })
  let ids = self.model.delta_decorations(old_ids, new_decorations)
  self.entries = self.entries.filter(e => markers.contains(e.0))
  for index in 0..<ids.length() {
    self.entries.push((added[index], ids[index]))
  }
  true
}

///|
/// `getMarker` (`markerDecorationsService.ts:175`): the marker behind a
/// decoration id, or `None`.
fn MarkerDecorations::get_marker(
  self : MarkerDecorations,
  id : String,
) -> Marker? {
  for entry in self.entries {
    if entry.1 == id {
      return Some(entry.0)
    }
  }
  None
}

///|
/// `getMarkers` (`markerDecorationsService.ts:179`): `(range, marker)` for
/// each live decoration, the range resolved from the model's storage.
fn MarkerDecorations::get_markers(
  self : MarkerDecorations,
) -> Array[(@base_common.Range, Marker)] {
  let res : Array[(@base_common.Range, Marker)] = []
  for entry in self.entries {
    let (marker, id) = entry
    match self.model.get_decoration_range(id) {
      Some(range) => res.push((range, marker))
      None => ()
    }
  }
  res
}
