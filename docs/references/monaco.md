# Monaco Reference Map

Monaco/VS Code is the primary reference for this project. Use it for readonly
viewer behavior, API shape, rendering roles, widget behavior, and conformance
tests. Copy roles and observable behavior, not runtime code, services, or
package names.

The VS Code submodule contains Monaco's editor implementation under
`vscode/src/vs/editor`.

Use these as design references only. Do not import from them in product code.
When Monaco and current local docs disagree, treat current local docs as the
product boundary and Monaco as the source to research before changing it.
