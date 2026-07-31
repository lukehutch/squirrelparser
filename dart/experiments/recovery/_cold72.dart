// _cold72.dart -- one engine, one cold process, the way the official table times.
//
// The `latms` column could not settle whether m72 is slower than m71. Every
// in-process harness disagreed with itself: `_recon72` timed the SAME build at
// 234.1, 257.4 and 270.2 ms in three consecutive reps, and the m72/m71 ratio
// read 1.05 from one harness and 1.13 from another. Engines sharing a VM share
// its JIT state and its heap, so a three-engine harness measures the harness.
//
// This runs ONE engine, alone, in its own process, and takes the corpus from
// `buildSetup()` so it is the same twelve cases the table's own column uses --
// not a copy that could drift. The caller rotates engines across rounds so
// machine drift cannot settle on one of them, and reports medians.
//
//   for r in $(seq 1 21); do for e in m71 app m72; do dart _cold72.dart $e; done; done
//
// USE n >= 21. Seven rounds is NOT enough, and this file previously recorded
// the proof of that as if it were a result: medians of 7 read m71 215.2, app
// 220.0, m72 220.3, from which the header concluded that I30's ordering is
// "free" at m72/app = 1.001. A second n=7 sweep put that same ratio at 1.047,
// and at n=21 the decomposition is m71 219.4, app 227.9, m72 236.5 -- I29's
// fourth int costs 3.9% and I30's ordering costs 3.8%, not nothing. Fixing the
// apparatus is not the same as fixing the measurement: a good instrument read
// at too small an n reproduces exactly the failure it was built to fix.
// (`app` is m72 with I29's recorded reason but WITHOUT I30's ordering. Costs
// here are already net of the 4-7x faster rebuild, since `recoverCost` builds
// and verifies the witness inside the timed path.)
//
// Post-bisect, n=21: m71 median 223.2, m72 229.2 -- ratio 1.027, with m72 above
// m71 at EVERY one of the 21 ranks. Ratios are drift-immune because both are
// measured in the same sweep, so bisecting `_keepBest` was worth 5.0%
// (1.078 -> 1.027), not the ~2% at which it was once dismissed as noise.
//
// The wider result is about the column, not the engine: one engine ranges
// 201.4-240.2 ms across cold runs, so the table's `latms` is a single sample
// from that spread and can be actively misleading -- in the run recorded in
// m72's LESSONS row it read m72 208.3 against m71 228.1, calling m72 8.7%
// FASTER where this harness says 2.7% slower, and 208.3 is below the minimum
// of all 21 cold samples. Re-read any single-digit difference here, at n >= 21,
// before believing it, optimising against it, OR DISMISSING IT.
import 'dart:io';
import 'dart:math';

import 'final_table.dart' show buildSetup;
import 'm62.dart' as e62;
import 'm71.dart' as e71;
import 'm72.dart' as e72;
import '_m72app.dart' as eap;

void main(List<String> argv) {
  final which = argv.isEmpty ? 'm72' : argv[0];
  final (rules, _, _, _, cases, _, _, _) = buildSetup();
  int run(String s) => switch (which) {
        'm62' => e62.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(s),
        'm71' => e71.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(s),
        'm72' => e72.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(s),
        _ => eap.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(s),
      };

  for (final s in cases) {
    run(s); // warm this one engine on every case, as the table does
  }
  var total = 0.0;
  for (final s in cases) {
    var t = double.infinity;
    for (var i = 0; i < 5; i++) {
      final sw = Stopwatch()..start();
      run(s);
      t = min(t, sw.elapsedMicroseconds / 1000);
    }
    total += t;
  }
  stdout.writeln('$which ${total.toStringAsFixed(1)}');
}
