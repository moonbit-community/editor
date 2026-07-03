// The inlay-hints producer: converts provider hints into `after`
// injected-text decorations, the storage Monaco's `InlayHintsController`
// writes (`inlayHintsController.ts` `_updateHintsDecorators`:
// `{ range: fromPositions(position), options: { description, showIfCollapsed,
// after: { content, inlineClassName, attachedData } } }`). The projection
// reads injected text back from the model's decoration storage
// (deviations-closeout Track F deleted the parallel `Array[InjectedText]`
// pipeline). The label padding / class-name derivation previously lived with
// the deleted `InjectedText::from_inlay_hint`.

///|
/// Rewrites this editor's inlay-hint decorations from the current provider
/// result. The decoration-change event (with `affects_injected_text`)
/// triggers the projection rebuild.
fn Viewer::sync_inlay_hint_decorations(self : Viewer) -> Unit {
  guard self.text_model is Some(model) else { return }
  if self.inlay_hints.is_empty() && self.inlay_hint_decoration_ids.is_empty() {
    return
  }
  self.inlay_hint_decoration_ids = model.delta_decorations(
    self.inlay_hint_decoration_ids,
    inlay_hint_delta_decorations(self.inlay_hints),
    owner_id=self.editor_id,
  )
}

///|
/// One collapsed `after`-injected-text decoration per non-empty hint.
fn inlay_hint_delta_decorations(
  hints : Array[@language.InlayHint],
) -> Array[@model.DeltaDecoration] {
  let decorations : Array[@model.DeltaDecoration] = []
  for index in 0..<hints.length() {
    let hint = hints[index]
    let content = padded_inlay_hint_label(hint)
    if content.length() == 0 {
      continue
    }
    decorations.push({
      range: Range(
        hint.position.line_number,
        hint.position.column,
        hint.position.line_number,
        hint.position.column,
      ),
      options: Decoration(
        "",
        description="inlay-hint",
        // A collapsed range must survive the injected-text tree's
        // `showIfCollapsed || !isEmpty` query filter (Monaco sets it too).
        show_if_collapsed=true,
        after=@model.ModelInjectedTextOptions(
          content,
          inline_class_name=inlay_hint_class_name(hint),
          attached_index=index,
        ),
      ),
    })
  }
  decorations
}

///|
fn padded_inlay_hint_label(hint : @language.InlayHint) -> String {
  let builder = StringBuilder()
  if hint.padding_left {
    builder.write_string(" ")
  }
  builder.write_string(hint.label)
  if hint.padding_right {
    builder.write_string(" ")
  }
  builder.to_string()
}

///|
fn inlay_hint_class_name(hint : @language.InlayHint) -> String {
  match hint.kind {
    Some(TypeHint) => "inlay-hint inlay-hint-type"
    Some(ParameterHint) => "inlay-hint inlay-hint-parameter"
    None => "inlay-hint"
  }
}
