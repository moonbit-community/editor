///|
test "demo providers expose hover diagnostic and definition" {
  let doc = @core.DocumentSnapshot("fn main { // TODO\n }")
  let providers = demo_providers(doc)
  assert_eq(providers.hovers.length(), 1)
  assert_eq(providers.diagnostics.length(), 1)
  assert_eq(providers.definitions.length(), 1)
  assert_eq(providers.definitions[0].uri.to_string(), "memory://fixture.mbt")
  let hover = providers.hover_at(3)
  match hover {
    Some(item) => assert_eq(item.contents, "Demo hover: entry point symbol")
    None => fail("expected hover")
  }
}
