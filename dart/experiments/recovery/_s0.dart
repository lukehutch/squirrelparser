// r9.dart -- r8 with the one thing a reading may not say: that the document
// both ran out here and has a character here to throw away.
//
// I92 -- AN OBLIGATION AND A TRAILING DISCARD ARE TWO CLAIMS ABOUT THE SAME
// POSITION, AND THEY CONTRADICT EACH OTHER.
//
// r8's cheapest reading of `{ a` -- the truncation of `{ a=1; ... }` -- is:
// delete the `a`, then owe the `}`. Cost 2. The reading a human wants is: read
// `a` as a name, then owe `= Cond ;` and the `}`. Cost 4. Levenshtein prefers
// the first and it is not close, so NO change to [_rank] can reach this: the
// deepening loop answers at the first budget that offers anything, and 2 comes
// before 4 whatever the tiebreaks say. That was measured, not assumed -- two
// separate [_rank] orders (`del` before `gap`, and `del` as first tiebreak)
// left the truncate column flat at 0.936 and cost 0.010 and 0.004 overall.
//
// What is wrong with the cheap reading is not its price. It is that an
// obligation is a claim that THE DOCUMENT RAN OUT, and a trailing discard is a
// claim that it did NOT. A way whose last act was to owe, with input still in
// front of it, makes both claims at one position: it says a character is
// missing HERE and then hands the character that IS here to the discard. It
// never earned the obligation -- it should have read what the document offered.
//
// So the rule is not a preference between prices, it is a coherence test on a
// single reading, and it applies where [recover] closes the tail. THE BIT IT
// TESTS IS A MONOID like every other counter a way carries: an obligation sets
// [owing], consuming anything clears it, reading nothing leaves it alone.
// `then` composes it as `v.owing || (v.end == end && owing)`, which is
// associative because positions only ever grow -- `p2 == p0` forces
// `p0 == p1 == p2` -- and identity holds on both sides. One bool suffices
// because an obligation's position is always the way's own end.
//
// AND THE RULE MAY NOT LEAVE THE ENGINE WITH NOTHING. It says which reading is
// better, not which readings exist. `Top <- Chunk 'z'` on `abab` has no
// coherent reading at any budget -- the repetition cannot resync past the `b`
// -- and a filter that refuses them all answers by deleting the whole document,
// which is exactly what the [_committed] gate exists to catch (it did: the
// hard-filter draft failed it). So the incoherent best is kept as [fall], at
// the FIRST budget that offers one, and used only if no coherent way is ever
// found. Coarsening the test to `tail > 0 && w.gap > 0` -- no [owing] bit at
// all -- scores the same 0.9716 on truncate but loses the insert categories:
// it refuses obligations a way had already paid for and read past.
//
// Battery 0.9711 -> 0.9721, perfect 73.2% -> 73.6%, truncate 0.936 -> 0.946,
// every other category equal or better, 1.052x latency. All six honesty gates
// unchanged.
//
// I91 IS CORRECTED HERE, AND THE CORRECTION IS FREE. r8 argued that a given-up
// slot owes ONE mark however many characters it stands for, because splitting
// it would describe separate omissions nothing observed. That is a nice
// sentence about a tree and it is wrong about an engine: the budget is charged
// [_minFill] characters and the charge is READ BACK OFF THE TREE, so a single
// mark standing for two obligations is a repair the tree does not show. On
// `if (a` the slot costs 2 and one mark reports 1. Measured over the battery,
// r8 under-reports its own charge on 14 of 1824 cases, always by exactly 1,
// always a truncated `if` where `_minFill(Stmt) = 2`. One mark per obligation:
// 0 violations, identical score. An engine may not charge for something it
// then declines to say.
//
// I90 -- DENYING INPUT AND GIVING UP GRAMMAR ARE THE SAME SKIP AT TWO DEPTHS.
//
// A sequence in r6 had two ways to repair a slot it could not read, and both
// of them work by DISCARDING INPUT: move the whole production somewhere the
// input does fit, or resynchronize past characters the slot does not want. Both
// answer "there is something here that should not be". Neither answers "there
// is nothing here and something should be" -- which is the other half of an
// edit distance, and the half a deletion leaves behind.
//
// r6 could say it, but only at the very end of the input, guarded by
// `w.end == _in.length` on the argument that a document which STOPPED is
// evidence for nothing, whereas one that carries on is evidence against. That
// is true of the tail of a production and false of a hole inside one: `if ()`
// supplies the bracket on both sides, so the production was entered, was left,
// and the part between them was simply never written. Deleting the guard is
// the whole of the change and it is strictly positive -- 0.9683 -> 0.9687 with
// all five honesty gates unchanged. The budget and [_rank] were already doing
// the work the guard was arguing for.
//
// I91 -- SO A PRODUCTION MAY GIVE UP ONE SLOT AND CARRY ON.
//
// Owing the TAIL of a sequence stops it. Owing ONE slot does not: the next slot
// is asked at the same position and the production finishes. That is the third
// repair, priced at [_minFill] -- the fewest characters any derivation of the
// slot could have consumed -- so it is charged in the same unit as a discard
// and [_rank] compares the two directly, with no rule about which to prefer.
//
// It is offered where nothing else reached the slot. A move and a resync both
// EXPLAIN what they take, using characters the document really supplied; a
// give-up assumes. Ordering them is not a preference but the rule [_first]
// already applies to a damaged arm, and it is worth 73.0 -> 73.2 perfect.
//
// And it owes one mark PER CHARACTER of [_minFill] -- see the correction under
// I92 above, which is where this claim was tested and reversed. r8 owed a
// single mark for the whole slot and thereby under-reported its own charge.
//
// r8 measured 0.9711 / 73.2% perfect / 1587 ms, to r6's 0.9683 / 73.6 / 1714.
// Every category is equal or better. THE PERFECT COLUMN IS DOWN AND THE REASON
// IS WORTH RECORDING: on `if (a) { if () { c=1; } }` r6 scores exact by a
// reading that is not the one it looks like. It supplies the inner `if` keyword
// and its `(` as ZERO-WIDTH holes (ERR @8+0, ERR @9+0), DELETES the `i` at 9
// (ERR @9+1), reads only the `f` at 10 as the condition variable, then deletes
// the real `(` at 12. The Cond spans `if` only because the deleted `i` hangs
// beneath it -- the keyword is not read as the variable, and could not be:
// `Name <- !Keyword [a-z]+` and `Keyword` matches `if ` at 9. What that
// happens to produce is the oracle's SHAPE. r8 reads the brackets as brackets
// and marks the hole between them. It loses the point and it is the better
// answer; ten cases turn on this and three turn the other way.
//
// WHAT THIS COST TO FIND, AND WHAT IT DID NOT BUY. r7 implements the original
// brief's own architecture -- pure parse, frontier list, widen, splice, resume
// -- with both sides of the alignment offered at each price. It works: it lifts
// r1 by 0.8018 -> 0.8970. It caps there, at 481 lines and 7180 ms, because it
// commits one repair per round and re-scores it by a full cold re-parse:
// measured, 114 re-parses per case. The chart does not re-parse at all. The
// operations were the brief's; only the architecture had to change.
//
// r6 -- r5 with the two questions it was answering EAGERLY answered late,
// and the round that is already a PEG parser made to do a PEG parser's work.
//
// I88 -- A WAY SAYS WHAT ITS NODE WOULD BE, NOT WHAT IT IS.
//
// r5 builds a `MatchResult` at every close, so the chart is a chart of trees.
// But [_rank] reads no tree: it orders by `del + gap`, then `peg`, then `net`,
// then `key` -- four integers a way already carries. So the winner can be
// CHOSEN before anything is built, and everything else never built at all. A
// way now records what its node WOULD be -- the clause to cap with ([cap]),
// where it started ([from]), and the chain to walk ([link]/[prev]) -- and
// [_Way._build] runs once, on the winner, from the root.
//
// Measured over the battery: [_wrap] calls 4,248,274 -> 244,677, so 94.2% of
// node construction was for readings that were discarded; chain steps
// 8,206,337 -> 416,042. The battery falls to 0.68x r5, and a flat list stops
// being quadratic (exponent 1.82 -> 1.02) because the DISCARDED trees were the
// quadratic -- the chart itself was never that wide.
//
// I89 -- THE FIRST ROUND IS THE FROZEN PARSER, SO IT SHOULD HAND OUT WHAT A
// FROZEN PARSER'S MEMO ENTRY HOLDS: one reading, PEG's own, or none.
//
// A clean way that is not PEG's reading is ALREADY DEAD when round 0 makes it.
// [_Way.then] takes the minimum key, so any chain holding one is at most
// [_far], and [recover] refuses exactly [_far]; buying it back takes a repair,
// and round 0 has nothing to spend. Round 0 was therefore building a cross
// product of readings none of which could ever be the answer. [_prune] cuts it
// to one, and because the next cell out expands from THAT one, the narrowing
// propagates: no cell ever materialises the wide set.
//
// THE TEST IS THE ROUND, NOT THE BUDGET. A later round spends down to a
// residual of 0, and the move and resync probes ask at 0 on purpose -- but they
// want a slot that reads CLEANLY, not one that reads as PEG would, and their
// chain has already paid, so its key is below [_far] and the root takes it.
// Only in the first round are the two questions the same one. Gating on the
// budget instead scored 0.9664 / 72.9 with diff=168 -- the refuted control.
//
// AND THE CUT MUST SIT INSIDE THE FIXED-POINT LOOP, not on the cell's way out.
// A left-recursive cell grows by re-reading its own ways as the next seed. Seed
// it from one way and it grows one way per pass: O(n) passes x O(1). Seed it
// from the full set -- which is what moving the cut to the return does -- and
// it grows O(n) ways per pass, and `left-rec` is quadratic again. Measured at
// n=2047: cut inside 1.84 ms, cut on the return 503.87 ms, r5's schedule
// 1353.38 ms. The extra passes the thin seed costs are not waste to be paid
// off; they ARE the linear-time schedule.
//
// What this buys, at n~2048: `left-rec` 740x, `seq-deep` 9739x. EVERY clean
// shape measured is now linear (exponents 0.91 - 1.25). What it costs: +6% on
// the battery, and the mechanism is +3.8% [_ways] calls -- round 1 re-deriving
// from a chart round 0 left narrower. At 0.90 ms per case that constant is
// invisible against the 250 ms goal; the quadratics it removes are not.
//
// The two remaining quadratics are `rep-first-err` (2.08) and `left-rec-err`
// (2.18), both on damaged input. That is the deepening loop itself -- budget
// rounds x chart -- not chart width, so no pruning change will reach it.
//
//
// -- inherited from r6 --------------------------------------------------
//
// -- inherited from r5, unchanged ------------------------------------------
//
// r5 -- r4 with its two questions about a reading merged into one number,
// and the three things that number was then able to say.
//
// THE MERGE. r4 asks two questions of every way it builds: is this the reading
// the frozen parser would take (`peg`), and where does it stop taking the
// document at face value (`fix`)? Over four million ways on the battery no way
// ever answers both -- `peg` implies the way repairs nothing, and repairing
// nothing is exactly `fix` being [_far]. Two fields, disjoint supports, one
// integer:
//
//   [_peg]           this is PEG's own reading
//   [_far]           read clean, but not the reading PEG would take
//   0 .. length      read clean up to here, and repaired at this position
//
// The propagations merge with the fields. Conjunction of `peg` and minimum of
// `fix` are the SAME operation on this key, so chaining two ways is `min`,
// losing the PEG claim is `min` with [_far], and charging a way for the tail it
// never reached is `min` with the position it stopped at -- which is why losing
// the claim and recording a repair were always one act. `free` reads off the
// same field: a way repairs nothing exactly when its key is at least [_far]. So
// the three questions the engine asks about a reading -- is it clean, is it
// PEG's, and where does it stop trusting the input -- are three thresholds on
// one number.
//
// THE CHAIN. What is left is a monoid. [_Way.unit] is the identity and
// [_Way.then] the product -- three sums and one minimum -- and because every
// counter is an aggregate over the tree, that IS what concatenating the trees
// does to them. A sequence is the product folded over its slots and a
// repetition is it starred; a deletion ([_Way.skip]) and an unmet obligation
// ([_Way.owe]) are two more ELEMENTS to fold in, not two more rules. Five
// construction formulas in r4 are one call here.
//
// AND THEN THE KEY CAN BE ENFORCED. r4's own comment said the round at budget 0
// IS the frozen parser. It was not: `peg` only ORDERED ways, nothing ever
// refused one, and any complete free reading ended the round. On `S <- 'a'* "ab"`
// with `aab` the possessive `*` quietly backs off to a single `a` and r4 answers
// cost 0 -- a claim about the grammar the frozen parser contradicts, and the
// same possessive-star defect occasion 31 named in the cgfr line. One line makes
// the sentence true:
//
//   if (a.key == _far) continue;
//
// Refuse the single value BETWEEN the two thresholds -- clean, but not PEG's.
// Were such a reading an answer the frozen parser would have returned it. That
// value exists to be refused only because the fields merged.
//
// A CEILING BELOW ITS FLOOR. `S <- S;` has no finite derivation, so [_minFill]
// leaves it at [_never] and r4 deepened towards a ceiling near 2^30 -- a hang,
// where the frozen parser returns at once. A fill tree and a match tree have the
// same shape, so a rule that cannot be filled to anything cannot match anything
// either: there is nothing to deepen TOWARDS, and the ceiling is put below the
// floor so the whole-input error stands.
//
// AND A CLAUSE THAT CANNOT CALL ITSELF NEEDS NO CELL. Everything a cell carries
// -- the nested lookup, the two cycle flags, the monotone loop, the version
// stamp -- exists for re-entry. A clause with no subclauses has nothing to
// re-enter through, and a reference's own cell only shadows the rule body's,
// which is where the cycle is detected and the fixed point actually taken.
// Between them they are most of the lookups the engine makes, and every one was
// paying for a loop that could run only once. With a sequence prefix that has
// already overspent the round no longer asked for slots it cannot afford, this
// is a tenth of the clock and not one tree changes.
//
// Measured against r4, same battery and clock, 1824 cases: 0.9683 both, exact
// recovery 73.2% -> 73.6%, eight documents better and none worse, median 2470
// -> 2210 ms over seven alternating rounds whose ranges do not overlap. Every
// structural claim the engine makes about its own ways is now total over
// 5,678,178 of them; r4 broke one 2,419 times, recording a stop that owed
// several obligations as a single mark.
//
// r4's own account follows unchanged.
//
// ---------------------------------------------------------------------------
//
// r4.dart -- r3, plus the two places where a repair was allowed to relocate a
// production, or outbid a reading the document had already settled.
//
// r3 loses two documents that a reader gets right without thinking:
//
//   `{"a":[1,[2,`                        -> Value(String), not the two arrays
//   `x=1; y=2; z=3; { p=4; q=5; " r=6;`  -> four assignments, the block gone
//
// Both are the search finding something CHEAPER than the truth, so neither is
// fixed by ranking: the cheap reading has to stop being available. And both
// turn out to be one mistake made in two clauses -- a repair helping itself to
// ground the input had already accounted for.
//
// ONE -- A PRODUCTION THAT HAD TO MOVE MUST FIT WHERE IT MOVED TO ([_seq]).
// r3 may discard input in front of any slot. In front of a LATER slot the
// discarded characters lie between two things the production has already
// claimed, so the production itself brackets them as junk. In front of the
// FIRST slot nothing of it has been read yet: there is no left bracket to be
// inside of, and the discard does not resynchronize the production, it moves
// the whole production somewhere else. That is how `{"a":[1,[2,` becomes a
// `String` -- delete the `{`, start at the quote, then supply the closing
// quote the input never reaches. Three repairs, against the four the nested
// arrays cost, and the arrays lose. So a first-slot discard is still offered,
// but only where the production reads CLEANLY from where it lands, entire.
// Moving is not evidence that it belongs there; fitting is. `1(2+3*(4-5))`
// still deletes its stray `1`, because `(2+3*(4-5))` is a Factor exactly as
// written -- which is the case that says the rule may not simply be "never
// discard in front of the first slot": at the start of a document EVERY
// enclosing production has that same position for its first slot, so there is
// no parent left to do the deleting honestly.
//
// TWO -- A REPAIR MAY NOT OUTBID A CLEAN READING UNLESS IT EXPLAINS MORE THAN
// IT ASSUMES ([_first]). Once an arm has read the input AS IT STANDS, the
// choice belongs to the document. A later arm may still take it where it too
// reads cleanly; where it needs a repair, it may take it only if the reading
// is more evidence than assumption -- more characters pinned by a terminal
// that constrains what it accepts ([_Way.net]) than characters it merely
// helped itself to. At `3; { p=4; q=5; "`, `Cond`'s `Num` arm reads `3` as
// written, while its `Str` arm can supply an opening quote and swallow sixteen
// characters through `[^"\]` to reach the real one -- explaining exactly one
// of them, and eating the block on the way. An `Array` that supplies its `[`
// and then accounts for every character between it and a real `]` is the same
// rule saying yes, which is why the test is evidence and not arithmetic on the
// repair count.
//
// AND ONE ORDERING KEY. [_Way.fix] is where a way's EARLIEST repair falls, and
// where cost, conformance, evidence and deletion have all tied, the reading
// whose first repair falls LATER wins: it took the longer prefix at face
// value. On `a*(b+` that is the whole difference between closing the
// parenthesis at column 4, which asserts an error the input never showed, and
// running out of input at column 5, which asserts nothing the document had not
// already said.
//
// Measured against r3, same battery and clock, 1787 distinct cases: 0.9642 ->
// 0.9683 overall, 71.2% -> 73.2% exact, and not one of the ten damage
// categories lower. Truncation 0.918 -> 0.936 and quote-insertion 0.973 ->
// 0.981 carry it.
//
// r3's own account of the chart follows unchanged, because r4 changes what the
// search is ALLOWED to say and nothing about how it says it.
//
// ---------------------------------------------------------------------------
//
// r3 -- r2's philosophy, with the one thing r2's memo could not say.
//
// r1 and r2 kept the frozen parser's memo exactly: ONE result per (rule, pos).
// That is what PEG means, and it is why they had to re-parse. A repair was a
// substitution installed into a side table, the whole parse was run again from
// cold to find out what it did, and the memo was cleared between every trial --
// two full parses per frontier site per widening step. 2,153 ms of it.
//
// It also set a ceiling no amount of searching could lift. Delete the closing
// quote of a JSON member and `Character*` runs greedily to the NEXT real quote,
// so `String` ends late, `Member`'s `':'` fails, and there is no mismatch at
// the position where the quote belongs -- nothing for a frontier repair to
// attach to. The repair the input wants is "String could have stopped earlier",
// and a cell holding one result cannot say it. Measured: quote-delete was r2's
// single largest deficit, 190 cases at a mean 0.163 below m143.
//
// So a cell holds a LIST of ways instead of one result. A way is one end
// position reached at one price. `String` at 1 offers both "ends at 7, free"
// and "ends at 3, one obligation unmet", the enclosing `Member` takes whichever
// lets IT finish, and the choice needs no search around the parse because it is
// made inside it.
//
// THE TRICK IS THE SAME ONE. The frozen parser's `MemoEntry` lets a frame
// arbitrarily deep tell an arbitrarily distant ancestor "you are the frame that
// entered this cycle, expand it" by writing `foundLeftRec` into the entry that
// ancestor already owns -- the message crosses the whole tree in O(1) because
// its destination is addressable by content rather than by walking, and not one
// intermediate combinator learns it exists. `_Cell` carries `inPath`, `foundLR`
// and `gen` unchanged, and the loop that grows a left-recursive match to its
// fixed point is the loop that grows a repaired one: both only ever IMPROVE, so
// "re-run while the answer improves" is one mechanism serving both, and the one
// integer bump at `_version[pos]` retires every stale cell at that position
// without touching any of them.
//
// What that buys, beyond the score: there is no second parse. No `_forget`, no
// `_repairs` side table, no frontier walk, no widening loop, no advancement
// test, no salvage pass, no re-parse to find out what a repair did. r2 needed
// all of it to ask "what would happen if"; the answer is now computed where the
// question arises.
//
// KEPT FROM r2, because measurement earned it:
//
//   * A fill supplies only what the grammar SHAPE-DETERMINES ([_determined]).
//     `'}'` and `A <- [ab]` have one tree whatever they derive; `Value` has one
//     per arm, and a zero-width `Value` would assert an object or an array or a
//     number happened, on no evidence at all.
//   * At equal cost, the reading that EXPLAINS more of the input wins
//     ([_Way.net]), and only then the one that DELETED less. Deleting a
//     character contradicts evidence the input supplied where a gap only
//     records evidence it never supplied -- but that is a proxy for keeping the
//     input, and [_rank] says where the proxy inverts.
//
// AND ONE THING NEITHER r1 NOR r2 NEEDED. A chart admits readings PEG does not:
// `'a'* 'a'` fails in PEG because the star is possessive, and succeeds here
// because a shorter chain is on offer. That freedom is exactly what repairs the
// quote -- but on an undamaged document the answer must still be PEG's, to the
// node. So every way carries [_Way.peg], set only along the reading the frozen
// parser itself would take, and a peg way outranks every other way of the same
// cost. Conformance is then a property of the ordering rather than a special
// case in the search.
import 'package:squirrel_parser/squirrel_parser.dart';

