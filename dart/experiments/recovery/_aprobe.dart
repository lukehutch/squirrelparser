// _aprobe.dart -- which corpus/category is pathological? Time each case and
// report the worst, printing as it goes so a hang is visible.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'm80.dart' as e80;

void main() {
  final cases = weighted(buildBattery());
  final byCorpus = <String, Corpus>{for (final c in corpora) c.name: c};
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final tot = <String, int>{}, n = <String, int>{};
  final worst = <(int, String, String)>[];
  for (final k in cases) {
    final c = byCorpus[k.grammar]!;
    final eng = e80.SuperDot3(rules: rulesOf[k.grammar]!, topRuleName: c.top);
    final sw = Stopwatch()..start();
    try {
      eng.recover(k.mutant);
    } catch (e) {
      print('THREW ${k.grammar} ${k.category}: ${k.mutant}  ($e)');
    }
    sw.stop();
    final us = sw.elapsedMicroseconds;
    tot[k.grammar] = (tot[k.grammar] ?? 0) + us;
    n[k.grammar] = (n[k.grammar] ?? 0) + 1;
    worst.add((us, k.grammar, k.mutant));
    if (us > 2000000) print('SLOW ${us ~/ 1000} ms  ${k.grammar}  ${k.mutant}');
  }
  for (final g in tot.keys) {
    print('$g: ${n[g]} cases, ${tot[g]! / 1000} ms total, '
        '${(tot[g]! / n[g]! / 1000).toStringAsFixed(2)} ms mean');
  }
  worst.sort((a, b) => b.$1.compareTo(a.$1));
  print('worst 10:');
  for (final w in worst.take(10)) {
    print('  ${(w.$1 / 1000).toStringAsFixed(1).padLeft(9)} ms  ${w.$2}  ${w.$3}');
  }
}
