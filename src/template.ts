/**
 * vbuilder — tiny dependency-free template engine.
 *
 * Substitutes {{VAR}} and {{#each arr}}...{{/each}} blocks with array-spread
 * helpers for generating SystemVerilog port/param lists.
 *
 * Kept deliberately small: no external deps, loads fast, reload-safe.
 *
 * @module vbuilder/template
 */

import * as fs from "node:fs";
import * as path from "node:path";
import type { Param, Port } from "./types.ts";

/** A bag of named values for substitution. */
export interface TemplateVars {
  [key: string]: string | number | boolean | Port[] | Param[] | TemplateVars;
}

/** Convert a Port[] to SystemVerilog port declarations (indented, comma-separated). */
export function portsToSV(ports: Port[] = []): string {
  if (ports.length === 0) return "    // (no ports declared)";
  // Each declaration line: `    <decl>,  // desc` — the separator comma goes
  // BEFORE the `// desc` comment (a comma after `//` is swallowed by the comment).
  return ports
    .map((p, i) => {
      const sign = p.signed ? "signed " : "";
      const w = p.width === 1 ? "" : `[${p.width - 1}:0] `;
      const comma = i < ports.length - 1 ? "," : "";
      const comment = p.desc ? `  // ${p.desc}` : "";
      return `    ${p.dir.padEnd(6)} ${sign}${w}${p.name}${comma}${comment}`;
    })
    .join("\n");
}

/** Convert a Param[] to normalized SystemVerilog parameter declarations. */
export function paramsToSV(params: Param[] = []): string {
  if (params.length === 0) return "    // (no parameters)";
  return params
    .map((p, i) => {
      const val = typeof p.default === "number" ? p.default : `"${p.default}"`;
      const comma = i < params.length - 1 ? "," : "";
      const comment = p.desc ? `  // ${p.desc}` : "";
      return `    parameter ${p.name} = ${val}${comma}${comment}`;
    })
    .join("\n");
}

/** Convert a Port[] to a markdown table for docs. */
export function portsToTable(ports: Port[] = []): string {
  if (ports.length === 0) return "| (none) | | | |";
  return ports
    .map((p) => `| \`${p.name}\` | ${p.dir} | ${p.width} | ${p.desc ?? ""} |`)
    .join("\n");
}

/** Convert a Param[] to a markdown table for docs. */
export function paramsToTable(params: Param[] = []): string {
  if (params.length === 0) return "| (none) | | |";
  return params
    .map((p) => `| \`${p.name}\` | ${p.default} | ${p.desc ?? ""} |`)
    .join("\n");
}

/** Convert a Port[] to the DUT-instantiation connection (name → name). */
export function portsToConn(ports: Port[] = []): string {
  if (ports.length === 0) return "";
  return ports.map((p) => `        .${p.name}(${p.name})`).join(",\n");
}

/** Uppercase a module name (for _PKG / _UPPER use). */
export function upper(s: string): string {
  return s.toUpperCase().replace(/[^A-Z0-9_]/g, "_");
}

/** Title-case a module name (for human-readable headers). */
export function title(s: string): string {
  return s
    .split(/[_\s-]+/)
    .filter(Boolean)
    .map((w) => w[0].toUpperCase() + w.slice(1))
    .join(" ");
}

/** Year for copyright headers. */
export function year(): string {
  return String(new Date().getFullYear());
}

/**
 * Substitute {{VAR}} placeholders in a template string.
 * Supports: simple vars, and the special helpers:
 *   {{PORTS_SV}}    → portsToSV(ports)
 *   {{PORTS_CONN}}  → portsToConn(ports)
 *   {{PARAMS_SV}}   → paramsToSV(params)
 *   {{MODULE_UPPER}}→ upper(module)
 *   {{TITLE}}       → title(module)
 *   {{YEAR}}        → current year
 */
