import 'package:squirrel_parser/squirrel_parser.dart';

import '_codexr4_fixpeg2.dart' as engine;

void main() {
  for (final (name, grammar, input) in <(String, String, String)>[
    ('possessive', 'S <- \'a\'* "ab";', 'aab'),
    ('committed', 'S <- (\'a\' / "ab") \'b\';', 'abb'),
    ('nested', 'S <- A \'c\';\nA <- \'a\' / "ab";', 'abc'),
  ]) {
    final rules = MetaGrammar.parseGrammar(grammar);
    final e = engine.Squirrel(rules: rules, topRuleName: 'S');
    final root = e.recover(input);
    final marks = <String>[];
    void walk(MatchResult m) {
      if (m is SyntaxError) marks.add('${m.pos}:${m.len}');
      m.subClauseMatches.forEach(walk);
    }
    walk(root);
    print('$name ${e.lastCost} marks=${marks.join(',')}');
  }
}
