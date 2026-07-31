// ONE harness for the full trade-off table: EVERY engine ever built -- sd3/sd5/v6,
// the shipped `dot`, and m12 through m40 -- measured on every metric in a single
// process so no number is recalled from a previous session's notes.
//
// CAVEAT, and it is why the isolated numbers exist: a single process warms as it
// goes, so an engine registered LATE looks faster than the same engine registered
// FIRST (measured: 377 vs 314 battms for m26). This table is for the correctness
// and shape columns, which are order-independent. For a timing A/B, run one engine
// per process by passing its name.
//
// ADDING AN ENGINE: register it here, then run THIS engine plus m26 as a
// reference (`final_table.dart m41,m26`) and APPEND those two rows to
// LESSONS_LEARNED.md 5j. Do not regenerate the whole table -- the old engines are
// not changing, so re-measuring them only burns ~12 minutes and rewrites their
// timings with the drift of the day. The reference row is what makes a newly
// appended row comparable to the ones already there.
//
// Six metric groups, each of which can independently disqualify an engine:
//   battery  -- shape / cover / cost histogram / crashes on the 519 mutants
//   valid    -- the 7 well-formed documents must come back untouched
//   latency  -- 12 synthetic cases, min-of-5, all engines alternating per case
//   truth    -- agreement with brute-force minimum edit distance (5 grammars)
//   pred     -- the same agreement on the LOOKAHEAD corner cases (see predCases)
//   depth    -- the input length at which native recursion overflows the stack
//
// WHY `pred` EXISTS. Every column above it is blind to predicates, because the
// JSON grammar has no lookahead and the five `truthCases` grammars have none
// either. m47 was UNSOUND -- it reported cost 0 for repairs that do not exist --
// and every column in this table was clean for it. A defect the table cannot see
// is a defect the table will let through, so the corner cases found while
// building m45..m49 are now IN the table, with the disqualifying direction
// (`unsnd`, an under-report) given a column of its own.
import 'dart:math';
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/parser/combinators.dart';
import 'package:squirrel_parser/src/parser/match_result.dart';
import 'package:squirrel_parser/src/recovery/dot_recovery.dart';
import 'package:squirrel_parser/src/recovery/skip_recovery.dart' show SkipResult;
import 'sd3.dart' as g3;
import 'sd5.dart' as g5;
import 'sd6.dart' as g6;
import 'm12.dart' as g12;
import 'm33.dart' as g33;
import 'm34.dart' as g34;
import 'm15.dart' as g15;
import 'm16.dart' as g16;
import 'm17.dart' as g17;
import 'm18.dart' as g18;
import 'm19.dart' as g19;
import 'm20.dart' as g20;
import 'm21.dart' as g21;
import 'm22.dart' as g22;
import 'm23.dart' as g23;
import 'm24.dart' as g24;
import 'm25.dart' as g25;
import 'm26.dart' as g26;
import 'm29.dart' as g29;
import 'm30.dart' as g30;
import 'm31.dart' as g31;
import 'm32.dart' as g32;
import 'm35.dart' as g35;
import 'm36.dart' as g36;
import 'm37.dart' as g37;
import 'm38.dart' as g38;
import 'm39.dart' as g39;
import 'm40.dart' as g40;
import 'm41.dart' as g41;
import 'm42.dart' as g42;
import 'm43.dart' as g43;
import 'm44.dart' as g44;
import 'm45.dart' as g45;
import 'm46.dart' as g46;
import 'm47.dart' as g47;
import 'm48.dart' as g48;
import 'm49.dart' as g49;
import 'm50.dart' as g50;
import 'm51.dart' as g51;
import 'm52.dart' as g52;
import 'm53.dart' as g53;
import 'm57.dart' as g57;
import 'm58.dart' as g58;
import 'm59.dart' as g59;
import 'm60.dart' as g60;
import 'm61.dart' as g61;
import 'm62.dart' as g62;
import 'm63.dart' as g63;
import 'm64.dart' as g64;
import 'm65.dart' as g65;
import 'm66.dart' as g66;
import 'm67.dart' as g67;
import 'm68.dart' as g68;
import 'cgfr1.dart' as gcgfr1;
import 'cgfr2.dart' as gcgfr2;
import 'cgfr5.dart' as gcgfr5;
import 'm69.dart' as g69;
import 'm70.dart' as g70;
import 'm71.dart' as g71;
import 'm72.dart' as g72;
import 'm27.dart' as g27;
import 'm28.dart' as g28;

const String jsonGrammar = '''
JSON <- WS Value WS;
Value <- Object / Array / String / Number / Boolean / Null;
Object <- '{' WS (Member (WS ',' WS Member)*)? WS '}';
Member <- String WS ':' WS Value;
Array <- '[' WS (Value (WS ',' WS Value)*)? WS ']';
String <- '"' Character* '"';
Character <- [^"\\\\] / ('\\\\' Escape);
Escape <- '"' / '\\\\' / '/' / 'b' / 'f' / 'n' / 'r' / 't' / ('u' [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F]);
Number <- Integer Fraction? Exponent?;
Integer <- '-'? (([1-9] [0-9]+) / [0-9]);
Fraction <- '.' [0-9]+;
Exponent <- ("e" / "E") ("+" / "-")? [0-9]+;
Boolean <- "true" / "false";
Null <- "null";
~WS <- [ \\t\\n\\r]*;
''';

const structural = <String>{
  'Object', 'Array', 'Member', 'String', 'Number', 'Boolean', 'Null', 'Value',
};

String treeShape(MatchResult r) {
  final sb = StringBuffer();
  void walk(MatchResult m) {
    final c = m.clause;
    if (c is Ref && structural.contains(c.ruleName)) {
      sb.write('${c.ruleName}(');
      m.subClauseMatches.forEach(walk);
      sb.write(')');
    } else {
      m.subClauseMatches.forEach(walk);
    }
  }

  walk(r);
  return sb.toString();
}

bool covers(MatchResult root, int len) {
  var pos = 0;
  var ok = true;
  void walk(MatchResult m) {
    if (!ok) return;
    if (m is SyntaxError || m.subClauseMatches.isEmpty) {
      if (m.len == 0) return;
      if (m.pos != pos) ok = false;
      pos = m.pos + m.len;
      return;
    }
    m.subClauseMatches.forEach(walk);
  }

  walk(root);
  return ok && pos == len;
}

/// `dot` is the original recovery, which lives in the frozen library and so
/// carries no markers; it is counted from the end of its import block, which is
/// what the markers would have delimited anyway. `v6` is the table's name for
/// sd6.
const _locSource = {
  'v6': 'sd6',
  'dot': '../../lib/src/recovery/dot_recovery',
};

final _locCache = <String, int>{};

int _locOf(String name) => _locCache.putIfAbsent(name, () {
      final dir = File.fromUri(Platform.script).parent.path;
      final stem = _locSource[name] ?? name;
      final src = File('$dir/$stem.dart');
      if (!src.existsSync()) {
        throw StateError('engine $name has no source at ${src.path}');
      }
      final lines = src.readAsLinesSync();
      var from = 0, to = lines.length;
      final start = lines.indexOf('// ERROR RECOVERY START');
      if (start >= 0) {
        from = start + 1;
        final end = lines.indexOf('// ERROR RECOVERY END');
        if (end > start) to = end;
      } else {
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].startsWith('import ')) from = i + 1;
        }
      }
      var n = 0;
      for (final l in lines.sublist(from, to)) {
        final s = l.trim();
        if (s.isNotEmpty && !s.startsWith('//')) n++;
      }
      return n;
    });

/// One engine, behind the uniform surface every variant happens to share.
class Eng {
  Eng(this.name, this.make, {this.bugs = '-'});
  final String name;

  /// LOC IS MEASURED, NOT DECLARED: the non-blank, non-comment lines between
  /// `// ERROR RECOVERY START` and `// ERROR RECOVERY END` in the engine's own
  /// source, read when the row is printed. Two reasons it works this way:
  ///
  ///   1. It used to be an integer written here by hand, and it had gone stale
  ///      for EVERY row at once -- the one column nobody re-derives.
  ///   2. An engine may now carry its own copy of the parser, so that it is
  ///      free to change it. That copy is identical wherever it appears and
  ///      sits OUTSIDE the markers, so it is charged to nobody: what this
  ///      column compares is the recovery code, and only that.
  ///
  /// An engine that reaches its work by importing ANOTHER engine would show a
  /// small number here for a large program. Those have been folded in, so what
  /// the file declares is what the engine costs.
  int get loc => _locOf(name);

  /// ELEGANCE, 0-10. THIS IS THE ONE COLUMN IN THIS TABLE THAT IS A JUDGMENT AND
  /// NOT A MEASUREMENT, and it is labelled as such wherever it is printed. It
  /// scores the CODE AND THE CONCEPTS -- not the answers, which have five columns
  /// of their own -- against five things the project has repeatedly found to
  /// matter, weighted equally:
  ///
  ///   1. HOW MANY MECHANISMS. A case in `_compute` per clause kind, a rewrite in
  ///      the builder, a fixed point over the grammar, a hand-written rule: each
  ///      is a thing a reader must hold in mind. Fewer is better, and DELETING one
  ///      scores higher than adding a good one.
  ///   2. IS IT DERIVED OR CHOSEN. A number someone picked by measurement is a
  ///      parameter, and a parameter is a confession. Derived bounds are free.
  ///   3. IS IT THE PARSER'S OWN IDEA. Machinery adopted from `MemoEntry` /
  ///      `combinators.dart` costs nothing to justify; machinery invented for
  ///      recovery has to argue for itself.
  ///   4. COMPACTNESS, as LOC -- correlated with the above but not the same, and
  ///      the column is printed beside this one so the reader can see the trade.
  ///   5. COMPREHENSIBILITY: can the engine be stated in one sentence that is
  ///      actually true of the code.
  ///
  /// A reader who disagrees with a score can read `elegNotes` below, which gives
  /// the one-line reason for every one of them, and re-score it. That is the point
  /// of writing them down rather than asserting a ranking. Kept in a map beside
  /// the reasons rather than as a constructor argument, so a score and its
  /// justification cannot drift apart.
  int get eleg => elegNotes[name]!.$1;

  /// Known defects SPECIFIC to this engine, as comma-separated tags expanded in
  /// the legend below. Four defects are shared by EVERY engine in the table and
  /// are deliberately not repeated per row -- see `sharedBugs`.
  final String bugs;

  /// Builds a fresh engine over `rules`/`top`, returning (recover, cost, costOnly).
  final (SkipResult Function(String), int Function(), int Function(String))
      Function(Map<String, Clause>, String) make;
}

/// Defects every engine in this table has, from `dot` onward. Listing them in the
/// per-engine column would fill it with the same four tags on every row.
const sharedBugs = <String>[
  'PEG   repairs toward the CFG reading of the grammar, not the PEG one:  a '
      'possessive `*` and a committed `/` are both treated as if any\n'
      '      alternative/stop were available. 4 of 5 conformance cases wrong, '
      'identically, in every engine back to `dot` (LESSONS 5b). The\n'
      '      `cost` column cannot see it -- its grammars are prefix-disjoint, '
      'so the CFG and PEG readings coincide there.',
  'RR    right-recursive grammars overflow the native stack (the RRmax column). '
      'Inherited from the pure parser, which shows the same\n'
      '      asymmetry; recovery worsens the threshold ~4x because its descent '
      'adds frames per position. FIXED by an explicit worklist in m50 (I8), the '
      'only row here besides `dot` at >=4096, so the tag excepts m50; what is '
      'left there is the pure parser\'s own ceiling (k~2100) and the witness '
      'descent\'s walk over an O(n)-deep output tree.',
  'd13   `del@13` and `swap@13` of the battery document are never recovered to '
      'the original shape, which is the 517/519 ceiling.',
  'K40   `maxCost` is a hard search ceiling (default 40) in every engine BEFORE '
      'm44. A repair costing more is not found at all:\n'
      '      cost -1, and the whole input is reported as one error span. It was '
      'the last tuning parameter in the m-line, and m44\n'
      '      onward DERIVE it instead -- `_inputLen + _goalFromNothing`, the '
      'price of discarding the input and fabricating the goal,\n'
      '      which is a repair that always exists -- so the tag does not apply '
      'to m44, m45, m46, m48 or m49.',
];

