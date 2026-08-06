// Same probe as _i81cost, against the fixed variant.
import 'package:squirrel_parser/squirrel_parser.dart';

import '_r1b.dart' as r1b;
import 'm132.dart' as m132;
import 'r1.dart' as r1;

const g = '''
Pair  <- Key ':' Value;
Key   <- [a-z]+;
Value <- [0-9]+;
''';

int errs(MatchResult m) {
  var n = m is SyntaxError ? 1 : 0;
  for (final k in m.subClauseMatches) {
    n += errs(k);
  }
  return n;
}

void main() {
  final rules = MetaGrammar.parseGrammar(g);
  final pure = (String s) =>
      !Parser(rules: rules, topRuleName: 'Pair', input: s)
          .parse()
          .hasSyntaxErrors;
  for (final s in const ['x:', 'x:5', 'x', 'x:q', '']) {
    final a = m132.SuperDot3(rules: rules, topRuleName: 'Pair');
    final b = r1.Squirrel(rules: rules, topRuleName: 'Pair');
    final c = r1b.Squirrel(rules: rules, topRuleName: 'Pair');
    final ta = a.recover(s), tb = b.recover(s), tc = c.recover(s);
    print('${'"$s"'.padRight(6)} PEG=${pure(s) ? 'accepts' : 'REJECTS'}  '
        'm132 cost=${a.recoverCost(s)} err=${errs(ta)} | '
        'r1 cost=${b.lastCost} err=${errs(tb)} | '
        'r1b cost=${c.lastCost} err=${errs(tc)}');
  }
  print('');
  print('--- r1b tree for "x:" ---');
  print(r1b.Squirrel(rules: rules, topRuleName: 'Pair')
      .recover('x:')
      .toPrettyString('x:'));
}
