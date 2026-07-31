// _ctor72.dart -- how much does CONSTRUCTING an engine cost, and does it differ
// between m71 and m72?
//
// `_cold72` builds a fresh `SuperDot3` for every timed call; `_cold72b` builds
// one and reuses it. They disagreed about which engine is faster, and a shared
// constant added to both cannot invert an order -- so if the per-construction
// cost were the same for m71 and m72, it could not be the explanation. This
// measures that cost per engine, in one process so the JIT state is shared.
//
//   A = fresh engine per timed call, over the 12 cases   (`_cold72`'s protocol)
//   B = one engine, reused, over the 12 cases            (`_cold72b`'s protocol)
//   A - B = what construct-per-call adds, for THIS engine
//
// `lower` is the same cost isolated: a fresh engine given a one-character input,
// so recovery is negligible and the `late final` grammar lowering dominates.
//
//   for r in $(seq 1 9); do for e in m71 m72; do dart _ctor72.dart $e; done; done
import 'dart:io';
import 'dart:math';

import 'final_table.dart' show buildSetup;
import 'm71.dart' as e71;
import 'm72.dart' as e72;

void main(List<String> argv) {
  final which = argv.isEmpty ? 'm72' : argv[0];
  final (rules, _, _, _, cases, _, _, _) = buildSetup();

  int Function(String) fresh() => which == 'm71'
      ? e71.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost
      : e72.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost;

  // Warm the JIT on this engine's code before anything is timed, so neither
  // protocol is charged for compilation the other already paid.
  final warm = fresh();
  for (var i = 0; i < 3; i++) {
    for (final s in cases) {
      warm(s);
    }
  }

  var a = 0.0; // fresh engine inside every timed call
  for (final s in cases) {
    var t = double.infinity;
    for (var i = 0; i < 5; i++) {
      final sw = Stopwatch()..start();
      fresh()(s);
      t = min(t, sw.elapsedMicroseconds / 1000);
    }
    a += t;
  }

  var b = 0.0; // one engine, reused
  final one = fresh();
  for (final s in cases) {
    one(s);
  }
  for (final s in cases) {
    var t = double.infinity;
    for (var i = 0; i < 5; i++) {
      final sw = Stopwatch()..start();
      one(s);
      t = min(t, sw.elapsedMicroseconds / 1000);
    }
    b += t;
  }

  // The construction cost alone: a one-character input makes recovery trivial,
  // so what remains is the lowering the `late final` fields do on first use.
  var lower = double.infinity;
  for (var i = 0; i < 20; i++) {
    final sw = Stopwatch()..start();
    fresh()('{');
    lower = min(lower, sw.elapsedMicroseconds / 1000);
  }

  stdout.writeln('$which A ${a.toStringAsFixed(1)} B ${b.toStringAsFixed(1)} '
      'A-B ${(a - b).toStringAsFixed(1)} lower ${lower.toStringAsFixed(3)}');
}
