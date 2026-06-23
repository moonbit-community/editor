///|
fn text_model_from_document(
  document : @workspace.DocumentSnapshot,
) -> @model.TextModel {
  TextModel(
    document.uri,
    document.display_name,
    document.language_id,
    1,
    document.revision,
    document.text,
  )
}

///|
fn document_from_text_model(
  model : @model.TextModel,
) -> @workspace.DocumentSnapshot {
  DocumentSnapshot(
    model.uri,
    model.display_name,
    model.language_id,
    model.revision,
    model.snapshot.text,
  )
}