/// A match carrying the spans a repair skipped, and the obligations it left
/// unmet, beside the grammar's own children.
///
/// It extends [MatchResult] rather than [Match] because `Match` recomputes its
/// span from its children, and so cannot represent a node that begins with a
/// skipped span or one that covers no characters at all.
class Repaired extends MatchResult {
  Repaired(super.clause, super.pos, super.len, this.children, this.errors);

  /// The grammar's own children, at the grammar's own indices.
  final List<MatchResult> children;
  final List<SyntaxError> errors;

  /// Children and marks together, in input order. Leaving the marks out would
  /// make the tree describe less than the whole input, and every consumer that
  /// walks a match would find a hole exactly where the repair is.
  @override
  List<MatchResult> get subClauseMatches =>
      [...children, ...errors]..sort((a, b) => a.pos - b.pos);

  @override
  String toPrettyString(String input, {int indent = 0}) {
    final b = StringBuffer();
    for (final k in subClauseMatches) {
      b.write(k.toPrettyString(input, indent: indent));
    }
    return b.toString();
  }
}

/// Further than any repair can fall, so a way that repairs nothing compares as
/// having its first repair past the end of every document.
const int _far = 1 << 30;

/// And one further still: the reading the frozen parser itself would take.
///
/// `peg` and `fix` were never two questions. Measured over four million ways,
/// `peg` implies `free`, and `free` holds exactly when `fix` is [_far] -- so no
/// way ever carries information in both, and one integer holds both:
///
///   [_peg]           this is PEG's own reading
///   [_far]           read clean, but not the reading PEG would take
///   0 .. length      read clean up to here, and repaired at this position
///
/// The two propagations collapse with the fields. Conjunction of `peg` and
/// minimum of `fix` are the SAME operation on this key, so chaining two ways is
/// `min`, demoting a way is `min` with [_far], and charging a way for the tail
/// it never reached is `min` with the position it stopped at -- which is why
/// losing the PEG claim and recording a repair there were always one act.
const int _peg = _far + 1;

