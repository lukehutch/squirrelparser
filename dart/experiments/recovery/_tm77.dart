// _tm77.dart -- does I33's description fold cost latency?
//
//   for r in $(seq 1 21); do for e in m75 m77; do for c in batt lat; do
//     for k in cost tree; do dart _tm77.dart $e $c $k; done; done; done; done
//
// One engine per process, constructed once outside the timed loop, warmed once,
// best-of-3 inside the process and the MEDIAN across the 21 rounds. Both arms
// run in every round, so they share one clock and the difference subtracts.
//
// BOTH entry points are measured, because they can move differently. `_descOf`
// runs inside the SEARCH -- it prices the budget-zero walk's settled subtrees --
// so it is paid under `recoverCost` too, not only when a tree is built.
import 'dart:io';
import 'dart:math';

import 'final_table.dart' show buildSetup;
import 'm75.dart' as e75;
import 'm77.dart' as e77;

void main(List<String> argv) {
  final which = argv.isEmpty ? 'm77' : argv[0];
  final corpus = argv.length > 1 ? argv[1] : 'batt';
  final kind = argv.length > 2 ? argv[2] : 'cost';
  final (rules, battery, _, _, latCases, _, _, _) = buildSetup();
  final inputs = corpus == 'lat' ? latCases : battery;

  final go = switch ((which, kind)) {
    ('m75', 'cost') => e75.SuperDot3(rules: rules, topRuleName: 'JSON')
        .recoverCost as Function(String),
    ('m75', _) => e75.SuperDot3(rules: rules, topRuleName: 'JSON').recover,
    (_, 'cost') => e77.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
    _ => e77.SuperDot3(rules: rules, topRuleName: 'JSON').recover,
  };

  for (final s in inputs) {
    go(s);
  }
  var best = double.infinity;
  for (var i = 0; i < 3; i++) {
    final sw = Stopwatch()..start();
    for (final s in inputs) {
      go(s);
    }
    best = min(best, sw.elapsedMicroseconds / 1000);
  }
  stdout.writeln('$corpus $kind $which ${best.toStringAsFixed(1)}');
}
