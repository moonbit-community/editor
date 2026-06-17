import { expect, test } from '../support/test.js';
import { workspaceItem as workspaceSelector } from '../support/app.js';

// Proves the library boundary: the embedded page runs the viewer and the
// file-tree widget against in-memory providers, with no websocket opened.
test('runs the viewer and tree from in-memory providers without a server', async ({ page }) => {
  const websockets = [];
  page.on('websocket', (ws) => websockets.push(ws.url()));

  await page.goto('/embed.html');

  // The embedding host auto-opens src/main.mbt; auto-reveal expands src.
  await expect(page.locator('.editor-shell')).toHaveAttribute('data-status', 'ready');
  await expect(page.locator('.monaco-editor.readonly-editor')).toContainText('fn main');

  // Real language highlighting with no server: the MoonBit lexer is
  // registered by the embedding host, not fetched from anywhere.
  await expect(page.locator('.tok-keyword', { hasText: 'fn' }).first()).toBeVisible();
  await expect(page.locator(workspaceItem('src'))).toHaveAttribute('aria-expanded', 'true');
  await expect(page.locator(workspaceItem('src/main.mbt'))).toHaveAttribute(
    'aria-selected',
    'true',
  );

  // Nested folders resolve lazily on expand.
  await expect(page.locator(workspaceItem('src/lib/util.mbt'))).toHaveCount(0);
  await page.locator(workspaceItem('src/lib')).click();
  await expect(page.locator(workspaceItem('src/lib'))).toHaveAttribute('aria-expanded', 'true');

  // Navigating between files goes through the in-memory document source.
  await page.locator(workspaceItem('src/lib/util.mbt')).click();
  await expect(page.locator('.monaco-editor.readonly-editor')).toContainText('util_answer');
  await expect(page.locator(workspaceItem('src/lib/util.mbt'))).toHaveAttribute(
    'aria-selected',
    'true',
  );

expect(websockets).toEqual([]);
});

function workspaceItem(path) {
  return workspaceSelector(path, { root: 'memory://workspace' });
}