/// Tags used in the per-engine `bugs` column. Every tag here is either visible
/// in a column of the table below or cites the measurement that found it.
const bugLegend = <String, String>{
  'LR': 'NON-MINIMAL REPAIRS ON LEFT-RECURSIVE GRAMMARS. The memo cached its own '
      'in-progress placeholder as a final answer, so the\n'
      '        left-recursive alternative contributed nothing: cost 2-3 where the '
      'truth is 1, and from n>=512 no repair at all (-1).\n'
      '        Visible in the `cost` column -- 32-38/44 against 44/44. Fixed by '
      'A5 in m23.',
  'null': 'RECONSTRUCTION DIVERGES ON NULLABLE LEFT RECURSION. `E <- E N` with N '
      'nullable re-derives E over the same extent at zero\n'
      '        extra Delta, so the Delta-exact descent takes that cycle forever '
      '(StackOverflowError). Visible in `tree` (42/44 while\n'
      '        `cost` is 44/44 -- the cost is right and the witness cannot be '
      'built). Fixed by the Ref re-entry guard in m24.',
  'empty': 'RangeError on empty input: the leading-span loop ran to the budget '
      'without bounding by input length. Found only because a\n'
      '        degenerate-input gate was written separately from the mutation '
      'battery, which can never produce the empty string.',
  'shape': 'loses shape points against the 517/519 line -- see the `shape` '
      'column. Not a crash; a worse tree on inputs the better\n'
      '        engines get right.',
  'slow': 'far off the pace on `battms` and/or `latms`; kept as a recorded '
      'negative, not as a candidate.',
  'batt': '20-35% slower on the battery than m26 (which is all K=1), because a '
      'complete CFG level 0 replaces m26\'s O(1) oracle call.\n'
      '        Buys latency and large-K time back; the trade is real in both '
      'directions.',
  'stack': 'stack ceiling collapses -- see `LRmax`/`RRmax`. m30/m31 fail below '
      '512 on BOTH recursion directions.',
  'latent': 'A WRONG-COST DEFECT SITS BEHIND A FLAG. m31 splits reach-cost from '
      'complete-cost; with `debugShortcut(true)` it reports\n'
      '        cost 4 on JSON repairs whose truth is 1, because the split removes '
      'the recomputation that was silently repairing m26\'s\n'
      '        greedy level 0. Committed with the shortcut OFF, which is why the '
      'row scores 44/44 and is 15x slower than m26.',
  'pegfix': 'ATTEMPTS THE PEG FIX AND PAYS FOR IT. The guard consults the '
      'ORIGINAL input, but PEG semantics quantify over the REPAIRED\n'
      '        string, so it rejects legitimate repairs: m27 494/519 with hist '
      '{1:478, 2:41}, m29 492/519 with {1:474, 2:45} and cost\n'
      '        42/44. Not fixable by a better local predicate (LESSONS 5e).',
  'over': 'the doubling deepening schedule overshoots whenever K is not a power '
      'of two, running budget 2K instead of K and paying ~5x\n'
      '        for it -- the `latms` column, 1071 against m26\'s 249.',
  'noop': 'DOES NOT DO WHAT IT WAS BUILT FOR. m36 guards PEG semantics at budget '
      '0 only; round 0 rejects the illegal parse but it costs\n'
      '        ZERO edits and resurfaces at round 1 where the guard is off, so '
      'conformance is unchanged (LESSONS 5i).',
  'LOC': 'not a defect: a regression on the LOC column against m26\'s 382.',
  'dup': 'not an engine: m26 registered a SECOND time, at the end, to measure '
      'how much the warming heap flatters a late row.',
  'leak': 'UNSOUND -- DO NOT USE. m47 discharges a pending lookahead at the end '
      'of a cons chain, so a chain that emits nothing\n'
      '        satisfies a non-empty constraint vacuously and it names repairs '
      'that do not exist: `_leak48.dart` block A, cost 0\n'
      '        where brute force says 1. Invisible in every column of this table, '
      'because JSON has no lookahead to get wrong.\n'
      '        Superseded by m48 (enforce at the terminator) and m49 (hand the '
      'obligation out through the value).',
};

