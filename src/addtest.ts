/**
 * vbuilder — action: add_test
 *
 * Adds a UVM test class and auto-wires it into:
 *   - dv/common/<top>_pkg.sv   (`include in PKG_TESTS section)
 *   - dv/filelist.f            (DV_TESTS section)
 *   - dv/Makefile              (TESTS variable)
 *   - dv/regression/run_all.sh (run line)
 *
 * All idempotent.
 *
 * @module vbuilder/addtest
 */

import * as fs from "node:fs";
import * as path from "node:path";
import { render, renderFileTo } from "./template.ts";
import { baseTestClass, loadManifest } from "./manifest.ts";
import {
  ANCHOR,
  appendToMakefileVar,
  appendToShell,
  insertAfterAnchor,
  raiseIfFailed,
} from "./patcher.ts";
import type { AddTestArgs, VBuilderResult } from "./types.ts";

function extRoot(): string {
  return path.dirname(path.dirname(new URL(import.meta.url).pathname));
}

export function addTest(args: AddTestArgs): VBuilderResult {
  const created: string[] = [];
  const patched: string[] = [];
  const warnings: string[] = [];

  const projectDir = path.resolve(args.projectDir);
  const test = args.test;

  // Manifest (written by init) is the source of truth for module name and
  // data width; fall back to filelist heuristics for pre-manifest projects.
  const manifest = loadManifest(projectDir);
  const top = manifest?.module ?? detectDvTop(projectDir);
  const mod = top.replace(/_top$/, "");
  const baseClass = baseTestClass(mod, args.extendsTest);

  // 1. Stamp the test .sv from the sanity template using real placeholder
  //    vars ({{TEST}} / {{BASE_TEST}}) — no fragile regex-chaining.
  const tplDir = path.join(extRoot(), "templates", "dv", "tests");
  const raw = fs.readFileSync(path.join(tplDir, "sanity_test.sv.tpl"), "utf8");
  let testContent = render(raw, {
    PROJECT: manifest?.project ?? path.basename(projectDir),
    MODULE: mod,
    DATA_WIDTH: manifest?.dataWidth ?? 8,
    TEST: test,
    BASE_TEST: baseClass,
  });
  if (args.desc) {
    testContent = testContent.replace("// Added by vbuilder.", `// Added by vbuilder.\n// Description: ${args.desc}`);
  }
  const testPath = path.join(projectDir, "dv", "tests", `${test}.sv`);
  if (fs.existsSync(testPath)) {
    warnings.push(`dv/tests/${test}.sv already exists; left untouched`);
  } else {
    fs.mkdirSync(path.dirname(testPath), { recursive: true });
    fs.writeFileSync(testPath, testContent);
    created.push(`dv/tests/${test}.sv`);
  }

  // 2. include in dv pkg (single registration — tests live in the pkg scope,
  //    NOT as a standalone unit in dv/filelist.f, which fails at global scope
  //    without `import uvm_pkg::*`.). Relative include resolves from
  //    dv/common/<top>_pkg.sv → dv/tests/….
  const dvPkg = path.join(projectDir, "dv", "common", `${top}_pkg.sv`);
  let pr = insertAfterAnchor(dvPkg, ANCHOR.PKG_TESTS, `    \`include "../tests/${test}.sv"`);
  raiseIfFailed(pr, `dv/common/${top}_pkg.sv`);
  if (pr.action === "inserted") patched.push(`dv/common/${top}_pkg.sv`);

  // 4. dv/Makefile TESTS var.
  const dvMakefile = path.join(projectDir, "dv", "Makefile");
  pr = appendToMakefileVar(dvMakefile, "TESTS", test);
  raiseIfFailed(pr, "dv/Makefile TESTS");
  if (pr.action === "inserted") patched.push("dv/Makefile (TESTS)");

  // 5. run_all.sh — insert into the REGRESSION_START..REGRESSION_END section.
  const runAll = path.join(projectDir, "dv", "regression", "run_all.sh");
  pr = insertAfterAnchor(runAll, "{{VBUILDER:REGRESSION_START}}", `make run-${test}`);
  if (pr.action === "inserted") patched.push("dv/regression/run_all.sh");
  else if (pr.action === "missing-anchor") {
    // fallback: plain append.
    pr = appendToShell(runAll, `make run-${test}`);
    if (pr.action === "inserted") patched.push("dv/regression/run_all.sh");
  }

  return { action: "add_test", created, patched, warnings };
}

function detectDvTop(projectDir: string): string {
  const fl = path.join(projectDir, "dv", "filelist.f");
  if (!fs.existsSync(fl)) return "top";
  const lines = fs.readFileSync(fl, "utf8").split("\n").map((l) => l.trim());
  const pkg = lines.find((l) => /_pkg\.sv$/.test(l) && !l.startsWith("#"));
  if (pkg) return path.basename(pkg, ".sv").replace(/_pkg$/, "");
  return "top";
}
