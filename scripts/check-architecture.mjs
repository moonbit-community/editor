import { readFile, readdir } from 'node:fs/promises';
import { join, relative } from 'node:path';

const root = new URL('..', import.meta.url);
const productDirs = ['core', 'syntax', 'decorations', 'language', 'view', 'web', 'app', 'tests'];
const forbidden = ['codemirror/', 'vscode/'];
const errors = [];

for (const dir of productDirs) {
  for await (const file of walk(new URL(`${dir}/`, root))) {
    if (!/\.(mbt|js|mjs|ts|html|css)$/.test(file)) continue;
    const content = await readFile(file, 'utf8');
    for (const target of forbidden) {
      if (content.includes(target)) {
        errors.push(`${relative(root.pathname, file)} references forbidden tree ${target}`);
      }
    }
  }
}

if (errors.length > 0) {
  console.error(errors.join('\n'));
  process.exit(1);
}

console.log('Architecture checks passed');

async function* walk(url) {
  let entries;
  try {
    entries = await readdir(url, { withFileTypes: true });
  } catch {
    return;
  }
  for (const entry of entries) {
    const child = new URL(entry.name, url);
    if (entry.isDirectory()) {
      yield* walk(new URL(`${entry.name}/`, url));
    } else {
      yield child.pathname;
    }
  }
}