int _min(int a, int b) => a < b ? a : b;

/// One way of reaching one end position: what it cost, how much it explained,
/// and the tree that says so.
///
/// Inside a sequence or a repetition a way is one LINK of a chain -- [node] is
/// that step's own child and [prev] is the step before it -- so extending a
/// chain is one allocation rather than a copy of everything built so far. The
/// children are collected once, for the few chains that survive.
class _Way {
  const _Way(this.end, this.del, this.gap, this.net, this.key,
      {this.toll = 0,
      this.leaf,
      this.cap,
      this.from = 0,
      this.link,
      this.prev,
      this.mark,
      this.owing = false,
      this.eof = 0,
      this.vouch = 0});

  /// Read nothing at [p], perfectly: the identity of the chain product.
  const _Way.unit(int p) : this(p, 0, 0, 0, _peg);

  /// Deny the characters in `[from, to)`.
  _Way.skip(int from, int to)
      : this(to, to - from, 0, 0, from,
            mark: SyntaxError(pos: from, len: to - from));

  /// Owe [n] obligations at [p], having matched nothing for them.
  ///
  /// AT THE END OF THE INPUT, EVERY OBLIGATION IS ONE CLAIM: "the document
  /// stopped here." Under I33 cost is the width of the description, and the
  /// description of a truncation is one position -- the grammar itself
  /// enumerates what is missing, so the reader is told nothing more by charging
  /// each absent character separately. Charging per character made "keep the
  /// construct the writer started and owe its tail" (4 marks) lose to "close
  /// the construct empty and DENY the characters the writer wrote" (2 deletions
  /// + 1 mark) on every short truncation -- the engine was paying extra to
  /// throw evidence away. So an owe at [_in.length] sets [eof] instead of
  /// raising [gap], and [edits] charges the bit once, however many marks it
  /// stands for. The marks are still all emitted: the claim is priced as one,
  /// not silenced.
  _Way.owe(int p, int n, {bool atEof = false})
      : this(p, 0, atEof ? 0 : n, 0, p,
            mark: SyntaxError(pos: p, len: 0), owing: true, eof: atEof ? n : 0);

  final int end;

  /// How much of the document this way takes at FACE VALUE: [_peg] where it is
  /// PEG's own reading, [_far] where it reads clean but is not, and otherwise
  /// the position of its earliest repair.
  ///
  /// Every character before that position was read exactly as the document
  /// supplied it. Checked over four million ways: where this is below [_far] it
  /// equals the earliest [SyntaxError] position in the tree the way heads, so
  /// the field is an O(1) memo of the tree and not an independent claim.
  final int key;

  /// Whether this is the reading the frozen parser itself would take.
  bool get peg => key > _far;

  /// Characters DISCARDED, and obligations left UNMET. Kept apart rather than
  /// summed because they are not the same claim: see [Squirrel._rank].
  final int del, gap;

  /// Characters matched by a terminal that CONSTRAINS what it accepts.
  ///
  /// `.` and an inverted set accept anything, or all but one thing, so matching
  /// one consumes a character without explaining it. This separates two
  /// readings that cost the same and cover the same text: `[1,[2,` read as one
  /// String matches all six characters through `[^"\]`, asserting nothing about
  /// any of them, where the Array reading pins `[`, `,` and both digits. It is
  /// what stops a damaged document being re-read as one long string.
  final int net;

  /// How many of this reading's repaired rule nodes ABSORBED MORE THAN THEY
  /// PINNED -- how many places it swallowed. A sum, because a reading that
  /// swallows twice is worse than one that swallows once; saturating it at one
  /// leaves the same swallows but costs 0.0004 of battery, and it is `transpose`
  /// and `junk-insert` that pay, so the count is doing work beyond this case.
  ///
  /// IT RANKS ALONGSIDE [del] AND [gap], AND IT IS NOT SPENT FROM THE BUDGET.
  ///
  /// It must rank, because [Squirrel._prune] keeps one way per end position by
  /// cost alone: on `"1,[2,[3,[4]]],5]` the swallow and the honest `Array` both
  /// end at 17, the swallow costs 1 and the `Array` 2, so the honest reading is
  /// destroyed inside the chart and a price charged at the top never gets to
  /// speak. A PRICE THE PRUNING CANNOT SEE IS NOT A PRICE.
  ///
  /// It must not be spent, because spending it buys a whole deepening round for
  /// every repaired string there is -- a `String` pins two quotes and absorbs
  /// its entire body, so every truncation trips it. Measured, that costs 2.94x
  /// the latency, p99 7.83x, and its worst single case is a TRUNCATION:
  /// `{"alpha":"beta gamma","delta":["epsilon","zet` went from 9.8 ms to 104 ms
  /// to re-decide a question it was never going to lose.
  ///
  /// SO THIS DOES NOT REPLACE THE BUDGET CHARGE LEVIED ONCE AT THE WHOLE
  /// DOCUMENT in [Squirrel.recover]. They do different jobs, and the four
  /// measurements say so plainly -- json's worst swallow, as a share of the
  /// document:
  ///
  ///     neither        94%   `[1,..,5"` and `"1,..,5]` both swallowed
  ///     document only  94%   the trailing shape fixed, the leading one not
  ///     this only      94%   NEITHER shape fixed
  ///     both           42%
  ///
  /// The budget charge BUYS THE ROUND and this counter KEEPS THE RIVAL ALIVE
  /// INSIDE IT. Ranking can only separate readings that exist at the same time,
  /// and in round 1 the honest `Array` costs 2 and is never built, while the
  /// swallow costs 1 and is accepted before any deeper round runs -- so ranking
  /// alone fixes nothing here. Deferring the swallow to round 2 is what makes
  /// its rival exist; and where the two then end at the SAME position, as they
  /// do on `"1,[2,[3,[4]]],5]`, [_prune] would delete the rival on cost before
  /// the document is ever reached, which is what this stops.
  ///
  /// Together they catch every swallow whose honest rival is affordable at the
  /// same budget, and no others. `i"f (a) { b=1; } ...` is what is left: the
  /// swallow costs 2 there and the honest reading 4, so it needs a deeper
  /// search, not a price.
  final int toll;

  /// A NODE IS A PROMISE UNTIL SOMETHING ACCEPTS THE WAY. [leaf] is a finished
  /// node -- a terminal's, which is the evidence itself and is one object with
  /// no children to collect. Every other way records only WHAT its node would
  /// be: clause [cap] over `[from, end)`, its children the nodes along [link].
  /// Measured, 94% of the nodes this engine built were thrown away by a choice
  /// made somewhere above them, so none is built until one is chosen.
  final MatchResult? leaf;
  final Clause? cap;
  final int from;

  /// A chain LINK's own step, or a capped way's chain -- never both, because a
  /// way that wears a node is not also a step of the chain under it.
  final _Way? link;
  final _Way? prev;
  final SyntaxError? mark;

  /// Whether the LAST thing this way did was leave an obligation unmet, with
  /// nothing consumed since. An obligation says the document ran out; this is
  /// the bit that says it ran out HERE, at [end], with nothing after it to say
  /// otherwise. It is a monoid like every other counter -- an obligation sets
  /// it, consuming anything clears it, and reading nothing leaves it alone --
  /// and it is associative because positions only ever grow, so `v.end == end`
  /// composes the same either way it is bracketed.
  final bool owing;

  /// Absorbed characters ALREADY JUDGED, so no cap above judges them again.
  /// A node's toll asks "did this take more than it pinned", and both the
  /// question and its absolution are local: a free subtree's absorption is the
  /// frozen parser's own reading (a String's contents), and a tolled node has
  /// paid for everything below it. Without this the same five characters of
  /// string content were re-judged by every Ref between them and the root, so
  /// an honest truncation of `{"alpha"` carried two tolls and lost to denying
  /// the `{` -- the toll designed against the swallow was firing on the
  /// reading it exists to protect.
  final int vouch;

