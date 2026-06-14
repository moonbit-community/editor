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
fn register_harness_hover_provider() -> Unit {
  @browser.register_hover_provider(HarnessHoverProvider::{  })
  @dom.install_hover_fixture_control((kind, contents) => {
    harness_hover_fixture.val = if contents == "" {
      None
    } else {
      Some({ kind, contents })
    }
  })
}

///|
impl @language.HoverProvider for HarnessHoverProvider with fn hover_at(
  _self,
  document,
  offset,
) {
  match harness_hover_fixture.val {
    Some(fixture) => {
      let start = @core.clamp_int(offset, 0, document.text.length())
      let end = @core.clamp_int(start + 1, start, document.text.length())
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
