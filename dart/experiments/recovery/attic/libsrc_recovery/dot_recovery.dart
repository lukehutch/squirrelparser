// Dot recovery: the pure parser plus TWO repair transitions, both local to a
// position-advancing clause. No grammar rewriting, no per-clause closure.
//
// This supersedes the "close the grammar with C -> <span> C and C -> eps for
// every clause C" formulation of semiring_recovery.dart / agenda_recovery.dart.
// Those add two productions to every one of the |G| clauses at every one of
// the n+1 positions. Two theorems say that is redundant:
//
// (1) LEADING-SPAN HOISTING. C -> <span-char> C only ever absorbs garbage at
//     C's LEFT EDGE. Absorbing k chars before C is derivationally identical,
//     and cost-identical, to absorbing them before C's slot in its parent.
//     Ascending the parse tree, every slot is either a Seq dot, a gap between
//     two Repetition items, or the root. So a span transition is needed at
//     exactly those three sites -- nowhere else. Concretely: spans are
//     allowed at Seq dots >= 1, at Repetition item gaps, and at dot 0 of the
//     goal wrapper (the only clause with no parent). Dot 0 of every other Seq
//     is DENIED the span, which is what stops the |Seq| x n x cost blowup of
//     "everything can eat garbage from the left".
//
// (2) EPSILON IS A STATIC TABLE, NOT A SEARCH DIMENSION. "Clause C is
//     missing" = "the shortest string C could have derived was not written".
//     Its cost is therefore minLen(C) -- the length of the shortest witness of
//     C -- computed once, by fixpoint, over the grammar:
//
//         minLen(terminal) = its length      minLen(Seq)  = sum over children
//         minLen(A?) = minLen(A*) = 0        minLen(First) = min over alts
//         minLen(A+) = minLen(A)             minLen(Ref)  = minLen(target)
//
//     This replaces the ad-hoc structural epsilon (1 for a terminal, 2 for a
//     composite) of the closure implementations, and it is not a heuristic:
//     with span = "delete an input char" at cost 1 and fabricate = "insert the
//     shortest witness" at cost minLen, the total cost of a repair is exactly
//     the INDEL (insert/delete) EDIT DISTANCE from the input to the nearest
//     string in L(G). The objective is no longer a weighting scheme with
//     tuned constants; it is Levenshtein distance to the language, and the
//     tree is the parse of the nearest member. A substitution costs 2 = one
//     delete + one insert, as it should.
//
// So the whole of error recovery is three transitions on a dotted Seq item
// (plus the Repetition gap, which exists only because Repetition is compiled
// natively instead of as the right-recursive Seq  R <- A R / eps  that it is
// equivalent to -- desugar it and the Seq dot is literally the only recovery
// site in the parser):
//
//     MATCH  (seq,s,d,p) + [sub_d : p..q]  ->  (seq,s,d+1,q)   cost +0
//     SPAN   (seq,s,d,p)                   ->  (seq,s,d,p+1)   cost +1   d>=1
//     FAB    (seq,s,d,p)                   ->  (seq,s,d+1,p)   cost +minLen(sub_d)
//     GAP    rep chain [s..e)              ->  pending [s..e+1) cost +1
//
// Every other clause type -- First, Optional, Ref, terminals, predicates --
// is the UNTOUCHED pure parser. They have no repair rules at all.
//
// Search is unchanged and still exact: Knuth's lightest-derivation algorithm
// (Dijkstra generalized to grammars) over a priority queue ordered
// lexicographically by
//
//     (cost, dataBits, classBits, fabSize)
//
// which is a rate-distortion objective, not a weighting scheme -- see the
// _V doc comment. Every component is additive and non-negative, so the order is
// a TOTAL order that is monotone under +: the key is monotone non-decreasing
// along every derivation, the superiority condition holds, and THE FIRST TIME
// THE GOAL ITEM POPS IT IS OPTIMAL. Nothing after that pop can improve it,
// which is why the loop breaks immediately.
//
// Because the order is total and monotone, only the lex-MINIMUM witness per
// cell can appear in the lex-minimum derivation, so each cell keeps ONE live
// witness (two, counting the pending/settled repetition split) rather than a
// Pareto frontier. Measured on the 519-mutant JSON battery: largest live list
// 2, against 52 for the earlier order that included the non-additive diameter.
// Dominance is then exactly the objective, so no component has to be left out
// of it to keep the search tractable -- the tie-break is exact for free.
//
// A multi-char Str is desugared to its char sequence, so edit distance inside
// a literal falls out of the same three transitions. The goal is a synthetic
// wrapper Seq [Top, EOF] where EOF is unfabricable (minLen = infinity), so
// trailing garbage is just SPAN at the wrapper's dot 1.

import 'dart:math' as math;

import '../parser/clause.dart';
import '../parser/combinators.dart';
import '../parser/match_result.dart';
import '../parser/parser.dart';
import '../parser/terminals.dart';
import 'skip_recovery.dart' show SkipResult, MissingObligation;

