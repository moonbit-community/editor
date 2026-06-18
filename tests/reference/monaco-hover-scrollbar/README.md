# Monaco Hover Scrollbar Oracle

This fixture is a local Playwright oracle for
`docs/exec-plans/monaco-hover-scrollbar-conformance.md`.

It is pinned to VS Code submodule commit
`294fb350837dbaee37b949533fead4df4e0e8971` by copying the DOM, class, CSS, and
geometry constants needed by the conformance specs. It does not import runtime
code from `vscode/`; product code also must not import from that submodule.
