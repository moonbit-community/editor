# Style Notes

## MoonBit Constructors

- Primary struct constructors use `fn Type::Type(...) -> Type` and are called as `Type(...)` or `@pkg.Type(...)`.
- Reserve named constructors such as `empty` or `from_array` for alternate construction paths.
- Canonical constructors may validate, normalize, or derive hidden fields.

## Tests

- Prefer inspect-family snapshots over long `assert_eq` chains when output shape matters.
- Use `inspect(..., content=...)` for stable `Show` output.
- Use `debug_inspect(..., content=...)` for structural `Debug` output.
- Use `@json.json_inspect(..., content=...)` for `ToJson` values and JSON-shaped output.
