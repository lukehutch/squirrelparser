// _latfair72.dart -- m62 vs m71 vs m72, interleaved, through both entry points.
//
// The official table gives each engine one cold run, and the m71 occasion showed
// that row's own battms and RRmax were outliers of their distributions. m72's
// row reads 225.6 latms against m71's 213.4, and a single sample cannot tell a
// 5% engine difference from a 5% machine difference. This interleaves the three
// engines WITHIN each case and each rep, so any drift hits all three equally,
// and reports the median rep rather than one sample.
//
// It times both entry points on purpose. `latms` times `recoverCost`, which
// under I28 returns a number AND a verified witness; `recover` is what a caller
// actually invokes, and the only point where all three have produced the same
// thing by the time the clock stops.
import 'dart:math';

import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show jsonGrammar;
import '_lat72.dart' show latCases;
import 'm62.dart' as e62;
import 'm71.dart' as e71;
import 'm72.dart' as e72;

const _reps = 7;

double best(void Function(String) f, String s) {
  var t = double.infinity;
  for (var i = 0; i < 3; i++) {
    final sw = Stopwatch()..start();
    try {
      f(s);
    } catch (_) {
      return -1;
    }
    t = min(t, sw.elapsedMicroseconds / 1000);
  }
  return t;
}

double median(List<double> xs) {
  final v = [...xs]..sort();
  return v.length.isOdd
      ? v[v.length ~/ 2]
      : (v[v.length ~/ 2 - 1] + v[v.length ~/ 2]) / 2;
}

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final cases = latCases();

  // Every engine sees every case before any of them is timed.
  for (final s in cases) {
    e62.SuperDot3(rules: rules, topRuleName: 'JSON').recover(s);
    e71.SuperDot3(rules: rules, topRuleName: 'JSON').recover(s);
    e72.SuperDot3(rules: rules, topRuleName: 'JSON').recover(s);
  }

  final cost = {'m62': <double>[], 'm71': <double>[], 'm72': <double>[]};
  final full = {'m62': <double>[], 'm71': <double>[], 'm72': <double>[]};

  for (var r = 0; r < _reps; r++) {
    var c62 = 0.0, c71 = 0.0, c72 = 0.0, f62 = 0.0, f71 = 0.0, f72 = 0.0;
    for (final s in cases) {
      c62 += best(
          (x) => e62.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(x),
          s);
      c71 += best(
          (x) => e71.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(x),
          s);
      c72 += best(
          (x) => e72.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(x),
          s);
      f62 += best(
          (x) => e62.SuperDot3(rules: rules, topRuleName: 'JSON').recover(x), s);
      f71 += best(
          (x) => e71.SuperDot3(rules: rules, topRuleName: 'JSON').recover(x), s);
      f72 += best(
          (x) => e72.SuperDot3(rules: rules, topRuleName: 'JSON').recover(x), s);
    }
    cost['m62']!.add(c62);
    cost['m71']!.add(c71);
    cost['m72']!.add(c72);
    full['m62']!.add(f62);
    full['m71']!.add(f71);
    full['m72']!.add(f72);
    print('rep $r  cost ${c62.toStringAsFixed(1)} / ${c71.toStringAsFixed(1)}'
        ' / ${c72.toStringAsFixed(1)}   full ${f62.toStringAsFixed(1)}'
        ' / ${f71.toStringAsFixed(1)} / ${f72.toStringAsFixed(1)}');
  }

  void row(String n, Map<String, List<double>> m) {
    final a = median(m['m62']!), b = median(m['m71']!), c = median(m['m72']!);
    print('${n.padRight(32)}${a.toStringAsFixed(1).padLeft(8)}'
        '${b.toStringAsFixed(1).padLeft(8)}${c.toStringAsFixed(1).padLeft(8)}'
        '   m72/m62=${(c / a).toStringAsFixed(2)}'
        '  m72/m71=${(c / b).toStringAsFixed(2)}');
  }

  print('');
  print('median of $_reps reps                m62     m71     m72');
  row('recoverCost (official latms)', cost);
  row('recover     (whole answer)', full);
}
