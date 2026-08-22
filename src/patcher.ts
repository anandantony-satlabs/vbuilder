/**
 * vbuilder — the contract enforcer.
 *
 * All auto-wiring (add_module, add_test) goes through here. The patcher does
 * anchor-safe, idempotent insertion into the four "registry" files:
 *
 *   1. <project>/rtl/filelist.f        — ordered compile list
 *   2. <project>/dv/filelist.f         — ordered DV compile list
 *   3. <project>/dv/common/<mod>_pkg.sv — UVM class visibility (`include)
 *   4. <project>/dv/Makefile           — TESTS list
 *   5. <project>/dv/regression/run_all.sh — test runner lines
 *
 * Principles:
 *   - Idempotent: never duplicates a line that already exists.
 *   - Anchored: inserts at vbuilder-owned markers; fails LOUD if an anchor is
 *     missing (means a human hand-edited — don't silently mis-wire).
 *   - Order-correct: pkg includes sorted env->tests; filelist pkg->modules->top.
 *
 * @module vbuilder/patcher
 */

import * as fs from "node:fs";
import * as path from "node:path";

/** vbuilder-owned anchor markers (bare markers — match commented or bare). */
export const ANCHOR = {
  /** In filelist.f: where RTL submodules are appended (after pkg, before tops). */
  RTL_MODULES: "{{VBUILDER:RTL_MODULES}}",
  /** In filelist.f: where RTL top modules live (last). */
  RTL_TOPS: "{{VBUILDER:RTL_TOPS}}",
  /** In *_pkg.sv: where env component `includes go. */
  PKG_ENV: "{{VBUILDER:PKG_ENV}}",
  /** In *_pkg.sv: where test `includes go. */
  PKG_TESTS: "{{VBUILDER:PKG_TESTS}}",
  /** In *_env.sv build_phase: component creation. */
  ENV_BUILD: "{{VBUILDER:ENV_BUILD}}",
  /** In *_env.sv field decls: component handles. */
  ENV_FIELDS: "{{VBUILDER:ENV_FIELDS}}",
  /** In rtl/tb/Makefile: where per-module sim-<module> targets go. */
  TB_TARGETS: "{{VBUILDER:TB_TARGETS}}",
} as const;

export interface PatchResult {
  file: string;
  action: "inserted" | "exists" | "missing-anchor" | "error";
  message?: string;
}

/** Read a file as string (throws if missing). */
function read(p: string): string {
  return fs.readFileSync(p, "utf8");
}

/** Does `content` already contain `needle` as its own line? */
function hasLine(content: string, needle: string): boolean {
  const esc = needle.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  return new RegExp(`(^|\\n)\\s*${esc}\\s*(\\n|$)`).test(content);
}

/**
 * Insert `line` after `anchor` in the file at `filePath`.
 * Idempotent: if `line` already present anywhere, returns "exists".
 * If anchor missing, returns "missing-anchor" (loud fail — caller raises).
 */
export function insertAfterAnchor(filePath: string, anchor: string, line: string): PatchResult {
  if (!fs.existsSync(filePath)) {
    return { file: filePath, action: "error", message: "file not found" };
  }
  const content = read(filePath);
  if (hasLine(content, line.trim())) {
    return { file: filePath, action: "exists" };
  }
  const idx = content.indexOf(anchor);
  if (idx === -1) {
    return {
      file: filePath,
      action: "missing-anchor",
      message: `anchor "${anchor}" not found — file was hand-edited; refusing to mis-wire`,
    };
  }
  // Insert on the line after the anchor.
  const lineEnd = content.indexOf("\n", idx);
  const insertAt = lineEnd === -1 ? content.length : lineEnd + 1;
  const updated = content.slice(0, insertAt) + line + "\n" + content.slice(insertAt);
  fs.writeFileSync(filePath, updated);
  return { file: filePath, action: "inserted" };
}

/**
 * Append `line` to a section delimited by `startAnchor` and `endAnchor`.
 * Used for filelist.f sections (# {{VBUILDER:RTL_MODULES}} ... # {{VBUILDER:RTL_TOPS}}).
 * Idempotent.
 */
export function appendInSection(
  filePath: string,
  startAnchor: string,
  endAnchor: string,
  line: string,
): PatchResult {
  if (!fs.existsSync(filePath)) {
    return { file: filePath, action: "error", message: "file not found" };
  }
  const content = read(filePath);
  if (hasLine(content, line.trim())) {
    return { file: filePath, action: "exists" };
  }
  const startIdx = content.indexOf(startAnchor);
  const endIdx = content.indexOf(endAnchor);
  if (startIdx === -1 || endIdx === -1 || endIdx < startIdx) {
    return {
      file: filePath,
      action: "missing-anchor",
      message: `section anchors "${startAnchor}" / "${endAnchor}" not found or mis-ordered`,
    };
  }
  // Insert just before the end anchor's line.
  const insertAt = endIdx;
  const updated = content.slice(0, insertAt) + line + "\n" + content.slice(insertAt);
  fs.writeFileSync(filePath, updated);
  return { file: filePath, action: "inserted" };
}

/**
 * Append a word to the TESTS variable in a Makefile.
 * Handles:  TESTS = a b c   →   TESTS = a b c <word>
 * Idempotent.
 */
export function appendToMakefileVar(filePath: string, varName: string, word: string): PatchResult {
  if (!fs.existsSync(filePath)) {
    return { file: filePath, action: "error", message: "file not found" };
  }
  const content = read(filePath);
  // Match: TESTS = a b c  or  TESTS = a b \
  //                          d
  const re = new RegExp(`(^${varName}\\s*[+:]?=\\s*)([^\n]*)`, "m");
  const m = content.match(re);
  if (!m) {
    return {
      file: filePath,
      action: "missing-anchor",
      message: `${varName} = ... not found in Makefile`,
    };
  }
  const existing = m[2];
  // Already present?
  if (existing.split(/\s+/).includes(word)) {
    return { file: filePath, action: "exists" };
  }
  const updated = content.replace(re, `${m[1]}${existing.trimEnd()} ${word}`);
  fs.writeFileSync(filePath, updated);
  return { file: filePath, action: "inserted" };
}

/**
 * Append a line to a shell script (idempotent). Used for run_all.sh.
 */
export function appendToShell(filePath: string, line: string): PatchResult {
  if (!fs.existsSync(filePath)) {
    return { file: filePath, action: "error", message: "file not found" };
  }
  const content = read(filePath);
  if (hasLine(content, line.trim())) {
    return { file: filePath, action: "exists" };
  }
  const updated = content.trimEnd() + "\n" + line + "\n";
  fs.writeFileSync(filePath, updated);
  return { file: filePath, action: "inserted" };
}

/** Raise on a patch error / missing-anchor (turns idempotent-skip into a hard fail). */
export function raiseIfFailed(r: PatchResult, context: string): void {
  if (r.action === "error" || r.action === "missing-anchor") {
    throw new Error(`vbuilder patch failed [${context}] on ${path.basename(r.file)}: ${r.message}`);
  }
}
