// _r3zw.dart -- WHICH rules does r3 grant at zero width?
//
// `_accept` case cx2 requires a zero-width named node (`A <- [ab]` filled must
// beat every deletion), while the brief forbids inventing a construct whose
// SHAPE the grammar does not fix. `_zerowidth` counts both alike, so the
// question it cannot answer is which kind these are.
import 'package:squirrel_parser/squirrel_parser.dart';

import '_score1.dart' show resolve;
import 'astdiff.dart';

void main(List<String> argv) {
  final name = argv.isEmpty ? 'r3' : argv[0];
  final build = resolve(name)!;
  final rulesOf = {
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final made = {
    for (final c in corpora) c.name: build(rulesOf[c.name]!, c.top)
  };
  final hits = <String, int>{};
  for (final k in weighted(buildBattery())) {
    final c = corpora.firstWhere((x) => x.name == k.grammar);
    MatchResult? m;
    try {
      m = made[k.grammar]!(k.mutant);
    } catch (_) {
      continue;
    }
    void walk(MatchResult x) {
      final cl = x.clause;
      if (cl is Ref && c.named.contains(cl.ruleName) && x.len == 0) {
        hits['${k.grammar}.${cl.ruleName}'] =
            (hits['${k.grammar}.${cl.ruleName}'] ?? 0) + 1;
      }
      x.subClauseMatches.forEach(walk);
    }

    walk(m!);
  }
  final keys = hits.keys.toList()..sort((a, b) => hits[b]!.compareTo(hits[a]!));
  print('$name zero-width named nodes by rule:');
  for (final r in keys) {
    print('  ${r.padRight(14)} ${hits[r]}');
  }
  print('  total ${hits.values.fold(0, (a, b) => a + b)}');
}
