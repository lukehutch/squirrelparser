// Per-case latency, four engines in ONE process: the shipped DotRecovery from
// lib/, the v6 baseline, and the two merged winners. Engines alternate per case
// so none gets a systematically colder heap; min of `reps`; cost disagreements
// are reported loudly (dot is expected to agree -- it optimizes the same
// objective -- so a disagreement here would be a real finding).
import 'dart:math';
import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/recovery/dot_recovery.dart';
import 'sd2_shape.dart' show jsonGrammar;
import 'sd6.dart' as v6;
import 'm15.dart' as a;
import 'm16.dart' as b;

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

  final rd = DotRecovery(rules: rules, topRuleName: 'JSON');
  final r6 = v6.SuperDot3(rules: rules, topRuleName: 'JSON');
  final r15 = a.SuperDot3(rules: rules, topRuleName: 'JSON');
  final r16 = b.SuperDot3(rules: rules, topRuleName: 'JSON');

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
  print('${'case'.padRight(13)}${'n'.padLeft(5)}${'cost'.padLeft(5)}'
      '${'dot'.padLeft(9)}${'v6'.padLeft(9)}${'m15'.padLeft(9)}'
      '${'m16'.padLeft(9)}${'dot/v6'.padLeft(9)}${'m15/v6'.padLeft(9)}'
      '${'m16/v6'.padLeft(9)}');
  var sd = 0.0, s6 = 0.0, s15 = 0.0, s16 = 0.0;
  for (final (label, m) in cases) {
    final td = best(() => rd.recover(m));
    final t6 = best(() => r6.recover(m));
    final t15 = best(() => r15.recover(m));
    final t16 = best(() => r16.recover(m));
    if (r6.lastCost != r15.lastCost || r6.lastCost != r16.lastCost) {
      print('  COST DISAGREEMENT $label: v6=${r6.lastCost} '
          'm15=${r15.lastCost} m16=${r16.lastCost}');
    }
    sd += td;
    s6 += t6;
    s15 += t15;
    s16 += t16;
    print('${label.padRight(13)}${m.length.toString().padLeft(5)}'
        '${r6.lastCost.toString().padLeft(5)}'
        '${td.toStringAsFixed(1).padLeft(9)}${t6.toStringAsFixed(1).padLeft(9)}'
        '${t15.toStringAsFixed(1).padLeft(9)}${t16.toStringAsFixed(1).padLeft(9)}'
        '${(td / t6).toStringAsFixed(2).padLeft(8)}x'
        '${(t15 / t6).toStringAsFixed(2).padLeft(8)}x'
        '${(t16 / t6).toStringAsFixed(2).padLeft(8)}x');
  }
  print('${'TOTAL'.padRight(23)}${sd.toStringAsFixed(1).padLeft(9)}'
      '${s6.toStringAsFixed(1).padLeft(9)}${s15.toStringAsFixed(1).padLeft(9)}'
      '${s16.toStringAsFixed(1).padLeft(9)}'
      '${(sd / s6).toStringAsFixed(2).padLeft(8)}x'
      '${(s15 / s6).toStringAsFixed(2).padLeft(8)}x'
      '${(s16 / s6).toStringAsFixed(2).padLeft(8)}x');
}
