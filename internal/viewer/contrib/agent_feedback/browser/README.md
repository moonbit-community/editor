# internal/viewer/contrib/agent_feedback/browser

The JS-only agent-feedback editor widgets and contribution state. It owns the
inline feedback input, grouped comment widgets, DOM event wiring, measurement,
layout state, and Markdown rendering used by the root Viewer.

This package depends on the DOM-free implementation in
`internal/viewer/contrib/agent_feedback`; public host values remain in
`viewer/common/agent_feedback_api`. The emitted stylesheet remains at the
stable asset path
`viewer/contrib/agent_feedback/browser/agent_feedback.css`.

Exact callable types are in `pkg.generated.mbti`. Check this JS-only package
with:

```sh
moon check internal/viewer/contrib/agent_feedback/browser --target js
```
