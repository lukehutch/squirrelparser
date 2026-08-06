# PEG Error Recovery — the living record (era 3)

Sixty-odd engines were built, measured, and mostly archived to reach the ten
that remain. This file records the yardstick, the standing results, the laws
that survived measurement, and the refutations that must not be retried. The
full era-1/era-2 history — every engine account, every intermediate insight
I1–I107 in long form — is preserved verbatim in
`dart/experiments/recovery/attic/OLD_LESSONS_LEARNED.md`; its numbers were
measured on the old battery and are not comparable to the table below.

## 1. The problem and the yardstick

An engine receives a grammar and a damaged document and must return the best
complete reading: a tree over the real input, with `SyntaxError` nodes
marking exactly what was denied (real text judged noise) or owed (text
judged missing). Directives: no second parse over a repaired string (D1); no
arbitrary constants (D2); never invent characters of an open class,
structural completion is fine (D7); the two acceptance readings of D8.

**The battery** (`astdiff.dart`): every single-character mutation of every
corpus document that breaks the parse, plus truncations and two-site damage,
across three grammars — json, a statement language (blocks/if/assign), and
left-recursive arithmetic. Expectations come from the frozen parser reading
the undamaged original, so no engine can be tuned toward them. Scoring is
Levenshtein distance over named-node skeletons.

**Era-3 curation (I107)** — the battery tests only what a human could
arguably expect:
- **Operator mutations are not generated.** Deleting or replacing a binary
  operator (`3(4-5)`, `2;3`) admits both restorations at the same edit
  distance; the original is unrecoverable and a test would score tie-luck.
- **One- and two-character truncation stubs are not generated.** `i` or `{"`
  carries no decidable evidence; a human could not read it either.
- **Truncation expectations drop left-recursion wrappers the cut removed.**
  The old rule kept any node *starting* before the cut, so `a+b*2-(` was
  expected to know about the `*4` nobody can see. A wrapper whose first
  named child is the same rule and whose own evidence lies wholly beyond
  the cut is not expected.

**Five categories, named by the operation** a person performed, weighted by
coverage (weights are how many cases a category contributes, never a
multiplier): truncation 3.0, deletion 3.0, insertion 2.5, substitution 2.0,
misc (transpositions, multi-site) 1.5.

**The gates** (all must pass; the battery cannot see these):
- `_accept` — D8's readings: cx2, b1, b2.
- `_freespan` — may a repair delete real input that already matched? (The
  battery is blind to this by construction; it once rewarded +0.0020 for
  exactly that.)
- `_recommit` — does the engine keep a committed construct rather than
  re-reading the healthy prefix as something else?
- `_conf1` — exact repair-cost conformance on six probes, no free passes.

## 2. The standing table (2026-08-06, one machine, one sweep)

| Engine | Score | Perfect% | ms | LOC | Gates | truncation | deletion | insertion | substitution | misc |
|---|---|---|---|---|---|---|---|---|---|---|
| **c4** | **0.9878** | **83.9** | 1687 | 566 | all | **0.997** | **0.984** | 0.993 | **0.987** | **0.967** |
| c3 | 0.9829 | 81.2 | 1713 | 515 | all | 0.985 | 0.979 | 0.994 | 0.987 | 0.964 |
| s1 | 0.9825 | 75.2 | 1773 | 697 | all | 0.987 | 0.980 | 0.994 | 0.981 | 0.963 |
| c1 | 0.9818 | 78.6 | 1785 | 493 | all | 0.982 | 0.979 | 0.994 | 0.985 | 0.962 |
| s4 | 0.9818 | 78.6 | 2068 | 480 | all | 0.982 | 0.979 | 0.994 | 0.985 | 0.962 |
| c2 | 0.9812 | 78.5 | 2354 | 454 | all | 0.981 | 0.979 | 0.994 | 0.985 | 0.961 |
| r9 | 0.9704 | 72.9 | 2552 | 562 | all | 0.959 | 0.973 | 0.988 | 0.972 | 0.955 |
| m143 | 0.9658 | 70.5 | 1669 | 628 | recommit 15/16 | 0.932 | 0.978 | 0.988 | 0.981 | 0.953 |
| m132 | 0.9600 | 65.8 | 1597 | 612 | recommit 15/16 | 0.908 | 0.978 | 0.988 | 0.981 | 0.953 |
| t1 | 0.9287 | 55.9 | 1170 | 899 | all | 0.946 | 0.946 | 0.976 | 0.870 | 0.860 |

Frontier (score/perfect/ms/LOC): c4 leads outright; c3–c2 form the size
ladder; t1 keeps raw latency; m143/m132 sit between. **s1 and r9 are
dominated** — on the fair battery, s1's remaining era-2 edge over the
c-line dissolves (it was tie-luck on coin flips and over-demanding
truncation expectations), and c3 beats it on every axis.

