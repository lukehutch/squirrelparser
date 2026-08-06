import 'package:squirrel_parser/squirrel_parser.dart';

import 'r4.dart' as r4;

bool pureAccepts(Map<String, Clause> rules, String top, String input) {
  final parsed = Parser(rules: rules, topRuleName: top, input: input).parse();
  return !parsed.hasSyntaxErrors && parsed.root.len == input.length;
}

List<String> acceptedOneEdits(
    Map<String, Clause> rules, String top, String input, List<String> alphabet) {
  final candidates = <String>{};
  for (var i = 0; i < input.length; i++) {
    candidates.add(input.substring(0, i) + input.substring(i + 1));
    for (final ch in alphabet) {
      candidates.add(input.substring(0, i) + ch + input.substring(i + 1));
    }
  }
  for (var i = 0; i <= input.length; i++) {
    for (final ch in alphabet) {
      candidates.add(input.substring(0, i) + ch + input.substring(i));
    }
  }
  return candidates.where((s) => pureAccepts(rules, top, s)).toList()..sort();
}

int treeCost(MatchResult root) {
  var cost = 0;
  void walk(MatchResult node) {
    if (node is SyntaxError) cost += node.len == 0 ? 1 : node.len;
    for (final child in node.subClauseMatches) {
      walk(child);
    }
  }

  walk(root);
  return cost;
}

void dump(MatchResult node, String indent) {
  final label = node is SyntaxError
      ? (node.len == 0 ? 'FILL' : 'DELETE')
      : node.clause is Ref
          ? (node.clause as Ref).ruleName
          : node.clause.runtimeType.toString();
  print('$indent$label pos=${node.pos} len=${node.len}');
  for (final child in node.subClauseMatches) {
    dump(child, '$indent  ');
  }
}

void main() {
  final conformance = <(String, String, String)>[
    ('possessive repetition', 'S <- \'a\'* "ab";', 'aab'),
    ('committed choice', 'S <- (\'a\' / "ab") \'b\';', 'abb'),
    ('nested committed choice', 'S <- A \'c\';\nA <- \'a\' / "ab";', 'abc'),
  ];
  print('case                       pure  r4-cost');
  for (final (name, grammar, input) in conformance) {
    final rules = MetaGrammar.parseGrammar(grammar);
    final engine = r4.Squirrel(rules: rules, topRuleName: 'S');
    print('${name.padRight(27)}'
        '${(pureAccepts(rules, 'S', input) ? 'ACCEPT' : 'REJECT').padRight(6)}'
        '  ${engine.recoverCost(input)}');
  }
  final possessiveRules = MetaGrammar.parseGrammar('S <- \'a\'* "ab";');
  print('possessive one-edit PEG members='
      '${acceptedOneEdits(possessiveRules, 'S', 'aab', ['a', 'b'])}');

  for (final (label, grammar, top) in <(String, String, String)>[
    ('choice used directly as top', "S <- 'a' / 'b';", 'S'),
    ('same choice behind a Ref', "Top <- S;\nS <- 'a' / 'b';", 'Top'),
  ]) {
    final rules = MetaGrammar.parseGrammar(grammar);
    final engine = r4.Squirrel(rules: rules, topRuleName: top);
    final root = engine.recover('');
    print('\n$label on empty input: cost=${engine.lastCost}');
    dump(root, '');
  }

  final stopRules = MetaGrammar.parseGrammar("S <- 'a' 'b' 'c';");
  final stopEngine = r4.Squirrel(rules: stopRules, topRuleName: 'S');
  final root = stopEngine.recover('a');
  print('\nEOI stop for S <- a b c on `a`:');
  print('reported=${stopEngine.lastCost} tree=${treeCost(root)} '
      'marks=${root.subClauseMatches.whereType<SyntaxError>().length}');
  dump(root, '');

  final owedRules = MetaGrammar.parseGrammar('''
S <- 'a' B C;
B <- 'b' / 'x';
C <- 'c' / 'y';
''');
  final owedEngine = r4.Squirrel(rules: owedRules, topRuleName: 'S');
  final owedRoot = owedEngine.recover('a');
  print('\nEOI stop with two shape-undetermined slots on `a`:');
  print('reported=${owedEngine.lastCost} tree=${treeCost(owedRoot)}');
  print('one-edit PEG members=${acceptedOneEdits(
      owedRules, 'S', 'a', ['a', 'b', 'x', 'c', 'y'])}; '
      'two-edit witness abc=${pureAccepts(owedRules, 'S', 'abc')}');
  dump(owedRoot, '');

  final nearestRules = MetaGrammar.parseGrammar("S <- 'a'+ 'z';");
  final nearestEngine = r4.Squirrel(rules: nearestRules, topRuleName: 'S');
  final nearestRoot = nearestEngine.recover('xazaaaaaz');
  print('\nnearest full slot-0 move on `xazaaaaaz` '
      '(deleting input positions 0 and 2 yields PEG-valid `aaaaaaz`):');
  print('reported=${nearestEngine.lastCost} tree=${treeCost(nearestRoot)}');
  print('one-edit PEG members=${acceptedOneEdits(
      nearestRules, 'S', 'xazaaaaaz', ['a', 'z'])}; '
      'two-delete witness aaaaaaz='
      '${pureAccepts(nearestRules, 'S', 'aaaaaaz')}');
  dump(nearestRoot, '');

  final lrRules = MetaGrammar.parseGrammar('''
E <- E A / B;
A <- 'x' / "yz";
B <- 'q' / "qjxy";
''');
  final lrEngine = r4.Squirrel(rules: lrRules, topRuleName: 'E');
  final lrRoot = lrEngine.recover('qjxyz');
  print('\nleft-recursive intermediate ending on `qjxyz`:');
  print('reported=${lrEngine.lastCost}; delete-j witness qxyz='
      '${pureAccepts(lrRules, 'E', 'qxyz')}');
  dump(lrRoot, '');
}
