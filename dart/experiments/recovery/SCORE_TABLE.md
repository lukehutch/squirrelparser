# The full score table

## The result

**`m143.dart` is the engine.** It is standalone (`own` — carries its own parser
and memo table), acceptance-compliant, sound (costs nothing at 0 that the frozen
parser rejects), cost-minimal, and it beats **all three** of m78's targets at
once — quality, latency and size.

|                | m143 | m132 (the previous standing engine) | m78 (the engine both replace) |
|----------------|------:|------:|------:|
| AST-diff       | **0.9693** | 0.9648 | 0.9444 |
| perfect%       | **72.1** | 69.2 | 68.4 |
| LOC normalised | 629 | **612** | 1,326 |
| ms             | **1,171** | 1,168 | 2,171 |
| acceptance     | ok | ok | ok |
| conformance    | `.` | `.` | `.` |
| free-span      | PASS | PASS | — |

Against m78: quality +0.0249, latency **1.85x faster**, size **2.11x smaller**.
Against m132: quality +0.0045, perfect% +2.9, latency unchanged, size +17 lines.

**m143 = m132 + I81, and it does not trade.** Every category is identical to
m132 except `truncate`, which goes 0.890 → 0.919 — the heaviest weight (3.0) and
previously the weakest column. There is no category it makes worse.

The +34 lines are the one target not improved on, and they are stated here
rather than buried. They buy I76's positional guard, and §"The collapse that
does not close" below records the four separate attempts to delete it and get
the lines back — all four lose more score than the lines are worth.

**m134 scored higher and is withdrawn.** m134 = m132 + I77, and it reads 0.9668
on the battery. It is not the engine, because I77 buys that 0.0020 by *deleting
real input that already matched* — see §"Why I77 is withdrawn" below and
`_freespan.dart`, the control that names it. The battery cannot see this: every
case in it is a mutant that genuinely needs repair, so it never presents a span
that is already fine. m132 is also the faster of the two (1,166 vs 1,237 ms on
one clock) and the same size, so withdrawing I77 costs battery score and nothing
else.

**Clocks.** The `ms` column throughout is one clock: m121 read 4,711 in the
original pass and 4,680 re-measured alongside m134, 0.7% apart, so figures from
the two passes are comparable. m78, m121, m126, m132 and m134 above are medians
of back-to-back alternating rounds, not single passes.

**Do not read the #1 row of the ranking as the winner.** The ranking is sorted
by battery score alone, and the five rows above m132 are all disqualified — the
top four by I77 (they delete real input; `_freespan.dart`), and m77 by `arch`
(`m77.dart:1141-1143` builds a repaired input string and runs a second `Parser`
over it, which the brief bans in four separate places). §"Why each row above
m132 is out" lists every one with its reason. Read the `arch` column, and the
free-span result, before the score column.

## What changed since m121: I73–I78

| engine | change | AST-diff | perfect% | ms | LOC | free-span |
|---|---|--:|--:|--:|--:|:-:|
| m121 | (previous standing engine) | 0.9573 | 67.0 | 4,680 | 578 | PASS |
| m124–m126 | I73/I74/I75 — residual-budget memo families rounded up to the deepening ladder | 0.9573 | 67.2 | 2,594 | 602 | PASS |
| m127 | **I76** — I43's evidence test asked at the ENDING, not at the alternative | 0.9629 | 69.1 | 1,192 | 611 | PASS |
| **m132** | **+ I78** (`net == 0` refused) | **0.9648** | 69.2 | **1,166** | 612 | **PASS** |
| m129 | I76 + I77 as `cost + got - net` | 0.9649 | 69.7 | 1,271 | 612 | FAIL |
| m130 | I76 + I77 as `cost - net` | 0.9656 | 69.3 | 1,262 | 612 | FAIL |
| m133 | I76 + I77(`c+g-n`) + I78 | 0.9663 | 69.7 | 1,247 | 612 | FAIL |
| m134 | I76 + I77(`c-n`) + I78 — *withdrawn* | 0.9668 | 69.4 | 1,237 | 612 | FAIL |

I76 is worth +0.0056 and 2.3x the speed for 9 lines; I78 is worth +0.0019 for
**one** line, and it is the line that lifts `truncate` 0.878 → 0.890. Everything
above m132 in the score column is an I77 engine, and every I77 engine fails the
free-span control.

## What changed since m132: I79–I81

The user asked for a two-mode parser — top-down PEG in O(n), then on failure a
bottom-up Earley/SPPF chart expanded by a DP wavefront from the failure point.
That was built (m141) and it loses. What it *revealed* is I81, which is a clean
win, and which is a top-down change.

| engine | chart | I81 | AST-diff | perfect% | ms | LOC | free-span |
|---|:-:|:-:|--:|--:|--:|--:|:-:|
| m132 | – | – | 0.9648 | 69.2 | 1,168 | 612 | PASS |
| m141 | **yes** (I79) | – | 0.9641 | 67.8 | **21,319** | 674 | PASS |
| m142 | – | I80, unrestricted | 0.9656 | 67.5 | 1,147 | 617 | PASS |
| **m143** | – | **yes (I81)** | **0.9693** | **72.1** | 1,171 | 628 | **PASS** |
| m145 | **yes** | **yes** | 0.9668 | 70.6 | 21,274 | 690 | PASS |

m145 exists to separate the chart from I81, which the first three rows confound.
**Holding I81 constant, the chart costs 0.0025 and 1.5 perfect points** — so its
extra reach is not unprofitable at 18x, it is negative at *zero* latency.

**I79 — the chart costs 17.8x and buys nothing.** m141 is m132 with the memo
replaced by a genuine chart: every clause node × every position, relaxed to a
fixpoint right-to-left, per budget. It is the requested architecture, built
faithfully, and it is 17.8x slower for -0.0007 score. The reason is measured,
not guessed: m132 already touches **13.9 chart columns at p50** (55.1 at p90) out
of |G| = 105 clause nodes, and only **119 of 3,675 = 3.2%** of cells are repair
cells. A chart fills 100% of them. Two earlier independent measurements agree —
the eager chart in `lib/src/recovery/semiring_recovery.dart` measured **11x**,
and m51's bottom-up agenda measured **14x**. Sparse top-down deepening is not a
weaker form of chart parsing; on this workload it is the optimisation.

**And the chart is not merely slower — it reaches worse readings.** I predicted
it would find nothing the search misses, from `calls/cell` = 1.00.
`_chartcost.dart` refutes that over 1792 cases: **1782 identical, chart cheaper
on 9, search cheaper on 1.** It does reach readings the search misses, and it is
not a superset either. What those readings are, on `[1,[2,`:

```
expect  Value (Array (Value (Number ()) Value (Array (Value (Number ())))))
m143    cost=3  err= 0   [1,[2,<]><]>     closes both brackets
m145    cost=2  err=19   <">[1,[2,<">     "the whole document is a string"
```

Two invented quotes beat three invented brackets, so the globally cost-minimal
repair of a truncated nested array is to **re-read the entire document as a
damaged JSON string**. Five of the nine are this pattern. The top-down search's
parochialism is the feature: it honours the structure the undamaged prefix
already committed to, and never considers discarding it.

The brief asks recovery to anticipate probable human intent in prioritising
insertions, deletions and mutations. This is the sharpest statement of that the
project has produced: **cost-minimality is not human intent.**

**I82 — and the reason is structural, not a matter of taste.** `_recommit.dart`
is the gate that catches this class, added because acceptance, conformance and
free-span are all blind to it (m145 passes all three). It asks only that the
repaired tree still take the arm of the grammar's own top-level choice that the
input's first character committed to. Bisected across the engine line:

