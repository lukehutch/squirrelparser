import 'package:squirrel_parser/squirrel_parser.dart';

import '_r1b.dart' as r1b;
import 'r1.dart' as r1;
import 'astdiff.dart';

void main() {
  final c = corpora.firstWhere((c) => c.name == 'expr');
  final rules = MetaGrammar.parseGrammar(c.grammar);
  const doc = '1*(2+3*(4-5))';
  final want = Parser(rules: rules, topRuleName: c.top, input: doc).parse().root;
  final a = r1.Squirrel(rules: rules, topRuleName: c.top).recover(doc);
  final b = r1b.Squirrel(rules: rules, topRuleName: c.top).recover(doc);
  print('frozen: ${skeleton(want, c.named)}');
  print('r1    : ${skeleton(a, c.named)}');
  print('r1b   : ${skeleton(b, c.named)}');
  print('');
  print('r1  == frozen: ${skeleton(a, c.named) == skeleton(want, c.named)}');
  print('r1b == frozen: ${skeleton(b, c.named) == skeleton(want, c.named)}');
}
