// Scratch: v13 vs v20 on the SAME shape at the SAME n, interleaved, so the
// speedup and the exponent come from one clock rather than two runs.
//
//   dart run _scaleab.dart

import 'dart:math' as math;

import 'package:squirrel_parser/squirrel_parser.dart';

import '_scale.dart' show shapes;
import '_v13.dart' as a;
import '_v20.dart' as b;

double _log2(double x) => x <= 0 ? 0.0 : math.log(x) / math.ln2;

double _time(MatchResult Function() run) {
  run();
  final sw = Stopwatch()..start();
  var reps = 0;
  while (sw.elapsedMilliseconds < 100) {
    run();
    reps++;
    if (sw.elapsedMilliseconds > 3000) break;
  }
  sw.stop();
  return sw.elapsedMicroseconds / 1000 / reps;
}

void main() {
  final sizes = [128, 256, 512, 1024];
  print('shape              n      v13 ms    v20 ms   x     e13    e20');
  for (final sh in shapes) {
    final rules = MetaGrammar.parseGrammar(sh.grammar);
    var pa = 0.0, pb = 0.0, pn = 0;
    for (final n in sizes) {
      final s = sh.gen(n);
      MatchResult safe(MatchResult Function() f) {
        try {
          return f();
        } catch (_) {
          return Match(rules.values.first, 0, 0);
        }
      }

      final ta = _time(() =>
          safe(() => a.Squirrel(rules: rules, topRuleName: sh.top).recover(s)));
      final tb = _time(() =>
          safe(() => b.Squirrel(rules: rules, topRuleName: sh.top).recover(s)));
      String e(double p, double c) => pn == 0
          ? '    '
          : (_log2(c / p) / _log2(s.length / pn.toDouble())).toStringAsFixed(2);
      print('${sh.name.padRight(15)} ${s.length.toString().padLeft(5)} '
          '${ta.toStringAsFixed(2).padLeft(9)} '
          '${tb.toStringAsFixed(2).padLeft(9)} '
          '${(ta / tb).toStringAsFixed(2).padLeft(5)}x '
          '${e(pa, ta).padLeft(6)} ${e(pb, tb).padLeft(6)}');
      pa = ta;
      pb = tb;
      pn = s.length;
    }
    print('');
  }
}
