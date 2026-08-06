// Scratch: r4 vs the final candidate, alternating on one clock, 7 rounds.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'r4.dart' as a;
import '_u11b.dart' as b;

void main() {
  final cases = weighted(buildBattery());
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final ta = <int>[], tb = <int>[];
  for (var round = 0; round < 7; round++) {
    for (final name in ['r4', 'u11b']) {
      final made = <String, MatchResult Function(String)>{
        for (final c in corpora)
          c.name: name == 'r4'
              ? a.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top).recover
              : b.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top).recover
      };
      final sw = Stopwatch()..start();
      for (final k in cases) {
        try {
          made[k.grammar]!(k.mutant);
        } catch (_) {}
      }
      sw.stop();
      (name == 'r4' ? ta : tb).add(sw.elapsedMilliseconds);
    }
  }
  int med(List<int> v) {
    final s = [...v]..sort();
    return s[s.length ~/ 2];
  }

  print('r4    ${ta.join(' ')}   median ${med(ta)}');
  print('u11b  ${tb.join(' ')}   median ${med(tb)}');
  print('u11b / r4 = ${(med(tb) / med(ta)).toStringAsFixed(3)}  '
      '(${((med(tb) / med(ta) - 1) * 100).toStringAsFixed(1)}%)');
}
