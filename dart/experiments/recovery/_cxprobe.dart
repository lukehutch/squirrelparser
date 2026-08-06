// Scratch: Codex's two counterexamples, checked against MY candidates.
//
//   dart run _cxprobe.dart
import 'package:squirrel_parser/squirrel_parser.dart';

import 'r5.dart' as r5;
import '_v13.dart' as v13;
import '_v20.dart' as v20;
import '_v23.dart' as v23;

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
  final cases = [
    ("S <- ((. 'b') / [ab])*;", 'S', 'abc', 'Codex #5 rep worklist'),
    ('S <- A; A <- A \'a\' / "ab"*;', 'S', 'baa', 'Codex #8 exact _improved'),
  ];
  for (final (g, top, input, why) in cases) {
    final rules = MetaGrammar.parseGrammar(g);
    print('--- $why\n    $g   input "$input"');
    final out = <String, String>{};
    for (final (name, f) in [
      ('r5 ', (String s) => r5.Squirrel(rules: rules, topRuleName: top)),
      ('v13', (String s) => v13.Squirrel(rules: rules, topRuleName: top)),
      ('v20', (String s) => v20.Squirrel(rules: rules, topRuleName: top)),
      ('v23', (String s) => v23.Squirrel(rules: rules, topRuleName: top)),
    ]) {
      try {
        final e = f(input);
        final m = (e as dynamic).recover(input) as MatchResult;
        out[name] = 'cost=${(e as dynamic).lastCost}  ${show(m)}';
      } catch (x) {
        out[name] = 'THREW $x';
      }
    }
    for (final k in out.keys) {
      print('  $k ${out[k] == out['r5 '] ? "= r5" : "DIFFERS"}');
    }
    for (final k in out.keys) {
      print('  $k ${out[k]}');
    }
    print('');
  }
}
