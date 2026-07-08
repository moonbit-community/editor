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
  marker_decorations.on_model_added(model)
  markers.set_diagnostics("diagnostics:0", model.uri, [
    {
      range: Range(2, 3, 2, 8),
      severity: Warning,
      message: "marker hover",
      tags: None,
    },
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
  let anchor : HoverAnchor = HoverRangeAnchor(
    priority=0,
    range=Range(2, 3, 2, 8),
    initial_mouse_pos_x=None,
    initial_mouse_pos_y=None,
  )
  let sync_hover = computer.compute_sync(model, anchor)
  match sync_hover {
    Some(hover) => {
      assert_eq(hover.parts.length(), 1)
      assert_true(hover.parts[0] is MarkerHover(_))
    }
    None => fail("expected marker hover")
  }
  let async_hover = computer.compute_async(model, anchor)
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
  let offset = model.get_offset_at(position)
  Some({
    range: model.snapshot.range_of(OffsetRange(offset, offset + 1)),
    contents: [PlainText("provider hover")],
  })
}
