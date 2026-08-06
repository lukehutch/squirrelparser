import 'package:squirrel_parser/squirrel_parser.dart' as sp;
import 'astdiff.dart';
import 'r13.dart' as r13;
import 'r7.dart' as r7;

void main() {
  final c = corpora.firstWhere((c) => c.name == 'expr');
  print(c.grammar);
  final rules = sp.MetaGrammar.parseGrammar(c.grammar);
  final a = r13.Squirrel(rules: rules, topRuleName: c.top).recover;
  final b = r7.Squirrel(rules: rules, topRuleName: c.top).recover;
  for (final s in ['(', '(a', 'a*']) {
    for (final e in [('r13', a), ('r7', b)]) {
      print('=== ${e.$1} "$s"');
      try {
        print(e.$2(s).toPrettyString(s));
      } catch (err) {
        print('THREW $err');
      }
    }
  }
}
