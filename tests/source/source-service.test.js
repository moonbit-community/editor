import assert from 'node:assert/strict';
import { promises as fs } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import { createSourceService } from '../../server/source-service.js';

test('reads only valid root-relative text files', async () => {
  const root = await makeRoot();
  await fs.writeFile(join(root, 'ok.mbt'), 'pub fn main {}\n');
  await fs.mkdir(join(root, 'nested'));
  await fs.writeFile(join(root, 'nested', 'file.txt'), 'plain\n');
  await fs.writeFile(join(root, 'binary.bin'), Buffer.from([0, 1, 2]));

  const service = createSourceService({ roots: [root] });
  const document = await service.read('ok.mbt');

  assert.equal(document.displayName, 'ok.mbt');
  assert.equal(document.languageId, 'moonbit');
  assert.equal(document.version, 1);
  assert.equal(document.text, 'pub fn main {}\n');
  assert.equal((await service.read('ok.mbt')).version, 1);
  assert.equal((await service.read('nested/file.txt')).languageId, 'plaintext');

  await assert.rejects(() => service.read('/etc/passwd'), hasCode('InvalidPath'));
  await assert.rejects(() => service.read('../outside.mbt'), hasCode('InvalidPath'));
  await assert.rejects(() => service.read('nested'), hasCode('IsDirectory'));
  await assert.rejects(() => service.read('missing.mbt'), hasCode('FileNotFound'));
  await assert.rejects(() => service.read('binary.bin'), hasCode('BinaryFile'));

  await fs.rm(root, { recursive: true, force: true });
});

test('rejects symlink escapes from the allowed root', { skip: process.platform === 'win32' }, async () => {
  const root = await makeRoot();
  const outside = await makeRoot();
  await fs.writeFile(join(outside, 'secret.mbt'), 'secret\n');
  await fs.symlink(outside, join(root, 'link'));

  const service = createSourceService({ roots: [root] });

  await assert.rejects(() => service.read('link/secret.mbt'), hasCode('OutsideRoot'));

  await fs.rm(root, { recursive: true, force: true });
  await fs.rm(outside, { recursive: true, force: true });
});

test('debounces watcher events and skips unchanged content', async () => {
  const root = await makeRoot();
  const filePath = join(root, 'watched.mbt');
  await fs.writeFile(filePath, 'let value = "one"\n');

  const service = createSourceService({ roots: [root], debounceMs: 30 });
  await service.read('watched.mbt');

  const events = [];
  const subscription = await service.subscribe('watched.mbt', (event) => {
    events.push(event);
  });
  await wait(50);

  await fs.writeFile(filePath, 'let value = "two"\n');
  await wait(10);
  await fs.writeFile(filePath, 'let value = "three"\n');

  await waitFor(() => events.filter((event) => event.type === 'document').length === 1);
  const documentEvent = events.find((event) => event.type === 'document');
  assert.equal(documentEvent.data.version, 2);
  assert.equal(documentEvent.data.text, 'let value = "three"\n');

  events.length = 0;
  await fs.writeFile(filePath, 'let value = "three"\n');
  await wait(120);
  assert.equal(events.length, 0);

  await fs.unlink(filePath);
  await waitFor(() => events.some((event) => event.type === 'missing'));

  await fs.writeFile(filePath, 'let value = "four"\n');
  await waitFor(() => events.some((event) => event.type === 'document'));
  assert.equal(events.at(-1).data.text, 'let value = "four"\n');

  subscription.dispose();
  await fs.rm(root, { recursive: true, force: true });
});

async function makeRoot() {
  return fs.mkdtemp(join(tmpdir(), 'readonly-editor-'));
}

function hasCode(code) {
  return (error) => error?.code === code;
}

async function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitFor(predicate) {
  const deadline = Date.now() + 3000;
  while (Date.now() < deadline) {
    if (predicate()) {
      return;
    }
    await wait(20);
  }
  assert.fail('timed out waiting for condition');
}
