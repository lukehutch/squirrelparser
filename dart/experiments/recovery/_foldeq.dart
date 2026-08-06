// _foldeq.dart -- did folding an imported engine into its caller change any
// answer?
//
// m63, m65 and cgfr1 exceed the table's 30-second cap, so their rows are `TO`
// both before and after the fold and cannot witness the change. This does:
// a fixed set of grammars and inputs, every engine's cost on each, printed as
// one line per engine. Run it before the fold, run it after, diff the output.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm63.dart' as e63;
import 'm65.dart' as e65;
import 'm66.dart' as e66;
import 'cgfr1.dart' as ecgfr1;

/// Small enough that the exponential engines finish, wide enough to reach the
/// tape: ordered choice, possessive repetition, lookahead, left recursion.
const cases = <(String, String, List<String>)>[
  ("S <- 'a'* \"ab\";\n", 'S', ['aab', 'ab', 'aaab', 'aa', 'b', '']),
  ("S <- &[a-z] [0-9m-q];\n", 'S', ['m', 'a', 'Z', '', '0']),
  ("S <- (![,] .)* ',';\n", 'S', ['abc,', 'abc', ',', 'a']),
  ("S <- '(' S ')' / 'x';\n", 'S', ['((x))', '((x)', 'x', '(', ')x']),
  ("E <- E '+' T / T;\nT <- [0-9]+;\n", 'E', ['1+22', '1+', '+1', '1++2']),
  ("S <- 'a' 'b' 'c';\n", 'S', ['abc', 'ac', 'abx', 'xbc', '']),
];

void main() {
  for (final (label, cost) in <(String, int Function(Map<String, Clause>, String, String))>[
    ('m63', (r, t, s) => e63.SuperDot3(rules: r, topRuleName: t).recoverCost(s)),
    ('m65', (r, t, s) => e65.SuperDot3(rules: r, topRuleName: t).recoverCost(s)),
    ('m66', (r, t, s) => e66.SuperDot3(rules: r, topRuleName: t).recoverCost(s)),
    ('cgfr1', (r, t, s) => ecgfr1.SuperDot3(rules: r, topRuleName: t).recoverCost(s)),
  ]) {
    final out = <String>[];
    for (final (g, top, inputs) in cases) {
      final rules = MetaGrammar.parseGrammar(g);
      for (final s in inputs) {
        try {
          out.add('${cost(rules, top, s)}');
        } catch (e) {
          out.add('E');
        }
      }
    }
    print('${label.padRight(6)} ${out.join(' ')}');
  }
}
