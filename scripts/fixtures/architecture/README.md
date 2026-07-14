# Architecture policy fixtures

Files ending in `.moon.pkg.fixture` are intentionally excluded from Moon's
package discovery. `scripts/check-architecture.mbtx` parses them directly as
negative policy cases, so forbidden imports can remain checked in without
making the repository itself architecturally invalid.
