// _ab72.dart -- where does m72's 5% over m71 actually go?
//
// _latfair72 confirms the gap is real and not drift. m72's search differs from
// m71's in exactly two ways: it records a reason on every write (a fourth int
// per answer) and it keeps answer lists in split order (I30). This times m71,
// m72, and an m72 whose ONLY change is that `_keepBest` appends the way m62 and
// m71 do -- so the difference between the last two is the price of the ordering
// alone, and whatever gap survives belongs to the reason slot.
import 'dart:math';

import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show jsonGrammar;
import '_lat72.dart' show latCases;
import 'm71.dart' as e71;
import 'm72.dart' as e72;
import '_m72app.dart' as eap;
import '_m72p3.dart' as ebs;

const _reps = 7;

double best(void Function(String) f, String s) {
  var t = double.infinity;
  for (var i = 0; i < 3; i++) {
    final sw = Stopwatch()..start();
    f(s);
    t = min(t, sw.elapsedMicroseconds / 1000);
  }
  return t;
}

double median(List<double> xs) {
  final v = [...xs]..sort();
  return v[v.length ~/ 2];
}

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final cases = latCases();
  for (final s in cases) {
    e71.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(s);
    e72.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(s);
    eap.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(s);
    ebs.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(s);
  }
  final m = {'m71': <double>[], 'm72': <double>[], 'm72-append': <double>[], 'm72-stride3': <double>[]};
  for (var r = 0; r < _reps; r++) {
    var a = 0.0, b = 0.0, c = 0.0, d = 0.0;
    for (final s in cases) {
      a += best((x) => e71.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(x), s);
      b += best((x) => e72.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(x), s);
      c += best((x) => eap.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(x), s);
      d += best((x) => ebs.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(x), s);
    }
    m['m71']!.add(a);
    m['m72']!.add(b);
    m['m72-append']!.add(c);
    m['m72-stride3']!.add(d);
    print('rep $r  ${a.toStringAsFixed(1)} / ${b.toStringAsFixed(1)} / ${c.toStringAsFixed(1)} / ${d.toStringAsFixed(1)}');
  }
  print('');
  final a = median(m['m71']!), b = median(m['m72']!), c = median(m['m72-append']!), d = median(m['m72-stride3']!);
  print('m71 (no reason, no order)   ${a.toStringAsFixed(1)}');
  print('m72 (reason + order)        ${b.toStringAsFixed(1)}   /m71=${(b / a).toStringAsFixed(3)}');
  print('m72 append (reason only)    ${c.toStringAsFixed(1)}   /m71=${(c / a).toStringAsFixed(3)}');
  print('m72 stride 3 (packed why)   ${d.toStringAsFixed(1)}   /m71=${(d / a).toStringAsFixed(3)}');
  print('');
  print('price of I30 ordering       ${(b - c).toStringAsFixed(1)} ms  (${((b / c - 1) * 100).toStringAsFixed(1)}%)');
  print('price of the reason slot    ${(c - a).toStringAsFixed(1)} ms  (${((c / a - 1) * 100).toStringAsFixed(1)}%)');
}
