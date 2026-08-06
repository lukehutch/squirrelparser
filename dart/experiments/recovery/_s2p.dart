import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import 's2.dart' as s2;

void main() {
  final j = corpora.firstWhere((x) => x.name == 'json');
  final jr = MetaGrammar.parseGrammar(j.grammar);
  const s = '{"n":[0,-7,1.5,2e],t":[true,false,null]}';
  final e = s2.Squirrel(rules: jr, topRuleName: j.top);
  final r = e.recover(s);
  print('cost=${e.lastCost}');
  print(r.toPrettyString(s));
}
