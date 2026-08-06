import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import 'r8.dart' as b;
void show(MatchResult m, [String ind = '']) {
  final lbl = m is SyntaxError
      ? 'ERR'
      : (m.clause is Ref ? (m.clause as Ref).ruleName : m.clause.runtimeType.toString());
  print('$ind$lbl @${m.pos}+${m.len}');
  for (final s in m.subClauseMatches) show(s, '$ind  ');
}
void main(List<String> argv) {
  final name = argv.isEmpty ? 'stmt' : argv[0];
  final input = argv.length > 1 ? argv[1] : '{ a';
  final c = corpora.firstWhere((x) => x.name == name);
  final rules = MetaGrammar.parseGrammar(c.grammar);
  print('grammar: ${c.grammar}\n');
  print('=== r8 on "$input"');
  final r = b.Squirrel(rules: rules, topRuleName: c.top).recover(input);
  show(r);
  print('skeleton: ${skeleton(r, c.named).join(" ")}');
}
