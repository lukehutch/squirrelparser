import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import 'r6.dart' as a;
import '_v31.dart' as b;

void show(String tag, MatchResult m, [String ind = '']) {
  final kind = m is SyntaxError ? 'ERR' : m.clause.runtimeType.toString();
  final lbl = m.clause is Ref ? (m.clause as Ref).ruleName : kind;
  print('$ind$lbl @${m.pos}+${m.len}${m is SyntaxError ? "  <<ERR" : ""}');
  for (final s in m.subClauseMatches) {
    show(tag, s, '$ind  ');
  }
}

void main() {
  final c = corpora.firstWhere((x) => x.name == 'stmt');
  final rules = MetaGrammar.parseGrammar(c.grammar);
  const input = 'if (a) { if () { c=1; } }';
  for (final e in [
    ('r6 ', a.Squirrel(rules: rules, topRuleName: c.top).recover),
    ('v31', b.Squirrel(rules: rules, topRuleName: c.top).recover)
  ]) {
    print('=== ${e.$1} on "$input"');
    try {
      final r = e.$2(input);
      show(e.$1, r);
      print('  skeleton: ${skeleton(r, c.named).join(" ")}');
    } catch (x) {
      print('  crash $x');
    }
    print('');
  }
}
