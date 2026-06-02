# Readonly MoonBit Editor

This repository is a from-scratch readonly code viewer built in MoonBit, with
Monaco and CodeMirror checked in as reference-only submodules.

## Quick Start

```sh
npm install
just check
just dev
```

The first milestone is a browser viewer backed by immutable MoonBit document,
syntax, decoration, language-provider, and render-model packages.

## Validation

```sh
just check
just test
just build
just test-browser
```

See [docs/architecture.md](docs/architecture.md) and [docs/harness.md](docs/harness.md).
