<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### The machine, sixth look — c18's falsification round (2026-09-05)

The experiment and reproduction commands are in
`dart/experiments/recovery/_C18_FINDINGS.md`. Starting HEAD: `1059d8e`.
The frozen library and existing engines were not edited. c18 is a useful
candidate, not the requested minimal addition: it still has its own plain
parser and c17's approximate two-unit windows.

44. **A local winner needs a replacement law, not just a comparator.**
    The earlier warning in §6d remains live in c14/c17. With
    `Top <- A 'd' 'e' 'Y'; A <- P / Q; P <- 'a' . .;`
    `Q <- 'u' 'v' . . 'b' 'c';`, input `xabcdY` costs 3 via Q,
    although P gives a two-edit reading. P's temporary absorption charge
    loses locally and disappears after the shared suffix supplies evidence.
    `_dominance18.dart` prints the original and forced-P trees. c18 applies
    absorption only to complete comparisons and returns cost 2. This fixes
    that eviction, not every possible continuation-dependent comparison.

45. **A free recovery reading is not proof of a PEG predicate.**
    `S <- &('a'* 'a') 'b';` on `a` produces `falseAssertions=1` in
    c14/c17: non-greedy recovery can satisfy the assertion's body, but greedy
    PEG cannot. `_pred18.dart` checks each returned assertion with the real
    library matcher. c18 asks the ordinary PEG verdict and returns an
    error-only tree (`falseAssertions=0`). Empty-input fallback must also
    cost one zero-width error mark, not zero. These are correctness fixes,
    not oracle preferences.

46. **Admission width is not retained width.** `_beam18.dart 64 7` finds
    13 retained c16 origins for repetition 39, end 374, budget 3, with W=8:
    `[29,62,98,116,149,203,237,294,328,354,364,365,366]`. All precede
    the end. Replacing an admission-row member does not remove old readings
    from other memo cells. This refutes the retained-width premise of
    lesson 33, not by itself every possible linear bound. A separate
    no-beam c18 control is full-tree-and-cost identical to c17 on all
    13,241 raw battery cases; that is not equivalence on all inputs.

47. **Retaining incomparable bills buys accuracy, not yet compactness.**
    The indexed `_envelope18.dart` admits conservative numeric alternatives
    per end. Its absorption inequality uses `deleted + 2*evidence` because
    `absorbed > evidence` iff `span > deleted + 2*evidence`; 2 is algebra,
    not a tuning coefficient. Final-memo census: 669,957 readings in
    438,949 end buckets, maximum width 50. This is not a peak-heap count or
    a minimal Pareto set, and windows still constrain candidate discovery.

    | Engine | Weighted score / perfect | Normalized code lines | Paired damaged latency / c17 |
    |---|---|---:|---:|
    | c17 | 0.9900 / 86.0% | 1330 | 1.000 |
    | c18 | 0.9900 / 86.0% | 1194 | 0.785 |
    | envelope | 0.9902 / 86.2% | 1219 | 1.362 |

    Five interleaved rounds after warmup; full methodology in the findings.
    Raw scores: c18 0.9914 / 87.7%, envelope 0.9915 / 87.7%. Both have
    zero crashes, uncovered cases, or error-cost audit failures. Both pass
    acceptance, freespan `3 3 4 4 1`, recommit 16/16, conformance
    `0 1 1 0 2 3`, clean-tree equality and 2,728 additional grammar/input
    property checks. The current library suite has 284 passing tests.
    At 201,260 chars / four errors / seed 7, fresh-process c17/c18 are
    4854/3640 ms and 1,646,927,872/1,308,446,720 bytes peak process RSS.
    Envelope's 100,060-char seed-2 rung regresses to 14,949 ms; no general
    speed or worst-case complexity win is claimed for it.

48. **Laziness needs a demand rule; deleting mechanisms is not enough.**
    Freezing every successful plain subtree outside windows loses score
    (0.9880 / 85.0%). Replacing the ambiguous-missing penalty by rejection
    passes the old gates but loses `xb` under
    `S <- A 'x' 'b'; A <- 'a' / 'b';` (cost 3 instead of 1).
    Removing windows from the envelope fails freespan (`4 4 5 5 1`).
    Each is retained as a rejected control. The architectural next step
    is to keep the ordinary PEG verdict and attach a lazy recovery relation
    to existing memo machinery, sharing clean trees and repair backpointers.
    Predicate truth and other hard coherence conditions must be distinct
    from final preference; pruning needs continuation-compatible dominance.
    At the close of c18 this was a hypothesis; c19's implementation and
    measurements follow below.
