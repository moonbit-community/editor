///|
test "public languages facade registers hover providers" {
  let disposable = @languages.languages.register_hover_provider(
    LanguageId("moonbit"),
    PublicHoverProvider::{  },
  )
  disposable.dispose()
}

///|
priv struct PublicHoverProvider {}

///|
impl @language.HoverProvider for PublicHoverProvider with fn provide_hover(
  _self,
  _document,
  _position,
  _token,
) {
  None
}
