// Three-way head-to-head in ONE process: v6 baseline vs m12 (516/519) vs m13
// (517/519). All three alternate per case so none gets a systematically colder
// heap, min of `reps`, and a cost disagreement is reported loudly.
import 'dart:math';
import 'package:squirrel_parser/squirrel_parser.dart';
import 'sd2_shape.dart' show jsonGrammar;
import 'sd6.dart' as v6;
import 'm15.dart' as a;
import 'm16.dart' as b;

const reps = 9;

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

  final r6 = v6.SuperDot3(rules: rules, topRuleName: 'JSON');
  final r12 = a.SuperDot3(rules: rules, topRuleName: 'JSON');
  final r13 = b.SuperDot3(rules: rules, topRuleName: 'JSON');

  double best(void Function() f) {
    var t = double.infinity;
    for (var i = 0; i < reps; i++) {
      final sw = Stopwatch()..start();
      f();
      sw.stop();
      t = min(t, sw.elapsedMicroseconds / 1000);
    }
    return t;
  }

  print('min of $reps runs, ms');
  print('${'case'.padRight(13)}${'n'.padLeft(5)}${'cost'.padLeft(6)}'
      '${'v6'.padLeft(9)}${'m15'.padLeft(9)}${'m16'.padLeft(9)}'
      '${'m15/v6'.padLeft(9)}${'m16/v6'.padLeft(9)}${'m16/m15'.padLeft(9)}');
  var s6 = 0.0, s12 = 0.0, s13 = 0.0;
  for (final (label, m) in cases) {
    final t6 = best(() => r6.recover(m));
    final t12 = best(() => r12.recover(m));
    final t13 = best(() => r13.recover(m));
    if (r6.lastCost != r12.lastCost || r6.lastCost != r13.lastCost) {
      print('  COST DISAGREEMENT $label: v6=${r6.lastCost} '
          'm15=${r12.lastCost} m16=${r13.lastCost}');
    }
    s6 += t6;
    s12 += t12;
    s13 += t13;
    print('${label.padRight(13)}${m.length.toString().padLeft(5)}'
        '${r6.lastCost.toString().padLeft(6)}'
        '${t6.toStringAsFixed(1).padLeft(9)}${t12.toStringAsFixed(1).padLeft(9)}'
        '${t13.toStringAsFixed(1).padLeft(9)}'
        '${(t12 / t6).toStringAsFixed(2).padLeft(8)}x'
        '${(t13 / t6).toStringAsFixed(2).padLeft(8)}x'
        '${(t13 / t12).toStringAsFixed(2).padLeft(8)}x');
  }
  print('${'TOTAL'.padRight(24)}${s6.toStringAsFixed(1).padLeft(9)}'
      '${s12.toStringAsFixed(1).padLeft(9)}${s13.toStringAsFixed(1).padLeft(9)}'
      '${(s12 / s6).toStringAsFixed(2).padLeft(8)}x'
      '${(s13 / s6).toStringAsFixed(2).padLeft(8)}x'
      '${(s13 / s12).toStringAsFixed(2).padLeft(8)}x');
}
