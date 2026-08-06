// _coldbat.dart -- `_cold72` for the OTHER timing column.
//
//   for r in $(seq 1 15); do for e in m62 m71 m72; do dart _coldbat.dart $e; done; done
//
// `_cold72` re-read `latms` with one engine per process and found that the
// table's column -- 45 engines sharing one VM -- had m72 and m71 in an order
// neither single-engine protocol reproduces. `battms` is produced by the same
// table under the same conditions, and every claim of the form "m62 is faster"
// rests on it. This reads the battery the same way `_cold72` reads the latency
// corpus: ONE engine, alone, in its own process, built outside the clock,
// warmed on every input first, over the same 519 mutants `buildSetup()` hands
// the table.
//
// `recoverCost` is the entry point, matching `_cold72`, so the witness is built
// and verified inside the timed path rather than being skipped.
import 'dart:io';
import 'dart:math';

import 'final_table.dart' show buildSetup;
import 'm62.dart' as e62;
import 'm71.dart' as e71;
import 'm72.dart' as e72;

void main(List<String> argv) {
  final which = argv.isEmpty ? 'm72' : argv[0];
  final (rules, battery, _, _, _, _, _, _) = buildSetup();

  final run = switch (which) {
    'm62' => e62.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
    'm71' => e71.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
    _ => e72.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
  };

  for (final s in battery) {
    run(s); // warm on every input before anything is timed
  }
  var best = double.infinity;
  for (var i = 0; i < 3; i++) {
    final sw = Stopwatch()..start();
    for (final s in battery) {
      run(s);
    }
    best = min(best, sw.elapsedMicroseconds / 1000);
  }
  stdout.writeln('$which ${best.toStringAsFixed(1)}');
}
