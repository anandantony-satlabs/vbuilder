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
import { renderFileTo } from "./template.ts";
import {
  ANCHOR,
  appendInSection,
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
  const extendsTest = args.extendsTest ?? "base_test";

  // Detect top module name from dv/filelist.f (the *_pkg.sv line).
  const top = detectDvTop(projectDir);
  const topPkg = `${top}_pkg`;

  const vars = {
    PROJECT: path.basename(projectDir),
    MODULE: top.replace(/_top$/, ""),
    TEST: test,
    EXTENDS: extendsTest,
    DATA_WIDTH: 8,
  };

  // 1. Stamp the test .sv from the base_test template (reuse + rename).
  const tplDir = path.join(extRoot(), "templates", "dv", "tests");
  const testContent = renderTestFromTemplate(tplDir, vars, args.desc);
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
  const dvPkg = path.join(projectDir, "dv", "common", `${topPkg}.sv`);
  let pr = insertAfterAnchor(dvPkg, ANCHOR.PKG_TESTS, `    \`include "../tests/${test}.sv"`);
  raiseIfFailed(pr, `dv/common/${topPkg}.sv`);
  if (pr.action === "inserted") patched.push(`dv/common/${topPkg}.sv`);

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

function renderTestFromTemplate(
  tplDir: string,
  vars: Record<string, string | number>,
  desc: string | undefined,
): string {
  const raw = fs.readFileSync(path.join(tplDir, "sanity_test.sv.tpl"), "utf8");
  let out = raw.replace(/\{\{MODULE\}\}/g, String(vars.MODULE));
  out = out.replace(/\{\{MODULE\}_sanity_test\}/g, String(vars.TEST));
  out = out.replace(/sanity/g, String(vars.TEST).replace(/_test$/, ""));
  if (desc) {
    out = out.replace("// Added by vbuilder.", `// Added by vbuilder. ${desc}`);
  }
  return out;
}

function detectDvTop(projectDir: string): string {
  const fl = path.join(projectDir, "dv", "filelist.f");
  if (!fs.existsSync(fl)) return "top";
  const lines = fs.readFileSync(fl, "utf8").split("\n").map((l) => l.trim());
  const pkg = lines.find((l) => /_pkg\.sv$/.test(l) && !l.startsWith("#"));
  if (pkg) return path.basename(pkg, ".sv").replace(/_pkg$/, "");
  return "top";
}

function appendBeforeTbTop(_filelist: string, _top: string, _line: string) {
  const content = fs.readFileSync(filelist, "utf8");
  if (content.includes(line.trim())) {
    return { file: filelist, action: "exists" as const };
  }
  const topLine = `tb/${top}.sv`;
  const idx = content.indexOf(topLine);
  if (idx === -1) {
    return { file: filelist, action: "missing-anchor" as const, message: `tb top line not found` };
  }
  fs.writeFileSync(filelist, content.slice(0, idx) + line + "\n" + content.slice(idx));
  return { file: filelist, action: "inserted" as const };
}