/// Weight: (cost, editLo, editHi, fabSize, classBits, subs, dataBits, regret).
/// lo > hi means "no edits". The live objective reads TWO of these, in order:
///
///     minimise lexicographically  (cost, regret)
///
/// and that pair is itself one integer -- see `scalarMode`:
///
///     minimise   Delta = cost * M + regret        for M above any regret
///
/// ONE QUESTION, ASKED PER ALIGNMENT COLUMN: how far is this column's claim from
/// the claim the evidence deserved? Give every input position an intrinsic
/// RESOLUTION h(p) = the width of the narrowest class or literal in G that can
/// name input[p] (`_dataAt`). Then
///
///   kept by a class of width b  ->  regret  b - h(p)   (over-wide claim)
///   discarded (SPAN or SUB)     ->  regret  h(p)       (claim never made)
///   fabricated character        ->  regret  log|Sigma| (claim with no witness)
///
/// and `cost` counts the columns where an edit happened at all. Non-negativity is
/// structural, not assumed: h(p) is the MINIMUM over all classes containing
/// input[p] and the matching class is one of them, so b >= h(p) always -- which
/// is what keeps the order monotone under `_add`.
///
/// HOW THIS SUBSUMES THE FOUR COMPONENTS IT REPLACED. The retired objective was
/// `(cost, dataBits, classBits, fabSize)`, and three of those four were the same
/// measurement counted twice:
///
///   dataBits + classBits  are one sum over COMPLEMENTARY SETS -- log|K| for what
///     the tree discards and log|K| for what it keeps. That is why they had to be
///     adjacent, and in that order. Merging them into `regret` is exact: measured
///     BYTE-IDENTICAL per-mutant, all 519 D1 mutants and 5 documents.
///   fabSize  is the invention share of `cost` (fabSize <= cost), so it carries no
///     information cost does not already have -- except the one thing it could not
///     say: what a fabricated character ASSERTS. Priced as an unwitnessed claim
///     (log|Sigma|, the whole alphabet on zero evidence) it folds into regret and
///     IMPROVES the result: 513/519 -> 515/519.
///
/// THE ASYMMETRY IS LOAD-BEARING, and was falsified in the right direction.
/// Input is EVIDENCE, worth what the grammar could have made of it (h(p)); a tree
/// node is a CLAIM, worth what it asserts (log|Sigma|). Making SPAN symmetric with
/// FAB (`spanRegretMode = 1`) collapses regret to `log|Sigma| * cost + slack`,
/// i.e. a constant given cost -- predicted in advance to score like classBits
/// alone, and confirmed at 502/519. A SUB must NOT pay the assertion price either
/// (`subRegretMode = 1`: 509/519), because a substitution's POSITION is witnessed
/// by the character standing there even though its value is not. A fabrication has
/// no witness at all, not even a position.
///
/// WHY EXACTLY TWO, AND NOT ONE COMPONENT. `cost` is not reducible to `regret`:
/// h(p) = 0 for every character G names as a literal, so a pure-regret objective
/// deletes punctuation for FREE, and profitably -- destroying a `,` lets the digit
/// beside it be claimed by `[1-9]` (3170) instead of `[0-9]` (3322). Run with
/// `costInLex = false` it corrupts 5/5 valid documents, shredding a 48-character
/// object down to 13 surviving characters (cost 35, regret 112212 -> 2882).
/// Conversely `regret` is not reducible to `cost`: tie orders that all share cost
/// as the primary key score anywhere from 474 to 515 on D1, so cost alone leaves
/// 41 mutants' worth of decisions undetermined. Both terms are load-bearing.
///
/// (cost, regret) is therefore NOT two norms of one vector -- the pretty version
/// of this claim is false. An edited column can carry zero regret, so the
/// edit-indicator vector and the discrepancy vector genuinely differ. What they
/// are is the two terms MDL always has: the cost of describing the ALIGNMENT, and
/// the cost of describing the CONTENT given it. The first must be
/// non-Archimedean above the second, or content bits could buy an edit -- which is
/// exactly the vandalism measured above.
///
/// WHY MDL ALONE IS NOT ENOUGH, and why the distortion tier is not a fudge.
/// Worked through the full Bayesian objective -- channel likelihood times
/// structural prior, with a SPAN charged as a channel insertion (the channel
/// names the char, log|Sigma|), a FAB as a channel deletion (the TREE names the
/// char, log|K|), plus derivation choice bits -- the posterior PREFERS to
/// discard a real digit and build an empty String over spanning a stray quote
/// and keeping the number, by 9.6 kbits. Adding rigour makes it worse, not
/// better: choice bits favour the empty container even more strongly. That is
/// not an accounting slip, it is what MDL means -- an empty container really is
/// a simpler explanation of the same amount of corruption. MDL has no concept
/// that the digit was DATA. So repair is not maximum-posterior decoding; it is
/// lossy reconstruction, and it needs a distortion term above the code length.
///
/// This is why the distortion term survives the reduction: `regret` keeps it,
/// because h(p) is what the author's character was worth.
///
/// The three components the objective does NOT read, all measured and rejected:
///   editLo/editHi (DIAMETER) -- the repair's spread. The only NON-additive
///     component, and the sole reason a Pareto frontier was ever needed here
///     (diam(a+b) != diam(a)+diam(b), so witnesses can be incomparable).
///     Dropping it costs 2 points of accuracy and buys a 55x faster tail.
///   first-edit position -- fixes del@37 but breaks ins@47/ins@48: net -1. The
///     cases it targets are genuine coin flips, so it just moves them around.
///   subs, the SUB count -- makes the objective the lexicographic pair
///     (Levenshtein distance, indel distance), on the argument that a
///     substitution is a deletion and an insertion COINCIDING at one site and
///     so is quadratically less likely than a lone indel. It works, in
///     isolation: it takes insertions from 210/216 to a perfect 216/216. But a
///     0-SUB repair is free to let a String swallow structure, which costs 7
///     genuine substitutions, and `dataBits` fixes the same insertions without
///     that side effect (513/519 with subs off, 509/519 with it on).
///   dataBits and classBits as separate tiers -- subsumed by `regret`, exactly.
///
/// Two loss families are PROVEN irreducible: each needs contradictory
/// inequalities on the price of one fabricated literal against one destroyed
/// digit (swap@12 wants it below 3170, ins@18 wants it above), so no value of any
/// single constant wins both. They need a Damerau transposition primitive, which
/// would change tier 1 from Levenshtein to Damerau-Levenshtein and break the
/// left-to-right tiling invariant `covers()` checks.
///
/// Every component is additive and non-negative, so the lexicographic order is
/// a total order monotone under `_add`: a conclusion is never lex-better than
/// its premises, and Knuth's superiority condition holds.
typedef _V = (int, int, int, int, int, int, int, int);

const int _inf = 1 << 24;
const _V _zero = (0, _inf, -1, 0, 0, 0, 0, 0);

_V _add(_V a, _V b) => (
      a.$1 + b.$1,
      a.$2 < b.$2 ? a.$2 : b.$2,
      a.$3 > b.$3 ? a.$3 : b.$3,
      a.$4 + b.$4,
      a.$5 + b.$5,
      a.$6 + b.$6,
      a.$7 + b.$7,
      a.$8 + b.$8
    );

int _diam(_V a) => a.$3 >= a.$2 ? a.$3 - a.$2 : 0;

/// MEASUREMENT ONLY: how the class-width component participates.
///   0 = ignore it entirely.
///   1 = EXACT: bits is in both _cmp and _dom, so the lightest-bits witness is
///       guaranteed found -- but it is a fifth Pareto axis, and weakening
///       dominance by a near-continuous component explodes the high-cost tail
///       (measured 31.7x on SCRAM-64).
///   2 = HEURISTIC: bits is in _cmp but NOT in _dom. Dominance still requires
///       cost <=, so the result is still a MINIMUM-COST repair and the
///       edit-distance theorem is untouched; only the MDL tie-break becomes
///       best-effort, since a lighter-bits witness can be pruned by a
///       dominating heavier-bits one.
int bitsMode = 2;

/// Millibits needed to name one member of a character class of `size` members.
/// A literal (size 1) is free. `_csSize` counts the full Unicode range, so JSON's
/// `[^"\\]` is 1114110 wide and costs ~20 bits, not the ~16 a BMP-sized alphabet
/// would give (measured: h('Q') = 20087 millibits).
///
/// This is the MDL / maximum-likelihood residual: taking the parse tree as the
/// model, this is what is left to specify to recover the actual input. It
/// discriminates repairs that are tied on every other component -- letting a
/// String swallow a structural `,` explains that comma with a 20-bit class,
/// while the literal `','` in Array explains it with 0 bits.
int _clsBits(int size) =>
    size <= 1 ? 0 : (math.log(size) / math.ln2 * 1000).round();

int _csSize(CharSet cs) {
  var k = 0;
  for (final (lo, hi) in cs.ranges) {
    k += hi - lo + 1;
  }
  return cs.inverted ? 0x110000 - k : k;
}

/// A zero-cost terminal match carrying `b` millibits of class width.
_V _termV(int b) => bitsMode == 0 ? _zero : (0, _inf, -1, 0, b, 0, 0, 0);

/// RESOLUTION REGRET, in millibits -- the unification of `dataBits` and
/// `classBits` into a single additive component with one sign.
///
/// Give every input character an intrinsic resolution `h(p)`: the width of the
/// NARROWEST class or literal in G that can name it (`_dataAt[p]`). That is the
/// number of bits it *ought* to cost to account for that character. A repair's
/// regret at position `p` is its absolute deviation from that ideal:
///
///   kept by a class of width `b`  ->  b - h(p)   (>= 0: h is the min over all
///                                     classes containing the char, and the
///                                     matching class is one of them)
///   discarded (SPAN or SUB)       ->  h(p)       (the tree makes no claim at
///                                     all, so all h(p) bits go unaccounted)
///
/// The two old components are the two halves of this one sum over complementary
/// sets, which is why they had to be adjacent and in that order. Regret makes
/// the shared quantity explicit: both are `|width claimed - width deserved|`.
///
/// `fabRegretMode` prices the mirror direction -- tree content with no input to
/// witness it. 0 = free (leave it to `fabSize`); 1 = `log|Sigma|` per fabricated
/// character (asserting one specific character out of the whole universe on zero
/// evidence); 2 = 1 per character (unit).
///
/// 1 is the live setting: it is what lets `fabSize` be dropped, and it is a net
/// gain (513/519 -> 515/519 on D1, 1923 -> 1925 / 2021 pooled over 5 documents).
int fabRegretMode = 1;

