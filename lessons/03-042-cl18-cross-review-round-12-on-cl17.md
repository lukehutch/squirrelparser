<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### cl18 - cross-review round 12 on cl17: the opener guard sees the whole inserted literal, 792 -> 796 LOC (2026-09-24)

Round 12 ran a Claude subagent (Opus 5.5, high effort) on BRIEF12 (Q1 invalid
trees, starting with the 8 cases where cdx1 is valid; Q2 one validity rule in
place of several guards; Q3 family 43 and the `_rejected` flag; Q4 size and
elegance; Q5 review of round 11). Codex and Gemini had no quota (until about
Sep 29). The engine is untracked `_cl18.dart` (kit name r12c18e): the seat's
`cand` plus the orchestrator's elegance review.

**What cl18 changes (confirmed from the diff against cl17).**
- **The opener guard tests the whole inserted text.** `_read` gives each
  reading of a multi-character literal with no deletion a `lead`: the rest of
  the literal from its first edit, `c.text.substring(r.first - pos)`. `change`
  takes an optional `lead`. `_starts` no longer requires a one-character text,
  so the guard asks whether the inserted text revives the body, not only its
  first character. A lead is never empty: it runs from an edit inside the
  literal to the literal's end.
- **A covered repetition's stop is left to the repetition that encloses it**:
  `_tail` skips a `Repetition` in `_covered`.
- **Two changes that change no result**: `.demoted` in the requireOne block
  (trees equal on the battery and fuzzer seeds 1-8); the `_rung` test
  `w.bad || w.departed` is evaluated once (`dropped`, +1 line, kept for
  clarity).
- Comments now say "literal" and "text" where the guard used to take one
  character. Elegance review: the guard functions' parameter `ch` is now `s`
  (it holds a text), which lets the formatter join two lines (798 -> 796
  normalized); renaming it `lead` instead wrapped lines (804).

**Measured (confirmed), kit r9/verify.** LOC 792 -> 796 normalized (+4,
+0.5%; raw 792 -> 798); the size target is missed. Battery 0.9900/84.4, treeDiff 0 and costDiff
0 against cl17, 1,821-1,857 ms. Accept t/t/t, freespan 3 3 4 4 1, recommit
16/16, conformance 0 1 1 0 2 3, cleanTreeDiff 0, props 2728/0, window P, pred
falseAssertions 0. Old fuzzer invalid 2/2/4/6 (= cl17), worse 0, treeDiff
22/29/23/31 at equal cost. No-repair 0. All 46 families finish with cl17's costs (family 43 at
16,384: 39,448 ms, cl17 40,101). Stress and rungs equal to
cl17 within noise (errors 4,096 160 / 161 ms, left recursion 8,192 312 / 357
ms, 1000/128/1 4,594 / 4,564 ms, 8000/4/7 6,116 / 5,858 ms).

**Corrected fuzzer, three-way with cl17 and cdx1 (confirmed, one run).**

| Seeds 1-8 | invalid | worse | levWorse |
|---|---|---|---|
| cl17 | 8/5/7/4/7/7/6/9 = 53 | 1/1/5/2/0/6/3/2 = 20 | 1/1/3/2/0/2/2/2 = 13 |
| cl18 | 7/5/7/4/7/6/6/9 = 51 | 0/1/5/2/0/5/3/2 = 18 | 0/1/3/2/0/1/2/2 = 11 |

Every seed is at or below cl17. levSum is equal on seeds 2-5, 7 and 8, one
higher on seeds 1 and 6 (532 against 531, 524 against 523). The two fixed
invalid trees are s1 `cba` (cl17 1002, cl18 1; cdx1 5) and s6
`R0 <- (R1 / R1?); R1 <- ('b' (('a' R0) "ab"+))` on `babab` (1007 -> 1). The
seat's two-way run finds 108 differing trees, all others at equal cost and
validity (not rerun). 18 of the 19 cases where cdx1 was cheaper remain.

