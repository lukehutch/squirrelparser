// Both trees side by side: committed r9 (`_r9base.dart`) and the working tree.
// Usage: dart run _swpair.dart <corpus> <input>...
import 'package:squirrel_parser/squirrel_parser.dart';

import '_r9base.dart' as base;
import 'astdiff.dart';
import 'r9.dart' as cand;

void main(List<String> argv) {
  final c = corpora.firstWhere((k) => k.name == argv[0]);
  final rules = MetaGrammar.parseGrammar(c.grammar);
  final eb = base.Squirrel(rules: rules, topRuleName: c.top);
  final ec = cand.Squirrel(rules: rules, topRuleName: c.top);
  for (final s in argv.sublist(1)) {
    final a = eb.recover(s), b = ec.recover(s);
    print('======== "$s"');
    print('-- BASE  cost ${eb.lastCost}');
    print(a.toPrettyString(s));
    print('-- CAND  cost ${ec.lastCost}');
    print(b.toPrettyString(s));
  }
}
