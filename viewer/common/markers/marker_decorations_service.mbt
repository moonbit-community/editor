// Marker → decoration transform + service ported from
// vscode/src/vs/editor/common/services/markerDecorationsService.ts

///|
/// Converts marker state into render decorations and the live-marker lookup,
/// `MarkerDecorationsService` (`markerDecorationsService.ts:24`). Models are
/// registered by the viewer (`on_model_added`/`on_model_removed`) in place of
/// Monaco's `IModelService` seeding.
pub struct MarkerDecorationsService {
  markers : MarkerService
  marker_decorations : Map[String, MarkerDecorations]
  suppressed_ranges : Map[String, Array[@base_common.Range]]
  did_change_marker_decorations : @base_common.Emitter[@model.TextModel]
  mut subscription : @base_common.Disposable?
}

///|
/// Creates a decoration facade over the marker store and subscribes to its change
/// event (`markerDecorationsService.ts:43`).
pub fn MarkerDecorationsService::new(
  markers : MarkerService,
) -> MarkerDecorationsService {
  let service : MarkerDecorationsService = {
    markers,
    marker_decorations: {},
    suppressed_ranges: {},
    did_change_marker_decorations: @base_common.Emitter::new(),
    subscription: None,
  }
  service.subscription = Some(
    markers.on_did_change_markers(resources => {
      service.handle_marker_change(resources)
    }),
  )
  service
}

///|
/// Subscribes to per-model decoration-change events, `onDidChangeMarker`
/// (`markerDecorationsService.ts:29`). The payload is the changed model.
pub fn MarkerDecorationsService::on_did_change_marker_decorations(
  self : MarkerDecorationsService,
  listener : (@model.TextModel) -> Unit,
) -> @base_common.Disposable {
  self.did_change_marker_decorations.event(listener)
}

///|
/// Releases the marker subscription and change emitter (`dispose`,
/// `markerDecorationsService.ts:46`).
pub fn MarkerDecorationsService::dispose(
  self : MarkerDecorationsService,
) -> Unit {
  match self.subscription {
    Some(d) => d.dispose()
    None => ()
  }
  self.did_change_marker_decorations.dispose()
  self.marker_decorations.clear()
}

///|
/// Registers a model and seeds its decorations, `_onModelAdded`
/// (`markerDecorationsService.ts:93`). A re-add (model version rotation) replaces
/// the prior per-model set.
pub fn MarkerDecorationsService::on_model_added(
  self : MarkerDecorationsService,
  model : @model.TextModel,
) -> Unit {
  let marker_decorations = MarkerDecorations::new(model)
  self.marker_decorations.set(model.uri.to_string(), marker_decorations)
  self.update_decorations(marker_decorations)
}

///|
/// Drops a model's decorations and cleans up markers for transient schemes,
/// `_onModelRemoved` (`markerDecorationsService.ts:99`).
pub fn MarkerDecorationsService::on_model_removed(
  self : MarkerDecorationsService,
  model : @model.TextModel,
) -> Unit {
  self.marker_decorations.remove(model.uri.to_string())
  // clean up markers for internal, transient models
  let scheme = model.uri.scheme()
  if scheme == "inmemory" || scheme == "internal" || scheme == "vscode" {
    for
      owner in self.markers
      .read(MarkerReadOptions::new(resource=model.uri))
      .map(m => m.owner) {
      self.markers.remove(owner, [model.uri])
    }
  }
}

///|
/// Per-resource `_updateDecorations`, `_handleMarkerChange`
/// (`markerDecorationsService.ts:84`).
fn MarkerDecorationsService::handle_marker_change(
  self : MarkerDecorationsService,
  changed_resources : Array[@base_common.Uri],
) -> Unit {
  for resource in changed_resources {
    match self.marker_decorations.get(resource.to_string()) {
      Some(marker_decorations) => self.update_decorations(marker_decorations)
      None => ()
    }
  }
}