  /// How many obligations this way owes at the very end of the input. They are
  /// CHARGED once -- "it stopped here" is one claim, see [_Way.owe] -- but they
  /// are COUNTED, because two readings that both stop can still differ in how
  /// much they assert was under way: on `1*`, owing Term's missing Factor is
  /// one mark, and wrapping that in a left-recursive Expr that also owes an
  /// AddOp and a Term is three, all at the same one-point price. The count is
  /// how [_rank] prefers the smaller claim (I33: at equal cost, the narrower
  /// description wins).
  final int eof;

  /// What this way costs the budget: deletions, mid-document obligations, and
  /// the end-of-input claim charged ONCE.
  int get edits => del + gap + (eof > 0 ? 1 : 0);

  /// Whether this way stands for a node at all. A deletion and an unmet
  /// obligation do not: they are a mark and no child, which is what they claim.
  bool get nodes => leaf != null || cap != null;

  /// Whether this way repairs nothing -- READ OFF THE SAME FIELD. A way with an
  /// edit in it has a first edit, and [key] is where that falls, so "costs
  /// nothing" and "takes the whole document at face value" are not two facts:
  /// measured over four million ways, `del == 0 && gap == 0` holds exactly when
  /// [fix] is [_far]. The three questions the engine asks about a reading --
  /// is it clean, is it PEG's, and where does it stop trusting the input --
  /// are three thresholds on one number.
  bool get free => key >= _far;

  /// THE CHAIN PRODUCT. Reading [this] and then [v] costs what both cost,
  /// explains what both explain, and takes at face value only as much as the
  /// earlier of the two did. Three sums and one minimum -- and because every
  /// counter is an aggregate over the tree, that IS what concatenating the trees
  /// does to them. A sequence is this folded over its slots and a repetition is
  /// it starred; a deletion and an unmet obligation are two more elements to
  /// fold in, not two more rules.
  _Way then(_Way v) =>
      _Way(v.end, del + v.del, gap + v.gap, net + v.net, _min(key, v.key),
          toll: toll + v.toll,
          link: v,
          prev: this,
          mark: v.mark,
          owing: v.owing || (v.end == end && owing),
          eof: eof + v.eof,
          vouch: vouch + v.vouch);

  /// The same way under a node of its own, the chain behind it already closed
  /// -- taking the document at face value no further than [k], which defaults
  /// to no further than it already did.
  _Way over(MatchResult n, [int k = _peg]) => _Way(end, del, gap, net,
      _min(key, k), toll: toll, leaf: n, owing: owing, eof: eof, vouch: vouch);

  /// The same way wearing [c]'s node over `[pos, end)`, the chain behind it
  /// KEPT rather than collected -- what the node will be, not the node.
  _Way capped(Clause c, int pos, [int k = _peg, int ate = 0, int vouched = 0]) =>
      _Way(end, del, gap, net, _min(key, k),
          toll: toll + ate, cap: c, from: pos, link: this, owing: owing,
          eof: eof, vouch: vouched > vouch ? vouched : vouch);

  /// No longer PEG's reading -- but still whatever else it was.
  _Way get demoted => _Way(end, del, gap, net, _min(key, _far),
      toll: toll,
      leaf: leaf,
      cap: cap,
      from: from,
      link: link,
      prev: prev,
      mark: mark,
      owing: owing,
      eof: eof,
      vouch: vouch);
}

/// One memo cell: every way its clause can be read from its position.
///
/// [inPath], [foundLR] and [gen] are the frozen `MemoEntry`'s three fields,
/// doing the frozen parser's job unchanged.
class _Cell {
  List<_Way> ways = const [];
  bool inPath = false, foundLR = false, has = false;
  int gen = -1;

  /// The budget these ways were computed under. A cell computed at a HIGHER
  /// budget answers a cheaper question by filtering; only a higher one has to
  /// be recomputed, and then what is already here is kept.
  int at = -1;
}

class Squirrel {
  Squirrel({required Map<String, Clause> rules, required this.topRuleName}) {
    for (final e in rules.entries) {
      final n = e.key.startsWith('~') ? e.key.substring(1) : e.key;
      this.rules[n] = e.value;
    }
  }

  final Map<String, Clause> rules = {};
  final String topRuleName;

  late String _in;

  /// The frozen parser, held for ONE reason: so that reading a terminal is the
  /// library's own [Terminal.match] and not a second implementation of it here.
  /// A recovering parser that disagrees with the parser it is recovering for --
  /// about a character class, about a surrogate pair, about anything -- is
  /// wrong by construction, and the only way not to disagree is not to have an
  /// opinion. It costs one `List.filled(n + 1, 0)` per call, which is the same
  /// allocation [recover] already makes for [_version].
  late Parser _ref;

  /// Every clause at every position, not just every rule: a chart's inner
  /// clauses are re-entered from as many chains as reach them.
  /// A ROW PER CLAUSE, INDEXED BY POSITION: the positions of an input are
  /// `[0, length]`, so a clause's cells are an array and not a dictionary, and
  /// the inner lookup is an index rather than a hash.
  final Map<Clause, List<_Cell?>> _memo = {};

  /// The frozen parser's per-position memo version.
  late List<int> _version;

  /// Memo for [_determined]: a property of the grammar, so it outlives a parse.
  final Map<Clause, bool> _det = {};

  /// Memo for [_minFill], likewise a property of the grammar alone.
  final Map<Clause, int> _fill = {};
  static const int _never = 1 << 30;

  /// What the emitted tree leaves unaccounted for.
  int lastCost = 0;

  /// This round's ceiling on the total cost of a way.
  ///
  /// Cost is additive and never negative, so a partial way's cost is a lower
  /// bound on every completion of it: discarding one that already exceeds the
  /// ceiling discards nothing that could have been the answer. The cut is
  /// exact, which is what makes deepening a search for the CHEAPEST repair
  /// rather than a heuristic for a cheap one.
  ///
  /// At 0 this is the frozen parser: no fill and no skip can be afforded, so
  /// every way is free and the chart is one PEG parse wide.
  /// This round's budget, which [_budget] is the unspent remainder of.
  int _round = 0;
  int _budget = 0;

  // -- the ordering ----------------------------------------------------------

  /// Fewest edits; PEG's own reading ahead of any other of the same cost; among
  /// equals the reading that EXPLAINS the most; among those, fewest DELETIONS.
  ///
  /// `net` ahead of `del` is measured, and the two disagree exactly where it
  /// matters. Fewest deletions is only a PROXY for keeping the input, and it
  /// inverts on the cheapest destructive repair there is: filling one opening
  /// quote costs a single gap and lets `Chr*` swallow the rest of the document
  /// through `[^"\]`, which deletes nothing, explains nothing, and loses every
  /// construct it covers -- while the honest reading spends several deletions
  /// and keeps everything after them. `net` measures what the proxy stood for.
  static int _rank(_Way a, _Way b) {
    final ea = a.edits + a.toll, eb = b.edits + b.toll;
    if (ea != eb) return ea - eb;
    if (a.peg != b.peg) return a.peg ? -1 : 1;
    if (a.net != b.net) return b.net - a.net;
    // The end-of-input mark count deliberately does NOT rank. Both directions
    // were measured: ranking fewer-marks-first kills the deep completions the
    // truncate corpus wants (0.983 -> 0.974), ranking on the sign kills honest
    // completions wherever a mid-document rival ties (0.973), and how much a
    // stopped reading says was under way is a bet on a continuation the
    // evidence cannot decide. List order stands (I30), and the residual it
    // costs is three quote-delete cases.
    // LAST, AND ONLY WHERE EVERYTHING ELSE TIES: the reading that takes the
    // LONGER PREFIX at face value. Two readings that cost the same, explain the
    // same and destroy the same still disagree about WHERE the document went
    // wrong, and every character before the first repair is one the reading
    // accepts as written -- so the later that repair falls, the more of the
    // document the reading is not second-guessing. On `a*(b+` this is the whole
    // difference between closing the parenthesis before the `+`, which asserts
    // an error at column 4, and running out of input at column 5, which asserts
    // nothing the input did not already say.
    return b.key - a.key;
  }

  /// One way per end position -- the best -- and one PEG way in the cell.
  ///
  /// Every distinct end is kept, because which one an enclosing clause needs is
  /// not knowable here: `Character*` must offer to stop at every position for
  /// `String` to find the one where its closing quote belongs. What is dropped
  /// is only a worse way to an end some better way already reaches.
  ///
  /// A shorter PEG reading is not one: the frozen parser would have grown past
  /// it. Demoting rather than deleting keeps it available as a repair.
  List<_Way> _prune(List<_Way> ws) {
    if (ws.length <= 1) return ws;
    // THE FIRST ROUND IS THE FROZEN PARSER, SO IT SHOULD DO THE FROZEN
    // PARSER'S WORK -- not find PEG's answer among all the others.
    //
    // A clean way that is not PEG's reading is already dead when this round
    // makes it. [then] takes the MINIMUM key, so any chain holding one is at
    // most `_far`, and `recover` refuses exactly `_far`; buying it would take a
    // repair somewhere, and this round has nothing to spend. So here a cell
    // holds ONE way -- PEG's -- or none, which is what a PEG parser's memo
    // entry holds. That deletes the entire cross product a sequence of
    // repetitions was exploring over input with nothing wrong with it:
    // `S <- W W W W W W W W` on clean text went from quadratic to linear.
    //
    // A cell with one way is left alone. Dropping its way too would be
    // sound -- the root refuses it -- but there is no cross product to cut
    // in a cell that offers a single reading, and this is the commonest
    // call the engine makes.
    //
    // The test is the ROUND and not the budget. A later round spends its way
    // down to a residual of 0, and the move and resync probes ask at 0 on
    // purpose -- but those want a slot that reads CLEANLY, not one that reads
    // as PEG would, and their chain has already paid, so its key is below
    // `_far` and the root will take it. Only in the first round are the two
    // questions the same one, and only there is nothing else affordable.
    // TWO WAYS NEED NO INDEX: measured, a call with anything to decide holds
    // two of them more often than every larger size put together, and for two
    // the map, the copy and the sort are all one comparison.
    if (ws.length == 2) {
      final a = ws[0], b = ws[1];
      if (a.end == b.end) return [_rank(a, b) <= 0 ? a : b];
      final both = a.peg && b.peg;
      final x = both && a.end < b.end ? a.demoted : a;
      final y = both && b.end < a.end ? b.demoted : b;
      return _rank(x, y) <= 0 ? [x, y] : [y, x];
    }
    final best = <int, _Way>{};
    var far = -1;
    for (final w in ws) {
      if (w.peg && w.end > far) far = w.end;
      final b = best[w.end];
      if (b == null || _rank(w, b) < 0) best[w.end] = w;
    }
    final out = [
      for (final w in best.values) w.peg && w.end != far ? w.demoted : w
    ]..sort(_rank);
    return out;
  }

