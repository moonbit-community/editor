# Style Notes

## Docs

- Prefer concise current-truth docs over detailed historical narration.
- Put architecture and ownership rules in `docs/architecture.md`.
- Put package-local contracts and checks in package READMEs.
- Put large future implementation plans in `docs/exec-plans/`.
- Do not update implemented execution plans to match newer architecture. Add a
  superseding plan or update current docs instead.

## MoonBit Constructors

- Primary struct constructors use `fn Type::Type(...) -> Type` and are called as `Type(...)` or `@pkg.Type(...)`.
- Reserve named constructors such as `empty` or `from_array` for alternate construction paths.
- Canonical constructors may validate, normalize, or derive hidden fields.

## Documentation Comments

- Write prose documentation for exported package contracts: public types, traits, constructors, functions, provider APIs, protocol packets, and host FFI bindings that another package or embedder may call.
- Internal declarations need prose only when they carry a non-obvious invariant, algorithm, reference-source mapping, host boundary, coordinate convention, async freshness rule, or wire/DOM contract.
- Bare `///|` separators are allowed for MoonBit block structure, but they do not count as documentation. Replace them with real prose when a declaration falls under the previous rules.
- Keep comments focused on behavior, constraints, ownership, and caller obligations. Do not repeat the type signature or restate obvious field names.
- Tests, generated fixtures, and small private helpers do not need prose unless a future reader would otherwise miss the intent of the case.

## Tests

- Prefer inspect-family snapshots over long `assert_eq` chains when output shape matters.
- Use `inspect(..., content=...)` for stable `Show` output.
- Use `debug_inspect(..., content=...)` for structural `Debug` output.
- Use `@json.json_inspect(..., content=...)` for `ToJson` values and JSON-shaped output.
