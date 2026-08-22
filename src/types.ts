/**
 * vbuilder — shared types
 *
 * @module vbuilder/types
 */

/** A single port on the top-level RTL module. */
export interface Port {
  name: string;
  dir: "input" | "output" | "inout";
  width: number;
  signed?: boolean;
  desc?: string;
}

/** A module parameter. */
export interface Param {
  name: string;
  default: string | number;
  desc?: string;
}

/** The full configuration for a vbuilder project / module. */
export interface VBuilderConfig {
  /** Project name (repo / directory). e.g. "ccsds_tx". */
  project: string;
  /** Top-level RTL module name. e.g. "ccsds_tx". */
  module: string;
  /** Target directory for `init`. */
  targetDir: string;
  /** Data width used in templates. */
  dataWidth?: number;
  /** Port list for the top module. */
  ports?: Port[];
  /** Parameter list for the top module. */
  params?: Param[];
  /** Golden model language. Default "python". */
  goldenLang?: "python" | "c";
  /** Golden check mode. "file" (proven) or "dpi" (pyhdl-if cosim, opt-in). Default "file". */
  goldenMode?: "file" | "dpi";
  /** Run `git init` + first commit on `init`. Default true. */
  gitInit?: boolean;
  /** Overwrite existing files on `init`. Default false. */
  force?: boolean;
}

/** A single RTL module addition (for add-module). */
export interface AddModuleArgs {
  /** Project root directory (where rtl/ lives). */
  projectDir: string;
  /** New module name. e.g. "ccsds_scrambler". */
  module: string;
  /** Parent/top module this belongs under (for filelist placement). */
  topModule?: string;
  ports?: Port[];
  params?: Param[];
  /** Also stamp a standalone rtl/tb/<module>_tb.sv. Default true. */
  alsoTb?: boolean;
  /** Also register in dv/ as a UVM component skeleton. Default false. */
  alsoDv?: boolean;
  /** Instantiate inside the top module at autowire anchors. Default false. */
  addToTop?: boolean;
}

/** A single UVM test addition (for add-test). */
export interface AddTestArgs {
  /** Project root directory (where dv/ lives). */
  projectDir: string;
  /** Test class name. e.g. "error_injection_test". */
  test: string;
  /** Base test to extend. Default "base_test". */
  extendsTest?: string;
  /** One-line description. */
  desc?: string;
}

/** Standard action union. */
export type VBuilderAction =
  | "init"
  | "add_module"
  | "add_test"
  | "status"
  | "upgrade-flow";

/** The flat parameters the single vbuilder tool accepts. */
export interface VBuilderParams {
  action: VBuilderAction;
  // init
  project?: string;
  module?: string;
  targetDir?: string;
  dataWidth?: number;
  ports?: Port[];
  params?: Param[];
  goldenLang?: "python" | "c";
  goldenMode?: "file" | "dpi";
  gitInit?: boolean;
  force?: boolean;
  // add_module / add_test / status / upgrade-flow
  projectDir?: string;
  // add_module
  topModule?: string;
  alsoTb?: boolean;
  alsoDv?: boolean;
  addToTop?: boolean;
  // add_test
  test?: string;
  extendsTest?: string;
  desc?: string;
}

/** Result of a vbuilder action. */
export interface VBuilderResult {
  action: VBuilderAction;
  created: string[];
  patched: string[];
  warnings: string[];
  flowVersion?: string;
}
