// _dom.dart -- Codex's budget-dominance probe for I77, run against the engines.
//
// THE CLAIM. `_put` keeps one way per ending, chosen by the comparison key. I77
// makes that key `cost - net` (m130/m134) or `cost + got - net` (m129/m133)
// instead of raw `cost`. But `_seq` computes the residual budget a suffix may
// spend from raw `w.cost`. So an S-winner whose RAW cost is higher can evict a
// way that was cheaper in the only currency the budget actually spends -- and
// the evicted way was the one that could still afford the rest of the parse.
//
// If that is real, an engine with I77 must report a HIGHER total cost than the
// same engine without it, on a grammar where the two disagree at a shared
// ending and the suffix then needs every unit of budget.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'm127.dart' as m127; // I76 only          -- cost is the first key
import 'm129.dart' as m129; // I76 + I77 c+g-n
import 'm130.dart' as m130; // I76 + I77 c-n
import 'm132.dart' as m132; // I76 + I78         -- cost is the first key
import 'm133.dart' as m133; // I76 + I77 c+g-n + I78
import 'm134.dart' as m134; // I76 + I77 c-n   + I78   <- the standing candidate

// C's two alternatives reach the SAME ending at position 4 with different
// (cost, got, net): E repairs one character but explains two constrained ones,
// W matches four unconstrained dots for free. Raw cost prefers W; `cost - net`
// and `cost + got - net` both prefer E. The suffix then needs three fills, so
// keeping E costs 1 + 3 and keeping W costs 0 + 3.
const g1 = '''
Top <- C 'q' 'r' 's';
C <- E / W;
E <- . 'a' 'b';
W <- . . . .;
''';

// The same shape with a longer all-fill suffix, where the budget cap can be
// overshot entirely rather than merely overspent.
const g2 = '''
Top <- C 'q' 'r' 's' 't';
C <- E / W;
E <- . 'a' 'b';
W <- . . . .;
''';

int? cost(String name, Map<String, Clause> rules, String top, String s) {
  switch (name) {
    case 'm127':
      return m127.SuperDot3(rules: rules, topRuleName: top).recoverCost(s);
    case 'm129':
      return m129.SuperDot3(rules: rules, topRuleName: top).recoverCost(s);
    case 'm130':
      return m130.SuperDot3(rules: rules, topRuleName: top).recoverCost(s);
    case 'm132':
      return m132.SuperDot3(rules: rules, topRuleName: top).recoverCost(s);
    case 'm133':
      return m133.SuperDot3(rules: rules, topRuleName: top).recoverCost(s);
    case 'm134':
      return m134.SuperDot3(rules: rules, topRuleName: top).recoverCost(s);
  }
  return null;
}

void main() {
  final probes = <(String, String, String)>[
    ('g1', g1, 'xxab'),
    ('g1', g1, 'ab'),
    ('g2', g2, 'xxab'),
    ('g2', g2, 'ab'),
  ];
  final rules = {
    'g1': MetaGrammar.parseGrammar(g1),
    'g2': MetaGrammar.parseGrammar(g2),
  };
  const engines = ['m127', 'm132', 'm129', 'm133', 'm130', 'm134'];

  print('grammar input   ${engines.map((e) => e.padLeft(5)).join()}');
  for (final (g, _, s) in probes) {
    final row = <String>[];
    for (final e in engines) {
      int? c;
      try {
        c = cost(e, rules[g]!, 'Top', s);
      } catch (_) {
        c = null;
      }
      row.add((c?.toString() ?? 'ERR').padLeft(5));
    }
    print('${g.padRight(7)} ${s.padRight(7)} ${row.join()}');
  }
  print('');
  print('cost-first engines: m127, m132     I77 engines: m129, m133, m130, m134');
}
