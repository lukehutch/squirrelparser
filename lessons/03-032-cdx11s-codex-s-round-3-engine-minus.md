<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### cdx11s — Codex's round-3 engine minus the four no-op parts: 837 → 802 LOC, 10% faster battery, one more valid repair (2026-09-23)

**Codex round 3 finished** (`cx3f`, 829 LOC, built on cdx11l). Beyond
`total_stage` it adds: First also consults the plain earlier-arm result (a
bound-pruned repair frontier does not show that an earlier PEG arm failed);
`_usedSeed` reads the relation cells' `recursive`/`usedSeed` flags instead of
a separate left-corner walk; a substitution carries its literal in `lead`, and
`_tail` checks whether the next edit completes a direct earlier Char/Str arm
of a frozen First; `_Way.change` replaces the copy constructors; the explicit
preferred-bit key in `_compare` is deleted (inert on battery and fuzzer).
Codex also refuted, by measurement: `Mismatch.len` as the examined span
(`'a' ('b' 'c')` on `abd`: len 1, the reviving edit is at 2; `&"ab"` on `ac`:
len 0, edit at 1); unordered choice (seed-1 invalid 6 → 18); one longest LR
extent per budget (0.9802, 213 trees differ); the regular bound alone
(1000/32/1 3.7 → 101 s); a productive-nullable rule (a new invalid on `aca`).

**cdx11s (untracked `_cdx11s.dart`) is cx3f minus the cdx11o deletions:** no
`incomplete` flag or fallback (F), no `_oneShape` in the Ref filter (H; the
function stays, a Seq slot still uses it), no absorption term in `charge`
and no `complete` flag in `_compare` (J).

Measured (orchestrator's kit, confirmed): battery 0.9900/84.3, treeDiff 0 and
costDiff 0 against cdx11r; alternating runs 1,594/1,575 ms against cdx11r's
1,757/1,777 (−10%). Accept t/t/t, freespan 3 3 4 4 1, recommit 16/16,
conformance 0 1 1 0 2 3, cleanTreeDiff 0, props 2728/0, window P at every n,
pred 0. Fuzzer seeds 1–4 invalid 6/7/6/17, the same as cdx11r; worse 0/0/1/0
against cdx11r's 0/0/0/1, and in both such cases both answers are invalid.
Rungs, paired and alternating (ms, cdx11s / cdx11r): 1000/1/1 327–329/321;
8/1 615–637/646; 16/1 1,798–1,864/1,859; 32/1 3,318–3,353/3,404; 64/1
3,708–3,721/3,844; 128/1 8,023–8,531/8,271; 4000/4/2 1,194–1,275/1,224;
8000/4/7 2,341–2,346/2,388; 8000/32/7 13,520–13,853/13,786. Codex's probes:
`S <- A 'b'; A <- "ab" / 'a'` on `ac` costs 2 (valid, `abb`, the only word;
cdx11r gives an invalid cost-1 tree); `R <- 'c'*+ 'b'` on `ccca` costs 1
(cdx11l 4); `S <- 'b'` on `a` still costs 2 (substitution exists only inside
a Seq slot). LOC 837 → 802 normalized (−35, −4.2%).

**Substitution at every Char/Str terminal is a trade-off, not a win
(scratch `subT`, `subT2`, 2026-09-23).** `subT` lets a failed Char/Str
terminal replace the next input character (`_Way.skip(pos, pos + 1, text)`)
beside its insertion; `subT2` also deletes the Seq-slot substitution block and
`_resumes`, which the terminal rule subsumes. Measured for `subT2` against
cdx11s: LOC 802 → 793 normalized (−9, −1.1%); all checks pass (accept t/t/t,
freespan 3 3 4 4 1, recommit 16/16, conformance 0 1 1 0 2 3, props 2728/0,
window P, pred 0); `S <- 'b'` on `a` costs 1 instead of 2; fuzzer seeds 1–4
worse 0/0/0/0 against cdx11s's 7/5/9/6 (cdx11s pays a higher cost on 27
cases), invalid 6/7/4/17 against 6/7/6/17. Against that: battery 0.9900/84.2
(two equal-cost cases lost, 618 `{"z":}3}` and 636 `[4,5,]6`: subT2 opens an
empty nested array and replaces the digit instead of moving the bracket), and
many-error rungs 16–21% slower, two paired runs each (1000/32/1 3,953–3,993
vs 3,360–3,431 ms; 1000/128/1 9,522–9,927 vs 8,071–8,224; 8000/32/7
14,742–15,086 vs 12,243–12,529); battery time is the same. Three tie-breaks
meant to recover 618 and 636 were refuted: forbidding substitution of a
character that a non-inverted CharSet reads (0.9897/84.0, 20 costs worse; the
battery contains a mistyped bracket that is a digit, `{"k":5{"a":1}...`);
counting only CharSet characters as evidence (0.9853/80.7, also 0.9855 on
cdx11s itself); a substitution as evidence −1 (0.9898/84.0, loses `[1\2]` →
`[1,2]` to deleting the `\`, and twice as slow). cdx11s stays the engine.
