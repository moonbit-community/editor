///|
/// Monaco-style marker stored by owner and resource, derived from diagnostics
/// but ready for marker-specific metadata.
pub(all) struct Marker {
  owner : String
  resource : String
  range : @base_common.OffsetRange
  severity : @language.DiagnosticSeverity
  message : String
  source : String?
  code : String?
} derive(Eq, Debug)

///|
/// Converts a language diagnostic into a marker owned by a specific provider.
pub fn Marker::from_diagnostic(
  owner : String,
  resource : @base_common.Uri,
  diagnostic : @language.Diagnostic,
) -> Marker {
  {
    owner,
    resource: resource.to_string(),
    range: diagnostic.range,
    severity: diagnostic.severity,
    message: diagnostic.message,
    source: None,
    code: None,
  }
}

///|
/// Converts marker data back to the shared diagnostic shape.
pub fn Marker::to_diagnostic(self : Marker) -> @language.Diagnostic {
  { range: self.range, severity: self.severity, message: self.message }
}

///|
/// In-memory marker store keyed by owner/resource pairs.
pub(all) struct MarkerService {
  entries : Array[Marker]
}

///|
/// Creates an empty marker store.
pub fn MarkerService::new() -> MarkerService {
  { entries: [] }
}

///|
/// Replaces diagnostics for one owner/resource pair.
pub fn MarkerService::set_diagnostics(
  self : MarkerService,
  owner : String,
  resource : @base_common.Uri,
  diagnostics : Array[@language.Diagnostic],
) -> Unit {
  let markers : Array[Marker] = []
  for diagnostic in diagnostics {
    markers.push(Marker::from_diagnostic(owner, resource, diagnostic))
  }
  self.set_markers(owner, resource, markers)
}

///|
/// Replaces markers for one owner/resource pair while retaining all other
/// owners and resources.
pub fn MarkerService::set_markers(
  self : MarkerService,
  owner : String,
  resource : @base_common.Uri,
  markers : Array[Marker],
) -> Unit {
  let resource_key = resource.to_string()
  let retained = self.entries.filter(marker => {
    marker.owner != owner || marker.resource != resource_key
  })
  self.entries.clear()
  self.entries.append(retained)
  self.entries.append(markers)
}

///|
/// Clears markers for one owner/resource pair.
pub fn MarkerService::remove_owner_resource(
  self : MarkerService,
  owner : String,
  resource : @base_common.Uri,
) -> Unit {
  self.set_markers(owner, resource, [])
}

///|
/// Clears markers from every owner for one resource.
pub fn MarkerService::clear_resource(
  self : MarkerService,
  resource : @base_common.Uri,
) -> Unit {
  let resource_key = resource.to_string()
  let retained = self.entries.filter(marker => marker.resource != resource_key)
  self.entries.clear()
  self.entries.append(retained)
}

///|
/// Returns markers for one resource, optionally capped by `limit`.
pub fn MarkerService::markers_for_resource(
  self : MarkerService,
  resource : @base_common.Uri,
  limit? : Int = 0,
) -> Array[Marker] {
  let resource_key = resource.to_string()
  let out : Array[Marker] = []
  for marker in self.entries {
    if marker.resource == resource_key {
      out.push(marker)
      if limit > 0 && out.length() >= limit {
        return out
      }
    }
  }
  out
}

///|
/// Returns resource markers in the shared diagnostic shape.
pub fn MarkerService::diagnostics_for_resource(
  self : MarkerService,
  resource : @base_common.Uri,
) -> Array[@language.Diagnostic] {
  let diagnostics : Array[@language.Diagnostic] = []
  for marker in self.markers_for_resource(resource) {
    diagnostics.push(marker.to_diagnostic())
  }
  diagnostics
}

///|
/// Converts marker state into viewer decorations and hover lookups.
pub(all) struct MarkerDecorationsService {
  markers : MarkerService
}

///|
/// Creates a decoration facade over the marker store.
pub fn MarkerDecorationsService::new(
  markers : MarkerService,
) -> MarkerDecorationsService {
  { markers, }
}

///|
/// Builds diagnostic decorations for one resource.
pub fn MarkerDecorationsService::decorations_for_resource(
  self : MarkerDecorationsService,
  resource : @base_common.Uri,
) -> @decorations.DecorationSet {
  let items : Array[@decorations.Decoration] = []
  for marker in self.markers.markers_for_resource(resource) {
    items.push(
      Decoration(
        marker.range,
        Diagnostic,
        marker_class_name(marker.severity),
        message=marker.message,
      ),
    )
  }
  @decorations.DecorationSet::from_array(items)
}

///|
/// Returns markers intersecting a rendered range, optionally capped by `limit`.
pub fn MarkerDecorationsService::markers_at(
  self : MarkerDecorationsService,
  resource : @base_common.Uri,
  range : @base_common.OffsetRange,
  limit? : Int = 0,
) -> Array[Marker] {
  let out : Array[Marker] = []
  for marker in self.markers.markers_for_resource(resource) {
    if marker.range.intersects(range) ||
      marker.range.contains(range.start) {
      out.push(marker)
      if limit > 0 && out.length() >= limit {
        return out
      }
    }
  }
  out
}

///|
fn marker_class_name(severity : @language.DiagnosticSeverity) -> String {
  match severity {
    Error => "diag-error"
    Warning => "diag-warning"
    Info => "diag-info"
  }
}