  // -- the parser ------------------------------------------------------------

  /// Every way [c] can be read from [pos], memoized, with the frozen parser's
  /// left-recursion loop around it.
  List<_Way> _ways(Clause c, int pos) {
    if (pos > _in.length) return const [];
    // A CLAUSE THAT CANNOT CALL ITSELF NEEDS NO CELL. Everything the cell
    // carries -- the nested lookup, the two cycle flags, the monotone loop and
    // its version stamp -- exists for re-entry. A clause with no subclauses has
    // nothing to re-enter through, and a reference's own cell only shadows the
    // rule body's, which is where the cycle is detected and the fixed point is
    // actually taken. Between them these are most of the lookups the engine
    // makes, and every one was paying for a loop that could run only once.
    // AND A REFERENCE NEEDS NO PRUNE. The rule body's ways are already one per
    // end and already in rank order; [_lift] neither reorders them nor merges
    // two into one end, and it cannot drop the farthest PEG way, because a PEG
    // way is free and free ways it keeps. Every decision [_prune] would make
    // here has been made. Measured: 2,354,118 calls, all returning the input.
    if (c is Ref) return _lift(c, pos, _ways(rules[c.ruleName]!, pos));
    if (c is! HasOneSubClause && c is! HasMultipleSubClauses) {
      return _prune(_terminal(c, pos));
    }
    final row = _memo[c] ??= List<_Cell?>.filled(_in.length + 1, null);
    final e = row[pos] ??= _Cell();
    if (e.inPath) {
      if (e.has) return e.ways;
      // Re-entered on the same path with nothing yet decided: the seed of a
      // left-recursive cycle. Answer with nothing, and tell the frame that
      // owns this cell -- however far above -- to expand it.
      e.foundLR = true;
      e.has = true;
      return e.ways = const [];
    }
    if (e.has && e.gen == _version[pos] && e.at >= _budget) {
      return e.at == _budget ? e.ways : _afford(e.ways);
    }
    e.inPath = true;
    while (true) {
      // Accumulate: an expansion computed from a smaller seed, or under a
      // smaller budget, is still a real derivation, and keeping it makes the
      // sequence of answers monotone -- so "while it improves" is guaranteed
      // to stop, and a round never re-derives what an earlier round found.
      final got = _prune([..._expand(c, pos), ..._afford(e.ways)]);
      final done = e.has && !_improved(got, e.ways);
      e.ways = got;
      e.has = true;
      e.at = _budget;
      if (done || !e.foundLR) break;
      e.gen = ++_version[pos];
    }
    e.inPath = false;
    e.gen = _version[pos];
    e.at = _budget;
    return e.ways;
  }

  /// The ways in [ws] this round can still afford -- a PREFIX of it.
  ///
  /// [_rank] orders by total cost first, so a cell's ways come out ordered by
  /// what they cost: the budget question and the ranking question are answered
  /// by the same order, and where the dearest way is affordable there is no
  /// question left to ask. The argument is always a [_prune] result, which
  /// sorts by [_rank], so the prefix is a property of the caller and not a
  /// hope; measured over the battery it held on all 2,377,870 calls, of which
  /// 91.1% dropped nothing.
  List<_Way> _afford(List<_Way> ws) {
    if (ws.isEmpty || ws.last.edits <= _budget) return ws;
    var n = 0;
    while (ws[n].edits <= _budget) {
      n++;
    }
    return ws.sublist(0, n);
  }

  /// Both ways an answer can get better: reaching further, or costing less.
  /// AN ANSWER GOT BETTER IF ANY OF IT DID. [a] is [b] merged with a fresh
  /// expansion, so it can only be better -- and then "did it improve" is just
  /// "is it the same list", position by position. Asking only whether the
  /// FARTHEST end moved or the BEST way changed stopped the loop on a cell
  /// whose middle improved, leaving a left-recursive fixed point half taken.
  static bool _improved(List<_Way> a, List<_Way> b) {
    if (a.length != b.length) return true;
    for (var i = 0; i < a.length; i++) {
      if (a[i].end != b[i].end || _rank(a[i], b[i]) != 0) return true;
    }
    return false;
  }

  /// [_ways] answers every [Ref] itself, so this is never asked one.
  List<_Way> _expand(Clause c, int pos) {
    if (c is Seq) return _seq(c, pos);
    if (c is First) return _first(c, pos);
    if (c is Repetition) return _rep(c, pos);
    if (c is Optional) return _opt(c, pos);
    // A predicate consumes nothing, so it can carry no repair anywhere the
    // enclosing parse could see it. It is asked of the input as it stands.
    if (c is FollowedBy || c is NotFollowedBy) {
      final sub =
          c is FollowedBy ? c.subClause : (c as NotFollowedBy).subClause;
      final ok = _ways(sub, pos).any((w) => w.free);
      return (c is FollowedBy) == ok
          ? [_Way.unit(pos).over(Match(c, pos, 0))]
          : const [];
    }
    return _terminal(c, pos);
  }

  /// Put the rule's own node around each of its body's ways -- and drop the
  /// ways that would make that node an invention.
  ///
  /// A repaired node that EXPLAINS NOTHING is one. r2 refused only the node
  /// covering no characters at all, which is the special case where explaining
  /// nothing is obvious: a zero-width `Value` claims an object or an array or a
  /// number happened with not one character to show for it. But `[1,[2,` read
  /// as a String claims exactly as little while covering six characters, since
  /// both of its quotes were supplied by the repair and every character between
  /// them went to `[^"\]`, which accepts anything. Neither reading is evidenced,
  /// and [_Way.net] already counts the evidence, so both are the same refusal.
  ///
  /// It is honest where the grammar FIXES what the construct would have looked
  /// like -- `'}'`, or an `A <- [ab]` that is one leaf either way -- because
  /// then the mark claims nothing the grammar had not already said.
  ///
  /// AND WHETHER IT SWALLOWED IS DECIDED HERE, because this is where a rule's
  /// node goes on and the span it covers is known. `net > 0` above is a floor,
  /// not a comparison: one real quote is enough to buy sixteen characters of
  /// `[^"\]`. The comparison is what that floor cannot make -- did this node
  /// take more than it pinned -- and its answer goes into [_Way.toll], which
  /// ranks. Levying it here rather than at the document is the whole point:
  /// [_prune] resolves the swallow against its honest rival long before the
  /// document is reached.
  ///
  /// Only for a repaired node, so round 0 stays the frozen parser.
  List<_Way> _lift(Ref c, int pos, List<_Way> ways) => [
        for (final w in ways)
          if (w.net > 0 || w.free || _determined(c))
            _judge(c, pos, w)
      ];

  /// The swallow judgment, made once per span: absorption a free subtree or a
  /// toll below has already accounted for is vouched, not re-judged.
  _Way _judge(Ref c, int pos, _Way w) {
    final absorbed = (w.end - pos) - w.del - w.net;
    final fresh = absorbed - w.vouch;
    final ate = !w.free && fresh > w.net ? 1 : 0;
    return w.capped(c, pos, _peg, ate,
        w.free || ate > 0 ? (absorbed > w.vouch ? absorbed : w.vouch) : w.vouch);
  }

