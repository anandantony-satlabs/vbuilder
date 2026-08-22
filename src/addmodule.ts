/**
 * vbuilder — action: add_module
 *
 * Adds one RTL module (+ optional standalone TB + optional DV component) and
 * auto-wires it into:
 *   - rtl/filelist.f          (ordered, in the RTL_MODULES section)
 *   - rtl/<module>_pkg.sv     (if it's a sub-constant source)
 *   - dv/filelist.f           (if alsoDv, in DV_ENV section)
 *   - dv/common/<top>_pkg.sv  (if alsoDv, `include)
 *   - dv/<env>_env.sv         (if alsoDv, field + build_phase create)
 *
 * @module vbuilder/addmodule
 */

import * as fs from "node:fs";
import * as path from "node:path";
import { render, renderFileTo } from "./template.ts";
import {
  ANCHOR,
  appendInSection,
  insertAfterAnchor,
  raiseIfFailed,
} from "./patcher.ts";
import type { AddModuleArgs, VBuilderResult } from "./types.ts";

function extRoot(): string {
  return path.dirname(path.dirname(new URL(import.meta.url).pathname));
}

export function addModule(args: AddModuleArgs): VBuilderResult {
  const created: string[] = [];
  const patched: string[] = [];
  const warnings: string[] = [];

  const projectDir = path.resolve(args.projectDir);
  const top = args.topModule ?? detectTopModule(projectDir);
  const alsoTb = args.alsoTb ?? true;
  const alsoDv = args.alsoDv ?? false;
  const addToTop = args.addToTop ?? false;

  const vars = {
    PROJECT: path.basename(projectDir),
    MODULE: args.module,
    DATA_WIDTH: 8,
    ports: args.ports ?? [],
    params: args.params ?? [],
  };

  // 1. Stamp the module .sv + its _pkg.sv from templates.
  const tplDir = path.join(extRoot(), "templates", "rtl");
  const { written: w } = renderFileTo(tplDir, "{{MODULE}}.sv.tpl", path.join(projectDir, "rtl"), vars, false);
  if (w) created.push(`rtl/${args.module}.sv`);
  // Stamp the submodule's constants package (so the `include resolves).
  const { written: wpkg } = renderFileTo(tplDir, "{{MODULE}}_pkg.sv.tpl", path.join(projectDir, "rtl"), vars, false);
  if (wpkg) created.push(`rtl/${args.module}_pkg.sv`);

  // 2. Auto-wire rtl/filelist.f — insert the pkg FIRST, then the module.
  const filelist = path.join(projectDir, "rtl", "filelist.f");
  // Insert the pkg just after the top-level pkg (before the RTL_MODULES section).
  // Simpler: insert both into the RTL_MODULES section, pkg before module.
  let r = insertAfterAnchor(filelist, ANCHOR.RTL_MODULES, `${args.module}_pkg.sv`);
  if (r.action === "missing-anchor") {
    r = appendBeforeTop(filelist, top, `${args.module}_pkg.sv`);
  }
  raiseIfFailed(r, "rtl/filelist.f (pkg)");
  if (r.action === "inserted") patched.push("rtl/filelist.f");
  // Now insert the module itself (after its pkg).
  r = insertAfterAnchor(filelist, `${args.module}_pkg.sv`, `${args.module}.sv`);
  if (r.action === "missing-anchor") {
    r = appendBeforeTop(filelist, top, `${args.module}.sv`);
  }
  raiseIfFailed(r, "rtl/filelist.f (module)");

  // 3. Optional standalone TB.
  if (alsoTb) {
    const tbDir = path.join(projectDir, "rtl", "tb");
    // Ensure the BFM is present (copy from templates if missing).
    const bfmPath = path.join(tbDir, "axi_stream_bfm.svh");
    if (!fs.existsSync(bfmPath)) {
      const bfmTpl = path.join(tplDir, "tb", "axi_stream_bfm.svh");
      if (fs.existsSync(bfmTpl)) {
        fs.copyFileSync(bfmTpl, bfmPath);
        created.push("rtl/tb/axi_stream_bfm.svh");
      }
    }
    const { written: wtb } = renderFileTo(
      path.join(tplDir, "tb"),
      "{{MODULE}}_tb.sv.tpl",
      tbDir,
      vars,
      false,
    );
    if (wtb) created.push(`rtl/tb/${args.module}_tb.sv`);

    // Auto-wire the sim-<module> target into rtl/tb/Makefile.
    const tbMakefile = path.join(tbDir, "Makefile");
    const target = makeTbTarget(args.module);
    let mr = insertAfterAnchor(tbMakefile, ANCHOR.TB_TARGETS, target);
    if (mr.action === "missing-anchor") {
      // Fallback: append before the clean target.
      mr = appendBeforeClean(tbMakefile, target);
    }
    // Don't raise on missing-anchor for the Makefile — it may be hand-rolled.
    // Just warn so the user knows to add the target manually.
    if (mr.action === "missing-anchor" || mr.action === "error") {
      warnings.push(`could not auto-wire sim-${args.module} into rtl/tb/Makefile: ${mr.message}`);
    } else if (mr.action === "inserted") {
      patched.push("rtl/tb/Makefile");
    }
  }

  // 4. Optional DV component wiring.
  if (alsoDv) {
    const dvTplDir = path.join(extRoot(), "templates", "dv", "env");
    const { written: wdv } = renderFileTo(
      dvTplDir,
      "{{MODULE}}_agent.sv.tpl",
      path.join(projectDir, "dv", "env"),
      vars,
      false,
    );
    if (wdv) created.push(`dv/env/${args.module}_agent.sv`);

    // include in dv pkg (single registration — env lives in the pkg scope,
    // NOT as a standalone unit in dv/filelist.f, which would compile it at
    // global scope without `import uvm_pkg::*` and fail.). Relative include
    // `../env/...` resolves from dv/common/<top>_pkg.sv → dv/env/….
    const dvPkg = path.join(projectDir, "dv", "common", `${top}_pkg.sv`);
    let pr = insertAfterAnchor(dvPkg, ANCHOR.PKG_ENV, `    \`include "../env/${args.module}_agent.sv"`);
    raiseIfFailed(pr, `dv/common/${top}_pkg.sv`);
    if (pr.action === "inserted") patched.push(`dv/common/${top}_pkg.sv`);

    // env.sv field + build create
    const envSv = path.join(projectDir, "dv", "env", `${top}_env.sv`);
    pr = insertAfterAnchor(envSv, ANCHOR.ENV_FIELDS, `    ${args.module}_agent ${args.module}_agent_h;`);
    if (pr.action === "inserted") patched.push(`dv/env/${top}_env.sv`);
    pr = insertAfterAnchor(envSv, ANCHOR.ENV_BUILD, `        ${args.module}_agent_h = ${args.module}_agent::type_id::create("${args.module}_agent_h", this);`);
    if (pr.action === "inserted") patched.push(`dv/env/${top}_env.sv`);
  }

  if (addToTop) {
    throw new Error("addToTop is not yet implemented — remove the flag or wire the instance manually at the {{VBUILDER:INSTANCES}} anchor in the top module.");
  }

  return { action: "add_module", created, patched, warnings };
}

