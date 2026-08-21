# The c11 study: recovery as a minimal edit in code space

The question this study asks: when a document is damaged, how does the
pure parser's *execution* differ from the execution that would have read
the undamaged document — not the input, not the AST, but the set of
recursion frames the code actually runs — and can the recovered parse be
expressed as a minimal patch to that execution?

## 1. The code space

An execution of the pure squirrel parser is a set of **rule frames**:
memo keys `(rule, pos)` with the result each computed, connected by the
consult edges of the descent. Combinator code between rule boundaries
(Seq's slot loop, First's arm loop, Repetition's step loop, terminal
checks) is inlined into its owning frame. Because memoization is at rule
granularity, the frame set at rule granularity *is* the unit of shareable
work.

## 2. The unrolled traces (3-level nesting, one per damage kind)

Document `{"a":[1,2]}` under the json grammar; damage at the `:`
(position 4). The error-free execution, fully unrolled at rule
granularity with combinator code inlined:

```
JSON@0   = Seq: WS@0→ε · Value@0 · WS@11→ε
Value@0  = First: Object@0 ✓ (arms 2..6 never run)
Object@0 = Seq: '{'@0 ✓ · WS@1 · Member@1 · (',' Member)*: ','@10 ✗ stop · WS@10 · '}'@10 ✓
Member@1 = Seq: String@1 ✓ "\"a\"" · WS@4 · ':'@4 ✓ · WS@5 · Value@5
Value@5  = First: Object@5 ✗('[') · Array@5 ✓
Array@5  = Seq: '['@5 ✓ · Value@6→Number"1" · ','@7 ✓ · Value@8→Number"2" ·
                 ','@9 ✗(']') stop · ']'@9 ✓
```

**Substitution** (`:`→`X`, giving `{"a"X[1,2]}`):

```
identical:  '{'@0, String@1, WS frames left of 4
divergence: Member@1: ':'@4 ✗ (sees 'X')  → Mismatch(read 3, failing slot ':'@4)
spine:      Object@0 ✗ (optional member-list empty, '}'@1 ✗) → Value@0 ✗ → JSON@0 ✗
cascade:    Value@0's fallback arms Array@0/String@0/Number@0/Boolean@0/Null@0,
            each failing on the first character  ← junk, not information
never run:  the whole Value@5 subtree (the suffix)
```

The code-space edit from the failed execution to the correct one is
**one terminal verdict** — `':'@4: fail → "matched, claiming one real
character as wrong content"` — plus re-execution of the spine
{Member@1, Object@0, Value@0, JSON@0}, plus computing the suffix frames
once (they were never run), minus the cascade junk.

**Deletion** (`:` deleted, `{"a"[1,2]}`): same divergence frame; the
verdict patch is `':'@4 → "matched, zero width, owed"`. The suffix
frames sit at shifted positions, but they are computed on the real
damaged input either way — the shift is invisible to the engine, which
never sees the original.

**Insertion** (`{"a":X[1,2]}`): `':'@4 ✓`, then `Value@5 ✗` with *every*
arm's mismatch in the tree. Verdict patch: at the failing consult, skip
one character as noise, then consult again — `Value@5 → noise(1) +
Value@6 ✓`.

**Truncation** (`{"a":[1,2`): the divergence is at EOF; the open spine
frames each lack exactly their closing terminal: `']'@10 ✗`, then
`'}'@10 ✗`. The patch is a cascade of owed verdicts along the open
spine only — and they all assert the same fact, "the document stopped",
which must be priced once (the boundary-claim law, I94/I110).

## 3. The measurements (`_unroll1.dart`)

Over all 350 substitution cases of the battery (the damage kind that
leaves suffix positions unshifted, so frames compare by key), comparing
the clean run's frames with the damaged run's:

- **shared (same key, same result): 43.3 frames/case** — 65% of the
  damaged run's frames are bit-identical to the clean run's.
- **differ (same key, different result): 6.5 frames/case** — and every
  single one (0 violations in 2290) had probed across the damage
  point. This is the spine, and it is small.
