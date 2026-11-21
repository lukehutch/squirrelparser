<!-- Part of LESSONS_LEARNED.md, section: 6. The refutation ledger (do not retry without new evidence) -->
[Back to the index](../LESSONS_LEARNED.md)

## 6. The refutation ledger (do not retry without new evidence)

| Claim | Verdict |
|---|---|
| A point window at the death, no walk at all | 0.9665 / 77.5 at 733 lines: the walk is worth 0.0236 and 8.8 perfect |
| Widen the window by doubling on a failed round | 0.9867 / 0.9874 at 742 / 758 lines — better than a point, still short of the walk |
| Walk the frame chain without descending into finished pieces | keeps 0.9900 / 86.1 but the first window is (0, 4077) not (4037, 4077): 24k does not finish |
| Drop `_fresh` (re-enter the piece that ends at the death) | battery IMPROVES to 0.9903 / 86.5, and 150k goes 2.1 s / 797 MB → 29.0 s / 6.3 GB; the battery is short inputs and cannot see it |
| Mark a boundary at every repetition occurrence, lexical included | 0.9805: a per-character scan marks every position, so the window is four characters wide |
| Mark a boundary at each sequence slot end | 0.9893; at each whole-sequence end, `costDiff` 3; at each repetition START, `costDiff` 2 |
| Widen the boundary count instead of capping it | score plateaus at 0.9900 / 86.1 from `back` = 6 and costs 28% more time; the residual gap to the walk is not window width |
| Boundaries from the ordinary parse ALONE, counting back `back` of them | 0.9797 at `back` = 4, 0.9884 at 16, 0.9900 at 64 — and 64 costs 3.7x the time at 24k and 4.5x at 200k |
| Clear the boundary marks each round to keep them local | battery unchanged, and the 47,618-character window survives: the gap is inside one round |
| Enter a death at the granularity of the scan that ends there | battery unchanged, blowup unchanged: the death was not at a scan's end |
| Delete the budget; compute cells once | ~100x latency; the budget is the horizon (A3, twice) |
| Grammar rewriting as the engine's foundation | −0.0008, foreign trees, and the library's LR does the same work (c2) |
| Repetition through its own memo cell | 2,440 vs 1,535 ms, no accuracy change (twice) |
| Greedy commit-one-then-reparse as judgment | the b-line's 0.88 ceiling: the correct choice depends on repairs not yet made |
| Eager trees / ways as materialized trees | +20–31% latency at the tie-refresh volume (I88 ×3) |
| Ties keep incumbents / PEG-first ties | −2.6 to −3.1 perfect; latest-wins stands (×4) |
| The fee ranked below net | breaks the acceptance gate: the b2 fill out-nets its denial and must still lose |
| Universal replace edit (all slots) | zero residual cases fixed, two regressions, 2x latency |
| Per-position version bump with ubiquitous growth | battery timeout; Warth's involved-set is the rule |
| Root simplification (drop owed-admission) | recommit fails: the incoherent honest reading must displace the coherent swallow |
| Prefix-freeze with conditions (non-LR, window, clean) | its consult cost its savings; budget-zero alone is faster |
| Merging `_determined` and `_minFill` | memoizing under a cycle-cut poisons minFill inside LR paths |
| Net crediting bare `Match(null)` spans | re-weights every completion's matched prefix; −3 recommit cases |
| A literal through the memo cell (an anonymous rule) | judgment-identical, +25% latency: front ceremony on every MATCHING literal outweighs caching the failing folds |
| Rank without latest-doubt / without the stranded count | −3.4 / −2.6 perfect (re-measured on c6, post-vouch): both keys stand |
| The stranded count collapsed to a bit | −2.6 perfect, identical to dropping the tier: the count IS the tier (I105, re-confirmed era-3) |
| `spend := edits` (eof claim in the budget) | −0.0019, truncation 0.997→0.990: the additive-ledger law |
| The fee counted as an owe (`fees` into `gap`) | battery-identical, ALL gates green — rejected on the audit identity: a winning fee'd way would report an edit the tree cannot show |
| Literals through the FUSED memo, and the naked version rule | both judgment-identical, both slower: literal fronts +25%; the version rule without the dep bit −13% (cold-starts every same-position cell per growth step) |
| Stateless predicates (delete _Look's front) | judgment-identical, badly slower: the predicate's front was the ONLY cache over its Ref-to-literal sub chain — memo state acts at a distance, and "dead" state can be load-bearing for a different node's latency |
| Composite freeze cached by allocating a front per probed position | a cache whose MISS allocates a front+map at every deny-scan probe costs more than the structural matches it saves |
| The front read-view cache | judgment-identical; unresolved under machine load (paired ratios 1.00±0.10) and dropped — a front stays read-only on reads; retry on a quiet machine |
| The budget watermark folded into the version array | blocked by analysis: atBudget is a >=-ordered clock serving every smaller query; the version is an =-checked clock scoped by usedSeed. One counter cannot express both, and unscoping the version is the −13% naked-version design. The absorbable piece — "never computed" as memoVersion == −1 — was absorbed (judgment-identical) |
| Canonical cell fills (every fill at the round's full budget) | +0.0001 score, 1.6x latency — declined: most cells are only reached by mostly-spent readings, and never exploring deeper than asked is where the time goes. The lazy watermark is the design, now documented with its price |
| The strict zero fiber (budget-zero always answers with the cached plain parse, never the champion map's zero-cost view) | ADOPTED: battery-inert, ~5% faster, and the zero fiber becomes order-independent — the last query-order dependence at budget zero is gone |
| Semi-naive evaluation / avoid re-derivation (the fix BOTH outside analyses converged on) | only 29% of fills re-derive an unchanged value; the other 71% are first derivations no delta scheme can skip |
| Saturation — run each budget's fixed point to completion so rungs start warm | ~7% fewer fills, zero time won: the rung tax is the ladder's shape, not repeated work |
| Compare-before-allocate (judge a candidate from component sums, allocate only on keep) | 1.02–1.04x SLOWER, measured twice (with and without `@pragma('vm:prefer-inline')`): the avoided young allocation was nearly free, and the guard duplicates the sum arithmetic on every keep |
| Cross-run cell reuse (grow-only arrays, epoch stamps, in-place reset instead of fresh allocation) | 1.10x SLOWER: stores into old-space objects pay the GC write barrier fresh young arrays never do; c6's fresh-arrays-per-run is the optimum, not a shortcut |
| The per-op campaign (indexed loops, fold micro-shapes, terminal tweaks) | ±5% with unstable sign under load; representation was the lever (R6–R8, 1.7x), operations were noise |
| Drop the substitution repair entirely (c12) | 0.9885 / 84.4 — fails the perfect bar. The repair is required; only its offer site was negotiable |
| A non-evicting substitution (keep the swap reading beside the incumbent instead of pruning against it) | 0.9895 / 85.6 and no operation count won: eviction was not the cost, the newly opened position was |
| The substitution offered `.penalized()` | 0.9886 / 84.6 — a penalty is not a ranking-only hint; it counts into charge, so it changes what the budget can afford |
| A ranking-only `guess` bit marking swap-derived readings (tried as an early key, a late key, and cleared at construct boundaries) | 0.9891–0.9895 / 85.4–85.6: a large operation cut, but it loses six mid-array-delimiter substitutions that are EXACT ties, which is precisely where a tiebreak bit does damage |
| `(end, guess)` as the per-end pruning key | battery timed out past 600 s (from 0.6 s): two survivors per end is not a refinement, it is a second search |
| Gate the substitution on `slot.text?.length == 1` | holds the record score, but a reproducible ~15% slowdown on the CLEAN path in an A/B/A test, for no damaged gain — the check runs where nothing is damaged |
| Gate the substitution on `deletedAhead < 0` | 85.7 perfect: cheaper than `_resumes` to evaluate and strictly worse at telling a swap from a guess |
| Detect the json string-swallow from reading totals (construct-boundary tax) | 0.9893 / 85.2 + 45 uncovered: the detector fires on intermediate search chains — a chain that later resolves is not evidence |
| The same tax priced only on grammar-literal failures | 0.9859 / 83.4 and ~26x battery time: literal decomposition makes the tax fire per character of every multi-char literal failure |
| Rank-suspect flags, three refinements (`litEvidence` accounting v1–v3) | 0.9843 / 0.9845 / 0.9847 — all WORSE than baseline: the flag condemns c12's own legitimate delete-quote-and-reassociate account; collateral ≥ the ≤+0.005 gain |
| Whole-document scope to judge swallows post-hoc | structurally blind: the swallow's absorbed span (16 chars) never exceeds the honest reading's evidence (23), so the comparison cannot separate them |
| The swallow family itself (charge-1 escape substitution opens a fake string whose `[^"\\]` swallows a member) | RE-DIAGNOSED 2026-08-22 (see §6c): the winning accounts are usually TRUE minimum-cost readings the yardstick penalizes — e.g. deleting one letter makes `""` a legal key at cost 1 where the human's repair costs 2. Not engine failure |
| Hold the ladder one extra rung past first admission, so costlier rivals reach the root | On all four worst json cases the extra rung's root frontier held only same-key duplicates of the winner — no honest rival exists AT THE ROOT at any single extra rung's depth |
| Retain exact-seven-key ties beside cell holders (cap 3/end), letting composition see both | As an engine change: WORSE (imperfect 298→330, mean 0.9896). As measurement: even a PERFECT offline oracle judging every collected candidate reaches only 0.9908 (+0.0012); 12 expr-deletion cases hold a perfect reading the comparator cannot see |
| Price deleted input above inserted text (destruction worse than invention), weights 2 and 3 | 0.9824 / 0.9656 vs 0.9899 — asymmetric pricing collapses insertion AND substitution categories too. Symmetric per-character pricing is strongly optimal under this yardstick |
| Local rungs / per-region budgets (c14 round: each failing region climbs its own ladder, the rest stays at zero) | 0.9875 / 84.7 — to four digits c11's restart number (0.9874 / 84.7), from a different design; a lower-rung reading that died one character short of a wrong family's reach holds the next rung's winner anywhere, so the frontier must be one number. Third refutation of locality; do not retry |
| Swap the order of the seven comparison keys (evidence before cost, and cost before evidence with charge first) | −0.0033 either way |
| An evidence memo on rule wrappers (`_Node extends lib.Match` with a lazy `evidence` field) | ≤11% and inconsistent in sign after the budget handoff; clean 1.00–1.09x (noise); every-node form 1.10–1.32x SLOWER on the clean path. Dropped from c14 |
| The library's parser memo as the plain fiber (consult `lib` for budget-zero answers instead of the engine's own plain memo) | 2.71x slower: the library's memo is keyed for its own left-recursion protocol and answers through a wrapper per consult |
| A per-budget view cache | no effect (the c12 round; re-confirmed as unnecessary once the sweep handoff removed the over-deep fills it would have cached) |
| `_Front` scan limit 8 instead of 32 | slower at 6k chars (map built for constructs that finish scanning), equal at 24k; 32 kept |
| Frontier frames keyed by their whole stack (c15 round, K=∞) | exponential in the open repaired frames: 18,516 shapes at one position of a 1.4k document, 2.99M entries / 8.4 s / 2.7 GB at 64/4, OOM at 24k; 0.9842 |
| Frontier frames keyed by K frames of context and no origin (c15, K=0..4) | 0.9113 / 0.9153 / 0.9332 / 0.9642 / 0.9618 — merging frames that differ in their enclosing context is unsound; the origin (lesson 29) is the key |
| Beam narrower than 8 origins per (position, shape) (c15, W=4/2/1) | 0.9887 / 0.9788 / 0.9290; W=8 equals the exact search on the whole battery |
| Exact origin-keyed frontier (c15, W=∞) | same score as W=8 but Θ(n²) walker readings: 15 GB and unfinished at 24k/4 |
| Beam of 4 origins per (state, end) in c14's cells (c16, W=4) | 0.9890 / 85.3 (333 diff lines); W=8, 16 and ∞ bit-identical to c14, so 8 is the width |
| Drop a repetition's non-greedy ends from the sweep (c16 round) | wrong: a nested construct that closes early needs the shorter end (the early-close case); refuted before measurement |
| Exact per-context refills of served cells as the default (c16) | battery-identical but sign varies by instance: 6.8 vs 8.8 s (24k seed 7), 13.3 vs 8.0 (24k seed 1), 106 vs 32 s (100k seed 2). Kept behind `-DREFILL=true` |
| Evidence memo on library-typed trees alone (an `Expando` on composite matches, c16 round) | never hit: c14 builds a fresh plain tree per call, so there is nothing to remember until the plain match itself is memoized (lesson 35) |
| Beam rows in hash maps keyed by (state, end) (c16 round) | replaced by arrays indexed by state then end; the map lookup was in the admission hot path |
| Timing several rungs in one process (c16 round, method) | invalid: the heap grows to 7 GB and later rungs slow down; one process per rung |
| Contiguous walk of K units across frames for the window (c17, first walk) | window from the death back past an enclosing frame's swallowing last unit: (26775, 150663) at 150k; the per-frame walk with fresh entry (lesson 40) replaces it |
| Leaf-granularity walk, and death-only entry with a shared count (c17) | both lose json 118 (the `[` inside the previous sibling); 0.9900 needs the per-frame spans |
| A 256-character cap on a window (c17) | same battery, a magic number; rejected for the per-frame walk |
| The frame's origin as the edge for a frame that counted no unit (c17) | windows from position 0 ((0, 13979) at 24k, (0, 26813) at 150k); 29 s / 2.08 GB at 24k, 200k did not finish |
| The budget-zero shortcut without noting a death (c17) | the real failure point (23937 on 24k seed 1) never windowed: cost 5 vs c14's 3 (lesson 41) |
| Skip the end-of-input death's window (c17) | 0.9840 / 83.7, 74 cases worse: that walk finds the repair inside a string that swallowed the rest of the input |
| Skip the end death's re-run when the winner has missingAtEnd 0 (c17) | 0.9897, 157 diff lines; the re-run stays |
| Also refuted in the c17 session before the per-frame walk: K other than 2, innermost-walker ownership of the walk, death = no offers, accepting a winner before opening the window, min over frame proposals, a slot as one unit, re-runs without the beam reset, a full reset per window | each lost battery cases or was O(E·n); details in the session transcript named at the top of this file |

| Bucket the repair front by its two equality-class heads (c20) | identical trees, no speedup: battery 1,481 → 1,517 ms, 100k 5,208 → 5,266 ms; the map traffic costs what the skipped comparisons save |
| Reorder `cover` to test the equality-class heads first (c20) | no change (1,495 ms battery, 5,229 at 100k); the cost is the number of insertions, not the price of one (lesson 56) |
| Prune a repetition to its clean stops only (c20) | no effect at all: every reading the prune would have dropped was already clean |
| Prune all short stops on closed ground (c20) | fastest of the criteria (1,862 ms at 100k) but 0.9895 / 85.7 with `costDiff` 8 |
| Keep only the farthest stop per bill (c20) | 0.9898 / 86.0, `costDiff` 8; both ends of the range gives 0.9900 / 86.1 and still loses four `stmt` cases that need an interior stop (lesson 58) |
| Collapse a sequence's equal-end readings and re-run the same budget (c20) | 0.9891–0.9892 and slower on every rung, with or without doubt quantization |
| A separate rule for an absent optional (c20) | no measurable gain on any rung; excluded as unused code |
