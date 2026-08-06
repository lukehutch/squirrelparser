import 'package:squirrel_parser/squirrel_parser.dart';

import 'm132.dart' as m132;
import 'm143.dart' as m143;
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
  for (final s in const ['x:', 'x:5', 'x', 'x:q']) {
    final a = m132.SuperDot3(rules: rules, topRuleName: 'Pair');
    final b = m143.SuperDot3(rules: rules, topRuleName: 'Pair');
    final c = r1.Squirrel(rules: rules, topRuleName: 'Pair');
    final ta = a.recover(s), tb = b.recover(s), tc = c.recover(s);
    print('${s.padRight(5)} '
        'm132 cost=${a.recoverCost(s)} errNodes=${errs(ta)} '
        'span=${ta.pos}+${ta.len} | '
        'm143 cost=${b.recoverCost(s)} errNodes=${errs(tb)} '
        'span=${tb.pos}+${tb.len} | '
        'r1 cost=${c.lastCost} errNodes=${errs(tc)} span=${tc.pos}+${tc.len}');
  }
}
