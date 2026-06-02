const { spawnSync } = require("node:child_process");
const {
  copyFileSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
} = require("node:fs");

const result = spawnSync("moon", ["build", "--target", "js", "web"], {
  cwd: process.cwd(),
  stdio: "inherit",
});

const status = result.status ?? 1;
if (status !== 0) {
  process.exit(status);
}

const sourceDir = "_build/js/debug/build/web";
const targetDir = "web/generated";
mkdirSync(targetDir, { recursive: true });

const generatedJs = readFileSync(`${sourceDir}/web.js`, "utf8");
writeFileSync(
  `${targetDir}/editor.mjs`,
  generatedJs.replace(
    "//# sourceMappingURL=web.js.map",
    "//# sourceMappingURL=editor.mjs.map",
  ),
);

copyFileSync(`${sourceDir}/web.js.map`, `${targetDir}/editor.mjs.map`);
copyFileSync(`${sourceDir}/moonbit.d.ts`, `${targetDir}/moonbit.d.ts`);
copyFileSync(`${sourceDir}/web.d.ts`, `${targetDir}/web.d.ts`);

console.log("Generated web/generated/editor.mjs");