| engine | insights | `_recommit` | cost | reading |
|---|---|:-:|--:|---|
| m126 | pre-I76 | PASS | 3 | array |
| m127 | I76 | **FAIL** | **2** | **string** |
| m129 | I76 + I77 | **FAIL** | 2 | string |
| m131 | I77 without I76 | PASS | – | (I76 absent — says nothing about I77) |
| m132 | I76 + **I78** | PASS | 3 | array |
| m143 | + I81 | PASS | 3 | array, err 0 |
| m141 | I78 + **chart** | **FAIL** | **2** | **string** |
| m145 | I78 + I81 + **chart** | **FAIL** | **2** | **string** |

Two results. **I77 does not do what it was named for** — its header says "a
String that swallows structure loses to the reading that explains it", and m129
carries it and produces the String anyway. I78 is what closes it. I77 was
withdrawn on score; this is the harder reason.

**And m141/m145 carry I78 at the same two sites as m132 and fail regardless.**
I78 admits a repair-opened alternative only where the input witnesses it — a
condition on the **descent**, on which alternative may be *opened*. A chart
materializes cells with no descent to test. That m132 reports cost **3** while
the chart reports **2**, with cost the first key of `_better`, shows I78 does not
demote the String reading in the top-down search — it removes it from the space,
and the chart re-admits it.

So: **a PEG-fidelity guard phrased over the derivation path is unenforceable in a
bottom-up half.** I72, I76 and I78 are all such guards. The two modes cannot
share a guard set by construction, and the 9 cases where the chart is cheaper are
not discoveries but I78 violations that had no guard surface to act on. Intent
lives in the path, not the cell: two invented quotes beat three invented brackets
by any cell-local measure, and what makes the brackets right is a commitment made
at character one.

Both proposed ways to bound the chart were also refuted by measurement:
repair sites are **100% at-or-before the frontier and 0% after** it (median 13
characters left of it, p90 37), so a forward wavefront from the failure point
searches the wrong direction; and a "healthy suffix" anchor exists in only
**167 of 598** cases and brackets every site in just 49.1% of those.

**I80/I81 — the one real signal the chart produced.** m141 invented 27% fewer
zero-width AST nodes than m132, because a right-to-left cell knows what lies to
its right before it commits. That is a local defect, and it is fixable top-down.
`_emptyprobe.dart` confirms the frozen parser returns `SyntaxError`, not `Match`,
for `Value`, `Number`, `Integer`, `Member` and `Object` on empty input — so a
zero-width `Number` is not a grammar artifact, it is invention, and the brief
bans inventing terminals of a class that are not there.

I80 dropped every node covering zero characters that asserts none. It *lost*:
0.9656 but perfect% 69.2 → 67.5, with `literal-damage` 0.970 → 0.943 and
`multi-damage` 0.946 → 0.933. I81 is I80 restricted to `pos >= input.length`,
and it costs nothing anywhere.

The restriction is the whole insight, and it is not a tuning parameter:

- **Past the end of the input the slot never existed.** The human never wrote
  it; there is no evidence to the right that the node could ever have covered.
  Naming it is invention.
- **Mid-input the slot exists and its evidence was destroyed.** `[1,x]` still
  has two `Number` slots even though one's characters are gone. Naming it is
  correct, and deleting it is the error — which is exactly what I80 did, and
  exactly what it paid for.

`_zerowidth.dart` confirms the rule fires only where intended:

| engine | cases hit | nodes | by category |
|---|--:|--:|---|
| m132 | 266/1792 | 378 | truncate 78, literal-damage 74, multi-damage 37, junk-insert 24 |
| m143 | 197/1792 | 266 | **truncate 0**, literal-damage 73, multi-damage 37, junk-insert 24 |

Truncate goes to zero; every other category is untouched to within one node.
The 266 that remain are not defects — they are the engine correctly naming a
slot whose evidence the damage destroyed.

Concretely, both of these go from `err=6` to `err=0`:

```
{"a":     m132  {"a":[--]<}>      Value(Object(Member(String() Value(Number()))))
          m143  {"a":<}>          Value(Object(Member(String())))
[1,[2,    m132  [1,[2,[--]<]><]>  ...Value(Array(Value(Number()) Value(Number())))
          m143  [1,[2,<]><]>      ...Value(Array(Value(Number())))
```

while `{"a":1,` — where the `Number` is real — is byte-identical under both.

Per-case rather than per-category, `_cmp.dart` reads **63 better, 5 worse**. All
five worse are `expr`, and on each one m143's tree is the *more* faithful: on
`(` it reproduces the expected `Factor ()` exactly where m132 invents a
`Factor (Expr ())`, and still scores no better, because the flat skeleton edit
distance aligns m132's stray `Expr` against an outer `Expr` wrapper both engines
fail to emit. That is an evaluator artifact, worth 0.0002 against I81's +0.0045,
and it is recorded rather than chased — see LESSONS_LEARNED occasion 58.

Controls, both measured rather than assumed:

| engine | control | AST-diff | what it establishes |
|---|---|--:|---|
| m128 | I76 in its strict form | 0.9601 | the weaker widening is worth 0.0028 |
| m131 | I77 **without** I76 | 0.9589 | I77 alone does not fix the deleted brace — I76 is what makes the comparison happen. m131 fails free-span too, so the defect is I77's own and not an interaction with I76 |

By category, m132 against m126: no category regresses, six improve, four flat.
The withdrawn m134 is shown alongside so the exact size of what I77 bought — and
what withdrawing it gives back — is on the record rather than asserted.

| category | m126 | **m132** | m134 (withdrawn) |
|---|--:|--:|--:|
| delim-delete | 0.945 | **0.977** | 0.976 |
| quote-insert | 0.967 | **0.980** | 0.985 |
| transpose | 0.956 | **0.966** | 0.972 |
| multi-damage | 0.938 | **0.946** | 0.948 |
| junk-insert | 0.981 | **0.983** | 0.985 |
| truncate | 0.891 | 0.890 | 0.895 |
| quote-delete | 0.997 | **0.999** | 0.999 |
| delim-insert | 0.979 | **0.979** | 0.980 |
| literal-damage | 0.970 | 0.970 | 0.970 |
| content-damage | 1.000 | 1.000 | 1.000 |

I77's 0.0020 is spread thin — six categories, the largest `transpose` +0.006 and
`quote-insert` +0.005, nothing concentrated. That is what a proxy artifact looks
like: no single repair class it fixes, just a slight systematic tilt toward the
more-constrained reading, which is the same tilt that deletes real input in
`_freespan.dart`.

## Why I77 is withdrawn

I77 made the first comparison key `cost - net` instead of raw `cost`, on the
argument that an unexplained character should cost what a deleted one costs. It
was declared a comparison key only, never a cost, so that `cost == 0` still
meant "pure PEG matched this" and round 0 stayed the frozen parser. Codex's
critique named the incoherence in that: `_put` discards ways at an ending by the
comparison key, but `_seq` computes the residual budget a suffix may spend from
raw `w.cost`. A way that wins its ending on the key but costs more in the only
currency the budget actually spends evicts a cheaper way that could still have
afforded the rest of the parse.

Verified on my own probe rather than taken (`_dom.dart`, then `_freespan.dart`):

    grammar  input   m127  m132   m129  m130  m133  m134
    g4       xxab       3     3      4     4     4     4
    g5       xxab       4     4      5     5     5     5

Codex's stronger sub-claim did **not** reproduce: it predicted the I77 engines
would return `-1` where a cost-first engine finds a repair, and on the case it
named all six engines return `-1`, so that is a property of the grammar and the
cap, not of I77.

**The extra cost is not paid for by a better tree — it buys a worse one.** The
witnesses say it outright. `W <- . . . .` matches any four characters, so on
`xxab` the span is already exactly right and needs no repair at all:

    m132  cost=3  C->W  witness "xxab<q><r><s>"
    m134  cost=4  C->E  witness  "xab<q><r><s>"   SKIP@1+1 "x"