/// `spanRegretMode` 1 charges a discarded character the full `log|Sigma|` instead
/// of `h(p)`, making SPAN and FAB perfectly symmetric. MEASUREMENT ONLY: it
/// should make the L1 norm equal `log|Sigma| * cost + slack`, collapsing the
/// distortion term to a constant given cost, and so should score like classBits
/// alone. The asymmetry is the point -- input is EVIDENCE (worth what the grammar
/// could have made of it), a tree node is a CLAIM (worth what it asserts).
int spanRegretMode = 0;

/// `subRegretMode` 1 completes the mirror: a substitution is a deletion and an
/// insertion coinciding at one site, so it both destroys `h(p)` bits of evidence
/// AND asserts `log|Sigma| - log|K|` bits without any. This is the rejected
/// `subs` component measured in bits rather than counted.
int subRegretMode = 0;

/// MEASUREMENT ONLY. `recover` short-circuits valid input to the pure parse
/// without ever entering the agenda, so on valid input `lastRegret` is a stub 0
/// rather than a computed value. Setting this forces the search to run anyway,
/// which is the only way to read the regret of a clean parse.
bool forceSearch = false;

/// MEASUREMENT ONLY. Drops `cost` from the lexicographic order, leaving regret
/// as the sole objective. Used to test whether `cost` is redundant: if regret
/// alone reproduced it, dropping it would change nothing. Sound to flip -- every
/// regret contribution is non-negative, so regret stays monotone under `_add`
/// and the first goal popped is still the minimum of whatever order is in force.
bool costInLex = true;

/// THE OBJECTIVE, AS ONE INTEGER.
///
/// `(cost, regret)` is a lexicographic pair only because an edit's STRUCTURAL
/// price must be incomparable to any amount of CONTENT price: if finitely many
/// content bits could buy an edit, the objective vandalises valid input (proved
/// by `costInLex = false`, which shreds every valid document it is given). That
/// is the statement "the coefficient of the structural term is infinite".
///
/// But on a finite input regret is BOUNDED, so the infinity is unnecessary. Let
/// `M` exceed every achievable regret; then
///
///     Delta = cost * M + regret
///
/// is a single non-negative integer that induces exactly the lexicographic
/// order, because a regret difference can never reach M. The whole objective is
/// one number: the description length of the input given the grammar, with the
/// alignment term weighted past the point where distortion can outbid it.
///
/// `_bigM` is recomputed per input in `recover`; `assert`s at the goal check the
/// bound was never approached.
/// The same collapse works for any lexicographic tuple whose components are
/// bounded, by Horner: mode 2 folds the 3-component `(cost, fabSize, regret)`
/// into `cost*M^2 + fabSize*M + regret`. The component count was never a
/// property of the objective -- only of leaving the components unbounded.
int scalarMode = 0;
int _bigM = 1;
int _scalar(_V v) => scalarMode == 1
    ? v.$1 * _bigM + v.$8
    : (v.$1 * _bigM + v.$4) * _bigM + v.$8;

/// DISCARDED DATA, in millibits: the information content of the input
/// characters a repair throws away (SPAN) or overwrites (SUB).
///
///   dataBits(c) = min { log2 |K| : K a class or literal of G with c in K }
///
/// i.e. the cheapest way the grammar can name that character. A character the
/// grammar spells out as a literal -- `{`, `,`, `"`, and the letters of `true`
/// / `null` -- costs 0: it is punctuation, carrying none of the author's data,
/// so discarding it destroys nothing. A character nameable only inside a wide
/// class -- a digit (3.2 bits), a free-text letter (20 bits) -- costs its class
/// width, because discarding it destroys that much of what the author wrote.
/// Measured against the engine: h('[')=h(',')=h(']')=0, h(digit)=3170 via
/// `[1-9]`, h('Q')=20087 via `[^"\\]`.
///
/// This exists because `bits` alone has a SIGN ERROR: it charges for the
/// characters the tree explains and nothing for the characters it discards, so
/// it rewards explaining LESS, and an empty container is always the cheapest
/// thing to describe. That is why plain MDL prefers substituting a real digit
/// to build an empty String over spanning a stray quote and keeping the number
/// (measured: 20087 vs 23409 millibits -- MDL picks the empty String). Charging
/// the discarded characters by how cheaply the grammar can name them inverts
/// exactly that preference, and only that one: for punctuation the charge is 0
/// on both sides, so it leaves every SPAN-vs-FAB tie exactly where it was.
///
/// `dataMode` does not charge fabricated characters -- but the claim that once
/// stood here, that charging them "would force a global FAB-over-SPAN preference,
/// which is provably self-defeating", is FALSE and was never measured. Charging a
/// fabricated character as an unwitnessed claim is a net GAIN (see
/// `fabRegretMode`, 513 -> 515 on D1); it is just charged through `regret`, whose
/// asymmetry -- h(p) for evidence destroyed, log|Sigma| for a claim invented --
/// is what makes the preference local rather than global.
int dataMode = 1;

