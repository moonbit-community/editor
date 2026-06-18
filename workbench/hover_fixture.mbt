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
fn register_harness_hover_provider(services : @browser.ViewerServices) -> Unit {
  let provider = HarnessHoverProvider::{  }
  let selector = @language.LanguageSelector::LanguageFilter(
    LanguageFilter(scheme="readonly-remote"),
  )
  services.language_features.register_hover_provider(selector, provider)
  |> ignore
  services.language_features.register_diagnostics_provider(selector, provider)
  |> ignore
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
    Some(viewer) => viewer.refresh_document_features()
    None => ()
  }
}

///|
impl @language.HoverProvider for HarnessHoverProvider with fn provide_hover(
  _self,
  document,
  position,
  _token,
) {
  match harness_hover_fixture.val {
    Some(fixture) =>
      if fixture.kind == "marker" {
        Some({ range: harness_marker_range(document), contents: [] })
      } else {
        let text = document.text
        let offset = document.offset_at_position(position)
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
  document,
  _token,
) {
  match harness_hover_fixture.val {
    Some(fixture) =>
      if fixture.kind == "marker" {
        [
          {
            range: harness_marker_range(document),
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
fn harness_marker_range(
  document : @workspace.DocumentSnapshot,
) -> @base_common.Range {
  if document.line_count() >= 3 {
    let start = document.offset_at_position({ line: 2, column: 2 })
    let end = document.offset_at_position({ line: 2, column: 23 })
    Range(start, end)
  } else {
    let end = if document.length() > 0 { 1 } else { 0 }
    Range(0, end)
  }
}
