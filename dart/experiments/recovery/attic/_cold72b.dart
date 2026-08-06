// _cold72b.dart -- _cold72 with the defect that made it disagree with the table.
//
// `_cold72` builds a FRESH `SuperDot3` for every timed call. The constructor
// looks free -- it only stores `rules` and `topRuleName` -- but `_rules`,
// `_eps` and the whole normal-form lowering are `late final`, so they are
// computed on FIRST USE. A fresh engine per call therefore re-lowers the entire
// grammar and re-derives `_goalFromNothing` inside the timed region, every time.
//
// `final_table.dart` does not do that. It builds ONE engine per row and returns
// closures over it, so the lowering is paid once and every timed call measures
// recovery on an already-lowered grammar. That is the protocol all 45 rows use,
// and for a latency column it is the right one: a caller constructs once.
//
// The two instruments disagreed in ORDER, not just magnitude -- across four full
// table runs m72's latms was below m71's every time (median 210.2 vs 225.0,
// ratio 0.934), while `_cold72` at n=21 put m72 ABOVE m71 at every one of 21
// ranks (229.2 vs 223.2, ratio 1.027). Same entry point, `recoverCost`, so the
// difference had to be what surrounds it. This file is the control: identical to
// `_cold72` except the engine is built ONCE, outside the timed region.
//
//   for r in $(seq 1 21); do for e in m71 m72; do dart _cold72b.dart $e; done; done
import 'dart:io';
import 'dart:math';

import 'final_table.dart' show buildSetup;
import 'm62.dart' as e62;
import 'm71.dart' as e71;
import 'm72.dart' as e72;
import '_m72app.dart' as eap;
import '_m72p3.dart' as ep3;

void main(List<String> argv) {
  final which = argv.isEmpty ? 'm72' : argv[0];
  final (rules, _, _, _, cases, _, _, _) = buildSetup();

  // Built ONCE, outside the timed region, exactly as `final_table.dart` does.
  final int Function(String) run = switch (which) {
    'm62' => e62.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
    'm71' => e71.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
    'm72' => e72.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
    'p3' => ep3.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
    _ => eap.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
  };

  for (final s in cases) {
    run(s); // untimed warm pass, as the table does
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