///|
/// `_updateDecorations` (`markerDecorationsService.ts:114`): read the first 500
/// markers, drop ones inside suppressed ranges, push them through `update`, and
/// fire the change event when something changed.
fn MarkerDecorationsService::update_decorations(
  self : MarkerDecorationsService,
  marker_decorations : MarkerDecorations,
) -> Unit {
  // Limit to the first 500 errors/warnings
  let mut markers = self.markers.read(
    MarkerReadOptions::new(resource=marker_decorations.model.uri, take=500),
  )
  // filter markers from suppressed ranges
  match self.suppressed_ranges.get(marker_decorations.model.uri.to_string()) {
    Some(suppressed_ranges) =>
      markers = markers.filter(marker => {
        !suppressed_ranges.any(candidate => {
          @base_common.Range::are_intersecting_or_touching(
            candidate,
            marker.range(),
          )
        })
      })
    None => ()
  }
  if marker_decorations.update(markers) {
    self.did_change_marker_decorations.fire(marker_decorations.model)
  }
}

///|
/// `getMarker` (`markerDecorationsService.ts:52`): the marker behind a decoration
/// id on `uri`. Ported for fidelity; the viewer hover consumes `get_live_markers`.
pub fn MarkerDecorationsService::get_marker(
  self : MarkerDecorationsService,
  uri : @base_common.Uri,
  decoration_id : String,
) -> Marker? {
  match self.marker_decorations.get(uri.to_string()) {
    Some(marker_decorations) => marker_decorations.get_marker(decoration_id)
    None => None
  }
}

///|
/// `getLiveMarkers` (`markerDecorationsService.ts:57`): `(range, marker)` pairs for
/// the resource. Replaces the prior `markers_at`; the marker hover participant
/// filters these by the anchor range.
pub fn MarkerDecorationsService::get_live_markers(
  self : MarkerDecorationsService,
  uri : @base_common.Uri,
) -> Array[(@base_common.Range, Marker)] {
  match self.marker_decorations.get(uri.to_string()) {
    Some(marker_decorations) => marker_decorations.get_markers()
    None => []
  }
}

///|
/// `addMarkerSuppression` (`markerDecorationsService.ts:62`): suppress markers in
/// `range` on `uri`; the disposable removes the suppression (D5).
pub fn MarkerDecorationsService::add_marker_suppression(
  self : MarkerDecorationsService,
  uri : @base_common.Uri,
  range : @base_common.Range,
) -> @base_common.Disposable {
  let key = uri.to_string()
  let suppressed_ranges = match self.suppressed_ranges.get(key) {
    Some(r) => r
    None => {
      let r : Array[@base_common.Range] = []
      self.suppressed_ranges.set(key, r)
      r
    }
  }
  suppressed_ranges.push(range)
  self.handle_marker_change([uri])
  @base_common.Disposable::from(() => {
    match self.suppressed_ranges.get(key) {
      Some(suppressed_ranges) => {
        match suppressed_ranges.search(range) {
          Some(index) => suppressed_ranges.remove(index) |> ignore
          None => ()
        }
        if suppressed_ranges.length() == 0 {
          self.suppressed_ranges.remove(key)
        }
        self.handle_marker_change([uri])
      }
      None => ()
    }
  })
}

///|
/// Builds squiggle decorations for a model, running each marker through the
/// faithful range + option transform. The decorations are rebuilt per frame from
/// the marker store rather than diffed into model-side stored decorations; the
/// `update()` diff is ported (see `MarkerDecorations`) but storage stays a
/// follow-up (plan D3 deviation, cross-referenced to the interval-tree note).
pub fn MarkerDecorationsService::decorations_for_resource(
  self : MarkerDecorationsService,
  model : @model.TextModel,
) -> @model.DecorationSet {
  let items : Array[@model.Decoration] = []
  for marker in self.markers.markers_for_resource(model.uri) {
    let range = create_decoration_range(model.snapshot, marker)
    items.push(create_decoration_option(marker, range))
  }
  @model.DecorationSet::from_array(items)
}

// Theme-color ids the option matrix carries (inert; plan D4). From
// editorColorRegistry.ts:74-76 and colors/minimapColors.ts:29-37.

///|
let overview_ruler_error : String = "editorOverviewRuler.errorForeground"

///|
let overview_ruler_warning : String = "editorOverviewRuler.warningForeground"

///|
let overview_ruler_info : String = "editorOverviewRuler.infoForeground"

///|
let minimap_error : String = "minimap.errorHighlight"

///|
let minimap_warning : String = "minimap.warningHighlight"

///|
let minimap_info : String = "minimap.infoHighlight"

