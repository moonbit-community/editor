///|
fn computer_test_model() -> @model.TextModel {
  TextModel(
    @base_common.Uri::memory("hover-test.mbt"),
    "hover-test.mbt",
    "moonbit",
    7,
    "rev-7",
    "fn main {\n  value\n}\n",
  )
}

///|
async test "content hover computer separates sync markers from async markdown" {
  let languages = @languages.Languages::new()
  let markers = @markers.MarkerService::new()
  let marker_decorations = @markers.MarkerDecorationsService::new(markers)
  let model = computer_test_model()
  markers.set_diagnostics("diagnostics:0", model.uri, [
    { range: OffsetRange(12, 17), severity: Warning, message: "marker hover" },
  ])
  languages.register_hover_provider(LanguageId("moonbit"), ComputerHoverProvider::{

  })
  |> ignore
  let services : HoverParticipantServices = {
    languages,
    marker_decorations,
    log_service: @log.LogService::new(),
  }
  let computer = ContentHoverComputer::new(services)
  let sync_hover = computer.compute_sync(model, OffsetRange(12, 17), 14)
  match sync_hover {
    Some(hover) => {
      assert_eq(hover.parts.length(), 1)
      assert_true(hover.parts[0] is MarkerHover(_))
    }
    None => fail("expected marker hover")
  }
  let async_hover = computer.compute_async(model, OffsetRange(12, 17), 14)
  match async_hover {
    Some(hover) => {
      assert_eq(hover.parts.length(), 1)
      assert_true(hover.parts[0] is MarkdownHover(_))
    }
    None => fail("expected markdown hover")
  }
}

///|
priv struct ComputerHoverProvider {}

///|
impl @language.HoverProvider for ComputerHoverProvider with fn provide_hover(
  _self,
  model,
  position,
  _token,
) {
  let offset = model.snapshot.offset_at_position(position)
  Some({
    range: OffsetRange(offset, offset + 1),
    contents: [PlainText("provider hover")],
  })
}
