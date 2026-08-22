/**
 * vbuilder — the single tool definition + action dispatch.
 *
 * @module vbuilder/tools
 */

import { Type } from "typebox";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { init } from "./scaffold.ts";
import { addModule } from "./addmodule.ts";
import { addTest } from "./addtest.ts";
import { status } from "./status.ts";
import { upgradeFlow } from "./upgrade-flow.ts";
import type { VBuilderAction, VBuilderParams, Port, Param } from "./types.ts";

const PortSchema = Type.Object({
  name: Type.String({ description: "Port name, e.g. 'data_in'" }),
  dir: Type.Union([Type.Literal("input"), Type.Literal("output"), Type.Literal("inout")]),
  width: Type.Number({ description: "Bit width (1 for scalar)", default: 1 }),
  signed: Type.Optional(Type.Boolean({ description: "Signed signal", default: false })),
  desc: Type.Optional(Type.String({ description: "Description for docs" })),
});

const ParamSchema = Type.Object({
  name: Type.String({ description: "Parameter name, e.g. 'DATA_WIDTH'" }),
  default: Type.Union([Type.String(), Type.Number()]),
  desc: Type.Optional(Type.String()),
});

export const VBuilderParamsSchema = Type.Object({
  action: Type.Union(
    [
      Type.Literal("init"),
      Type.Literal("add_module"),
      Type.Literal("add_test"),
      Type.Literal("status"),
      Type.Literal("upgrade-flow"),
    ],
    { description: "What to do: init (new project) | add_module | add_test | status | upgrade-flow" },
  ),

  // init
  project: Type.Optional(Type.String({ description: "Project name (init)" })),
  module: Type.Optional(Type.String({ description: "Top RTL module name (init / add_module)" })),
  targetDir: Type.Optional(Type.String({ description: "Target directory for init" })),
  dataWidth: Type.Optional(Type.Number({ description: "Default data width", default: 8 })),
  ports: Type.Optional(Type.Array(PortSchema, { description: "Top-module ports" })),
  params: Type.Optional(Type.Array(ParamSchema, { description: "Top-module parameters" })),
  goldenLang: Type.Optional(Type.Union([Type.Literal("python"), Type.Literal("c")], { default: "python" })),
  goldenMode: Type.Optional(Type.Union([Type.Literal("file"), Type.Literal("dpi")], {
    description: "file = proven file-diff (default); dpi = pyhdl-if cosim (opt-in)",
    default: "file",
  })),
  gitInit: Type.Optional(Type.Boolean({ description: "git init + commit on init", default: true })),
  force: Type.Optional(Type.Boolean({ description: "Overwrite existing files", default: false })),

  // add_module / add_test / status / upgrade-flow
  projectDir: Type.Optional(Type.String({ description: "Existing project root (for add_*/status/upgrade-flow)" })),
  topModule: Type.Optional(Type.String({ description: "Parent/top module name (add_module)" })),
  alsoTb: Type.Optional(Type.Boolean({ description: "Also create standalone rtl/tb (add_module)", default: true })),
  alsoDv: Type.Optional(Type.Boolean({ description: "Also register a DV component (add_module)", default: false })),
  addToTop: Type.Optional(Type.Boolean({ description: "Instantiate in top module (add_module)", default: false })),

  // add_test
  test: Type.Optional(Type.String({ description: "Test class name (add_test)" })),
  extendsTest: Type.Optional(Type.String({ description: "Base test to extend (add_test)", default: "base_test" })),
  desc: Type.Optional(Type.String({ description: "One-line description (add_test)" })),
});

/** Convert the flat tool params into a dispatched call. */
export function dispatch(p: VBuilderParams): {
  text: string;
  result: ReturnType<typeof init> | ReturnType<typeof status>;
} {
  const action = p.action as VBuilderAction;

  switch (action) {
    case "init": {
      if (!p.project || !p.module || !p.targetDir) {
        throw new Error("init requires: project, module, targetDir");
      }
      const res = init({
        project: p.project,
        module: p.module,
        targetDir: p.targetDir,
        dataWidth: p.dataWidth,
        ports: p.ports as Port[] | undefined,
        params: p.params as Param[] | undefined,
        goldenLang: p.goldenLang,
        goldenMode: p.goldenMode,
        gitInit: p.gitInit,
        force: p.force,
      });
      return { text: formatResult(res), result: res };
    }

    case "add_module": {
      if (!p.projectDir || !p.module) {
        throw new Error("add_module requires: projectDir, module");
      }
      const res = addModule({
        projectDir: p.projectDir,
        module: p.module,
        topModule: p.topModule,
        ports: p.ports as Port[] | undefined,
        params: p.params as Param[] | undefined,
        alsoTb: p.alsoTb,
        alsoDv: p.alsoDv,
        addToTop: p.addToTop,
      });
      return { text: formatResult(res), result: res };
    }

    case "add_test": {
      if (!p.projectDir || !p.test) {
        throw new Error("add_test requires: projectDir, test");
      }
      const res = addTest({
        projectDir: p.projectDir,
        test: p.test,
        extendsTest: p.extendsTest,
        desc: p.desc,
      });
      return { text: formatResult(res), result: res };
    }

    case "status": {
      if (!p.projectDir) throw new Error("status requires: projectDir");
      const res = status(p.projectDir);
      return { text: res.created[0] ?? "no status", result: res };
    }

    case "upgrade-flow": {
      if (!p.projectDir) throw new Error("upgrade-flow requires: projectDir");
      const res = upgradeFlow(p.projectDir);
      return { text: formatResult(res), result: res };
    }

    default:
      throw new Error(`unknown action: ${action as string}`);
  }
}

function formatResult(r: {
  action: string;
  created: string[];
  patched: string[];
  warnings: string[];
  flowVersion?: string;
}): string {
  const parts: string[] = [`vbuilder ${r.action} ✓`];
  if (r.created.length) {
    parts.push(`created (${r.created.length}):`);
    parts.push(...r.created.map((c) => `  + ${c}`));
  }
  if (r.patched.length) {
    parts.push(`auto-wired (${r.patched.length}):`);
    parts.push(...r.patched.map((c) => `  ~ ${c}`));
  }
  if (r.warnings.length) {
    parts.push(`warnings:`);
    parts.push(...r.warnings.map((w) => `  ! ${w}`));
  }
  if (r.flowVersion) parts.push(`flow: ${r.flowVersion}`);
  return parts.join("\n");
}

/** Register the vbuilder tool. Called once from index.ts (reload-safe). */
export function registerVBuilderTool(pi: ExtensionAPI): void {
  pi.registerTool({
    name: "vbuilder",
    label: "VBuilder",
    description:
      "Scaffold an RTL verification project (golden→RTL→UVM→regress) or add modules/tests to an existing one. " +
      "Stamps the full tree from templates, vendors a standardized simulator-agnostic DV build/run flow, " +
      "and auto-wires new modules/tests into filelists, UVM packages, Makefiles, and regression scripts. " +
      "Actions: init | add_module | add_test | status | upgrade-flow.",
    promptSnippet: "Scaffold/extend RTL verification projects (golden+RTL+UVM+regress).",
    parameters: VBuilderParamsSchema,
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      try {
        const { text } = dispatch(params as VBuilderParams);
        return {
          content: [{ type: "text", text }],
          details: { ok: true },
        };
      } catch (e) {
        return {
          content: [{ type: "text", text: `vbuilder error: ${(e as Error).message}` }],
          details: { ok: false, error: (e as Error).message },
          isError: true,
        };
      }
    },
  });
}
