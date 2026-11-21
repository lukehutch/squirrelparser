<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.18 Round 71: cross-review round 1 (gpt-6.1-sol medium, claude-opus-5-5 medium, gemini-4-argon high)

Three agents worked one brief (scratchpad `ur1/BRIEF1.md`): review the whole record, define the
exact problem, trace z15's misses, design and build a better engine. The brief was wrong in one
place: it called xref exact under the collapsed end-of-input price. Codex found the error.

**The two prices.** The record uses two costs without saying so.

- *Collapsed:* each inserted character costs 1, except that a run inserted at the end of the
  input costs 1 in total. z15 ranks with it (`cost => spent + (owed == 0 ? 0 : 1)`, z15:16).
- *Per character:* every inserted character costs 1. The freespan gate checks this price
  (`_freespan17.dart:67`, want 3 for `xxab`), the battery's `auditBad` counts it
  (`_research18.dart:457-460, 517`), and z15 reports it on its checked path (z15:398). z15's
  exact fallback reports the collapsed price (z15:536), so z15 bills one way on one path and
  the other way on the other.

Two agents proved, by different reductions, that exact repair under the collapsed price is
undecidable for a fixed PEG, already at cost 1: Codex from a universal machine's accepting
history completed at the end of the input, Claude from a PEG that checks Turing-machine
histories (Theorem 2). Both are proof sketches; neither was built as a grammar. Under the
per-character price the cost bounds the number of insertions, so exact repair is decidable
and, for a fixed number of edits, polynomial in n (Claude, Theorem 1, sketch).

**z16a: rank per character.** z15 with `cost => spent + owed` and the exact fallback billed per
character (two changed lines, 542 LOC). All gates pass. The battery falls from 0.9899 / 86.2%
to 0.9674 / 75.4% (261 trees differ, 13.8 s vs 3.0 s): the battery expects long completions of
truncated json documents, which the per-character price makes expensive. On the fuzzers it
closes most per-character misses (below). The battery's judgment needs the collapsed price,
which is the undecidable one; the decidable price loses 2.25 points.

**Measured in the master kit** (16 seeds x 400, `LIMIT=30`; `worse` compares self-reported
costs, so it mixes the two prices; `levWorse` compares the Levenshtein distance from the input
to the repaired string, so with xrefp in the run it is an exact per-character test):

| Engine | Agent | LOC | Battery | Gates | dl worse / levWorse | lf worse / levWorse |
|---|---|---|---|---|---|---|
| z15 | - | 542 | 0.9899 / 86.2 | all pass | 132 / 118 | 140-141 / 101 |
| z16a | orchestrator | 542 (+0) | 0.9674 / 75.4 | all pass | 102 / 19 | 141 / 20 |
| sol2 | Codex | 591 (+49, +9.0%) | 0.9899 / 86.2, auditBad 423 | freespan fails 4 | 21 / 118 | 22 / 101 |
| opu1 | Claude | 546 (+4, +0.7%) | 0.9899 / 86.2, auditBad 423 | freespan fails 4 | 18 / 155 | 44 / 130 |
| opu3 | Claude | 576 (+34, +6.3%) | 0.9900 / 86.2, auditBad 423 | freespan fails 4 | 13 / 155 | 20 / 130 |
| arg1 | Gemini | 579 (+37, +6.8%) | 0.9902 / 86.4, 3.7 s | all pass | 123 / 116 | 114 / 104 |
| xrefp | - | 165 | - | - | 3 / 0 | 2 / 0 |

The z16a, sol2, opu1 and opu3 rows are from one run (tag u1, `worse` counted against all six
engines); the z15, arg1 and xrefp rows from another (tag g1). Invalid trees and timeouts are 0
for every engine in both runs. z15's lf `worse` was 140 in u1 and 141 in g1; the one-case
difference is not explained.

**Verdicts on the agents' claims:**

| Claim | Agent | Check | Verdict |
|---|---|---|---|
| xref is not exact under the collapsed price | Codex | `S <- "abcdef" / ('x' 'y');` on `a` | confirmed |
| z15 publishes `spent + owed` while ranking collapsed (z15:16, 398) | Codex, Gemini | read | confirmed |
| Collapsed exact repair is undecidable at cost 1 | Codex, Claude | read the sketches | accepted as sketches, not built |
| sol2 cuts losses against xref from 187/217 to 15/20 | Codex | u1 run | confirmed as a bill, levWorse unchanged; Codex said so itself |
| opu1/opu3 fix traced misses (four relaxed filters, alignment pricing) | Claude | u1 run | wrong per character: levWorse 118 -> 155, 101 -> 130 |
| arg1/arg2 are worse than xref in 16 dl / 24 lf cases | Gemini | g1 run | wrong: collapsed bill against collapsed xref; per character 123/114, levWorse 116/104 |
| arg1 battery 0.9902 / 86.4%, all gates, 0 invalid, 0 timeouts | Gemini | battery, gates, g1 | confirmed |
| The `(r.first == p)` bit in `_Cell._key` fixes dl s3 `cacaa` | Gemini | g1: arg1 still pays 4, xrefp 2 | wrong |
| Clearing cells at the start of every rung makes a rung depend only on (input, rung) | Gemini | read arg1:393 | confirmed by construction; battery 3.0 -> 3.7 s |
| `_seq` and `_repeat` are unified | Gemini | diff | wrong: three shared helpers, file grows 37 lines |
| Removing the 64(n+1) prune causes no timeouts | Gemini | g1: 0 timeouts | confirmed on the fuzzers; the battery rarely reaches Exact |
| No single-parse engine can reach 0 invalid without a check parse | Gemini | read | unsupported: an argument about local cells, marked "proved" |
| Exact repair is NP-hard (3-SAT, G and k growing) | Gemini | not checked | unsupported |

Gemini's arg1 also deletes about 30 explanatory comments from z15's code; LOC does not count
them, so the loss is invisible in the size column.

**Conclusion.** No round-1 engine finds cheaper repaired strings than z15 except z16a, and z16a
loses the battery. The round-1 gains are in billing: what an engine reports for a string it
already chose. The open question for round 2 is a price for an end-of-input run of m
characters that grows without limit in m (so a cost bound limits the search and exact repair
stays decidable) and still ranks the battery's long completions first, with no fixed constant
(D2).