- **damaged-run-only: 9.2 frames/case**, of which 2546 of 2548
  pre-damage frames read ≤ 2 characters: the choice-fallback cascade,
  fail-fast junk created by an ancestor's changed control flow.
- **clean-run-only: 48.3 frames/case**: the suffix the failed parse
  never reached. Recovery must compute these once; no scheme can avoid
  first derivations (the semi-naive refutation in the ledger said the
  same thing from the other side).

**Theorem (locality, measured):** the correct execution is the failed
execution with a handful of frame verdicts changed at the failure
spine, plus the suffix computed once, minus the cascade. The minimal
code-space patch is O(nesting depth) verdicts, not O(document).

**Theorem (addressing):** the natural coordinate of a verdict patch is
the memo key `(clause, pos)` — patches addressed this way commute with
memoization, because the memo is keyed by exactly the same pair.

**Theorem (the frontier is already computed):** the pure parser's
`Mismatch` nodes carry `subClauseMatches` — Seq keeps the matched
prefix plus the failing slot, First keeps *every* failed arm,
Repetition keeps what stopped it. The failed parse therefore returns,
in its own result, the complete list of frames where the next verdict
patch can apply. No engine machinery is needed to find candidate
repairs; the parser already reports them.

## 4. The design these force: parser restarts with directives

A **directive** is a verdict patch, addressed by `(clause, pos)`:

- `Owe(clause, pos)` — the consult answers "matched, zero width, owed"
  (a structural completion; D7 is respected because zero width invents
  no content). Mid-document it keeps the clause's name; at EOF the
  name is dropped (names are evidence, I96).
- `Skip(clause, pos, 1)` — the consult skips one character as noise and
  consults again at pos+1. Runs of noise emerge as chains: after a
  skip, the same clause fails at pos+1 and the next restart's frontier
  proposes the next skip — no widening logic is needed.
- `Replace(clause, pos)` — terminal-scoped: the terminal claims one
  real character as wrong content (the literal-scoped replace edit,
  I95; cost 1 where skip+owe would cost 2).

The engine is the **pure parser plus one changed line per combinator**:
every `sub.match(parser, pos)` becomes `parser.consult(sub, pos)`, and
`consult` applies at most one directive before delegating. Left
recursion needs *nothing*: the seed-and-grow loop is untouched code and
directives simply flow through its consults. (This is I100 — "a
mismatch and an LR seed are the same object" — seen from the other
side: MemoEntry's grow loop re-runs a parse with one seeded cell; the
restart loop re-runs a parse with one patched verdict. Same move,
different granularity.)

The search is uniform-cost over directive sets: run the parse (top rule
wrapped with an EOI slot, so "trailing junk" is an ordinary mismatch);
if it fails, read the frontier out of the mismatch tree and branch on
one more directive; if it completes, it is a candidate. Exhaust the
completing cost level, then judge all candidates simultaneously with
the five-key rank — whole-document judgment, because nothing commits
during search. Pricing carries the c-line's laws: skips cost their
characters, replaces one, mid-document owes one each, and all owes at
EOF collectively cost one (the boundary claim is one and idempotent).

## 5. What restarts cannot see (the honest limit)

