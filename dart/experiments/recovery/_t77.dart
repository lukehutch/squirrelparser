// _t77.dart -- the certificate split, all three arms in ONE run.
//
//   for r in $(seq 1 21); do for e in m73 nv nc; do
//     for c in batt lat; do dart _t77.dart $e $c; done; done; done
//
// t74 held `nc` (no certificate) and t75 held `nv` (`_build`, no re-parse), but
// never together, so the two halves of the certificate were priced against two
// different m73 baselines and subtracted across runs. This arm set puts all
// three on one clock: m73-nc is the whole certificate, nv-nc is `_build`, and
// m73-nv is `_emit` plus the fresh parse.
import 'dart:io';
import 'dart:math';

import 'final_table.dart' show buildSetup;
import 'm73.dart' as e73;
import '_m73nv.dart' as env;
import '_m73nc.dart' as enc;

void main(List<String> argv) {
  final which = argv.isEmpty ? 'm73' : argv[0];
  final corpus = argv.length > 1 ? argv[1] : 'batt';
  final (rules, battery, _, _, latCases, _, _, _) = buildSetup();
  final inputs = corpus == 'lat' ? latCases : battery;

  final run = switch (which) {
    'nv' => env.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
    'nc' => enc.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
    _ => e73.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
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
