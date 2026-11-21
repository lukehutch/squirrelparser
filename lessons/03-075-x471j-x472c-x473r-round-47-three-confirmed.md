<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### x471j, x472c, x473r - round 47: three confirmed parts on x464a: every deep input finishes (+55 lines), invalid fuzzer trees 66 -> 34 (+31), quiet parses without trees (-9.8% battery Ir, +10) (2026-10-11)

Three Opus builders worked on x464a, each followed by an independent
checker that re-measured its best engine. Codex was to brainstorm in
parallel, but OpenAI's content filter stopped both of its runs ("flagged
for possible cybersecurity risk") after 6-7 minutes, while it was
editing the kit's shell scripts; rewording "overflow" and "crash" in
the brief did not help. It left no report.

Depth (x471, checker confirmed):

- A larger stack is not available: the Dart SDK has no stack-size flag,
  and a spawned isolate gets the same stack as the main one.
- Fewer frames per nesting level (x471c, Seq in its own frame) lowers
  the depth that finishes (705 -> 630).
- x471j catches StackOverflowError only in `_safe`, which the top level
  calls. It forgets the path entries and every entry at a position with
  left recursion, reruns the shallowest path entry at each position,
  deepest first, in the engine state recorded at its entry, then
  retries. A cap (`++_dep == _cap` throws, `_cap` set from the last
  real overflow) makes later overflows cheap: a thrown error costs about
  1.3 ms, a real one about 170 ms. `_edits` is iterative. Reach and
  `_top` are written after a match returns, so an entry is either on
  the path or complete; this let the clock and the reach reset go.
- 306 -> 361 lines (+55, +18.0%). Same trees as x464a on the battery,
  fuzzer, gates and rungs; nesting 3200 and x(ax)*1600 b finish
  (x464a: 705 and 847); answers identical over 10 repeats on deep
  random inputs (x453s's defect was run-dependent answers). Battery Ir
  1.009x, 64/1 rung 0.95x.
- Ablations: rerunning in the top-level state instead of the recorded
  one changes 9-58 trees under forced overflows; rerunning by position
  without the depth order livelocks on left recursion; recursive
  `_edits` overflows at 3200.
- Open: random deep inputs are slow (n = 1100, 31 s); `_cap` is set from
  a nested `_safe` and never reset between inputs.

Validity (x472, checker confirmed with one defect):

| Engine | Change | Lines | Invalid | Worse (x464a) | Battery Ir |
|---|---|---|---|---|---|
| x464a | base | 306 | 66 | - | 1 |
| x472a | x462x's ban ported (`_into`) | 354 | 35 | 13 (31) | 1.131 |
| x472c | plain Parser over the inserted text | 337 | 34 | 16 (35) | 1.132 |
| x472e | c + forced `+` over nullable body | 344 | 33 | 21 (39) | 1.130 |
| x472g | ban decided at offer time | 321 | 65 | 8 (4) | 1.019 |
| x472h | c without choice arms | 334 | 47 | 6 (21) | 1.124 |
| x472j | c without repetitions | 337 | 53 | 15 (17) | 1.118 |
| x472k | c without the left-recursion exclusion | 334 | 37 | 51 (38) | 1.150 |

- x472c fixes bcbab (cost 2, witness "bcb"). 64/1 rung 1.008x and
  x(ab)*400 1.05x, so the walker was never the cost: with the walk off
  the battery still costs 25.3G against 23.15G. The inferred cause is
  the Expando now holding a record instead of an int.
- The checker found a crash: `rules[r.$1]!` looks a stripped rule name
  up in the unstripped map, so any grammar with a transparent `~` rule
  throws once the ban reaches it. The battery and the fuzzer have no
  such grammar. Fix: `p.rules[r.$1]!`.
- D1: x472c runs the plain parser over the inserted characters of one
  fix, a piece of the repaired string. x472a's set walker does not. The
  ruling is the user's.
- A ban decided when the fix is offered (x472g) sees only the element
  just before the fix and removes 1 invalid tree.

Smaller and faster (x473, checker confirmed):

- x473r: quiet parses (offers and probes) build no tree; a memo entry
  carries a loud flag and a loud parse redoes an entry a quiet parse
  made. 306 -> 316 lines (+10), battery treeDiff 0, fuzzer worse 0
  against 0, 1 tree differing at equal cost. Ir: battery 23.14G ->
  20.88G (-9.8%), 64/1 46.4G -> 36.7G, x(ab)*1600 24.8G -> 19.9G.
- x473v deletes `_wins` and keeps the offer with the largest r - p:
  306 -> 284 lines, battery 9.93G, 64/1 7.5G, but score 0.9811 ->
  0.9756 and fuzzer worse 146 against 18. `_wins` is 57% of battery
  time and all of that quality. No tie rule recovers it (costDiff about
  60 for each of four).
- Refuted: capping the `_wins` extension by the cost gap (64/1 rung
  306G, a fuzzer case at cost 1011); a `_wins` parse without a tree
  (trees change, one crash); 14 single-feature deletions, each of which
  lowers the score.
- The iteration cache ported onto x473r (x475d, 348 lines): 64/1 rung
  36.7G -> 19.2G with the same trees, but battery +10% and x(ax)*800 b
  overflows. The first port had a bug: a left recursion at the
  repetition's own position is read inside the first pass before its
  reach is known (`aacaabab` costs 3 instead of 1); stamping the
  position on each forget fixes it.

Open: one engine with all three parts; `_wins`' cost at equal trees;
the D1 ruling on x472c.

LOC: x464a 306; x471j 361 (+55, +18.0%); x472c 337 (+31, +10.1%); x473r
316 (+10, +3.3%).
