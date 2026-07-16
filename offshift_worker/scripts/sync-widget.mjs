import { cpSync, mkdirSync, readdirSync, rmSync } from "node:fs";
import { resolve } from "node:path";
import { execFileSync } from "node:child_process";

const workerDir = resolve(import.meta.dirname, "..");
const rootDir = resolve(workerDir, "..");
const assetsDir = resolve(rootDir, "assets");
const publicDir = resolve(workerDir, "public");
const pnpm = process.platform === "win32" ? "pnpm.cmd" : "pnpm";

execFileSync(pnpm, ["run", "build", "--target", "offshift"], {
  cwd: rootDir,
  stdio: "inherit",
});

const available = readdirSync(assetsDir).filter((entry) => entry.startsWith("offshift"));
const js = available.find((entry) => /^offshift-[a-f0-9]+\.js$/.test(entry));
const css = available.find((entry) => /^offshift-[a-f0-9]+\.css$/.test(entry));
if (!js || !css) {
  throw new Error(`Expected hashed Offshift JS and CSS after the widget build. Available: ${available.join(", ") || "none"}`);
}

rmSync(publicDir, { recursive: true, force: true });
mkdirSync(publicDir, { recursive: true });
cpSync(resolve(assetsDir, js), resolve(publicDir, "offshift.js"));
cpSync(resolve(assetsDir, css), resolve(publicDir, "offshift.css"));
