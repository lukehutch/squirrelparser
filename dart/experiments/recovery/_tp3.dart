// _tp3.dart -- prices the STRIDE against the battery, which has never been done.
//
//   for r in $(seq 1 21); do for e in m62 m72 p3 ins; do
//     for c in batt lat; do dart _tp3.dart $e $c; done; done; done
//
// The residual battery gap -- everything except the certificate -- is 26.4 ms
// (10.4%) and survives four counts that all say m72 does LESS work per input
// than m62. The one untested candidate with the right shape is the stride:
// every value list is 4 ints wide where m62's is 3. `_m72p3` packs (reg, why)
// into one word and is answer-identical over 531 inputs, but it was priced at
// 0.2-0.6% on LATENCY, where entries number 282k, never against the battery's
// 880k. If the stride is the residual, m73's stride-3 core inherits the win.
import 'dart:io';
import 'dart:math';

import 'final_table.dart' show buildSetup;
import 'm62.dart' as e62;
import 'm72.dart' as e72;
import '_m72p3.dart' as ep3;
import '_m72ins.dart' as eins;

void main(List<String> argv) {
  final which = argv.isEmpty ? 'm72' : argv[0];
  final corpus = argv.length > 1 ? argv[1] : 'batt';
  final (rules, battery, _, _, latCases, _, _, _) = buildSetup();
  final inputs = corpus == 'lat' ? latCases : battery;

  final run = switch (which) {
    'm62' => e62.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
    'p3' => ep3.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
    'ins' => eins.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
    _ => e72.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
  };
  for (final s in inputs) {
    run(s);
  }
  var best = double.infinity;
  for (var i = 0; i < 3; i++) {
    final sw = Stopwatch()..start();
    for (final s in inputs) {
      run(s);
    }
    best = min(best, sw.elapsedMicroseconds / 1000);
  }
  stdout.writeln('$corpus $which ${best.toStringAsFixed(1)}');
}