## 3. The lines, and what each one taught

**dot / m-line (m1–m145, archived; m132, m143 kept).** Budgeted
iterative-deepening repair over the memo table. Taught: the budget is the
HORIZON — deleting it is ~100x latency (A3, re-proven in the c-line); the
worklist over cells; per-position generation stamps; and dozens of scoring
laws. Its ceiling: repairs judged per-round without whole-document rivalry,
and truncation (0.91–0.93) — it cannot afford deep completion spines.
m143 still fails `_recommit` on the escape-conjure swallow.

**r-line (r1–r13, archived; r9 kept).** The chart engine: whole-document
rival readings priced simultaneously. Taught: judgment must be
simultaneous (greedy per-commit repair provably cannot order a cheap fill
against a dear denial — its correct choice depends on repairs not yet
made); the give-up exclusion; the swallow toll. Its ceiling: the chart
re-derives per round what the parse already computed once.

**t/b-lines (archived; t1 kept).** t1: recovery walking the enriched
mismatch tree, memo as repair channel — the latency record (1,170 ms) and
proof the tree's sideways signal is sound; but the tree holds each
committed reading's FIRST failure, while recovery's information is every
REJECTED reading (I98). b1/b2: the explicit two-mode architecture (parse
until stuck, breadth-first widening, commit, resume) — proved classes can
decide D8 with no pricing at all, and hit the greedy-commit wall at 0.88.

**s-line (s1–s4; s1, s4 kept).** The way-algebra: one costed descent, every
clause returns rival priced readings, a budget ladder, a six-part global
judgment. s1 = the explicit four-mechanism form (I94–I97); s3/s4 = the
collapse (fills emerge from the descent; a literal is a sequence; a move is
a resync at slot 0) at 480 lines. The c-line is this algebra rebuilt on
better substrate.

**c-line (c1–c4, all kept).** c1 (I101): parsing mode IS budget zero — with
no edits left the descent is definitionally the pure parser, so the frozen
memo answers unconditionally; the budget itself marks where repair can no
longer reach. c2 (I102): the four-form normalization (X* is left recursion,
X? is choice, a literal is a char-sequence, EOI is a slot) — the smallest
engine, and the proof that grammar rewriting costs accuracy and foreign
trees. c3 (I103): the way-front — insertion IS the improvement test; the
sort and its livelock class deleted. c4 (I104–I107): the completed rank and
the fee's scope, current best on every accuracy axis.

## 4. The laws (what survived every measurement)

1. **The LR loop is the recovery loop** (I100, the pivotal insight of the
   project): a mismatch and an LR seed are the same object — a suspended
   reading addressed by (clause, pos); the memo entry's grow-loop serves
   left recursion and repair with no second mechanism; left recursion is
   recovery at cost zero.
2. **Parsing mode is budget zero** (I101): the frozen memo's answer is
   exactly equivalent wherever edits are spent — except at end of input,
   where owes must still be offered, because…
3. **The eof edit is the root's one claim, not local spend** (I94
   completed): "the document stopped" charges once however many slots it
   strands; it must not block a fold, fail an afford filter, or freeze a
   cell. Eof-ways exist only at EOI, so the exclusion needs no conditions.
4. **The rank is six keys, each placed by a failing case** (I105): fewest
   edits+toll; PEG's own reading; most explained (net); latest doubt (key);
   most vouched; fewest marks. Vouch entered when instrumentation showed
   every materially different rank-tie was the same reading carrying more
   certified absorption; marks entered when the collapsed eof claim let a
   five-mark spine tie a two-mark one.
5. **The tie law**: the latest same-price rival holds the bucket —
   deterministic, since expansion order is; measured four ways
   (first-keeps −2.6 to −3.1 perfect). A tie never signals improvement, or
   rank-equal rivals spin forever.
6. **A span is judged once** (I97): absorption pays its toll at the
   construct that saw it; `vouch` records what was already judged (a free
   span vouches itself, span − net), and a frozen span vouches exactly
   what its enumerated form would have — asymmetry here hands the
   escape-conjure swallow whole families.
7. **The fee and its scope** (I72∩I36 + I106): an unspellable fill pays one
   where a denial no dearer offered to read — but a slot that is a
   back-edge into a growing cell is an LR SEED, exempt: its give-up
   anchors the spine the growth exists to build. The fee lives in the
   price; ranking it below net breaks the acceptance gate.
8. **Warth's involved-set is the staleness rule** (I103): only rules that
   read a growing seed, at that position, during that growth, are ever
   recomputed. The per-position version bump cold-starts whole positions
   and cannot survive growth being ubiquitous.
9. **The literal is a sequence, and its third op is replace** (I95): match,
   owe, and deny-one-then-owe inside a literal; the replace edit is
   literal-scoped — universalizing it fixed nothing and doubled latency.
