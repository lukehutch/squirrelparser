import 'package:squirrel_parser/squirrel_parser.dart' as sp;
import 'r10.dart' as r10;
import 'astdiff.dart';

void main() {
  final c = corpora.firstWhere((c) => c.name == 'json');
  final rules = sp.MetaGrammar.parseGrammar(c.grammar);
  final eng = r10.Squirrel(rules: rules, topRuleName: c.top);
  final doc = c.documents.first;
  for (final s in [doc, doc.replaceFirst(':', ''), doc.replaceFirst('"a"', '"a'),
                   'X$doc', doc.substring(0, doc.length - 6)]) {
    print('=== "$s"');
    try {
      final t = eng.recover(s);
      print(t.toPrettyString(s));
    } catch (e) { print('THREW $e'); }
  }
}
