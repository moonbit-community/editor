// Per-model marker decorations ported from the inner `MarkerDecorations` class,
// vscode/src/vs/editor/common/services/markerDecorationsService.ts:132

///|
priv struct StoredMarkerDecoration {
  id : String
  marker : Marker
  decoration : @model.Decoration
}

///|
/// Per-model marker decorations, `MarkerDecorations`
/// (`markerDecorationsService.ts:132`). The `BidirectionalMap<IMarker, id>` is a
/// list keyed by structural equality (Monaco compares marker references, which
/// are stable when unchanged, so structural equality is observationally
/// equivalent). Synthetic ids stand in for `model.deltaDecorations` — the viewer
/// has no model-side stored decorations (plan D3 deviation, cross-referenced to
/// the interval-tree follow-up).
struct MarkerDecorations {
  model : @model.TextModel
  mut entries : Array[StoredMarkerDecoration]
  mut next_id : Int
}

///|
/// Builds an empty per-model decoration set bound to `model`'s snapshot.
fn MarkerDecorations::new(model : @model.TextModel) -> MarkerDecorations {
  { model, entries: [], next_id: 0 }
}

///|
/// `update` (`markerDecorationsService.ts:146`): `diffSets` over the current and
/// new marker sets; early-return `false` when nothing changed (load-bearing — it
/// stops the change event, hence any re-render loop); otherwise recompute the
/// range + option for added markers and report a change.
fn MarkerDecorations::update(
  self : MarkerDecorations,
  markers : Array[Marker],
) -> Bool {
  let current = self.entries.map(e => e.marker)
  let added = markers.filter(m => !current.contains(m))
  let removed = current.filter(m => !markers.contains(m))
  if added.length() == 0 && removed.length() == 0 {
    return false
  }
  self.entries = self.entries.filter(e => markers.contains(e.marker))
  for marker in added {
    let range = create_decoration_range(self.model.snapshot, marker)
    let decoration = create_decoration_option(marker, range)
    let id = "marker-decoration-" + self.next_id.to_string()
    self.next_id += 1
    self.entries.push({ id, marker, decoration })
  }
  true
}

///|
/// `getMarker` (`markerDecorationsService.ts:175`): the marker behind a decoration
/// id, or `None`.
fn MarkerDecorations::get_marker(
  self : MarkerDecorations,
  id : String,
) -> Marker? {
  for entry in self.entries {
    if entry.id == id {
      return Some(entry.marker)
    }
  }
  None
}

///|
/// `getMarkers` (`markerDecorationsService.ts:179`): `(range, marker)` for each
/// live decoration, the range being the transform's tracked range.
fn MarkerDecorations::get_markers(
  self : MarkerDecorations,
) -> Array[(@base_common.Range, Marker)] {
  self.entries.map(e => (e.decoration.range, e.marker))
}
