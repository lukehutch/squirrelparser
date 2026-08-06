// Scratch: THE CEILING ON CROSS-ROUND REUSE.
//
// The deepening loop runs one full round per budget from 0 up to the answer's
// cost. Every round after the first re-derives a chart that mostly did not
// change. This measures the bound: give the engine the final budget for free,
// so it runs exactly ONE round, and see what the battery costs. No reuse scheme
// can do better than that, and the gap between it and the real run is the whole
// prize.
//
//   dart run _oracle.dart

import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';

import '_v20.dart' as e;
import '_o20.dart' as o;

String _sk(MatchResult m) {
  final b = StringBuffer('${m.clause?.runtimeType}:${m.pos}:${m.len}(');
  for (final k in m.subClauseMatches) {
    b.write(_sk(k));
  }
  b.write(')');
  return b.toString();
}


void main() {
  final cases = weighted(buildBattery());
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final topOf = {for (final c in corpora) c.name: c.top};

  // Learn each case's final cost, and check the oracle run gives the same tree.
  final need = <int>[];
  var diff = 0, rounds = 0;
  for (final k in cases) {
    final a = e.Squirrel(rules: rulesOf[k.grammar]!, topRuleName: topOf[k.grammar]!);
    MatchResult? ra;
    try {
      ra = a.recover(k.mutant);
    } catch (_) {}
    final c = ra == null ? 0 : a.lastCost;
    need.add(c);
    rounds += c + 1;
    final b = o.Squirrel(rules: rulesOf[k.grammar]!, topRuleName: topOf[k.grammar]!)
      ..startAt = c;
    MatchResult? rb;
    try {
      rb = b.recover(k.mutant);
    } catch (_) {}
    if ((ra == null) != (rb == null) ||
        (ra != null && rb != null && _sk(ra) != _sk(rb))) diff++;
  }
  print('cases ${cases.length}   total rounds run $rounds  '
      '(${(rounds / cases.length).toStringAsFixed(2)} per case)');
  print('oracle tree differences: $diff');

  double run(bool oracle) {
    final sw = Stopwatch()..start();
    for (var i = 0; i < cases.length; i++) {
      final k = cases[i];
      try {
        if (oracle) {
          (o.Squirrel(rules: rulesOf[k.grammar]!, topRuleName: topOf[k.grammar]!)
                ..startAt = need[i])
              .recover(k.mutant);
        } else {
          e.Squirrel(rules: rulesOf[k.grammar]!, topRuleName: topOf[k.grammar]!)
              .recover(k.mutant);
        }
      } catch (_) {}
    }
    sw.stop();
    return sw.elapsedMicroseconds / 1000;
  }

  run(false);
  run(true);
  final real = <double>[], orc = <double>[];
  for (var r = 0; r < 5; r++) {
    real.add(run(false));
    orc.add(run(true));
  }
  real.sort();
  orc.sort();
  print('real   median ${real[2].toStringAsFixed(0)} ms');
  print('oracle median ${orc[2].toStringAsFixed(0)} ms   '
      'x${(orc[2] / real[2]).toStringAsFixed(3)}  <-- the whole prize');
}
