# viewer/hover

The content-hover feature for the readonly viewing path. A port of Monaco's
`contrib/hover/browser/`, reduced to what a readonly viewer needs. Depends on
viewer-adjacent services and provider contracts, but not on the browser `viewer`
package itself.

## Responsibilities

- Hover-part types and the merged result: `HoverPart`, `ComputedHover`,
  `HoverComputeContext` (the compute inputs — model, anchor, offset, inlay
  hints; never a services bag).
- The `HoverParticipant` trait and the built-in participants — marker,
  inlay-hint, and markdown — each capturing the services it needs at
  construction (Monaco's DI constructors), described by `HoverParticipantServices`.
- `HoverParticipantRegistry`: a free registry of participant factories with the
  process-wide `hover_participant_registry` and `register_default_hover_participants`
  — the analog of Monaco's `HoverParticipantRegistry` singleton populated by
  `hoverContribution.ts`. Registration lives here, never in the viewer services
  constructor.
- `ContentHoverComputer`: builds the registered participants for a given
  `HoverParticipantServices` and runs the sync/async compute passes (Monaco's
  `ContentHoverWidgetWrapper` + `ContentHoverComputer`).
- `render_hover_shell`: the content-hover widget's inner HTML, including fenced
  code blocks rendered through the viewer token classes.

The hover *controller* — the timing state machine (half/full/loading delays,
staleness tokens) and the `Viewer` event driver — stays in the `viewer` core,
because it is driven imperatively by the viewer and consumes the core's
editor-event types. Monaco breaks the equivalent edge through its generic
editor-contribution registry (`registerEditorContribution` / `getContribution`);
porting that registry is separate work, so until then the controller stays in
core. `viewer/hover` still owns everything the controller does *not* drive.

## Boundaries

- DOM-free: produces HTML strings, not DOM; no Rabbita framework. Builds on `js`
  and `native`.
- Depends on `base/common`, `language`, `platform/log`, `syntax`,
  `viewer/common`, `viewer/decorations`, `viewer/languages`, `viewer/markers`,
  `viewer/model`, `viewer/view_model`, and the `cmark` markdown packages.
- Depends on neither the `viewer` browser package nor any view part. The
  dependency edge is one-directional: `viewer -> viewer/hover`.
