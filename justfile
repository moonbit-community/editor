default:
    just --list

check:
    moon check --warn-list +73

test-moon:
    moon test

test: test-moon

build-moon-web:
    moon run --target native scripts/build-web.mbtx

build: check build-moon-web
    ./node_modules/.bin/vite build

dev *args: build-moon-web
    ./node_modules/.bin/vite --host 127.0.0.1 {{ args }}

test-browser: build-moon-web
    ./node_modules/.bin/playwright test