/// Number of SUB steps. Adding this after `cost` makes the objective the
/// lexicographic pair (Levenshtein distance, indel distance): a substitution is
/// not a primitive corruption but a deletion and an insertion that COINCIDE at
/// one site, so under independent per-site corruption it is quadratically less
/// likely than a lone indel. Levenshtein charges it 1 by fiat; indel charges the
/// honest 2. Minimising cost first and subs second takes the coarse metric as
/// the objective and the finer one as the refinement, which is what breaks the
/// SPAN-vs-SUB ties that no bit count can (an empty container is always the
/// cheapest thing to describe, so additive MDL actively prefers discarding real
/// input -- measured, not assumed).
///
/// Which tie-break order the queue uses after cost. Components: 1 = diameter,
/// 2 = first-edit-LATEST, -2 = first-edit-EARLIEST, 3 = fabricated size,
/// 4 = class-width bits, 5 = SUB count, 6 = discarded data, 7 = REGRET.
///
/// 48 is the live setting: `[7]`, regret alone, making the whole objective
/// `(cost, regret)`. Every other entry is a measurement. The alternatives worth
/// knowing: 47 = `[7, 3]` reproduces the retired 4-tier objective byte for byte,
/// and 53 = `[3, 7]` is ~20% faster for -2 accuracy pooled.
int tieMode = 48;
const List<List<int>> tieOrders = [
  [1, 2, 3], // 0 diam, lo-latest, fab   (current)
  [1, 3, 2], // 1 diam, fab, lo-latest
  [3, 1, 2], // 2 fab, diam, lo-latest
  [1, 2], // 3 diam, lo-latest
  [1, 3], // 4 diam, fab
  [3, 2], // 5 fab, lo-latest
  [2, 1, 3], // 6 lo-latest, diam, fab
  [1], // 7 diam only
  [], // 8 cost only
  [-2, 3], // 9 lo-EARLIEST, fab
  [3, -2], // 10 fab, lo-EARLIEST
  [4, 1, 3], // 11 bits, diam, fab
  [1, 4, 3], // 12 diam, bits, fab
  [1, 3, 4], // 13 diam, fab, bits
  [4], // 14 bits only
  [1, 4], // 15 diam, bits
  [4, 1, 2, 3], // 16 bits, diam, lo-latest, fab
  [4, 3], // 17 bits, fab
  [5, 4], // 18 SUBS, bits
  [5, 3, 4], // 19 SUBS, fab, bits
  [5, 1, 3, 4], // 20 SUBS, diam, fab, bits
  [1, 5, 3, 4], // 21 diam, SUBS, fab, bits
  [5], // 22 SUBS only
  [1, 3, 4, 5], // 23 diam, fab, bits, SUBS  (control: subs last)
  [5, 1, 4], // 24 SUBS, diam, bits
  [1, 5, 4], // 25 diam, SUBS, bits
  [5, 4, 1, 3], // 26 SUBS, bits, diam, fab
  [1, 3, 6, 4], // 27 diam, fab, DATA, bits   (incumbent + data before bits)
  [1, 6, 3, 4], // 28 diam, DATA, fab, bits
  [6, 1, 3, 4], // 29 DATA, diam, fab, bits
  [1, 3, 4, 6], // 30 diam, fab, bits, DATA   (control: data last)
  [1, 3, 6, 4, 5], // 31 diam, fab, DATA, bits, SUBS
  [1, 3, 6, 5, 4], // 32 diam, fab, DATA, SUBS, bits
  [6, 5, 1, 3, 4], // 33 DATA, SUBS, diam, fab, bits
  [1, 6, 4], // 34 diam, DATA, bits
  [6, 4], // 35 DATA, bits
  [6], // 36 DATA only
  [1, 6, 5, 4], // 37 diam, DATA, SUBS, bits
  // Pure-additive orders: these trigger the lex-total-order engine (_lexDom).
  [6, 4, 5], // 38 DATA, bits, SUBS
  [6, 5, 4], // 39 DATA, SUBS, bits
  [4, 6], // 40 bits, DATA
  [5, 6, 4], // 41 SUBS, DATA, bits
  [6, 3, 4], // 42 DATA, fab, bits
  [6, 4, 3], // 43 DATA, bits, fab
  [6, 4, 3, 5], // 44 DATA, bits, fab, SUBS
  [6, 4, 3, -2], // 45 DATA, bits, fab, lo-EARLIEST
  [6, 4, 3, 2], // 46 DATA, bits, fab, lo-LATEST
  // REGRET (7) = DATA and bits unified into one component. See `fabRegretMode`.
  [7, 3], // 47 REGRET, fab            <-- the 3-component candidate
  [7], // 48 REGRET alone              <-- the 2-component candidate
  [7, 3, 4], // 49 REGRET, fab, bits   (does bits still add anything?)
  [7, 4, 3], // 50 REGRET, bits, fab
  [7, 6, 3], // 51 REGRET, DATA, fab   (does DATA still add anything?)
  [6, 7, 3], // 52 DATA, REGRET, fab   (control: regret below data)
  [3, 7], // 53 fab, REGRET            (control: order flipped)
  [7, 5, 3], // 54 REGRET, SUBS, fab
  [7, 3, 2], // 55 REGRET, fab, lo-LATEST
  [7, 3, -2], // 56 REGRET, fab, lo-EARLIEST
];

int _cmp(_V a, _V b) {
  if (scalarMode != 0) return _scalar(a) - _scalar(b);
  if (costInLex && a.$1 != b.$1) return a.$1 - b.$1;
  for (final k in tieOrders[tieMode]) {
    switch (k) {
      case 1:
        final da = _diam(a), db = _diam(b);
        if (da != db) return da - db;
      case 2:
        if (a.$2 != b.$2) return b.$2 - a.$2; // later first edit first
      case -2:
        if (a.$2 != b.$2) return a.$2 - b.$2; // earlier first edit first
      case 3:
        if (a.$4 != b.$4) return a.$4 - b.$4;
      case 4:
        if (a.$5 != b.$5) return a.$5 - b.$5;
      case 5:
        if (a.$6 != b.$6) return a.$6 - b.$6;
      case 6:
        if (a.$7 != b.$7) return a.$7 - b.$7;
      case 7:
        if (a.$8 != b.$8) return a.$8 - b.$8;
    }
  }
  return 0;
}

/// Dominance must imply "at least as good under _cmp", and every component
/// must stay monotone under _add. Extra conjuncts only prune LESS, so the
/// latest-lo form is sound for every mode that prefers a later first edit or
/// ignores it; the earliest-lo modes flip the lo conjunct and drop diameter
/// (with lo<= and hi<= the edit intervals are not nested, so diameter is not
/// monotone).
/// MEASUREMENT ONLY: whether the SUB count is a dominance axis too. Unlike
/// `bits` it is a small integer bounded by cost, so making it exact should not
/// cost the tail what a near-continuous axis did.
bool subsInDom = true;

/// True when the tie order uses only ADDITIVE components -- cost, bits, subs,
/// data -- and no non-additive one (diameter, first-edit position).
///
/// This is the case that collapses the whole Pareto machinery. A lexicographic
/// order over non-negative additive components is a TOTAL order that is
/// monotone under `_add`, so Knuth's superiority condition holds for it
/// directly: only the lex-minimum witness per cell can ever be part of the
/// lex-minimum derivation. Pareto sets become singletons, dominance is no
/// longer weakened by any component (so the tie-break is EXACT, not
/// best-effort), and the algorithm is plain Dijkstra/Knuth again.
///
/// Diameter is the only reason Pareto sets ever existed here: diam(a+b) is not
/// diam(a)+diam(b), so two witnesses can be incomparable.
bool _lexDom = false;

/// Only DIAMETER breaks it. `editLo` is combined by `min`, and min is monotone
/// (a.lo <= b.lo implies min(a.lo,c) <= min(b.lo,c)), so a first-edit-position
/// component is lex-compatible in either direction; only diam(a+b) !=
/// diam(a)+diam(b) makes two witnesses genuinely incomparable.
void _setLexDom() {
  _lexDom = true;
  for (final k in tieOrders[tieMode]) {
    if (k == 1) _lexDom = false;
  }
}

bool _dom(_V a, _V b) => _lexDom
    ? _cmp(a, b) <= 0
    : (tieMode == 9 || tieMode == 10)
    ? (a.$1 <= b.$1 &&
        a.$2 <= b.$2 &&
        a.$4 <= b.$4 &&
        (bitsMode != 1 || a.$5 <= b.$5) &&
        (!subsInDom || a.$6 <= b.$6))
    : (a.$1 <= b.$1 &&
        a.$2 >= b.$2 &&
        a.$3 <= b.$3 &&
        a.$4 <= b.$4 &&
        (bitsMode != 1 || a.$5 <= b.$5) &&
        (!subsInDom || a.$6 <= b.$6));

/// Matches only at end of input; unfabricable, so the goal cannot be reached
/// by pretending the input stopped early.
class _Eof extends Clause {
  const _Eof();
  @override
  MatchResult match(Parser parser, int pos) =>
      pos == parser.input.length ? Match(this, pos, 0) : mismatch;
  @override
  void checkRuleRefs(Map<String, Clause> grammarMap) {}
  @override
  String toString() => '<end of input>';
}

/// A multi-char Str desugared to its char sequence. Reported as the original.
class _StrSeq extends Seq {
  final Str orig;
  _StrSeq(this.orig)
      : super([for (var i = 0; i < orig.text.length; i++) Char(orig.text[i])]);
  @override
  String toString() => orig.toString();
}

/// Goal wrapper: Seq(Top, EOF). The only Seq permitted to span at dot 0.
class _Wrap extends Seq {
  _Wrap(Clause top, Clause eof) : super([top, eof]);
  @override
  String toString() => '<goal>';
}

