// The battery cannot see the flat-terminal pricing, because in all three of its
// grammars the `First` holding a multi-character literal always has a cheaper
// arm. This builds the grammar where it DOES decide, and asks both engines.
//
//   S <- A / B ;   A <- 'return' 'x' ;   B <- 'q' 'x' ;
//
// On input `x`, both arms need a fill. Flat pricing: A costs 1+1=2 and B costs
// 1+1=2, they tie, and the earlier arm wins -- so the engine invents the six
// characters of `return` at the price of two. Priced by length: A costs 6+1=7
// and B costs 1+1=2, so B wins and the engine invents one character.
import 'package:squirrel_parser/squirrel_parser.dart';

import '_r9len.dart' as len;
import 'r9.dart' as flat;

const g = 'S <- A / B;\nA <- "return" \'x\';\nB <- \'q\' \'x\';\n';

void main() {
  final rules = MetaGrammar.parseGrammar(g);
  for (final s in ['x', 'returnx', 'qx']) {
    final a = flat.Squirrel(rules: rules, topRuleName: 'S').recover(s);
    final b = len.Squirrel(rules: rules, topRuleName: 'S').recover(s);
    print('=== "$s"');
    print('  flat: ${a.toPrettyString(s).replaceAll('\n', '\n        ')}');
    print('  len : ${b.toPrettyString(s).replaceAll('\n', '\n        ')}');
  }
}
