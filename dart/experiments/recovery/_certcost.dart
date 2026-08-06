// _certcost.dart -- is I28's certificate demand the battery gap against m62?
//
//   for r in $(seq 1 11); do for a in cert guard m62; do dart _certcost.dart $a batt; done; done
//   ...and the same with `lat` for the 12 latency cases.
//
// m72's battery is 26.4% slower than m62's (0 of 15 paired rounds) but its
// latency only 4.3% slower. That split is the shape of a cost that does NOT
// scale with the DP: linear in the tree, so a small fraction of a large input
// and a large fraction of a tiny one. `_tight72` already ruled out the obvious
// candidate -- I28's tighten path fires on 0 of 519 battery inputs and 0 of 12
// latency cases, exactly 1.000 passes per input.
//
// What remains is that `_certified` is called on EVERY `recoverCost` even when
// it succeeds, and on the cost path it runs the whole reconstruction. m62 never
// demands a certificate there. `nocert` skips it -- which CHANGES THE ANSWER and
// is a diagnostic, not a proposal -- so the gap between `cert` and `nocert` is
// what the demand costs, and `m62` says how much of the 26.4% that accounts for.
import 'dart:io';
import 'dart:math';

import 'final_table.dart' show buildSetup;
import 'm62.dart' as e62;
import '_m72cnt.dart' as cnt;

void main(List<String> argv) {
  final arm = argv.isEmpty ? 'cert' : argv[0];
  final corpus = argv.length > 1 ? argv[1] : 'batt';
  final (rules, battery, _, _, latCases, _, _, _) = buildSetup();
  final inputs = corpus == 'lat' ? latCases : battery;

  final int Function(String) run;
  if (arm == 'm62') {
    run = e62.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost;
  } else {
    cnt.SuperDot3.skipCert = arm == 'nocert' || arm == 'guard';
    cnt.SuperDot3.forceGuard = arm == 'guard' || arm == 'guardcert';
    cnt.SuperDot3.skipVerify = arm == 'nverify';
    run = cnt.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost;
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
  stdout.writeln('$corpus $arm ${best.toStringAsFixed(1)}');
}