// Backpointer tags -- completes.
const int _tTerm = 0; // terminal match axiom
const int _tEmpty = 1; // free zero-width (Optional/ZeroOrMore empty, EOF)
const int _tPred = 2; // predicate satisfied on the zero slice
const int _tUnary = 3; // Ref/First/Optional wrap: a = child entry
const int _tRepSeed = 4; // first repetition item: a = item entry
const int _tRepExt = 5; // repetition extension: a = rep entry, b = item
const int _tRepGap = 6; // repetition gap (pending): a = rep entry
const int _tSeq = 7; // completed sequence: a = final partial
// Backpointer tags -- partials (how the dot got here).
const int _tSeed = 8; // dot 0 at its start position
const int _tStep = 9; // MATCH: a = previous partial, b = child
const int _tSpanStep = 10; // SPAN: a = previous partial, one char deleted
const int _tFabStep = 11; // FAB: a = previous partial, subclause fabricated
const int _tSub = 12; // SUB: terminal matched the wrong input char (cost 1)

class _E {
  final bool partial;
  final int cid; // clause id (for partials, the Seq's id)
  final int s; // start
  final int d; // dot (partials only)
  final int e; // end (for partials, current position)
  final _V v;
  /// Repetition state that has just crossed a gap: extendable by a further
  /// item, but not itself a usable match of the repetition.
  final bool pend;
  final int tag;
  final _E? a;
  final _E? b;
  bool dead = false;
  bool popped = false;
  _E(this.partial, this.cid, this.s, this.d, this.e, this.v, this.tag,
      [this.a, this.b, this.pend = false]);
}

class DotRecovery {
  final Map<String, Clause> rules;
  final String topRuleName;
  final bool debug;

  /// Whether a terminal may match the WRONG input character at cost 1.
  /// Off = the objective is indel edit distance to the language; on = full
  /// Levenshtein distance. Off is measurement-only; see the header.
  final bool substitution;

  DotRecovery(
      {required this.rules,
      required this.topRuleName,
      this.debug = false,
      this.substitution = true});

  late final Map<String, Clause> _rules = () {
    final m = <String, Clause>{};
    rules.forEach((k, v) => m[k.startsWith('~') ? k.substring(1) : k] = v);
    return m;
  }();

  final Map<Clause, Clause> _strSubst = {}; // Str(len>1) -> _StrSeq

  Clause _sub(Clause c) => (c is Str && c.text.length > 1)
      ? _strSubst.putIfAbsent(c, () => _StrSeq(c))
      : c;

  late final _Wrap _wrap = _Wrap(_sub(_top), const _Eof());

  late final Clause _top = () {
    final t = _rules[topRuleName];
    if (t == null) throw ArgumentError('top rule "$topRuleName" not found');
    return t;
  }();

  /// All clause nodes reachable from the wrapper, Strs desugared.
  late final List<Clause> _universe = () {
    final seen = <Clause>{};
    final out = <Clause>[];
    void collect(Clause raw) {
      final c = _sub(raw);
      if (!seen.add(c)) return;
      if (c is Ref) {
        final t = _rules[c.ruleName];
        if (t == null) throw ArgumentError('rule "${c.ruleName}" not found');
        collect(t);
      } else if (c is HasOneSubClause) {
        collect(c.subClause);
      } else if (c is HasMultipleSubClauses) {
        c.subClauses.forEach(collect);
      }
      out.add(c);
    }

    collect(_wrap);
    return out;
  }();

  late final Map<Clause, int> _cid = () {
    final m = <Clause, int>{};
    for (var i = 0; i < _universe.length; i++) {
      m[_universe[i]] = i;
    }
    return m;
  }();

  late final List<Seq> _seqs = [for (final c in _universe) if (c is Seq) c];

  // ---- minLen: the cost of fabricating a missing clause ----

  /// For each clause: (minLen, fabSize) of its cheapest witness --
  /// minLen = length of the shortest string the clause can derive (the number
  /// of characters that would have to be inserted to supply it), fabSize =
  /// number of grammar nodes that witness spans. Least fixpoint under
  /// lexicographic (minLen, fabSize), so recursion through First alternatives
  /// resolves to the shortest terminating expansion.
  late final List<(int, int)> _fab = () {
    final m = List<(int, int)>.filled(_universe.length, (_inf, _inf));
    (int, int) sat((int, int) a, (int, int) b) =>
        (a.$1 >= _inf || b.$1 >= _inf) ? (_inf, _inf) : (a.$1 + b.$1, a.$2 + b.$2);
    var changed = true;
    while (changed) {
      changed = false;
      for (var i = 0; i < _universe.length; i++) {
        final c = _universe[i];
        (int, int) val;
        if (c is _Eof) {
          val = (_inf, _inf); // the end of input cannot be fabricated
        } else if (c is Nothing) {
          val = (0, 1);
        } else if (c is Str) {
          val = (c.text.length, 1); // only 1-char Strs survive desugaring
        } else if (c is Terminal) {
          val = (1, 1); // Char, CharSet, AnyChar
        } else if (c is NotFollowedBy || c is FollowedBy) {
          // Zero-width, but skipping it waives a constraint; charge one unit
          // so violations are never free.
          val = (1, 1);
        } else if (c is Optional || (c is Repetition && !c.requireOne)) {
          val = (0, 1); // matches empty; nothing below it is invented
        } else if (c is Repetition) {
          val = _bump(_at(m, c.subClause));
        } else if (c is Ref) {
          val = _bump(_at(m, _rules[c.ruleName]!));
        } else if (c is First) {
          val = (_inf, _inf);
          for (final s in c.subClauses) {
            final x = _at(m, s);
            if (x.$1 < val.$1 || (x.$1 == val.$1 && x.$2 < val.$2)) val = x;
          }
          val = _bump(val);
        } else if (c is Seq) {
          val = (0, 0);
          for (final s in c.subClauses) {
            val = sat(val, _at(m, s));
          }
          val = _bump(val);
        } else {
          val = (1, 1);
        }
        if (val.$1 < m[i].$1 || (val.$1 == m[i].$1 && val.$2 < m[i].$2)) {
          m[i] = val;
          changed = true;
        }
      }
    }
    return m;
  }();

  static (int, int) _bump((int, int) v) =>
      v.$1 >= _inf ? (_inf, _inf) : (v.$1, v.$2 + 1);

  (int, int) _at(List<(int, int)> m, Clause c) => m[_cid[_sub(c)]!];

  // Deduction indexes (built once).
  late final Map<int, List<Clause>> _unaryParents = _buildUnary();
  late final Map<int, List<Repetition>> _repParents = _buildRepParents();
  late final Map<int, List<(Seq, int)>> _seqDots = _buildSeqDots();

  Map<int, List<Clause>> _buildUnary() {
    final m = <int, List<Clause>>{};
    for (final c in _universe) {
      if (c is Ref) {
        m.putIfAbsent(_cid[_sub(_rules[c.ruleName]!)]!, () => []).add(c);
      } else if (c is First) {
        for (final s in c.subClauses) {
          m.putIfAbsent(_cid[_sub(s)]!, () => []).add(c);
        }
      } else if (c is Optional) {
        m.putIfAbsent(_cid[_sub(c.subClause)]!, () => []).add(c);
      }
    }
    return m;
  }

  Map<int, List<Repetition>> _buildRepParents() {
    final m = <int, List<Repetition>>{};
    for (final c in _universe) {
      if (c is Repetition) {
        m.putIfAbsent(_cid[_sub(c.subClause)]!, () => []).add(c);
      }
    }
    return m;
  }

