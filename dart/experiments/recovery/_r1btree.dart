import 'package:squirrel_parser/squirrel_parser.dart';
import '_r1b.dart' as r1b;
import 'm132.dart' as m132;

const g = '''
Pair  <- Key ':' Value;
Key   <- [a-z]+;
Value <- [0-9]+;
''';

void main() {
  final rules = MetaGrammar.parseGrammar(g);
  const s = 'x:q';
  print('--- r1b "$s" ---');
  print(r1b.Squirrel(rules: rules, topRuleName: 'Pair')
      .recover(s)
      .toPrettyString(s));
  print('--- m132 "$s" ---');
  print(m132.SuperDot3(rules: rules, topRuleName: 'Pair')
      .recover(s)
      .toPrettyString(s));
}