///|
/// `MarkerDecorations._createDecorationOption`
/// (`markerDecorationsService.ts:226`): the severity→option matrix plus tag
/// overrides. `range` is supplied by `create_decoration_range`; the viewer bundles
/// range + options into one `Decoration`. An empty `class_name` is Monaco's
/// `className: undefined` (Hint+Deprecated).
pub fn create_decoration_option(
  marker : Marker,
  range : @base_common.Range,
) -> @model.Decoration {
  let mut class_name = ""
  let mut color : String? = None
  let mut z_index = 0
  let mut inline_class_name : String? = None
  let mut minimap : @model.MinimapOptions? = None
  match marker.severity {
    Hint => {
      if marker.has_tag(Deprecated) {
        class_name = ""
      } else if marker.has_tag(Unnecessary) {
        class_name = "squiggly-unnecessary"
      } else {
        class_name = "squiggly-hint"
      }
      z_index = 0
    }
    Info => {
      class_name = "squiggly-info"
      color = Some(overview_ruler_info)
      z_index = 10
      minimap = Some({ color: minimap_info, position: Inline })
    }
    Warning => {
      class_name = "squiggly-warning"
      color = Some(overview_ruler_warning)
      z_index = 20
      minimap = Some({ color: minimap_warning, position: Inline })
    }
    Error => {
      // default
      class_name = "squiggly-error"
      color = Some(overview_ruler_error)
      z_index = 30
      minimap = Some({ color: minimap_error, position: Inline })
    }
  }
  match marker.tags {
    Some(tags) => {
      if tags.contains(Unnecessary) {
        inline_class_name = Some("squiggly-inline-unnecessary")
      }
      if tags.contains(Deprecated) {
        inline_class_name = Some("squiggly-inline-deprecated")
      }
    }
    None => ()
  }
  Decoration(
    range,
    Diagnostic,
    class_name,
    message=marker.message,
    inline_class_name?,
    z_index~,
    show_if_collapsed=true,
    stickiness=NeverGrowsWhenTypingAtEdges,
    overview_ruler={ color, position: Right },
    minimap?,
    description="marker-decoration",
  )
}

///|
/// `MarkerDecorations._createDecorationRange` (`markerDecorationsService.ts:190`):
/// turns a raw marker into the decoration's render `Range`. Four branches:
///   1. Hint without Unnecessary/Deprecated → single line, `+2` columns (room for
///      three dots);
///   2. clamp via `validateRange`;
///   3. empty range → keep 1ch (empty line / behind EOL) or expand to the
///      surrounding word;
///   4. full-line marker (`endColumn == MAX_VALUE`, `startColumn == 1`, single
///      line) → snap the start to the first non-whitespace column (and mutate the
///      raw marker, as Monaco does).
pub fn create_decoration_range(
  snapshot : @model.TextSnapshot,
  raw_marker : Marker,
) -> @base_common.Range {
  let mut ret = raw_marker.range()
  if raw_marker.severity == Hint &&
    !raw_marker.has_tag(Unnecessary) &&
    !raw_marker.has_tag(Deprecated) {
    // * never render hints on multiple lines
    // * make enough space for three dots
    ret = ret.set_end_position(ret.start_line_number, ret.start_column + 2)
  }
  ret = snapshot.validate_range(ret)
  if ret.is_empty() {
    let last_non_ws = snapshot.get_line_last_non_whitespace_column(
      ret.start_line_number,
    )
    let max_column = if last_non_ws != 0 {
      last_non_ws
    } else {
      snapshot.get_line_max_column(ret.start_line_number)
    }
    if max_column == 1 || ret.end_column >= max_column {
      // empty line or behind eol
      // keep the range as is, it will be rendered 1ch wide
      return ret
    }
    match snapshot.get_word_at_position(ret.get_start_position()) {
      Some(word) =>
        ret = Range(
          ret.start_line_number,
          word.start_column,
          ret.end_line_number,
          word.end_column,
        )
      None => ()
    }
  } else if raw_marker.end_column == max_value_column &&
    raw_marker.start_column == 1 &&
    ret.start_line_number == ret.end_line_number {
    let min_column = snapshot.get_line_first_non_whitespace_column(
      raw_marker.start_line_number,
    )
    if min_column < ret.end_column {
      ret = Range(
        ret.start_line_number,
        min_column,
        ret.end_line_number,
        ret.end_column,
      )
      raw_marker.start_column = min_column
    }
  }
  ret
}