  Map<int, List<(Seq, int)>> _buildSeqDots() {
    final m = <int, List<(Seq, int)>>{};
    for (final c in _universe) {
      if (c is Seq) {
        for (var i = 0; i < c.subClauses.length; i++) {
          m.putIfAbsent(_cid[_sub(c.subClauses[i])]!, () => []).add((c, i));
        }
      }
    }
    return m;
  }

  // ---- per-recover() state ----
  late String input;
  late int n;

  /// `_dataAt[p]` = millibits of author data destroyed by discarding
  /// `input[p]`: the width of the NARROWEST class or literal in the grammar
  /// that can name it. Derived entirely from the grammar -- no constants.
  late List<int> _dataAt;

  /// MEASUREMENT ONLY: `h(p)` for the input of the last `recover` call.
  List<int> get dataAt => _dataAt;

  void _buildDataAt() {
    _dataAt = List<int>.filled(n, 0);
    final floor = _clsBits(0x110000);
    for (var p = 0; p < n; p++) {
      final ch = input.codeUnitAt(p);
      var best = floor; // unnameable characters are all equally expensive
      for (final c in _universe) {
        int? w;
        if (c is Char) {
          if (c.char.codeUnitAt(0) == ch) w = 0;
        } else if (c is Str) {
          if (c.text.codeUnitAt(0) == ch) w = 0;
        } else if (c is CharSet) {
          if (_csMatch(c, ch)) w = _clsBits(_csSize(c));
        } else if (c is AnyChar) {
          w = floor;
        }
        if (w != null && w < best) best = w;
        if (best == 0) break;
      }
      _dataAt[p] = dataMode == 0 ? 0 : best;
    }
  }

  /// MEASUREMENT ONLY. dataMode 2 charges only SUB, on the argument that a SPAN
  /// claims the character was never the author's at all (a pure channel
  /// insertion), so discarding it destroys nothing; 3 charges only SPAN.
  int _spanData(int p) => dataMode == 2 ? 0 : _dataAt[p];
  int _subData(int p) => dataMode == 3 ? 0 : _dataAt[p];

  /// A kept input character at `p`, matched by a class of width `b` millibits:
  /// zero cost, `b` class bits, and `b - h(p)` regret.
  _V _keptV(int b, int p) {
    // h(p) is the minimum width over ALL classes of G containing input[p], and
    // the matching class is one of them, so the regret can never go negative.
    // Non-negativity is what keeps the lex order monotone under _add.
    assert(b >= _dataAt[p], 'regret went negative: $b < ${_dataAt[p]} at $p');
    final v = _termV(b);
    return (v.$1, v.$2, v.$3, v.$4, v.$5, v.$6, v.$7, b - _dataAt[p]);
  }

  /// A discarded input character at `p`: all of its `h(p)` bits go unaccounted.
  int _lostRegret(int p) =>
      spanRegretMode == 1 ? _clsBits(0x110000) : _dataAt[p];

  /// A substituted character at `p`, overwritten by a class of width `b`:
  /// evidence destroyed plus claim asserted.
  int _subRegret(int p, int b) => subRegretMode == 0
      ? _lostRegret(p)
      : _lostRegret(p) + _clsBits(0x110000) - b;

  /// Millibits a fabricated subtree of `ml` characters asserts without evidence.
  int _fabRegret(int ml) => fabRegretMode == 0
      ? 0
      : fabRegretMode == 1
          ? ml * _clsBits(0x110000)
          : ml;
  Parser? _oracle;
  late List<_E> _heap;
  late Map<int, Map<int, List<_E>>> _completes; // cid*(n+1)+s -> end -> Pareto
  /// (cid*256+d)*(n+1)+pos  ->  start  ->  Pareto set of partials.
  /// Two indexes in one: the outer key is the SCAN index (every partial
  /// waiting for child d at pos, whatever its start -- what a completed child
  /// must step), the inner key is the DOMINANCE class (dominance compares
  /// derivations of the same item, so only same-start entries may dominate).
  /// Keeping them separate is what stops insertion from costing O(all starts).
  late Map<int, Map<int, List<_E>>> _partialsAt;
  late Map<int, List<_E>> _repEnding; // repCid*(n+1)+end -> rep chain states
  late List<MissingObligation> _missing;

  int lastTotalCost = -1;

  /// The winning repair's L1 norm: total information discrepancy, millibits.
  int lastRegret = -1;
  int lastPops = -1;
  int lastPushes = -1;

  /// MEASUREMENT ONLY. Pushes performed by `_axioms` alone, i.e. before the
  /// search proper begins. The axiom set is EAGER -- every terminal clause is
  /// seeded at every input position (with a SUB item wherever it mismatches),
  /// and every Seq gets a dot-0 seed at every position -- so this is the size of
  /// the bottom-up layer the search has to wade through whether it needs it or
  /// not. Compare against `lastPushes` to see how much of the work is the eager
  /// layer versus derived items.
  int lastAxiomPushes = -1;

  /// MEASUREMENT ONLY. Distinct item SLOTS the search touched: `(cid,s,e)` for
  /// completes and `(cid,d,pos,s)` for partials. Compared against `lastPops`
  /// this separates two very different costs -- the size of the item space
  /// itself, versus how many times best-first search revisits it. If pops
  /// greatly exceed slots, a position-ordered chart keeping one best value per
  /// slot would do strictly less work than the priority queue does.
  int lastSlots = -1;

  /// MEASUREMENT ONLY. `lastPopsByCost[k]` = items popped whose cost tier was k.
  /// Dijkstra on the lexicographic pair must drain every item cheaper than the
  /// goal, so this shows whether the tail is spent below the optimal cost or
  /// spinning on regret ties AT the optimal cost.
  List<int> lastPopsByCost = const [];

  // ---- heap ----

