// _cold72.dart -- one engine, one cold process, timed the way a caller uses it.
//
//   for r in $(seq 1 21); do for e in m71 app bs m72; do dart _cold72.dart $e; done; done
//   dart _cold72.dart m72 fresh      # the defective protocol, kept reproducible
//
// THIS FILE HAS BEEN WRONG TWICE. Read the whole header before believing a
// number it produces, optimising against one, OR DISMISSING one.
//
// It exists because every in-process harness disagreed with itself: `_recon72`
// timed the SAME build at 234.1, 257.4 and 270.2 ms in three consecutive reps,
// and the m72/m71 ratio read 1.05 from one harness and 1.13 from another.
// Engines sharing a VM share its JIT state and its heap, so a three-engine
// harness measures the harness. This runs ONE engine, alone, in its own
// process, over the same twelve cases `buildSetup()` gives the table's own
// column -- not a copy that could drift -- with the caller rotating engines
// across rounds so machine drift cannot settle on one of them.
//
// FIRST WRONG READING -- THE SAMPLE SIZE. Medians of 7 read m71 215.2, app
// 220.0, m72 220.3, and this header recorded the conclusion that I30's ordering
// was "free" at 1.001. A second n=7 sweep put the same ratio at 1.047. A good
// instrument read at too small an n reproduces exactly the failure it was built
// to fix. USE n >= 21.
//
// SECOND WRONG READING -- THE PROTOCOL. This file used to build a FRESH
// `SuperDot3` inside every timed call. `_rules`, `_eps` and the whole
// normal-form lowering are `late final`, so a fresh engine re-lowers the
// grammar and re-derives `_goalFromNothing` inside the clock, and it throws
// away whatever the engine had cached from the previous input. `final_table`
// does not do that: it builds ONE engine per row and returns closures over it.
// For a latency column that is the right protocol -- a caller constructs once.
//
// `_ctor72` prices the difference, both arms in one process so the JIT state is
// shared (n=9 medians): fresh-per-call adds 11.9 ms per round to m71 AND 11.9
// to m72, of which the lowering itself is only ~0.57 ms per construction. Note
// what that does NOT explain: a constant added to both engines cannot invert
// their order. What it does is INFLATE the ratio -- within one process m72/m71
// read 1.061 fresh-per-call against 1.024 reused. The published "m72 is 2.7%
// slower, at every one of 21 ranks" came from the fresh arm and is withdrawn,
// along with the decomposition built on it (I29 3.9%, I30 3.8%, bisect 5.0%).
//
// Construct-once, n=21, this instrument:
//
//   m71 216.3   m72 218.4   app 218.6   p3 217.1        (medians, ms)
//   m72/m71 1.0097, m72 faster in 10 of 21 paired rounds
//
// Nothing separates. Every engine here is within 1% of every other with
// coin-flip paired win counts, so the honest statement about I29+I30 is that
// their latency cost is NOT RESOLVABLE at n=21, in either direction.
//
// The table's column is not exempt and is the worst of the three: over four
// full runs it put m72's latms BELOW m71's every time (210.2 vs 225.0, 0.934),
// an ordering neither single-engine protocol reproduces. Forty-five engines
// share one VM there. Treat `latms` as comparative-within-a-run at best.
//
// WATCH THE CONFOUND when using the ablation arms. `app` appends instead of
// ordered-inserting AND drops the head-length restart, so it ablates I30
// whole -- but it is also LINEAR, as is `bs`, while `m72` bisects. Comparing
// `app` against `m72` therefore charges I30 and credits the bisect in the same
// number. The confound-free pairs are `app` vs `bs` for I30, and `bs` vs `m72`
// for the bisect.
import 'dart:io';
import 'dart:math';

import 'final_table.dart' show buildSetup;
import 'm62.dart' as e62;
import 'm71.dart' as e71;
import 'm72.dart' as e72;
import '_m72app.dart' as eap;
import '_m72bs.dart' as ebs;
import '_m72p3.dart' as ep3;

void main(List<String> argv) {
  final which = argv.isEmpty ? 'm72' : argv[0];
  final freshPerCall = argv.length > 1 && argv[1] == 'fresh';
  final (rules, _, _, _, cases, _, _, _) = buildSetup();

  int Function(String) build() => switch (which) {
        'm62' => e62.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
        'm71' => e71.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
        'm72' => e72.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
        'bs' => ebs.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
        'p3' => ep3.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
        _ => eap.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
      };

  // One engine, built OUTSIDE the timed region, exactly as `final_table` does.
  // `fresh` reproduces the defect instead, for anyone re-checking the header.
  final one = build();
  int run(String s) => freshPerCall ? build()(s) : one(s);

  for (final s in cases) {
    run(s); // warm on every case, as the table does
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
