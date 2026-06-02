# Style Notes

## MoonBit Constructors

- Prefer MoonBit same-name struct constructors for a type's primary constructor: define `fn Type::Type(...) -> Type` and call it as `Type(...)` or `@pkg.Type(...)`.
- Do not expose a primary constructor as `Type::new`; reserve named constructors such as `empty`, `from_array`, or other descriptive names for alternate construction paths.
- Use a same-name constructor even when construction performs validation, normalization, or derives hidden fields, as long as it is still the canonical way to create that type.
