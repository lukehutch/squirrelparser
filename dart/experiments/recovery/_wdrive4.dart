// _wdrive4.dart -- the number that decides the bottom-up rewrite.
//
// m132 searches top-down: every parent that descends into (clause, position)
// recomputes that cell's repair layer from scratch, because a repaired result
// is only memoised per budget round and the `_pure` guard lets a cheap re-entry
// through. A bottom-up chart evaluates each cell EXACTLY ONCE per cost layer,
// by construction.
//
// So `_repair` calls / distinct cells is the redundancy factor the chart
// removes -- an upper bound on the speedup available from the schedule change
// alone, with the algorithm's decisions left completely untouched. If it is
// near 1, the top-down schedule is already optimal and the rewrite buys nothing
// but exactness; if it is large, the chart is strictly less work.
import 'package:squirrel_parser/squirrel_parser.dart';

import '_wprobe.dart';
import 'astdiff.dart';

String pct(List<num> xs, double q) {
  final s = List<num>.of(xs)..sort();
  return s[((s.length - 1) * q).round()].toStringAsFixed(1);
}

void main() {
  final rulesOf = {
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final seen = <String>{};
  final calls = <num>[], cells = <num>[], ratio = <num>[], lens = <num>[];
  final byCat = <String, List<num>>{};
  var sumCalls = 0.0, sumCells = 0.0;
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
    final r = p.probeCalls / p.probeCells.length;
    calls.add(p.probeCalls);
    cells.add(p.probeCells.length);
    ratio.add(r);
    lens.add(k.mutant.length);
    sumCalls += p.probeCalls;
    sumCells += p.probeCells.length;
    (byCat[k.category] ??= <num>[]).add(r);
  }

  print('${calls.length} distinct cases');
  print('');
  print('                     p50    p75    p90    p95    p99    max');
  for (final (l, xs) in [
    ('input length', lens),
    ('_repair calls', calls),
    ('distinct cells', cells),
    ('calls/cell', ratio),
  ]) {
    print('${l.padRight(20)}'
        '${[0.5, 0.75, 0.9, 0.95, 0.99, 1.0].map((q) => pct(xs, q).padLeft(7)).join()}');
  }
  print('');
  print('  TOTAL calls ${sumCalls.toStringAsFixed(0)} over '
      '${sumCells.toStringAsFixed(0)} cells '
      '= ${(sumCalls / sumCells).toStringAsFixed(2)}x redundancy');
  print('');
  final cats = byCat.keys.toList()
    ..sort((a, b) => double.parse(pct(byCat[b]!, 0.5))
        .compareTo(double.parse(pct(byCat[a]!, 0.5))));
  for (final c in cats) {
    print('  ${c.padRight(16)} calls/cell p50 ${pct(byCat[c]!, 0.5).padLeft(6)}'
        '  p90 ${pct(byCat[c]!, 0.9).padLeft(7)}  (${byCat[c]!.length} cases)');
  }
}
