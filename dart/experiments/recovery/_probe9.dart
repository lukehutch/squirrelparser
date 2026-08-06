// Scratch: r9 tree + cost on one case, with the ORACLE tree beside it, so a
// disagreement can be read as two competing readings rather than one bad one.
//
//   dart run _probe9.dart <corpusName> <input>

import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import 'r9.dart' as b;

void show(MatchResult m, [String ind = '']) {
  final lbl = m is SyntaxError
      ? 'ERR'
      : (m.clause is Ref
          ? (m.clause as Ref).ruleName
          : m.clause.runtimeType.toString());
  print('$ind$lbl @${m.pos}+${m.len}');
  for (final s in m.subClauseMatches) {
    show(s, '$ind  ');
  }
}

void main(List<String> argv) {
  final name = argv.isEmpty ? 'json' : argv[0];
  final input = argv.length > 1 ? argv[1] : '[{"x';
  final c = corpora.firstWhere((x) => x.name == name);
  final rules = MetaGrammar.parseGrammar(c.grammar);
  print('grammar: ${c.grammar}\n');
  final eng = b.Squirrel(rules: rules, topRuleName: c.top);
  print('=== r9 on "$input"  (${input.length} chars)');
  final r = eng.recover(input);
  show(r);
  print('skeleton: ${skeleton(r, c.named).join(" ")}');
  print('cost:     ${eng.recoverCost(input)}');
}
