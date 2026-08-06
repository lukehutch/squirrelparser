import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import 'c1.dart' as c1;
import 'c2.dart' as c2;

void main() {
  final g = corpora.firstWhere((x) => x.name == 'json');
  final gr = MetaGrammar.parseGrammar(g.grammar);
  const doc = '{"n":[0,-7,1.5,2e3],zt":[true,false,null]}';
  final e1 = c1.Squirrel(rules: gr, topRuleName: g.top);
  final t1 = e1.recover(doc);
  print('c1 cost=${e1.lastCost} ${skeleton(t1, g.named).join(' ')}');
  final e2 = c2.Squirrel(rules: gr, topRuleName: g.top);
  final t2 = e2.recover(doc);
  print('c2 cost=${e2.lastCost} ${skeleton(t2, g.named).join(' ')}');
  void walk(MatchResult k, int d) {
    if (k is SyntaxError) print('${'.' * d}ERR@${k.pos}+${k.len}');
    if (k.clause is Ref) {
      print('${'.' * d}${(k.clause as Ref).ruleName} pos=${k.pos} len=${k.len}');
    }
    for (final c in k.subClauseMatches) {
      walk(c, d + 1);
    }
  }
  walk(t2, 0);
}