  /// A sequence: carry the chains forward slot by slot, and where a slot cannot
  /// be read at the position the last one left, either discard the characters
  /// in front of it or record it as unmet.
  List<_Way> _seq(Seq c, int pos) {
    final stops = <_Way>[];
    final moved = <_Way>[];
    var cur = <_Way>[_Way.unit(pos)];
    var whole = true;
    for (var i = 0; i < c.subClauses.length; i++) {
      final sub = c.subClauses[i];
      final next = <_Way>[];
      for (final w in cur) {
        // A prefix that has already overspent the round has no completion at
        // all, so it is not asked: without this the residual below goes
        // negative and every slot is looked up only to be thrown away. The
        // prefixes arrive in cost order, so the first that overspends ends the
        // slot: every prefix behind it costs at least as much.
        if (w.edits > _budget) break;
        // ASK FOR WHAT THE PREFIX CAN STILL AFFORD. `w` has spent `w.del +
        // w.gap` of the round, so a slot reading that costs more than the rest
        // cannot appear in any completion, and asking at the residual stops it
        // from being built at all. At residual 0 this is the frozen parser.
        final full = _budget;
        _budget = full - w.edits;
        final here = _ways(sub, w.end);
        _budget = full;
        // Discarding input in front of a slot is offered only where the slot
        // cannot be read where it stands. Offering it anyway would let any
        // sequence buy length by throwing the input away. The question is
        // answered while the readings are carried forward, since that walk is
        // over the same list.
        //
        // A NULLABLE SLOT COUNTS AS REACHED, and that is correct even though it
        // looks like the swallow's door. `Array <- '[' WS (Value (',' WS
        // Value)*)? WS ']'` on `"1,[2,[3,[4]]],5]` never gets offered the resync
        // that would discard the leading quote, because the optional body
        // matches empty at 0 and an empty match is free. Requiring the slot to
        // consume before it counts opens that resync -- and measured, it changes
        // no swallow and costs 546 ms, because the swallow was never losing on
        // reachability. It was losing on price, inside [_prune]. See [_Way.toll].
        var clean = false;
        for (final v in here) {
          next.add(w.then(v));
          if (v.free) clean = true;
        }
        if (clean) continue;
        // GIVE THE SLOT UP AND CARRY ON -- but only where nothing else
        // reached it. A production may move, resynchronize past input it does
        // not want, or say this part was never supplied and go on to the next;
        // only the last repairs a part that is MISSING rather than surrounded
        // by junk, and only it asserts something on no evidence at all. So it
        // is offered where the other two found nothing, which is the same rule
        // [_first] already applies to a damaged arm: a reading that explains
        // what it takes outranks one that assumes it. A STOP IS NOT REACHING
        // IT: the production ends there, so the slot is still unaccounted for.
        var reached = false;
        if (i == 0) {
          // AND A PRODUCTION THAT HAD TO MOVE MUST FIT WHERE IT MOVED TO.
          // Discarding in front of the FIRST slot does not resynchronize
          // within this production: nothing of it has been read yet, so there
          // is no left bracket to be inside of. It moves the WHOLE production
          // somewhere else, and the only evidence that it belongs there is
          // that it fits there, entire. `[1,[2,` read as a `String` that
          // begins at the second character and then still needs its closing
          // quote supplied is not a String that moved; it is a String invented
          // around whatever the deletion happened to leave behind.
          for (var k = pos + 1; k <= pos + _budget && k <= _in.length; k++) {
            final full = _budget;
            _budget = 0; // it must read cleanly there; the move is the cost
            var chain = <_Way>[w.then(_Way.skip(pos, k))];
            for (final s in c.subClauses) {
              final step = <_Way>[];
              for (final x in chain) {
                for (final v in _ways(s, x.end)) {
                  if (!v.free) continue;
                  step.add(x.then(v));
                }
              }
              chain = _prune(step);
              if (chain.isEmpty) break; // it does not fit here; stop asking
            }
            _budget = full;
            if (chain.isEmpty) continue;
            moved.addAll(chain);
            reached = true;
            break;
          }
        } else {
          // THE PRODUCTION STOPS, owing what the rest of it would have cost,
          // and contributes NO NODE for any of it. Stopping is the whole of the
          // claim: carrying on to fill a closing bracket whose body never
          // arrived would assert a part that was never reached, and it is the
          // difference between saying "this ended here" and saying "an object
          // was here". `w.end > pos` keeps it from inventing a production that
          // was never entered.
          //
          // THIS IS A SHORTCUT, NOT A RULE. [_owed] is by construction the sum
          // of [_minFill] over the remaining slots, so a stop costs exactly
          // what the give-up chain below costs over the same slots -- it is
          // that chain telescoped. And it is NOT confined to the end of the
          // input, which is what the shape of the argument suggests it should
          // be: guarding it with `w.end == _in.length` was measured to produce
          // identical trees AND costs to deleting it outright, on all 1824
          // cases. Where the document really does stop, the chain reaches the
          // same end at the same price. So everything this branch does, it does
          // MID-DOCUMENT -- letting a production abandon its tail while input
          // remains -- and that is worth 48 differing trees and 0.0002 of
          // score. Occasion 70 has the measurements.
          final owed = w.end > pos ? _owed(c, i) : 0;
          final atEof = w.end == _in.length;
          final chg = atEof ? (w.eof > 0 ? 0 : 1) : owed;
          if (owed > 0 && owed < _never && w.edits + chg <= _budget) {
            var x = w;
            for (var j = 0; j < owed; j++) {
              x = x.then(_Way.owe(w.end, 1, atEof: atEof));
            }
            stops.add(x);
          }
          // And only as far as the FIRST position where it can be read
          // cleanly. Discarding more costs strictly more, so the nearest place
          // the slot reappears is the cheapest resynchronization there is;
          // scanning past it would price the same repair several ways over.
          final room = _budget - w.edits;
          for (var k = w.end + 1; k <= w.end + room && k <= _in.length; k++) {
            final full = _budget;
            _budget =
                0; // the slot itself must read cleanly; the skip is the cost
            final at = _ways(sub, k);
            _budget = full;
            if (at.isEmpty) continue;
            final past = w.then(_Way.skip(w.end, k));
            for (final v in at) {
              // The slot must read CLEANLY where it resumes: the discarded run
              // is the whole price of the resynchronization, so a slot that
              // still needs repairing there has not resynchronized. (Requiring
              // it to CONSUME as well is dead code, not a missing guard -- a
              // nullable slot matches empty for free at `w.end`, which sets
              // `clean` above and never reaches here.)
              if (!v.free) continue;
              next.add(past.then(v));
              reached = true;
            }
            break;
          }
        }
        if (reached) continue;
        // ONE MARK PER OBLIGATION, exactly as the stop above emits them. The
        // charge is read back off the tree, so a single mark standing for
        // [fill] obligations is a repair the tree does not show: on `if (a`
        // the slot costs 2 and one mark reports 1. The engine may not charge
        // the budget for something it then declines to say.
        final fill = _minFill(sub);
        final atEof = w.end == _in.length;
        final chg = atEof ? (w.eof > 0 ? 0 : 1) : fill;
        if (fill > 0 && fill < _never && w.edits + chg <= _budget) {
          // MID-DOCUMENT, AN OWED SLOT IS STILL A PLACE IN THE TREE. The
          // grammar demanded the slot, so "a Value belongs here" is the
          // grammar's own claim, not an invention -- and the reader was going
          // to be shown a bare mark where the damage deleted a whole
          // construct. The node names the slot and descends exactly as far as
          // the grammar FORCES: through references, one-or-more bodies, the
          // single unfillable-for-nothing element of a sequence, and an
          // ordered choice only where a UNIQUE arm is cheapest to satisfy --
          // one more step would be choosing, which is I36's line. At the end
          // of the input the node is withheld (I81): there the slot is not a
          // construct the damage broke, it is one the writer never reached.
          final spine = atEof ? null : _owedNode(sub, w.end, fill);
          if (spine != null) {
            next.add(w.then(_Way(w.end, 0, fill, 0, w.end,
                leaf: spine, owing: true)));
          } else {
            var x = w;
            for (var j = 0; j < fill; j++) {
              x = x.then(_Way.owe(w.end, 1, atEof: atEof));
            }
            next.add(x);
          }
        }
      }
      if (next.isEmpty) {
        whole = false;
        break;
      }
      cur = _prune(next);
    }
    // A stop and a move already carry a repair, so neither can still be PEG's
    // reading and neither needs demoting: closing them is closing any chain.
    // AND CHOOSE BEFORE BUILDING, as [_rep] does: closing a chain walks it and
    // collects its children, and [_rank] reads none of that.
    return [
      for (final w in _prune([if (whole) ...cur, ...stops, ...moved]))
        w.capped(c, pos)
    ];
  }

  /// The named nodes the grammar FORCES for an owed slot at [p], or null where
  /// it forces none. The descent stops at any real choice: a `First` is entered
  /// only where a unique arm is cheapest to satisfy, so nothing here ever picks
  /// what the evidence could not.
  MatchResult? _owedNode(Clause sub, int p, int fill) {
    final chain = <Clause>[];
    var c = sub;
    for (var guard = 0; guard < 64; guard++) {
      if (c is Ref) {
        chain.add(c);
        c = rules[c.ruleName]!;
        continue;
      }
      if (c is Repetition && c.requireOne) {
        c = c.subClause;
        continue;
      }
      if (c is Seq) {
        Clause? nz;
        var many = false;
        for (final k in c.subClauses) {
          if (_minFill(k) > 0) {
            if (nz != null) many = true;
            nz = k;
          }
        }
        if (nz == null || many) break;
        c = nz;
        continue;
      }
      if (c is First) {
        Clause? best;
        var min = _never;
        var many = false;
        for (final k in c.subClauses) {
          final v = _minFill(k);
          if (v < min) {
            min = v;
            best = k;
            many = false;
          } else if (v == min) {
            many = true;
          }
        }
        if (best == null || many || min >= _never) break;
        c = best;
        continue;
      }
      break;
    }
    if (chain.isEmpty) return null;
    MatchResult node = Repaired(chain.last, p, 0, const [],
        [for (var j = 0; j < fill; j++) SyntaxError(pos: p, len: 0)]);
    for (var i = chain.length - 2; i >= 0; i--) {
      node = Repaired(chain[i], p, 0, [node], const []);
    }
    return node;
  }

  /// What slots [i] onwards of [c] are owed, if the input stops before them:
  /// the fewest obligations each can be left holding while matching nothing.
  /// Same currency as a fill, because it IS the fills that were never bought.
  int _owed(Seq c, int i) {
    var n = 0;
    for (var j = i; j < c.subClauses.length; j++) {
      final v = _minFill(c.subClauses[j]);
      if (v >= _never) return _never;
      n += v;
    }
    return n;
  }

  /// An ordered choice. Every arm contributes, so a later arm can carry the
  /// parse where an earlier one is damaged -- but PEG is exact where nothing is
  /// damaged: once an arm reads cleanly, no later arm's reading is PEG's.
  List<_Way> _first(First c, int pos) {
    final out = <_Way>[];
    var settled = false;
    for (final s in c.subClauses) {
      final ws = _ways(s, pos);
      for (final w in ws) {
        // Once an arm has read the input AS IT STANDS, the choice belongs to
        // the document. A later arm may still carry the parse where it too
        // reads cleanly, and where its reading is more evidence than
        // assumption -- but it may not take the choice from a clean reading
        // with a repair that explains less of what it takes than it helps
        // itself to. An `Array` whose `[` was supplied still accounts for
        // every character inside it; a `Str` whose quote was supplied and
        // whose body is `[^"\\]` accounts for nothing but its own closing
        // quote, and would swallow three statements to say so.
        if (settled && !w.free && (w.end - pos) - w.del - w.net >= w.net) {
          continue;
        }
        out.add(w.capped(c, pos, settled ? _far : _peg));
      }
      settled = settled || ws.any((w) => w.peg);
    }
    return out;
  }

  /// A repetition as reachability: every end an iteration chain can reach.
  ///
  /// Only iterations that ADVANCE are chained, which is both what stops `()*`
  /// from looping forever and what bounds this: each step strictly increases
  /// the end position, so no chain is longer than the input.
  List<_Way> _rep(Repetition c, int pos) {
    final zero = _Way.unit(pos);
    // A WORKLIST, NOT A SERIES OF ROUNDS. Every step strictly advances, so the
    // ends form a forward-only graph and the best way to a position can be
    // relaxed in place. A round that finds no better way to a position it has
    // already reached has found nothing to carry forward, and re-extending the
    // way it already extended only rebuilds what the prune above throws away.
    // What gets expanded is exactly what improved.
    final best = <int, _Way>{if (!c.requireOne) pos: zero};
    var frontier = <_Way>[zero];
    while (frontier.isNotEmpty) {
      final moved = <int>{};
      for (final w in frontier) {
        for (final v in _ways(c.subClause, w.end)) {
          if (v.end <= w.end) continue;
          final x = w.then(v);
          final b = best[x.end];
          if (b != null && _rank(x, b) >= 0) continue;
          best[x.end] = x;
          moved.add(x.end);
        }
      }
      frontier = [for (final e in moved) best[e]!];
    }
    final all = best.values.toList();
    // A `+` the input supplied no occurrence of owes exactly ONE, and never
    // more. The guard above rightly refuses a zero-width iteration to a
    // repetition that is already growing -- that is the loop it would spin in
    // forever -- but a `+` with nothing at all is the one place a zero-width
    // occurrence is what the grammar REQUIRES rather than a way to grow.
    if (all.isEmpty) {
      for (final v in _ways(c.subClause, pos)) {
        if (v.end != pos) continue;
        all.add(zero.then(v).demoted);
      }
    }
    // AND CHOOSE BEFORE BUILDING. Chains of different lengths finish at the
    // same position, so `all` holds ways an enclosing prune discards -- 35.1%
    // of them, measured -- and closing a chain is the dearest thing here: it
    // walks the chain and collects its children. Ranking reads none of that.
    return [for (final w in _prune(all)) w.capped(c, pos)];
  }