export function render(template: string, vars: TemplateVars): string {
  let out = template;

  // Helper-derived values (computed from arrays where present).
  const ports = (vars["ports"] as Port[]) || (vars["PORTS"] as Port[]) || [];
  const params = (vars["params"] as Param[]) || (vars["PARAMS"] as Param[]) || [];
  const module = String(vars["MODULE"] ?? vars["module"] ?? "module");

  const derived: Record<string, string> = {
    PORTS_SV: portsToSV(ports),
    PORTS_TABLE: portsToTable(ports),
    PORTS_CONN: portsToConn(ports),
    PARAMS_SV: paramsToSV(params),
    PARAMS_TABLE: paramsToTable(params),
    MODULE_UPPER: upper(module),
    TITLE: title(module),
    YEAR: year(),
  };

  // Substitute all {{KEY}} with derived or provided values.
  out = out.replace(/\{\{([A-Z0-9_]+)\}\}/g, (_m, key: string) => {
    if (key in derived) return derived[key];
    if (key in vars) {
      const v = vars[key];
      return typeof v === "string" || typeof v === "number" || typeof v === "boolean"
        ? String(v)
        : "";
    }
    return `{{${key}}}`; // leave unknown placeholders (caller missed a var)
  });

  return out;
}

/**
 * Render a template FILE (read from templatesDir/<relPath>) and write to
 * <outDir>/<relPath> (without the .tpl suffix).
 *
 * Filenames may themselves contain {{PLACEHOLDER}} tokens (e.g.
 * {{MODULE}}.sv.tpl) — these are substituted too.
 *
 * Path rewrites applied to the relative output path:
 *   - leading "root/" is stripped (root/ templates go to project root)
 *   - "gitignore" (no dot) is renamed to ".gitignore"
 *
 * @param templatesDir root of the templates/ tree
 * @param relPath path relative to templatesDir, e.g. "rtl/{{MODULE}}.sv.tpl"
 * @param outDir destination root
 * @param vars substitution vars
 * @param force overwrite if exists
 * @returns the written path (relative to outDir), or null if skipped
 */
export function renderFileTo(
  templatesDir: string,
  relPath: string,
  outDir: string,
  vars: TemplateVars,
  force: boolean,
): { written: string | null; skipped: string | null } {
  const src = path.join(templatesDir, relPath);
  let rel = relPath.replace(/\.tpl$/, "");

  // Strip leading "root/" so root templates land at the project root.
  if (rel.startsWith("root/")) rel = rel.slice("root/".length);
  // Substitute placeholders in the relative path (filenames).
  rel = render(rel, vars);
  // Special-case: a bare "gitignore" becomes ".gitignore".
  rel = rel.replace(/(^|\/)gitignore$/, "$1.gitignore");

  const dst = path.join(outDir, rel);

  if (!force && fs.existsSync(dst)) {
    return { written: null, skipped: rel };
  }

  const raw = fs.readFileSync(src, "utf8");
  const rendered = render(raw, vars);
  fs.mkdirSync(path.dirname(dst), { recursive: true });
  fs.writeFileSync(dst, rendered);
  return { written: rel, skipped: null };
}

/**
 * Walk a templates directory, render every file, write to outDir mirroring
 * structure. Returns the list of written + skipped (already-existed) files.
 */
export function renderTree(
  templatesDir: string,
  outDir: string,
  vars: TemplateVars,
  force: boolean,
): { written: string[]; skipped: string[] } {
  const written: string[] = [];
  const skipped: string[] = [];

  const walk = (dir: string, prefix: string) => {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const e of entries) {
      const rel = prefix ? `${prefix}/${e.name}` : e.name;
      const full = path.join(dir, e.name);
      if (e.isDirectory()) {
        walk(full, rel);
      } else {
        const res = renderFileTo(templatesDir, rel, outDir, vars, force);
        if (res.written) written.push(res.written);
        if (res.skipped) skipped.push(res.skipped);
      }
    }
  };

  walk(templatesDir, "");
  return { written, skipped };
}