10. **Names are evidence** (I81/I96): a zero-width completion at end of
    input loses its name (the construct was never reached); mid-document
    it keeps it. The grammar-forced spine is emitted only where a unique
    arm is cheapest.
11. **The seed is read raw, and re-entry IS left recursion** (I103's
    porting truths): a budget filter at the seed hides the repair-carrying
    ways growth must build on; any in-path hit sets foundLR — gating it on
    a null container silently turns growth off.
12. **Laziness is load-bearing** (I88, confirmed three times): building
    trees eagerly per candidate costs 20–31% latency at the tie-refresh
    volume the tie law requires. The way encodes its tree as a chain;
    only winners are materialized.
13. **The size floor is a measurement** (I104): at c4's accuracy every
    remaining subsystem is pinned by a gate or a battery family; nine
    collapse attempts each broke a bar by a recorded number. The seam
    below is c2's 454 lines at −0.0008 (era-2).
14. **The yardstick is a design object** (I107): a battery that scores
    coin flips or post-cut structure measures tie-luck; curate mutations
    to what a human could arguably expect, and put expectation-changes in
    the open, never silently.

## 5. What separates the top engines

All of s1/s4/c1–c4 share the same judgment core. The deltas:

- **c4 vs c3**: the six-key rank (vouch, marks), the fee's seed exemption,
  the literal replace edit, eof-not-spend. Worth +0.0049 score and +2.7
  perfect on the fair battery — every piece traced to a named family.
- **c3 vs c1**: the way-front (champion-per-ending; insertion is the
  improvement test) and Warth's involved-set replacing version stamps.
  Equal score at era-2; c3 ahead on the fair battery (better convergence).
- **c1 vs s4**: identical judgment, near-identical results; c1 adds the
  budget-zero collapse (17% faster at era-2) and the fill-cache. s4 is the
  smallest s-form; c1 the faster restatement.
- **c2**: the same algebra after grammar normalization — 454 lines, the
  size point; pays a small accuracy and latency premium and its trees
  follow the normalized grammar, not the author's.
- **s1**: the explicit-mechanism reference (alignment table, spine
  emitter, owed-slot machinery as separate code). On the fair battery it
  holds nothing the c-line lacks; its era-2 edge was tie-luck plus
  over-demanding truncation expectations.
- **m143/m132**: the budgeted-deepening reference points — fast, sturdy,
  and structurally unable to afford deep completion spines (truncation
  0.91–0.93); both fail `_recommit` by one case (the escape-conjure).
- **t1**: the latency record and the proof of the mismatch-tree channel;
  concedes ~0.06 score.

## 6. The refutation ledger (do not retry without new evidence)

| Claim | Verdict |
|---|---|
| Delete the budget; compute cells once | ~100x latency; the budget is the horizon (A3, twice) |
| Grammar rewriting as the engine's foundation | −0.0008, foreign trees, and the library's LR does the same work (c2) |
| Repetition through its own memo cell | 2,440 vs 1,535 ms, no accuracy change (twice) |
| Greedy commit-one-then-reparse as judgment | the b-line's 0.88 ceiling: the correct choice depends on repairs not yet made |
| Eager trees / ways as materialized trees | +20–31% latency at the tie-refresh volume (I88 ×3) |
| Ties keep incumbents / PEG-first ties | −2.6 to −3.1 perfect; latest-wins stands (×4) |
| The fee ranked below net | breaks the acceptance gate: the b2 fill out-nets its denial and must still lose |
| Universal replace edit (all slots) | zero residual cases fixed, two regressions, 2x latency |
| Vouch 0 for anonymous frozen spans | tolls the honest reading, shields the swallow: −25 quote-delete cases |
| Per-position version bump with ubiquitous growth | battery timeout; Warth's involved-set is the rule |
| Root simplification (drop owed-admission) | recommit fails: the incoherent honest reading must displace the coherent swallow |
| Prefix-freeze with conditions (non-LR, window, clean) | its consult cost its savings; budget-zero alone is faster |
| Merging `_determined` and `_minFill` | memoizing under a cycle-cut poisons minFill inside LR paths |
| Net crediting bare `Match(null)` spans | re-weights every completion's matched prefix; −3 recommit cases |

## 7. Where things live

- Engines: `dart/experiments/recovery/{c1..c4,s1,s4,r9,m132,m143,t1}.dart`
- Battery + scoring: `astdiff.dart`; runner: `_score1.dart <engine> [dump]`
- Gates: `_accept.dart <engine>`, `_freespan.dart`, `_recommit.dart`,
  `_conf1.dart`
- Frontier: `pareto.py`; size: `loc.py`
- Archive: `attic/` (≈290 files), era-2 record in
  `attic/OLD_LESSONS_LEARNED.md`
