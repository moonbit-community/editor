# viewer/contrib/hover

The content-hover feature for the readonly viewing path: a port of Monaco's
`contrib/hover/browser/` with the DOM-free logic hoisted into this
multi-target package. The root `viewer` package only dispatches editor events
into it and mounts the widget DOM through
`viewer/browser/view_parts/content_widgets`.

## Responsibilities

- `HoverController`: the hover state machine — scheduling delays, staleness
  tokens, sticky-hover reconciliation, async part arrival, and the derived
  `HoverWidgetView` the content-widgets part renders. Driven through
  `on_event(EditorEvent, EditorContext)`; the `Viewer`-facing dispatch glue
  stays in the root package (foreign-method rule).
- Hover-part types and the merged result: `HoverPart`, `ComputedHover`,
  `HoverComputeContext` (the compute inputs — model, anchor, inlay hints;
  never a services bag).
- The `hoverTypes.ts` anchor types (`hover_anchor.mbt`): `HoverAnchor` as
  Monaco's `HoverRangeAnchor` (the mouse position as a collapsed model range)
  / `HoverForeignElementAnchor` (the inlay participant's, carrying the hint
  index), with the source's `equals`/`canAdoptVisibleHover` semantics, plus
  `find_anchor_candidates` — the wrapper's `suggestHoverAnchor` +
  CONTENT_TEXT / CONTENT_EMPTY-epsilon candidate pass.
- The `HoverParticipant` trait and the built-in participants — marker,
  inlay-hint, and markdown — each capturing the services it needs at
  construction (Monaco's DI constructors), described by
  `HoverParticipantServices`.
- `HoverParticipantRegistry`: a free registry of participant factories with the
  process-wide `hover_participant_registry` and
  `register_default_hover_participants` — the analog of Monaco's
  `HoverParticipantRegistry` singleton populated by `hoverContribution.ts`.
- `ContentHoverComputer`: builds the registered participants for a given
  `HoverParticipantServices` and runs the sync/async compute passes.
- `render_hover_shell` and the widget geometry: the content-hover widget's
  inner HTML (fenced code blocks rendered through the viewer token classes)
  and the DOM-free placement/size math.

## Boundaries

- DOM-free: produces HTML strings and geometry, not DOM; no Rabbita framework.
  Multi-target (`js` and `native`) so the native build enforces DOM-freeness.
- Exact imports live in `moon.pkg` (`base/common`, `language`, `platform/log`,
  `syntax`, `viewer/common`, `viewer/common/{model,languages,markers,view_model}`,
  and the `cmark` markdown packages).
- Depends on neither the root `viewer` package nor any view part. The
  dependency edge is one-directional: `viewer -> viewer/contrib/hover`.
