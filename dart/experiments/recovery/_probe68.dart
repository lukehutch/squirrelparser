import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import 'r6.dart' as a6;
import 'r8.dart' as a8;
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
  for (final e in [('r6', a6.Squirrel(rules: rules, topRuleName: c.top).recover),
                   ('r8', a8.Squirrel(rules: rules, topRuleName: c.top).recover)]) {
    print('=== ${e.$1} on "$input"');
    final r = e.$2(input);
    show(r);
    print('skeleton: ${skeleton(r, c.named).join(" ")}\n');
  }
}
