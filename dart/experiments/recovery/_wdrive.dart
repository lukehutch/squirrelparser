// _wdrive.dart -- at how many DISTINCT positions does the engine actually
// generate a repair during one recover()? The windowed-hybrid design is only
// worth building if that number is large relative to the input length; if the
// `_pure` guard in `_repair` already confines the search to the damage, the
// window has nothing left to remove.
import 'package:squirrel_parser/squirrel_parser.dart';

import '_wprobe.dart';
import 'astdiff.dart';

String pct(List<num> xs, double q) {
  final s = List<num>.of(xs)..sort();
  return s[((s.length - 1) * q).round()].toStringAsFixed(1);
}

void main() {
  final rulesOf = {
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final seen = <String>{};
  final posN = <num>[], calls = <num>[], lens = <num>[], frac = <num>[],
      spread = <num>[];
  for (final k in weighted(buildBattery())) {
    if (!seen.add('${k.grammar}\x00${k.category}\x00${k.mutant}')) continue;
    final p = SuperDot3(rules: rulesOf[k.grammar]!, topRuleName: corpora
        .firstWhere((c) => c.name == k.grammar)
        .top);
    try {
      p.recover(k.mutant);
    } catch (_) {
      continue;
    }
    if (p.probePos.isEmpty) continue;
    final s = p.probePos.toList()..sort();
    posN.add(p.probePos.length);
    calls.add(p.probeCalls);
    lens.add(k.mutant.length);
    frac.add(p.probePos.length / (k.mutant.length + 1));
    spread.add(s.last - s.first + 1);
  }
  print('${posN.length} cases');
  print('                     p50    p75    p90    p95    p99    max');
  for (final (l, xs) in [
    ('input length', lens),
    ('repair POSITIONS', posN),
    ('positions/length', frac),
    ('position spread', spread),
    ('_repair calls', calls),
  ]) {
    print('${l.padRight(20)}${[0.5, 0.75, 0.9, 0.95, 0.99, 1.0].map((q) => pct(xs, q).padLeft(7)).join()}');
  }
}
