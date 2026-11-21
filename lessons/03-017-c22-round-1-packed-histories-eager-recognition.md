<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### c22, round 1 — packed histories, eager recognition (2026-09-08)

**69. A packed forest is implemented; packing alone is not a performance
solution.** `_c22eager.dart` preserves this round's executable. It attaches
AND/OR recovery relations to actual native memo entries, with budget-indexed
cells and no windows or beams. It does not create a second Parser, alter the
input, or replace ordinary PEG verdicts. Discrete relation keys contain end,
spent edits, fee, EOF-owed flag, clean rank, and incomplete flag. Evidence,
deletion/missing split, first/last error positions and concrete histories are
not recognition keys.

The implemented selection factors non-additive pricing into queries. Fixing
the deletion count makes support filters monotone in evidence. First-error
and last-error bounds constrain every error leaf; three passes maximize
evidence/first, constrain first and minimize last, then constrain both and
apply a stable owed/count/canonical-tree preference. The final mixed-edit
tie-break is applied at the root. Optional direct-terminal repetition is
the evidence-erasing case; here evidence before erasure is fixed by consumed
span minus deletion count. This is an algebraic argument for this engine's
specific filters, not a proof for arbitrary recovery policies.

CONFIRMED initial checks (run from `dart/` with
`/opt/flutter/bin/cache/dart-sdk/bin/dart run experiments/recovery/…`):

- `_compare22.dart gates c22`: A=3, F=5, R=16, C=6, committed=true,
  committedErrors=[2..3,3..4], falsePredicates=0, failures=[], errors={}.
- `_properties22.dart c22`: 2,728 cases, 60 clean, zero violations.
- `_memo22.dart`: 34 checks passed, including unchanged Parser/MemoEntry
  identities, ordinary verdicts, input and clock, and shared clean subtrees.
- `_research22.dart battery c22 compare`: 2,101 cases, score .989836,
  1,800 perfect (85.7%), zero crashes/uncovered/mischarges/invalid-zero;
  2,020 raw-tree differences and zero cost differences from c20. The large
  raw-tree count includes label differences on clean EOF subtrees, not 2,020
  changed AST skeletons. This is below c20's .990135 / 1,806 perfect.
  Timed recovery total was 3,862 ms (single JIT run, not a warmed median).
- `_packed22.dart scale 1000 4 1`: length 23,568, cost=edits=4,
  covered=true; **43,890 ms / 11,774.3 MiB process peak RSS**, 31,663,803
  nodes, 13,593,328 groups, 332,412 budget cells. Only 25,155 query states
  were needed. This timing overlapped short audit workers; it is not a
  controlled speed ratio. The allocation count itself establishes failure.

This round is rejected as a performance candidate. Histories are shared,
but eager enumeration of repetition endpoints still builds an enormous
relation that its actual continuation scarcely uses. The next experiment
must share continuation/suffix work, not merely the prefixes that lead to it.
`dart/lib` and the pre-existing engines were not edited.
