# The recovery measurement harness

Measures the engine in `../../experiments/recovery/c7.dart`. Run from the
`dart/` directory:

```sh
dart --packages=$PWD/.dart_tool/package_config.json test/recovery/<file>.dart
```

- `astdiff.dart` — the battery: every parse-breaking single-character
  mutation of every corpus document plus truncations and multi-site
  damage, across three grammars (json, statements, left-recursive
  arithmetic); expectations come from the frozen parser reading the
  undamaged original; scoring is Levenshtein over named-node skeletons.
- `_score1.dart <engine> [dump]` — battery runner; one machine-readable
  line, plus one line per imperfect case with `dump`.
- The four gates (hard requirements the battery cannot see; all must
  pass):
  - `_accept.dart <engine>` — the brief's acceptance readings (cx2, b1,
    b2).
  - `_freespan.dart` — may a repair delete real input that already
    matched?
  - `_recommit.dart` — does the repair keep the construct the healthy
    prefix committed to?
  - `_conf1.dart` — exact repair-cost conformance; no free passes for
    predicates.
- `loc.py` — normalized line counts (formatter-era-independent).

These are runnable scripts, not `package:test` suites; an engine that
hangs is killed by the caller's timeout rather than blocking the rest.
