/**
 * vbuilder — action: upgrade-flow
 *
 * Re-vendors the flow/ snapshot from the extension into a project's dv/flow/.
 * Lets projects pick up flow fixes without re-running init.
 *
 * @module vbuilder/upgrade-flow
 */

import * as fs from "node:fs";
import * as path from "node:path";
import type { VBuilderResult } from "./types.ts";

function extRoot(): string {
  return path.dirname(path.dirname(new URL(import.meta.url).pathname));
}

function copyDir(src: string, dst: string): void {
  fs.mkdirSync(dst, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const s = path.join(src, entry.name);
    const d = path.join(dst, entry.name);
    if (entry.isDirectory()) copyDir(s, d);
    else fs.copyFileSync(s, d);
  }
}

export function upgradeFlow(projectDir: string): VBuilderResult {
  const dst = path.join(path.resolve(projectDir), "dv", "flow");
  const src = path.join(extRoot(), "flow");
  if (!fs.existsSync(src)) {
    throw new Error(`flow source not found at ${src}`);
  }
  // Remove old vendored flow, then re-copy.
  if (fs.existsSync(dst)) {
    fs.rmSync(dst, { recursive: true });
  }
  copyDir(src, dst);
  return {
    action: "upgrade-flow",
    created: ["dv/flow/ (re-vendored)"],
    patched: [],
    warnings: [],
    flowVersion: extractVersion(fs.readFileSync(path.join(dst, "flow.mk"), "utf8")),
  };
}

function extractVersion(content: string): string {
  const m = content.match(/FLOW_VERSION\s*[:?]?=\s*([0-9.]+)/);
  return m ? m[1] : "unknown";
}
