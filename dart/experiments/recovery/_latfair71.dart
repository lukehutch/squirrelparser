// _latfair71.dart -- the latency column compares half an answer to a whole one.
//
// final_table's `lat` part times `recoverCost`. Under I22/I28 that call returns
// a number AND a verified witness, because the number is only trustworthy
// BECAUSE the witness verified. m62's `recoverCost` returns the number alone and
// reconstructs later, inside `recover`. So the official latms puts m62's search
// against m71's search-plus-certificate, which is the same asymmetry _witdepth71
// found in the depth column.
//
// This times the identical corpus through `recover` -- the entry point a caller
// actually uses, and the only one where both engines have produced the same
// thing by the time the clock stops.
import 'dart:math';

import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show jsonGrammar;
import 'm62.dart' as e62;
import 'm70.dart' as e70;
import 'm71.dart' as e71;

/// final_table's latency corpus, rebuilt here so this file stands alone.
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

double best(void Function(String) f, String s) {
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
  // warm every engine on every case before any of them is timed
  for (final s in cases) {
    e62.SuperDot3(rules: rules, topRuleName: 'JSON').recover(s);
    e70.SuperDot3(rules: rules, topRuleName: 'JSON').recover(s);
    e71.SuperDot3(rules: rules, topRuleName: 'JSON').recover(s);
  }

  var c62 = 0.0, c70 = 0.0, c71 = 0.0; // recoverCost: the official column
  var r62 = 0.0, r70 = 0.0, r71 = 0.0; // recover: the whole answer
  for (final s in cases) {
    c62 += best((x) => e62.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(x), s);
    c70 += best((x) => e70.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(x), s);
    c71 += best((x) => e71.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(x), s);
    r62 += best((x) => e62.SuperDot3(rules: rules, topRuleName: 'JSON').recover(x), s);
    r70 += best((x) => e70.SuperDot3(rules: rules, topRuleName: 'JSON').recover(x), s);
    r71 += best((x) => e71.SuperDot3(rules: rules, topRuleName: 'JSON').recover(x), s);
  }
  void row(String n, double a, double b, double c) => print('${n.padRight(34)}'
      '${a.toStringAsFixed(1).padLeft(9)}${b.toStringAsFixed(1).padLeft(9)}'
      '${c.toStringAsFixed(1).padLeft(9)}   m71/m62=${(c / a).toStringAsFixed(2)}');
  print('entry point                           m62      m70      m71');
  row('recoverCost  (official latms)', c62, c70, c71);
  row('recover      (the whole answer)', r62, r70, r71);
}
