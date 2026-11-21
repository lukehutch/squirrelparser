<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### cl27 - cross-review round 23 on cl26: the text inserted after a stop is tested as one string, 889 -> 898 LOC (2026-09-26)

Round 23 ran a Claude subagent (Opus 5.5, high effort) on BRIEF23 (Q1 owed
text split across joins; Q2 kind D; Q3 the second front entry; Q4 size and
`owing`; Q5 review of round 22). Codex and Gemini had no quota. The engine is
untracked `_cl27.dart` (kit name r24p1): the seat's o9 with the lead
concatenated only when the joined reading has one, and a stale comment fixed
by the orchestrator. The seat's `cand` was o20 (977 lines).

**What cl27 changes (confirmed from the diff against cl26).**
- `lead` was what the first edit inserts, to the end of its literal. For an
  insertion it now runs on through every literal the reading inserts after
  it, up to the first character read, deleted or of a class. Whether it is
  still growing is derived, not stored: `open` holds when `lead != null`,
  `end == first` and `missing + owed == lead.length` (each inserted literal
  character adds 1 to both sides; a read, a deletion or a class insertion
  breaks one of the three for good; the seat's proof, read and accepted).
- In `then`, a reading joined at a stop with an open lead `t` adds the guard
  `(stop, null, (s) => opens(t + s), null)`, so the next join tests the text
  inserted so far together with what follows.
- `owing` (19 lines, a walk over the reading's pieces) is deleted; the
  owed-only case is the case where the lead runs to the end of input.
- The diverse key holds the lead up to `_wide`, the length of the grammar's
  longest literal. The whole lead does not terminate (seat's o11: battery
  case `stmt 'x="ab'` killed after 60 s, 386 MB): a string rule at the end of
  input owes `\n`, `\n\n`, ... each at cost 1 with a different lead.

**Measured (confirmed), kit r9/verify.**
- Three cases above: o9, o20 and cl27 all answer `abacc` (owed, cost 1,
  valid); cl26 invalid on all three.
- `check27.sh`, identical for o9, o20 and cl27 apart from wall time:
  battery 0.9900/84.5, treeDiff 0 and costDiff 0 against cl26; accept
  t/t/t, freespan 3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 3, props
  2728/0, window and pred as cl26. `_samedw` (three-way with cdx1) invalid
  7/5/5/4/7/6/4/10 = 48 against cl26's 49, worse 11 against 12, the one tree
  change (seed 7) valid at 1 edit where cl26 was invalid; `_same` and
  `_samew` invalid equal per seed, worse 2 -> 0 (seeds 4 and 7, both cheaper
  and valid).
- no-repair 0; `det11.sh`: only `aabb`; `deep2.sh` and `multi.sh`: every
  cost equal to cl26 on every shape; `idk.sh` identical.
- AOT stress (`aot.sh`, 11 runs, medians, cl26 / o9 / cl27): errors 4096
  49/49/50 ms, lr 8192 131/133/131; the other rows equal.
- Rungs (one run): 1000/128/1 5,271 -> 5,566 ms, 8000/32/7 5,982 -> 6,458,
  the others within 2%, all costs equal.
- Families (`famaot.py`, AOT n=16384, medians of 5, cl26 / o9 / cl27 / o20,
  all costs equal): 4 397/423/408/416; 6 1,049/1,100/1,081/1,150; 10
  1,240/1,297/1,314/1,338; 11 522/549/547/560; 16 1,920/2,040/1,988/1,783; 18
  2,480/2,483/2,470/2,229. So o9 and cl27 are 0-6% slower than cl26, and o20
  is 8-11% faster on 16 and 18 and 4-9% slower on 4-11.
- Skipping the empty concatenation (cl27 against o9) changes no time beyond
  noise, so the seat's guess that the concatenation is the cost is not
  supported. The cause of the 0-6% is not found.

**Elegance review of cl27 (confirmed with `_wone.dart`).**
- The cut at `_wide` loses answers where a stop's body spans more than its
  longest literal. `S <- ("ab" "cd")* A; A <- 'a' 'b' 'c' B; B <- 'd' / 'e'
  'e';` on `abcd`: cl26 and cl27 both invalid at cost 2 (delete `a`, the
  repetition empty, `A` inserts `a`); the owed `abcee` and the owed `abcd`
  share the key prefix `ab`, and `abcd` wins inside `A`'s cell before the
  guard at `S` rejects it. With the literal `"abcd"` (`_wide` 4), or with no
  rule `A`, cl27 answers `abcdabcee` validly. The seat proved no finite key
  is exact for a non-regular body.
- That tree deletes `a` and inserts `a` at the same place: the repaired
  string equals the input. Since PEG's tree of a string is unique, a reading
  whose deletion and adjacent insertion of the same character cancel is
  either invalid or has the repaired string of a reading with 2 fewer edits
  (proved). No rule forbids it.

**Negative results (the seat's, not rerun).**
- A deletion test at every stop (o13) fixes 5 `_samedw` and 11 `_samew`
  invalid trees but adds 2 and 6 and raises three-way worse 12 -> 32; every
  restriction that removes the new invalid trees also removes the fixes, but
  o39 (acyclic bodies only) fixes `ccbbbc` and adds `bba` on `_samew`.
- Dropping `~pos` everywhere (o12) makes `bbc` invalid and family 2 27-30%
  slower; keeping it only for `+` bodies (o20) needs the restricted kind-D
  test to keep `bbc` valid.
- `owing` ran at 3.9% of joins, 3.2 steps on average, 44 at most.
- The `errors 4096` gap of o20 (57 against 49 ms) is not explained; o33 and
  o34 do the same work at 56 and 50 ms.

**Candidates.**

| Candidate | Change | Result | Score | Reasoning |
|---|---|---|---|---|
| r24p1 = cl27 | o9, lead concatenated only when the joined reading has one, stale comment fixed | 898 LOC; trees = o9 everywhere | 8 | the Q1 fix for +9 lines, one mechanism fewer |
| o9 (Claude) | lead grows across joins, guard carried, `owing` deleted, key cut at `_wide` | 898 LOC; same trees as cl27 | 7 | stale comment |
| o20 = cand (Claude) | o9 + `~pos` only for `+` bodies + kind-D test for acyclic Optional bodies | 977 LOC; same trees as o9; mixed family times | 5 | 79 lines for a mixed speed change |
| cl26 unchanged | none | 889 LOC; three cases invalid | 5 | more invalid trees |
| o39 (Claude) | o20 with the kind-D test on every acyclic body | `ccbbbc` fixed, `bba` new (seat's figures) | 3 | loses a case |
| o13, o17, o19 (Claude) | kind-D tests of other scopes | new invalid trees or slower (seat's figures) | 2-4 | lose cases |
| o12 (Claude) | o9 without `~pos` | `bbc` invalid (seat's figure) | 2 | loses a case |
| o1, o3, o11 (Claude) | whole lead in the key | does not finish (seat's figure) | 0 | fails termination |

**Claims table.**

| Claim | Agent | My check | Verdict |
|---|---|---|---|
| o9 and o20 make the three cases valid at cost 1 | Claude | `_wone.dart` | confirmed |
| o9: battery and every check = cl26; `_samedw` 49 -> 48 | Claude | check27.sh r23o9 | confirmed |
| o20: same trees and fuzzer counts as o9 | Claude | check27.sh r23o20 | confirmed |
| o9: errors 4096 = cl26 (49) | Claude | aot.sh | confirmed |
| o9 slower than cl26 on many families by 3-13% | Claude | famaot.py, 11 families | direction confirmed, size smaller (0-6%) |
| o20 5-12% faster on the five families | Claude | famaot.py on 16 and 18 | confirmed (8-11%) |
| the per-join concatenation is the cost | Claude | cl27 = o9 without it | not supported |
| the whole lead in the key does not finish | Claude | not rerun | plausible (argument read) |
| no finite key is exact for a non-regular body | Claude | argument read | plausible |
| j1 0.9699/75.8, j17 `bbc` (round 22 claims) | Claude | not rerun | unsupported by my check |

**Open items.**
- The `_wide` cut (the `("ab" "cd")*` case above).
- A deletion next to an insertion of the same character (proved dominated or
  invalid), and kind D in general (`cbbb`).
- The five families (cl24's times) and the 0-6% cl27 costs over cl26.
- The quadratic term with two or more errors in the four shapes.
- Size: 898 against cl20's 757.
