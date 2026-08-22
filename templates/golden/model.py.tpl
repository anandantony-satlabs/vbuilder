#!/usr/bin/env python3
"""
{{TITLE}} — Python golden model (the executable spec)

This is the single source of truth for {{MODULE}} behavior. RTL is checked
against it (golden_check). Per FACTORY.md §5.1, the model must clear a
validation gate (reproduce a published reference vector) BEFORE any RTL is
checked against it.

Two interfaces are exposed:

  1. FILE mode (default, proven): CLI that reads input samples from a file
     and writes golden output to a file. Used by scripts/golden_check.sh.

  2. DPI mode (opt-in, pyhdl-if): exports golden_step() for cosimulation —
     the SV scoreboard calls it per-sample. See the pyhdl-if decorators below.

Usage (file mode):
    python3 model.py <input_file> <output_file> [--verbose]
"""

import argparse
import sys
from pathlib import Path

# --- pyhdl-if cosim interface (opt-in) --------------------------------------
# Import is wrapped so the model still runs standalone (file mode) when
# pyhdl-if is not installed / not used.
try:
    import pyhdl_if  # type: ignore

    _HAS_PYHDL_IF = True
except ImportError:  # pragma: no cover
    _HAS_PYHDL_IF = False


# ============================================================================
# The golden algorithm — fill this in (it is the executable spec)
# ============================================================================

def golden_step(data_in: int) -> int:
    """
    Process one input sample and return the expected output sample.

    This is the per-sample core shared by both file mode and DPI mode.
    TODO: implement the real algorithm per the verified reference.
    """
    # TODO: real implementation. Placeholder: pass-through.
    return data_in


# ============================================================================
# pyhdl-if DPI registration (active only in dpi mode)
# ============================================================================

if _HAS_PYHDL_IF:

    @pyhdl_if.export
    def golden_init(cfg: str) -> None:
        """Called once from the SV scoreboard at build_phase."""
        # TODO: load config / build tables.
        pass

    @pyhdl_if.export
    def golden_step_dpi(din: int) -> int:
        """Per-sample DPI entrypoint called from SV via import \"DPI-C\"."""
        return golden_step(din)


# ============================================================================
# File-mode CLI
# ============================================================================

def run_file_mode(input_path: Path, output_path: Path, verbose: bool) -> int:
    if not input_path.exists():
        print(f"error: input file not found: {input_path}", file=sys.stderr)
        return 1

    out_lines: list[str] = ["# {{MODULE}} golden output", "# data_out"]
    n = 0
    for line in input_path.read_text().splitlines():
        if not line or line.startswith("#"):
            continue
        try:
            sample = int(line.strip(), 0)
        except ValueError:
            continue
        out_lines.append(str(golden_step(sample)))
        n += 1

    output_path.write_text("\n".join(out_lines) + "\n")
    if verbose:
        print(f"processed {n} samples -> {output_path}", file=sys.stderr)
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description="{{MODULE}} golden model")
    p.add_argument("input_file", nargs="?", help="input samples (file mode)")
    p.add_argument("output_file", nargs="?", help="golden output (file mode)")
    p.add_argument("-v", "--verbose", action="store_true")
    args = p.parse_args()

    if args.input_file and args.output_file:
        return run_file_mode(Path(args.input_file), Path(args.output_file), args.verbose)

    # No args → emit a trivial self-test vector.
    print("golden model: use file mode (model.py in out) or import golden_step()")
    return 0


if __name__ == "__main__":
    sys.exit(main())
