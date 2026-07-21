#!/usr/bin/env python3
"""Verification driver for squirrel_parser.tex.

Runs, from the repository's dart/ package:
  1. verify_paper_numbers.dart -- re-checks every deterministic measured number
     quoted in the paper (work counts, mutation-sweep totals, parse counts,
     semantics examples, figure examples). Exits non-zero on any mismatch.
  2. The full Dart test suite (304 tests), the gate behind the paper's
     correctness and recovery claims.

Timing figures quoted in the paper (ms/s) are environment-dependent
(AMD Ryzen 9 3950X, Dart 3.12.2, single thread) and are not asserted.
Citation verification is recorded in bib.md alongside this script.
"""

import pathlib
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
DART_PKG = HERE.parent.parent / "dart"


def run(desc, cmd):
    print(f"== {desc}: {' '.join(cmd)}")
    proc = subprocess.run(cmd, cwd=DART_PKG)
    if proc.returncode != 0:
        print(f"FAILED: {desc}")
        sys.exit(proc.returncode)


run(
    "Paper-number verification",
    ["dart", "--packages=.dart_tool/package_config.json",
     str(HERE / "verify_paper_numbers.dart")],
)
run("Full Dart test suite", ["dart", "test"])
print("VERIFICATION OK")
