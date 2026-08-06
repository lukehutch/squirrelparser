// Which battery cases make r1 throw, and with what?
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'r2.dart';

void main() {
  final rulesOf = {
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final topOf = {for (final c in corpora) c.name: c.top};
  final seen = <String>{};
  final kinds = <String, int>{};
  var n = 0;
  for (final k in weighted(buildBattery())) {
    if (!seen.add('${k.grammar}\x00${k.category}\x00${k.mutant}')) continue;
    try {
      Squirrel(rules: rulesOf[k.grammar]!, topRuleName: topOf[k.grammar]!)
          .recover(k.mutant);
    } catch (x) {
      n++;
      final key = '${x.runtimeType}: $x';
      kinds[key] = (kinds[key] ?? 0) + 1;
      if (kinds[key]! <= 2) {
        print('${k.grammar} ${k.category} ${jsonish(k.mutant)}  -> $x');
      }
    }
  }
  print('');
  print('$n distinct cases throw');
  for (final e in kinds.entries) {
    print('  ${e.value}x  ${e.key}');
  }
}

String jsonish(String s) => s.length > 60 ? '${s.substring(0, 60)}...' : s;
