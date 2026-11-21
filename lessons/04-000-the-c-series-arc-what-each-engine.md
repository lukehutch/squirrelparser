<!-- Part of LESSONS_LEARNED.md, section: 4. The c-series arc — what each engine taught -->
[Back to the index](../LESSONS_LEARNED.md)

## 4. The c-series arc — what each engine taught

- **c1** (I101): the budget-zero collapse. The two-mode split (parse vs
  repair) is not a feature of the problem, only of earlier designs — the
  pure parser is the zero fiber of the costed descent. 0.9818, 493 lines.
- **c2** (I102): the four-form normalization (X* is left recursion, X? is
  choice, a literal is a char-sequence, EOI is a slot) — the smallest
  engine ever above 0.98 (454 lines) and the proof that grammar rewriting
  as a FOUNDATION costs accuracy and produces trees foreign to the
  author's grammar. The behavioral laws survive; the rewriting does not.
- **c3** (I103): the way-front as the memo cell; Warth's involved-set;
  the sort and its livelock class deleted. Porting truths: the seed is
  read raw; gating foundLR on a null container silently turns growth off.
- **c4** (I104–I107): the completed rank — every key traced to a family;
  the fee's seed exemption; the literal replace edit; eof-is-not-spend.
  The residual then classified: mostly yardstick, not engine (→ era-3
  curation). Proved the size floor is a measurement: nine collapses below
  ~511 lines each broke a recorded bar.
- **c5** (I108): the swallow derived, never stored — toll, vouch, judge,
  and the vouch-symmetry bug class deleted; judgment bit-identical.
- **c6** (I109–I111, then the fusion): the way as a cons cell that knows
  its sums (fifteen fields → ten); the root protocol and audit walk
  deleted; the pentad audit — admission is the rank's own price, tier 5
  is the stranded count alone, and the five counters are proven the
  floor (0.9879 / 84.0 / ~1490 ms / 461 lines). Then the whole squirrel
  parser folded in: an engine-owned node hierarchy with behavior as
  methods and memo state as stamped arrays on the nodes —
  judgment-identical and −20% latency, 707 lines all told.
- **c7** (I112): one left-recursion law for both fibers — re-entry
  seeds, growth bumps the position's version, and the involved set is a
  single boolean recorded by the unwind; Warth's stack, heads map, tick
  and sets delete. Judgment-identical, 0.9879 / 84.0 / ~1112 ms / 692
  lines, every gate exact — the first engine to hold the accuracy AND
  latency records at once.
