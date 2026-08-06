// _tins.dart -- m62 / m72 / _m72ins on both timing corpora, one engine per
// process, built outside the clock, warmed on every input first.
//
//   for r in $(seq 1 21); do for e in m62 m72 ins; do
//     for c in batt lat; do dart _tins.dart $e $c; done; done; done
//
// No instrumented copy appears here: `_m72cnt` carries the `nRelax` probes in
// `_step`, which call `_notFirst` and `_guardsOf` on the relaxed path, so it
// cannot stand in for m72 on a clock.
import 'dart:io';
import 'dart:math';

import 'final_table.dart' show buildSetup;
import 'm62.dart' as e62;
import 'm72.dart' as e72;
import '_m72ins.dart' as eins;

void main(List<String> argv) {
  final which = argv.isEmpty ? 'm72' : argv[0];
  final corpus = argv.length > 1 ? argv[1] : 'batt';
  final (rules, battery, _, _, latCases, _, _, _) = buildSetup();
  final inputs = corpus == 'lat' ? latCases : battery;

  final run = switch (which) {
    'm62' => e62.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
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
