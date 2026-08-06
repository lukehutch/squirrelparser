// _t75.dart -- splits m73's certificate and prices the allocation fixes.
//
//   for r in $(seq 1 21); do for e in m62 m73 nv a1 ab all o62; do
//     for c in batt lat; do dart _t75.dart $e $c; done; done; done
//
// At n=21 the whole m73/m62 gap is the certificate: 43.7 ms battery (m73 298.0
// vs nc 254.3) and 4.4 ms latency, with the I27/I28 wiring itself a dead tie
// (`w` 1.0039 batt at 9/21 paired rounds). `nv` builds the witness tree but
// never re-parses it, so nv-nc prices `_build` and m73-nv prices `_emit` plus
// the fresh parse. That split decides whether a design that emits the repaired
// string WITHOUT a tree can afford to keep a whole-string re-parse.
//
// a1/ab/all/o62 price the three hot-path allocations: `_entryAt`'s putIfAbsent
// closure (C3), `_widthOf`'s (C2), and `_cleanRegret`'s missing leaf fast path
// (C1). o62 is the same three on m62, so a win can be attributed rather than
// credited to m73.
import 'dart:io';
import 'dart:math';

import 'final_table.dart' show buildSetup;
import 'm62.dart' as e62;
import 'm73.dart' as e73;
import '_m73nv.dart' as env;
import '_m74a.dart' as ea;
import '_m74b.dart' as eb;
import '_m74.dart' as eall;
import '_m62o.dart' as eo;

void main(List<String> argv) {
  final which = argv.isEmpty ? 'm73' : argv[0];
  final corpus = argv.length > 1 ? argv[1] : 'batt';
  final (rules, battery, _, _, latCases, _, _, _) = buildSetup();
  final inputs = corpus == 'lat' ? latCases : battery;

  final run = switch (which) {
    'm62' => e62.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
    'nv' => env.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
    'a1' => ea.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
    'ab' => eb.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
    'all' => eall.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
    'o62' => eo.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
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
