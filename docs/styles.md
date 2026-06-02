# Style Notes

## MoonBit Constructors

- Primary struct constructors use `fn Type::Type(...) -> Type` and are called as `Type(...)` or `@pkg.Type(...)`.
- Reserve named constructors such as `empty` or `from_array` for alternate construction paths.
- Canonical constructors may validate, normalize, or derive hidden fields.
