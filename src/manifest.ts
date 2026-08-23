/**
 * vbuilder — project manifest (.vbuilder.json)
 *
 * Written once by `init`, read back by add_module / add_test so later-stamped
 * artifacts inherit the project's real module name and data width (instead of
 * hardcoded guesses).
 *
 * @module vbuilder/manifest
 */

import * as fs from "node:fs";
import * as path from "node:path";
import type { ProjectManifest, VBuilderConfig } from "./types.ts";

/** Manifest file name at the project root. */
export const MANIFEST_FILE = ".vbuilder.json";

/**
 * Write the manifest. Refuses to clobber an existing one (idempotent re-init).
 * @returns true if written, false if it already existed.
 */
export function saveManifest(projectDir: string, cfg: VBuilderConfig): boolean {
  const dst = path.join(projectDir, MANIFEST_FILE);
  if (fs.existsSync(dst)) return false;
  const manifest: ProjectManifest = {
    project: cfg.project,
    module: cfg.module,
    dataWidth: cfg.dataWidth ?? 8,
    goldenLang: cfg.goldenLang ?? "python",
    goldenMode: cfg.goldenMode ?? "file",
    createdAt: new Date().toISOString(),
  };
  fs.writeFileSync(dst, JSON.stringify(manifest, null, 2) + "\n");
  return true;
}

/**
 * Load the manifest, or null if missing/corrupt (callers fall back to their
 * legacy detection heuristics).
 */
export function loadManifest(projectDir: string): ProjectManifest | null {
  const p = path.join(path.resolve(projectDir), MANIFEST_FILE);
  if (!fs.existsSync(p)) return null;
  try {
    const m = JSON.parse(fs.readFileSync(p, "utf8")) as ProjectManifest;
    if (!m.module || typeof m.dataWidth !== "number") return null;
    return m;
  } catch {
    return null;
  }
}

/** Resolve the effective base-test class name for a project. */
export function baseTestClass(moduleName: string, extendsTest?: string): string {
  if (!extendsTest || extendsTest === "base_test") return `${moduleName}_base_test`;
  return extendsTest;
}
