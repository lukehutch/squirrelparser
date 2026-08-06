import 'package:squirrel_parser/squirrel_parser.dart';

import 'r4.dart' as r4;

void main() {
  final rules = MetaGrammar.parseGrammar('S <- S;');
  final pure = Parser(rules: rules, topRuleName: 'S', input: '').parse();
  print('pure returned: errors=${pure.hasSyntaxErrors} len=${pure.root.len}');
  final engine = r4.Squirrel(rules: rules, topRuleName: 'S');
  print('starting r4');
  engine.recover('');
  print('r4 returned');
}
