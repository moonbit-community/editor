const { readdirSync, readFileSync } = require("node:fs");
const { join } = require("node:path");

const productDirs = [
  "core",
  "syntax",
  "decorations",
  "language",
  "view",
  "dom",
  "web",
  "app",
  "tests",
];
const forbidden = ["codemirror/", "vscode/"];
const jsFfiMarker = 'extern "' + 'js"';
const wanted = /\.(mbt|js|mjs|ts|html|css)$/;
const errors = [];

function sourceFiles(dir) {
  const files = [];

  function walk(relativeDir) {
    let entries;
    try {
      entries = readdirSync(join(process.cwd(), relativeDir), {
        withFileTypes: true,
      });
    } catch {
      return;
    }

    for (const entry of entries) {
      const relativePath = `${relativeDir}/${entry.name}`;
      if (entry.isDirectory()) {
        walk(relativePath);
      } else if (wanted.test(relativePath)) {
        files.push(relativePath);
      }
    }
  }

  walk(dir);
  return files;
}

for (const dir of productDirs) {
  for (const file of sourceFiles(dir)) {
    const content = readFileSync(join(process.cwd(), file), "utf8");

    for (const target of forbidden) {
      if (content.includes(target)) {
        errors.push(`${file} references forbidden tree ${target}`);
      }
    }

    if (content.includes(jsFfiMarker) && !file.startsWith("dom/")) {
      errors.push(`${file} declares JavaScript FFI outside dom package`);
    }
  }
}

if (errors.length > 0) {
  console.error(errors.join("\n"));
  process.exit(1);
}

console.log("Architecture checks passed");