  List<_Way> _opt(Optional c, int pos) {
    final ws = _ways(c.subClause, pos);
    return [
      _Way.unit(pos).over(Match(c, pos, 0), ws.any((w) => w.peg) ? _far : _peg),
      for (final w in ws) w.capped(c, pos)
    ];
  }

  /// A terminal reads the input, or -- where the input does not carry it -- is
  /// recorded as one obligation the input never supplied. Nothing is spelled,
  /// so no character of an absent class is ever invented.
  List<_Way> _terminal(Clause c, int pos) {
    final m = (c as Terminal).match(_ref, pos);
    // ASK WHETHER IT MATCHED, NOT HOW LONG IT IS. This read `m.len >= 0` back
    // when a mismatch was one shared tombstone with `len == -1`. A mismatch now
    // reports the input it consumed before failing, so `Str` returning the
    // length of the prefix the input did supply would be taken here for a match
    // of that length -- `fun` of `function` would be accepted as a keyword.
    if (!m.isMismatch) {
      final n =
          c is Str || c is Char || (c is CharSet && !c.inverted) ? m.len : 0;
      return [_Way(pos + m.len, 0, 0, n, _peg, leaf: m)];
    }
    if (_budget < 1) return const [];
    // A MULTI-CHARACTER LITERAL IS A SEQUENCE OF SINGLE-CHARACTER SLOTS, so
    // the two repairs the rest of the engine already uses apply inside it:
    // supply an absent character as one obligation, and DENY a character the
    // literal did not ask for. The denial is what a subsequence-only alignment
    // could not say: on `fa"se`, `falzse`, `i,f` the damage is INSIDE the
    // literal, and without it the engine pays the enclosing sequence to
    // destroy the whole keyword. The literal's text is grammar-determined, so
    // reading through interior junk completes a shape the input witnesses
    // (I36/I78) and no character of an absent class is invented.
    final out = <_Way>[];
    if (c is Str) {
      for (final w in _align(c, pos)) {
        out.add(w);
      }
    } else {
      // A single-character terminal owes one either way.
      out.add(_Way(pos, 0, pos == _in.length ? 0 : 1, 0, pos,
          leaf: Repaired(c, pos, 0, const [], [SyntaxError(pos: pos, len: 0)]),
          owing: true,
          eof: pos == _in.length ? 1 : 0));
    }
    return out;
  }

  /// Every way of reading [c]'s text at [pos] with characters OWED (the input
  /// never supplied them, one obligation each) and characters DENIED (the input
  /// supplied them where the literal asked for something else). One edit-
  /// distance table serves every end position: cell (i, j) is the cheapest way
  /// to account for the first i characters of the text against the first j
  /// characters of input, and every j with a finished last row is one way out.
  /// Every character read or denied becomes a leaf or a mark, so the tree
  /// accounts for exactly the span the way claims.
  List<_Way> _align(Str c, int pos) {
    final text = c.text;
    final t = text.length;
    final kMax = _min(_in.length - pos, t + _budget);
    if (kMax < 0) return const [];
    // d[i][j], flattened; unreachable is _far.
    final w = kMax + 1;
    final d = List<int>.filled((t + 1) * w, _far);
    d[0] = 0;
    for (var j = 1; j <= kMax; j++) {
      d[j] = j; // deny the leading input
    }
    for (var i = 1; i <= t; i++) {
      d[i * w] = i; // owe the leading text
      for (var j = 1; j <= kMax; j++) {
        final hit = _in.codeUnitAt(pos + j - 1) == text.codeUnitAt(i - 1)
            ? d[(i - 1) * w + j - 1]
            : _far;
        var v = hit;
        final owe = d[(i - 1) * w + j] + 1;
        if (owe < v) v = owe;
        final deny = d[i * w + j - 1] + 1;
        if (deny < v) v = deny;
        d[i * w + j] = v;
      }
    }
    final out = <_Way>[];
    for (var j = 0; j <= kMax; j++) {
      final cost = d[t * w + j];
      if (cost == 0 || cost > _budget) continue; // 0 was a plain match
      // Walk the script back from (t, j).
      final kids = <MatchResult>[];
      final marks = <SyntaxError>[];
      var net = 0, del = 0, mid = 0, eof = 0, first = _far;
      var i = t, jj = j;
      while (i > 0 || jj > 0) {
        final here = d[i * w + jj];
        if (i > 0 &&
            jj > 0 &&
            _in.codeUnitAt(pos + jj - 1) == text.codeUnitAt(i - 1) &&
            d[(i - 1) * w + jj - 1] == here) {
          kids.add(Match(null, pos + jj - 1, 1));
          net++;
          i--;
          jj--;
        } else if (i > 0 && d[(i - 1) * w + jj] + 1 == here) {
          marks.add(SyntaxError(pos: pos + jj, len: 0));
          if (pos + jj == _in.length) {
            eof++;
          } else {
            mid++;
          }
          if (pos + jj < first) first = pos + jj;
          i--;
        } else {
          marks.add(SyntaxError(pos: pos + jj - 1, len: 1));
          del++;
          if (pos + jj - 1 < first) first = pos + jj - 1;
          jj--;
        }
      }
      out.add(_Way(pos + j, del, mid, net, first,
          leaf: Repaired(c, pos, j, kids.reversed.toList(),
              marks.reversed.toList()),
          owing: marks.isNotEmpty && marks.first.pos >= pos + j,
          eof: eof));
    }
    return out;
  }

  /// THE TREE FOR ONE WAY, BUILT WHEN SOMETHING ACCEPTS IT.
  ///
  /// A leaf is already a node. Anything else wears [_Way.cap]'s node over the
  /// chain behind it, where each link contributes its own node if it has one
  /// and the node of the step it appended if it does not -- and its mark either
  /// way. This is exactly what closing a chain used to do at every cell, for
  /// every way, and it is done here once, along the answer.
  static MatchResult _build(_Way w) {
    if (w.leaf != null) return w.leaf!;
    final kids = <MatchResult>[];
    final errs = <SyntaxError>[];
    for (_Way? p = w.link; p != null; p = p.prev) {
      if (p.mark != null) errs.add(p.mark!);
      final n = p.nodes ? p : p.link;
      if (n != null && n.nodes) kids.add(_build(n));
    }
    return _wrap(
        w.cap!, w.from, w.end, kids.reversed.toList(), errs.reversed.toList());
  }

  /// A node for [c] over `[pos, end)`: the plain match where nothing was
  /// repaired, and one that can carry the marks where something was.
  static MatchResult _wrap(Clause c, int pos, int end, List<MatchResult> kids,
      List<SyntaxError> errs) {
    if (errs.isEmpty && kids.isNotEmpty && kids.first.pos == pos) {
      return Match(c, pos, end - pos, subClauseMatches: kids);
    }
    return Repaired(c, pos, end - pos, kids, errs);
  }

  // -- honesty ---------------------------------------------------------------

  /// Whether every string [c] derives yields the same tree shape.
  ///
  /// A clause the grammar pins to one shape stands for a hole whose contents
  /// were never in question -- `'}'`, or an `A <- [ab]` that is one leaf either
  /// way -- so marking it absent claims nothing the grammar had not said. A
  /// clause with a choice in it does not. Choice is the whole of the
  /// difference, so `First`, `Repetition` and `Optional` are the whole of the
  /// exclusion; a predicate contributes no node at all.
  ///
  /// A rule that re-enters itself reads false while in progress, which refuses
  /// a fill rather than wrongly allowing one.
  bool _determined(Clause c) {
    final memo = _det[c];
    if (memo != null) return memo;
    _det[c] = false;
    return _det[c] = c is Terminal || c is FollowedBy || c is NotFollowedBy
        ? true
        : c is Seq
            ? c.subClauses.every(_determined)
            // A `+` offers no choice of SHAPE, only of count, and one
            // occurrence is the only count a fill can mean. `*` and `?` never
            // need filling -- they match nothing for free -- so `requireOne` is
            // the whole of the repetition that can be granted.
            : c is Repetition && c.requireOne
                ? _determined(c.subClause)
                : c is Ref
                    ? _determined(rules[c.ruleName]!)
                    : false;
  }

  // -- the entry point -------------------------------------------------------