- **c8** (I113): the adversarial audit, and one frozen-answer protocol.
  Every assumption re-questioned; most held with sharper reasons (the
  clean-cell rivals are load-bearing — b1's winner SPLITS a purely
  matching "33"; the pure fiber stays dual code; the ladder stays).
  What changed: freeze(pos) is the single frozen-answer protocol at
  every node kind (go = freeze-or-repair; grow's budget zero calls it;
  a terminal's pin bit is the leaf case of the net walk), and the rule
  cell owns its frozen way, built once. Judgment-identical, every gate
  exact — the standing engine. The audit's two new refutations are in
  the ledger; the design is visibly at a fixed point (c5→c6 cut 73
  lines, c6→c7 one law, c7→c8 one protocol). c8 was then renamed and
  re-documented end to end for readers without this file's history —
  every invented term replaced (section 8), every mechanism explained in
  plain language in the source, judgment re-verified identical — and
  finished with the strict zero fiber: budget-zero queries always get
  exactly the plain parser's cached answer, making the zero fiber
  order-independent and ~5% faster. 0.9879 / 84.0 / ~1126 ms / 759
  lines, every gate exact, analyzer-clean.
- **c9** (I115–I116): the same algorithm on the data its measured shape
  asks for — 1.7x faster (paired ratio 0.587), judgment bit-identical
  (zero-diff dump), every gate exact. The round began by measuring the
  SHAPE of the hot structures over the whole battery: 71% of cell
  consults see at most one reading (90% at most three, max 52); 80% of
  fold steps hold one partial; and every champion-map insert used the
  stored reading's own `end` as its key. Three changes follow from
  those numbers and account for the whole win: the champion map becomes
  a plain list scanned by `end` (the key was the value's own field);
  a cell's filtered view is cached between changes, and its object
  identity — which now changes exactly when content may — lets a rule
  reference cache its labeled wrapping and revalidate by `identical`;
  and naming moves from per-fill to per-change, applied as the view is
  built (with the packaged plain answers — zero-budget reading, its
  list, a reference's tree wrapper — each built at most once). Two
  "obvious" moves measured backwards and were reverted: judging a
  candidate before allocating it (1.02–1.04x) and reusing cell arrays
  across runs via epoch stamps (1.10x) — Dart's generational GC makes
  young allocation nearly free and charges a write barrier for
  old-space stores, so the fresh-arrays-per-run design c6 chose is not
  a shortcut but the optimum. The per-op campaign around these
  (indexed loops, fold micro-shapes, terminal tweaks) measured ±5%
  with unstable sign: on this engine the representation, not the
  operations, was the lever.
- **c10** (I117–I118): one machine at every budget. The dedicated
  plain parser c9 still carried for the zero fiber is deleted; a
  budget-zero consult runs the SAME costed descent with nothing to
  spend. Three laws make the collapse exact to the tree and the label:
  WITH NO BUDGET LEFT, REPAIR IS PARSING (the zero fiber's one
  PREFERRED reading — greedy demotion strips "the parser's own choice"
  from every reading the greedy parser would not produce — IS the
  plain answer); EACH FIBER OWNS ITS STORE AND ITS CLOCK (budget-zero
  fills the cell's twin, each fiber grows left recursion on its own
  version clock, and ties follow the fiber: the costed search keeps
  the newcomer, the zero fiber keeps the incumbent, because a fixed
  point discards an equal re-derivation); SHARING FOLLOWS THE VIEW
  (every packaged answer is cached by the identity of the view it was
  built over, so the first asker builds it and every later asker
  shares the same object — label sharing is observable, so this is
  correctness, not tuning). Bit-identical trees (zero-diff dump plus a
  node-by-node oracle over all 2101 cases), every gate exact,
  890 → 790 lines (−11%) at a measured ~1.09x paired latency — c9
  keeps the latency point. I118 is the boundary of I116's ledger,
  found by compressing past the knee and bisecting back: routing the
  two per-candidate hot paths (the slot walk, the store's view build)
  through the shared judge — an intermediate list per store, a judging
  cell with its cache bookkeeping per offer — measured 1.18x slower
  end to end (paired ratio 1.30 → 1.57), so those two sites inline
  the rules the helpers state. Young allocation is nearly free; a
  per-offer allocation plus invalidation writes in the innermost loop
  is not just allocation.
- **c10, second pass** (I119): the plain parse is a FACE of each
  construct, not a mode of the search. c10's first cut ran the zero
  fiber through the costed machinery's full shape — a memo cell per
  composite, a list of candidates per consult, a tree translation per
  serve — and measured 1.30x against c9. Instrumented attribution
  (stopwatch around every zero-fiber entry) put essentially the WHOLE
  gap in that fiber: the costed rounds were already at parity. The fix
  is a fiber split inside each construct: `proposePlain` is the
  classic PEG parse — one preferred reading, its finished tree built
  as it returns (`_node`), children consulted through the
  single-reading `plainReading`, no lists between stores — and
  `proposeReadings` is the costed candidate generation; `_grow` fills
  the same cells with whichever face the fiber calls for, and inside a
  twin fill inline composites skip cells entirely, so the zero fiber
  memoizes only at rule boundaries, exactly the plain parser's own
  shape. Readings-with-trees stay sound because in the zero fiber
  every consult is served at most one preferred reading, so every
  chain is deterministic and demotion has already discarded whatever
  the greedy parser would not produce. Bit-identical at every step
  (four gate-verified stages: lean proposals 1.30 → 1.20, cell bypass
  → ~1.17, eager trees → ~1.13, single-reading consults → ~1.09);
  the residual ~9% is the dispatch tax of one machine choosing its
  fiber per consult, below this VM's run-to-run noise. 714 → 790
  lines: the second face costs 76 lines and buys back most of the
  deleted parser's speed.
- **c10, third pass** (I120): the state a variable holds is only real
  if some read distinguishes it. A reachability audit of the engine's
  state cross-product found two collapses and confirmed the rest is
  load-bearing. Landed: `_round` deleted (written everywhere, read
  only to copy into `_budget` — the ladder now loops on `_budget`
  itself), and the per-fiber version clocks merged into ONE
  (bit-identical, gates, ratio 1.073: a cross-fiber bump can only
  force a refill that re-derives the same content, because the plain
  parse is deterministic and a zero cell keeps its incumbent on ties —
  so the stores must be disjoint but the clock need not be). Refuted
  by the oracle: one-sided zeroWraps (769/2101 differ — `_r10`
  compares tree labels by POINTER, so which RuleRef built a shared
  wrap is observable; the dump text stayed identical, meaning the
  two-sidedness exists solely to reproduce c9's first-asker choices).
  That same mechanism analytically refutes deleting the wrap caches,
  un-sharing refView, and merging `_probing` into `_zeroFill` (both
  would shift wrap sides/pointers). 790 → 785 lines.
- **c11** (the code-space study, `c11_study.md`): the pure parser re-run
  under directive sets — uniform-cost search over restarts, no chart,
  the library untouched. It scores 0.9874 / 84.7 with all four gates:
  −0.0005 on score, **+0.7 on coverage** against the c9/c10 plateau,
  which is why it is in the record at all. One structural zero remains
  (i=168, same-cell left recursion — the repair consults (Value,0) while
  that cell is in progress; only a chart serves it). Its veto
  (challenge) directive is free in charge but pays one unit of QUEUE
  ORDER — free in both is a random walk, priced in both loses ties the
  evidence key should decide — with sites read off the returned tree and
  `run.discarded` only where an enclosing match ends at the failure
  frontier, cuts of one repetition never composing, no two consecutive
  vetoes (which bounds vetoes at edits+1 and keeps the charge bands
  finite), and rings admitted in bulk because per-level draining starves
  the far family. Its search needs TWO clocks over one frontier, found
  only after three full batteries: queue-cost bands with the furthest
  parent frontier first before a candidate exists (greedy, so capped
  multi-error searches complete something), charge bands FIFO within
  after one does (the only starvation-free rival hunt — both frontier
  extremes livelocked, 18 regressions near-end and 22 far-end). The
  verdict is the closing sentence of the study: **a restart engine
  re-derives what a chart holds.** Its battery takes ~1,926 seconds
  against c9's 0.6, all of it in a ~30-case cap-out tail. c11 is kept
  as a study and as the source of c12's architecture, not as a
  candidate.
- **c12** (I121, the standing engine): the best of c9, c10 and c11 in
  one file. From c11 it takes the architecture — the published library
  untouched, a separate recovery module consuming library clauses
  natively, so no `_convert.dart` adapter exists for it. From c10 it
  takes the one-machine design and the state-space discipline. From c9
  it takes the measured containers of I115 and the caches that make the
  clean path fast. It is the first engine to break the c6–c10 judgment
  plateau: **0.9896 / 85.8**, substitution 0.988 → 0.997 and misc
  0.968 → 0.969, all four gates exact, 784 lines, and on the paired
  clock at or below c9 on both clean and damaged input. The judgment
  gain is the substitution repair (a wrong character consumed as an
  error span for an exact-text slot); the latency was won back by
  gating where that repair is offered (lessons 22 and 23 above), which
  cost ten lines for the `_resumes` helper against five recovered by
  condensation. Note what the score does NOT say: c12's trees are no
  longer bit-identical to c9's — that invariant ended here, deliberately,
  because c9's substitution reading was the thing being improved on.
- **c13** (the standing engine): c12 plus one rule — the noise-vs-absence
  penalty (a demonstrated deletion nearby prices the "something was
  missing" reading) is EXEMPT at a sequence's LAST slot. The reason is
  jurisdiction: at the last slot, the question of what stood there belongs
  to the enclosing context — the parent's next slot may want exactly the
  character the deletion would consume — and the fold cannot see that far,
  so pricing the absence locally is a guess charged as knowledge. Net
  +0.511 pts over 14 battery cases (10 fixed, 4 broken): 0.9899 / 85.8,
  all four gates, clean path bit-identical, damaged 1.010 vs c12, 786
  lines (+2). The same window attacked the OTHER half of the residual —
  the json string-swallow family (mechanism A) — seven ways and refuted
  the whole line (see the ledger): the swallow signal is not reliably
  computable from reading totals at proposal time, and every detection
  policy fired on the engine's own legitimate accounts.
- **c14** (the standing engine, 2026-09-02): c13's judgment on a bounded
  machine. The round set out to find a revolutionary engine and
  scored its candidates first (per-region rungs, key reorderings, an
  evidence memo on rule wrappers, the library's own memo as the plain
  fiber, and the two changes kept; the ledger records each result). Every
  candidate that touched the judgment scored below c13 — the seven-key
  comparison and the single global frontier are, by the ledger's count,
  at a strict local optimum of this yardstick (§6c's perfect-oracle
  bound of +0.0012 is the headroom that remains and none of it is
  reachable by an ordering change). What the round found instead was a
  bound the battery could not see: the repetition sweep was asking
  each step at the round's whole budget (lesson 24). c14 =
  c13 + that four-line handoff + `_Front` (lesson 26). Battery
  `0.9899 / 85.8`, dump diff against c13 empty, `_accept` ok cx2=1 b1=1
  b2=1, `_freespan` PASS, `_recommit` 16/16, `_conf1` `0 1 1 0 2 3`;
  807 lines (+21); damaged 0.73x c13 paired. Scaling on generated json
  (`_scale14.dart`, `members/errors`, min of two warm runs, ms):

  | chars / errors | c13 | c14 |
  |---|---|---|
  | 354 / 1 (the edit landed harmlessly: cost 0, a clean parse) | 0.47 ms | 0.48 ms |
  | 717 / 1 | 111 ms | 4.9 ms |
  | 1,445 / 1 (two runs) | 1,142 ms; 1,388 ms | 6.9 ms; 7.7 ms |
  | 2,927 / 1 | 16,238 ms | 10.6 ms |
  | 5,962 / 1 | > 300 s (timed out) | 3.6 ms |
  | 24,193 / 1 | > 300 s | 415 ms |
  | 100,075 / 1 | not attempted | 2,497 ms |
  | 1,444 / 2 | 6,306 ms | 21 ms |
  | 5,961 / 2 | > 300 s | 53 ms |
  | 24,192 / 2 | not attempted | 3,326 ms |
  | 100,074 / 2 | not attempted | 2,905 ms |
  | 1,442 / 4 | 112,763 ms | 176 ms |
  | 5,959 / 4 | > 300 s | 728 ms |
  | 24,190 / 4 | not attempted | 28,497 ms |
  | 1,438 / 8 | > 300 s | 3,890 ms |

  Each row is one process per engine pair (`timeout 300`), one warm-up
  call and then the mean over up to 20 calls or one second; "> 300 s"
  means the process was killed before the warm-up call and one timed
  call finished. c13's curve between 717 and 2,927 characters is a
  factor of 10–12 per doubling of length (about n^3.5); the committed
  c13 had no bound on the sweep at all, so the `_c13b` variant timed
  during the round (a step cap, 990 ms at 24k/1) was already far ahead
  of it and is not what the c13 column shows. c14's time tracks the
  error position rather than the length (lesson 27): 5,962/1 is
  cheaper than 1,445/1 because its edit fell earlier in the document.

  and the ablation on top of the budget handoff (four variants
  interleaved, `_scale3.dart`, min of 2):

  | doc | handoff only | + index | + evidence memo | + both |
  |---|---|---|---|---|
  | 100,075 chars / 1 error | 5,031 | 2,269 | 5,129 | 2,012 |
  | 24,192 / 2 | 5,894 | 3,279 | 5,342 | 2,545 |
  | 24,190 / 4 | 92,700 | 25,100 | 87,200 | 26,900 |
  | 5,959 / 4 | 1,032 | 823 | 879 | 951 |

  The evidence memo (a lazy per-wrapper `evidence` field on a `_Node`
  subclass of the library's `Match`) reads within noise of the handoff
  alone in every row and was dropped; its clean-path cost was 1.0–1.09x
  in the wrapper-only form and 1.1–1.3x when every node carried it.
  What c14 does NOT change: no key, no price, no offer site, no gate.

- **c15** (scratch `_c15.dart`, 2026-09-03; not the standing engine):
  c14's judgment on a level-by-level frontier machine — a
  graph-structured stack of frames with a beam of W origins per
  (position, frame shape). Battery equal to c14 to four digits
  (0.9899 / 85.8, 298 imperfect, all gates), 1,018 lines (+211, +26%),
  3.75x slower on the battery's short inputs, linear in the input at
  fixed budget where c14 is ~n^2.6 (24k chars / 4 errors: 10.3 s vs
  26.2 s; 150k: 38 s where c14 would take tens of minutes), ~74 KB per
  character of memory. Lessons 28–32. Why it is not promoted: the
  latency goal is the battery's (short inputs, where it loses 3.75x)
  and its memory ceiling is ~600k characters at four errors; promotion
  is a call on which workload matters, recorded here for the user.
- **c16** (scratch `_c16.dart`, 2026-09-04; not the standing engine):
  c14 with c15's beam of W=8 origins moved into c14's own cells (an
  admission test at the repetition sweep and at every sequence slot,
  keyed by (state, end), judged on the whole-document bill from seven
  scalars) plus memoized plain matches (a suffix-shared chain per
  repetition position, a cached composite match per cell) and an O(1)
  sweep dedup. Battery bit-identical to c14 at every step (0.9899 /
  85.8, 298 imperfect, 0 diff lines, all gates), 1,015 lines (+208,
  +25.8%), 1.38x c14 on the battery's short inputs (683–701 vs 500
  ms), bounded linear at fixed budget: 24k/4 8.8 s vs c14 26.2 s,
  100k/4 12.9 s vs 70.0 s, 150k/4 15.5 s; peak RSS 1.7 GB at 24k and
  3.3–7.5 GB at 100k where c14 takes 4.9 and 13.4 GB. Lessons 33–38.
  Why it is not promoted: the same workload call as c15 (short inputs
  pay 1.38x) and the memory per character is still tens of KB; the
  user decides.
- **c17** (scratch `_c17.dart`, 2026-09-04; not the standing engine):
  c16 with repairs allowed only inside windows opened over the round's
  farthest death, each window walked two evidenced units back per frame,
  and the same budget re-run after every window. 0.9900 / 86.0 (11
  equal-cost tie-break deviations from c14), all gates (recommit 16/16
  once its driver resolved c17, lesson 55), 1,330 lines (+315, +31%
  over c16), 2.3x c14 on the battery; 24k 0.6–1.1 s / 0.4 GB, 100k
  2.3–3.1 s / 0.9 GB, 200k 5.4 s / 1.5 GB. Lessons 39–43. Superseded
  as the scratch candidate by c18.
- **c18** (scratch `_c18.dart`, Codex 2026-09-05, rebuilt with c17's
  documentation 2026-09-06; the scratch candidate, not the standing
  engine): c17 minus the origin beam, with the absorb penalty charged
  only at the root comparison, the plain PEG verdict for predicates, a
  memoized repetition's evidence read off its chain, and a zero-width
  error mark for empty input. Same score (0.9900 / 86.0); 41 weighted
  trees differ from c17 at equal score and five raw cases cost one less;
  all gates and the extra checks; 1,194 lines (−136, −10.2% vs c17;
  +387, +48.0% vs c14); 0.76x c17 on the battery and 1.8x c14; 24k
  0.57 s / 330 MB, 100k 2.75 s / 713 MB, 200k 4.71 s / 1.22 GB, where
  the plain parser alone is 230 MB. Lessons 44–48 and 55. Why it is not
  promoted: the same workload call as c15–c17 (short inputs pay 1.8x
  c14); the user decides.

- **c19** (scratch `_c19.dart`, Codex 2026-09-05; not the standing
  engine): the repair relation as a small addition to the real library
  parser — `Recovery(parser).recover()`, repair bills in side maps keyed
  by MemoEntry identity, no engine-owned plain interpreter. 0.9900 /
  86.1, all gates, **470 lines**, the smallest engine ever at that score.
  But enumeration without locality: 1.9x c18 on the battery and it does
  not finish 24k in 150 s / 7.7 GB. Lessons 49–52.
- **c20** (scratch `_c20.dart`, 2026-09-07; not the standing engine):
  c19's relation on the real parser, c18's windows, and the repetition
  stop prune of lesson 58. 0.9901 / 86.3 — the highest accuracy measured
  — all gates and extra checks, 886 lines (+88.5% over c19, 0.74x c18),
  1.5x c18 on the battery, and 0.9x c18's time at 150k and 200k where c19
  does not run at all. Lessons 56–59. Why it is not promoted: the same
  workload call as c15–c18, short inputs pay about 1.5x c18 and 2.9x c14;
  the user decides.
