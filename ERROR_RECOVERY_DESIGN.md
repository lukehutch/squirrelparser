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
     5. *Consulted-region edits*: all edit types over (frontier, horizon] — positions read by
        successful lookaheads; an edit here can flip the lookahead (see Sec. 9.2).
     6. Lookahead-block perturbations.
     7. Long-range sweep of frontier-expected characters (unterminated-span repairs at any
        distance: the unclosed-quote/brace family).
     8. Far deletions/transpositions.
     9. Full-window whole-alphabet net, character-major (structural characters take precedence
        over escape-character tricks).
     — end of within-horizon candidates (the provable early-commit gate, Sec. 9.3) —
     10. *Setup moves*: all edit types beyond the horizon; they replay the current parse
        identically and exist only to enable later edits (bca example, Sec. 9.2).
     Multi-character rule witnesses are enqueued eagerly at cost = length.
   - **Committed mode** (default): globally minimal search, but at (a) exhaustion of the
     within-horizon candidates of the base state (the setup moves that follow parse identically,
     so they can be neither repairs nor progress — see Sec. 9), (b) a cost-level boundary, or
     (c) the state budget (deployment fallback only), it *commits* to the best-progress
     state found and restarts from it — repairing errors left-to-right, exactly as PEG commits
     choices left-to-right. Synthetic-character marks are carried across rounds. **Progress is strict**: only the user's own (non-synthetic)
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

## 9. Heuristic purification (2026-07-20/21): from radii to rules

Question posed: the candidate tiers used arbitrary numeric heuristics (targetedRadius=32,
evidenceCap=48, a radius-4 completeness net, blockedSpanCap=16, a state-budget formula).
Is there a purer, more general way to solve the repair problem that subsumes them?
Process: three brainstorm rounds, each pairing an independent Claude analysis with an
independent Codex consultation (Codex session 019f8310-6abf-77c0-8770-e5329e2c6d86),
with every load-bearing claim tested empirically before adoption.

### 9.1 Diagnosis (measured)

Every constant serves exactly one of three roles: (R1) ordering among equal-cost
candidates, (R2) gating the committed-mode early commit, (R3) work bounds. A sensitivity
sweep over the 519-mutation JSON corpus showed targetedRadius in {8,32,128} identical in
quality and radius<=4 losing 6 repairs to premature commits (all one scenario: damaged
closing quote, repair ~7 chars behind the frontier, early commit locks in an
escape-character cascade); blockedSpanCap was inert at any value. So only R2 was
semantically load-bearing -- and it is exactly the role a pure rule can take over.

### 9.2 Three correctness holes found and fixed along the way

The purification uncovered real soundness bugs, each with a committed counterexample,
regression test, and machine check:

1. **Horizon (commit a92ecbb).** Successful lookaheads read beyond the farthest failure;
   the frontier-bounded window missed repairs there. `S <- (&"xxxxxxxxxxq" 'x') /
   "xxxxxxxxxxz"`, input `xxxxxxxxxxq`: true cost 1 (substitute at position 10, inside
   the succeeded lookahead), search returned 3. Fix: the observer records the farthest
   position consulted by ANY character test (the horizon); a consulted-region tier
   proposes all edits over (frontier, horizon].
2. **Setup moves (commit 2db78d7, found by Codex round 2).** Definition-of-repair
   semantics are operation SEQUENCES, so a transpose may act on characters made adjacent
   by an earlier delete. `S <- "a" "b"`, input `bca`: the unique 2-op repair starts with
   delete@1 -- beyond the horizon, changing nothing about the current parse. Any window
   pruning is therefore unsound. Fix: a final tier proposes every edit at every position
   beyond the horizon ("setup moves"), ordered last, justified by the replay lemma (an
   edit beyond the horizon replays the parse identically -- it can never itself be a
   repair, only enable a later one).
3. **Alphabet lemma gap (commit 9a03fa0).** The search inserts only Sigma_G characters
   but the lemma guaranteed sufficiency of Sigma_G union chars(s). Strengthened to
   Sigma_G alone via a persistence argument (no minimal sequence destroys a character it
   wrote; every written character survives into s*, is accepted by some test, and can be
   written as its class representative).

### 9.3 The pure rules that replaced the heuristics

- **Move set = every unit edit, every position, Sigma_G characters.** Complete by
  construction (alphabet lemma for characters; nothing to prove for positions).
  Radii can then never prune -- only order.
- **Commit gate = "all within-horizon candidates exhausted."** The candidates skipped
  (setup moves) provably parse identically to the base, so they can be neither repairs
  nor progress. Replaces "targeted tiers exhausted" (radius-dependent). Single-error
  exactness of committed mode is now provable as stated, with no radius condition.
- **Cost-level boundaries** remain the other commit point (Dijkstra guarantees every
  cheaper candidate was seen). Committed mode's semantics are now exactly: "commit at
  the first cost level with strict progress, to the max-progress state of that level" --
  leftmost-progress-greedy, mirroring PEG's own leftmost commitment.
- **Result (measured):** across targetedRadius 0..128 and blockedSpanCap 0..16 the
  519-mutation sweep returns byte-identical repairs at every setting; only work varies
  (11.4K-16.7K parses). Every remaining numeric constant is ordering-only. The paper's
  pinned numbers were unchanged throughout (14,592 parses; 519/519 cost-1; 490/519
  shape; 51 machine checks; 307 tests).

### 9.4 Future work, in priority order (converged Claude+Codex ranking)

(a) **Incremental oracle for the cost-1 sibling fan-out**: snapshot the base parse once
    and reuse memo results whose read-dependency interval is untouched by the sibling's
    single edit; certify any proposed success with a cold parse. Attacks the measured
    dominant cost (a long-range quote repair = ~520 full parses of a 2.2KB doc).
(b) **Evidence-band ordering with multiple anchors** replacing the remaining ordering
    radii: bands = causal divergence > moved exact literal > delete/transpose at a read
    boundary > witness/class-rep > generic net; anchors = farthest causal failure,
    matched-prefix EOF, ends of successful lookahead reads, blocked spans; Pareto
    enumeration over (band, distance-to-anchor) rather than any weighted score.
    Requires observer provenance (root-causal vs branch-rejection failures).
(c) **Regular-over-approximation A***: h(x) = transpose-aware edit distance to a regular
    superset language (admissible, consistent); plus certified-incumbent deadline
    reporting ([lower, upper] interval instead of a silent budget).
(d) **Exhaustive tiny-PEG pruning-property harness**: enumerate small grammars x inputs
    x full Damerau neighborhoods; compare the search against brute force. Tests the
    pruning/ordering theorems themselves, not just repair quality on one corpus.
(e) **Grammar-derived bounds with honest infinity** for anything that still wants a
    number (e.g. lookahead reach), never a universal constant.

