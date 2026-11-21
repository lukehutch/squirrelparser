<!-- Part of LESSONS_LEARNED.md, section: 3. The critical lessons -->
[Back to the index](../LESSONS_LEARNED.md)

### sk9y6 - round 42: more candidates, fixes compared by what follows them, inserted class characters marked; battery 0.9647 -> 0.9802, fuzzer worse cases 361 -> 86 against sk8z3 (2026-10-08)

Changes from sk8z3 to sk9y6 (net, read from the two files):

- A fix at element i of a sequence also stops the repetition at element
  i-1 at q, so a repetition that read past an error can end where the
  next element should start.
- New candidates. (1) Each later arm of a choice that read to the
  frontier, if it is a sequence whose first element fails there without
  reading; its fixes lose ties to other fixes. (2) Where a repetition
  that is not the last element of a sequence reads to the frontier
  without nesting (a token), the next element at the start of each of
  its iterations. Characters of a layout rule (named with `~`) are not
  tokens; this fixed battery case 1297.
- Each candidate is offered every later element that matches at q + s,
  not only the first.
- The window: later offers delete no more than the first gaining offer
  cost (sk8z3 added what it gained).
- In the top-level repair, an offer replaces the kept one only if it and
  the fixes that follow it read as far as the kept one and its following
  fixes, for fewer edits (`_wins`). Offers that cost as much as deleting
  the rest of the input are not measured, except where the root failed.
- Keeping an offer that reads to the end ends the search only if its
  price is just the deleted characters.
- In the tree each inserted terminal, a character class included, is a
  terminal holding a zero-length syntax error, and each fix counts as at
  least 1 edit. auditBad (battery cases where the tree's edit count
  differs from the reported cost) falls 773 -> 419.

Refuted or dropped this round:

- sk9x5: when two lines of fixes read equally far before the end, keep
  fixing both until they parse the whole input. Battery 0.9810 (6
  better, 4 worse), but every comparison runs to the end of the input:
  12 errors 4.7 -> 24.9 s, 32 errors 8.5 -> 93.8 s. A single extra fix
  at the first tie (sk9y3) was still 1.5x slower, 0.9808, and the
  32-error rung cost 35 instead of 34. Dropped.
- sk9w9's cap `input.length - max(end, 0) - 1`: where the root failed it
  forbade offers that cost the whole input, so the fuzzer found whole-
  input deletions (cost 1000+) where sk9w8 costs 1-3, for example `R0 <-
  (R0*? "aaaca")` on `ac`. Reverted to `input.length - end - 1`.
- sk9x1 (record `_opens` outside the frontier test): 0.9789, 7 worse.
- sk9x7 (wrap a rule's insertion in a match of the rule): 0.9678, 281
  better, 283 worse.
- sk9y2 (the arm a choice took is also a candidate for its opener):
  no battery change.

The elegance review (Opus agent) found that the cap compared raw prices
while the tree counts each fix as at least 1 edit, so a fix of raw price
0 could tie the deletion it should beat. Fixed (`_cost(p) > cap`): on the
fuzzer against sk9y5, worse 0 vs 2, invalid 102 vs 104. Its other
behavior proposals were each fuzzed against sk9y5 and not adopted: a
forced offer may not end the search (worse 1 vs 0), a give-back must
also read as far as the kept offer (worse 4 vs 3), `_forced` kept per
parse (no change), `_follow` reusing `_kept` (no change). The comment
on give-backs was changed to say what the code does. Five no-op
simplifications were taken (treeDiff 0 on the battery).

**Results (confirmed).** Rungs are costs (1000/k/1); ms for the 64/1 rung.

| Engine | Battery | ms | 6/1 | 8/1 | 12/1 | 16/1 | 32/1 | 64/1 | 64/1 ms | Invalid | Worse vs sk8z3 | LOC |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| sk8z3 | 0.9647/69.9 | 1498 | 6 | 8 | 16 | 19 | 38 | 70 | 12134 | 113 | - | 525 |
| sk9y4 | 0.9802/76.4 | 4316 | 6 | 8 | 16 | 19 | 34 | 68 | 14072 | 104 | 88 vs 361 | 611 |
| sk9y6 | 0.9802/76.4 | 4196 | 6 | 8 | 16 | 19 | 34 | 68 | 14168 | 102 | 86 vs 361 | 608 |

- Battery against u28's costs: sk9y6 costs more in 31 cases, sk8z3 in
  221; neither costs less in any.
- Fuzzer (8 seeds x 400): worse 86 vs 361, levWorse 61 vs 191, invalid
  102 vs 113, timeouts 0.
- Gates as sk8z3: accept cx2/b1/b2 true, freespan 3 3 4 4 1, recommit
  16/16, conformance 0 1 1 0 1 1, cleanTreeDiff 0.
- `deep.sh`: `x (ax)*n b` costs 1 (sk8z3 2); x(ab)*1600 5.1 s. Depth
  800 still overflows the stack.
- Slower: battery 1.5 -> 4.2 s, 64/1 12.1 -> 14.2 s; 12/1 4.2 s.
- Open: insert-a-value against delete-an-extra-comma ties (`[1,,2`); a
  missing `[` far from where the parse fails (battery 158); case 549;
  greedy-repetition invalid trees; left recursion; stack depth.

LOC: sk8z3 525 -> sk9y6 608 (+83, +15.8%).
