// _bat75.dart -- ONE engine per process, named on the command line.
//
// The protocol the m72 occasion had to learn four times: engines sharing a VM
// share its JIT state, so each is measured in its own process; the engine is
// CONSTRUCTED ONCE outside the clock, because the lowering is late-final and a
// fresh-per-call engine re-lowers the grammar inside the timed region; and the
// entry point is NAMED, because `recoverCost` and `recover` are different
// questions -- m74 and m75 both build the witness on the cost path, so only
// `recover` compares like with like.
//
// Prints two numbers: battery total ms, latency median ms.
import 'dart:io';
import 'dart:math';

import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show buildSetup;
import '_lat72.dart' show latCases;
import 'm74.dart' as e74;
import 'm75.dart' as e75;

double median(List<double> xs) {
  final v = [...xs]..sort();
  return v.length.isOdd
      ? v[v.length ~/ 2]
      : (v[v.length ~/ 2 - 1] + v[v.length ~/ 2]) / 2;
}

void main(List<String> argv) {
  final which = argv.isEmpty ? 'm75' : argv.first;
  final setup = buildSetup();
  final rules = setup.$1, battery = setup.$2;

  // Constructed once, outside every clock.
  final dynamic engine = which == 'm74'
      ? e74.SuperDot3(rules: rules, topRuleName: 'JSON')
      : e75.SuperDot3(rules: rules, topRuleName: 'JSON');
  void run(String s) => engine.recover(s);

  for (final s in battery.take(60)) {
    run(s); // warm the VM on the same shapes, off the clock
  }

  final sw = Stopwatch()..start();
  for (final s in battery) {
    run(s);
  }
  final batt = sw.elapsedMicroseconds / 1000;

  final lats = <double>[];
  for (final c in latCases()) {
    var t = double.infinity;
    for (var i = 0; i < 3; i++) {
      final w = Stopwatch()..start();
      try {
        run(c);
      } catch (_) {
        t = -1;
        break;
      }
      t = min(t, w.elapsedMicroseconds / 1000);
    }
    lats.add(t);
  }

  // The table's `latms` is the TOTAL over the 12 cases; the median it reports
  // is over repeated RUNS, which is what the driver around this does.
  final lat = lats.fold<double>(0, (a, b) => a + b);
  stdout.writeln('$which ${batt.toStringAsFixed(1)} '
      '${lat.toStringAsFixed(1)}');
}
