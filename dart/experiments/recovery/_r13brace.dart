import 'package:squirrel_parser/squirrel_parser.dart' as sp;
import 'astdiff.dart';
import 'r13.dart' as r13;
import 'r7.dart' as r7;

void main() {
  final c = corpora.firstWhere((c) => c.name == 'json');
  print(c.grammar);
  final rules = sp.MetaGrammar.parseGrammar(c.grammar);
  for (final s in ['{', '[', '[1']) {
    for (final e in [
      ('r13', r13.Squirrel(rules: rules, topRuleName: c.top).recover),
      ('r7', r7.Squirrel(rules: rules, topRuleName: c.top).recover),
    ]) {
      print('=== ${e.$1} on "$s"');
      try {
        print(e.$2(s).toPrettyString(s));
      } catch (err) {
        print('THREW $err');
      }
    }
  }
}
