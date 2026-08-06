import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import 'c1.dart' as c1;
import 'c3.dart' as c3;

void main() {
  final g = corpora.firstWhere((x) => x.name == 'expr');
  final gr = MetaGrammar.parseGrammar(g.grammar);
  c3.Squirrel.spyOn = true;
  for (final doc in ['1*']) {
    final e1 = c1.Squirrel(rules: gr, topRuleName: g.top);
    final t1 = e1.recover(doc);
    final e3 = c3.Squirrel(rules: gr, topRuleName: g.top);
    final t3 = e3.recover(doc);
    print('doc "$doc"');
    print('  c1 cost=${e1.lastCost} ${skeleton(t1, g.named).join(' ')}');
    print('  c3 cost=${e3.lastCost} ${skeleton(t3, g.named).join(' ')}');
  }
}
