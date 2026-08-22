/**
 * vbuilder — pi extension entry point.
 *
 * Scaffolds full RTL verification projects (golden→RTL→UVM→regress) from a
 * config, with a reusable, simulator-agnostic DV build/run flow. Auto-wires
 * new modules/tests into filelists, UVM packages, Makefiles, and regression.
 *
 * Reload-safe: the single tool is registered once in the factory function.
 *
 * @module vbuilder
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { registerVBuilderTool } from "./src/tools.ts";

export default function vbuilder(pi: ExtensionAPI) {
  registerVBuilderTool(pi);
}
