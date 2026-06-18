///|
priv struct HarnessHoverFixture {
  kind : String
  contents : String
}

///|
let harness_hover_fixture : Ref[HarnessHoverFixture?] = Ref(None)

///|
priv struct HarnessHoverProvider {}

///|
fn register_harness_hover_provider(services : @viewer.ViewerServices) -> Unit {
  let provider = HarnessHoverProvider::{  }
  let selector = @language.LanguageSelector::LanguageFilter(
    LanguageFilter(scheme="readonly-remote"),
  )
  services.languages.register_hover_provider(selector, provider) |> ignore
  services.languages.register_diagnostics_provider(selector, provider) |> ignore
  install_hover_fixture_control(set_harness_hover_fixture)
}

///|
fn set_harness_hover_fixture(kind : String, contents : String) -> Unit {
  harness_hover_fixture.val = if contents == "" {
    None
  } else {
    Some({ kind, contents })
  }
  match viewer_cell.val {
    Some(viewer) => viewer.refresh_model_features()
    None => ()
  }
}

///|
impl @language.HoverProvider for HarnessHoverProvider with fn provide_hover(
  _self,
  model,
  position,
  _token,
) {
  match harness_hover_fixture.val {
    Some(fixture) =>
      if fixture.kind == "marker" {
        Some({ range: harness_marker_range(model), contents: [] })
      } else {
        let text = model.snapshot.text
        let offset = model.snapshot.offset_at_position(position)
        let start = @base_common.clamp_int(offset, 0, text.length())
        let end = @base_common.clamp_int(start + 1, start, text.length())
        let content : @language.HoverContent = if fixture.kind == "markdown" {
          Markdown(fixture.contents)
        } else {
          PlainText(fixture.contents)
        }
        Some({ range: Range(start, end), contents: [content] })
      }
    None => None
  }
}

///|
impl @language.DiagnosticsProvider for HarnessHoverProvider with fn provide_diagnostics(
  _self,
  model,
  _token,
) {
  match harness_hover_fixture.val {
    Some(fixture) =>
      if fixture.kind == "marker" {
        [
          {
            range: harness_marker_range(model),
            severity: Warning,
            message: fixture.contents,
          },
        ]
      } else {
        []
      }
    None => []
  }
}

///|
fn harness_marker_range(model : @model.TextModel) -> @base_common.Range {
  let snapshot = model.snapshot
  if snapshot.line_count() >= 3 {
    let start = snapshot.offset_at_position({ line: 2, column: 2 })
    let end = snapshot.offset_at_position({ line: 2, column: 23 })
    Range(start, end)
  } else {
    let end = if snapshot.length() > 0 { 1 } else { 0 }
    Range(0, end)
  }
}
