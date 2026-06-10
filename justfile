default:
    just --list

check:
    moon check --target all --warn-list +73

test-moon:
    moon test --target all

test: test-moon

build-moon-web:
    moon run --target native scripts/build-web.mbtx

build: check build-moon-web
    moon build --target native server_host_native/main

dev *args: build
    sh -c 'ROOT=docs/fixtures/project; PORT=5173; ASSET_DIR=web/dist; for arg do case "$arg" in ROOT=*) ROOT="${arg#ROOT=}";; PORT=*) PORT="${arg#PORT=}";; ASSET_DIR=*) ASSET_DIR="${arg#ASSET_DIR=}";; esac; done; moon run --target native server_host_native/main -- --root "$ROOT" --port "$PORT" --asset-dir "$ASSET_DIR"' sh {{ args }}

test-browser: build
    ./node_modules/.bin/playwright test
