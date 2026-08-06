// Per-case latency, base against candidate, on the SAME clock and the same
// case order -- so the question "is the slowdown broad or concentrated?" is
// answered by the distribution and not by a total that one pathological
// document can carry on its own.
//
// Usage: dart run _swlat.dart
import 'package:squirrel_parser/squirrel_parser.dart';

import '_r9base.dart' as base;
import 'astdiff.dart';
import 'r9.dart' as cand;

int _at(List<int> xs, double q) => xs[(xs.length * q).floor().clamp(0, xs.length - 1)];

void main() {
  final cases = weighted(buildBattery());
  final rulesOf = {
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final eb = {
    for (final c in corpora)
      c.name: base.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top)
  };
  final ec = {
    for (final c in corpora)
      c.name: cand.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top)
  };
  final a = <int>[], b = <int>[];
  var worstDelta = 0;
  Case? worstCase;
  final sw = Stopwatch();
  for (final k in cases) {
    sw.reset();
    sw.start();
    try {
      eb[k.grammar]!.recover(k.mutant);
    } catch (_) {}
    sw.stop();
    final ta = sw.elapsedMicroseconds;
    sw.reset();
    sw.start();
    try {
      ec[k.grammar]!.recover(k.mutant);
    } catch (_) {}
    sw.stop();
    final tb = sw.elapsedMicroseconds;
    a.add(ta);
    b.add(tb);
    if (tb - ta > worstDelta) {
      worstDelta = tb - ta;
      worstCase = k;
    }
  }
  a.sort();
  b.sort();
  final sa = a.fold<int>(0, (x, y) => x + y), sb = b.fold<int>(0, (x, y) => x + y);
  print('             base      cand    ratio');
  for (final q in const [0.5, 0.9, 0.99]) {
    final x = _at(a, q), y = _at(b, q);
    print('p${(q * 100).toStringAsFixed(0).padRight(3)}  ${'${x}us'.padLeft(9)} '
        '${'${y}us'.padLeft(9)}  ${(y / (x == 0 ? 1 : x)).toStringAsFixed(2)}x');
  }
  print('max   ${'${a.last}us'.padLeft(9)} ${'${b.last}us'.padLeft(9)}  '
      '${(b.last / a.last).toStringAsFixed(2)}x');
  print('total ${'${sa ~/ 1000}ms'.padLeft(9)} ${'${sb ~/ 1000}ms'.padLeft(9)}  '
      '${(sb / sa).toStringAsFixed(2)}x');
  print('');
  print('biggest single regression: +${worstDelta}us on '
      '${worstCase?.grammar} ${worstCase?.category}');
  print('  "${worstCase?.mutant}"');
  // How much of the extra total is carried by the slowest 1% of cases?
  final tail = b.length ~/ 100;
  var tailB = 0;
  for (var i = b.length - tail; i < b.length; i++) {
    tailB += b[i];
  }
  print('slowest 1% of candidate runs = ${(100 * tailB / sb).toStringAsFixed(1)}% '
      'of its total');
}
