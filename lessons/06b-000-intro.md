<!-- Part of LESSONS_LEARNED.md, section: 6b. The mechanism-A autopsy (json string-swallow, 2026-08-22) -->
[Back to the index](../LESSONS_LEARNED.md)

## 6b. The mechanism-A autopsy (json string-swallow, 2026-08-22)

The residual class: a single substitution inside a json string opens a
fake string literal whose repetition `[^"\\]` then swallows the rest of
the member — including the comma and next key — at charge 1. The honest
reading needs two edits (close the fake string, re-open the swallowed
one), so it costs more and loses the round race; the ladder stops at
budget 1 and never sees it. Root dumps confirmed this exact shape.

Four attack classes, all measured, all rejected:

1. **Tax where the swallow is proposed** (construct-boundary or
   grammar-literal-scoped): fires on intermediate search chains that a
   later budget rung legitimately resolves, or per-character via literal
   decomposition; both cost more than they fix.
2. **Rank suspects below clean readings** (three `litEvidence`
   refinements): cannot distinguish "this reading was reached through a
   swap" from "this reading was reached through an honest deletion" —
   c12's own best account for one damaged case carries the same mark.
3. **Judge whole-document after search** (absorbed-vs-evidence): the
   quantities do not separate — absorbed 16 < evidence 23 on the very
   case that motivates the fix.
4. **Let the ladder climb further**: the general latency problem, already
   measured (c11); not a targeted fix.

The durable lesson is about SIGNALS, not swallows: whether a reading is
a swallow is a property of what its subtree COULD have been under other
edits — counterfactual information that does not exist in the reading's
own totals. Any detector built from totals prices honest repairs too.
A correct signal would need to enumerate the alternative edits, which is
the search itself.
