import { describe, it, expect, beforeEach, afterEach } from "vitest";
import * as fs from "node:fs";
import * as path from "node:path";
import * as os from "node:os";
import { render, portsToSV, paramsToSV, portsToTable } from "../src/template.ts";
import { insertAfterAnchor, appendToMakefileVar, appendToShell } from "../src/patcher.ts";

const TMP = () => fs.mkdtempSync(path.join(os.tmpdir(), "vbuilder-test-"));

describe("template engine", () => {
  it("substitutes simple vars", () => {
    expect(render("hello {{MODULE}}", { MODULE: "ccsds_tx" })).toBe("hello ccsds_tx");
  });

  it("derives MODULE_UPPER and TITLE", () => {
    const out = render("{{MODULE_UPPER}} {{TITLE}}", { MODULE: "ccsds_tx" });
    expect(out).toBe("CCSDS_TX Ccsds Tx");
  });

  it("renders ports to SystemVerilog", () => {
    const out = portsToSV([
      { name: "clk", dir: "input", width: 1 },
      { name: "data", dir: "input", width: 8, signed: true },
    ]);
    expect(out).toContain("input  clk");
    expect(out).toContain("input  signed [7:0] data");
  });

  it("renders params", () => {
    const out = paramsToSV([{ name: "WIDTH", default: 8 }]);
    expect(out).toContain("parameter WIDTH = 8");
  });

  it("renders port markdown table", () => {
    const out = portsToTable([{ name: "clk", dir: "input", width: 1, desc: "clock" }]);
    expect(out).toContain("| `clk` | input | 1 | clock |");
  });

  it("leaves unknown placeholders intact (so caller notices)", () => {
    expect(render("{{UNKNOWN}}", { MODULE: "x" })).toBe("{{UNKNOWN}}");
  });
});

describe("patcher — insertAfterAnchor", () => {
  let dir: string;
  let file: string;

  beforeEach(() => {
    dir = TMP();
    file = path.join(dir, "pkg.sv");
    fs.writeFileSync(
      file,
      ["package p;", "    // {{VBUILDER:PKG_TESTS}}", "endpackage"].join("\n") + "\n",
    );
  });
  afterEach(() => fs.rmSync(dir, { recursive: true, force: true }));

  it("inserts a line after the anchor", () => {
    const r = insertAfterAnchor(file, "{{VBUILDER:PKG_TESTS}}", '    `include "tests/t.sv"');
    expect(r.action).toBe("inserted");
    const content = fs.readFileSync(file, "utf8");
    expect(content).toContain('`include "tests/t.sv"');
    expect(content.indexOf('`include "tests/t.sv"')).toBeGreaterThan(content.indexOf("PKG_TESTS"));
  });

  it("is idempotent (second call returns exists)", () => {
    insertAfterAnchor(file, "{{VBUILDER:PKG_TESTS}}", '    `include "tests/t.sv"');
    const r = insertAfterAnchor(file, "{{VBUILDER:PKG_TESTS}}", '    `include "tests/t.sv"');
    expect(r.action).toBe("exists");
  });

  it("fails loud on missing anchor", () => {
    const r = insertAfterAnchor(file, "{{VBUILDER:NONEXISTENT}}", "x");
    expect(r.action).toBe("missing-anchor");
  });
});

describe("patcher — appendToMakefileVar", () => {
  let dir: string;
  let file: string;

  beforeEach(() => {
    dir = TMP();
    file = path.join(dir, "Makefile");
    fs.writeFileSync(file, "TESTS = sanity_test random_test\n");
  });
  afterEach(() => fs.rmSync(dir, { recursive: true, force: true }));

  it("appends a word to TESTS", () => {
    const r = appendToMakefileVar(file, "TESTS", "error_test");
    expect(r.action).toBe("inserted");
    expect(fs.readFileSync(file, "utf8")).toContain("error_test");
  });

  it("is idempotent", () => {
    appendToMakefileVar(file, "TESTS", "error_test");
    expect(appendToMakefileVar(file, "TESTS", "error_test").action).toBe("exists");
  });
});

describe("patcher — appendToShell", () => {
  let dir: string;
  let file: string;

  beforeEach(() => {
    dir = TMP();
    file = path.join(dir, "run.sh");
    fs.writeFileSync(file, "#!/bin/sh\necho hi\n");
  });
  afterEach(() => fs.rmSync(dir, { recursive: true, force: true }));

  it("appends a line", () => {
    const r = appendToShell(file, "make run-foo");
    expect(r.action).toBe("inserted");
    expect(fs.readFileSync(file, "utf8")).toContain("make run-foo");
  });

  it("is idempotent", () => {
    appendToShell(file, "make run-foo");
    expect(appendToShell(file, "make run-foo").action).toBe("exists");
  });
});
