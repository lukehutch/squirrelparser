<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### cl8 — cdx11s with eleven rules deleted and the ordering penalty turned into a tie-break: 802 → 712 LOC, the same speed, fewer invalid trees (2026-09-23)

**What was deleted (each confirmed by battery, gates and fuzzer; untracked
`_cl8.dart`).** Every change below keeps the battery at 0.9900/84.3 and all
gates passing; together they change 6 battery trees at equal score.
- `_view`: the per-budget view cache, and the rule that dropped an edited
  reading ending where PEG's plain reading ends. The view is now: level the
  cell's readings, keep those within budget, and read a preferred reading
  that ends where PEG ends as PEG's own reading.
- Ref: the support filter (`r.end - pos > r.deleted || r.clean || ...`).
- Seq: the per-slot leveling of the incoming front; the `r.spent > _budget`
  skip; the condition that resumption and substitution are tried only when no
  clean option advances; `_resumes` (a substitution no longer has to be
  followed by a clean read of the next slots).
- First: demoting a later arm's readings.
- Repetition: the filter on a step that is a pure deletion with no evidence;
  the rule that kept an earlier stop when the bound proved the rest of the
  document cheaper from there.
- `_Bound`: the transition that skips a whole Str for one deletion.

**The ordering penalty is a tie-break, not a cost.** cdx11s added one to a
reading's `charge` (cost + fee) for an insertion a deletion could have
avoided, and used `charge` both to rank readings and against the budget.
Ranking by cost first and by that count second (`avoidable`), and checking
only cost against the budget, changes no tree, cost, gate or fuzzer answer
(h1 against the fee version). `charge` is gone; `_compare` is cost,
avoidable, evidence, first, last, owed. Of the penalty's conditions, `!o.clean`
is implied by `ahead <= o.missing` with `ahead > 0` (deleted, no change);
every other condition changes results when dropped: the last-slot exemption
0.9898/84.1, the one-shape exemption 0.9899/83.9, the one-shape and seed
exemptions together 0.9882/83.7, `ahead <= o.missing` 0.9896/84.1,
`o.end == r.end` 0.9732/80.5 with 35 costs changed.

**The penalty cannot be deleted, and D7 alone cannot replace it.** Without it
(cl6, 679 LOC) the battery rises to 0.9902/84.8 but gate b2 fails:
`[,2,33,true]` gets an invented digit instead of losing the comma. The battery
contains the same shape both ways (`[,33,true]` from a deleted `2` scores
insertion; `[2,,33,true]` from an added comma scores deletion), so no local
rule can win both; cl6 wins more of them, and b2 is D7. Three D7 rules on
cl6, all refuted: never insert a CharSet/AnyChar (0.9704/76.8, fails cx2;
the same ban away from end of input 0.9733/78.2, fails cx2); an invented
open-class character as evidence −1 (0.9900/84.1, still fails b2, because
the comma it keeps is evidence +1); a count of invented open-class
characters ranked after cost, before evidence (passes b2, 0.9803/81.1: the
expression corpus wants `a+*2` → `a+b*2`, which is also an invention) or
after evidence (0.9901/84.1, fails b2).

**A guard that changes no tree can still be the speed.** Always resuming in
`_repeat` (deleting the `steps.any(clean && advances)` guard) keeps every tree
and costs 4x on 1000/128/1 (7.7 → 32.6 s) and 2x on 8000/32/7 (10.9 → 23.6 s).
It stays.

**Measured (confirmed).** LOC 802 → 712 normalized (−90, −11.2%). Battery
0.9900/84.3, 1,580–1,644 ms (cdx11s 1,485–1,541 in the same runs, 3–7%
slower); treeDiff 6, costDiff 0. Accept t/t/t, freespan 3 3 4 4 1, recommit
16/16, conformance 0 1 1 0 2 3, cleanTreeDiff 0, props 2728/0, window P,
pred 0. Fuzzer seeds 1–4 against cdx11s: invalid 6/6/6/12 against 6/7/6/17;
worse 1/0/1/0 against 6/4/5/9. Rungs, alternating (ms, cdx11s / cl8):
1000/1/1 309/299; 1000/32/1 3,356/3,304; 1000/128/1 8,299/7,920; 8000/4/7
2,548/2,304; 8000/32/7 11,934/11,454; every cost equal.

The rest is restructuring: `_first`, `_optional`, `_after` (read after a
reading with its unspent budget), `_level`, `_body`, `_text`, a `_Guard`
typedef, `departed` for `first == _clean`, and switches in `_propose` and
the bound's automaton builder.
