// _star71.dart -- what route does m71 still find on an EMPTY language?
//
// I27 changed `'a'* "ab"` on "aab" from 0 to 3, not to -1. A cost of 3 means
// the search believes a repair exists, so either the stop obligation is being
// discharged somewhere it should not be, or the star is not the only leak.
// This prints what the engine actually answers, and whether its OWN witness
// check (I5) accepts the answer it returns.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'm62.dart' as e62;
import 'm71.dart' as e71;

final cases = <(String, String, String)>[
  ("S <- 'a'* \"ab\";\n", 'S', 'aab'),
  ("S <- 'a'* \"ab\";\n", 'S', 'aaaab'),
  ("S <- 'a'* \"ab\";\n", 'S', 'b'),
  ("S <- 'a'* \"ab\";\n", 'S', ''),
  ("S <- 'a'* 'b';\n", 'S', 'aab'), // NON-empty language, must still work
  ("S <- [0-9]* 'x';\n", 'S', '12x'), // non-empty, star then disjoint terminal
];

void main() {
  print('grammar / input        m62cost  m71cost  m71verified  spans');
  for (final (g, top, s) in cases) {
    final rules = MetaGrammar.parseGrammar(g);
    final c62 = e62.SuperDot3(rules: rules, topRuleName: top).recoverCost(s);
    final c71 = e71.SuperDot3(rules: rules, topRuleName: top).recoverCost(s);
    final e = e71.SuperDot3(rules: rules, topRuleName: top);
    final r = e.recover(s);
    print('${g.trim().padRight(22)} "$s"'.padRight(40) +
        '${c62.toString().padLeft(4)}'
            '${c71.toString().padLeft(9)}'
            '${e.lastVerified.toString().padLeft(13)}'
            '   events=${r.recoveryEvents} spans=${r.errorSpans.length} forced=${r.forced}');
  }
}
