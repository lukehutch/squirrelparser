<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### cdx11o — five deletions from cdx11l keep every tree class; two others are the speed (2026-09-23)

**Each part of cdx11l was removed alone and measured** (battery against
cdx11l, all checks, fuzzer seeds 1–4, then the rungs 8000/4/7 and 1000/32/1):

| Removed | treeDiff/costDiff | Score/perfect | Checks | 8000/4/7, 1000/32/1 ms |
|---|---|---|---|---|
| (A) hand-copied `_Way` in the scan-evidence reset → `change(ev: 0)` | 0/0 | 0.9900/84.3 | pass | — |
| (F) `incomplete` flag, its fallback and price loop at the root | 1/0 | 0.9900/84.3 | pass | 2,433 / 3,564 |
| (H) `_oneShape` term in the Ref filter | 0/0 | 0.9900/84.3 | pass | 2,483 / 3,646 |
| (J) the absorption term in `charge` (`charge = cost + fee`) | 0/0 | 0.9900/84.3 | pass | 2,301 / 3,553 |
| (B) the ordering penalty | 58/0 | 0.9902/84.7 | **fails accept b2 (D8)** | — |
| (D) stop exposure (`exposed`, `kept`, `floor`) | 4/0 | 0.9900/84.3 | pass, invalid 11/11/10/18 | 2,551 / **10,495** |
| (I) sealed occurrence sharing | 4/0 | 0.9900/84.3 | pass, invalid 11/11/10/18 | **46,341 / 15,743** |
| (E) the Str split | 131/88 | 0.9800/80.1 | — | — |
| (G1) the `last` key | 32/0 | 0.9896/83.9 | — | — |
| (G2) the `owed` key | 220/220 | 0.9870/81.6 | — | — |

cdx11l itself: 2,380 / 3,519 ms. A, F, H and J are removable at no measured
cost. B, E, G1 and G2 change judgments (B breaks D8's `,3true` case). D and I
remove one invalid tree per seed but are what keeps long inputs fast: without
sealed sharing 8000/4/7 takes 19x longer and 4.4 GB. cdx11n (all of A, D, F,
H, I, J removed, 780 LOC) confirmed this: 8000/4/7 32.6 s, 1000/128/1 40.9 s,
8000/32/7 47.3 s against 2.3/8.6/13.7 s.

**The engine (`cdx11o`, untracked `_cdx11o.dart`) is cdx11l minus A, F, H, J.**
Measured (orchestrator's kit, confirmed): battery 0.9900/84.3, 1,685 ms,
treeDiff 1, costDiff 0 against cdx11l; accept t/t/t, freespan 3 3 4 4 1,
recommit 16/16, conformance 0 1 1 0 2 3, cleanTreeDiff 0, props 2728/0,
window P at every n, pred 0 false assertions; fuzzer invalid 12/11/11/19,
worse 0 on every seed (same as cdx11l). LOC 839 → 804 raw, 803 normalized
(−35, −4.2%). Rungs (ms): 1000/1/1 309; 8/1 574; 16/1 1,640; 32/1 3,531;
64/1 3,655; 128/1 8,471; 4000/4/2 1,169; 8000/4/7 2,339; 8000/32/7 11,807.
Every rung finishes, at cdx11l's times.

**Refuted: cdx11m, "an unconditional clean reading is the plain one".**
Dropping every clean way whose end differs from the plain parse's end raises
173 costs. Clean left-recursive growth stages are prefixes that later repairs
build on, and they carry no cut guard. Gemini's round-3 `_view` patch is the
same rule (it reports seed-1 invalid 12 → 6 but did not measure costs).
Codex's round-3 variant demotes such readings instead of deleting them and
leaves the battery unchanged; it is under test.
