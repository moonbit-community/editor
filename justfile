default:
    just --list

check:
    moon check --warn-list +73
    node scripts/check-architecture.js

test:
    moon test

build-moon-web:
    node scripts/build-web.js

build: check build-moon-web
    ./node_modules/.bin/vite build

dev *args: build-moon-web
    ./node_modules/.bin/vite --host 127.0.0.1 {{ args }}

test-browser: build-moon-web
    ./node_modules/.bin/playwright test
