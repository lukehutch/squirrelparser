import 'package:squirrel_parser/squirrel_parser.dart';

import 'r5.dart' as r5;
import '_v4.dart' as v4;
import '_v5.dart' as v5;
import '_v13.dart' as v13;
import '_v14.dart' as v14;
import '_codex_audit26_safe.dart' as safe;
import '_codex_audit26_deferred.dart' as lazy;

String ser(MatchResult m) {
  final out = StringBuffer();
  void walk(MatchResult n) {
    out.write('${n.runtimeType}{${n.clause}@${n.pos}+${n.len}');
    for (final child in n.subClauseMatches) {
      out.write(',');
      walk(child);
    }
    out.write('}');
  }

  walk(m);
  return out.toString();
}

void compare(String name, String grammar, String input,
    Map<String, dynamic Function(Map<String, Clause>)> makes) {
  final rules = MetaGrammar.parseGrammar(grammar);
  final engines = {for (final e in makes.entries) e.key: e.value(rules)};
  print('case=$name');
  print('grammar=$grammar');
  print('input=$input');
  for (final entry in engines.entries) {
    final tree = entry.value.recover(input) as MatchResult;
    print('${entry.key}: cost=${entry.value.lastCost} tree=${ser(tree)}');
  }
  print('');
}

void main() {
  compare('claim-5 nonmonotone repetition', "S <- ((. 'b') / [ab])*;", 'abc', {
    'r5': (r) => r5.Squirrel(rules: r, topRuleName: 'S'),
    'v4-preprune': (r) => v4.Squirrel(rules: r, topRuleName: 'S'),
    'v5-worklist': (r) => v5.Squirrel(rules: r, topRuleName: 'S'),
    'v13': (r) => v13.Squirrel(rules: r, topRuleName: 'S'),
    'safe2': (r) => safe.Squirrel(rules: r, topRuleName: 'S'),
    'deferred': (r) => lazy.Squirrel(rules: r, topRuleName: 'S'),
  });
  compare('claim-8 exact fixed point', 'S <- A; A <- A \'a\' / "ab"*;', 'baa', {
    'r5': (r) => r5.Squirrel(rules: r, topRuleName: 'S'),
    'v14-improved-only': (r) => v14.Squirrel(rules: r, topRuleName: 'S'),
    'v13': (r) => v13.Squirrel(rules: r, topRuleName: 'S'),
    'safe2': (r) => safe.Squirrel(rules: r, topRuleName: 'S'),
    'deferred': (r) => lazy.Squirrel(rules: r, topRuleName: 'S'),
  });
}