m134 **deletes the real `x`** to force the more-constrained E reading. On `xyab`
it deletes the real `y`. Deleting a character does not explain more of the
input; it explains a larger *fraction* of a smaller input, and `net` measures
the fraction. So `net` is a good tie-breaker among ways that cost the same — it
is exactly m132's second key — and a bad objective the moment it may outrank
cost. Note what follows: restricted to within a cost class, `cost - net` reduces
to `net` descending, which is already m132's key. **I77 contributes nothing
except in the cases where it overrides cost**, so its 0.0020 and its defect are
one phenomenon measured two ways, and they cannot be separated.

**The battery cannot see this, by construction.** `astdiff.dart` keeps a mutant
only `if (m.isNotEmpty && !parses(m))` — every case in all 1824 is damage that
genuinely needs repair, so none of them presents a span that is already fine
beside a costlier reading of the same span. The +0.0020 is therefore not
evidence that I77 is right; it is evidence that the corpus is blind to where it
is wrong. `_freespan.dart` is that missing control, and it separates the two
families exactly:

| | free-span |
|---|:-:|
| m121, m126, m127, **m132** — raw `cost` is the first key | **PASS** |
| m129, m130, m133, m134, m135, m137, m138, m139, m140 — `cost - net` outranks it | FAIL 4/5 |

Every engine in the I79/collapse family is built from m134 or m135, so all of
them inherit I77 and all of them fail; that is measured above, not assumed. The
one probe every engine passes (`g6 zzz`, the same trap built from a repetition
rather than a choice) shows the trap needs a choice between a permissive and a
constrained reading of one span, which is why it is narrow enough to have been
missed and sharp enough to be decisive.

**A second finding, not acted on.** Codex also claimed I76 can select a branch
PEG would not. It reproduces, but it is not I76's doing and not clearly a
defect. On `Top <- A / B; A <- . 'a' 'b'; B <- 'x' 'a' 'b'` with input `ab`:

    m126  branch=A  cost=1  witness "a<a>b"     `.` eats the real `a`, invents a literal `a`
    m127+ branch=B  cost=1  witness "<x>ab"     invents the `x`, both real chars read precisely

Both cost 1 and both invent exactly one literal the grammar names, so both are
sanctioned fills. B wins on `net` (2 vs 1, because A spends its wildcard on a
real character), in cost-first m132 too — m126 avoided B only because I43
refused it outright. The objection is that pure PEG on B's own witness `xab`
picks **A**, so the repair is not a fixed point. But that is because `A <- . 'a'
'b'` *subsumes* `B`, making B unreachable in this grammar; in any grammar with a
dead alternative, no repair choosing it can ever be a fixed point, so a
fixed-point test would forbid B categorically and force the worse reading. Ruled
out rather than fixed: the check needs either a re-parse (D1 forbids) or a
static subsumption analysis, and it pays only on degenerate grammars.

Codex's fourth claim, a predicted `truncate`/`x="a` regression in the statement
corpus, does **not** reproduce — m126, m127, m132 and m134 are byte-identical on
`x="a`, `x="ab` and `p="q`. Its third, a subsuming single-list formulation, is
m135, refuted below on measurement.

## The collapse that does not close

I78 says invention may complete a shape the input witnesses but may not conjure
one nothing witnesses. If that is the whole rule, then I43's prohibition, I53's
exception, I76's guard and the two-list split that defers the comparison should
all be deletable, and the ~34 lines they cost come back. Four attempts:

| engine | form | AST-diff | ms | LOC | fails on |
|---|---|--:|--:|--:|---|
| m134 | I78 + I76 guard — *withdrawn, I77* | 0.9668 | 1,227 | 612 | free-span |
| m138 | I79 (`net > cost`) + guard | 0.9662 | 1,205 | 612 | truncate 0.891; free-span |
| **m132** | **I78 + I76 guard, no I77 — the engine** | **0.9648** | **1,166** | 612 | — |
| m135 | I78, single list, no guard | 0.9637 | 1,508 | **599** | literal-damage 0.946; free-span |
| m139 | I79 (`net >= cost` admitted), single list | 0.9634 | 1,418 | 599 | literal-damage 0.945; free-span |
| m137 | I79 (`net > cost`), single list | 0.9621 | 1,403 | 599 | literal-damage 0.945; free-span |
| m140 | I79 **ungated** (`cost > 0 && net <= cost`) | 0.9485 | 1,646 | 599 | truncate 0.820; free-span |

The collapse loses against m132 too, so withdrawing I77 does not rescue it: the
best single-list form reads 0.9637 against m132's 0.9648, is 342 ms slower, and
still fails free-span because every member of the family is built from m134 or
m135. The 13 lines it saves cost 0.0011 and 29% of the latency.

**Why it does not close.** Both witness tests are gated on `_Way.synth`, which
records only whether a way OPENS with a repair. The swallow that the guard
actually stops does not open with one. `_cmp.dart m134 m135 literal-damage`
isolates it — every regression is a value damaged or deleted where the grammar
expects one — and on `{"a":1,"bc":[2,33,rue],...}`:

    m134  cost=2  FILL@18 '"'  FILL@21 '"'   quote `rue` locally
    m135  cost=2  FILL@10 '\'  FILL@23 '\'   escape two real quotes, swallow the span
    m137  cost=2  SKIP@10+1 '"'  SKIP@23+1 '"'   delete them instead, same swallow