  /// Parse [s], recovering from syntax errors. Always covers the whole input.
  ///
  /// The round at budget 0 IS the frozen parser -- nothing can be filled and
  /// nothing skipped -- so an undamaged document is answered by one pure parse
  /// and never opens the chart at all. Each further round raises the ceiling by
  /// one and asks again, over the SAME memo: a way found under a smaller budget
  /// is still a way, so nothing already derived is derived twice, and the first
  /// round that answers answers with the cheapest repair there is.
  MatchResult recover(String s) {
    _in = s;
    _ref = Parser(rules: rules, topRuleName: topRuleName, input: s);
    // ROUND 0 IS THE FROZEN PARSER, SO LET THE FROZEN PARSER RUN IT (I89 by
    // construction). A clean document is answered by the library's own parse
    // and memo table, and the chart below is opened only on damage -- where
    // round 0 by definition finds nothing, so starting the rounds at 1 is
    // exact, not an approximation.
    final pure = _ref.parse();
    if (!pure.hasSyntaxErrors) {
      lastCost = 0;
      return pure.root;
    }
    _memo.clear();
    _version = List.filled(s.length + 1, 0);

    // Deleting the whole input and filling the top rule to nothing is always
    // available and always the most expensive answer worth having, so its cost
    // is the ceiling. Past it there is nothing left to find.
    final fill = _minFill(rules[topRuleName]!);
    final ceiling = fill >= _never ? -1 : s.length + fill;
    // [fall] is the answer the engine would give if the coherence rule below
    // did not exist, held at the FIRST budget that offers one. The rule says
    // which reading is better, not which readings there are, so it may not be
    // able to leave the engine with nothing: `Top <- Chunk 'z'` on `abab` has
    // no coherent reading at any budget, and a filter that refuses them all
    // answers by deleting the whole document.
    // The rounds step by ONE, and that is measured, not inherited: with this
    // chart's accumulate-and-merge cells, round k+1 re-derives only the cost
    // frontier k+1 (everything cheaper is already in the cell and merged), so
    // the marginal round is small. Doubling -- fastest in the m-line's
    // budget-indexed tables -- is 1.39x SLOWER here (2,831 vs 2,037 ms on the
    // battery): a doubled round explores several cost frontiers fresh at every
    // cell, and the wider lists make every prune dearer.
    _Way? best, fall;
    for (_round = 1; _round <= ceiling; _round++) {
      _budget = _round;
      final owed = <_Way>[];
      for (final w in _ways(rules[topRuleName]!, 0)) {
        // A way that stops short is charged for the tail it never reached, so
        // a real derivation of a prefix competes on the same terms as a reading
        // of the whole input rather than being preferred for being a parse.
        //
        // AND IT LOSES ITS PEG CLAIM WITH THE TAIL. `peg` says "this is the
        // reading the frozen parser would take" of THE INPUT, and a way that
        // stops short read a prefix instead; carrying the flag past the charge
        // let a clean parse of part of the document outrank the honest reading
        // of all of it, because `peg` outranks everything below total cost. On
        // `a*` that is exactly the difference between naming the `MulOp` whose
        // operand the document never supplied and deleting the `*`.
        final tail = s.length - w.end;
        // AND FOR THE INPUT IT KEEPS WITHOUT SAYING ANYTHING ABOUT IT. Every
        // character is denied, PINNED by a terminal that constrains what it
        // accepts, or taken by one that does not -- `.` or an inverted set --
        // so what is left over here is what the reading absorbed. `String <-
        // '"' Chr* '"'` with one quote supplied lets `[^"\]` take the whole
        // document for a single obligation, and no repair whose price grows
        // with the damage can outbid that: on `[1,[2,[3,[4]]],5"` the swallow
        // costs 1 where the honest Array costs 2.
        //
        // It is ONE, not one per character. The reading absorbs or it does not,
        // and that is all this has to say, because a difference in price was
        // the only thing keeping [_rank] from reaching [_Way.net] -- the test
        // written for exactly this reading and unreachable while the swallow
        // was strictly cheaper. Levelling the price hands the question to it.
        //
        // Measured at the WHOLE DOCUMENT, which is the only place it cannot be
        // dodged. Charged per slot instead, `"a` closing early so the real
        // quote opens the swallow pays nothing, and the honest repair pays: on
        // `{"k":[{"a":1},{,b":2}]}` that moved the supplied quote from 15 to 9.
        // Charged per node, a span is charged again by every Ref above it.
        //
        // Charged where the reading takes MORE than it explains, which is the
        // comparison [_first] already makes about an arm and [_lift] about a
        // node, asked here about a whole document. Charging every reading that
        // absorbs anything at all scores the same to four places and costs 2x
        // the latency: a document with a short string in it pins far more than
        // it absorbs, and paying a round to re-decide a question it was never
        // going to lose is the entire difference.
        //
        // Not charged where the reading is the parser's own, since round 0 must
        // stay the frozen parser: a document that IS one long string absorbs
        // more than it pins and owes nothing for it.
        //
        // AND IT IS NOT ENOUGH ON ITS OWN, because it is levied HERE, and by
        // the time a reading arrives here its honest rival may already be gone:
        // [_prune] keeps ONE way per end position ranked by cost, and on
        // `"1,[2,[3,[4]]],5]` the swallow and the honest `Array` both end at 17
        // with the swallow cheaper, so the `Array` is destroyed inside the chart
        // and a price charged at the top never gets to speak. A PRICE THE
        // PRUNING CANNOT SEE IS NOT A PRICE. [_Way.toll] is the same judgement
        // made where the pruning can see it, and the two together take the
        // worst json swallow from 94% of the document to 42%.
        final loose = s.length - w.del - tail - w.net;
        final swallowed = !w.free && loose > w.net ? 1 : 0;
        if (w.edits + tail + swallowed > _budget) continue;
        // AN OBLIGATION IS A CLAIM THAT THE DOCUMENT RAN OUT, AND A TAIL IS A
        // CLAIM THAT IT DID NOT. A way whose last act was to owe, with input
        // still in front of it, makes both claims at the same position: it says
        // a character is missing HERE and then hands the character that IS here
        // to the discard. It has not earned the obligation -- it should have
        // read what the document offered.
        final incoherent = tail > 0 && w.owing;
        final a = _Way(w.end, w.del + tail, w.gap + swallowed, w.net,
            tail == 0 ? w.key : _min(w.key, w.end),
            toll: w.toll,
            leaf: w.leaf,
            cap: w.cap,
            from: w.from,
            link: w.link,
            owing: w.owing,
            eof: w.eof);
        // AND A WAY THAT REPAIRS NOTHING BUT IS NOT PEG'S READING IS NO
        // ANSWER AT ALL: were it one, the frozen parser would have returned it,
        // and charging 0 for it claims of the grammar something untrue. This is
        // the single key value BETWEEN the two thresholds -- clean, but not
        // PEG's -- so refusing it is one equality, and it is what makes the
        // round at budget 0 the frozen parser rather than merely resemble it.
        if (a.key == _far) continue;
        if (incoherent) {
          owed.add(a);
          continue;
        }
        if (best == null || _rank(a, best) < 0) best = a;
      }
      // AND IT MAY NOT BE PAID FOR BEING CHEAP. Refused outright, an incoherent
      // reading loses to any coherent one at any price -- and the cheapest
      // coherent reading of a damaged document is often the swallow. On
      // `[1,[2,[3,[4]]],5"` the honest Array owes its `]` at 16 and hands the
      // `"` to the discard, so the veto threw it away and returned the whole
      // document read as one String.
      //
      // WHAT SEPARATES THE TWO CASES IS COVERAGE, AND PRICE SAYS NOTHING ABOUT
      // IT. On `{ a` the incoherent reading -- discard the `a`, owe the `}` --
      // costs 2 where the reading a human wants costs 4, and it explains TWO
      // characters where that one explains three. On
      // `{ a=1; { b=2; } if (c) d=3; "` the incoherent reading also costs 2 --
      // owe the `}`, discard the stray quote -- and it explains twenty-seven
      // characters where the coherent swallow explains one. Cheaper in both, so
      // no rule about price can tell them apart; more of the document in the
      // second only, which is exactly the question [_Way.net] answers.
      //
      // So an incoherent reading is admitted only where it EXPLAINS MORE, and
      // never where it also costs more: it must beat the coherent reading at
      // its own claim, not outbid it. Ties go to the coherent one, which is the
      // veto wherever the veto had anything to say.
      if (best != null) {
        final c = best;
        var b = c;
        for (final f in owed) {
          if (f.edits + f.toll <= c.edits + c.toll && f.net > b.net) {
            b = f;
          }
        }
        best = b;
        break;
      }
      // The rule says which reading is better, not which readings exist, so it
      // may not leave the engine with nothing -- so the best incoherent reading
      // at the FIRST budget that offers one is kept, and used if no coherent
      // reading is ever found. `Top <- Chunk 'z'` on `abab` has none at any
      // budget, and an engine that refuses them all answers by deleting the
      // whole document.
      if (fall == null && owed.isNotEmpty) {
        var f = owed.first;
        for (final g in owed) {
          if (_rank(g, f) < 0) f = g;
        }
        fall = f;
      }
    }
    best ??= fall;

    final root = best == null
        ? Repaired(
            null, 0, s.length, const [], [SyntaxError(pos: 0, len: s.length)])
        : best.end == s.length
            ? _build(best)
            : Repaired(null, 0, s.length, [_build(best)],
                [SyntaxError(pos: best.end, len: s.length - best.end)]);
    // Read the cost off the tree, so what is charged is exactly what the tree
    // says and nothing the emit did not keep.
    final (del, gap) = _edits(root);
    lastCost = del + gap;
    return root;
  }

  /// The fewest obligations [c] can be left holding while matching nothing at
  /// all, or [_never] where it cannot match nothing however much is supplied.
  ///
  /// Relaxed to a fixed point over the whole grammar on first use, because a
  /// rule's answer can depend on itself.
  int _minFill(Clause c) {
    if (_fill.isEmpty) {
      final all = <Clause>[];
      void collect(Clause k) {
        if (_fill.containsKey(k)) return;
        _fill[k] = _never;
        all.add(k);
        if (k is Ref) {
          collect(rules[k.ruleName]!);
        } else if (k is HasOneSubClause) {
          collect(k.subClause);
        } else if (k is HasMultipleSubClauses) {
          k.subClauses.forEach(collect);
        }
      }

      rules.values.forEach(collect);
      for (var moved = true; moved;) {
        moved = false;
        for (final k in all) {
          final v = _fillOf(k);
          if (v < _fill[k]!) {
            _fill[k] = v;
            moved = true;
          }
        }
      }
    }
    return _fill[c] ?? _never;
  }

  int _fillOf(Clause c) {
    if (c is Ref) return _fill[rules[c.ruleName]!]!;
    if (c is Seq) {
      var n = 0;
      for (final k in c.subClauses) {
        final v = _fill[k]!;
        if (v >= _never) return _never;
        n += v;
      }
      return n;
    }
    if (c is First) {
      var n = _never;
      for (final k in c.subClauses) {
        if (_fill[k]! < n) n = _fill[k]!;
      }
      return n;
    }
    if (c is Repetition) return c.requireOne ? _fill[c.subClause]! : 0;
    // An optional and a predicate are both satisfied by nothing at all.
    if (c is Optional || c is FollowedBy || c is NotFollowedBy) return 0;
    // A SLOT THAT WAS NEVER REACHED OWES ONE WHATEVER IT IS, even a
    // multi-character literal that [_terminal] would charge `text.length` to
    // supply in place. The two look like the same obligation priced two ways,
    // and making them agree -- `if (c is Str) return c.text.length` here -- is
    // MEASURABLY WRONG: 0.9748 -> 0.9745 over three runs each, and two
    // swallows become four. (Latency is unchanged; the medians are 1998 ms
    // against 1954 ms, inside a spread of ~140 ms.) The stop is the honest
    // reading of a truncated document, and every obligation added to it is a
    // discount for the swallow it competes against. They are not the same
    // claim: the terminal says the literal is HERE with characters missing,
    // the stop says the production ENDED.
    return c is Nothing ? 0 : 1;
  }

  /// Edits recorded inside [m]: a skipped span deletes its characters, and a
  /// zero-width mark is one obligation the input never supplied.
  (int, int) _edits(MatchResult m) {
    var del = 0, gap = 0;
    void walk(MatchResult k) {
      if (k is SyntaxError) {
        if (k.len == 0) {
          gap++;
        } else {
          del += k.len;
        }
      }
      k.subClauseMatches.forEach(walk);
    }

    walk(m);
    return (del, gap);
  }

  int recoverCost(String s) {
    recover(s);
    return lastCost;
  }
}
