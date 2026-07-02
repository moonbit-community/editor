// The public decoration API slice of Monaco's `codeEditorWidget.ts`
// (decoration plan Phase 5), vscode submodule commit
// 294fb350837dbaee37b949533fead4df4e0e8971:
// `deltaDecorations` (:1368), `removeDecorations` (:1380),
// `getLineDecorations` (:1342), `getDecorationsInRange` (:1350).
//
// Deviations: the no-model `null` returns are empty arrays (MoonBit
// signatures stay non-optional, matching the viewer's public read API
// conventions); `filterFontDecorations` is constantly false (font
// decorations out of scope); `createDecorationsCollection` stays DEFERRED
// until a host asks (plan out-of-scope list).

///|
/// `deltaDecorations` (`codeEditorWidget.ts:1368-1378`): atomically replace
/// `old_decorations` (ids) with `new_decorations`, owned by this viewer
/// (`ownerId` = the viewer's editor id). Returns the new decoration ids.
/// Decoration state lives on the model, so it follows the model across
/// `set_model` swaps like Monaco's — re-apply on swap.
pub fn Viewer::delta_decorations(
  self : Viewer,
  old_decorations : Array[String],
  new_decorations : Array[@model.DeltaDecoration],
) -> Array[String] {
  guard self.text_model is Some(model) else { return [] }
  if old_decorations.length() == 0 && new_decorations.length() == 0 {
    return old_decorations
  }
  model.delta_decorations(
    old_decorations,
    new_decorations,
    owner_id=self.editor_id,
  )
}

///|
/// `removeDecorations` (`codeEditorWidget.ts:1380-1387`): delta to empty
/// through one `change_decorations` bracket.
pub fn Viewer::remove_decorations(
  self : Viewer,
  decoration_ids : Array[String],
) -> Unit {
  guard self.text_model is Some(model) && decoration_ids.length() > 0 else {
    return
  }
  model.change_decorations(accessor => {
    ignore((accessor.delta_decorations)(decoration_ids, []))
  })
}

///|
/// `getLineDecorations` (`codeEditorWidget.ts:1342-1348`): the model's line
/// query filtered by this viewer's editor id and its
/// `renderValidationDecorations` option.
pub fn Viewer::get_line_decorations(
  self : Viewer,
  line_number : Int,
) -> Array[@model.ModelDecoration] {
  guard self.text_model is Some(model) else { return [] }
  model.get_line_decorations(
    line_number,
    owner_id=self.editor_id,
    filter_out_validation=@view_model.filter_validation_decorations(
      self.options.render_validation_decorations,
    ),
  )
}

///|
/// `getDecorationsInRange` (`codeEditorWidget.ts:1350-1356`).
pub fn Viewer::get_decorations_in_range(
  self : Viewer,
  range : @base_common.Range,
) -> Array[@model.ModelDecoration] {
  guard self.text_model is Some(model) else { return [] }
  model.get_decorations_in_range(
    range,
    owner_id=self.editor_id,
    filter_out_validation=@view_model.filter_validation_decorations(
      self.options.render_validation_decorations,
    ),
  )
}
