import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import 'r1.dart';
void main(List<String> a) {
  final c = corpora.firstWhere((x) => x.name == a[0]);
  final e = Squirrel(rules: MetaGrammar.parseGrammar(c.grammar), topRuleName: c.top);
  final m = e.recover(a[1]);
  print('cost=${e.lastCost} len=${m.len}/${a[1].length}');
  print(m.toPrettyString(a[1]));
}
