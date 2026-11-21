<!-- Part of LESSONS_LEARNED.md, section: 1. The problem and the yardstick -->
[Back to the index](../LESSONS_LEARNED.md)

## 1. The problem and the yardstick

An engine receives a grammar and a damaged document and must return the best
complete reading: a tree over the real input, with `SyntaxError` nodes
marking exactly what was denied (real text judged noise) or owed (text
judged missing). Directives: no second parse over a repaired string (D1); no
arbitrary constants (D2); never invent characters of an open class,
structural completion is fine (D7); the two acceptance readings of D8
(`,3true` → `,3,true`; `[,2,` → `[2,`).

**The battery** (`astdiff.dart`): every single-character mutation of every
corpus document that breaks the parse, plus truncations and two-site damage,
across three grammars — json, a statement language (blocks/if/assign), and
left-recursive arithmetic. Expectations come from the frozen parser reading
the undamaged original, so no engine can be tuned toward them. Scoring is
Levenshtein distance over named-node skeletons. Five categories, named by
the operation a person performed: truncation, deletion, insertion,
substitution, misc. Curation (I107): operator coin-flips and 1–2-character
truncation stubs are not generated, and truncation expectations drop
left-recursion wrappers whose evidence lies beyond the cut — the battery
asks only questions a human could answer.

**The gates** (all must pass; the battery cannot see them by construction):

- `_accept` — D8's readings: cx2, b1, b2.
- `_freespan` — may a repair delete real input that already matched?
- `_recommit` — does the engine keep a committed construct rather than
  re-reading the healthy prefix as something else?
- `_conf1` — exact repair-cost conformance, no free passes for predicates.
