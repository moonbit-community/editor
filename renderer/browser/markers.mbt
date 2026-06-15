///|
pub(all) struct Marker {
  owner : String
  resource : String
  range : @core.Range
  severity : @language.DiagnosticSeverity
  message : String
  source : String?
  code : String?
} derive(Eq, Debug)

///|
pub fn Marker::from_diagnostic(
  owner : String,
  resource : @workspace.DocumentUri,
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
pub fn Marker::to_diagnostic(self : Marker) -> @language.Diagnostic {
  { range: self.range, severity: self.severity, message: self.message }
}

///|
pub(all) struct MarkerService {
  entries : Array[Marker]
}

///|
pub fn MarkerService::new() -> MarkerService {
  { entries: [] }
}

///|
pub fn MarkerService::set_diagnostics(
  self : MarkerService,
  owner : String,
  resource : @workspace.DocumentUri,
  diagnostics : Array[@language.Diagnostic],
) -> Unit {
  let markers : Array[Marker] = []
  for diagnostic in diagnostics {
    markers.push(Marker::from_diagnostic(owner, resource, diagnostic))
  }
  self.set_markers(owner, resource, markers)
}

///|
pub fn MarkerService::set_markers(
  self : MarkerService,
  owner : String,
  resource : @workspace.DocumentUri,
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
pub fn MarkerService::remove_owner_resource(
  self : MarkerService,
  owner : String,
  resource : @workspace.DocumentUri,
) -> Unit {
  self.set_markers(owner, resource, [])
}

///|
pub fn MarkerService::clear_resource(
  self : MarkerService,
  resource : @workspace.DocumentUri,
) -> Unit {
  let resource_key = resource.to_string()
  let retained = self.entries.filter(marker => marker.resource != resource_key)
  self.entries.clear()
  self.entries.append(retained)
}

///|
pub fn MarkerService::markers_for_resource(
  self : MarkerService,
  resource : @workspace.DocumentUri,
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
pub fn MarkerService::diagnostics_for_resource(
  self : MarkerService,
  resource : @workspace.DocumentUri,
) -> Array[@language.Diagnostic] {
  let diagnostics : Array[@language.Diagnostic] = []
  for marker in self.markers_for_resource(resource) {
    diagnostics.push(marker.to_diagnostic())
  }
  diagnostics
}

///|
pub(all) struct MarkerDecorationsService {
  markers : MarkerService
}

///|
pub fn MarkerDecorationsService::new(
  markers : MarkerService,
) -> MarkerDecorationsService {
  { markers, }
}

///|
pub fn MarkerDecorationsService::decorations_for_resource(
  self : MarkerDecorationsService,
  resource : @workspace.DocumentUri,
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
pub fn MarkerDecorationsService::markers_at(
  self : MarkerDecorationsService,
  resource : @workspace.DocumentUri,
  range : @core.Range,
  limit? : Int = 0,
) -> Array[Marker] {
  let out : Array[Marker] = []
  for marker in self.markers.markers_for_resource(resource) {
    if marker.range.intersects(range) ||
      marker.range.contains_offset(range.start) {
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