Rejected en route: PEG-derivative edit product (forfeits the unmodified-oracle claim and
"left recursion for free"); Aho-Peterson over-grammar k-best (second parser, large
false-positive plateaus); beam search / learned edit models (reintroduce capricious
constants); defining the metric as restricted OSA to rescue horizon pruning (would make
the search's own composed sequences out-of-model).

### 9.5 Round-3 adversarial findings (all addressed or logged, 2026-07-21)

Fixed immediately (with tests/checks):
- **Surrogate-only equivalence classes** were skipped by `grammarAlphabet`, so a grammar
  accepting exactly the UTF-16 surrogate range had an empty alphabet and `repair` returned
  null on a nonempty language. Representatives are now kept (the parser is code-unit-based).
- **The state budget depended on targetedRadius**, quietly re-making the radius semantic.
  Decoupled (same default value); the budget is a deployment safety valve only.
- **Marks reset across rounds**: characters written by an earlier round's commit were counted
  as user text by later rounds. Marks now persist across rounds.
- **Paper horizon definition** lacked the end-of-input probe (the replay lemma was false for
  the test-reads-only definition: S <- "a", input "aX"). Horizon is now defined as
  max(farthest test read, frontier). Proof-text gaps in the persistence argument closed via
  an occurrence-projection formulation; the "generates every member of L(G)" reachability
  overclaim replaced by the Sigma_G-subgraph statement; panic-ladder and budget-commit
  claims qualified as uncertified deployment fallbacks; edit-list-vs-cost asymmetry
  documented (the list is an alignment script and can exceed the sequence cost).

Logged as prerequisites for stronger claims (not yet implemented):
- **Edit-path certificate**: return the actual minimum-cost operation sequence (predecessor
  tracking or unrestricted-DL traceback) instead of only the alignment script.
- **Provenance-aware state identity**: `visited` is keyed by string, but strict progress
  depends on marks; two paths to the same string can carry different marks. Single-error
  exactness is unaffected (marks do not influence acceptance); multi-round dominance is not
  yet formalized.
- **Causal progress**: the frontier includes speculative consumption by rejected
  alternatives; a causal definition needs observer provenance (also wanted by the
  evidence-band ordering).

## 10. Skip-based "leading edge" recovery experiment (2026-07-21)

Prototype of a fundamentally different recovery model (Luke's proposal):
instead of repairing the *string*, keep the input untouched and resume the
*parse* - reconstruct the leading edge (the spine of in-progress
Seq/Repetition nodes at the failure), then for growing skip lengths n try to
resume each edge node, allowing Seq obligations to be skipped as "missing"
(partial Levenshtein restoration); insert SyntaxError spans and continue.
Implementation: `dart/lib/src/recovery/skip_recovery.dart` (driver outside
the parser; pure oracle preserved; synthetic matches stitched driver-side).

### Measured results (JSON, same 519-mutant sweep; eval scripts in session scratchpad)

- Speed: 0.66 ms/mutant avg (341 ms for all 519); every long-span case
  (DEL/INS/SCRAM up to k=64 on the 149-char doc) completes in <= 2 ms with a
  full-coverage tree - vs 43 s (committed) / budget-panic cost-40..150
  (global) for the repair search on the same inputs. Full-coverage trees
  519/519, no forced fallbacks; valid input passes through clean.
- Fidelity: original tree shape restored 210/519 (40.5%) vs repair search
  490/519 (94.4%). By mutation type: ins 126/216 (58%), sub 58/224 (26%),
  del 10/37 (27%), swap 16/42 (38%). Cost-1-equivalent recoveries (1 span
  char or 1 missing obligation): 160/519 (repair: 519/519 cost 1).
- Failure profile: quote-parity mutations (ins/sub/del of '"') cascade into
  large spans (worst: 46 skipped chars); multi-error doc handled in 2 events
  but swallows 16 chars where repair finds the 3-edit fix.
- Hard cases: LR expr "1+*3" -> clean "missing '*'-operand" style recovery;
  "(1+2*3" -> 2 one-char spans (repair: 1 insert); lookahead-guarded grammar
  -> trailing span (repair: cost-1 substitution).

### Design forces discovered (each via concrete counterexample)

1. The leading edge is not just the failing spine: stopped repetitions,
   empty-matched Optionals, and *wrong First choices* on the rightmost edge
   are where real errors hide (del '{' at 0: the document parses "short" as
   the string "a"; only re-choosing the Object alternative recovers).
   Prototype adds reopen frames + First re-choice for these.
2. Greedy cheapest-resumption is myopic: a cost-1 shallow hit that strands
   the rest of the input beats the correct deep fix. Fixed by aftermath
   scoring: enumerate hits, simulate pure continuation, maximize
   (aftermath - cost). One-step lookahead; still fails on some ties.
3. Ranking descent targets needs a "potential reach" metric; it must (a)
   fork hypothetical inner recoveries instead of advancing the walk position
   with them, and (b) budget skips (budget 2) or it saturates and stops
   discriminating. It remains blind to potential hidden behind char-garbage;
   a char-skip window (16) was tried and REVERTED - it re-saturated
   (in JSON any token matches within a few chars).
4. Left recursion cannot be reopened: the iteration lives in the memo
   table, not in a Repetition node. Post-LR errors degrade to trailing
   spans. Would need oracle cooperation (seeded re-expansion).
5. Termination needs cycle guards: LR descent revisits (clause, pos);
   re-choice can cycle. Guards: descend-visited set + depth cap 64 +
   stack cap 300 + event cap 4n+64 + wrapper always completes via
   trailing span.

### Meta-lesson and direction

Every fix pushed the greedy model toward best-first search: the prototype
converged on "repair search with edit alphabet {skip-span, skip-obligation},
beam width 1, heuristic = aftermath". The two designs are points on one
spectrum (edit set x search width x cost model). Complementary roles:
- Skip recovery: linear-time, full-coverage, honest ERROR-node trees;
  the principled replacement for the budget/panic fallback (Sec. 9's open
  deployment-valve problem) and the right default for IDE-style resilience.
  Note: on INS k=64 its "one garbage span" answer is semantically saner
  than the repair search's minimal-cost quote-wrapping of the garbage.
- Repair search: certified minimal edits; unmatched fidelity for small d.
- Best hybrid (unimplemented): skip-recovery pass localizes error regions
  and upper-bounds repair cost; windowed repair search then repairs each
  region; certified minimality where affordable, resilience everywhere.

## 11. Skip recovery round 2 (2026-07-21): the same rules, applied to more clause types

Luke's follow-up question: what MINIMAL fixes extend the skip model to
repair more cases, applying the same simple pattern (skip n input chars /
skip pending obligations) to other rules? Implemented and measured, in
order (all in `dart/lib/src/recovery/skip_recovery.dart`; sweep = the same
519 invalid single-char mutants; "shape" = original tree shape restored):

| change | shape restored | notes |
|---|---|---|
| (round-1 baseline) | 210/519 (40.5%) | ins 126, sub 58, del 10, swap 16 |
| + retract + Str-as-Seq | 222 (42.8%) | retract initially mis-costed (+1 event pressure made it tie and lose to span hits) |
| + retract cost = missing only | 234 (45.1%) | needed applied-signature guard: zero-cost retract oscillates with reopen-extend |
| + reach: deepen is free, skips pay | 246 (47.4%) | fixed "shallow wrong branch outranks deep true error"; but re-choice tunneling regressed ins |
| + re-choice budget 1 + conservative-first two-pass | 286 (55.1%) | re-choice must STRICTLY beat failure-following candidates |
| + two-way descent lookahead (per ambiguous level) | 292 (56.3%) | reach cannot rank; evaluate top-2 choices by actual scan score |
| + rewind (Seq-level give-back) | **294 (56.6%)** | ins 135, sub 116, del 20, swap 23 |

Cost: 0.66 -> 2.2 ms/mutant average (lookahead + probes). Still 519/519
full-coverage, forced 0, valid input clean, all long-span cases <= 48 ms
(first-call JIT included), multi-error doc improved (10 chars swallowed
vs 16), LR and lookahead grammars unchanged-safe. dart test: 308/308.

### The new moves (each is the user's skip rule applied to another rule)

1. **Retract** (skip leftward, Repetition): a greedy rep inside a matched
   tail child gives back trailing items; the enclosing Seq's remaining
   obligations re-walk from the truncation point (missing allowed, n=0).
   Cost = missing only (given-back chars are re-parsed, not errors).
   Termination: applied-signature set (rep, start, k) - never twice.
   This killed the worst family (quote-parity: Character* swallowing
   everything past a lost '"').
2. **Rewind** (skip before a matched child, Seq): give back trailing
   MATCHED children of a frame and place the span before them. Fixes
   "successful short parse" prefix garbage (`"{"a"...` parsed as the
   String `"{"` with no failing frame anywhere near the error).
3. **Str-as-Seq**: a multi-char literal is a Seq of single chars; the
   (J-j) rule then repairs corrupted keywords mid-token (`tQue` ->
   span Q, missing r, resume `ue`) instead of opaque garbage. Plus a
   prefix-reach term so descent can choose the corrupted literal.
4. **Reach re-accounting**: deepening into a mismatched sub-clause is
   free (same error, localized deeper); only skipping past an obligation
   pays budget. Charging both made a shallow wrong branch (1 charge)
   outrank the true error 3 levels down (3 charges for one error).
5. **Re-choice discipline**: budget 1 (an alternative replacing a
   successful parse must be near-clean) and conservative-first ranking
   (re-choice must strictly beat every failure-following candidate).
6. **Two-way lookahead**: reach has no char-skip model and saturates on
   tunnels of real matches, so at each ambiguous descent level the top-2
   choices are evaluated by their actual best scan score (evaluation
   descents don't recurse the evaluation - linear work per event).

### Remaining failure families (identified, unimplemented)

- **Early close** (~15-20 cases, worst at 33-34 chars): `{"a":1}` + rest -
  a '}' inserted early makes a VALID short Object; fixing it needs rewind
  + re-descent (recovery inside the re-matched region), i.e. recursive
  application of the whole machinery to a rewound attempt - another step
  toward full search.
- **Str alignment**: prefix-only reach misses keyword corruption at token
  start (`rue` for `true`); a tiny banded edit-DP over (text pos, budget)
  would cover it.
- Two-way lookahead is per-level and top-2; a k-way, cross-level beam is
  the next rung on the ladder to best-first search.

### Meta-lesson, reinforced

Round 2 repeats round 1's lesson at a finer grain: every extension that
worked (aftermath over greed, lookahead over reach, cost = reported
errors) is a step from "greedy rule" toward "best-first search over
structural edits". 56.6% shape restoration at ~2ms/case vs the repair
search's 94.4% at seconds-per-case for d>=2 brackets the design space;
the hybrid (skip pass localizes + windowed repair certifies) remains the
recommended synthesis.

## 12. The nesting cross-product and the universal principles (2026-07-22)

Question (Luke): under the greedy leading-edge rule, take the full cross
product of clause types nested in clause types, cross damage kinds
(ins/del/mut), and extract the universal principles for optimal recovery.

### 12.1 Compositional reduction

The 8 containers (Seq, First, Opt, Star, Plus, &, !, Ref) x 12 containees
(those + Char, CharSet, Str, Nothing) x 3 damage kinds = 288 cells reduce
compositionally: a containee's damage response is summarized at its
boundary as one of five classes, and each container transforms that class;
nesting deeper than two levels is the same transform iterated (structural
induction, damage responses compose associatively).

Containee boundary responses to interior damage:
- F      fail at own start (progress HIDDEN by PEG failure semantics)
- S<     succeed short (fallback fired: Opt-epsilon, Rep close, short alt)
- S>     succeed long (absorber swallowed past the damage)
- S=     succeed same-length wrong (silent; often still-valid)
- M      migration (charset accepts the damaged char; damage slides to the
         region's edge and re-manifests at the next anchor)

Container transforms of a failing/short/long child:
- Seq:   F -> F (hides progress); S< -> next child misaligned (leftover
         garbage); S> -> next child starved (needs give-back); affords
         missing-suffix (J-j) and rewind.
- First: F -> tries siblings: wrong-alt capture (S< / S> / S=) or F with
         best-alt progress DISCARDED; affords descend-by-progress and
         re-choice. Damage can also invert PEG priority silently (an
         earlier alt starts matching: still-valid, wrong shape).
- Opt:   F -> S< always (total failure laundering); affords reopen.
- Star:  F at item k+1 -> S< close (laundering); item S> -> cascade
         misalignment of later items; affords extend and retract. Item
         Seqs make repairs straddle iteration boundaries (suffix-missing
         + reopen + prefix-missing in one conceptual repair).
- Plus:  k=0 like Seq child; k>=1 like Star.
- &:     child F -> zero-width F; the damaged chars are RE-READ by the
         consumer: obligation duplication (measured: cost 3 for 1-char
         damage, missing &K + span + missing c). Input-edit repair does
         not have this problem (one edit satisfies both readers).
- !:     inverts: damage making X match -> !X fails, and the obligation is
         NEGATIVE: no grammar-side repair exists, only input-side (span).
         Damage making a guard fail -> silent overrun (the !-form of the
         absorber).
- Ref:   transparent (+ memo); left recursion: the expansion count lives
         in the memo, so one level is re-enterable via re-choice, deeper
         re-expansion needs recursive recovery (measured: shape truncates
         one level).

Damage kinds map onto the two streams: ins is repaired input-side (span),
del grammar-side (missing), mut both; swap is composite. Forged evidence
(ins/mut TO an anchor char) closes structure early; destroyed evidence
(del/mut OF an anchor) makes absorbers overrun. Mirror duals.

### 12.2 What the cross product exposed (measured, micro-cells + sweep)

Micro-cell harness (scratchpad micro_cells.dart) confirmed per-cell:
control Seq/Char cells optimal; absorber self-limits unless the swallowed
region contains downstream anchors; item-boundary cells all restore;
&-duplication (cost 3 vs 1); !-flip span-2 vs optimal 1; token-start span
4+missing (vs optimal 2); LR one-level re-entry. Anchor/content cross-tab
over the 519-mutant sweep: content damage is mostly silent (89/234
still-valid) or repairs in place (disp avg 0.1); anchor damage carries
almost all hard cases.

Debug-tracing the worst live family (whole-subtree spans on content subs,
e.g. tQue -> the entire enclosing Array spanned) found TWO new ranking
pathologies, both instances of one law:

1. Absorber tunneling in the reach metric: with one budgeted skip,
   Character* tunnels to the next quote, giving WRONG alternatives
   (Object/Array/String) reach 25 with ZERO real progress, tying each
   other and OUT-RANKING the true alternative (Boolean, honest prefix
   reach 19). First order then picked Object; the surgical repair was
   never on the stack.
2. Visited-set poisoning: sibling reach probes shared exploration state,
   so a sub-probe first reached under an exhausted budget blocked a later
   fuller probe (Array ranked below String for no structural reason).

### 12.3 Round-3 fixes (both derived from the analysis)

1. k-way consequence eval at First descent: reach ties are structurally
   meaningless, so up to two members of the top class plus the best of
   the next class are evaluated by actual scan score (same _inEval
   machinery as _descendFrom's two-way eval).
2. Progress-primary ranking: alternatives are ranked by budget-0 reach
   (real matches / prefix agreement only) FIRST, budgeted reach second.
   Real progress cannot be faked by tunnels; speculation only breaks
   progress ties. This also made the common case cheaper (unique progress
   max -> no eval at all).

Result: 294/519 (56.6%) -> 426/519 (82.1%) at 2.77ms avg; ins 197/216
(91%), sub 175/224 (78%), del 29/37, swap 25/42; forced 0; coverage
519/519; long spans <= 49ms; multi-error unchanged (2 events, 10 chars);
LR/lookahead unchanged; valid doc clean; 308/308 tests; repair search
untouched (519/519 cost-1, 490/519 = 94.4%). Remaining worst list is now
PURELY the predicted families: forged-anchor early close (ins/sub -> '}'
at 33-34 chars), token/document start (sub@0), forged opener (ins '"'),
swap composites.

### 12.4 The universal principles

P1 Two-stream duality. A parse error is a desynchronization between the
   input stream and the obligation stream the grammar unfolds. The only
   two primitive repairs are: advance input without obligations (span,
   repairs insertions) and advance obligations without input (missing,
   repairs deletions); mutation = both. Luke's two original rules are
   the two sides; they are jointly complete at the point of repair.

P2 Commit-undo completeness. PEG determinism comes from greedy commits:
   choice (First/Opt), munch (Rep/absorbers), consumption (terminals),
   order (Seq). Each commit type displaces failure in its own way, so a
   complete recovery needs one UNDO per commit type: re-choice, retract,
   rewind, reopen. Every round-2/3 move slots into this taxonomy; the
   remaining families (early close, token start) are the not-yet-recursive
   undos.

P3 Displacement law. Fallbacks launder F into S< (failure surfaces later,
   structure already lost); absorbers convert del/mut of anchors into S>
   (failure surfaces later, position overrun); PEG failure semantics hide
   progress (failure reported earlier than the damage). The frontier is
   therefore only a lower bound estimate; optimal recovery must search
   BOTH directions from the stall, which is why forward-only span growth
   is incomplete, not merely suboptimal.

P4 Anchors carry the information. Low-frequency structural tokens
   (delimiters, keywords, predicates) are where input and obligations can
   be re-synchronized; charset interiors are alignment-neutral (damage
   migrates freely, usually silently). Forged anchors close structure
   early; destroyed anchors let absorbers overrun. Recovery difficulty is
   a function of anchor damage, not damage count (measured: content disp
   0.1 avg, anchor carries every 10+ char failure).

P5 Real progress dominates speculation. Chars actually matched (prefix
   agreement included) are evidence; budgeted-skip reach is hypothesis.
   Rank by evidence first; use hypothesis only to break evidence ties
   (round 3's decisive fix: +25.5 points). Corollary: never let two
   hypotheses tie-break each other by ORDER; ties must be settled by
   consequences (scan score) or not at all.

P6 Consequences decide, costs report. The user-visible cost function
   (span chars + missing count) defines optimality; search-guidance
   quantities (reach, budgets, aftermath) must never leak into it
   (round 2's retract +1 bug) and heuristic ties must always fall
   through to consequence evaluation (rounds 2 and 3, three separate
   instances measured: descent-level, First-level, tie-order).

P7 Silent-change limit. Damage that yields a valid parse (137/656 here)
   is invisible to ANY parse-triggered recovery - absorbed insertions,
   priority inversions, merged tokens. Only out-of-grammar redundancy
   could catch it. This bounds every recovery design, including repair
   search.

P8 Zero-width obligations break tree-side cost coherence. Predicates
   read input the consumer will re-read: obligation-skip repairs double-
   count (&), and negative obligations (!) have NO grammar-side repair.
   Input-side repair (string edit) is coherent for both. A skip-model
   driver should re-test predicates after each candidate rather than
   discharging them when possible.

P9 The limit object is A*. States = (input pos, residual obligation
   stack, undo set); moves = span+1 / missing / undo-commit(+re-descend);
   cost = spans + missings; heuristic = aftermath. The greedy leading-
   edge rule is the beam-1 specialization; the repair search is the
   beam-infinity, char-granularity point; every fix that has ever worked
   (aftermath, lookahead, progress-first, k-way eval) moves the skip
   driver one step along this dial. Optimal recovery "given the nature of
   PEG" = lazily reconstructing, near errors only, the viable-prefix
   information that PEG's commits discarded (what GLR keeps eagerly
   everywhere) - pay for nondeterminism only where damage demands it.

### 12.5 Still open (ranked)

1. Recursive re-descend (one move: give back a committed success, re-run
   recovery inside the re-walk) - subsumes early-close, !-flip, LR
   re-expansion; the last big family (~30-40 cases incl. most swaps).
2. Banded Str DP for token-start alignment (sub@0 family).
3. Extend progress-primary + consequence-eval discipline to
   _rankedChoices (currently reach-sorted with rank tie-break).
   (Tried 2026-07-22: sweep 426->427, but the multi-error doc regressed
   10->16 chars swallowed - a 9-char span ate the "bc" string. Reverted:
   prog-primacy at the descent level needs the Sec. 13 formulation, not
   another local patch.)
4. Structure-preservation tie-break at equal (score, cost) - measured in
   micro-cell M5-mut: flatten-vs-reopen tie resolved by frame order, the
   only tie class where the metric is blind to structure.
5. Hybrid certify pass (windowed repair search around each event).

## 13. Meta-analysis: the pure core the zoo was shadowing (2026-07-22)

Question (Luke): is there a single, simplest, purest principle that
handles the P1-P9 failure modes, instead of the accumulated move zoo?

### 13.1 The tell

_aftermath() already simulates the pure continuation of every candidate
repair - and then throws the simulation away, keeping a score. The driver
computes the successor STATE of each candidate and discards it. Every
heuristic subsystem (aftermath scoring, two-way/k-way consequence eval,
conservative-first ranks, re-choice budget gates, applied-once signatures)
exists to compensate for that discard.

### 13.2 The pure core

  Parse greedily; when stuck, be GLR locally; charge only for skipped
  chars and skipped obligations; expand cheapest-then-furthest first.

Formally: cost-ordered search over states (input position, residual),
where a residual is the spine of dotted clauses still owed:

- FREE move: consume real input (the "snake" - driven by the memoized
  pure oracle, so re-deriving state anywhere is cheap).
- COST-1 moves (the only two, = Luke's original rules): skip one input
  char (span); skip one leaf obligation (missing).
- COST-0 lateral moves: switch to a sibling residual at the same
  position - a different First alternative, a shorter repetition, an
  un-taken Optional, given-back Seq children. These undo ORDER/MUNCH
  POLICY, not evidence: both residuals derive the same consumed prefix,
  so no cost. The entire move zoo (reopen, extend, retract, rewind,
  re-choice, re-descend) is the lazy materialization of this class.
- ORDER: priority queue on (cost, then furthest snake reach) -
  generalized Myers O(ND) diff between the input and the grammar's
  language, with parsing as the diagonal runs.

Every remaining mechanism is subsumed rather than approximated:
- aftermath        -> the successor state's snake (kept, not discarded)
- two-way/k-way eval -> actual queue expansion order
- progress-primacy -> furthest-reach tie-break (Myers greed)
- conservative-first -> committed residual has max reach at cost 0, so
  it is expanded first automatically; alternatives surface exactly when
  the committed line stalls - no rank constants
- re-choice budget-1 -> unneeded: lateral states enqueue at same cost
  but lower reach, so they wait their turn
- applied-once signatures / close-empty gates -> a standard closed set
- Str-as-Seq -> obligation granularity (a literal is a Seq of chars)
- event cap -> the cost bound d itself

And the P-mapping: P1 = the two cost-1 edges; P2 = cost-0 closure;
P3 = search regenerates state in both directions, frontier not
privileged; P4 = anchors are where snakes die/restart (rapid class
collapse); P5 = expansion order; P6 = cost IS the order, heuristics
never commit; P7 = cost-0 complete parse => search never triggered
(provably out of scope for any parser-side method); P8 = predicates
are per-state zero-width evaluations, not skippable leaves - the
double-count incoherence disappears; P9 = this IS the limit object,
made lazy.

Known points on the dial: beam-1 + hand-rolled closure = current skip
driver; full frontier at char granularity, input-side edits only =
repair_search.dart (its measured radius-invariance is evidence the
cost-ordered shape converges robustly); closure everywhere, no edits =
GLR; closure nowhere, rule-level skips = classic panic mode.

### 13.3 Complexity (and the recursive re-descend question)

Recursive re-descend as literal recursion: naive (sub-recovery per
candidate at scan time) is multiplicative per level - exponential in
nesting depth. Disciplined (apply-time only, shared global event budget)
adds only constant factor. In the frontier formulation the question
dissolves: "give back + re-enter" is one edge; recursion depth becomes
the edit budget d. Per error: states within cost d of the committed
parse = O(d x spine depth x alternatives + anchor occurrences for
retract targets), each state O(1) amortized memoized probes for its
snake. Ground truth says d is tiny: 519/519 single-point mutants repair
at cost 1 (repair-search sweep); skip events are almost all cost <= 2.
Uniform-cost => first complete state popped is minimal (the repair
search's early-commit lemma shape, Lemma 6.4).

Multi-error stays linear via a snake-stability commit: pop states until
one's snake runs K chars (a few anchors) past its last edit, commit it,
resume normal parsing to the next failure. The window is defined by
suffix agreement, not by a fixed radius.

### 13.4 Brainstormed alternatives (scored)

| Candidate pure core | Score | Reasoning |
|---|---|---|
| Frontier unification (13.2): enqueue-and-continue, reuse existing enumerators as edge generators | 9 | Subsumes every measured fix; deletes six heuristic subsystems; complexity bounded by d<=2 empirics; unmeasured until built (hence not 10) |
| Windowed char-granularity repair search per event (hybrid) | 7 | Same object, dual (input-edit) coordinates; already exists; loses obligation-side structure preservation |
| Cost-semiring weighted-PEG interpreter (Pareto memo on (clause,pos,d)) | 6 | Same object as formalism; memo blowup risk; harder to keep the oracle pure |
| Brzozowski derivative-sets for PEG | 6 | Identical object in derivative clothing; heavier machinery, no added power |
| Bidirectional bracket (reverse parse pins damage right edge) | 5 | PEGs don't reverse (predicates, order); snake-stability yields the benefit forward |
| Keep patching the zoo cell-by-cell | 3 | Works (40.5->82.1% proves it) but each new cell costs a bespoke move + guard, and composites are unbounded |
| Static grammar transform (error productions / sync sets) | 2 | Context-free by construction; refuted by capture/tunneling cells needing consequence-awareness |

### 13.5 Recommended next step

Implement the frontier core behind the same SkipResult API: states =
(pos, spine snapshot, cost, spans, missings); edges from the EXISTING
enumerators (_kwalk, _reopenCands, _retractCands, re-choice collection);
priority (cost, -reach); snake-stability commit K ~ 8-16 chars; closed
set on (pos, spine hash). Baseline to beat: 426/519 @ 2.7ms, multi-error
10 chars, all 308 tests. Then delete _inEval, aftermath, budget gates,
and applied-once signatures, which it obsoletes.

## 14. Frontier implementation and the semiring transcendence (2026-07-22)

### 14.1 What was built

`dart/lib/src/recovery/frontier_recovery.dart` (new, ~650 lines,
uncommitted): the Sec. 13 design realized. States (spine, pos, cost);
priority queue on (cost, edit-diameter, span-chars, reach, age); free
snakes via the pure oracle; edits = span-char / missing-obligation
(cost 1); free branchful expansion of the failing obligation; free CUTS
(un-commit matched material through a threaded spine-builder context,
budget 2 per path); dedup on (pos, spine-hash) with cost-aware push
filtering; commit on completion only; pop-cap bailout to best progress.
The baseline skip driver is untouched; both share SkipResult.

### 14.2 Measured (all gates re-run on the final configuration)

Sweep: 466/519 (89.8%) at 10.5ms avg - vs the tuned skip driver's
426 (82.1%) at 2.8ms and repair search's 490 (94.4%) at seconds-scale.
ins 202/216, sub 193/224, del 32/37, swap 39/42 (skip driver: 25/42).
Zero coverage failures, zero forced. WORST CASE 2 CHARS SKIPPED - the
skip driver's 33-34-char catastrophic tail (early close) is gone.
Solved outright by cuts+queue: early-close, !-flip (span 1), Str
token-start (cost 2 - obsoletes the banned-DP item), LR extend
(1+23 -> missing '+', 3-level shape), trailing-Optional ties, multi-
error at exact minimal cost (1 event, cost 3). Micro-cells 23/25
(remaining: the genuinely ambiguous First-confusable tie and one LR
ins). 308/308 tests; repair search untouched.

Bugs found by measurement, fixed: frame aliasing (a pushed state's snake
mutates frames later copied - stale child duplicated); context-less cut
recursion (nested truncation delivered as whole top-level child -> 88
non-covering trees); span/missing lists leaking entries given back by
cuts.

Experiments tried and REVERTED (recorded in-code): immediate stability
commit (absorber makes fake stability; cost-2 repair -> committed
cost-5 cascade); deferred-acceptance stability (fixed long-doc quality,
but cost-0 cut-only reinterpretations preempt done: 466 -> 412);
clustered edit diameter (exempts exactly the spread exploits whole-
diameter kills: 466 -> 407).

Cost-model findings (properties of the SEMIRING, not the search):
- Fabricated-escape degeneracy: at equal cost and compactness, "missing
  backslash" repairs that re-role real quotes tie with honest repairs
  (multi-error picks one; sub@31 family). Geometry cannot separate them;
  anchor-role weights can.
- Absorption beats honesty on long damage: linear span cost makes
  min-cost prefer absorbing 16 garbage chars into fabricated structure
  (cost ~7) over spanning them (16). Affine span cost (per-span constant
  + small per-char) is the lever if honest spans are wanted.
- Long-input scaling: uniform cost explodes at repair cost >= 4 on a
  137-char doc; pop-cap bailouts give erratic compromises. The cure is
  an admissible heuristic, not a stability proxy (see 14.4).

### 14.3 The pika lessons (../pikaparser, paper Sec. "Error recovery")

Pika parses bottom-up right-to-left, so the memo table is always full to
the right of the parse position: recovery = a passive READ (stitch
islands of designated recovery rules; getSyntaxErrors() inverts their
covered ranges), at the price of a large constant (every rule at every
position; the Java-grammar benchmark loss). Pika and packrat are the
eager and lazy extremes of ONE chart; the frontier is the demand-driven
middle. Luke's judgment that switching to pika wholesale is wrong for
local repairs holds: eager right-side work pays off only as GUIDANCE.

### 14.4 The transcendent principle

  There is no error recovery. There is only parsing, evaluated in a
  larger semiring.

Extend the grammar with two weighted productions per clause C:
C -> <span-char> C (cost 1) and C -> epsilon (cost 1, "missing"); keep
PEG semantics; interpret over (min, +). chart[C, p] = lightest match.
Then:
- the pure parser  = the zero-cost slice, evaluated lazily left-to-right
  (packrat memoization);
- pika             = the zero-cost slice, evaluated eagerly bottom-up
  right-to-left (recovery becomes a read);
- repair search    = the cost-k slices in input-edit coordinates;
- frontier         = the cost-k slices, best-first (Knuth's lightest-
  derivation algorithm; the agenda is the queue), both coordinates.
Every mechanism this project ever built is an evaluation strategy of
that one closure, and the remaining quality gaps (escape degeneracy,
absorption-vs-honesty) are properties of the WEIGHTS, not of any
algorithm. The design space is a plane: (which cost slice) x (which
evaluation order); "simplify, optimize, robustify" = pick points per
need - zero-slice lazy for valid input, weighted best-first near damage,
eager right-side zero-slice as the admissible A* heuristic h for long
inputs (pika as h: distance to the next island of the pending
obligation, O(log n) per lookup from a NavigableMap chart).

### 14.5 Roadmap (scored)

| Step | Score | Why |
|---|---|---|
| Pika-index A* heuristic (right-side islands as h + span targets) | 9 | The principled cure for long-input scaling; makes bounded commits sound |
| Anchor-role weights in the semiring | 8 | Kills the escape/re-roling degeneracy family (sub@31, multi-error variant) |
| Replace skip driver with frontier as THE driver | 7 | After the two above; deletes six heuristic subsystems for good |
| Affine span cost | 6 | Honest long spans vs absorption - a semantics choice to make deliberately |
| Persistent spines (structural sharing) | 6 | 10.5ms -> ~3ms; pure perf |

## 15. The semiring principle, built literally (2026-07-22)

Sec. 14.4 was analysis; this section is the measurement. Luke asked
whether the transcendent principle (and the pika-index A* item) had
actually been BUILT, and if not, to build the pure thing standalone --
no skip-driver machinery, no frontier machinery -- and measure it.
Answer to the first question: neither had been built (the frontier
APPROXIMATES the principle with events, pop-caps and cut budgets; the
A* index was a roadmap item). The pure object now exists:

    dart/lib/src/recovery/semiring_recovery.dart

### 15.1 What it is

The closed grammar (C -> <span-char> C, C -> epsilon, per clause),
evaluated by direct dynamic programming: chart[C, p] = Pareto set of
weighted matches per end position. No search, no events, no frames.
Two structural facts fell out immediately:

- The span production makes cell (C,p) depend on (C,p+1), which FORCES
  pika's evaluation order (right-to-left, bottom-up, within-position
  fixpoint). The "two bullets" of the request are one artifact: the
  weighted chart IS the pika idea taken to its limit, and once it is
  evaluated eagerly the A*-heuristic question dissolves (the chart does
  not approximate remaining repair cost; it computes it exactly; an A*
  index is only meaningful as an accelerator for the LAZY frontier).
- The within-position fixpoint handles left recursion with zero special
  casing (M10 LR cells all pass, including the ins case the frontier
  lost).

Interpretation decisions (documented in the file header): ordered
choice = per-end min (PEG commitment is not a semiring operation; PEG
tie-breaks restored at extraction; measured divergence on the zero
slice: ZERO cases in 519); predicates consult the zero slice via the
pure Parser as oracle (negation is not monotone under min); repetition
items must advance; a multi-char Str under the closure IS banded edit
distance (the Sec. 13 banded-DP item is not a feature, it falls out);
iterative deepening on a cost cap with a certificate (all 519 sweep
repairs certified minimal within cap 4; histogram 375 at cost 1, 144
at cost 2).

### 15.2 The weight iterations (each measured on the 519-mutant sweep)

| Weighting / order | Sweep | ins/sub/del/swap | Note |
|---|---|---|---|
| v1: pure cost (min,+) only | 366 (70.5%) @ 28ms | 203/105/30/28 | equal-cost ties decided arbitrarily; absorbers win subs |
| v2: + compactness (cost, diameter, spanChars asc; Pareto cells) | 431 (83.0%) @ 119ms | 186/178/30/37 | diameter kills spread absorbers (quote re-roling) but spanChars-asc prefers fabrications over honest spans on ins |
| v3: + distance-to-failure tie-break | 448 (86.3%) | 190/189/32/37 | REVERTED: syntaxErrorPosition() is rule-START granular (rule-level memoization), mis-anchored M5 |
| v4: first-edit-latest instead (P5 as a selection order) | 450 (86.7%) | 192/189/32/37 | no oracle anchor needed; M5 fixed |
| v5: + structural epsilon: eps(terminal)=1, eps(composite)=2 | **469 (90.4%)** @ 115ms | 202/193/34/40 | P8 made a weight: fabricating a structure out of nothing must cost more than missing one corroborated leaf |

v5 headline vs the other drivers on the identical sweep:

| | skip driver | frontier | SEMIRING CHART | repair search |
|---|---|---|---|---|
| shape restored | 426 (82.1%) | 466 (89.8%) | **469 (90.4%)** | 490 (94.4%) |
| micro-cells | 21/25 | 23/25 | **24/25** | -- |
| content-subs | 4/4 | 4/4 | 4/4 | -- |
| multi-error | 10 chars | cost 3 (escape variant) | cost 3 (escape variant) | cost 3 |
| coverage/forced | 0/0 | 0/0 | 0/0 | n/a |
| avg time (n=49) | 2.8ms | 10.5ms | 115ms | seconds |
| n=137 typical | -- | ~ms, but INS-family 56-char over-spans | ~400ms, repairs 0-1 spans (bailout family GONE) | seconds |

The remaining micro loss is M4 aQxy (genuinely ambiguous First
confusable). dart test: 308/308; repair search untouched.

### 15.3 What the exact evaluator taught (the important part)

1. The frontier's residual edge (before v5) was BENEFICIAL
   SUBOPTIMALITY. Enumerating the 519-sweep losses showed most were not
   ties: with eps=1 uniform, "missing Member" (fabricate a whole
   structural node for 1) and "missing '\\'" (re-role a real quote for
   1) are genuinely CHEAPER than the honest span+missing (cost 2). The
   frontier never found those global minima because local commits and
   cut budgets hid them; the exact chart HAS to find them. An exact
   minimizer exposes the true degeneracy of the weight model -- you
   cannot fix it with a better search, only with better weights.
2. Structural epsilon (P8 as a weight) is the first anchor-role weight,
   and it alone was worth +19 points. It also subsumed the planned
   "prefer deepest epsilon" extraction hack: with leaf-eps cheaper, the
   deep witness (Value(Number()) via missing digit) is cheaper than the
   shallow fabrication (missing Object), not just tie-preferred.
3. Selection orders cannot resolve span-vs-missing in general: M5 (del
   f: honest = missing, LATER, fewer span chars) and ins-comma (honest
   = span, EARLIER, more span chars) are perfect opposites on every
   axis in the value tuple. The discriminating information (which char
   was inserted vs deleted) is not in the tuple; structural-eps
   resolved the family by making the fabrications non-ties.
4. Remaining loss families (all weight-level, all with the fabrication
   strictly cheaper): (a) escape fabrication: sub@3/sub@10 quote->X,
   missing '\\' at the next real quote re-roles it, cost 1 vs honest 2;
   (b) interior-span absorption: sub@14 ,->X, a span INSIDE Number's
   digit run merges two Numbers, cost 1 vs honest 2 (the frontier
   cannot even reach this repair -- its spans only insert at frame
   boundaries, an accidental structural prior worth stating: spans
   at boundaries only); (c) INS-64 long damage absorbed as string
   content for cost ~2 instead of 64 honest span chars (affine span
   cost is the lever).
5. Scaling (one sub error, JSON arrays of repeated objects):
   n=50: 146ms; n=99: 307ms; n=197: 700ms; n=393: 1.8s; n=785: 6.2s
   (valid-doc chart builds slightly slower than damaged: 176ms..10.9s).
   Empirically ~n^1.5 in this range with the pika constant. SCRAM-64 on
   n=137 took 9.4s (deepening). The eager exact chart is a BATCH tool;
   interactive use needs the lazy frontier or the A* hybrid.

### 15.4 Where this leaves the design plane

The plane (cost slice x evaluation order) now has all four corners
measured, plus the first weight enrichment: values (cost, spanChars,
editLo, editHi) with lexicographic (cost, diameter, firstEdit-latest,
spanChars) and Pareto cells -- still a valid weighted interpretation
(dominance is monotone under composition; an exchange argument gives
optimality). Compactness, leading-edge, and structure-costs-more are
now WEIGHTS, not heuristics. Roadmap after this build:

| Step | Score | Why |
|---|---|---|
| Anchor-role weights, round 2: escape/quote roles + affine span cost | 9 | The ONLY remaining loss families are cheaper-fabrications; measured, named, reproducible |
| Lazy best-first evaluation of the SAME enriched semiring (frontier v2) | 8 | Frontier + structural-eps + Pareto values = chart quality at frontier speed; the chart is now the executable spec |
| Pika-index A* h for the lazy evaluator | 7 | Still the scaling cure for the lazy side; the eager chart showed what h must bound |
| Packed values / persistent cells for the eager chart | 5 | 115ms -> ~20ms plausible; only matters for batch use |

## 16. The push to one mechanism (2026-07-22/23)

Luke: "you're still not there yet at the most optimal, pure, efficient,
robust, and in particular, simplest solution possible." Two moves, both
measured.

### 16.1 The weights cannot get simpler (ablation)

Selection-order ablations on the eager chart (full Pareto kept
internally, so each run is exact for its own order):

| order | sweep |
|---|---|
| cost only (+ structural eps) | 403 (77.6%) |
| (cost, first-edit-latest) | 450 (86.7%) |
| (cost, diameter, first-edit-latest, spanChars) | 469 (90.4%) |

Every component is load-bearing; the enriched tuple IS the minimum.
Simplicity had to come from the machinery instead.

### 16.2 agenda_recovery.dart: weighted deductive parsing, one loop

dart/lib/src/recovery/agenda_recovery.dart (~700 lines): agenda-based
weighted deduction over the closed grammar -- Knuth's lightest-derivation
algorithm (the grammar generalization of Dijkstra) -- with the enriched
weights on the queue. Items are complete matches and dotted partials;
rules are the clause semantics plus the two closure productions; the
first time the goal item pops it is lex-optimal (superiority: every
conclusion is lex->= each premise; cost adds, the edit interval only
grows under union, spanChars add).

Machinery DELETED relative to what it replaces:
- iterative deepening + optimality certificate (pop order is the
  certificate);
- the within-position fixpoint (left recursion is just a cyclic item
  dependency under monotone improvement -- M10 passes with no special
  casing);
- pop caps, bailouts, event loops, spines, frames, cut budgets (nothing
  to cap; cuts never existed -- un-commitment is not needed when nothing
  commits);
- the entire witness re-derivation layer (~250 lines of suffix DPs and
  greedy backtraces, one of which had a mode-dependent bug): every kept
  value carries the backpointer that produced it;
- the banded-DP special case for Str (desugared to a Char sequence; edit
  distance inside literals falls out of the uniform closure);
- trailing-garbage special case (goal = Seq(Top, EOF) where EOF has the
  span production like everything else).

Three bugs found on the way, each a lesson:
1. Partial items were dominance-pruned in a bucket keyed by
   (seq, dot, position) but not START -- dominance must only relate
   values of the SAME item. (Cost-7 repairs where cost-1 existed.)
2. At exact-value ties the first-arrived witness won, diverging from the
   chart's PEG-preference extraction (sub@5 1->Q: missing-digit inside
   Number ties with missing-"true" inside Boolean at the same tuple).
   Fix: backpointers are mutable; an equal-value arrival with a
   preferred derivation (normal < span < eps, then lower First-alt
   index) re-points the incumbent -- parents reference the entry, not
   its derivation, so the re-point propagates consistently.
3. The goal can pop at the SAME lex key as pending witness improvements
   (del@5(1)); fix: drain the equal-key plateau before extracting --
   still exact, since nothing below the goal key can appear.

### 16.3 Measured standing (all same harnesses)

| | skip | frontier | eager chart | AGENDA | repair search |
|---|---|---|---|---|---|
| sweep 519 | 426 (82.1%) | 466 (89.8%) | 469 (90.4%) | 469 (90.4%) | 490 (94.4%) |
| micro / content | 21/25, 4/4 | 23/25, 4/4 | 24/25, 4/4 | 24/25, 4/4 | -- |
| avg ms (n=49) | 2.8 | 10.5 | 115 | 11.5 | seconds |
| n=137 typical | -- | ms, bailout artifacts | ~400ms | 30-230ms | -- |
| n=785, one error | -- | -- | 6.2s | 0.77s (~linear) | -- |
| valid doc | -- | -- | chart anyway | ~1ms (pure parse) | -- |
| exact? | no | no | yes | yes (first-pop) | yes (its model) |

Cross-verification: the agenda's 50 sweep losses are IDENTICAL to the
chart's, case for case -- two architecturally different exact evaluators
of the same objective agreeing everywhere. dart test 308/308; repair
search untouched.

Honest tail: at HIGH repair cost the uninformed best-first breadth
inverts the advantage (SCRAM-64 on n=137: agenda 19.5s vs chart 9.4s;
both exact). This is precisely the A* regime: the pika-style right-side
island index as an admissible h added to the queue key -- the agenda is
its natural host (one addition in _cmp/push, no structural change).

### 16.4 The architecture, final form

    parse:   the pure parser (zero-cost slice, lazy packrat).
    recover: the SAME grammar, closed with span/epsilon productions,
             evaluated best-first under (cost, diameter,
             first-edit-latest, spanChars) with structural epsilon.
             First goal pop = certified minimal repair, backpointers =
             the tree, full coverage by construction.

One parser, one closure, one queue. The skip driver and the frontier are
subsumed (the frontier's every heuristic is now either a weight, a queue
order, or unnecessary); the eager chart remains as the executable spec
that cross-checks the agenda. The remaining 50 losses are all
cheaper-fabrication weight families (escape re-roling, interior-span
absorption, ambiguous nesting), untouchable by ANY search improvement.

Roadmap: (1) A* island index on the agenda queue (high-cost tail,
score 8); (2) anchor-role weights round 2 (the 50, score 8); (3) ports
after the Dart form settles (frontier_recovery.dart and
skip_recovery.dart can be retired when the agenda is adopted; keep
semiring_recovery.dart as the spec/cross-check).

## 17. Dot recovery: recovery is two transitions at a Seq dot (2026-07-24)

`dart/lib/src/recovery/dot_recovery.dart`, 785 lines. This supersedes
§16. Written in answer to two questions, both of which turned out to be
right in substance and to sharpen into theorems.

### 17.1 The two questions, answered

**(a) "Rather than rewriting the grammar to add span/ε forms of every
rule, shouldn't the parser just have a recovery mode?"**

Half premise-correction, half real insight. The closure was never
*materialized*: `agenda_recovery.dart` has no rewritten grammar
anywhere -- the span/ε productions live inside its transition function,
which is exactly "a recovery mode in the parse function". So (a) as
stated describes what already existed.

But the instinct pointed at something real. Conceptually the closure
still grants *every* clause at *every* position the right to eat garbage
from its left, and that is `|G| × n × cost` redundant work. Theorem 1
below deletes it, and that is the actual content of this section.

The other half of (a) -- decide recovery **greedily**, accepting the
first thing that re-matches after skipping k characters -- is a separate
proposal, and it was already built and measured: that is precisely
`skip_recovery.dart`. It scores **426/519** with no optimality
certificate, against 477 for the exact search. Greedy is 2× faster and
loses 51 cases; it is a real point on the curve, not the destination.

**(b) "Only Seq and ZeroOrMore/OneOrMore can advance the position, so
only they need recovery logic."**

**Correct, and now provable** (Theorem 1). Two refinements:

1. Recovery must be **re-entrant**: a subclause attempted during
   recovery is itself parsed in recovery mode. Otherwise a repair
   interior to a `First` alternative is unreachable. This falls out for
   free in a deductive formulation and is easy to get wrong in a
   recursive-descent one.
2. Repetition is a *second* site only because it is compiled natively.
   Since `A* ≡ R where R <- A R / ε`, desugaring it would leave **the
   Seq dot as the single recovery site in the entire parser**.

### 17.2 Theorem 1 (leading-span hoisting)

`C → <span-char> C` only ever absorbs garbage at C's **left edge**.
Absorbing k characters immediately before C is derivationally identical,
and cost-identical, to absorbing them immediately before C's slot in its
parent. Ascending the parse tree, every slot is a Seq dot, a gap between
two Repetition items, or the root.

⇒ A span transition is needed at **exactly** those three sites: Seq dots
≥ 1, Repetition item gaps, and dot 0 of the goal wrapper (the only
clause with no parent). Dot 0 of every other Seq is *denied* the span.
That denial is what kills the `|Seq| × n × cost` blowup of "everything
may eat garbage from the left", and it is why this is ~2× faster than
the closure while being strictly more accurate.

### 17.3 Theorem 2 (ε is a static table, and cost becomes edit distance)

"Clause C is missing" = "the shortest string C could have derived was
not written". Its cost is therefore `minLen(C)`, computed once by
fixpoint over the grammar:

    minLen(terminal) = its length      minLen(Seq)   = Σ over children
    minLen(A?) = minLen(A*) = 0        minLen(First) = min over alts
    minLen(A+) = minLen(A)             minLen(Ref)   = minLen(target)

This replaces the ad-hoc structural ε (1 for a terminal, 2 for a
composite) of §15/§16 -- and it is not a re-tuned heuristic. With
SPAN = "delete one input char" at cost 1 and FAB = "insert the shortest
witness" at cost `minLen`, the total is **exactly the indel edit
distance from the input to the nearest string in L(G)**, and the tree is
the parse of that nearest member. Substitution costs 2 = one delete +
one insert, as it should. The objective stopped being a weighting scheme
with tuned constants and became Levenshtein distance to the language.

### 17.4 The whole of recovery

    MATCH  (seq,s,d,p) + [sub_d : p..q]  ->  (seq,s,d+1,q)   cost +0
    SPAN   (seq,s,d,p)                   ->  (seq,s,d,p+1)   cost +1   d>=1
    FAB    (seq,s,d,p)                   ->  (seq,s,d+1,p)   cost +minLen(sub_d)
    GAP    rep chain [s..e)              ->  pending [s..e+1) cost +1

`First`, `Optional`, `Ref`, terminals and predicates are the **untouched
pure parser** -- they have no repair rules at all. Two guards carry
weight and were both found empirically before they were understood:

* SPAN is denied at dot 0 (Theorem 1), the goal wrapper excepted.
* FAB never fires on a **nullable** subclause: it already has a
  zero-cost empty derivation, so fabricating it would duplicate that
  derivation *and* forge an edit position, corrupting the locality
  weights. This was the direct cause of a 5-case regression.

### 17.5 Measured (same harnesses as §16, JSON, n=49, 519 mutants)

| | skip | frontier | eager chart | agenda | **dot** |
|---|---|---|---|---|---|
| sweep 519 | 426 (82.1%) | 466 (89.8%) | 469 (90.4%) | 469 (90.4%) | **477 (91.9%)** |
| ins / sub / del / swap | -- | -- | -- | 202/193/34/40 | **208/197/33/39** |
| avg ms | 2.8 | 10.5 | 115 | 11.5 | **5.7-6.3** |
| coverage failures | -- | -- | 0 | 0 | **0** |
| forced fallbacks | -- | -- | 0 | 0 | **0** |
| exact? | no | no | yes | yes | **yes (first-pop)** |

Against the agenda, dot wins 10 cases and loses 2 (`del@13`, `swap@13`);
every difference sits in the comma-separated array region, i.e. they are
**equal-cost witness ties**, not cost differences. The +8 is a tie-break
outcome on one corpus, not a theoretical gain -- stated plainly because
it would be easy to oversell.

All side batteries hold: micro cells, case-content, multi-error,
DEL/INS/SCRAM-4/16/64, LR, lookahead -- `covers=true` and
`forced=false` everywhere. `dart test` **308/308** (baseline 308/308).
Scaling on one error, n = 50→785: pops 6.3k→210k, 35ms→495ms, i.e.
about linear.

### 17.6 Ablation, and the four deletions it licensed

Selection-order ablation on the 519 sweep:

| weight key | sweep | avg ms |
|---|---|---|
| cost, diam, first-edit-latest, span, fab | 469 | 6.3 |
| drop fabSize | 467 | 6.5 |
| drop spanChars + fabSize | 467 | 6.5 |
| drop diameter | 457 | 8.4 |
| cost only | 385 | 15.0 |

So: diameter is worth +10 and a 25% speedup, first-edit-latest +72,
fabSize +2. Two further ablations showed both exact-tie **witness
re-point hacks** (`_stepRank`, `_altIndex`) to be **dead code** -- 469
with neither -- once `fabSize` existed. Deleted, and with them:

* the mutable backpointers they required (`tag`/`a`/`b` are now `final`),
* the goal **plateau drain**, which existed only to give re-points a
  chance to fire; the first goal pop is optimal by superiority, so the
  loop now simply `break`s,
* the `spanChars` weight component entirely.

Net −1734 bytes. Removing `spanChars` from *dominance* as well as from
the order is what moved 469 → 477: coarser dominance prunes more
aggressively, and the survivors happen to agree with the original tree
more often. Honest reading: a lucky tie-break, kept because it is
simultaneously simpler *and* better, not because it is justified.

Also fixed: `lastTotalCost` was stale after a clean parse (the fast path
returned without setting it), which made the scaling harness report
`cost=2` for a valid document.

### 17.7 Scored alternatives (the architecture question)

| solution | measured | score | reasoning |
|---|---|---|---|
| **Dot recovery: SPAN/FAB at Seq dots + rep gap** | 477/519, ~6ms, exact | **10** | Fewest mechanisms, best accuracy, ~2× the agenda's speed *in the low-cost regime that real editing produces*, and cost = a named quantity (edit distance) rather than tuned constants. Both theorems are proofs, not heuristics. Docked nothing for the deep-repair tail (§17.9) only because that regime is not what an editor hits; if batch repair of heavily-corrupted input mattered, the eager chart would win. |
| Desugar `A*` to `R <- A R / ε` so the Seq dot is the *only* site | not built | 8 | Would delete the GAP transition and the entire pending-state mechanism -- the last irregularity. Cost: repetition tree shape must be re-sugared for output, and PEG greedy semantics need care. The clear next step. |
| Full grammar closure, best-first (`agenda_recovery`) | 469/519, 11.5ms, exact | 7 | Correct and exact, but grants every clause a left-span it provably never needs. Superseded; keep until dot is adopted. |
| Eager chart (`semiring_recovery`) | 469/519, 115ms, exact | 6 | Too slow to ship, but it is the executable spec: an architecturally independent exact evaluator that cross-checks the others. Keep for that alone. |
| External repair search | 490/519, seconds | 5 | Highest shape-restoration, but seconds per document and a different (non-edit-distance) objective. Already committed; leave it. |
| Greedy first-match recovery mode (`skip_recovery`) | 426/519, 2.8ms | 4 | 2× faster, 51 cases worse, no optimality certificate. Defensible only if latency dominates correctness. |
| Frontier | 466/519, 10.5ms | 3 | Every one of its heuristics is now a weight, a queue order, or unnecessary. Retire. |
| Materially rewrite the grammar with span/ε nodes | never built | 2 | Blows up the grammar by 2|G| nodes, destroys the user-visible clause identity needed for error reporting, and buys nothing the transition function doesn't. |

One clear winner, so it was applied. Row 2 is the follow-on, not a rival.

### 17.9 The tail, measured properly (seeded), and one real fix

Same 137-char document, `shuffle(Random(seed))` so all three engines see
byte-identical input. **All three agree on cost at all 12 points** --
a fourth independent cross-verification of the objective.

| | dot | agenda | eager chart |
|---|---|---|---|
| SCRAM-8 (cost 2-4) | **0.1-0.7s** | 0.2-1.1s | 0.4-0.5s |
| SCRAM-16 (cost 5-6) | **1.5-2.8s** | 2.1-3.6s | 2.9-3.2s |
| SCRAM-32 (cost 8-9) | 6.1-7.4s | 6.8-8.4s | **2.3-10.0s** |
| SCRAM-64 (cost 14-15) | 21.3s | 14.9s | **6.9-7.9s** |

So the honest shape is a **double crossover**, not a ranking: dot is
fastest to about cost 9; the eager chart -- whose work is bounded by the
chart, not by the repair cost -- overtakes both best-first engines from
about cost 8; and by cost 14 dot falls behind the agenda too. Best-first
pays for breadth exactly when the answer is deep, which is textbook.

Pop counts locate the cause precisely, and it is not one thing:

| | dot pops / pushes | agenda pops / pushes |
|---|---|---|
| SCRAM-32 | 565k / 967k | 632k / 1202k |
| SCRAM-64 | 972k / 1855k | 830k / 1774k |

At moderate damage hoisting **removes** derivations (dot explores 11%
less). At extreme damage it **adds** them (dot explores 17% more):
denying the dot-0 span forces garbage up to an ancestor, and when damage
is dense that lengthens the derivation path to the same repair. Hoisting
is a redundancy win *and* a path-length loss; which dominates depends on
the damage density. This was not predicted by either theorem and is the
one place where the design is genuinely worse than what it supersedes.

**One real fix found and applied.** At SCRAM-32 dot had *fewer* pops
than the agenda yet ran *slower* -- so the gap there was per-item cost,
not search. `_addPartial` was scanning a bucket holding partials of
**all start positions** while dominance only ever applies within one
start. Splitting the scan index from the dominance class
(`bucket -> start -> Pareto set`; the completed-child step still scans
all starts, which is its legitimate use) cut SCRAM-32 from 9.65s to
7.05s (**-27%**) with **identical pop counts**, identical sweep
(477/519), and a byte-identical 42-case loss set. Push counts move by
~0.004% because grouping by start changes arrival order among
mutually-dominating values -- semantics unchanged.

Remaining work is the A* heuristic (pika-style right-side island index
as an admissible `h` on the queue key), which is the only thing that
addresses breadth-when-deep. Micro-optimization is done.

### 17.8 Honest caveats

* **At extreme damage dot LOSES, and the "2× faster" claim is
  regime-bound.** See §17.9: dot wins up to about cost 9 and loses from
  about cost 14, where the eager chart beats both best-first engines.
  The §16 measurement that put the agenda at 19.5s vs the chart at 9.4s
  was taken with an **unseeded `chars.shuffle()`**, so those numbers
  were never comparable across engines -- different random strings per
  engine. That was a methodology flaw in my own harness, not a result;
  §17.9 replaces it with seeded inputs.
* The +8 over the agenda is a witness tie-break on a single grammar and
  a single corpus. It should not be read as "dot is 1.5% more accurate"
  in general.
* Nothing here is committed.

### 17.10 Failure analysis: the two missing edit primitives (2026-07-24)

Baseline at the start of this analysis: **477/519 (91.9%)**, 42 losses.
Each loss was classified by comparing the recogniser's total cost against
the true Damerau-Levenshtein distance from the mutant back to the original
document (`d_diag.dart`):

* **TIE** (found cost == honest cost) -- both repairs are optimal under the
  objective, so the loss is a *witness-selection* problem, fixable only by
  the tie-break order.
* **CHEAPER** (found < honest) -- the cost model itself prefers the wrong
  tree. **No tie-break can ever fix this.**
* **WORSE** (found > honest) -- a search bug.

Result: **0 search bugs, 27 CHEAPER, 15 TIE.** Grouping the 27 CHEAPER gave
25 substitutions and 2 transpositions -- one structural root cause, not a
scatter of special cases.

**Why the CHEAPER group is unfixable by reweighting.** Under an indel-only
model, undoing a substitution costs 2 (one delete + one insert), so *any*
single-operation repair beats it. This is independent of how SPAN and FAB
are weighted: no assignment of positive weights makes a 2-op repair beat a
1-op one. The only remedy is a new primitive.

#### The third primitive: SUB

    SUB    terminal at p matches the WRONG input char   cost +1

This upgrades the objective from **indel distance** to **true Levenshtein
distance to the language** -- a strengthening of Theorem 2, not a heuristic.
It eliminated all 27 CHEAPER losses.

It also *reversed* an earlier tuning result: `first-edit-latest` was worth
+72 under indel-only, but became **harmful (-8)** once SUB existed. It had
been silently compensating for the missing primitive. Dropping it is both
more accurate and faster, so the tie-break got shorter, not longer.

#### The remaining ties: class width (MDL)

With SUB in place the residual losses were **all** ties, and all one shape:
a repair that lets `String <- '"' Character* '"'` swallow a structural `,`
or `:`, because `Character <- [^"\\] / ...` matches a comma as happily as
the literal `','` in `Array` does. Cost, diameter and fabSize are all
*identical* between the honest and the wrong tree, so the winner was
arbitrary heap order.

The discriminator is **description length**. Charge each matched input
character `log2(|character class|)` millibits:

    literal ',' (size 1)      ->      0 bits
    [0-9]       (size 10)     ->  3,322 millibits
    [^"\\]      (size 65534)  -> 16,000 millibits

Taking the parse tree as the model, this is exactly the residual needed to
specify the input -- the MDL / maximum-likelihood term. It has **no tuned
constants**: the numbers come from the grammar's own character classes.

#### Measured (JSON, 519 mutants, same harness for all three rows)

| `bitsMode` | Accuracy | Sweep avg | SCRAM-64 tail |
| --- | --- | --- | --- |
| 0 -- off                       | 492/519 (94.8%) |  9.23 ms |   7,386 ms |
| 1 -- exact (bits also in `_dom`) | **508/519 (97.9%)** | 16.58 ms | **234,144 ms** |
| 2 -- heuristic (bits in `_cmp` only) | 504/519 (97.1%) | 14.00 ms | 7,280 ms |

Mode 1 is *exact*: bits is a fifth Pareto axis, so the lightest-bits witness
is guaranteed found. But a near-continuous component weakens dominance
badly, and the high-cost tail explodes **31.7x** (7.4s -> 234s on the same
SCRAM-64 input, measured by flipping only this flag).

Mode 2 keeps bits in the comparator but drops it from the dominance test.
Dominance still requires `cost <=`, so **the result is still a
minimum-cost repair and the edit-distance theorem is untouched**; only the
MDL preference degrades to best-effort, since a lighter-bits witness can be
pruned by a dominating heavier-bits one. It captures 12 of the 16 available
cases at **zero tail cost**. This is the recommended setting.

Tie-break order was swept over 18 candidates; the winner is
`(cost, diameter, fabSize, bits)` -- bits *last*, which is both the most
accurate and the cheapest of the class-width orders, because the cheap
components resolve most comparisons before the expensive one is consulted.

#### Remaining losses and known gaps

* 11 losses remain at mode 1, all ties; the families are quote
  re-bracketing plus `del@13(2)`, `swap@13`.
* **No transposition primitive.** `swap@N` cases cost 2 (delete+insert)
  rather than 1. Adding Damerau transposition would fix ~2 cases in 519 --
  judged not worth a third transition in a design whose entire claim is
  "two transitions at a Seq dot".
* **Reporting flaw introduced by SUB.** A substituted character and a
  deleted character both surface as an identical 1-char `SyntaxError`
  (`dot_recovery.dart`, `case _tSub`), so a caller cannot distinguish
  "this character is extra" from "this character is wrong". Fixing this
  needs a distinct span kind in `SkipResult`.
* Some remaining "losses" are defensible repairs where the benchmark's
  ground truth (restore the *original* tree) is arguably not the better
  answer -- e.g. `del@13(2)` on `[,33,true]`, where deleting the stray
  comma is a perfectly reasonable repair.

#### Verification status

* `dart test`: **308/308**, unchanged from baseline. But **nothing in
  `test/` or `lib/` references `DotRecovery`** -- the gate confirms no
  regression elsewhere and provides *zero* coverage of this file. The
  `490/519` line printed by `json_mutation_test.dart` comes from
  `RepairSearch`, a different engine, and is unrelated to these numbers.
* All evidence above is from standalone scratchpad harnesses.
* Coverage invariant (`covers=true`, `forced=false`) holds on every case of
  the validate battery, and a valid document still yields 0 events.
* `tieMode` / `bitsMode` remain in the file as documented measurement
  scaffolding; they should be collapsed to the winning constants before any
  commit.
