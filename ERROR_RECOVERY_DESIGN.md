# Squirrel Parser Error Recovery: Design, Rationale, and Results

*2026-07-20. Companion to the pure-algorithm rollback of the Dart implementation.*

## 1. Context

The core squirrel algorithm (as specified in `paper/squirrel_parser_orig.tex`) performs **no**
error recovery: if the top rule does not match the whole input, parsing simply fails. An earlier
AI-driven attempt to weave recovery *into* the parsing algorithm (bound propagation, two-phase
parses, per-clause skip heuristics — preserved in git stash "AI error-recovery attempt") produced
cascading errors on 79% of single-character JSON mutations and was abandoned; the Dart core has
been rolled back to the pure algorithm (see `dart/lib/src/parser/`).

This document describes the replacement design: error recovery as **minimum-cost repair search**,
implemented entirely *outside* the pure core (`dart/lib/src/recovery/`).

## 2. Problem statement

Given a PEG grammar G (with left recursion, handled by the squirrel algorithm) and an input s:

- If s ∈ L(G): parse in linear time, unchanged (the recovery machinery must not run at all).
- Otherwise: produce the parse of a repaired input s* ∈ L(G) minimizing the
  **Damerau-Levenshtein distance** from s (unit-cost character deletion, insertion, substitution,
  adjacent transposition), plus the edit list mapping s to s* in original coordinates.

Requirements: assumption-free (no language-specific knowledge), heuristic-free in *what* is
accepted (the objective is a distance metric; only deterministic tie-breaking is policy),
linear until an error, near-linear recovery (quadratic worst case acceptable), and repairs that
match human expectation. Left recursion must compose with recovery.

## 3. Brainstorm: the full solution space

| # | Approach | Empirical/known result | Score | Reasoning |
|---|----------|------------------------|-------|-----------|
| 1 | **Min-cost repair search over candidate repaired inputs (Dijkstra), pure parser as oracle** — the chosen design | 100% minimal-cost repairs on 519 JSON mutations; 94.4% structural restoration; LR composes trivially | **9** | Core stays pure; semantics = "Damerau-Levenshtein distance to L(G)"; exact for single errors & small clusters; deterministic; degrades gracefully. Cost: repeated re-parsing (see §8). |
| 2 | Global budgeted DP (Aho-Peterson/Lyon-style error-correcting parse, endpos×cost tables) | Known O(n³)-ish; provably globally minimal | 4 | The theoretical gold standard, but destroys linear-when-valid and is a full second engine; kept as *oracle* (test/recovery/oracle.dart is its brute-force cousin). |
| 3 | CPCT+-style repair at failure point over the parser's continuation stack | Literature: works for LR | 6 | Subsumed by #1's frontier-local candidate tier; alone it cannot repair *before* the failure point (missing-quote case). |
| 4 | Bidirectional squirrel–pika hybrid (bottom-up suffix memo table to re-sync after error) | Untested here | 6 | Elegant, near-linear for heavy corruption; but cannot repair before the failure point either, and needs a second parsing mode. Worth revisiting as an accelerator for the far-error case. |
| 5 | Farthest-failure single-point repair menu (Burke–Fisher validation horizon) | Literature | 5 | The validation horizon is a real heuristic; misses coupled and before-frontier repairs. |
| 6 | Grammar-transformation recovery (auto-inserted recovery expressions, Medeiros et al.) | Literature | 4 | Changes grammar semantics; FOLLOW-set heuristics; per-grammar tuning. |
| 7 | User-designated recovery rules + panic skip (pika-paper style; the "last resort") | Implemented as final fallback tier (no annotation needed: panic deletes at the frontier; witness of top rule as terminal fallback) | 4 | Robust but coarse; loses all sub-structure between sync points. Retained only as the bottom of the escalation ladder. |
| 8 | AI's abandoned in-parser bound-propagation recovery | 79% cascading errors (its own analysis); 2% ideal repairs | 1 | Entangled recovery with matching, broke LR invariants, unbounded heuristic patches; empirically refuted. |
| 9 | Weighted/semiring parsing throughout (always-on costs) | — | 3 | Violates "linear until error" by constant-factor and bookkeeping; Pareto sets per memo entry. |
| 10 | Levenshtein-automaton ∩ grammar (lattice parsing) | — | 3 | Equivalent to #2 in disguise; PEG greediness is ill-defined over a lattice. |
| 11 | Token-level (lexer-based) recovery | — | 2 | Squirrel is scannerless; would add an assumption-laden lexing layer. |
| 12 | GLR/GLL with error transitions (tree-sitter style) | — | 2 | Wholesale replacement of the squirrel architecture. |
| 13 | ML/statistical repair ranking | — | 1 | Heuristic by construction; not reproducible; out of spirit. |
| 14 | Constraint/SAT encoding of min-edit parse | — | 1 | Hopeless performance for this use. |