Directive generation is frontier-driven: a tweak is proposed only where
some restart *failed*. A rival reading that requires a locally
*successful* greedy choice to go differently — splitting a purely
matching token, taking a later choice arm although the earlier one
matched — is never generated, because no frontier ever points there.
This is I98 (recovery's information is every rejected reading) as a
reachability gap, and it is the structural difference between this
design and the c-line, which keeps rejected readings alive per cell.
The gates (`_accept`'s b1 splits a purely matching "33") are exactly
where this will show. If it shows, the minimal completion is a
challenge directive (forbid a choice arm / cap a terminal's greed),
generated conflict-driven — only at choices on a completed candidate's
error spine — and priced as a penalty, not an edit. Whether that is
needed is an empirical question the prototype answers.

## 6. Expected economics

Fresh-parse-per-restart costs |states| × parse. The measured shape says
cross-restart memo sharing is worth ~65% of each restart plus the whole
suffix once, and that the true new work per restart is the ~6.5-frame
spine. The prototype runs fresh parses first (correctness before
speed), then adds directive-aware memo reuse if the battery latency
demands it.

## 7. Results (filled in as measured)

- Prototype: see `c11.dart` (815 normalised LOC; c9 890, c10 785).
- **Battery: 0.9874 / 84.7% perfect / 0 crashes / 0 uncovered**
  (deletion 0.981, truncation 0.995, insertion 0.993, substitution
  0.998, misc 0.962). The c9/c10 reference is 0.9879 / 84.0: c11 is
  0.0005 under on score with MORE perfect cases. One zero remains
  (i=168), down from the two that were long documented as this
  design's structural limit -- i=622 now scores 1.000.
- **All four gates pass**: `_accept` (cx2/b1/b2), `_freespan` 5/5,
  `_conf1` costs `0 1 1 0 2 3`, `_recommit` 16/16.
- **Latency is the unmet goal**: ~1,926 s for the battery vs c9's
  0.574 s. The time is a ~30-case tail of 20,000-run cap-outs
  (multi-error nested documents, 4-13 s each); the run cap returns the
  best reading found, so these degrade gracefully in score.

The §5 prediction came true and the challenge directive was built as
the **veto** (kind `_veto`): consult answers Mismatch, so a First
falls through to its later arms and a possessive repetition stops one
element short. The laws that made it workable, each forced by a
measured failure:

- **A veto is free in the charge** (`_costOf` skips it; `_judge`'s
  pieces exclude it). Re-asking a question the parse already answered
  is not an edit of the document -- pricing it as one (battery6) made
  cut+owe lose ties to junk-skips that the oracle's evidence key
  should have decided.
- **Veto sites are read off the run's own trees** -- the returned
  tree AND `run.discarded` (an Optional/Repetition puts its rejected
  body there, I98's home) -- as First winning-arm commits and
  terminal-body repetition element boundaries.
- **Frontier touch**: a commit is challengeable only if some
  enclosing match ends exactly at the run's failure frontier. A
  commit the parse moved past carried nothing; re-asking it floods
  the free band (measured: two battery-family cap-out regressions).
- **Span exclusion** (`vetoDead`): cuts of one repetition are
  alternatives, not composables -- the earlier cut stops the loop, so
  a later cut in the same span can never fire.
- **The consecutive-veto ban**: two free re-asks with no paid
  directive between them are never a composite repair; this also
  bounds vetoes by edits + 1, which is what makes charge bands
  finite.
- **Bulk ring admission**: `widen()` drops the floor to the lowest
  known ring in one shot. Level-by-level draining starved whichever
  damage family needed the far ring (site count is bounded; the runs
  a ring-per-round schedule burns are not).
- **Two priority indexes, one one-way switch** (the final piece;
  three battery iterations to find). While no reading has completed:
  queue-cost bands (vetoes pay one unit of ORDER, not charge),
  furthest parent frontier first -- greedy progress, so a capped
  multi-error search completes something instead of random-walking
  re-ask space. Once a reading exists: charge bands, expansion order
  within a band -- FIFO is the only order in which no self-feeding
  family (boundary-owe chains at the far frontier, junk pairs at the
  near one) can starve an equal-charge rival, because children always
  queue behind their parents. Either frontier extreme, used
  post-candidate, livelocked measurably (battery10: 18 newly
  imperfect at the near end; battery11: 22 at the far end).

What still separates c11 from the c-line bar: a cap-bound tail of
multi-error quote/bracket deletions (0.5-0.78) where the right
multi-veto rival exists but sits deep in a charge band the run cap
cannot exhaust, and i=168, where veto+owe on the first element makes
the repair consult (Value,0) while (Value,0) is in progress -- the
same-cell left recursion only a chart can serve. Both are the same
sentence from two sides: **a restart engine re-derives what a chart
holds**; the chart engines answer the rival-reading question by
POINTER comparison where c11 answers it by re-running the parse.
