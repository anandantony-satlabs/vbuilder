/**
 * vbuilder — action: status
 *
 * Presence-based project health check: reports which stage artefacts exist.
 * v1: file/directory presence only (no git-tag parsing). The Makefile targets
 * are the real gate; this is a quick overview.
 *
 * @module vbuilder/status
 */

import * as fs from "node:fs";
import * as path from "node:path";
import { execSync } from "node:child_process";
import type { VBuilderResult } from "./types.ts";

function extRoot(): string {
  return path.dirname(path.dirname(new URL(import.meta.url).pathname));
}

interface StageCheck {
  label: string;
  present: boolean;
  detail: string;
}

export function status(projectDir: string): VBuilderResult {
  const dir = path.resolve(projectDir);
  const checks: StageCheck[] = [];

  const exists = (p: string) => fs.existsSync(path.join(dir, p));

  // S0 ingest
  checks.push({ label: "S0 docs/architecture", present: exists("docs/architecture/theory.md"), detail: "theory.md" });

  // S1 golden
  checks.push({ label: "S1 golden/model.py", present: exists("golden/model.py"), detail: "golden/model.py" });
  checks.push({ label: "S1 golden vectors", present: exists("golden/vectors/golden_output.txt"), detail: "vectors/golden_output.txt" });

  // S2 module
  checks.push({ label: "S2 rtl/filelist.f", present: exists("rtl/filelist.f"), detail: "rtl/filelist.f" });
  checks.push({ label: "S2 rtl standalone tb", present: exists("rtl/tb"), detail: "rtl/tb/" });

  // S2 module — RTL lint gate (catches compile-blocking stub errors, e.g.
  // the desc-comma syntax bug) so a broken RTL can't be reported healthy.
  const rtlLint = runRtlLint(dir);
  checks.push({ label: "S2 rtl/lint gate", present: rtlLint.present, detail: rtlLint.detail });

  // S3/S4 DV
  checks.push({ label: "S3 dv/filelist.f", present: exists("dv/filelist.f"), detail: "dv/filelist.f" });
  checks.push({ label: "S4 dv/flow vendored", present: exists("dv/flow/flow.mk"), detail: "dv/flow/flow.mk" });
  checks.push({ label: "S4 dv/tests/", present: exists("dv/tests/base_test.sv"), detail: "base_test.sv" });
  // DV harness sanity: tb_top must import uvm_pkg (else run_test/ uvm_* don't
  // resolve at module scope — the P1-a false-green).
  checks.push({
    label: "S4 tb_top imports uvm_pkg",
    present: tbTopImportsUvm(dir),
    detail: "dv/tb/*_tb_top.sv has `import uvm_pkg::*;`",
  });

  // flow version drift check
  let flowDetail = "n/a";
  const vendoredFlow = path.join(dir, "dv", "flow", "flow.mk");
  const extFlow = path.join(extRoot(), "flow", "flow.mk");
  if (fs.existsSync(vendoredFlow) && fs.existsSync(extFlow)) {
    const v = extractVersion(fs.readFileSync(vendoredFlow, "utf8"));
    const e = extractVersion(fs.readFileSync(extFlow, "utf8"));
    flowDetail = `vendored ${v} vs extension ${e}${v !== e ? " (DRIFT — run upgrade-flow)" : ""}`;
  } else if (fs.existsSync(extFlow)) {
    flowDetail = `extension ${extractVersion(fs.readFileSync(extFlow, "utf8"))}`;
  }
  checks.push({ label: "flow version", present: fs.existsSync(vendoredFlow), detail: flowDetail });

  const lines = checks.map((c) => `  ${c.present ? "✓" : "✗"} ${c.label.padEnd(24)} ${c.detail}`);
  const report = ["vbuilder status for " + dir, ...lines].join("\n");

  return {
    action: "status",
    created: [report],
    patched: [],
    warnings: checks.filter((c) => !c.present).map((c) => `missing: ${c.label}`),
    flowVersion: flowDetail,
  };
}

function extractVersion(content: string): string {
  const m = content.match(/FLOW_VERSION\s*[:?]?=\s*([0-9.]+)/);
  return m ? m[1] : "unknown";
}

/** Run a fast verilator --lint-only gate on the project RTL. Presence shatters on nonzero. */
function runRtlLint(projectDir: string): { present: boolean; detail: string } {
  const rtlDir = path.join(projectDir, "rtl");
  const filelist = path.join(rtlDir, "filelist.f");
  if (!fs.existsSync(filelist)) {
    return { present: true, detail: "no rtl/filelist.f yet" };
  }
  // Reuse the installed verilator; prefer the same default the Makefile uses.
  const verilator = process.env.VERILATOR ?? "verilator";
  const cmd = `${verilator} -Wall -Wno-fatal --lint-only -f filelist.f`;
  try {
    execSync(cmd, { cwd: rtlDir, timeout: 30_000, stdio: "pipe" });
    return { present: true, detail: "rtl/filelist.f lints clean" };
  } catch {
    return { present: false, detail: "rtl lint FAILED (compile error in generated RTL)" };
  }
}

/** Does dv/tb/*_tb_top.sv contain `import uvm_pkg::*;`? */
function tbTopImportsUvm(projectDir: string): boolean {
  const tbDir = path.join(projectDir, "dv", "tb");
  if (!fs.existsSync(tbDir)) return false;
  for (const f of fs.readdirSync(tbDir)) {
    if (!f.endsWith("_tb_top.sv")) continue;
    const content = fs.readFileSync(path.join(tbDir, f), "utf8");
    if (/import\s+uvm_pkg\s*::\s*\*/.test(content)) return true;
  }
  return false;
}
