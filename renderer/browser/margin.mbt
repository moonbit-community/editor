///|
priv struct MarginPart {
  margin : @rdom.Element
  margin_view_overlays : @rdom.Element
  folding : @rdom.Element
  line_numbers : @rdom.Element
}

///|
fn create_margin_part(document : @rdom.Document) -> MarginPart {
  let margin = document.create_element("div")
  margin.set_attribute("class", "margin")
  margin.set_attribute("data-view-part", "margin")
  margin.set_attribute("aria-hidden", "true")
  let margin_view_overlays = document.create_element("div")
  margin_view_overlays.set_attribute("class", "margin-view-overlays")
  margin_view_overlays.set_attribute("data-view-part", "margin-view-overlays")
  let folding = document.create_element("div")
  folding.set_attribute("class", "view-layer folding")
  folding.set_attribute("data-view-part", "folding")
  let line_numbers = document.create_element("div")
  line_numbers.set_attribute("class", "view-layer line-numbers")
  line_numbers.set_attribute("data-view-part", "line-numbers")
  margin_view_overlays.append_child(folding.as_node())
  margin_view_overlays.append_child(line_numbers.as_node())
  margin.append_child(margin_view_overlays.as_node())
  { margin, margin_view_overlays, folding, line_numbers }
}