The m135 way opens on the real `"` at 7 and does its inventing *inside*, so
`synth` is false and the test never fires. I78's `net == 0` would not catch it
either: a JSON escape is `'\\' ["\\/bfnrt]`, a **constraining** set, so an
invented `\` promotes the real `"` after it out of the wide body class `[^"\\]`
into a precise one and that character then counts as explained — the fill buys
itself a witness. Un-gating the test (m140) rejects honest repairs instead and
costs 0.018.

So the guard is not redundant machinery around I78: it is the only one of the
two that is **positional**. It compares at each ending, which is the sole place
the swallow and the honest reading differ; an aggregate witness test over a
whole way cannot see a local swallow embedded in an otherwise-correct parse.

Why each row above m132 is out — every one of them, for a stated reason:

| engine | AST-diff | out because |
|---|--:|---|
| m134 | 0.9668 | I77 — deletes real input from a span that already matched (`_freespan.dart`) |
| m133 | 0.9663 | I77, same |
| m138 | 0.9662 | I77, same |
| m130 | 0.9656 | I77, same |
| m129 | 0.9649 | I77, same |
| m77 | 0.9609 | `reparse` — re-parses a modified string (D1) |
| m114 | 0.9588 | invents a `Value` in `[,2,`, breaking acceptance case B2 |
| m112, m113 | 0.9575, 0.9573 | fail CX2 |
| m110, m105, m111 | 0.9573 | fail CX2 **and** cost 0 for all 4 strings the frozen parser rejects — unsound |

Five of the nine are the same defect. Read the `arch` column and the free-span
column before the score column.

122 engines scored on the 1824-case weighted AST-diff battery; 7 more could not be scored and are listed at the end.

**How to read the columns.**

- `AST-diff` is the weighted aggregate over 10 damage categories. It scores the SHAPE of the recovered tree against the shape a human would expect, and nothing else.
- `perfect%` is the share of cases whose recovered skeleton matches the expected one exactly.
- `LOC` is measured after `dart format --language-version=3.0` -- the style this package's own `sdk: '>=3.0.0'` selects. The committed files span two formatter eras and drift by up to +38 lines, so the raw counts are not comparable to each other. `(raw)` is the committed count where it differs.
- `arch` is what the engine does with the frozen `Parser`, and it decides whether a row is comparable at all:
  - `own` -- carries its own parser and memo table; LOC covers parser + recovery, which is what the brief asked for.
  - `probe` -- own parser, but still constructs a library `Parser` over a ONE-CHARACTER synthesized string to ask whether a clause accepts that character. A grammar query, not a parse of the input.
  - `lib` -- no parser of its own; calls the frozen library parser over the ORIGINAL input. LOC is recovery ONLY, so it is not comparable to an `own` row.
  - **`reparse` -- builds a repaired INPUT STRING and runs a second `Parser` over it.** The brief bans this in four separate places ("Don't ever start a new parse"; "you should not launch whole new parser instances"; "Why do you even need to produce a modified input string...? Just keep parsing, and repairing/flagging in-place"; "the input should not be modified or fixed in-place, ever"). **These rows are solving a different problem and their scores are not comparable.** The top-ranked engine used to be one of them; as of m127 it is not.
- `ms` is the engine clock summed over all 1824 cases, measured strictly sequentially and alone on the machine. Two caveats, stated rather than smoothed over. **These are single passes**, so small differences are not real: m121 and m113 read 4,711 and 4,433 here, but measured back-to-back over three alternating rounds they are 4,636 and 4,442, so the gap is 4.4% and not the 6% these figures imply. And **m67's 869,454 includes a few seconds of contention** from a probe running alongside it; at 0.3% of its own figure it changes nothing about a disqualified `reparse` engine ranked 70th, so it was not re-run.
- `brief` is the acceptance probe on the three cases that constrain the design: `,3true` -> `,3,true`; `[,2,` -> `[2,` WITHOUT inventing a Value; and `S <- A 'x' 'a'` on `xa` reaching its own minimum. `-` = not probed. **The battery cannot substitute for this** -- it reads only the tree produced, so an engine can top the ranking while breaking a hard requirement.
- `free` is the conformance probe: how many of the 4 strings the FROZEN parser rejects the engine nevertheless costed at 0. `.` = none, sound. `-` = not swept (the sweep covers m78 onward).

† fails `_freespan.dart`: deletes real input from a span that already matched
(I77). Disqualified regardless of score -- see "Why I77 is withdrawn".

‡ fails `_recommit.dart`: re-reads a prefix that already matched under a
different arm of the grammar's top-level choice, discarding the structure the
healthy prefix committed to. The two failure modes are complements -- one throws
away input, the other throws away the reading of it -- and the battery sees
either only in aggregate. m129/m130 carry both marks.

| # | engine | AST-diff | perfect% | LOC | arch | ms | brief | free | crash | uncov |
|--:|---|--:|--:|--:|:-:|--:|:-:|:-:|--:|--:|
| 1 | m134 † | **0.9668** | 69.4 | 612 | own | 1,227 | ok | . | 0 | 0 |
| 2 | m133 † | **0.9663** | 69.7 | 612 | own | 1,247 | ok | . | 0 | 0 |
| 3 | m138 † | **0.9662** | 69.5 | 612 | own | 1,205 | ok | . | 0 | 0 |
| 4 | m130 †‡ | **0.9656** | 69.3 | 611 | own | 1,262 | ok | . | 0 | 0 |
| 5 | m129 †‡ | **0.9649** | 69.7 | 611 | own | 1,271 | ok | . | 0 | 0 |
| 6 | m132 | **0.9648** | 69.2 | 612 | own | 1,177 | ok | . | 0 | 0 |
| 7 | m135 † | **0.9637** | 67.8 | 599 | own | 1,508 | ok | . | 0 | 0 |
| 8 | m139 † | **0.9634** | 67.8 | 599 | own | 1,418 | ok | . | 0 | 0 |
| 9 | m127 ‡ | **0.9629** | 69.1 | 611 | own | 1,221 | ok | . | 0 | 0 |
| 10 | m137 † | **0.9621** | 66.7 | 599 | own | 1,403 | ok | . | 0 | 0 |
| 11 | m77 | **0.9609** | 71.5 | 763 | reparse | 1,386 | ok | - | 0 | 0 |
| 12 | m136 | **0.9609** | 67.7 | 599 | own | 1,365 | ok | . | 0 | 0 |
| 13 | m128 ‡ | **0.9601** | 67.6 | 611 | own | 2,592 | ok | . | 0 | 0 |
| 14 | m131 † | **0.9589** | 67.3 | 602 | own | 2,630 | ok | . | 0 | 0 |
| 15 | m114 | **0.9588** | 67.7 | 576 <sub>(546)</sub> | own | 4,869 | x:b2 | . | 0 | 0 |
| 16 | m112 | **0.9575** | 67.2 | 582 <sub>(557)</sub> | own | 4,554 | x:cx2 | . | 0 | 0 |
| 17 | m113 | **0.9573** | 67.0 | 579 <sub>(555)</sub> | own | 4,433 | x:cx2 | . | 0 | 0 |
| 18 | m110 | **0.9573** | 67.2 | 581 <sub>(554)</sub> | own | 4,509 | x:cx2 | 4/4 | 0 | 0 |
| 19 | m105 | **0.9573** | 67.2 | 581 <sub>(554)</sub> | own | 4,564 | x:cx2 | 4/4 | 0 | 0 |
| 20 | m111 | **0.9573** | 67.2 | 581 <sub>(556)</sub> | own | 4,569 | x:cx2 | 4/4 | 0 | 0 |
| 21 | m121 | **0.9573** | 67.0 | 578 | own | 4,711 | ok | . | 0 | 0 |
| 22 | m126 | **0.9573** | 67.2 | 602 | own | 2,594 | ok | . | 0 | 0 |
| 23 | m125 | **0.9573** | 67.2 | 594 | own | 2,919 | ok | . | 0 | 0 |
| 24 | m124 | **0.9573** | 67.1 | 584 | own | 3,101 | ok | . | 0 | 0 |
| 25 | m85 | **0.9572** | 66.8 | 500 <sub>(499)</sub> | own | 5,737 | x:b2 | 4/4 | 0 | 0 |
| 26 | m108 | **0.9572** | 67.1 | 597 <sub>(571)</sub> | own | 4,530 | x:cx2 | 4/4 | 0 | 0 |
| 27 | m109 | **0.9572** | 67.2 | 611 <sub>(573)</sub> | own | 5,027 | x:cx2 | 4/4 | 0 | 0 |
| 28 | m102 | **0.9571** | 67.0 | 578 <sub>(552)</sub> | own | 4,546 | x:cx2 | 4/4 | 0 | 0 |
| 29 | m122 | **0.9571** | 66.4 | 576 | own | 4,626 | ok | . | 0 | 0 |
| 30 | m100 | **0.9569** | 66.6 | 561 <sub>(541)</sub> | own | 4,406 | x:cx2 | 4/4 | 0 | 0 |
| 31 | m99 | **0.9569** | 66.6 | 556 <sub>(542)</sub> | own | 5,148 | x:cx2 | 4/4 | 0 | 0 |
| 32 | m106 | **0.9568** | 66.9 | 577 <sub>(550)</sub> | own | 4,567 | x:cx2 | 4/4 | 0 | 0 |
| 33 | m98 | **0.9567** | 67.1 | 566 <sub>(550)</sub> | own | 4,680 | x:cx2 | 4/4 | 0 | 0 |
| 34 | m97 | **0.9567** | 67.1 | 567 <sub>(551)</sub> | own | 5,144 | x:cx2 | 4/4 | 0 | 0 |
| 35 | m96 | **0.9565** | 66.7 | 555 <sub>(538)</sub> | own | 4,481 | x:cx2 | 4/4 | 0 | 0 |
| 36 | m95 | **0.9565** | 66.8 | 556 <sub>(539)</sub> | own | 5,122 | x:cx2 | 4/4 | 0 | 0 |
| 37 | m123 | **0.9564** | 67.0 | 578 | own | 4,400 | ok | . | 0 | 0 |
| 38 | m91 | **0.9560** | 66.4 | 521 <sub>(509)</sub> | own | 5,949 | x:cx2 | 4/4 | 0 | 0 |
| 39 | m94 | **0.9559** | 66.2 | 536 <sub>(524)</sub> | own | 4,199 | x:cx2 | 4/4 | 0 | 0 |
| 40 | m92 | **0.9559** | 66.3 | 537 <sub>(525)</sub> | own | 4,905 | x:cx2 | 4/4 | 0 | 0 |
| 41 | m93 | **0.9559** | 66.3 | 574 <sub>(562)</sub> | own | 4,957 | x:cx2 | 4/4 | 0 | 0 |
| 42 | m90 | **0.9559** | 66.3 | 528 <sub>(516)</sub> | own | 5,642 | x:cx2 | 4/4 | 0 | 0 |
| 43 | m68 | **0.9559** | 69.7 | 1149 <sub>(1138)</sub> | reparse | 859,931 | x:b1 | - | 0 | 0 |
| 44 | m87 | **0.9553** | 65.7 | 504 <sub>(501)</sub> | own | 5,429 | x:cx2 | 4/4 | 0 | 0 |
| 45 | m88 | **0.9553** | 65.7 | 482 <sub>(484)</sub> | own | 5,308 | x:cx2 | 4/4 | 0 | 0 |
| 46 | m89 | **0.9552** | 65.7 | 489 <sub>(491)</sub> | own | 5,129 | x:cx2 | 4/4 | 0 | 0 |
| 47 | m38 | **0.9551** | 67.2 | 406 <sub>(407)</sub> | lib | 1,325 | x:b1 | - | 0 | 0 |
| 48 | m40 | **0.9551** | 67.2 | 429 | lib | 1,340 | x:b1 | - | 0 | 0 |
| 49 | m39 | **0.9551** | 67.2 | 395 <sub>(396)</sub> | lib | 1,277 | x:b1 | - | 0 | 0 |
| 50 | m25 | **0.9551** | 67.2 | 393 <sub>(394)</sub> | lib | 1,470 | x:b1 | - | 0 | 0 |
| 51 | m37 | **0.9551** | 67.2 | 384 <sub>(385)</sub> | lib | 1,465 | x:b1 | - | 0 | 0 |
| 52 | m26 | **0.9551** | 67.2 | 381 <sub>(382)</sub> | lib | 1,482 | x:b1 | - | 0 | 0 |
| 53 | m28 | **0.9551** | 67.2 | 383 <sub>(384)</sub> | lib | 1,696 | x:b1 | - | 0 | 0 |
| 54 | m23 | **0.9551** | 67.2 | 370 <sub>(371)</sub> | lib | 2,016 | x:b1 | - | 0 | 0 |
| 55 | m24 | **0.9551** | 67.2 | 392 <sub>(393)</sub> | lib | 2,079 | x:b1 | - | 0 | 0 |
| 56 | m34 | **0.9551** | 67.1 | 380 <sub>(381)</sub> | lib | 2,685 | x:b1 | - | 0 | 0 |
| 57 | m30 | **0.9551** | 67.2 | 381 <sub>(382)</sub> | lib | 10,635 | x:b1 | - | 0 | 0 |
| 58 | m41 | **0.9550** | 67.2 | 382 <sub>(379)</sub> | probe | 1,053 | x:b1 | - | 0 | 0 |
| 59 | m45 | **0.9550** | 67.2 | 500 <sub>(497)</sub> | probe | 1,263 | x:b1 | - | 0 | 0 |
| 60 | m42 | **0.9550** | 67.2 | 382 <sub>(381)</sub> | probe | 1,286 | x:b1 | - | 0 | 0 |
| 61 | m43 | **0.9550** | 67.2 | 386 <sub>(385)</sub> | probe | 1,217 | x:b1 | - | 0 | 0 |
| 62 | m60 | **0.9550** | 67.2 | 784 <sub>(782)</sub> | probe | 1,345 | x:b1 | - | 0 | 0 |
| 63 | m62 | **0.9550** | 67.2 | 795 <sub>(793)</sub> | probe | 1,312 | x:b1 | - | 0 | 0 |
| 64 | m44 | **0.9550** | 67.2 | 429 <sub>(428)</sub> | probe | 1,328 | x:b1 | - | 0 | 0 |
| 65 | m46 | **0.9550** | 67.2 | 542 <sub>(539)</sub> | probe | 1,312 | x:b1 | - | 0 | 0 |
| 66 | m64 | **0.9550** | 67.2 | 920 <sub>(917)</sub> | probe | 1,286 | x:b1 | - | 0 | 0 |
| 67 | m48 | **0.9550** | 67.2 | 657 <sub>(656)</sub> | probe | 1,480 | x:b1 | - | 0 | 0 |
| 68 | m73 | **0.9550** | 67.2 | 847 <sub>(843)</sub> | probe | 1,357 | x:b1 | - | 0 | 0 |
| 69 | m47 | **0.9550** | 67.2 | 629 | probe | 1,388 | x:b1 | - | 0 | 0 |
| 70 | m49 | **0.9550** | 67.2 | 689 <sub>(688)</sub> | probe | 1,454 | x:b1 | - | 0 | 0 |
| 71 | m71 | **0.9550** | 67.2 | 1039 <sub>(1035)</sub> | probe | 1,395 | x:b1 | - | 0 | 0 |
| 72 | m53 | **0.9550** | 67.2 | 760 <sub>(759)</sub> | probe | 1,593 | x:b1 | - | 0 | 0 |
| 73 | m32 | **0.9550** | 67.2 | 377 <sub>(378)</sub> | lib | 1,598 | x:b1 | - | 0 | 0 |
| 74 | m61 | **0.9550** | 67.2 | 719 <sub>(717)</sub> | probe | 1,653 | x:b1 | - | 0 | 0 |
| 75 | m33 | **0.9550** | 67.2 | 388 <sub>(389)</sub> | lib | 1,692 | x:b1 | - | 0 | 0 |
| 76 | m52 | **0.9550** | 67.2 | 758 <sub>(757)</sub> | probe | 1,654 | x:b1 | - | 0 | 0 |
| 77 | m51 | **0.9550** | 67.2 | 745 | probe | 1,749 | x:b1 | - | 0 | 0 |
| 78 | m50 | **0.9550** | 67.2 | 721 <sub>(720)</sub> | probe | 3,002 | x:b1 | - | 0 | 0 |
| 79 | m31 | **0.9550** | 67.2 | 387 <sub>(388)</sub> | lib | 12,093 | x:b1 | - | 0 | 0 |
| 80 | m59 | **0.9550** | 67.2 | 619 <sub>(616)</sub> | probe | 13,212 | x:b1 | - | 0 | 0 |
| 81 | m58 | **0.9549** | 67.2 | 861 <sub>(862)</sub> | probe | 3,522 | x:b1 | - | 0 | 0 |
| 82 | dot | **0.9549** | 67.3 | 818 <sub>(797)</sub> | lib | 15,728 | x:b1 | - | 0 | 0 |
| 83 | m74 | **0.9548** | 67.1 | 791 | reparse | 1,189 | x:b1 | - | 0 | 0 |
| 84 | m72 | **0.9548** | 67.1 | 992 <sub>(986)</sub> | probe | 1,423 | x:b1 | - | 0 | 0 |
| 85 | m57 | **0.9548** | 67.1 | 861 <sub>(862)</sub> | probe | 3,404 | x:b1 | - | 0 | 0 |
| 86 | m67 | **0.9547** | 68.7 | 1216 <sub>(1208)</sub> | reparse | 869,454 | x:b1 | - | 0 | 0 |
| 87 | m66 | **0.9547** | 68.7 | 1314 <sub>(1311)</sub> | reparse | 864,159 | x:b1 | - | 0 | 0 |
| 88 | m101 | **0.9537** | 64.9 | 578 <sub>(552)</sub> | own | 4,588 | x:cx2 | 4/4 | 0 | 0 |
| 89 | m103 | **0.9532** | 64.5 | 575 <sub>(550)</sub> | own | 4,638 | x:cx2 | 4/4 | 0 | 0 |
| 90 | m75 | **0.9528** | 70.8 | 746 | reparse | 1,204 | ok | - | 0 | 0 |
| 91 | m116 | **0.9512** | 66.5 | 576 <sub>(546)</sub> | own | 4,910 | ok | . | 0 | 0 |
| 92 | m115 | **0.9511** | 66.7 | 576 <sub>(546)</sub> | own | 4,889 | ok | . | 0 | 0 |
| 93 | m118 | **0.9511** | 66.7 | 579 <sub>(549)</sub> | own | 4,703 | x:cx2 | . | 0 | 0 |
| 94 | m117 | **0.9509** | 66.9 | 575 | own | 3,846 | ok | . | 0 | 0 |
| 95 | m119 | **0.9508** | 66.2 | 577 | own | 3,674 | ok | . | 0 | 0 |
| 96 | m86 | **0.9498** | 65.7 | 512 <sub>(509)</sub> | own | 5,702 | ok | 4/4 | 0 | 0 |
| 97 | m140 † | **0.9485** | 63.7 | 599 | own | 1,646 | ok | . | 0 | 0 |
| 98 | m29 | **0.9484** | 62.2 | 389 <sub>(390)</sub> | lib | 9,288 | x:b1 | - | 0 | 0 |
| 99 | m27 | **0.9475** | 62.3 | 386 <sub>(387)</sub> | lib | 1,544 | x:b1 | - | 0 | 0 |
| 100 | m78 | **0.9444** | 68.4 | 1326 <sub>(1296)</sub> | own | 2,182 | ok | . | 0 | 0 |
| 101 | m120 | **0.9439** | 63.4 | 566 | own | 3,107 | x:cx2 | . | 0 | 0 |
| 102 | m84 | **0.9431** | 58.1 | 496 <sub>(495)</sub> | own | 3,861 | x:b2 | 4/4 | 0 | 0 |
| 103 | m83 | **0.9278** | 58.8 | 480 <sub>(479)</sub> | own | 2,626 | x:cx2 | 4/4 | 0 | 0 |
| 104 | sd3 | **0.9247** | 63.0 | 504 <sub>(499)</sub> | lib | 2,422 | x:b1 | - | 4 | 4 |
| 105 | v6 | **0.9023** | 62.9 | ? | lib | 2,189 | x:b1 | - | 55 | 55 |
| 106 | m17 | **0.8974** | 63.2 | 355 <sub>(357)</sub> | lib | 1,979 | x:b1 | - | 61 | 61 |
| 107 | m19 | **0.8962** | 63.2 | 361 <sub>(362)</sub> | lib | 1,792 | x:b1 | - | 61 | 61 |
| 108 | m18 | **0.8962** | 63.2 | 372 <sub>(373)</sub> | lib | 1,959 | x:b1 | - | 61 | 61 |
| 109 | m21 | **0.8962** | 63.2 | 360 <sub>(361)</sub> | lib | 3,490 | x:b1 | - | 61 | 61 |
| 110 | m20 | **0.8962** | 63.2 | 349 <sub>(350)</sub> | lib | 3,971 | x:b1 | - | 61 | 61 |
| 111 | m22 | **0.8959** | 63.2 | 336 <sub>(337)</sub> | lib | 1,921 | x:b1 | - | 63 | 63 |
| 112 | m16 | **0.8958** | 63.2 | 350 <sub>(352)</sub> | lib | 2,199 | x:b1 | - | 66 | 66 |
| 113 | m15 | **0.8958** | 63.2 | 409 <sub>(406)</sub> | lib | 2,287 | x:b1 | - | 66 | 66 |
| 114 | m36 | **0.8948** | 64.9 | 389 <sub>(390)</sub> | lib | 1,650 | x:b1 | - | 0 | 0 |
| 115 | m35 | **0.8948** | 64.9 | 380 <sub>(381)</sub> | lib | 1,696 | x:b1 | - | 0 | 0 |
| 116 | m82 | **0.8942** | 57.0 | 476 <sub>(475)</sub> | own | 1,949 | x:cx2 | 4/4 | 0 | 0 |
| 117 | sd5 | **0.8906** | 62.9 | 518 <sub>(513)</sub> | lib | 2,707 | x:b1 | - | 90 | 90 |
| 118 | m12 | **0.8810** | 62.9 | 399 <sub>(396)</sub> | lib | 2,178 | x:b1 | - | 113 | 113 |
| 119 | m76 | **0.8262** | 66.8 | 1324 <sub>(1294)</sub> | own | 2,301 | ok | - | 252 | 252 |
| 120 | m80 | **0.8168** | 56.4 | 437 <sub>(440)</sub> | own | 3,956 | x:cx2 | 4/4 | 0 | 0 |
| 121 | m81 | **0.8167** | 56.1 | 472 <sub>(471)</sub> | own | 1,951 | x:cx2 | 4/4 | 0 | 0 |
| 122 | m79 | **0.7970** | 43.5 | 365 <sub>(364)</sub> | own | 392 | x:cx2,b1,b2 | 4/4 | 0 | 0 |

## Per-category means

The number under each category is its COVERAGE WEIGHT -- how many cases of that kind the battery generates relative to the others, not a multiplier applied after the fact. The heaviest categories are the ones a human hits most often.

| engine | truncate<br>3.0 | delim-delete<br>3.0 | quote-delete<br>2.5 | delim-insert<br>2.0 | junk-insert<br>2.0 | literal-damage<br>1.5 | quote-insert<br>1.5 | multi-damage<br>1.5 | transpose<br>1.0 | content-damage<br>1.0 |
|---|---|---|---|---|---|---|---|---|---|---|
| m134 | 0.895 | 0.976 | 0.999 | 0.980 | 0.985 | 0.970 | 0.985 | 0.948 | 0.972 | 1.000 |
| m133 | 0.895 | 0.977 | 0.999 | 0.981 | 0.986 | 0.970 | 0.986 | 0.939 | 0.973 | 1.000 |
| m138 | 0.891 | 0.976 | 0.998 | 0.980 | 0.984 | 0.970 | 0.986 | 0.948 | 0.972 | 1.000 |
| m130 | 0.887 | 0.976 | 0.999 | 0.980 | 0.985 | 0.970 | 0.985 | 0.949 | 0.972 | 1.000 |
| m129 | 0.885 | 0.977 | 0.999 | 0.981 | 0.986 | 0.970 | 0.986 | 0.940 | 0.973 | 1.000 |
| m132 | 0.890 | 0.977 | 0.999 | 0.979 | 0.983 | 0.970 | 0.980 | 0.946 | 0.966 | 1.000 |
| m135 | 0.905 | 0.976 | 0.999 | 0.977 | 0.979 | 0.946 | 0.985 | 0.933 | 0.961 | 1.000 |
| m139 | 0.905 | 0.976 | 0.999 | 0.977 | 0.979 | 0.945 | 0.985 | 0.930 | 0.961 | 1.000 |
| m127 | 0.878 | 0.977 | 0.999 | 0.979 | 0.983 | 0.970 | 0.980 | 0.947 | 0.966 | 1.000 |
| m137 | 0.902 | 0.976 | 0.991 | 0.975 | 0.978 | 0.945 | 0.986 | 0.937 | 0.959 | 1.000 |
| m136 | 0.899 | 0.977 | 0.999 | 0.974 | 0.979 | 0.933 | 0.980 | 0.933 | 0.960 | 1.000 |
| m128 | 0.878 | 0.966 | 0.997 | 0.979 | 0.981 | 0.970 | 0.979 | 0.939 | 0.965 | 1.000 |
| m131 | 0.896 | 0.945 | 0.997 | 0.981 | 0.983 | 0.970 | 0.973 | 0.932 | 0.963 | 1.000 |
| m126 | 0.891 | 0.945 | 0.997 | 0.979 | 0.981 | 0.970 | 0.967 | 0.938 | 0.956 | 1.000 |
| m125 | 0.891 | 0.945 | 0.997 | 0.979 | 0.981 | 0.970 | 0.967 | 0.938 | 0.956 | 1.000 |
| m124 | 0.891 | 0.945 | 0.997 | 0.979 | 0.981 | 0.970 | 0.966 | 0.938 | 0.956 | 1.000 |
| m140 | 0.820 | 0.976 | 0.987 | 0.975 | 0.978 | 0.945 | 0.988 | 0.935 | 0.959 | 1.000 |
| m77 | 0.852 | 0.975 | 0.999 | 0.992 | 0.992 | 0.963 | 0.997 | 0.932 | 0.974 | 1.000 |
| m114 | 0.891 | 0.945 | 0.997 | 0.979 | 0.980 | 0.984 | 0.966 | 0.945 | 0.956 | 1.000 |
| m112 | 0.891 | 0.945 | 0.997 | 0.980 | 0.982 | 0.970 | 0.966 | 0.939 | 0.956 | 1.000 |
| m113 | 0.891 | 0.945 | 0.997 | 0.979 | 0.981 | 0.970 | 0.966 | 0.938 | 0.956 | 1.000 |
| m110 | 0.890 | 0.945 | 0.997 | 0.980 | 0.982 | 0.970 | 0.966 | 0.939 | 0.956 | 1.000 |
| m105 | 0.890 | 0.945 | 0.997 | 0.980 | 0.982 | 0.970 | 0.966 | 0.939 | 0.956 | 1.000 |
| m111 | 0.890 | 0.945 | 0.997 | 0.980 | 0.982 | 0.970 | 0.966 | 0.939 | 0.956 | 1.000 |
| m121 | 0.891 | 0.945 | 0.997 | 0.979 | 0.981 | 0.970 | 0.966 | 0.938 | 0.956 | 1.000 |
| m85 | 0.883 | 0.945 | 0.997 | 0.978 | 0.979 | 0.984 | 0.964 | 0.947 | 0.956 | 1.000 |
| m108 | 0.890 | 0.945 | 0.997 | 0.980 | 0.981 | 0.970 | 0.966 | 0.938 | 0.956 | 1.000 |
| m109 | 0.890 | 0.945 | 0.997 | 0.980 | 0.982 | 0.970 | 0.966 | 0.939 | 0.956 | 1.000 |
| m102 | 0.890 | 0.945 | 0.997 | 0.979 | 0.981 | 0.970 | 0.966 | 0.938 | 0.956 | 1.000 |
| m122 | 0.891 | 0.944 | 0.997 | 0.979 | 0.981 | 0.970 | 0.966 | 0.938 | 0.955 | 1.000 |
| m100 | 0.890 | 0.945 | 0.997 | 0.979 | 0.980 | 0.970 | 0.964 | 0.940 | 0.953 | 1.000 |
| m99 | 0.890 | 0.945 | 0.997 | 0.979 | 0.980 | 0.970 | 0.964 | 0.940 | 0.953 | 1.000 |
| m106 | 0.887 | 0.946 | 0.997 | 0.980 | 0.982 | 0.969 | 0.966 | 0.939 | 0.955 | 1.000 |
| m98 | 0.886 | 0.945 | 0.997 | 0.980 | 0.982 | 0.970 | 0.966 | 0.939 | 0.953 | 1.000 |
| m97 | 0.886 | 0.945 | 0.997 | 0.980 | 0.982 | 0.970 | 0.966 | 0.939 | 0.953 | 1.000 |
| m96 | 0.886 | 0.944 | 0.997 | 0.980 | 0.981 | 0.970 | 0.966 | 0.939 | 0.953 | 1.000 |
| m95 | 0.886 | 0.944 | 0.997 | 0.980 | 0.981 | 0.970 | 0.966 | 0.939 | 0.953 | 1.000 |
| m123 | 0.891 | 0.945 | 0.997 | 0.978 | 0.980 | 0.970 | 0.966 | 0.930 | 0.956 | 1.000 |
| m91 | 0.884 | 0.945 | 0.997 | 0.980 | 0.982 | 0.969 | 0.966 | 0.938 | 0.951 | 1.000 |
| m94 | 0.884 | 0.945 | 0.997 | 0.980 | 0.981 | 0.969 | 0.966 | 0.938 | 0.952 | 1.000 |
| m92 | 0.884 | 0.945 | 0.997 | 0.980 | 0.981 | 0.969 | 0.966 | 0.938 | 0.952 | 1.000 |
| m93 | 0.884 | 0.945 | 0.997 | 0.980 | 0.981 | 0.969 | 0.966 | 0.938 | 0.952 | 1.000 |
| m90 | 0.884 | 0.945 | 0.997 | 0.980 | 0.981 | 0.969 | 0.966 | 0.938 | 0.952 | 1.000 |
| m68 | 0.820 | 0.966 | 0.998 | 0.993 | 0.997 | 0.963 | 0.997 | 0.947 | 0.971 | 1.000 |
| m87 | 0.884 | 0.945 | 0.997 | 0.978 | 0.979 | 0.969 | 0.963 | 0.938 | 0.951 | 1.000 |
| m88 | 0.884 | 0.945 | 0.997 | 0.978 | 0.979 | 0.969 | 0.963 | 0.938 | 0.951 | 1.000 |
| m89 | 0.883 | 0.945 | 0.997 | 0.978 | 0.979 | 0.969 | 0.963 | 0.938 | 0.952 | 1.000 |
| m38 | 0.816 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.972 | 1.000 |
| m40 | 0.816 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.972 | 1.000 |
| m39 | 0.816 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.972 | 1.000 |
| m25 | 0.816 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.972 | 1.000 |
| m37 | 0.816 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.972 | 1.000 |
| m26 | 0.816 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.972 | 1.000 |
| m28 | 0.816 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.972 | 1.000 |
| m23 | 0.816 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.972 | 1.000 |
| m24 | 0.816 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.972 | 1.000 |
| m34 | 0.817 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.970 | 1.000 |
| m30 | 0.817 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.970 | 1.000 |
| m41 | 0.816 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.971 | 1.000 |
| m45 | 0.816 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.971 | 1.000 |
| m42 | 0.816 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.971 | 1.000 |
| m43 | 0.816 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.971 | 1.000 |
| m60 | 0.816 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.971 | 1.000 |
| m62 | 0.816 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.971 | 1.000 |
| m44 | 0.816 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.971 | 1.000 |
| m46 | 0.816 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.971 | 1.000 |
| m64 | 0.816 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.971 | 1.000 |
| m48 | 0.816 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.971 | 1.000 |
| m73 | 0.816 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.971 | 1.000 |
| m47 | 0.816 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.971 | 1.000 |
| m49 | 0.816 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.971 | 1.000 |
| m71 | 0.816 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.971 | 1.000 |
| m53 | 0.816 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.971 | 1.000 |
| m32 | 0.816 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.971 | 1.000 |
| m61 | 0.816 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.971 | 1.000 |
| m33 | 0.816 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.971 | 1.000 |
| m52 | 0.816 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.971 | 1.000 |
| m51 | 0.816 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.971 | 1.000 |
| m50 | 0.816 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.971 | 1.000 |
| m31 | 0.816 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.971 | 1.000 |
| m59 | 0.816 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.971 | 1.000 |
| m58 | 0.815 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.942 | 0.971 | 1.000 |
| dot | 0.816 | 0.965 | 0.998 | 0.997 | 0.997 | 0.962 | 0.997 | 0.941 | 0.970 | 1.000 |
| m74 | 0.816 | 0.965 | 0.998 | 0.995 | 0.996 | 0.962 | 0.998 | 0.942 | 0.971 | 1.000 |
| m72 | 0.816 | 0.965 | 0.998 | 0.995 | 0.996 | 0.962 | 0.998 | 0.942 | 0.971 | 1.000 |
| m57 | 0.814 | 0.965 | 0.998 | 0.995 | 0.997 | 0.962 | 0.998 | 0.943 | 0.971 | 1.000 |
| m67 | 0.814 | 0.965 | 0.998 | 0.995 | 0.997 | 0.963 | 0.998 | 0.941 | 0.972 | 1.000 |
| m66 | 0.814 | 0.965 | 0.998 | 0.995 | 0.997 | 0.963 | 0.998 | 0.941 | 0.972 | 1.000 |
| m101 | 0.873 | 0.943 | 0.997 | 0.978 | 0.981 | 0.970 | 0.965 | 0.937 | 0.955 | 1.000 |
| m103 | 0.872 | 0.943 | 0.997 | 0.977 | 0.980 | 0.970 | 0.964 | 0.936 | 0.954 | 1.000 |
| m75 | 0.839 | 0.975 | 1.000 | 0.992 | 0.993 | 0.963 | 0.995 | 0.918 | 0.880 | 1.000 |
| m116 | 0.869 | 0.943 | 0.997 | 0.979 | 0.982 | 0.960 | 0.966 | 0.920 | 0.951 | 1.000 |
| m115 | 0.870 | 0.943 | 0.997 | 0.979 | 0.982 | 0.960 | 0.964 | 0.921 | 0.951 | 1.000 |
| m118 | 0.870 | 0.943 | 0.997 | 0.979 | 0.982 | 0.960 | 0.964 | 0.921 | 0.951 | 1.000 |
| m117 | 0.867 | 0.944 | 0.997 | 0.979 | 0.983 | 0.960 | 0.966 | 0.921 | 0.951 | 1.000 |
| m119 | 0.867 | 0.944 | 0.997 | 0.979 | 0.983 | 0.959 | 0.966 | 0.921 | 0.951 | 1.000 |
| m86 | 0.866 | 0.944 | 0.997 | 0.977 | 0.980 | 0.959 | 0.961 | 0.921 | 0.947 | 1.000 |
| m29 | 0.822 | 0.963 | 0.954 | 0.995 | 0.997 | 0.961 | 0.998 | 0.925 | 0.969 | 1.000 |
| m27 | 0.817 | 0.963 | 0.951 | 0.995 | 0.997 | 0.962 | 0.998 | 0.925 | 0.970 | 1.000 |
| m78 | 0.824 | 0.968 | 0.999 | 0.953 | 0.951 | 0.952 | 0.984 | 0.926 | 0.968 | 1.000 |
| m120 | 0.867 | 0.935 | 0.997 | 0.976 | 0.971 | 0.928 | 0.959 | 0.909 | 0.951 | 1.000 |
| m84 | 0.897 | 0.944 | 0.989 | 0.964 | 0.964 | 0.887 | 0.951 | 0.908 | 0.949 | 1.000 |
| m83 | 0.855 | 0.933 | 0.989 | 0.960 | 0.959 | 0.844 | 0.949 | 0.881 | 0.944 | 1.000 |
| sd3 | 0.776 | 0.938 | 0.998 | 0.954 | 0.954 | 0.924 | 0.958 | 0.903 | 0.938 | 1.000 |
| v6 | 0.780 | 0.907 | 0.998 | 0.917 | 0.922 | 0.877 | 0.932 | 0.874 | 0.890 | 1.000 |
| m17 | 0.775 | 0.904 | 0.998 | 0.903 | 0.913 | 0.866 | 0.921 | 0.885 | 0.879 | 1.000 |
| m19 | 0.777 | 0.903 | 0.998 | 0.909 | 0.911 | 0.868 | 0.908 | 0.867 | 0.890 | 1.000 |
| m18 | 0.777 | 0.903 | 0.998 | 0.909 | 0.911 | 0.868 | 0.908 | 0.867 | 0.890 | 1.000 |
| m21 | 0.777 | 0.903 | 0.998 | 0.909 | 0.911 | 0.868 | 0.908 | 0.867 | 0.890 | 1.000 |
| m20 | 0.777 | 0.903 | 0.998 | 0.909 | 0.911 | 0.868 | 0.908 | 0.867 | 0.890 | 1.000 |
| m22 | 0.774 | 0.903 | 0.998 | 0.909 | 0.911 | 0.868 | 0.908 | 0.867 | 0.890 | 1.000 |
| m16 | 0.775 | 0.898 | 0.998 | 0.903 | 0.913 | 0.866 | 0.921 | 0.877 | 0.879 | 1.000 |
| m15 | 0.775 | 0.898 | 0.998 | 0.903 | 0.913 | 0.866 | 0.921 | 0.877 | 0.879 | 1.000 |
| m36 | 0.816 | 0.898 | 0.998 | 0.872 | 0.899 | 0.827 | 0.895 | 0.872 | 0.932 | 1.000 |
| m35 | 0.816 | 0.898 | 0.998 | 0.872 | 0.899 | 0.827 | 0.895 | 0.872 | 0.932 | 1.000 |
| m82 | 0.823 | 0.895 | 0.989 | 0.900 | 0.912 | 0.793 | 0.901 | 0.860 | 0.909 | 1.000 |
| sd5 | 0.762 | 0.898 | 0.998 | 0.904 | 0.908 | 0.860 | 0.913 | 0.856 | 0.880 | 1.000 |
| m12 | 0.762 | 0.886 | 0.998 | 0.879 | 0.892 | 0.842 | 0.905 | 0.857 | 0.853 | 1.000 |
| m76 | 0.721 | 0.808 | 0.999 | 0.781 | 0.805 | 0.768 | 0.838 | 0.810 | 0.817 | 1.000 |
| m80 | 0.760 | 0.780 | 0.989 | 0.800 | 0.817 | 0.673 | 0.805 | 0.782 | 0.801 | 1.000 |
| m81 | 0.760 | 0.780 | 0.989 | 0.800 | 0.818 | 0.673 | 0.805 | 0.782 | 0.801 | 1.000 |
| m79 | 0.797 | 0.824 | 0.888 | 0.792 | 0.814 | 0.679 | 0.777 | 0.719 | 0.710 | 0.876 |

## Schedule-independence probes

Each probe is its engine with the doubling budget schedule (`_budget * 2`) replaced by step-by-one. An engine whose answer depends on which costs happen to share a deepening round is tuned to the schedule, not to the grammar, and must score differently here. One that does not must score identically.

| probe | AST-diff | perfect% | base engine | base AST-diff | identical? |
|---|--:|--:|---|--:|:-:|
| m113step | 0.9573 | 67.0 | m113 | 0.9573 | **yes** |
| m116step | 0.9511 | 66.4 | m116 | 0.9512 | **NO** |
| m121step | 0.9573 | 67.0 | m121 | 0.9573 | **yes** |

## Engines that produced no score

Listed rather than omitted: omission would read as "these were covered".

- `cgfr1` -- no score -- exceeded 1200 s on the battery, no per-case profile taken
- `cgfr2` -- no score -- exceeded 1200 s on the battery, no per-case profile taken
- `cgfr5` -- no score -- exceeded 1200 s on the battery, no per-case profile taken
- `m63` -- did not finish -- blows up on **truncate** (4 of 6 first offenders); worst 16,076 ms on a 35-char input
- `m65` -- did not finish -- blows up on **truncate** (5 of 6); worst 20,218 ms on a 42-char input
- `m69` -- did not finish -- blows up on **transpose** (6 of 6); worst 12,192 ms on a 48-char input
- `m70` -- did not finish -- blows up on **transpose** (6 of 6); worst 11,985 ms on a 48-char input

These four were previously recorded as "combinatorial blowup on nested damage".
**That was wrong**, and `_slowcase.dart` (per-case clock, first six cases over
2,000 ms) says so: there are **two** different failure modes here, not one.
m63/m65 blow up on truncated input, where the skip loop cannot run past the end
and the search has only fills to work with; m69/m70 blow up on transposition,
exclusively — not one truncate case among their offenders. An engine that is
slow on a particular shape of damage is a different claim about the algorithm
from one that is slow everywhere, and the earlier note asserted neither
correctly. Raw output: `slowcase.txt`.