  void _hpush(_E x) {
    _heap.add(x);
    var i = _heap.length - 1;
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (_cmp(_heap[p].v, x.v) <= 0) break;
      _heap[i] = _heap[p];
      i = p;
    }
    _heap[i] = x;
  }

  _E _hpop() {
    final top = _heap[0];
    final last = _heap.removeLast();
    if (_heap.isNotEmpty) {
      var i = 0;
      while (true) {
        final l = 2 * i + 1, r = 2 * i + 2;
        var m = i;
        _E mv = last;
        if (l < _heap.length && _cmp(_heap[l].v, mv.v) < 0) {
          m = l;
          mv = _heap[l];
        }
        if (r < _heap.length && _cmp(_heap[r].v, mv.v) < 0) {
          m = r;
        }
        if (m == i) break;
        _heap[i] = _heap[m];
        i = m;
      }
      _heap[i] = last;
    }
    return top;
  }

  // ---- item insertion with Pareto dominance ----

  void _addComplete(int cid, int s, int e, _V v, int tag,
      [_E? a, _E? b, bool pend = false]) {
    final key = cid * (n + 1) + s;
    final byEnd = _completes.putIfAbsent(key, () => {});
    final list = byEnd.putIfAbsent(e, () => []);
    for (final x in list) {
      // Pending and settled repetition states are different kinds of item and
      // never dominate each other (a pending state cannot complete).
      if (x.pend != pend || x.dead || !_dom(x.v, v)) continue;
      return;
    }
    for (final x in list) {
      if (x.pend == pend && !x.dead && _dom(v, x.v)) x.dead = true;
    }
    final entry = _E(false, cid, s, 0, e, v, tag, a, b, pend);
    list.add(entry);
    _hpush(entry);
    lastPushes++;
    if (_universe[cid] is Repetition && _isChainState(entry)) {
      _repEnding.putIfAbsent(cid * (n + 1) + e, () => []).add(entry);
    }
  }

  /// Repetition states that may take a further item: the free empty
  /// (ZeroOrMore), genuine chains, and gap-crossing pending states. NOT a
  /// zero-width single take (the pure parser stops a repetition there).
  bool _isChainState(_E x) =>
      x.tag == _tEmpty ||
      x.tag == _tRepGap ||
      ((x.tag == _tRepSeed || x.tag == _tRepExt) && x.e > x.s);

  void _addPartial(Seq seq, int s, int d, int pos, _V v, int tag, _E? prev,
      [_E? child]) {
    final cid = _cid[seq]!;
    // A finished partial becomes the complete Seq item.
    if (d == seq.subClauses.length) {
      final p = _E(true, cid, s, d, pos, v, tag, prev, child);
      _addComplete(cid, s, pos, v, _tSeq, p);
      return;
    }
    final key = (cid * 256 + d) * (n + 1) + pos;
    final list = _partialsAt.putIfAbsent(key, () => {}).putIfAbsent(s, () => []);
    for (final x in list) {
      if (x.dead || !_dom(x.v, v)) continue;
      return;
    }
    for (final x in list) {
      if (!x.dead && _dom(v, x.v)) x.dead = true;
    }
    final entry = _E(true, cid, s, d, pos, v, tag, prev, child);
    list.add(entry);
    _hpush(entry);
    lastPushes++;
  }

  // ---- recover ----

  SkipResult recover(String input) {
    this.input = input;
    n = input.length;
    _oracle = Parser(rules: rules, topRuleName: topRuleName, input: input);
    // The zero-cost slice, evaluated lazily: the pure parser. Valid input
    // never reaches the agenda.
    final pure = _oracle!.parse();
    if (!pure.hasSyntaxErrors && !forceSearch) {
      lastTotalCost = 0;
      lastRegret = 0;
      lastPops = 0;
      lastPushes = 0;
      return SkipResult(pure.root, const [], const [], 0, false);
    }

    // Regret is at most log|Sigma| per column, over at most the n input columns
    // plus the fabricated ones (themselves bounded by n + the shortest witness
    // of the whole grammar). M past that bound makes `cost * M + regret` order
    // repairs exactly as the lexicographic pair does; the goal asserts it held.
    final minTop = _fab[_cid[_wrap]!].$1;
    _bigM = (2 * n + (minTop >= _inf ? 0 : minTop) + 2) * (_clsBits(0x110000) + 1);

    _heap = [];
    _completes = {};
    _partialsAt = {};
    _repEnding = {};
    _missing = [];
    lastPops = 0;
    lastPushes = 0;
    _setLexDom();
    _buildDataAt();
    _axioms();
    lastAxiomPushes = lastPushes;
    lastPopsByCost = <int>[];

    final wrapCid = _cid[_wrap]!;
    _E? goal;
    while (_heap.isNotEmpty) {
      final x = _hpop();
      if (x.dead || x.popped) continue;
      x.popped = true;
      lastPops++;
      while (lastPopsByCost.length <= x.v.$1) {
        lastPopsByCost.add(0);
      }
      lastPopsByCost[x.v.$1]++;
      // Superiority holds, so the first goal pop is already optimal: there is
      // nothing to drain and no witness left to improve.
      if (!x.partial && x.cid == wrapCid && x.s == 0 && x.e == n) {
        goal = x;
        break;
      }
      if (x.partial) {
        _firePartial(x);
      } else {
        _fireComplete(x);
      }
    }
    lastSlots = 0;
    for (final byEnd in _completes.values) {
      lastSlots += byEnd.length;
    }
    for (final byStart in _partialsAt.values) {
      lastSlots += byStart.length;
    }
    if (goal == null) throw StateError('agenda exhausted without goal');
    lastTotalCost = goal.v.$1;
    lastRegret = goal.v.$8;
    assert(lastRegret < _bigM,
        'regret $lastRegret reached the M bound $_bigM: the scalar collapse '
        'cost * M + regret would no longer induce the lexicographic order');
    assert(goal.v.$4 < _bigM, 'fabSize ${goal.v.$4} reached the M bound $_bigM');

    final root = _build(goal);
    final raw = <SyntaxError>[];
    void walk(MatchResult m) {
      if (m is SyntaxError) {
        raw.add(m);
        return;
      }
      m.subClauseMatches.forEach(walk);
    }

    walk(root);
    raw.sort((a, b) => a.pos.compareTo(b.pos));
    final spans = <SyntaxError>[];
    for (final s in raw) {
      if (spans.isNotEmpty && spans.last.pos + spans.last.len == s.pos) {
        final last = spans.removeLast();
        spans.add(SyntaxError(pos: last.pos, len: last.len + s.len));
      } else {
        spans.add(s);
      }
    }
    _missing.sort((a, b) => a.pos.compareTo(b.pos));
    return SkipResult(root, spans, _missing, 1, false);
  }

  void _axioms() {
    for (final c in _universe) {
      final ci = _cid[c]!;
      if (c is Char) {
        final ch = c.char.codeUnitAt(0);
        const b = 0; // a literal names itself: 0 bits
        for (var p = 0; p < n; p++) {
          if (input.codeUnitAt(p) == ch) {
            _addComplete(ci, p, p + 1, _keptV(b, p), _tTerm);
          } else if (substitution) {
            _addComplete(ci, p, p + 1,
                (1, p, p, 0, 0, 1, _subData(p), _subRegret(p, b)), _tSub);
          }
        }
      } else if (c is CharSet) {
        final b = _clsBits(_csSize(c));
        for (var p = 0; p < n; p++) {
          if (_csMatch(c, input.codeUnitAt(p))) {
            _addComplete(ci, p, p + 1, _keptV(b, p), _tTerm);
          } else if (substitution) {
            _addComplete(ci, p, p + 1,
                (1, p, p, 0, 0, 1, _subData(p), _subRegret(p, b)), _tSub);
          }
        }
      } else if (c is Str) {
        // Only single-char Strs remain after desugaring.
        final ch = c.text.codeUnitAt(0);
        const b = 0;
        for (var p = 0; p < n; p++) {
          if (input.codeUnitAt(p) == ch) {
            _addComplete(ci, p, p + 1, _keptV(b, p), _tTerm);
          } else if (substitution) {
            _addComplete(ci, p, p + 1,
                (1, p, p, 0, 0, 1, _subData(p), _subRegret(p, b)), _tSub);
          }
        }
      } else if (c is AnyChar) {
        final b = _clsBits(0x110000);
        for (var p = 0; p < n; p++) {
          _addComplete(ci, p, p + 1, _keptV(b, p), _tTerm);
        }
      } else if (c is Nothing) {
        for (var p = 0; p <= n; p++) {
          _addComplete(ci, p, p, _zero, _tEmpty);
        }
      } else if (c is Repetition && !c.requireOne) {
        for (var p = 0; p <= n; p++) {
          _addComplete(ci, p, p, _zero, _tEmpty);
        }
      } else if (c is Optional) {
        for (var p = 0; p <= n; p++) {
          _addComplete(ci, p, p, _zero, _tEmpty);
        }
      } else if (c is NotFollowedBy) {
        for (var p = 0; p <= n; p++) {
          if (c.subClause.match(_oracle!, p).isMismatch) {
            _addComplete(ci, p, p, _zero, _tPred);
          }
        }
      } else if (c is FollowedBy) {
        for (var p = 0; p <= n; p++) {
          if (!c.subClause.match(_oracle!, p).isMismatch) {
            _addComplete(ci, p, p, _zero, _tPred);
          }
        }
      } else if (c is _Eof) {
        _addComplete(ci, n, n, _zero, _tEmpty);
      }
    }
    // Dot-0 seeds. A seed exists only so that its Seq can FAB a missing first
    // subclause (or match it); leading garbage is NOT absorbed here -- by the
    // hoisting theorem it belongs to the parent's dot, a repetition gap, or
    // the wrapper.
    for (final seq in _seqs) {
      for (var p = 0; p <= n; p++) {
        _addPartial(seq, p, 0, p, _zero, _tSeed, null);
      }
    }
  }

  bool _csMatch(CharSet cs, int ch) {
    var inSet = false;
    for (final (lo, hi) in cs.ranges) {
      if (ch >= lo && ch <= hi) {
        inSet = true;
        break;
      }
    }
    return cs.inverted ? !inSet : inSet;
  }

  void _fireComplete(_E x) {
    final c = _universe[x.cid];
    // A pending (gap-crossing) repetition state is not a match of the
    // repetition: it may only take a further item or cross another gap.
    if (!x.pend) {
      // Unary parents (Ref / First / Optional).
      final ups = _unaryParents[x.cid];
      if (ups != null) {
        for (final p in ups) {
          _addComplete(_cid[p]!, x.s, x.e, x.v, _tUnary, x);
        }
      }
      // Repetition parents.
      final reps = _repParents[x.cid];
      if (reps != null) {
        for (final rep in reps) {
          final rc = _cid[rep]!;
          if (x.e > x.s) {
            _addComplete(rc, x.s, x.e, x.v, _tRepSeed, x); // first item
            // Extend previously popped rep states ending at x.s.
            final ending = _repEnding[rc * (n + 1) + x.s];
            if (ending != null) {
              for (final r in ending) {
                if (r.popped && !r.dead) {
                  _addComplete(rc, r.s, x.e, _add(r.v, x.v), _tRepExt, r, x);
                }
              }
            }
          } else if (rep.requireOne && x.v.$1 >= 1) {
            // A zero-width item only as a repair (the pure parser mismatches
            // OneOrMore on a zero-width first item).
            _addComplete(rc, x.s, x.s, x.v, _tRepSeed, x);
          }
        }
      }
      // Sequence stepping: MATCH a subclause at a waiting dot.
      final dots = _seqDots[x.cid];
      if (dots != null) {
        for (final (seq, d) in dots) {
          final key = (_cid[seq]! * 256 + d) * (n + 1) + x.s;
          final byStart = _partialsAt[key];
          if (byStart != null) {
            // Safe to insert while iterating: every _addPartial below targets
            // dot d+1, a different outer key, so this map is never mutated.
            for (final parts in byStart.values) {
              for (final p in parts) {
                if (p.popped && !p.dead) {
                  _addPartial(
                      seq, p.s, d + 1, x.e, _add(p.v, x.v), _tStep, p, x);
                }
              }
            }
          }
        }
      }
    }
    // Repetition self: extend with popped items starting at x.e, and cross a
    // gap (the hoist target for garbage between repetition items).
    if (c is Repetition && _isChainState(x)) {
      final itemCid = _cid[_sub(c.subClause)]!;
      final byEnd = _completes[itemCid * (n + 1) + x.e];
      if (byEnd != null) {
        byEnd.forEach((e2, list) {
          if (e2 <= x.e) return;
          for (final it in list) {
            if (it.popped && !it.dead) {
              _addComplete(x.cid, x.s, e2, _add(x.v, it.v), _tRepExt, x, it);
            }
          }
        });
      }
      // GAP: only from a chain that already holds a real item -- a gap before
      // the first item hoists to the parent instead.
      if (x.e < n && x.e > x.s) {
        _addComplete(x.cid, x.s, x.e + 1, _add(x.v, (1, x.e, x.e, 0, 0, 0, _spanData(x.e), _lostRegret(x.e))),
            _tRepGap, x, null, true);
      }
    }
  }

  void _firePartial(_E x) {
    final seq = _universe[x.cid] as Seq;
    final sub = _sub(seq.subClauses[x.d]);
    // MATCH: consume an already-derived complete for the expected subclause.
    final byEnd = _completes[_cid[sub]! * (n + 1) + x.e];
    if (byEnd != null) {
      byEnd.forEach((e2, list) {
        for (final it in list) {
          if (it.popped && !it.dead && !it.pend) {
            _addPartial(seq, x.s, x.d + 1, e2, _add(x.v, it.v), _tStep, x, it);
          }
        }
      });
    }
    // SPAN: delete one input character here. Denied at dot 0 (hoisting), with
    // the goal wrapper the sole exception, as it has no parent to hoist to.
    if (x.e < n && (x.d > 0 || seq is _Wrap)) {
      _addPartial(seq, x.s, x.d, x.e + 1, _add(x.v, (1, x.e, x.e, 0, 0, 0, _spanData(x.e), _lostRegret(x.e))),
          _tSpanStep, x);
    }
    // FAB: the subclause is missing; insert its shortest witness. A nullable
    // subclause is never fabricated -- it already has a zero-cost empty
    // derivation, so FAB would only duplicate it and forge an edit position.
    final (ml, fs) = _fab[_cid[sub]!];
    if (ml < _inf && ml > 0) {
      _addPartial(seq, x.s, x.d + 1, x.e, _add(x.v, (ml, x.e, x.e, fs, 0, 0, 0, _fabRegret(fs))),
          _tFabStep, x);
    }
  }

  // ---- tree building from backpointers ----

  Clause _outClause(_E x) {
    final c = _universe[x.cid];
    return c is _StrSeq ? c.orig : c;
  }

  MatchResult _build(_E x) {
    switch (x.tag) {
      case _tTerm:
        return Match(_outClause(x), x.s, x.e - x.s);
      case _tSub:
        // The character is present but wrong: report it as a one-char error
        // span. It still covers the input, so leaf coverage is unaffected.
        return SyntaxError(pos: x.s, len: 1);
      case _tEmpty:
      case _tPred:
        return Match(_outClause(x), x.s, 0);
      case _tUnary:
      case _tRepSeed:
        return Match(_outClause(x), 0, 0, subClauseMatches: [_build(x.a!)]);
      case _tRepExt:
      case _tRepGap:
        // Walk the repetition chain back to its seed, collecting items and
        // gap characters in reverse.
        final kids = <MatchResult>[];
        _E cur = x;
        while (true) {
          if (cur.tag == _tRepGap) {
            kids.add(SyntaxError(pos: cur.e - 1, len: 1));
            cur = cur.a!;
          } else if (cur.tag == _tRepExt) {
            kids.add(_build(cur.b!));
            cur = cur.a!;
          } else {
            if (cur.tag == _tRepSeed) kids.add(_build(cur.a!));
            break;
          }
        }
        return Match(_outClause(x), 0, 0,
            subClauseMatches: kids.reversed.toList());
      case _tSeq:
        final kids = <MatchResult>[];
        _E? p = x.a; // final partial
        while (p != null && p.tag != _tSeed) {
          switch (p.tag) {
            case _tStep:
              kids.add(_build(p.b!));
            case _tSpanStep:
              kids.add(SyntaxError(pos: p.e - 1, len: 1));
            case _tFabStep:
              // subClauses holds the ORIGINAL clauses (desugaring happens at
              // lookup), so this reports the literal/rule the user wrote.
              final missing = (_universe[p.cid] as Seq).subClauses[p.d - 1];
              _missing.add(MissingObligation(missing, p.e));
              kids.add(Match(missing, p.e, 0));
          }
          p = p.a;
        }
        return Match(_outClause(x), 0, 0,
            subClauseMatches: kids.reversed.toList());
      default:
        throw StateError('bad backpointer tag ${x.tag}');
    }
  }
}
