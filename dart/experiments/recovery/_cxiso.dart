// Scratch: WHICH of the chart changes moves Codex's #5 case off r5's answer?
import 'package:squirrel_parser/squirrel_parser.dart';

import 'r5.dart' as r5;
import '_v1.dart' as v1;
import '_v2.dart' as v2;
import '_v3.dart' as v3;
import '_v4.dart' as v4;
import '_v5.dart' as v5;

String show(MatchResult m) {
  final b = StringBuffer('${m.clause}@${m.pos}+${m.len}');
  if (m.subClauseMatches.isNotEmpty) {
    b.write('{');
    for (final k in m.subClauseMatches) {
      b.write('${show(k)} ');
    }
    b.write('}');
  }
  return b.toString();
}

void main() {
  const g = "S <- ((. 'b') / [ab])*;";
  const s = 'abc';
  final rules = MetaGrammar.parseGrammar(g);
  final pure = Parser(rules: rules, topRuleName: 'S', input: s).parse();
  print('pure prefix: ${show(pure.root)}\n');
  final es = <String, dynamic>{
    'r5': r5.Squirrel(rules: rules, topRuleName: 'S'),
    'v1-ref-noprune': v1.Squirrel(rules: rules, topRuleName: 'S'),
    'v2-afford-prefix': v2.Squirrel(rules: rules, topRuleName: 'S'),
    'v3-seq-break': v3.Squirrel(rules: rules, topRuleName: 'S'),
    'v4-rep-preprune': v4.Squirrel(rules: rules, topRuleName: 'S'),
    'v5-rep-worklist': v5.Squirrel(rules: rules, topRuleName: 'S'),
  };
  String? base;
  for (final e in es.entries) {
    final t = show(e.value.recover(s) as MatchResult);
    base ??= t;
    print('${e.key.padRight(18)} ${t == base ? "= r5     " : "DIFFERS  "} $t');
  }
}