**Decision: #1**, with #2's brute-force variant as the *minimality oracle* in tests, and #7 as the
last-resort fallback exactly as the requirements permitted.

## 4. Architecture

The recovery module never modifies the core parser. It consists of:

1. **Instrumented grammar** (`observed_grammar.dart`): a grammar-to-grammar rewrite wrapping
   every terminal and rule reference in observer clauses that record, per input position:
   - characters *exactly* expected by failed `Char`/`Str`/single-char-set terminals
     (with `Str` failures recorded at their divergence offset, not the terminal's start);
   - representative "filler" characters of failed character classes;
   - failed rule names (for whole-rule witness insertion);
   - spans blocked by `NotFollowedBy` lookaheads that *matched* (repair may need to break them).
   The pure parser runs this instrumented grammar unmodified.

2. **Rule witnesses** (`witness.dart`): fixpoint computation of the shortest string matching each
   rule, used as macro insertions (cost = witness length, so macro edges never undercut true
   character-level cost), and the grammar's character alphabet.

3. **Repair search** (`repair_search.dart`): uniform-cost search over candidate repaired strings.
   - **States** are repaired strings; expanding a state = parsing it (recording failure data) and
     proposing single-edit successors. The first fully-parsing state popped is a minimum-cost
     repair over the explored space.
   - **Lazy materialization**: candidate edits are stored as compact descriptors; strings are
     built one at a time in preference order when dequeued, so memory tracks states *parsed*,
     not states *proposed* (this converts an O(n·|Σ|) per-expansion allocation into O(1)).
   - **Candidate tiers**, in deterministic preference order (= tie-break among equal costs):
     1. *Targeted, frontier-local* (radius 32): per position, transpose > exact-insert >
        exact-substitute > delete > filler; single-char rule witnesses.
     2. *Targeted, evidence-based*: the nearest positions (≤48) farther back where this parse
        recorded expectations.
     3. *Local delimiter sweep*: exact "glue" characters expected at the frontier or *occurring*
        near it (e.g. a quote), inserted/substituted at every local position — a missing or
        damaged delimiter re-segments the span it delimits.
     4. *Frontier-local completeness net* (radius 4): all alphabet characters — covers evidence
        shadowed by PEG's committed choice (e.g. `Number` matching the `5` of `5rue` so that
        `Boolean`'s `t` is never "expected").
     5. Lookahead-block perturbations.
     — end of targeted tier —
     6. Long-range sweep of frontier-expected characters (unterminated-span repairs at any
        distance: the unclosed-quote/brace family).
     7. Far deletions/transpositions.
     8. Full-window whole-alphabet net, character-major (structural characters take precedence
        over escape-character tricks).
     Multi-character rule witnesses are enqueued eagerly at cost = length.
   - **Committed mode** (default): globally minimal search, but at (a) exhaustion of the targeted
     tier, (b) a cost-level boundary, or (c) the state budget, it *commits* to the best-progress
     state found and restarts from it — repairing errors left-to-right, exactly as PEG commits
     choices left-to-right. **Progress is strict**: only the user's own (non-synthetic)
     characters consumed before the frontier count, so a repair that merely papers over the
     frontier with invented characters never triggers a premature commit; ties prefer higher raw
     progress (characters *accounted for*, including deletions). `RepairMode.global` disables
     committing entirely (exact, for small inputs).
   - **Panic ladder** (last resort): delete one character at the frontier per step (O(n) parses
     bound); if the input empties, the top rule's shortest witness.

4. **Reporting**: the final repair is aligned to the original input by Damerau-Levenshtein
   traceback, yielding the edit list in original coordinates; the parse tree of s* is returned.

### Why this composes with left recursion for free

Recovery never touches parser state: every candidate is a plain string parsed by the pure
squirrel algorithm, whose LR handling is input-agnostic. The entire class of "LR × recovery
interaction" bugs that sank the previous attempt is structurally impossible.

## 5. Semantics and determinism

- **Accepted result**: the first fully-parsing state in (cost, tier, position, order) priority.
  With `RepairMode.global`, this is a globally minimum-cost repair over the move set.
  With `committed` (default), each round's repair is minimum-cost among candidates explored in
  that round, rounds proceed left-to-right, and single isolated errors are repaired exactly
  minimally (the tests enforce this against a brute-force oracle).
- **Tie-break policy** (the only "opinion" in the system, stated explicitly): repairs closer to
  the failure frontier first; transpose > exact-insert > exact-substitute > delete > filler;
  grammar-order for characters. Rationale: prefer repairs that preserve or restore the user's
  own content over repairs that invent or discard content.

## 6. Empirical results (Dart, this repo, 2026-07-20)

Mutation testing on `{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}` (all deletions,
transpositions, and a 6-character insertion/substitution alphabet at every position; 519
non-still-valid mutants), full JSON grammar:

| Metric | Old in-parser attempt | This design |
|---|---|---|
| Repairs at minimal cost (1) | 2% "ideal" | **519/519 (100%)** |
| Structural tree restoration | ~21% | **490/519 (94.4%)** |
| Cascading behavior | 79% | 0% (every repair is a single edit) |

The 5.6% non-restored structures are *inherently ambiguous* minimal repairs (e.g. a damaged quote
where merging two members is as cheap as re-quoting; the repaired tree is still a valid,
single-edit explanation).

- Left-recursive expression grammar (`E <- E "+" T / …`): 56/56 mutations repaired at cost 1.
- Minimality verified against a brute-force Damerau-Levenshtein-ball oracle over five grammars
  (sequences, choices, lists, left-recursive expressions, lookaheads) including randomized
  mutation batteries — all minimal (`test/recovery/minimality_oracle_test.dart`).
- Valid input: recovery does not engage; pure-parser work/char is flat (1.77–1.96 over 1k–32k).
- Single error: 3–6 parses total; 29 ms (n=500) to ~270 ms (n=4000), ~linear in n.
- k errors: linear in k (~900 parses per error at n=2000 with the completeness tiers on).
- Pure garbage input (n=400): 5 ms — minimal repair found (wrap in quotes: a valid JSON string).
- Whole-repo suite: 304/304 tests pass.

## 7. Theoretical properties

- **Completeness**: if L(G) ≠ ∅ (reachable by the move set — deletions alone reach ε, plus the
  top-rule witness), the search terminates with a repair; the panic ladder bounds the worst case.
- **Minimality**: exact in `global` mode (uniform-cost search, non-negative unit edges, macro
  edges cost their true length). In `committed` mode, exact for single errors and error clusters
  resolvable within one round; across *coupled* errors, per-round-minimal (bounded regret) — the
  same trade PEG makes with ordered choice.
- **Complexity**: 0 overhead when input is valid. Per error: O(T · n) where T is the targeted
  tier size (radius- and evidence-capped, grammar-dependent constant) — near-linear per error.
  Worst case (level exhaustion, unterminated spans repaired at distance d): O((d + n·|Σ|) · n)
  = quadratic-with-constant, as anticipated; the `window` parameter trades this against
  long-range repair reach.

## 8. Known limitations / next steps

1. **Per-candidate full re-parse** is the dominant cost (~n chars per candidate). The memo
   table's per-position version mechanism (the same idea that powers LR expansion) extends to
   *incremental re-parsing*: memo entries whose span precedes the first edit of a candidate are
   reusable. This should cut per-candidate cost to O(spine) and is the single highest-leverage
   optimization before porting.
2. **Committed-mode regret**: pathological coupled-error inputs can exceed the global minimum;
   `RepairMode.global` is exact but exponential in error count. A hybrid (global within a sliding
   error-cluster window) would close most of the gap.
3. **Ports**: Java/Python/TypeScript still carry the old contaminated recovery code (working tree
   + HEAD); they should be rolled back to the pure core and given this recovery module once the
   Dart version is considered final.
4. The `SyntaxError`-in-tree representation was removed with the rollback; the repair result
   instead reports an explicit edit list plus the clean parse tree of the repaired string. If
   in-tree error nodes are wanted for IDE tooling, they can be reconstructed from the edit list
   and the s→s* alignment without touching the core.
