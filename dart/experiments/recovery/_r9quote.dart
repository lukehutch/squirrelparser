// Pricing a literal by its length costs one stmt case 0.9872 -> 0.3718. That is
// far too big a drop to be a preference; this looks at what the engine actually
// emits, to tell "a different reading" from "a defect the price exposed".
import 'package:squirrel_parser/squirrel_parser.dart';

import '_r9len.dart' as len; // r9 + both pricing fixes
import 'astdiff.dart';
import 'r9.dart' as flat; // r9 + the _terminal fix only

void main() {
  final c = corpora.firstWhere((k) => k.name == 'stmt');
  final rules = MetaGrammar.parseGrammar(c.grammar);
  for (final s in [
    'x=1; "f (x) { y=2; z=3; } w=4;',
    '{ a=1; { b=2; } "f (c) d=3; }',
    'if (a) { i,f (b) { c=1; } }',
  ]) {
    print('======== "$s"');
    final a = flat.Squirrel(rules: rules, topRuleName: c.top).recover(s);
    final b = len.Squirrel(rules: rules, topRuleName: c.top).recover(s);
    print('-- _terminal fix only');
    print(a.toPrettyString(s));
    print('-- both fixes');
    print(b.toPrettyString(s));
  }
}
