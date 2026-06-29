# View-zone `afterLineNumber`: view-line vs Monaco's model-line resolution

Status: known, intentional divergence (2026-06-29). Surfaced while landing
Track A of `docs/exec-plans/monaco-arch-divergence-closeout.md` (the 1-based
view-line-number rebase). Oracle pin: `vscode` submodule at `294fb350`.

## The divergence

The viewer's `ViewZone.anchor_line` (`viewer/view_layout/view_zone.mbt`) is fed
**directly as a view-line `afterLineNumber`** into the faithful `LinesLayout`
whitespace layer:

- `ViewLayout::build_lines` → `WhitespaceChangeAccessor::insert_whitespace(
  zone.anchor_line, …)` with no translation (`viewer/view_layout/view_layout.mbt`).
- `normalized_view_zones` clamps `anchor_line` into `[0, line_count]`.

Monaco's *public* `IViewZone.afterLineNumber` is a **model** line number. Its
`_computeWhitespaceProps`
(`src/vs/editor/browser/viewParts/viewZones/viewZones.ts`) resolves it to a
**view** line before handing it to `LinesLayout`:

```js
if (zone.afterLineNumber === 0) {
    return { afterViewLineNumber: 0, … };          // 0 = above the first line
}
const validAfterLineNumber = model.validatePosition({   // clamp to [1, lineCount]
    lineNumber: zone.afterLineNumber, column: 1 }).lineNumber;
… coordinatesConverter.convertModelPositionToViewPosition(zoneAfterModelPosition, …);
return { afterViewLineNumber: viewPosition.lineNumber, … };
```

So Monaco does a `model line → validatePosition → convertModelPositionToView`
step (plus `afterColumn`/`afterColumnAffinity` and hidden-area visibility) that
the viewer does not. The viewer ports only the **`afterViewLineNumber →
whitespace`** half; it does not port the **`model afterLineNumber →
afterViewLineNumber`** half.

## Why it is equivalent today

- The viewer's only view zone is the references peek — single-line, and
  addressed in view coordinates where **model ↔ view is 1:1**. With no soft wrap
  and no folding, `convertModelPositionToViewPosition` is the identity, so a
  view-line `afterLineNumber` equals what Monaco would compute.
- The clamp range matches: Monaco's `afterViewLineNumber` (the value that
  reaches `LinesLayout`) is `[0, viewLineCount]`, and `afterLineNumber === 0`
  is the explicit "above the first line" case. The viewer's `[0, line_count]`
  with `0` = above the first line is the same.
- Track A preserved this exactly: `anchor_line` is numerically Monaco's
  `afterLineNumber`, so the rebase changed only documentation, not zone numbers.
  All zone tests (incl. the browser references-peek scenario) passed unchanged.

### Plan-clamp correction

The Track A Phase-1 inventory prescribed clamping into `[1, line_count + 1]`.
That contradicts the plan's own goal of "expose Monaco's `afterLineNumber`
directly": `afterLineNumber`'s real range is `[0, lineCount]`, and the
`[1, line_count+1]` figure came from over-applying a "shift every 0-based
boundary by one" heuristic to a field that was already `afterLineNumber`.
Following it would clip `anchor_line = 0` up to `1`, deleting the above-first-line
position. The implemented clamp is `[0, line_count]` (= Monaco's
`afterViewLineNumber` range).

## When it would diverge

- **Soft wrap on (now supported, Track C) or folding:** a model line spans
  several view lines. If a caller passed a *model* line number as `anchor_line`,
  Monaco would place the zone at the view line at the **end** of that model
  line's wrapped/folded segments; the viewer would treat the number as a view
  line as-is and land the zone elsewhere. Today no caller does this (the peek is
  view-addressed and single-line), so it is latent.
- **Negative `anchor_line` (invalid input):** the viewer floors it to `0`
  (above the first line); Monaco's non-zero branch runs `validatePosition`, which
  floors `lineNumber` to `1` (after the first line). No caller passes this.

## Follow-up (if/when zones grow beyond the peek)

Port the `model afterLineNumber → afterViewLineNumber` step from
`_computeWhitespaceProps`: run the anchor through the coordinates converter
(model→view) and `validatePosition`, and decide a model- vs view-addressed zone
API. Until then, the viewer's zone API is documented as **view-addressed**, and
that is the lone seam between it and Monaco's `IViewZone`.
