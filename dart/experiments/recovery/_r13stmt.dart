import 'package:squirrel_parser/squirrel_parser.dart' as sp;
import 'astdiff.dart';
import 'r13.dart' as r13;

void main() {
  final c = corpora.firstWhere((c) => c.name == 'stmt');
  print(c.grammar);
  final rules = sp.MetaGrammar.parseGrammar(c.grammar);
  final e = r13.Squirrel(rules: rules, topRuleName: c.top).recover;
  for (final s in ['x="a', 'if (a', 'x=1;']) {
    print('=== "$s"');
    try {
      print(e(s).toPrettyString(s));
    } catch (err) {
      print('THREW $err');
    }
  }
}