/// The `eleg` column: (score, the one-line reason). A JUDGMENT, not a
/// measurement -- see `Eng.eleg` for the five criteria it weighs. One entry per
/// engine: a MISSING key crashes the run, a stale one is inert. A reason must
/// NOT restate the LOC column -- eleven of the thirteen that did had gone stale
/// against the number printed beside them. Comparisons against another engine's
/// size are fine, since the column cannot make those.
const elegNotes = <String, (int, String)>{
  'dot': (2, 'recovery as its own algorithm: hand-written skip/insert passes, '
      'nothing shared with the parser'),
  'sd3': (3, 'first "superdot": one value per position, but left recursion '
      'hand-reasoned and got wrong'),
  'sd5': (3, 'sd3 plus a wider result; the cycle reasoning is still recovery\'s '
      'own and still wrong'),
  'v6': (3, 'the LR fix lands but as a special case bolted beside the memo, not '
      'as the memo\'s own rule'),
  'm12': (4, 'first real compaction (526 -> 396) by dropping the separate span '
      'search; LR still hand-reasoned'),
  'm15': (4, 'per-end minimum arrives as a concept; four combinator cases still '
      'carry recovery logic each'),
  'm16': (5, 'the compactness floor of the pre-A5 line, and it is '
      'compact by omission -- LR is broken'),
  'm17': (5, 'same shape as m16, faster; the extra 5 lines are a memo-reuse rule '
      'that is derived, not tuned'),
  'm18': (5, 'a clean budget filter, but a second mechanism (span merge) exists '
      'only to make output readable'),
  'm19': (5, 'm18 minus a redundant pass; still four recovery-aware combinators'),
  'm20': (5, 'reorganised for latency and lost it; the idea did not change'),
  'm21': (5, 'as m20, one rule less; no new concept and no new deletion'),
  'm22': (5, 'the tightest the CFG-flavoured line gets, and every '
      'correctness column says why it is cheap'),
  'm23': (6, 'A5: STOP REASONING ABOUT CYCLES, adopt MemoEntry field for field. '
      'The first idea in the line that deletes rather than adds'),
  'm24': (6, 'A5 completed with a re-entry guard in reconstruction -- necessary, '
      'and the one piece of cycle logic recovery still owns'),
  'm25': (6, 'm24 with the regret weights in closed form; a loop over characters '
      'becomes a prefix sum'),
  'm26': (7, 'the settled baseline: three edits, one memo, one deepening loop '
      '-- but `maxCost` is still a chosen number'),
  'm27': (4, 'adds a PEG guard that consults the wrong string; machinery that '
      'cannot work is the least elegant kind'),
  'm28': (6, 'm26 with a doubling schedule -- one fewer arbitrary decision in '
      'the loop, one more overshoot to explain'),
  'm29': (4, 'the PEG guard again, deeper and slower; two mechanisms now share '
      'the blame for one wrong answer'),
  'm30': (3, 'splits the budget into two mechanisms wearing one name, which is '
      'exactly the confusion 5d names'),
  'm31': (3, 'the same split, plus a wrong-cost path behind a flag: a mechanism '
      'that must stay off is not a mechanism'),
  'm32': (6, 'a complete CFG level 0 replaces the oracle call -- honest and '
      'uniform, and it costs the O(1) shortcut'),
  'm33': (5, 'budget-as-lever, refuted; the code is fine and the idea was not '
      'there'),
  'm34': (5, 'as m33 from the other side; kept as a recorded negative'),
  'm35': (6, 'm32\'s level 0 with the deepening reused; the cleanest form of an '
      'idea the measurements reject'),
  'm36': (4, 'a PEG guard at budget 0 only, which cannot fire where it matters: '
      'a mechanism that is a no-op'),
  'm37': (6, 'm26 with the level-0 shortcut restored and the guard gone -- back '
      'to one mechanism per job'),
  'm38': (6, 'regret made absolute rather than relative; a real simplification '
      'of the ORDERING paid for in 22 lines'),
  'm39': (6, 'absolute regret with the prefix sums folded back in; 11 lines '
      'returned'),
  'm40': (6, 'the pricing reaches its final form (A1-A3 all derived) at the cost '
      'of 33 lines of derivation'),
  'm41': (9, 'THE RESTATEMENT: recovery is the parser over a wider value. Three '
      'node kinds, no dot, currying supplies the item boundaries, and '
      'one hand-written insertion rule left'),
  'm42': (10, 'THERE IS NO THIRD EDIT: deletion is SUB applied to `Nothing`, '
      'repeated. The last hand-written recovery rule in any combinator is DELETED '
      'and a gap gains one canonical attachment point. Nothing in the line is '
      'simpler or more derived than this'),
  'm43': (10, 'I3 in four lines: the oracle is authoritative as far as the '
      'edit-free window reaches, so `_Alt` becomes `First.match` and PEG '
      'commitment costs one memo hit'),
  'm44': (9, 'the last tuning parameter is DERIVED away (`_goalFromNothing`), '
      'which is the highest-value deletion available -- paid for with a real '
      'fixed point over the grammar, +43 LOC'),
  'm45': (7, 'I4 fuses `&C T` into a class: exactly right where it applies, and '
      'a build-time rewrite that provably cannot be completed. +69 LOC for a '
      'partial answer'),
  'm46': (8, 'I5: the witness is a proof, so check it. Turns a silent '
      'approximation into a reported one for the price of a walk -- honesty as a '
      'mechanism, and the cheapest kind'),
  'm47': (4, 'I6 is the right dimension, and `_split`\'s two-reading union at '
      'three call sites is the ugliest code in the line -- a static guess where '
      'the value should speak'),
  'm48': (5, 'the same union, plus a nullability fixed point to decide where to '
      'post a class: two mechanisms predicting what one value could carry'),
  'm49': (8, 'I7 UNIFIES THE THREE CHANNELS -- down is the argument, across is '
      'the value, up is the memo -- and deletes six mechanisms with it. The '
      'deepest idea in the line, in the largest file, and I4 is retained '
      'with nothing depending on it'),
  'm50': (9, 'I8: POSITION IS THE STRATIFICATION VARIABLE, so one worklist is '
      'm49\'s LR fixed point, its RR native stack, and its deepening loop at once. '
      'Bit-identical answers, 4.0x the search ceiling (k 541 -> 2160, at the pure '
      'parser\'s own k~2100), and the FIRST engine in the line without the `RR` '
      'bug. Paid for with 2.10x the relaxations, 1.9x `battms`, 3.9x `latms` '
      'and +48 LOC -- the deepest idea and the dearest'),
  'm51': (9, 'I9: A CELL IS RELAXED MANY TIMES, SO THE VALUE IS WRITTEN INTO AND '
      'NOT BUILT. m50 allocated a map per relaxation to compare against the one it '
      'already had; the cell accumulates in place instead, the value is a flat list '
      'of (key, Delta) pairs at mean width 1.63, and I1\'s fixed point test is the '
      'write. Bit-identical to m50, and CHEAPER IN STEPS TOO (0.83x: 2.43 '
      'relaxations per cell -> 1.97), because a value is no longer discarded when a '
      'budget rises'),
  'm52': (9, 'I11: A DEPENDENCY IS AN EDGE OF THE GRAMMAR, NOT AN ADDRESS TO BE '
      'LOOKED UP. A cell holds the cells it reads, slot by slot, so the 58-71% of '
      'reads that ask for an address already resolved cost a field load instead of a '
      'hash. Measured invariant before it was built, zero violations on four grammar '
      'families. Bit-identical to m51 on all 252 smoke inputs'),
  'm53': (10, 'I11 completed: THE REVERSE EDGE IS THE FORWARD EDGE\'S TRANSPOSE, so '
      'it is declared once with the forward edge and never consumed -- which DELETES '
      'I10 rather than improving it. Reverse-edge slots fall to 54742, the exact '
      'figure the rejected `Set<_Cell> readers` reached at a 14% cost, here for '
      'nothing. Bit-identical and step-identical to m52'),
  'm57': (10, 'I14: DELTA IS THE SCHEDULE -- pop work in order of total repair '
      'price (Knuth\'s lightest derivation) and the deepening ladder, the budget, '
      'and the search ceiling are DELETED, not tuned: the first goal fact to '
      'settle is the minimum, unrepairable means the queue drained, and the '
      'oracle short-circuit survives as a creation-time seed that is sound '
      'because it is redundant. Bit-identical to m53 on all 252 smoke inputs'),
  'cgfr1': (6, 'CERTIFICATE-GUIDED FRONTIER REPAIR (CGFR-1). Zero overhead when '
      'valid; harvests failure evidence at the syntax error frontier f; '
      'evaluates frontier-localized single edits via pure parser certificate '
      'checks; falls back to a reference tape for complex wide lookaheads. '
      'The 210 LOC this note used to claim counted the frontier logic only: '
      'the tape it falls back to was reached by importing m65, which imports '
      'm62. Folded in and measured, the engine is 1456 lines -- the LARGEST '
      'in the table, and larger than the m68/m69 it was offered as an '
      'alternative to. The frontier idea is real and the score is for that; '
      'the size advantage was an accounting artifact.'),
  'm70': (10, 'I26: THE RECONSTRUCTION IS A PASS TOO. The table said conformance costs two depth rungs -- m62/m64 reach >=4096 on both ladders and every engine that answers the true PEG language stops at 1024/2048 -- and read the tape as the price. The stack traces refute that: the ladder grammars are lookahead-free so the tape never runs on them, the parser alone survives len=4096, and every m69 overflow is in the WITNESS DESCENT, measured linear in the input (522 frames at len=512, 1034 at 1024). It is unavoidable under I22, where a verified witness IS the certificate, so the cost path must reconstruct; m62 escapes only by returning the number without a witness. So the gap was the certificate\'s shadow, and it takes I18\'s answer one level out: `_build`/`_child`/`_row` become one `_RFrame` driver, `_cleanRegret`/`_collect`/`_emit` become explicit walks, and a reader that ended in a tail call re-labels its frame instead of pushing one. Bit-identical to m69 on 471 inputs -- costs, trees, spans and obligations alike -- and LRmax goes from 1024 to >=4096, deterministic at 10/10 against m69\'s 0/10. The RRmax cell is NOT a property of the engine: it reads >=4096 whenever the depth isolate runs alone (10/10 in _marginal, and in _depthrepro, _seq70 and _rr70) and 2048 whenever the `main` or `lat` isolate ran before it in the same isolate group (7/7 official runs, reproduced by _warm70), with the overflow always inside a parser and never inside the engine. _twoparsers shows why it is that marginal: the LIBRARY parser tops out at len 4096 cold and 8192 warm, while the CARRIED copy every engine holds tops out at 4096 either way despite byte-identical source, so the RR rung sits exactly at the carried parser\'s ceiling with no margin. Forcing the tape route also overflowed at 4096, and reading that as the same wall was wrong: traced, it is `_tremap <- _tapeRecover`, the tape\'s own remap of the witness through the alignment -- a reconstruction, so I26 governs it, and it survived only because the lookahead-free ladder grammars never route to the tape and no ladder column could see it. Walked instead of recursed, the tape clears len=4096 (~7.0s there against ~1.8s at 2048), so I26 is complete on both routes and the carried parser\'s ceiling is now reached by `_verify` alone'),
  'm71': (10, 'I27+I28+I26: REACHING A BRANCH IS A CLAIM THAT THE ONES BEFORE IT FAILED, AND A CLAIM COSTS NOTHING UNTIL SOMEBODY DOUBTS IT. Three insights, and the second is what makes the first affordable. I27, A GREEDY CONSTRUCT IS A COMMITMENT, AND SO IS EVERY BRANCH AFTER THE FIRST: m70 bought true-PEG conformance with a tape -- 542 lines and two stack rungs over m62 -- and measuring WHICH cases it buys shows the whole price goes on one thing: every 3/5 engine in the table fails on exactly the two possessive-star cases and nothing else. Reading m62 says why, and it is not about stars. PEG has three greedy constructs and m62 desugars them into two node types: First and Optional become _Alt, whose results pass through _mergeAlt where I3\'s oracle veto lives; Repetition becomes a _Cons self-loop whose zero-cost stop calls _put directly and never meets that veto. Conformance was decided by which desugaring a construct happened to land in. The unifying law is that ordered choice is possessive, so branch i is legal exactly where branches 0..i-1 all fail -- and A* is X <- A X / eps, making the star\'s stop that law\'s degenerate case; broken down by grammar, the 226 exactness fixes land 138 on S <- A \'c\' with A <- \'a\' / "ab", 60 on \'a\'* "ab", 22 on (\'a\' / "ab") \'b\' and 6 on \'a\'? "ab", so 160 of the 226 are on grammars with no star in them at all -- had I27 been implemented as a rule about stars, which is how the failing gate cases present it, it would have found 60 of the 226. _mergeAlt enforces the law at cost 0 by asking the oracle; above cost 0 the input is repaired and the oracle is silent, so the claim has to travel as an OBLIGATION on the character that will sit there after repair -- and !A, for a one-character A, is already what _looks builds for NotFollowedBy. That obligation is part of the memo key, so narrowing it FRAGMENTS the memo: I27 alone measured 1.35x cells and 1.58x time on the worst latency case, and the official latms went 188.8 -> 343.7. The reflex is to prove the obligation unnecessary and drop it, and that reflex is wrong twice over -- neutralizing the star stop makes the engine SLOWER (411 vs 281 ms), because the obligation prunes as well as fragments. I28, A PROOF IS WORTH MORE THAN A TIGHTER SEARCH, SO ASK FOR THE PROOF FIRST AND PAY FOR THE TIGHTENING ONLY WHEN IT DOES NOT ARRIVE: the guards only ever DELETE repairs, so costOff <= costOn ALWAYS, with no appeal to the true cost. Compose that with I5, the witness is a proof: a cheap answer whose witness verifies is a repair that genuinely EXISTS at a price the guarded pass could not have beaten, so there is nothing left for the guards to win. Run relaxed, demand the certificate, re-run tight exactly when it fails to come. On JSON the tight pass never runs: latms 343.7 -> 208.7, the per-case ratio against m62 falls from 1.61 to 1.05, and cells land at 18527 against m62\'s 18479. Note what this deliberately does NOT claim -- costOff <= costTrue is FALSE in general, because a non-fusable lookahead is an oracle call against RAW input; the argument needs only the comparison between the two passes, and gets it for free. The cheap half of the certificate is not enough on its own: the free cost-0 test alone fixes 5 of the 226, so the reconstruction does 221 of the work and cannot be skipped. I26, THE RECONSTRUCTION IS A PASS TOO: I28 forces the witness onto the COST path, and a native witness descent is as deep as the input, so LRmax fell 4096 -> 1024 the moment I28 landed -- diagnosed from the real trace, not guessed. m70\'s answer ports over unchanged: _build/_child/_row become one _RFrame driver and _cleanRegret/_collect/_emit become explicit walks, restoring >=4096 on both ladders. The walks cost ~20% of the battery until _cleanRegret gets m62\'s leaf case back as a fast path -- _build asks it of every node it visits and almost all of them are leaves, so the walk was allocating two lists to fold nothing. Measured on 2387 brute-force-truth inputs: m62 is wrong on 324, m71 on 98, with 226 fixed and ZERO regressions; every gate m62 passes, m71 passes byte-identically. Conformance 3/5 -> 5/5. This row\'s own battms and RRmax are outliers of their distributions, which matters because the whole complaint against m70 was stated in those columns: re-measuring the three engines five times under the identical cold-isolate protocol gives battms medians m62 353 / m70 445 / m71 424, latms medians (ten samples) m62 194.7 / m70 218.3 / m71 195.3, and RRmax m71 >=4096 in 5 of 5 against m70\'s 2048 in 5 of 5. So against m70 it is -303 LOC and better on battery, latency AND RRmax at equal conformance; against m62 it is +239 LOC and a battery premium for an INDISTINGUISHABLE latency. Part of even that premium is the column timing half an answer against a whole one: latms times recoverCost, which under I28 returns a number AND a verified witness, where m62\'s returns the number alone and reconstructs later inside recover. Timing the identical corpus through recover -- the entry point a caller actually uses, and the only one where both engines have produced the same thing by the time the clock stops -- narrows m71/m62 from 1.08 to 1.03. The same asymmetry hides something larger in the depth column, since depthLimit calls recoverCost too: m62\'s >=4096 is a ceiling for half an answer, and asking each engine for recover instead tops m62 out at 1024 on BOTH ladders while m71 reaches >=4096 on both. THE HONEST LIMIT, and it is the same hole as m70\'s: _oneCharClass is null for a multi-character branch, where the complement is SUFFICIENT for failure but not NECESSARY, so those stay free -- m62\'s behaviour, unchanged and still wrong there. Named as a grammar rather than left abstract: ("ab")* "abc" has an EMPTY language for precisely the reason \'a\'* "ab" does -- the star is possessive, so wherever "abc" could match the star has already eaten its "ab" -- and m71 answers 3,2,0,0,1 there, identical to m62 and wrong on all five, where m70 returns -1. (\'a\')* "ab", a one-character body wearing a group, IS fixed, so true WIDTH decides and not syntactic shape; and ("ab")* "cd", whose language is non-empty, keeps answering finite verified costs, so the obligation costs nothing where the follower is disjoint from the body. What a CALLER sees there was measured rather than assumed: recover never reports clean on any of the five. Where the relaxed cost is 0 the witness is never built, so root is null and the whole input is forced into one error span -- sound. Where the cost is above 0 the tree IS built, fails _verify, and is handed back anyway as N missing obligations; lastVerified is false and public, which is the only thing separating this from m62, which returns the identical shape with no way to tell. A pre-existing hole made DETECTABLE, not a new one. And where I27 does apply the gap runs the other way at the recover level: on \'a\'* "ab" m71 correctly forces the whole input as unrepairable, while m62 offers a 1-to-2 event repair for a language with no strings in it. The residual 98 were classified rather than assumed: under-priced = 0, over-priced or rejected = 98, so m71 never names a repair that does not exist, and no further ladder rung can reach them (climbing only fixes under-pricing). 97 of the 98 are one grammar, S <- &(A \'b\') A \'b\' \'x\' with A <- \'a\'*, whose lookahead is multi-character; only a tape re-judging the lookahead against the REPAIRED string can close it, and that is exactly the 542 lines I28 and I27 were built to avoid paying for'),
  'm72': (10, 'I29+I30: THE WRITE KNOWS ITS OWN REASON, AND WHEN THE COMPARISON REFUSES A TIE THE ENUMERATION ORDER IS THE REST OF THE ANSWER. m71 answers the true PEG language in 1028 lines and 217 of them are _reconstruct -- a function whose whole job is to work out something the search already computed and threw away. Every memo value in this family is written by one funnel, _put -> _keepBest, and at the instant of the write the thing that produced it is a local variable: the spine\'s headKey, the alternation\'s branch index, or one of three leaf shapes. Keeping it costs one int per entry, a fourth slot beside (key, cost, regret). What it buys is not only the deletion of the search but the deletion of the DOUBT: m71 carries a _path set of cycle tokens because a re-derived predecessor chain might loop, and under I29 it cannot. Suppose the back-pointers closed a cycle at the fixed point; every edge adds a non-negative increment, so summing round the cycle forces every increment to zero and every value equal; take the cell on the cycle written LAST, at time t -- that write was a strict improvement so its value strictly dropped at t, but some cell on the cycle consumed this one\'s value BEFORE t and hence a strictly larger one, contradicting equality. A back-pointer closes a cycle only if the cycle has strictly negative weight, and every weight here is >= 0. The whole proof rests on one line of _keepBest, which refuses an equal entry. So _path, the candidate sort, both backtrack arms, _deltaOf and _ends existed only because the reason was discarded; _build can no longer fail to find a witness for a cost the search reported. _verify stays, since I5 checks the witness against the REAL parser -- a different question from self-consistency. COST IDENTITY IS NOT EVIDENCE OF WITNESS IDENTITY: the first build passed the cost gate outright, _subset72 reading 0 differences against m71 on all 2387 brute-force truths, and was still broken. Under I28 the engine demands a certificate and re-runs tight when one does not arrive, so a chase that silently fails is INVISIBLE to a cost comparison. _wit72 compares what a caller receives and read 1283 certificate differences, m71 certifying 2245 against m72\'s 962 -- more than half the witnesses destroyed by a change the cost gate called identical. Every failure was the _wPure sentinel read as a head key, because the budget-zero window writes _wPure into ANY node\'s cell and _child tail-calls _row for a junk-headed spine. THE CANONICAL FORM: a reason is a SUFFICIENT explanation, not a canonical one, and _wholesale prefers the oracle\'s whole-subtree match at cost == 0 -- no candidates, no backtracking, and when it declines the recorded reason answers. It belongs to _build and NOT to _row, since _row walks a spine\'s SUFFIX nodes and a suffix shares its orig with the whole sequence; putting it there dropped certificates 2245 -> 2197 and produced trees with gaps. I30: _keepBest refusing an equal entry means whoever is offered FIRST wins, so the enumeration order stops being a scheduling detail and becomes the semantics. PEG says take the reading a recursive-descent parser reaches first: earliest branch for an alternation (free, _mergeAlt walks in source order) and SHORTEST HEAD for a sequence, which m72 lacked because head answers arrive cheapest-first and the cheapest head is the one that swallowed the repair. Fixing it moved shape 513 -> 517/519 with nothing regressing. IT CANNOT GO IN THE COMPARISON: accepting an equal write destroys the proof, which needs the last write to have strictly dropped. THE MEASUREMENT WAS THE LAST THING STANDING AND IT WAS WRONG THREE TIMES. The row\'s 225.6 latms against m71\'s 213.4 survived six hypotheses, each killed by its own test: the restart guard fires 0 times in 274176 resumes; sorting at consumption is worse; bisecting _keepBest cuts 3.5x the scan work; the ordered insert shifts only 186699 of 49873423 scanned entries; stride-3 packing gains 0.6%; and _wholesale\'s rebuild is 4-7x FASTER than m71\'s, not slower. _work72 reads the step ratio at 1.0027 and the cell ratio at 0.9944 -- the engines do the same work. FIRST ERROR, THE APPARATUS: harnesses sharing one VM share its JIT state, and _recon72 timed the SAME build at 234.1, 257.4 and 270.2 ms in consecutive reps. _cold72 runs one engine per process, rotated across rounds. SECOND ERROR, THE SAMPLE SIZE: medians of 7 read m71 215.2, m72-without-ordering 220.0, m72 220.3, and this note once concluded from them that I30\'s ordering was FREE at 1.001; a second n=7 sweep put the same ratio at 1.047. At n=21 the decomposition is m71 219.4, without-ordering 227.9, m72 236.5 -- I29 costs 3.9% and I30 costs 3.8%, total 7.8%, not the 2.4% once published here. A better instrument read at too small an n reproduces exactly the failure it was built to fix. THIRD ERROR, AND THE EXPENSIVE ONE: bisecting _keepBest had been dismissed at ~2% as not the bottleneck, on the strength of the same broken harnesses. Split order is a TOTAL order computable from the key alone, (endOf(key), key), so the walk that looks for a key bisects and a miss stops exactly where the new key belongs -- mean list 13.9 entries, longest 90, ~7 comparisons becoming ~4. Folding it in needed a PROOF and not a benchmark, because under I30 the enumeration order IS the tie-break rule and any change to the list is a change to the LANGUAGE: _bseq compares certificate, spans, missing set and tree shape over 519 battery inputs and 12 latency cases -- 531 checked, 0 cost differences, 0 full-result differences -- with _m72bs deliberately keeping the LINEAR form and scanning the whole list so it does not assume the ordering it exists to check. Post-bisect at n=21: m71 median 223.2, m72 229.2, m72 above m71 at EVERY one of the 21 ranks, ratio 1.027. Ratios are drift-immune, so the bisect was worth 5.0% (1.078 -> 1.027), not 2% -- the largest single win in the engine, and it had already been found and discarded once. THE LESSON IS THAT NOISE COSTS IN BOTH DIRECTIONS: the same apparatus manufactured six hypotheses that were not there and hid one that was, and a measurement too weak to CONFIRM an effect is equally too weak to REJECT one -- the rejection being the more dangerous, since it leaves no artifact to come back to. The table\'s own column is not exempt: in the run that produced this row latms read 208.3 for m72 against 228.1 for m71, calling m72 8.7% faster where the cold sweep says 2.7% slower, and 208.3 falls below the MINIMUM of all 21 cold samples -- a lucky single draw, and no claim rests on it. MEASURED: 979 LOC against m71\'s 1028 and m70\'s 1331, conformance 5/5 and shape 517/519 both identical to m71, exactness byte-identical (98 wrong, 226 fixed, 0 regressed, 0 cost differences), 0 certificate differences with 2245 certified by each. Against m71: 49 lines smaller at a measured 2.7% latency cost with every other column tied -- a trade, not a domination. Against m62 it neither dominates nor is dominated: m62 is 789 LOC and faster on both timing columns, but scores conformance 3/5 to m72\'s 5/5 and is wrong on 324 of the 2387 brute-force truths to m72\'s 98.'),
  'm69': (10, 'I25: A REPRESENTATIVE CHOSEN ALONE CANNOT MEET A CONSTRAINT IMPOSED BY SOMEBODY ELSE. m68 with the per-terminal proposal alphabet (lowest CharSet member, code unit 0 for AnyChar) replaced by the Boolean interval partition of the code-unit line: cut at every CharSet range boundary and every literal character, and each touched terminal proposes EVERY representative it accepts. An intersection of unions-of-intervals is itself a union of intervals, so the union over touched terminals always contains a representative of their intersection when one exists -- which the one-per-terminal alphabet could not, since m68 routes every lookahead to the tape. All m68 gates held identically, and the new _isect intersection gate goes 4/4 where m65 and m68 are 1/4'),
  'cgfr2': (0, 'CGFR-2 AS RECEIVED, BROKEN. Three independent defects, diagnosed in full under `cgfr5`, which is the repair: a missing version stamp in _finish that leaves left-recursive positions permanently unsettled, a tape that enumerates over a hardcoded 12-character alphabet priced by |y| instead of edit distance and stops at a tuned input.length+10, and a narrow envelope that is only sound under I4 fusion. It does not terminate on the battery. Kept registered so the repair has something to be measured against.'),
  'cgfr5': (10, 'THE REPAIRED CGFR-2 (measured dead end, kept as evidence). cgfr2 had three independent defects: (1) the version stamp missing from _finish, so any left-recursive widening left every entry at that position permanently unsettled and the driver re-pushed forever; (2) _tapeRecover enumerated strings over a hardcoded 12-character alphabet priced at |y| rather than edit distance from the input, pruning nothing and stopping at a tuned input.length+10 -- two tuning-parameter violations and a divergence; (3) its _wideG used m62s narrow envelope, which is only sound under I4 fusion, so a positive lookahead needing repair never terminated. Repaired with m68s tape, m68s conservative routing and the I25 interval alphabet it passes every gate, but at 1147 LOC it is LARGER than m68: cgfr2s apparent size advantage was an absent tape'),
  'm68': (10, 'I24: UNDER A CERTIFICATE, THE FAST ENGINE ONLY NEEDS TO BE A '
      'FLOOR. m67 with the I6/I7 obligation lattice deleted from the relaxed '
      'core: an under-report can never verify (its witness would realize a '
      'cost below its own claim), so every predicate mistake fails '
      'verification and routes to the tape, which is exact; on '
      'lookahead-free grammars the union relaxation is trivially a floor, '
      'and the whole performance corpus is lookahead-free, so the lattice '
      'was inert on every measured input. Any lookahead routes to the tape. '
      'all gates held including cost+shape smoke identity'),
  'm67': (10, 'I23: THE ROUTER WAS A SEAM, NOT A DESIGN. m66\'s semantics '
      'hoisted into one class over one substrate: ONE relaxed core serves '
      'the fast path, the envelope floor and the fabrication floor; ONE '
      '_oneCharClass/_looks analysis is both I4\'s fusion test and the '
      'envelope boundary (a wide lookahead IS a clause _looks cannot read); '
      'ONE width/regret table prices the lattice, the tape edits, and the '
      'ranking; one set of result fields written by whichever search '
      'answers. Same re-verified semantics (certificate / floor / horizon), '
      'standalone, against the three-file composition it replaced'),
  'm66': (10, 'I22: A VERIFIED WITNESS IS A CERTIFICATE OF EQUALITY. The '
      'CFG-union reading is a superset language, so the relaxed cost is a '
      'floor; when the relaxed witness survives I5 verification the true '
      'cost is squeezed to equality and the witness in hand is a legitimate '
      'minimum-cost true repair. m62 answers verbatim wherever it can prove '
      'itself; the tape (m65) answers exactly where the relaxation lied -- '
      'the conformance cases. 53 LOC of router over the two engines: '
      'true-PEG exactness (conformance 5/5) at relaxed speed and shape '
      '(517/519, bit-identical smoke), the first tape-family engine to run '
      'the full latency protocol'),
  'm65': (10, 'I21: THE LAYER IS THE ANSWER; THE TIE IS A RANKING, NOT A '
      'SCHEDULE. m63 paced: 0/1 Dijkstra settles in strict cost layers '
      'whatever the tie order, so the search carries cost only, the whole '
      'minimal layer is drained, and the m-line exact regret (actual '
      'consuming-terminal widths from the candidate parse + a lexicographic '
      '(edits, regret) alignment DP) ranks candidates AFTER the search -- '
      'path-independent, and the DP traceback is the witness. Classify on '
      'pop; clean-tail shortcut (the budget-zero walk on the tape); '
      'within-layer closer-to-done-first order so accepts surface at the '
      'head of their layer and the drain suppresses stepwise expansion. '
      '87x -> 21x battery, shape 467 -> 514 (m62: 517, of which 2 are d13), '
      'every exactness gate unchanged, conformance 5/5'),
  'm63': (10, 'I20: MEMBERSHIP, DEADNESS, AND THE USEFUL ALPHABET ARE ONE '
      'PROBED PARSE. True-PEG-exact repair as Dijkstra over (input cursor, '
      'emitted text): every terminal is wrapped in a probe that records when '
      'it consults the open end, so one frozen-parser parse of the emitted '
      'prefix answers membership (authoritative), deadness (a failure that '
      'never touched the frontier fails on every extension), and the atoms '
      '(which next characters could matter). Ordered choice and possessive '
      'repetition mean what PEG says: the FIRST engine in the line to score '
      '5/5 on the conformance cases, back to dot. The price is '
      'exponential worst-case search (NP-hardness licenses it); the ladder '
      'protocol is unviable at latency case 8, and -1 means "none within '
      'the derived cap n + CFG-fabrication floor"'),
  'm64': (8, 'I19: THE SUFFIX IS THE INVARIANT; THE EDIT ONLY MOVES THE '
      'ORIGIN. m62 plus an incremental entry point: cells right of a single '
      'edit survive verbatim at a shifted address (value = f(node, '
      'obligation, budget, suffix)), and d(s,L) is 1-Lipschitz so the ladder '
      'restarts within +-1 of the previous answer -- never more than three '
      'rungs, verified over 500 comparisons with zero cost or shape '
      'differences. Honest verdict: economically empty at measured scales '
      '(0.96-1.11x) because the budget-zero walk already collapses clean '
      'regions and the expensive cells sit exactly at the edit'),
  'm62': (10, 'I18: THE ENTRY IS A FACT; THE PASS IS A FRAME. m60 with the '
      'continuation lifted out of the memo entry onto one explicit DFS stack: '
      'of the ten entry fields, six described the pass in flight and move to '
      'a pooled frame; the stack adjacency IS the parent pointer, running '
      'derives from membership, and a descendant reaching an active entry '
      'sets the ancestral FRAME\'s foundCycle bit by index. The durable memo '
      'shrinks to value/settledBudget/version(+activeDepth); recurrence, '
      'ladder, walk, ceiling, witness unchanged, m60\'s ceilings preserved '
      '(bisect 2160/1161). Bit-identical to m53 on all 252 smoke inputs. '
      'Codex\'s ranked-first candidate (twentieth occasion), built and '
      'measured'),
  'm61': (9, 'I17: A MEMO ENTRY IS A FIXPOINT ENGINE. m60\'s recurrence in '
      'direct recursive style, hosted by the frozen parser itself: a cell '
      '(node, obligation, budget) IS a Clause, its value set rides a Match '
      'whose len is a growth counter, and MemoEntry.match supplies the '
      'memoization, cycle seed, widening loop and staleness rule -- zero '
      'recovery-side memo machinery. Bit-identical to m53 on all 252 smoke '
      'inputs. The price is measured: waits return to the native stack '
      '(ceiling ~650, m49-class) and the host\'s generic memo path costs '
      '~27% over m60\'s specialized table'),
  'm60': (9, 'I16: THE CONTINUATION IS A MEMO FIELD. m49\'s recurrence, ladder, '
      'budget and walk -- all three amortizations -- with native recursion '
      'deleted: an entry that needs an unsettled child parks itself as the '
      'child\'s parent and the driver resumes it at its cursor; a request '
      'reaching a RUNNING entry is an ancestor, hence a cycle -- inRecPath and '
      'foundLeftRec generalized verbatim from cycles to all waits. Dissolves '
      'the m49-vs-m53 trade: m49-class speed at m50-class stack ceilings.'),
  'm59': (10, 'I15 minimal: the bucket queue IS the deepening ladder with every '
      'round run once -- an array index, no heap, no budget, no ceiling, no '
      'packed cost unit (Delta is the pair (cost, regret), lexicographic). '
      'Every optimization any occasion measured answer-neutral is deleted; '
      'what remains each answers a named requirement. Bit-identical '
      'to m53 on all 252 smoke inputs, every exactness gate green'),
  'm58': (9, 'I15: THE CLASS IS THE ROUND, RUN ONCE. m57\'s schedule at edit-count '
      'grain: Dijkstra across cost strata, m53\'s batched chaotic relaxation '
      'inside one, packed as (costClass << rankBits) | rank in one heap key. '
      'Keeps I14\'s deletions (no ladder, no budget, no ceiling as a bound) and '
      'restores the production cut the budget used to provide. Bit-identical '
      'to m53 on all 252 smoke inputs; loses a point because the deferred-leaf '
      'rule that would finish the collapse breaks witness-tie parity'),
  // Reference re-measurements: the same engine, so the same score.
  'm26c': (7, 'm26'),
  'm26d': (7, 'm26'),
  'm42e': (10, 'm42'),
  'm43f': (10, 'm43'),
  'm46i': (8, 'm46'),
};