**Determinism (confirmed, g/m copies).** Battery treeDiff 0; fuzzer seeds 1-8
differ only on seed 3 `aabb`, as in cl17.

**The 8 cases where cl17 is invalid and cdx1 valid, traced by the seat.** Six
causes:
- A, the opener test saw one character (`cba`): fixed by cl18.
- B, the guard cuts at the match end where the body's examined extent is
  needed (`ccacccababb`, `aaaaa`): a look rule fixes them (w2) but adds 56
  lines and raises worse on seeds 3, 5 and 7.
- C, a left-recursive seed read empty under the `_usedSeed` exemption
  (`cbccbcb`, `cbaa`): conjectured from the diagnostics, not built.
- D, a later First arm whose first edit deletes where an earlier arm still
  matches (`ccaab`): not built.
- E, the diverse ladder resumes past a deletion the guard forbids (`ccbbbc`):
  fixed by `_free` (below), not kept.
- F, an exact tie decided by the last key (`aaacbbb`).
Of cl18's 51 invalid trees, most are a repetition or option PEG would read
longer on the repaired string (groups B and C), then ordered choice (D).

**Negative results (the seat's measurements).**
- **No single rule replaces several guards.** The look rule (w1, both cuts):
  invalid 61, worse 30. The lead rule implies no other guard: deleting
  `_finishes` on top of it gives +1 invalid on s4, the `_stop` seed line worse
  56, the requireOne block 0.9694. A resume lead in place of `_resume`'s guard
  skip (w3, w4): 12 battery trees change, worse 41 or 26 against 24.
- **Family 43.** The diverse ladder is about half its time (confirmed: a copy
  that runs it only when nothing was found takes 1,465-1,530 / 5,325-5,389 ms
  at 1,024 / 4,096 against cl18's 2,641-2,649 / 10,314-10,343 ms, same costs).
  In family 43 the flag is always set by `_Front.add`
  seeing a bad reading, never by `_rung`. The diverse ladder never runs on the
  battery; on the fuzzer it runs on 35 of 3,200 inputs and changes 12 answers
  (7 replaced, 5 found from nothing). Every narrower condition changes trees
  or leaves family 43 unchanged: the flag from `_rung` only for dropped
  readings at or below the found cost (no gain), no flag from `_Front.add`
  (worse above cl17 on s2 and s8), the flag only from the answer's rung
  (battery treeDiff 1).
- **V1 (the clean skip in `_view`) stays**: -4 lines, but `(('a' 'a')* (R0
  'a')*)` on `aaaaa` (s7) becomes invalid.
- **cand_free** (cl18 + `_free`: the diverse ladder skips `_resume`'s guard
  only when the ordinary ladder found nothing), 799 LOC: invalid 49, worse 17,
  17 of 19; but the old fuzzer loses two cases, s3 `('a'? 'a' 'a')` on `caab`
  (2 -> 3; cl17's repaired string is rejected by plain PEG) and s4
  `((R0 / R0)? 'b' 'b'?+)` on `bbbbbaab` (2 -> 3; a real loss: `_resume`
  stops at an empty match of the nullable `'b'?`). Two fixes for s4 failed
  (battery treeDiff 39; worse above cl17 on s6, s7). Not rerun here.

**Candidates.**

| Candidate | Change | Result | Score | Reasoning |
|---|---|---|---|---|
| r12c18e = cl18 | cand + `ch` -> `s` | trees = cand; 798/796 LOC | 8 | every target but size |
| cand (Claude) | lead rule + covered `_tail` + `.demoted` removed + `_rung` merge | 798/798 LOC; invalid 51, worse 18; treeDiff 0 | 8 | two invalid trees fixed, nothing lost |
| cand_free (Claude) | cand + `_free` | 799 LOC; invalid 49, worse 17; old fuzzer s3, s4 lose | 7 | better fuzzer, one real old-fuzzer loss |
| w6 (Claude) | V1 deleted | 796 LOC; invalid 50 on the `_free` line, +1 on s7 | 5 | -4 lines for a real loss |
| w2 (Claude) | look rule where the cut is null | 848 LOC; invalid 49; worse up on s3, s5, s7 | 3 | fixes group B, +56 lines |
| w1 (Claude) | look rule for reach and cut | 843 LOC; invalid 61, worse 30 | 1 | worse on every column |
| w3, w4 (Claude) | resume lead | 794 LOC; treeDiff 12; worse 41 / 26 | 1-2 | battery trees change |
| w10, w8, w12 (Claude) | narrower `_rejected` | trees change or family 43 unchanged | 1-3 | no tree-preserving speedup |
| lead + a guard deleted (Claude) | `_finishes` / `_stop` seed line / requireOne | +1 invalid s4 / worse 56 / 0.9694 | 0-1 | each guard still decides a case |
| `lead` rename (orchestrator) | `ch` -> `lead` | 804 LOC | 2 | lines wrap |

**Claims table.**

| Claim | Agent | My check | Verdict |
|---|---|---|---|
| cand: battery treeDiff 0, every check = cl17 | Claude | check18.sh r12c18 | confirmed |
| cand: invalid 51, worse 18, levWorse 11; cl17 53, 20, 13 | Claude | the same run, three-way | confirmed |
| cand: no-repair 0 | Claude | norepair.sh r12c18 | confirmed |
| cand: det only `aabb` | Claude | det11.sh r12c18 | confirmed |
| cand: stress and rungs = cl17 | Claude | stress.sh, rungs.sh | confirmed |
| cand: 46 families, costs = cl17 | Claude | sweep3.py r11c17e r12c18 | confirmed |
| r12c18e: trees = cand | orchestrator | battery BASE=r12c18, treeDiff 0 | confirmed |
| diverse ladder ~49% of family 43 | Claude | a copy with `if (found == null)`: 5,325-5,389 against 10,314-10,343 ms at 4,096, same costs | confirmed (about 48%) |
| cl17 section: KD/KI labels swapped | Claude | final key `a.missing - b.missing`: treeDiff 85; `b.missing - a.missing`: 0.9899/84.3, treeDiff 8 | confirmed; corrected below |
| cl17 section: `_Front.add` keeps whichever arrives first | Claude | read `_Front.add`: only `_first` passes keepFirst; elsewhere a later equal reading replaces the stored one | confirmed; the order of production decides, not a first-wins rule |
| round 11 knockouts G1, F1b, V1, T, S3 reproduce | Claude | not rerun | unsupported by my check |
| group C cause (`_usedSeed`) | Claude | the seat marks it conjectured | conjectured |
| cand_free old-fuzzer losses | Claude | not rerun | unsupported by my check |

**Corrections to the cl17 section.** Its determinism paragraph has the two
tie-break labels swapped: preferring insertion changes 8 battery trees (the
stray-`}` cases get an inserted `{`), and preferring fewer insertions changes
85. The same paragraph says `_Front.add` keeps whichever reading arrives first;
only ordered choice keeps the first, and elsewhere the later equal reading
replaces it, so the tie is decided by the order the rungs produce the readings.

**Open items.**
- Size: 796 normalized lines against cdx1's 616. No deletion inside every target was found
  this round.
- Invalid groups B, C and D; the examined-extent cut is the right cut for B but
  costs 56 lines as built.
- Family 43: a flag that fires only when a bad reading could outrank the found
  answer under `_compare` (not built).
- `aabb`, an exact tie.
- `lastCost` holds edits, not the rank cost (above it exactly when owed > 1).

**Process lessons.**
- A rename can move LOC either way under the formatter: `ch` -> `lead` added 6
  normalized lines, `ch` -> `s` saved 2. `bench.sh loc` formats with
  `--language-version=3.0` (the short style); the installed `dart format` without
  it uses the tall style and restyles the whole file, so only `bench.sh loc`
  measures size.
- `pgrep -f` with a pattern from the loop's own command line matches the loop
  itself, so a wait loop built on it never ends. Wait on output files or the
  job's own completion.
