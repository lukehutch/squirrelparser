// _wdrive7.dart -- how much of m132's work is REDONE by the next budget round?
//
// m132 deepens by cost: budget 0, 1, 2, 4, 8, ... and each round allocates a
// fresh `_mc[budget]`/`_me[budget]`, so everything the previous round computed
// is discarded and recomputed. Only the cost-0 memo `_pc` survives.
//
// That is the real target of the brief's "confidently move the parse position
// forwards": a span already bridged should not be re-searched. Applied to the
// COST axis rather than the position axis, it asks how much a round inherits
// from its predecessor -- work that is provably still valid, because a cheaper
// way stays a way when the budget rises.
//
// Reports, per case: the budgets actually run, the repair cells per budget, and
// what fraction of the total was spent in rounds that the FINAL round repeated.
import 'package:squirrel_parser/squirrel_parser.dart';

import '_wprobe.dart';
import 'astdiff.dart';

String pct(List<num> xs, double q) {
  if (xs.isEmpty) return '-';
  final s = List<num>.of(xs)..sort();
  return s[((s.length - 1) * q).round()].toStringAsFixed(2);
}

void main() {
  final rulesOf = {
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final seen = <String>{};
  final rounds = <num>[], wasted = <num>[], finalShare = <num>[];
  final cellsByBudget = <int, int>{};
  var casesByRounds = <int, int>{};
  var totalCells = 0, totalFinal = 0;
  for (final k in weighted(buildBattery())) {
    if (!seen.add('${k.grammar}\x00${k.category}\x00${k.mutant}')) continue;
    final p = SuperDot3(
        rules: rulesOf[k.grammar]!,
        topRuleName: corpora.firstWhere((c) => c.name == k.grammar).top);
    try {
      p.recover(k.mutant);
    } catch (_) {
      continue;
    }
    if (p.probeCells.isEmpty) continue;
    // Cell keys are 'clause\0pos\0budget'.
    final byB = <int, int>{};
    for (final key in p.probeCells) {
      final b = int.parse(key.split('\x00')[2]);
      byB[b] = (byB[b] ?? 0) + 1;
      cellsByBudget[b] = (cellsByBudget[b] ?? 0) + 1;
    }
    final bs = byB.keys.toList()..sort();
    final tot = byB.values.fold(0, (a, b) => a + b);
    final last = byB[bs.last]!;
    rounds.add(bs.length);
    casesByRounds[bs.length] = (casesByRounds[bs.length] ?? 0) + 1;
    totalCells += tot;
    totalFinal += last;
    finalShare.add(last / tot);
    wasted.add((tot - last) / tot);
  }

  print('${rounds.length} distinct cases');
  print('                          p50    p75    p90    p95    p99    max');
  for (final (l, xs) in [
    ('repair rounds run', rounds),
    ('share in FINAL round', finalShare),
    ('share DISCARDED', wasted),
  ]) {
    print('${l.padRight(24)}'
        '${[0.5, 0.75, 0.9, 0.95, 0.99, 1.0].map((q) => pct(xs, q).padLeft(7)).join()}');
  }
  print('');
  print('  cases by number of repair rounds:');
  final rk = casesByRounds.keys.toList()..sort();
  for (final r in rk) {
    print('    $r round(s): ${casesByRounds[r]} cases');
  }
  print('');
  print('  repair cells by budget:');
  final bk = cellsByBudget.keys.toList()..sort();
  for (final b in bk) {
    print('    budget ${b.toString().padLeft(4)}: '
        '${cellsByBudget[b].toString().padLeft(7)} cells '
        '(${(100 * cellsByBudget[b]! / totalCells).toStringAsFixed(1)}%)');
  }
  print('');
  print('  ${(100 * (totalCells - totalFinal) / totalCells).toStringAsFixed(1)}% '
      'of all repair cells are computed in a round that a LATER round redoes.');
}
