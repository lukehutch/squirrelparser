// Latency across the generations, all in ONE process, alternating per case so
// none gets a systematically colder heap. Cost disagreements are reported
// loudly: every engine here claims to compute the same objective, so any
// disagreement is a real finding, not a tuning difference.
import 'dart:math';
import 'package:squirrel_parser/squirrel_parser.dart';
import 'sd2_shape.dart' show jsonGrammar;
import 'sd6.dart' as g6;
import 'm16.dart' as g16;
import 'm22.dart' as g22;
import 'm25.dart' as g25;
import 'm26.dart' as g26;

const reps = 5;

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final big = '{"users":[{"id":1,"name":"ann","tags":["x","y"]},'
      '{"id":2,"name":"bob","tags":["z"]},{"id":3,"name":"cyd","tags":[]}],'
      '"total":3,"ok":true}';
  final cases = <(String, String)>[];
  for (final k in [4, 16, 64]) {
    cases.add(('DEL-$k', big.substring(0, 30) + big.substring(30 + k)));
    cases.add(('INS-$k', big.substring(0, 30) + ('@' * k) + big.substring(30)));
    final ch = big.substring(30, 30 + k).split('')..shuffle(Random(12345 + k));
    cases.add(
        ('SCRAM-$k', big.substring(0, 30) + ch.join() + big.substring(30 + k)));
  }
  String doc(int k) {
    final it = [for (var i = 0; i < k; i++) '{"id":$i,"name":"n$i","ok":true}'];
    return '{"items":[${it.join(',')}],"total":$k}';
  }
  for (final k in [4, 16, 64]) {
    final d = doc(k);
    final mid = d.length ~/ 2;
    cases.add(
        ('1typo-n${d.length}', '${d.substring(0, mid)}Q${d.substring(mid + 1)}'));
  }

  final names = ['v6', 'm16', 'm22', 'm25', 'm26'];
  final r6 = g6.SuperDot3(rules: rules, topRuleName: 'JSON');
  final r16 = g16.SuperDot3(rules: rules, topRuleName: 'JSON');
  final r22 = g22.SuperDot3(rules: rules, topRuleName: 'JSON');
  final r25 = g25.SuperDot3(rules: rules, topRuleName: 'JSON');
  final r26 = g26.SuperDot3(rules: rules, topRuleName: 'JSON');
  final runs = <int Function(String)>[
    (s) => r6.recoverCost(s),
    (s) => r16.recoverCost(s),
    (s) => r22.recoverCost(s),
    (s) => r25.recoverCost(s),
    (s) => r26.recoverCost(s),
  ];

  double best(int Function(String) f, String m) {
    var t = double.infinity;
    for (var i = 0; i < reps; i++) {
      final sw = Stopwatch()..start();
      f(m);
      sw.stop();
      t = min(t, sw.elapsedMicroseconds / 1000);
    }
    return t;
  }

  final tot = List<double>.filled(names.length, 0);
  print('min of $reps runs, ms');
  final hdr = StringBuffer('${'case'.padRight(13)}${'n'.padLeft(5)}'
      '${'cost'.padLeft(5)}');
  for (final n in names) {
    hdr.write(n.padLeft(8));
  }
  for (final n in names.skip(1)) {
    hdr.write('$n/v6'.padLeft(9));
  }
  print(hdr);
  for (final (label, m) in cases) {
    final t = <double>[];
    final costs = <int>[];
    for (var i = 0; i < names.length; i++) {
      t.add(best(runs[i], m));
      costs.add(runs[i](m));
    }
    if (costs.any((c) => c != costs[0])) {
      print('  COST DISAGREEMENT $label: $costs');
    }
    final row = StringBuffer('${label.padRight(13)}'
        '${m.length.toString().padLeft(5)}${costs[0].toString().padLeft(5)}');
    for (var i = 0; i < names.length; i++) {
      tot[i] += t[i];
      row.write(t[i].toStringAsFixed(1).padLeft(8));
    }
    for (var i = 1; i < names.length; i++) {
      row.write('${(t[i] / t[0]).toStringAsFixed(2).padLeft(8)}x');
    }
    print(row);
  }
  final row = StringBuffer('TOTAL'.padRight(23));
  for (final v in tot) {
    row.write(v.toStringAsFixed(1).padLeft(8));
  }
  for (var i = 1; i < names.length; i++) {
    row.write('${(tot[i] / tot[0]).toStringAsFixed(2).padLeft(8)}x');
  }
  print(row);
}
