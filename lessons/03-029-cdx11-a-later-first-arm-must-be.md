<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### cdx11 — a later First arm must be one an edit could have forced (2026-09-23)

**The engine (`cdx11l`, untracked `_cdx11l.dart`) is cdx10 with four changes.**
Each one removes a class of invalid tree, where an invalid tree is one whose
failures (an earlier First arm, a repetition stop, an absent optional) do not
hold on the repaired string R. All four come from reading the fuzzer's
INVALID lines (`_q1diag.dart`), not from the battery.

1. **The lexical-repetition shortcut in `_read` was wrong and is deleted.**
   Its comment claimed that a one-character terminal cannot repair and advance,
   so every alternative of a successful lexical repetition is a prefix of its
   PEG tree. That claim is false. `S <- 'b'+` on `bcbb` costs 3 in every
   engine since c14 (it deletes the `cbb` tail), while one deletion of `c`
   suffices. Deleting the shortcut and the `_lexicalWays` field fixes it.
2. **A repetition can delete forward.** Deletions used to be offered only
   before a `Seq` slot. `_repeat` now offers, when no occurrence reads past
   the run's end, the nearest position within the budget where the body
   parses cleanly again, with a skip in between. The same loop in `_seq` and
   `_repeat` is one helper, `_resume`. The first attempt,
   calling `_seq([c.subClause], ...)` from `_repeat`, made 94–95 uncovered
   trees: `_Way.then` keeps only the last piece of a multi-piece way, so the
   skip was lost. The way is now built as `r.then(skip).then(clean)`.
3. **The insertion fallback is decided by a flag, not by an empty result.**
   The fallback (insert one occurrence) ran only when `best.ends` was empty.
   Once the deletion offer filled `best`, the fallback stopped running and
   equal-cost ties changed (for example Num became Name on `+2*3...`). A
   `read` flag, set when any occurrence read input, restores them.
4. **Two rules for a later First arm.** (a) A later arm stands only if an
   edit could have failed the earlier one: it must not be clean, and its first
   edit must lie at or before `reach`, the farthest end any earlier arm's
   reading attained. (b) Its first edit must not insert the character that
   starts an earlier arm (`_starts(e, lead)`), since on R that earlier arm
   would then succeed. Rule (b) exempts an earlier arm that is left-recursive
   (`_cyclic`), because a left-recursive arm fails on its first visit by
   construction: without the exemption the valid seed case
   `R0 <- 'a'?? (R0 / 'c'+)` on `b` is rejected. The old test
   `r.absorbed(pos) >= r.evidence` on later arms is implied by these rules
   and is deleted (same trees on the battery, same fuzzer counts).

**Measured (orchestrator's kit, confirmed):** battery 0.9899/84.3 → 0.9900/84.3,
190 trees differ from cdx10 and one cost is lower (i=1023, 2 → 1, now
perfect). Scores are better in 8 cases and worse in 3 (564 `1.,52e3`
1.0 → 0.917, 680 1.0 → 0.993, 756 0.958 → 0.938). Checks unchanged:
accept t/t/t, freespan 3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 3,
cleanTreeDiff 0, props 2728/0, window P at every n, pred 0 false assertions.
Fuzzer at N=400: invalid 26/21 → **12/11** (seeds 1/2), worse 4/4 against
cdx10's 78/87 (worse counts against the best listed engine). LOC 845 → 839
normalized (−6, −0.7%). Rungs (ms), cdx10 vs cdx11l: 1000/1/1 337 vs 330;
8/1 687 vs 698; 16/1 1,661 vs 1,872; 32/1 3,254 vs 3,636; 64/1 3,148 vs
3,804; 4000/4/2 1,157 vs 1,258; 8000/4/7 2,507 vs 2,505. Every rung finishes;
16–64 errors are 7–21% slower.

**Refuted or neutral in this round:** setting a deletion's `lead` to the next
input character (25 costs rise, all substitutions: a substitution inserts the
slot's character, not the next one); using the slot's character for a
substitution's lead (neutral: invalid 15/11 against 14/12, worse 7/9).

**Known limits, not changed:**
- Substitution exists only inside a `Seq` slot, so `R0 <- 'b'` on `a` costs 2.
- The Ref filter (`evidence > 0 || clean || end == pos || _oneShape`) counts a
  voluntary lexical scan as zero evidence, so `R0 <- 'c'* 'b'` on `ccca`
  costs 4 where one substitution suffices. This is the filter's deliberate
  policy against invented readings.
- Mutual left recursion still gives cost-0 invalid trees (for example
  `aaaac`): the engine's relation fixed point is not PEG's seed growth.
- `_q1diag` counts a tree as invalid only when the plain parser rejects every
  witness spelling of it (membership). It does not compare spans or First
  arms with the plain parse of the repaired string; its `_diag` line only
  prints a diagnosis. The invalid counts above are lower bounds. A strict
  count (`_q1strict`, any node span or arm that differs from the plain parse
  of R) gives 122–151 per seed for cdx10 and 127–179 for cdx11r; about half
  of those trees differ only within one character of an edit, mostly a
  repetition or First arm that would continue across the edit point. The
  strict count does not separate the engines (trees with a difference more
  than one character from every edit, seeds 1–4: cdx10 199, cdx11r 224).
