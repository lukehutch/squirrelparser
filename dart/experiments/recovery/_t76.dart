// _t76.dart -- the m74 timing sweep, one engine per process.
//
//   for r in $(seq 1 21); do for e in m62 m73 m74; do
//     for c in batt lat; do for m in cost rec; do dart _t76.dart $e $c $m;
//   done; done; done; done
//
// Two entry points, because they are not the same question. `cost` times
// `recoverCost`, which is what the final_table columns time -- and under I28
// that returns a number AND a verified witness in m74, where m62's returns the
// number alone and reconstructs later inside `recover`. `rec` times `recover`,
// the entry point a caller actually uses, and the only one where both engines
// have produced the same thing by the time the clock stops.
import 'dart:io';
import 'dart:math';

import 'final_table.dart' show buildSetup;
import 'm62.dart' as e62;
import 'm73.dart' as e73;
import 'm74.dart' as e74;

void main(List<String> argv) {
  final which = argv.isEmpty ? 'm74' : argv[0];
  final corpus = argv.length > 1 ? argv[1] : 'batt';
  final entry = argv.length > 2 ? argv[2] : 'cost';
  final (rules, battery, _, _, latCases, _, _, _) = buildSetup();
  final inputs = corpus == 'lat' ? latCases : battery;

  void Function(String) run;
  switch (which) {
    case 'm62':
      final g = e62.SuperDot3(rules: rules, topRuleName: 'JSON');
      run = entry == 'rec' ? (s) => g.recover(s) : (s) => g.recoverCost(s);
    case 'm73':
      final g = e73.SuperDot3(rules: rules, topRuleName: 'JSON');
      run = entry == 'rec' ? (s) => g.recover(s) : (s) => g.recoverCost(s);
    default:
      final g = e74.SuperDot3(rules: rules, topRuleName: 'JSON');
      run = entry == 'rec' ? (s) => g.recover(s) : (s) => g.recoverCost(s);
  }

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
  stdout.writeln('$corpus $entry $which ${best.toStringAsFixed(1)}');
}
