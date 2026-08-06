// HOW MUCH OF `_core2.dart`'s FRONTIER DID THE LIBRARY PORT ACTUALLY GET?
//
// `_core2.dart` was the experiment that proved an exact frontier makes the
// brief's iterative widening work (r10-r13). The library adoption took the part
// the instruction named -- a fresh mismatch per failure, carrying the length it
// consumed and the subclause results under it -- and left `reach` behind.
//
// `reach` is a watermark on EVERY node, including matched ones, so it also keeps
// what a successful clause tried and threw away: an `X?` that matched empty
// still learned how far `X` agreed. The library keeps no such record, so its
// frontier can only be a lower bound on `_core2`'s.
//
// This measures the gap on the recovery battery: per case, the deepest
// `pos + len` over the library's mismatch tree against `_core2`'s root `reach`.
// A gap of 0 means the mismatch tree alone found everything `reach` did.

import 'package:squirrel_parser/squirrel_parser.dart';

import '_core2.dart' as c2;
import 'astdiff.dart';

/// The deepest end-of-accepted-input the library tree can report.
///
/// `pos + len` on EVERY node, not just the mismatches: on a match it is input
/// the clause accepted, on a mismatch it is input the clause read and accepted
/// before failing. This is the same quantity `_core2`'s `reach` folds upward,
/// minus the one thing the library does not keep -- what a successful clause
/// tried and discarded.
int libFrontier(MatchResult m) {
  var best = -1;
  final seen = <MatchResult>{};
  void walk(MatchResult k) {
    if (!seen.add(k)) return;
    if (k.pos + k.len > best) best = k.pos + k.len;
    k.subClauseMatches.forEach(walk);
  }

  walk(m);
  return best;
}

void main() {
  final battery = buildBattery();
  final byGrammar = <String, Map<String, Clause>>{};
  final byGrammarC2 = <String, Map<String, c2.Clause>>{};
  for (final corpus in corpora) {
    final libRules = MetaGrammar.parseGrammar(corpus.grammar);
    byGrammar[corpus.name] = libRules;
    byGrammarC2[corpus.name] = c2.rulesToCore(libRules, <c2.Clause, Clause>{});
  }

  var cases = 0, same = 0, short = 0, ahead = 0, shortTotal = 0;
  final worst = <(int, String, String)>[];

  for (final k in battery) {
    final corpus = corpora.firstWhere((c) => c.name == k.grammar);
    final lib = Parser(rules: byGrammar[k.grammar]!, topRuleName: corpus.top, input: k.mutant)
        .matchRule(corpus.top, 0);
    final c2root = c2.Parser(rules: byGrammarC2[k.grammar]!, topRuleName: corpus.top, input: k.mutant)
        .matchRule(corpus.top, 0);

    final a = libFrontier(lib);
    final b = c2root.reach;
    cases++;
    if (a == b) {
      same++;
    } else if (a < b) {
      short++;
      shortTotal += b - a;
      worst.add((b - a, k.grammar, k.mutant));
    } else {
      ahead++;
    }
  }

  worst.sort((x, y) => y.$1.compareTo(x.$1));
  print('battery cases            $cases');
  print('library frontier == _core2 reach   $same  (${(100 * same / cases).toStringAsFixed(1)}%)');
  print('library SHORT of it                $short  total ${shortTotal}ch, '
      'mean ${short == 0 ? 0 : (shortTotal / short).toStringAsFixed(1)}ch');
  print('library AHEAD of it                $ahead');
  if (worst.isNotEmpty) {
    print('\nwidest gaps:');
    for (final w in worst.take(8)) {
      final s = w.$3.length > 46 ? '${w.$3.substring(0, 46)}...' : w.$3;
      print('  ${w.$1.toString().padLeft(4)}ch  ${w.$2.padRight(5)} ${s.replaceAll('\n', ' ')}');
    }
  }
}
