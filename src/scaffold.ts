/**
 * vbuilder — action: init
 *
 * Stamps the full project tree from templates/, vendors the flow/ snapshot,
 * optionally runs `git init` + first commit.
 *
 * @module vbuilder/scaffold
 */

import * as fs from "node:fs";
import * as path from "node:path";
import { execSync } from "node:child_process";
import { renderTree } from "./template.ts";
import type { VBuilderConfig, VBuilderResult } from "./types.ts";

/** The extension's own root (where flow/ and templates/ live). */
function extRoot(): string {
  // index.ts -> vbuilder/
  return path.dirname(path.dirname(new URL(import.meta.url).pathname));
}

/** Vendor a copy of flow/ into <project>/dv/flow/. */
function vendorFlow(projectDir: string): void {
  const src = path.join(extRoot(), "flow");
  const dst = path.join(projectDir, "dv", "flow");
  if (!fs.existsSync(src)) {
    throw new Error(`flow source not found at ${src} (extension install corrupt)`);
  }
  copyDir(src, dst);
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

/** Make shell scripts executable. */
function chmodScripts(projectDir: string): void {
  const dirs = [
    path.join(projectDir, "scripts"),
    path.join(projectDir, "dv", "regression"),
  ];
  for (const dir of dirs) {
    if (!fs.existsSync(dir)) continue;
    for (const f of fs.readdirSync(dir)) {
      if (f.endsWith(".sh")) {
        fs.chmodSync(path.join(dir, f), 0o755);
      }
    }
  }
}

export function init(cfg: VBuilderConfig): VBuilderResult {
  const force = cfg.force ?? false;
  const created: string[] = [];
  const patched: string[] = [];
  const warnings: string[] = [];

  const targetDir = path.resolve(cfg.targetDir);
  if (!fs.existsSync(targetDir)) {
    fs.mkdirSync(targetDir, { recursive: true });
  }

  // Template variables.
  const vars = {
    PROJECT: cfg.project,
    MODULE: cfg.module,
    DATA_WIDTH: cfg.dataWidth ?? 8,
    ports: cfg.ports ?? [],
    params: cfg.params ?? [],
    GOLDEN_LANG: cfg.goldenLang ?? "python",
    GOLDEN_MODE: cfg.goldenMode ?? "file",
  };

  // 1. Render the whole templates/ tree (rtl, dv, golden, docs, root).
  const templatesDir = path.join(extRoot(), "templates");
  const { written, skipped } = renderTree(templatesDir, targetDir, vars, force);
  created.push(...written);
  if (skipped.length > 0) {
    warnings.push(`${skipped.length} files skipped (already exist; use force to overwrite)`);
  }

  // 2. Vendor the flow library into dv/flow/.
  vendorFlow(targetDir);
  created.push("dv/flow/ (vendored)");

  // 3. Ensure vectors/error_injected dir exists.
  fs.mkdirSync(path.join(targetDir, "golden", "vectors", "error_injected"), { recursive: true });

  // 4. Make scripts executable.
  chmodScripts(targetDir);

  // 5. Optionally git init + first commit.
  if (cfg.gitInit ?? true) {
    try {
      if (!fs.existsSync(path.join(targetDir, ".git"))) {
        execSync("git init -q", { cwd: targetDir });
      }
      execSync('git add -A && git -c user.name="vbuilder" -c user.email="vbuilder@local" ' +
        'commit -q -m "vbuilder init: scaffold ' + cfg.project + '"', { cwd: targetDir });
      patched.push("git: initial commit");
    } catch (e) {
      warnings.push(`git init/commit failed: ${(e as Error).message}`);
    }
  }

  return {
    action: "init",
    created,
    patched,
    warnings,
    flowVersion: "0.1.0",
  };
}