/** Find the top module name by scanning rtl/filelist.f for *_top.sv or the last .sv. */
function detectTopModule(projectDir: string): string {
  const fl = path.join(projectDir, "rtl", "filelist.f");
  if (!fs.existsSync(fl)) return "top";
  const lines = fs.readFileSync(fl, "utf8").split("\n").map((l) => l.trim()).filter(Boolean);
  const tops = lines.filter((l) => !l.startsWith("#")).filter((l) => /_top\.sv$/.test(l));
  if (tops.length) return path.basename(tops[tops.length - 1], ".sv");
  const last = lines.filter((l) => !l.startsWith("#")).pop();
  return last ? path.basename(last, ".sv") : "top";
}

/** Fallback: append a line to filelist.f just before the top-module line. */
function appendBeforeTop(filelist: string, top: string, line: string) {
  if (!fs.existsSync(filelist)) {
    return { file: filelist, action: "error" as const, message: "file not found" };
  }
  const content = fs.readFileSync(filelist, "utf8");
  const topLine = `${top}.sv`;
  if (content.includes(line.trim())) {
    return { file: filelist, action: "exists" as const };
  }
  const idx = content.indexOf(topLine);
  if (idx === -1) {
    return { file: filelist, action: "missing-anchor" as const, message: `top line "${topLine}" not found` };
  }
  const updated = content.slice(0, idx) + line + "\n" + content.slice(idx);
  fs.writeFileSync(filelist, updated);
  return { file: filelist, action: "inserted" as const };
}

/**
 * Generate a sim-<module> Makefile target for a standalone TB.
 * Includes --trace (for VCD generation) and the BFM include path.
 */
function makeTbTarget(module: string): string {
  return [
    `# --- ${module} smoke test (auto-wired by vbuilder) ---`,
    `sim-${module}:`,
    `\t$(VERILATOR) --binary --top-module ${module}_tb \\`,
    `\t\t$(LINT_FLAGS) --timing --trace --Mdir $(BUILD_DIR)_${module} \\`,
    `\t\t+incdir+$(RTL_DIR) +incdir+. \\`,
    `\t\t$(RTL_DIR)/${module}_pkg.sv $(RTL_DIR)/${module}.sv \\`,
    `\t\t${module}_tb.sv`,
    `\t./$(BUILD_DIR)_${module}/V${module}_tb`,
    ``,
  ].join("\n");
}

/** Fallback: append a target to the Makefile just before the `clean:` target. */
function appendBeforeClean(makefile: string, target: string) {
  if (!fs.existsSync(makefile)) {
    return { file: makefile, action: "error" as const, message: "file not found" };
  }
  const content = fs.readFileSync(makefile, "utf8");
  // Check if the target already exists (by sim-<module> label)
  const label = target.split("\n")[0];
  if (content.includes(label)) {
    return { file: makefile, action: "exists" as const };
  }
  const idx = content.indexOf("clean:");
  if (idx === -1) {
    return { file: makefile, action: "missing-anchor" as const, message: "clean: target not found" };
  }
  const updated = content.slice(0, idx) + target + "\n" + content.slice(idx);
  fs.writeFileSync(makefile, updated);
  return { file: makefile, action: "inserted" as const };
}
