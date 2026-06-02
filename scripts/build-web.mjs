import { copyFile, mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const moon = spawnSync('moon', ['build', '--target', 'js', 'web'], {
  cwd: root,
  stdio: 'inherit'
});

if (moon.status !== 0) {
  process.exit(moon.status ?? 1);
}

const sourceDir = resolve(root, '_build/js/debug/build/web');
const targetDir = resolve(root, 'web/generated');
await mkdir(targetDir, { recursive: true });
const generatedJs = await readFile(resolve(sourceDir, 'web.js'), 'utf8');
await writeFile(
  resolve(targetDir, 'editor.mjs'),
  generatedJs.replace('//# sourceMappingURL=web.js.map', '//# sourceMappingURL=editor.mjs.map')
);
await copyFile(resolve(sourceDir, 'web.js.map'), resolve(targetDir, 'editor.mjs.map'));
await copyFile(resolve(sourceDir, 'moonbit.d.ts'), resolve(targetDir, 'moonbit.d.ts'));
await copyFile(resolve(sourceDir, 'web.d.ts'), resolve(targetDir, 'web.d.ts'));

console.log('Generated web/generated/editor.mjs');
