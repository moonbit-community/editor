# Readonly MoonBit Editor

This repository is a from-scratch readonly code viewer built in MoonBit, with
Monaco and CodeMirror checked in as reference-only submodules.

## Quick Start

```sh
npm install
npm run check
npm run dev
```

The first milestone is a browser viewer backed by immutable MoonBit document,
syntax, decoration, language-provider, and render-model packages.

## Validation

```sh
npm run check
npm run test
npm run build
npm run test:browser
```

See [docs/architecture.md](docs/architecture.md) and [docs/harness.md](docs/harness.md).
