import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import 'c4.dart' as c4;
import 's1.dart' as s1;

void main() {
  c4.Squirrel.spyOn = true;
  for (final (g0, doc) in [
    ('expr', '1*(2+*(4-5))'),
  ]) {
    final g = corpora.firstWhere((x) => x.name == g0);
    final gr = MetaGrammar.parseGrammar(g.grammar);
    final e4 = c4.Squirrel(rules: gr, topRuleName: g.top);
    final t4 = e4.recover(doc);
    final e1 = s1.Squirrel(rules: gr, topRuleName: g.top);
    final t1 = e1.recover(doc);
    print('doc "$doc"');
    print('  c4 cost=${e4.lastCost} ${skeleton(t4, g.named).join(' ')}');
    print('  s1 cost=${e1.lastCost} ${skeleton(t1, g.named).join(' ')}');
  }
}
