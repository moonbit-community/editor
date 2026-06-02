default:
    just --list

check:
    moon check --warn-list +73
    moon run --target js scripts/check-architecture.mbtx

test:
    moon test

build-moon-web:
    moon run --target js scripts/build-web.mbtx

build: check build-moon-web
    ./node_modules/.bin/vite build

dev *args: build-moon-web
    ./node_modules/.bin/vite --host 127.0.0.1 {{ args }}

test-browser: build-moon-web
    ./node_modules/.bin/playwright test