// NO DUPLICATE ROWS. Engines used to be registered a second time under a letter
// suffix -- m26b, m44g, m53k, m62r..m62y -- so that a new engine had a reference
// row for the same engine measured in the SAME process. That was necessary when
// one process measured every engine in sequence and JIT state carried across
// them. It is not necessary now: each engine gets its own part-isolated, COLD
// isolate, and the latency loop does one untimed warm pass before the timed
// min-of-5. The cold start costs a little latency and buys a table that is one
// row per engine and sorts. Do not re-add them.
final engines = <Eng>[
  Eng('dot', (r, t) {
    final e = DotRecovery(rules: r, topRuleName: t);
    return (e.recover, () => e.lastTotalCost, (s) => (e.recover(s), e.lastTotalCost).$2);
  }, bugs: 'slow,shape'),
  Eng('sd3', (r, t) {
    final e = g3.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'LR,empty'),
  Eng('sd5', (r, t) {
    final e = g5.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'LR,empty'),
  Eng('v6', (r, t) {
    final e = g6.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'LR'),
  Eng('m12', (r, t) {
    final e = g12.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'LR,shape'),
  Eng('m15', (r, t) {
    final e = g15.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'LR'),
  Eng('m16', (r, t) {
    final e = g16.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'LR'),
  Eng('m17', (r, t) {
    final e = g17.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'LR'),
  Eng('m18', (r, t) {
    final e = g18.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'LR'),
  Eng('m19', (r, t) {
    final e = g19.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'LR'),
  Eng('m20', (r, t) {
    final e = g20.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'LR,slow'),
  Eng('m21', (r, t) {
    final e = g21.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'LR,slow'),
  Eng('m22', (r, t) {
    final e = g22.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'LR'),
  Eng('m23', (r, t) {
    final e = g23.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'null'),
  Eng('m24', (r, t) {
    final e = g24.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),
  Eng('m25', (r, t) {
    final e = g25.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),
  Eng('m26', (r, t) {
    final e = g26.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),
  Eng('m27', (r, t) {
    final e = g27.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'pegfix'),
  Eng('m28', (r, t) {
    final e = g28.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'over'),
  Eng('m29', (r, t) {
    final e = g29.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'pegfix,slow,stack'),

  Eng('m30', (r, t) {
    final e = g30.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'slow,stack,shape'),

  Eng('m31', (r, t) {
    final e = g31.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'slow,stack,latent'),

  Eng('m32', (r, t) {
    final e = g32.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'batt'),

  Eng('m33', (r, t) {
    final e = g33.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'slow'),

  Eng('m34', (r, t) {
    final e = g34.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'slow,shape'),

  Eng('m35', (r, t) {
    final e = g35.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'batt'),

  Eng('m36', (r, t) {
    final e = g36.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'noop'),

  Eng('m37', (r, t) {
    final e = g37.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),

  Eng('m38', (r, t) {
    final e = g38.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'LOC'),

  Eng('m39', (r, t) {
    final e = g39.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'LOC'),

  Eng('m40', (r, t) {
    final e = g40.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'LOC'),

  Eng('m41', (r, t) {
    final e = g41.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),

  Eng('m42', (r, t) {
    final e = g42.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),

  Eng('m43', (r, t) {
    final e = g43.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),

  Eng('m44', (r, t) {
    final e = g44.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),

  Eng('m45', (r, t) {
    final e = g45.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),

  // m46 verifies its own witness on every `recover`, which this table calls once
  // per mutant -- so `battms` here INCLUDES the extra parse, and the gap to m45
  // is what that costs.
  Eng('m46', (r, t) {
    final e = g46.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),

  // I6 (m48) and I7 (m49). Both verify their own witness on every `recover`, as
  // m46 does, so `battms` includes that parse and m46 is the row to read them
  // against. JSON has no lookahead anywhere, so every column here is a REGRESSION
  // check, not a claim: `_smoke49` reports m49 identical to m46 on this battery
  // down to the `_compute` count, and these rows are what that costs in time.
  // m47 is registered for the record and MUST NOT be used: it discharges a
  // pending lookahead at the end of a cons chain, so a chain that emits nothing
  // satisfies a non-empty constraint vacuously and it reports repairs that do not
  // exist (`_leak48.dart`, block A: 0 where brute force says 1). Every column
  // below is clean because JSON has no lookahead to get wrong.
  Eng('m47', (r, t) {
    final e = g47.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'leak'),

  Eng('m48', (r, t) {
    final e = g48.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),

  Eng('m49', (r, t) {
    final e = g49.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),

  Eng('m50', (r, t) {
    final e = g50.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),

  Eng('m51', (r, t) {
    final e = g51.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),

  Eng('m52', (r, t) {
    final e = g52.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),

  Eng('m53', (r, t) {
    final e = g53.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),

  Eng('m57', (r, t) {
    final e = g57.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),

  Eng('m58', (r, t) {
    final e = g58.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),

  Eng('m59', (r, t) {
    final e = g59.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),

  Eng('m60', (r, t) {
    final e = g60.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),

  Eng('m61', (r, t) {
    final e = g61.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),

  Eng('m62', (r, t) {
    final e = g62.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),

  Eng('m63', (r, t) {
    final e = g63.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),

  Eng('m64', (r, t) {
    final e = g64.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),

  Eng('m65', (r, t) {
    final e = g65.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),

  Eng('m66', (r, t) {
    final e = g66.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),

  Eng('m67', (r, t) {
    final e = g67.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),

  Eng('m68', (r, t) {
    final e = g68.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),

  Eng('cgfr1', (r, t) {
    final e = gcgfr1.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),

  Eng('cgfr2', (r, t) {
    final e = gcgfr2.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),

  Eng('m69', (r, t) {
    final e = g69.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),

  Eng('cgfr5', (r, t) {
    final e = gcgfr5.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),

  Eng('m70', (r, t) {
    final e = g70.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),
  Eng('m71', (r, t) {
    final e = g71.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),
  Eng('m72', (r, t) {
    final e = g72.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),

];

// ---------------------------------------------------------------- ground truth
bool inLanguage(Map<String, Clause> rules, String top, String s) {
  final p = Parser(rules: rules, topRuleName: top, input: s).parse();
  return !p.hasSyntaxErrors && p.root != null && p.root!.len == s.length;
}

/// Brute-force truth is a property of the GRAMMAR AND THE INPUT, not of an
/// engine, so it is computed once and shared by all 46 rows. Before this cache
/// every engine re-ran the same breadth-first search over the same 44 cases,
/// which is 46x the work for one answer -- and it is what made a second truth
/// battery unaffordable.
final _truthCache = <String, int?>{};
int? truth(Map<String, Clause> rules, String top, String grammarText, String s,
        String alphabet, int maxK) =>
    _truthCache.putIfAbsent('$grammarText $top $s $maxK',
        () => trueDistance(rules, top, s, alphabet, maxK));

int? trueDistance(
    Map<String, Clause> rules, String top, String s, String alphabet, int maxK) {
  var frontier = {s};
  final seen = {s};
  for (var k = 0; k <= maxK; k++) {
    for (final c in frontier) {
      if (inLanguage(rules, top, c)) return k;
    }
    final next = <String>{};
    for (final c in frontier) {
      for (var i = 0; i < c.length; i++) {
        final del = c.substring(0, i) + c.substring(i + 1);
        if (seen.add(del)) next.add(del);
      }
      for (var i = 0; i <= c.length; i++) {
        for (final ch in alphabet.split('')) {
          if (seen.add(c.substring(0, i) + ch + c.substring(i))) {
            next.add(c.substring(0, i) + ch + c.substring(i));
          }
          if (i < c.length) {
            final sub = c.substring(0, i) + ch + c.substring(i + 1);
            if (seen.add(sub)) next.add(sub);
          }
        }
      }
    }
    frontier = next;
  }
  return null;
}

final truthCases = <(String, String, String, List<String>)>[
  (
    "E <- E '+' T / T;\nT <- T '*' F / F;\nF <- [0-9];\n",
    'E',
    '0+*',
    ['1+2', '1++2', '1+', '+1', '1*', '1+2++3', '1 + 2', '', '++', '1+2*'],
  ),
  (
    "E <- T '+' E / T;\nT <- F '*' T / F;\nF <- [0-9];\n",
    'E',
    '0+*',
    ['1+2', '1++2', '1+', '+1', '1*', '1+2++3', '1 + 2', '', '++', '1+2*'],
  ),
  (
    "E <- A / F;\nA <- B '+' F;\nB <- E;\nF <- [0-9];\n",
    'E',
    '0+',
    ['1+2', '1++2', '1+', '+1', '1+2+3', '', '++', '1+2+'],
  ),
  (
    "E <- E N / F;\nN <- '-'?;\nF <- [0-9];\n",
    'E',
    '0-',
    ['1', '1-', 'x', '1--', '', '11'],
  ),
  (
    "V <- O / A / N;\nO <- '{' (M (',' M)*)? '}';\nM <- N ':' V;\n"
        "A <- '[' (V (',' V)*)? ']';\nN <- [0-9];\n",
    'V',
    '0{}[],:',
    ['0', '{0:0}', '{0:0', '{0:}', '[0,]', '[0 0]', '{}}', '', '[[0]', '{0:0,}'],
  ),
];

/// THE LOOKAHEAD CORNER CASES, which no other column in this table can see. Every
/// block below is a family that a specific engine got specifically wrong, and the
/// engine that got it wrong is named, so a row that regresses is traceable to the
/// insertion that caused it.
///
/// Brute force runs at `predMaxK` = 2, not 3: every truth here is 0, 1 or 2, and
/// the failures being caught are 0-against-1 (m47, unsound) and 1-against-3 (m48,
/// blind). A case whose true distance exceeds 2 reads as "no repair within 2",
/// against which any finite cost <= 2 is still an under-report -- so the `unsnd`
/// column stays sound at the lower K while the search stays affordable.
const predMaxK = 2;

final predCases = <(String, String, String, List<String>)>[
  // -- A: a nullable run ENDING a rule body. m47 discharged a pending obligation
  //    at the terminator of a cons chain, so a chain that emits nothing satisfied
  //    `!'x'` vacuously: cost 0 where the truth is 1. THE UNSOUND DIRECTION.
  (
    "S <- !'x' A D;\nA <- 'a'? 'c'?;\nD <- 'd' / 'x';\n",
    'S',
    'acdx',
    ['x', 'ax', 'acx', 'd', 'ad', ''],
  ),
  (
    "S <- !'x' A D;\nA <- B C;\nB <- 'b'?;\nC <- 'c'?;\nD <- 'd' / 'x';\n",
    'S',
    'bcdx',
    ['x', 'bx', 'd', 'bd', ''],
  ),
  // -- B: the reader is behind a NAME, so no static placement of the constraint is
  //    the right language (`_nullseq45.dart` proves it with the pure parser alone).
  //    This is what I6 exists for; every engine before m47 prices it by asking the
  //    oracle about the wrong string.
  (
    "S <- !'x' A B;\nA <- 'a'?;\nB <- 'b' / 'x';\n",
    'S',
    'abx',
    ['x', 'xx', 'ax', 'b', '', 'xb'],
  ),
  (
    "S <- !'x' A;\nA <- 'x' / \"yy\";\n",
    'S',
    'xyq',
    ['q', 'x', 'yy', 'y', '', 'xy'],
  ),
  // -- C: a TRAILING lookahead, whose reader is in the parent's continuation. This
  //    is what I7 exists for: m48 has the class and nowhere to put it, so it
  //    fabricates the continuation instead and over-reports.
  (
    "S <- A 'b';\nA <- 'a' &'b';\n",
    'S',
    'abx',
    ['ab', 'a', 'ax', 'b', ''],
  ),
  (
    "S <- Kw !Alpha;\nKw <- \"if\";\nAlpha <- [a-z];\n",
    'S',
    'ifq',
    ['if', 'ifq', 'iff', 'i', 'if '],
  ),
  // -- D: THE KEYWORD BOUNDARY, `Kw <- "if" !Alpha` with the reader at the call
  //    site -- the commonest real use of a lookahead there is. m48 reports 3 on
  //    "ifa" where the truth is 1.
  (
    "S <- Kw Rest;\nKw <- \"if\" !Alpha;\nRest <- ' ' Alpha;\nAlpha <- [a-z];\n",
    'S',
    'ifa ',
    ['if a', 'ifa', 'if ', 'iff a', 'i a'],
  ),
  (
    "S <- Kw Rest;\nKw <- \"if\" !Alpha;\nRest <- ' '*;\nAlpha <- [a-z];\n",
    'S',
    'ifa ',
    ['if', 'ifa', 'if ', 'iff'],
  ),
  (
    "S <- A 'b';\nA <- 'a' &'b' / 'c';\n",
    'S',
    'abc',
    ['ab', 'cb', 'a', 'c', 'ax'],
  ),
  // -- E: PEG COMMITMENT, which is the other half of I3's veto. `_veto49.dart`
  //    shows that dropping either half of the guard breaks one of these: the star
  //    must be allowed to stop where the input still offers 'a' (5m), and the
  //    longer alternative must NOT be allowed to free-ride past a commitment the
  //    oracle already made, even while owing a debt.
  ("S <- 'a'* 'b' 'a';\n", 'S', 'ab', ['aa', 'aba', 'ba', 'a', '']),
  ("S <- A 'b';\nA <- 'a' / 'a' 'a' 'a' &'b';\n", 'S', 'ab',
      ['ab', 'aaab', 'aab', 'b', 'a']),
  // -- F: SPELLING INVARIANCE. `[^"]` and `!'"' .` are the same language, and
  //    before I4 they were priced differently. The two blocks must agree with each
  //    other AND with brute force; the second is the control.
  ("S <- '\"' (!'\"' .)* '\"';\n", 'S', '\"x', ['\"x\"', 'x', '\"x', '']),
  ("S <- '\"' [^\"]* '\"';\n", 'S', '\"x', ['\"x\"', 'x', '\"x', '']),
  // -- G: AN EMPTY LANGUAGE. `&'x' 'y'` demands that the next character be both x
  //    and y, so NO input is repairable at any cost and every finite answer here
  //    is an under-report. m44's derived ceiling is what makes declining possible;
  //    I4 fuses the pair to the empty class so the branch is dead rather than
  //    cheap.
  ("S <- &'x' 'y';\n", 'S', 'xy', ['', 'y', 'x', 'xy']),
  // -- H: A LOOKAHEAD WIDER THAN ONE CHARACTER, where EVERY engine including m49
  //    is still approximate -- the derivative of `!"*/"` after one emitted
  //    character is `!"/"`, an obligation that changes as it is discharged, and
  //    the channel carries a set. Recorded here so the approximation is measured
  //    rather than asserted: the requirement is SOUNDNESS (`unsnd` = 0), not
  //    exactness.
  ("S <- (!\"*/\" .)* \"*/\";\n", 'S', '*/a', ['a*/', '*/', 'a', 'a/']),
];

/// Compare one engine's answer with brute force. `want` is null when no repair
/// exists within `predMaxK`, and then ANY finite cost within that range is an
/// under-report -- the disqualifying direction, because it names a repair that
/// does not exist.
///
/// Returns 'ok' (exact), 'over' (too high -- safe, an exactness loss), 'under'
/// (unsound), or 'unk' (truth beyond reach of the search, and the engine did not
/// claim anything inside it).
String verdictOf(int? want, int got, int maxK) {
  if (want != null) {
    return got == want ? 'ok' : (got < 0 || got > want ? 'over' : 'under');
  }
  return got >= 0 && got <= maxK ? 'under' : 'unk';
}

// ------------------------------------------------------------------------ main

// --------------------------------------------------------- capped measurement
// Every engine is measured in its OWN isolate, under a hard 30-second cap. Two
// reasons, and the second is the one that made it necessary:
//
//   1. A divergent engine used to hang the whole table, and a Dart timer cannot
//      interrupt a synchronous loop -- only killing an isolate can. An engine
//      that overruns is killed and reported as `TO`, and the run continues.
//   2. It removes the warming bias this file's header warns about (377 vs 314
//      battms for the same engine registered late vs first): every engine now
//      starts from a cold isolate instead of inheriting its predecessors' JIT.
//
// The cost is that latency is no longer interleaved across engines. Under the
// standing protocol -- one engine per process, medians of three, read only
// against a reference measured in the SAME run -- that changes nothing, because
// the reference is measured in its own isolate in the same run.
typedef Setup = (
  Map<String, Clause>, // rules
  List<String>, // battery
  String, // origShape
  List<String>, // validDocs
  List<String>, // latCases
  Map<String, Clause>, // depthLR
  Map<String, Clause>, // depthRR
  String Function(Eng, Map<String, Clause>, List<int>), // depthLimit
);

/// The battery's exact minimum edit cost, per mutant, in `battery` order.
///
/// This column used to be a HISTOGRAM: printed, never scored. Every engine read
/// {1: 503, 2: 16} so it looked like a constant, until cgfr1 read {1: 510, 2: 9}
/// and there was no column that could say which one was right. `unsnd` could
/// not: it is computed on the pred corpus. So an engine that UNDERPRICES the
/// battery displayed the better-looking histogram and nothing flagged it.
///
/// The truth is a construction property, not a search. `buildSetup` builds each
/// mutant from `base` by exactly one edit, so undoing that edit is:
///
///   delete c / insert c / substitute c -> 1 edit, so the true minimum is 1
///   transpose x,y                      -> 2 edits under delete/insert/subst,
///                                         so the minimum is 2 UNLESS some
///                                         unrelated single edit repairs it
///
/// Only the transposes need searching, and that search is exhaustive over all
/// 95 printable ASCII characters: a negative result means no single-byte edit
/// exists at all, not none over a chosen alphabet. 42 transposes survive the
/// filter and cost ~2.6s to settle, which is why this runs in the 'main' part
/// only. Measured: {1: 503, 2: 16} -- the histogram every sound engine printed.
List<int> batteryTruth(Map<String, Clause> rules, List<String> battery) {
  bool ok(String s) {
    final p = Parser(rules: rules, topRuleName: 'JSON', input: s).parse();
    return !p.hasSyntaxErrors && p.root.len == s.length;
  }

  // Rebuilt exactly as buildSetup builds it, but carrying the edit kind.
  const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';
  final mutants = <String>[], kinds = <String>[];
  void add(String m, String k) {
    mutants.add(m);
    kinds.add(k);
  }

  for (var j = 0; j < base.length; j++) {
    add(base.substring(0, j) + base.substring(j + 1), 'one');
    if (j + 1 < base.length && base[j] != base[j + 1]) {
      add(base.substring(0, j) + base[j + 1] + base[j] + base.substring(j + 2),
          'transpose');
    }
  }
  for (var j = 0; j <= base.length; j++) {
    for (final c in ['Q', 'z', '}', '"', ',', '5']) {
      add(base.substring(0, j) + c + base.substring(j), 'one');
      if (j < base.length && base[j] != c) {
        add(base.substring(0, j) + c + base.substring(j + 1), 'one');
      }
    }
  }

  final keptM = <String>[], keptK = <String>[];
  for (var i = 0; i < mutants.length; i++) {
    if (!ok(mutants[i])) {
      keptM.add(mutants[i]);
      keptK.add(kinds[i]);
    }
  }
  // If the rebuild ever drifts from buildSetup, the kinds attach to the wrong
  // strings and every truth below is silently wrong -- so fail loudly instead.
  if (keptM.length != battery.length) {
    throw StateError('batteryTruth rebuilt ${keptM.length} != ${battery.length}');
  }
  for (var i = 0; i < keptM.length; i++) {
    if (keptM[i] != battery[i]) {
      throw StateError('batteryTruth drifted at $i');
    }
  }

  return <int>[
    for (var i = 0; i < keptM.length; i++)
      if (keptK[i] != 'transpose')
        1
      else ...[
        () {
          final s = keptM[i];
          for (var j = 0; j < s.length; j++) {
            if (ok(s.substring(0, j) + s.substring(j + 1))) return 1;
          }
          for (var j = 0; j <= s.length; j++) {
            for (var c = 32; c < 127; c++) {
              final ch = String.fromCharCode(c);
              if (ok(s.substring(0, j) + ch + s.substring(j))) return 1;
              if (j < s.length &&
                  s[j] != ch &&
                  ok(s.substring(0, j) + ch + s.substring(j + 1))) {
                return 1;
              }
            }
          }
          return 2;
        }()
      ]
  ];
}

Setup buildSetup() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';
  bool parses(String s) =>
      !Parser(rules: rules, topRuleName: 'JSON', input: s).parse().hasSyntaxErrors;

  // ---- the 519-mutant battery
  final mutants = <String>[];
  for (var j = 0; j < base.length; j++) {
    mutants.add(base.substring(0, j) + base.substring(j + 1));
    if (j + 1 < base.length && base[j] != base[j + 1]) {
      mutants.add(
          base.substring(0, j) + base[j + 1] + base[j] + base.substring(j + 2));
    }
  }
  for (var j = 0; j <= base.length; j++) {
    for (final c in ['Q', 'z', '}', '"', ',', '5']) {
      mutants.add(base.substring(0, j) + c + base.substring(j));
      if (j < base.length && base[j] != c) {
        mutants.add(base.substring(0, j) + c + base.substring(j + 1));
      }
    }
  }
  final battery = mutants.where((m) => !parses(m)).toList();
  final origShape = treeShape(
      Parser(rules: rules, topRuleName: 'JSON', input: base).parse().root);

  const validDocs = [
    '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}',
    '[]',
    '{}',
    '  [1, 2, [3, {"x": -4.5e+6}], false, null]  ',
    '{"s":"a\\\\u00ffb\\\\n\\\\t","n":-0.5,"deep":{"a":{"b":{"c":[[[1]]]}}}}',
    '"just a string"',
    '0',
  ];

  // ---- latency cases (identical to gen_cmp.dart so numbers stay comparable)
  final big = '{"users":[{"id":1,"name":"ann","tags":["x","y"]},'
      '{"id":2,"name":"bob","tags":["z"]},{"id":3,"name":"cyd","tags":[]}],'
      '"total":3,"ok":true}';
  final latCases = <String>[];
  for (final k in [4, 16, 64]) {
    latCases.add(big.substring(0, 30) + big.substring(30 + k));
    latCases.add(big.substring(0, 30) + ('@' * k) + big.substring(30));
    final ch = big.substring(30, 30 + k).split('')..shuffle(Random(12345 + k));
    latCases.add(big.substring(0, 30) + ch.join() + big.substring(30 + k));
  }
  for (final k in [4, 16, 64]) {
    final it = [for (var i = 0; i < k; i++) '{"id":$i,"name":"n$i","ok":true}'];
    final d = '{"items":[${it.join(',')}],"total":$k}';
    final mid = d.length ~/ 2;
    latCases.add('${d.substring(0, mid)}Q${d.substring(mid + 1)}');
  }

  // ---- stack-depth probe grammars
  final depthLR = MetaGrammar.parseGrammar(
      "E <- E '+' T / T;\nT <- T '*' F / F;\nF <- [0-9] / '(' E ')';\n");
  final depthRR = MetaGrammar.parseGrammar(
      "E <- T '+' E / T;\nT <- F '*' T / F;\nF <- [0-9] / '(' E ')';\n");
  String oneErr(int k) {
    final c = List.generate(k, (i) => '${i % 10}').join('+');
    return '${c.substring(0, c.length ~/ 2)}+${c.substring(c.length ~/ 2)}';
  }

  /// Largest n from `sizes` that completes without overflowing, as ">=hi" or "<lo".
  String depthLimit(Eng e, Map<String, Clause> g, List<int> sizes) {
    var last = 'none';
    for (final k in sizes) {
      final s = oneErr(k);
      try {
        final (_, _, cost) = e.make(g, 'E');
        cost(s);
        last = '${s.length}';
      } on StackOverflowError catch (_, st) {
        final fr = st.toString().split('\n');
        final seen = <String>{};
        final names = <String>[];
        for (final x in fr) {
          final mm = RegExp(r'#\d+\s+(\S+)').firstMatch(x);
          if (mm != null && seen.add(mm.group(1)!)) names.add(mm.group(1)!);
        }
        print('    [diag] len=${s.length} SO, ${fr.length} frames, '
            'distinct: ${names.take(14).join(" <- ")}');
        return last == 'none' ? '<${s.length}' : last;
      } catch (e) {
        print('    [diag] len=${s.length} THREW ${e.runtimeType}: '
            '${e.toString().split('\n').first}');
        return last == 'none' ? 'err' : last;
      }
    }
    return '>=$last';
  }
  return (rules, battery, origShape, validDocs, latCases, depthLR, depthRR,
      depthLimit);
}

/// ONE PART of one engine's measurement: `part` is 'main', 'lat' or 'depth'.
///
/// The split exists so the cap can kill a PART instead of an engine. It is not
/// cosmetic. `_gate70.dart` times the gates separately, and the LR/RR ladder --
/// which deliberately climbs to 4096-character inputs hunting the stack ceiling
/// -- is 72-96% of every engine's clock: m62, which passes, spends 21.4s of its
/// 23.3s there, and m32 spends 48.0s of 50.1s. Capping the engine as one unit
/// therefore reported `TO` in the battery, cost, tree and pred columns of
/// engines whose battery runs in 384ms, because a probe that is SUPPOSED to be
/// expensive was expensive. Each part returns a payload whose first element is
/// 'OK', which is distinguishable from the `[error, stack]` a dying isolate
/// sends.
List<Object> measureOne(String name, String part) {
  final (rules, battery, origShape, validDocs, latCases, depthLR, depthRR,
      depthLimit) = buildSetup();
  final engine = engines.firstWhere((e) => e.name == name);

  if (part == 'depth') {
    return <Object>[
      'OK',
      depthLimit(engine, depthLR, [256, 512, 1024, 2048]),
      depthLimit(engine, depthRR, [256, 512, 1024, 2048]),
    ];
  }

  if (part == 'lat') {
    final latList = <double>[];
    final (_, _, latCost) = engine.make(rules, 'JSON');
    // One untimed pass first. Each engine now gets a COLD isolate, so without
    // this the timed loop measures JIT compilation: m69 read 243.0 cold against
    // 213.1 warm, purely from being the only thing its isolate had ever run.
    for (final m in latCases) {
      try {
        latCost(m);
      } catch (_) {}
    }
    for (final m in latCases) {
      var t = double.infinity;
      for (var i = 0; i < 5; i++) {
        final sw = Stopwatch()..start();
        try {
          latCost(m);
        } catch (_) {
          t = -1;
          break;
        }
        t = min(t, sw.elapsedMicroseconds / 1000);
      }
      latList.add(t);
    }
    return <Object>['OK', latList];
  }

  final rows = <List<String>>[];
  for (final e in [engine]) {
    // battery
    final (rec, cost, _) = e.make(rules, 'JSON');
    final bTruth = batteryTruth(rules, battery);
    var shape = 0, cov = 0, crash = 0, bExact = 0, bUnder = 0;
    final sw = Stopwatch()..start();
    for (var i = 0; i < battery.length; i++) {
      final m = battery[i];
      SkipResult r;
      try {
        r = rec(m);
      } catch (_) {
        crash++;
        continue;
      }
      final c = cost();
      if (c == bTruth[i]) {
        bExact++;
      } else if (c < bTruth[i]) {
        bUnder++;
      }
      if (covers(r.root, m.length)) cov++;
      if (treeShape(r.root) == origShape) shape++;
    }
    sw.stop();

    // valid
    final (rec2, cost2, _) = e.make(rules, 'JSON');
    var clean = 0;
    for (final d in validDocs) {
      try {
        final r = rec2(d);
        if (cost2() == 0 && r.errorSpans.isEmpty && r.missing.isEmpty) clean++;
      } catch (_) {}
    }

    // ground truth. Two separate claims, and conflating them hides a real
    // difference: `tOk` is only that the COST is minimal, `rOk` is that the
    // witness tree can actually be rebuilt and covers the input. m23 passes the
    // first and diverges on the second.
    var tOk = 0, tTot = 0, rOk = 0;
    for (final (g, top, alpha, inputs) in truthCases) {
      final gr = MetaGrammar.parseGrammar(g);
      final (r3, _, c3) = e.make(gr, top);
      for (final s in inputs) {
        tTot++;
        final want = truth(gr, top, g, s, alpha, 3);
        try {
          if (want != null && c3(s) == want) tOk++;
        } catch (_) {}
        try {
          if (covers(r3(s).root, s.length)) rOk++;
        } catch (_) {}
      }
    }

    // ---- the lookahead corner cases. Three counts, because they are three
    // different claims and averaging them would hide the only one that
    // disqualifies: `pOk` is exact agreement, `pUnder` is a repair named that does
    // not exist, and `pTot` is the cases brute force settled outright.
    //
    // `pTot` COUNTS TRUTH, NOT VERDICTS, so it is the same number on every row and
    // the fractions are comparable. Counting settled verdicts instead -- the first
    // way this was written -- gave an engine a LARGER denominator the more
    // under-reports it made, because an under-report on an unrepairable input is
    // decidable while a decline is not: `dot` read 57/73 and m49 69/69 off the same
    // battery. Cases whose truth is beyond `predMaxK` are outside `pred` entirely
    // and appear only in `unsnd`, where naming a repair that cannot exist belongs.
    var pOk = 0, pTot = 0, pUnder = 0;
    for (final (g, top, alpha, inputs) in predCases) {
      final gr = MetaGrammar.parseGrammar(g);
      final (_, _, c4) = e.make(gr, top);
      for (final s in inputs) {
        final want = truth(gr, top, g, s, alpha, predMaxK);
        int got;
        try {
          got = c4(s);
        } catch (_) {
          // A crash is not an under-report; it is counted in `crsh` above for the
          // battery and here it can only lose an exactness point.
          got = -1;
        }
        final v = verdictOf(want, got, predMaxK);
        if (want != null) pTot++;
        if (v == 'ok') pOk++;
        if (v == 'under') pUnder++;
      }
    }

    rows.add([
      e.name,
      '${e.loc}',
      '$shape/${battery.length}',
      '$cov/${battery.length}',
      '$crash',
      '$bExact/${battery.length}',
      '$bUnder',
      '$clean/${validDocs.length}',
      '$tOk/$tTot',
      '$rOk/$tTot',
      '$pOk/$pTot',
      '$pUnder',
      '${e.eleg}',
      e.bugs,
      '${sw.elapsedMilliseconds}',
      '', // latms, from the separately capped 'lat' part
      '', // /v6, filled once v6's total is known -- index `v6Col` below
      '', // LRmax, from the separately capped 'depth' part
      '', // RRmax, likewise
    ]);
  }
  return <Object>['OK', rows.first];
}

void measureIso(List<Object> msg) {
  (msg[0] as SendPort).send(measureOne(msg[1] as String, msg[2] as String));
}

/// Nothing here should take 30 seconds. Anything that does is killed.
Future<List<Object>?> runCapped(String name, String part, Duration cap) async {
  final rp = ReceivePort();
  final iso = await Isolate.spawn(measureIso, <Object>[rp.sendPort, name, part],
      onError: rp.sendPort, onExit: rp.sendPort);
  try {
    final v = await rp.first.timeout(cap);
    if (v is List && v.isNotEmpty && v.first == 'OK') return v.cast<Object>();
    return null; // died: onExit sends null, onError sends [error, stack]
  } on TimeoutException {
    return null;
  } finally {
    iso.kill(priority: Isolate.immediate);
    rp.close();
  }
}

Future<void> main(List<String> args) async {
  // Comma-separated engine names keep an iteration under a minute; with no
  // argument every engine runs, which is the table that gets reported.
  if (args.isNotEmpty) {
    final keep = args.first.split(',').toSet();
    engines.retainWhere((e) => keep.contains(e.name));
  }
  final (_, battery, _, validDocs, latCases, _, _, _) = buildSetup();
  print('battery=${battery.length}  valid=${validDocs.length}  '
      'latency cases=${latCases.length}');

  const head = ['engine', 'LOC', 'shape', 'cover', 'crsh', 'bmin', 'bund',
    'valid', 'cost', 'tree', 'pred', 'unsnd', 'eleg', 'bugs', 'battms', 'latms',
    '/v6', 'LRmax', 'RRmax'];
  // Derived, never written as literals. `bmin`/`bund` replaced a single
  // `cost hist` column and the old literal 14 then pointed at `battms`, so the
  // latency total overwrote the battery time and every row reported one column
  // short. Looking the index up by name makes the next column addition inert.
  final latCol = head.indexOf('latms');
  final v6Col = head.indexOf('/v6');
  final lrCol = head.indexOf('LRmax');
  final rrCol = head.indexOf('RRmax');

  // Two minutes, and what exceeds it is reported as SLOW rather than TO.
  //
  // The first cap was 30s on the premise that "nothing should take that long".
  // `_gate70.dart` refuted that premise: the LR/RR stack-ceiling ladder climbs
  // to 4096-character inputs on purpose and is 72-96% of every engine's clock,
  // so m53 -- whose battery runs in 384ms -- lost its battery, shape, cost, tree
  // and pred columns to a probe that is SUPPOSED to be expensive. Capping each
  // PART separately fixed the collateral damage; raising the cap to 120s fixes
  // the threshold. Past two minutes the distinction between "would have finished
  // in three minutes" and "would never have finished" does not matter: the
  // engine is too slow, and SLOW says that as a verdict rather than implying the
  // measurement merely ran out of room.
  const cap = Duration(seconds: 120);
  final lat = <String, List<double>>{};
  final rows = <List<String>>[];
  final timedOut = <String>{};
  for (final e in engines) {
    final mainOut = await runCapped(e.name, 'main', cap);
    final latOut = await runCapped(e.name, 'lat', cap);
    final depthOut = await runCapped(e.name, 'depth', cap);

    // `eleg` and `bugs` are declared, not measured, so a killed part never
    // costs them; only the columns the dead part would have filled read `TO`.
    final row = mainOut != null
        ? (mainOut[1] as List).cast<String>()
        : <String>[
            e.name,
            '${e.loc}',
            for (var c = 2; c < 12; c++) 'SLOW',
            '${e.eleg}',
            e.bugs,
            'SLOW',
            '', '', '', '',
          ];
    final ll = latOut == null
        ? List<double>.filled(latCases.length, -1)
        : (latOut[1] as List).cast<double>();
    lat[e.name] = ll;
    row[latCol] = latOut == null
        ? 'SLOW'
        : ll.fold(0.0, (a, b) => a + max(b, 0)).toStringAsFixed(1);
    row[lrCol] = depthOut == null ? 'SLOW' : depthOut[1] as String;
    row[rrCol] = depthOut == null ? 'SLOW' : depthOut[2] as String;
    rows.add(row);

    if (latOut == null) timedOut.add(e.name); // the /v6 ratio has no numerator
    final dead = <String>[
      if (mainOut == null) 'main',
      if (latOut == null) 'lat',
      if (depthOut == null) 'depth',
    ];
    print(dead.isEmpty
        ? '  ...${e.name} done'
        : '  ...${e.name} done, ${dead.join("+")} SLOW past '
            '${cap.inSeconds}s');
  }

  // The /v6 column is a ratio to the baseline, so it only exists when the
  // baseline was one of the engines run.
  final v6 = lat['v6']?.fold(0.0, (a, b) => a + max(b, 0));
  for (var i = 0; i < engines.length; i++) {
    final t = lat[engines[i].name]!.fold(0.0, (a, b) => a + max(b, 0));
    rows[i][v6Col] = v6 == null ? '-' : '${(t / v6).toStringAsFixed(2)}x';
  }
  for (var i = 0; i < engines.length; i++) {
    if (timedOut.contains(engines[i].name)) rows[i][v6Col] = 'SLOW';
  }

  for (final r in rows) {
    if (r.length != head.length) {
      throw StateError('row ${r.first} has ${r.length} cells, '
          'head has ${head.length}');
    }
  }
  final w = [
    for (var c = 0; c < head.length; c++)
      [head[c].length, for (final r in rows) r[c].length].reduce(max)
  ];
  String fmt(List<String> r) =>
      [for (var c = 0; c < r.length; c++) r[c].padLeft(w[c])].join(' ');
  print('\n${fmt(head)}');
  for (final r in rows) {
    print(fmt(r));
  }
  print('\nSLOW:  that PART of the measurement exceeded ${cap.inSeconds}s and was '
      'killed. It is a\n       verdict on the engine, not a limit of the harness: '
      'past two minutes it does\n       not matter whether it would have finished '
      'in three. The three parts (main,\n       lat, depth) are capped '
      'independently, so a row can be SLOW in LRmax/RRmax\n       and fully '
      'measured everywhere else -- which is the common case, because the\n'
      '       LR/RR ladder climbs to 4096-character inputs and is 72-96% of every '
      'engine\'s\n       clock.');
  print('\nshape/cover/bmin/battms: 519-mutant battery.  cost: agreement '
      'with\nbrute-force minimum edit distance over 5 grammars (44 cases).  '
      'tree: the witness\nrebuilds and covers the input on those same 44.  latms: '
      'sum of 12 latency\ncases, min-of-5, interleaved.  LRmax/RRmax: largest '
      '1-error input length that\ncompletes without StackOverflowError '
      '(">=4096" means it never overflowed).');
  print('\npred:  exact agreement with brute force on the LOOKAHEAD corner cases '
      '(predCases,\n       K<=$predMaxK), the families that no other column here '
      'can see. The denominator is\n       the cases brute force settled outright, '
      'so it is the same on every row; the\n       4 cases whose grammar has an '
      'EMPTY language are outside it and score only in\n       `unsnd`, where '
      'naming a repair that cannot exist belongs.');
  print('bmin:  agreement with the battery\'s EXACT minimum edit cost, and `bund` '
      'is how\n       many of the 519 it priced BELOW that minimum. This column '
      'used to be a\n       histogram -- printed, never scored -- and every engine '
      'read {1: 503, 2: 16}\n       until cgfr1 read {1: 510, 2: 9}, which no '
      'column could adjudicate. The truth\n       is derived, not guessed: 503 '
      'mutants are one edit from `base` by construction,\n       and the 42 '
      'transposes are settled by exhaustive search over all 95 printable\n'
      '       ASCII characters. cgfr1 is 512/519 with 7 under; the m-line is '
      '519/519.');
  print('unsnd: of those cases, how many the engine priced BELOW the true '
      'minimum -- i.e.\n       how many repairs it names that DO NOT EXIST. This '
      'is the one number in the\n       table that disqualifies outright, and it '
      'is the defect m47 shipped with while\n       every other column stayed '
      'clean. Reporting too HIGH is safe and shows up as a\n       lower `pred` '
      'instead.');
  print('eleg:  0-10, AND IT IS A JUDGMENT, NOT A MEASUREMENT -- the only such '
      'column here.\n       It scores the code and the concepts (how many '
      'mechanisms; derived or chosen;\n       adopted from the parser or invented '
      'for recovery; compactness; can it be stated\n       in one true sentence) '
      'and says nothing about the answers, which have five\n       columns of '
      'their own. The per-engine reason is printed below so a reader can\n     '
      '  disagree with a specific score rather than with a ranking.');
  print('\neleg -- the reason for each score:');
  for (final e in engines) {
    final (score, why) = elegNotes[e.name]!;
    print('  ${e.name.padRight(5)} $score  $why');
  }

  // The bugs column, expanded. Tags name defects specific to one engine; the
  // shared list names the four every engine in the table has, which would
  // otherwise repeat on every row.
  final used = <String>{for (final e in engines) ...e.bugs.split(',')}
    ..remove('-');
  if (used.isNotEmpty) {
    print('\nbugs -- per-engine:');
    for (final tag in bugLegend.keys.where(used.contains)) {
      print('  ${tag.padRight(5)} ${bugLegend[tag]}');
    }
  }
  print('\nbugs -- shared by EVERY engine below, so not repeated per row:');
  for (final b in sharedBugs) {
    print('  $b');
  }
  print('\nUNPROVEN, not a measured bug: the left-recursion fixed point in every\n'
      'A5 engine (m23 onward) re-runs until no Delta improves, and that iteration\n'
      'count has no tight polynomial bound in the derivation -- only the '
      'measurement\nthat it behaves like a small constant.');
}
