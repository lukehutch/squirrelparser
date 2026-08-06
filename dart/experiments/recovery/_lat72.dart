// _lat71.dart -- WHERE does I27 spend the latency, case by case.
//
// The official row says m71 is 342.6 latms against m62's 204.1, and the meet
// cache did not move it, so the cost is not in the class algebra. This runs
// final_table's own latency corpus, per case, under both engines, and prints
// the memo cell count with it -- because the obligation is part of the memo
// key, so I27 can only be paying in one of two currencies: more cells, or more
// work per cell.
import 'dart:math';

import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show jsonGrammar;
import '_m62cells.dart' as e62;
import 'm72.dart' as e71;
import '_m71tight.dart' as tig;

List<String> latCases() {
  final big = '{"users":[{"id":1,"name":"ann","tags":["x","y"]},'
      '{"id":2,"name":"bob","tags":["z"]},{"id":3,"name":"cyd","tags":[]}],'
      '"total":3,"ok":true}';
  final out = <String>[];
  for (final k in [4, 16, 64]) {
    out.add(big.substring(0, 30) + big.substring(30 + k));
    out.add(big.substring(0, 30) + ('@' * k) + big.substring(30));
    final ch = big.substring(30, 30 + k).split('')..shuffle(Random(12345 + k));
    out.add(big.substring(0, 30) + ch.join() + big.substring(30 + k));
  }
  for (final k in [4, 16, 64]) {
    final it = [for (var i = 0; i < k; i++) '{"id":$i,"name":"n$i","ok":true}'];
    final d = '{"items":[${it.join(',')}],"total":$k}';
    final mid = d.length ~/ 2;
    out.add('${d.substring(0, mid)}Q${d.substring(mid + 1)}');
  }
  return out;
}

double best(int Function(String) f, String s) {
  var t = double.infinity;
  for (var i = 0; i < 5; i++) {
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

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final cases = latCases();
  final a = e62.SuperDot3(rules: rules, topRuleName: 'JSON');
  final b = e71.SuperDot3(rules: rules, topRuleName: 'JSON');
  for (final s in cases) {
    a.recoverCost(s);
    b.recoverCost(s);
  }
  print('case  len  cost62 cost71     m62ms     m71ms   ratio   cells62   '
      'cells71  cellratio');
  var t62 = 0.0, t71 = 0.0;
  for (var i = 0; i < cases.length; i++) {
    final s = cases[i];
    final f = e62.SuperDot3(rules: rules, topRuleName: 'JSON');
    final g = e71.SuperDot3(rules: rules, topRuleName: 'JSON');
    final c62 = f.recoverCost(s), c71 = g.recoverCost(s);
    final n62 = f.cellCount, n71 = g.cellCount;
    final x = best(e62.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost, s);
    final y = best(e71.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost, s);
    t62 += x;
    t71 += y;
    print('${i.toString().padLeft(4)}'
        '${s.length.toString().padLeft(5)}'
        '${c62.toString().padLeft(8)}'
        '${c71.toString().padLeft(7)}'
        '${x.toStringAsFixed(1).padLeft(10)}'
        '${y.toStringAsFixed(1).padLeft(10)}'
        '${(y / x).toStringAsFixed(2).padLeft(8)}'
        '${n62.toString().padLeft(10)}'
        '${n71.toString().padLeft(10)}'
        '${(n71 / n62).toStringAsFixed(2).padLeft(11)}');
  }
  print('TOTAL m62=${t62.toStringAsFixed(1)}  m71=${t71.toStringAsFixed(1)}  '
      'ratio=${(t71 / t62).toStringAsFixed(2)}');
  // Which half of I27 costs it? Case 8 is 90% of the total.
  final s8 = cases[8];
  void row(String n, double Function() time, int Function() cells) => print(
      'case8  $n  ${time().toStringAsFixed(1).padLeft(7)} ms   cells=${cells()}');
  row('m62      ',
      () => best(e62.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost, s8),
      () {
    final p = e62.SuperDot3(rules: rules, topRuleName: 'JSON');
    p.recoverCost(s8);
    return p.cellCount;
  });
  row('tight    ',
      () => best(tig.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost, s8),
      () {
    final p = tig.SuperDot3(rules: rules, topRuleName: 'JSON');
    p.recoverCost(s8);
    return p.cellCount;
  });
  row('m71 full ',
      () => best(e71.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost, s8),
      () {
    final p = e71.SuperDot3(rules: rules, topRuleName: 'JSON');
    p.recoverCost(s8);
    return p.cellCount;
  });
}
