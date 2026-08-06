import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import 'c1.dart' as c1;

void main() {
  final g = corpora.firstWhere((x) => x.name == 'stmt');
  final gr = MetaGrammar.parseGrammar(g.grammar);
  c1.Squirrel.debug = true;
  final e1 = c1.Squirrel(rules: gr, topRuleName: g.top);
  final t1 = e1.recover('x="ab"; y="cz; { z="de"; }');
  print('cost=${e1.lastCost} ${skeleton(t1, g.named).join(' ')}');
}
