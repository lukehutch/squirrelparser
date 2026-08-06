// Does r1 survive a repair INSIDE a left-recursive cycle?
//
// `_memoized` expands left recursion in the frame that entered the cycle, but
// the frontier walk and the salvage are outside that mechanism: both reach
// `Expr` at the same position from `Expr`'s own first subclause, and without a
// cycle guard neither terminates. 76 of the battery's expr cases died of exactly
// that. This checks the repaired trees, not just that nothing threw.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'r2.dart';

const lr = '''
Expr <- Expr WS AddOp WS Term / Term;
Term <- Term WS MulOp WS Factor / Factor;
Factor <- Num / '(' WS Expr WS ')' / Name;
AddOp <- '+' / '-';
MulOp <- '*' / '/';
Num <- [0-9]+;
Name <- [a-z]+;
~WS <- [ \\t\\n]*;
''';

/// Directly left-recursive with the damage in the LEFT operand, so the repair
/// must be visible to the frame that entered the cycle.
const cases = <String>[
  '1+2+3', // clean: must cost 0
  '1+@+3', // junk inside the growing left operand
  '1@+2+3', // junk in the innermost seed
  '1+2+@', // junk in the last right operand
  '((1+2)', // unbalanced, deep
  '1++2', // doubled operator
  'a*b+@*c', // damage under the second level of recursion
];

int depth(MatchResult m) {
  var d = 0;
  for (final k in m.subClauseMatches) {
    final x = depth(k);
    if (x > d) d = x;
  }
  return d + 1;
}

void main() {
  final rules = MetaGrammar.parseGrammar(lr);
  for (final s in cases) {
    final e = Squirrel(rules: rules, topRuleName: 'Expr');
    final sw = Stopwatch()..start();
    try {
      final m = e.recover(s);
      sw.stop();
      final covers = m.pos == 0 && m.len == s.length;
      print('${s.padRight(9)} cost=${e.lastCost}  depth=${depth(m)}  '
          '${covers ? 'covers' : 'COVERS ONLY ${m.pos}..${m.pos + m.len}'}  '
          '${sw.elapsedMicroseconds}us');
    } catch (x) {
      print('${s.padRight(9)} THREW ${x.runtimeType}');
    }
  }
}
