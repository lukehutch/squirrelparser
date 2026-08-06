import 'package:squirrel_parser/squirrel_parser.dart';

import '_codexr4_candidate.dart' as fixed;

String label(MatchResult node) {
  if (node is SyntaxError) return node.len == 0 ? 'FILL' : 'DELETE';
  if (node.clause is Ref) return (node.clause as Ref).ruleName;
  return node.clause.runtimeType.toString();
}

List<String> nodes(MatchResult root) {
  final out = <String>[];
  void walk(MatchResult node) {
    out.add('${label(node)}:${node.len}');
    node.subClauseMatches.forEach(walk);
  }

  walk(root);
  return out;
}

void run(String name, String grammar, String top, String input) {
  final rules = MetaGrammar.parseGrammar(grammar);
  final engine = fixed.Squirrel(rules: rules, topRuleName: top);
  final root = engine.recover(input);
  print('$name cost=${engine.lastCost} nodes=${nodes(root).join(',')}');
}

void main() {
  run('possessive', 'S <- \'a\'* "ab";', 'S', 'aab');
  run('committed', 'S <- (\'a\' / "ab") \'b\';', 'S', 'abb');
  run('nested-committed', 'S <- A \'c\';\nA <- \'a\' / "ab";', 'S', 'abc');
  run('top-choice', "S <- 'a' / 'b';", 'S', '');
  run('direct-EOI', "S <- 'a' 'b' 'c';", 'S', 'a');
  run('undetermined-EOI', '''
S <- 'a' B C;
B <- 'b' / 'x';
C <- 'c' / 'y';
''', 'S', 'a');
  run('nonproductive', 'S <- S;', 'S', '');
  run('nearest-move', "S <- 'a'+ 'z';", 'S', 'xazaaaaaz');
}
