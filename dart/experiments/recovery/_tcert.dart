// _tcert.dart -- prices the CERTIFICATE against m62 on a clean build.
//
//   for r in $(seq 1 21); do for e in m62 m72 cert nocert ins; do
//     for c in batt lat; do dart _tcert.dart $e $c; done; done; done
//
// m62's `recoverCost` returns the cost and stops (m62.dart:913-963): `_build`
// and `_verify` live behind `recover()`. m72's calls `_certified`, which
// reconstructs the witness AND re-parses the repaired string, on every input
// with cost > 0. So the battery column has been comparing cost-only work
// against cost-plus-certificate work. `nocert` is m72 with that one call
// skipped -- `_cert2.dart` is a byte copy of m72 plus a `skipCert` flag and
// nothing else, so `cert` must reproduce m72 and stands as the control.
//
// No instrumented copy appears here; `_m72cnt` cannot go on a clock.
import 'dart:io';
import 'dart:math';

import 'final_table.dart' show buildSetup;
import 'm62.dart' as e62;
import 'm72.dart' as e72;
import '_m72ins.dart' as eins;
import '_cert2.dart' as ecert;

void main(List<String> argv) {
  final which = argv.isEmpty ? 'm72' : argv[0];
  final corpus = argv.length > 1 ? argv[1] : 'batt';
  final (rules, battery, _, _, latCases, _, _, _) = buildSetup();
  final inputs = corpus == 'lat' ? latCases : battery;

  ecert.SuperDot3.skipCert = which == 'nocert';
  ecert.SuperDot3.skipVerify = which == 'nverify';
  final run = switch (which) {
    'm62' => e62.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
    'ins' => eins.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
    'cert' || 'nocert' || 'nverify' =>
      ecert.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
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
