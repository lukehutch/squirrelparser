// Scratch: is a -1 from m47 the CEILING refusing to search, or the search
// failing? `lastSteps` is 0 in the first case and positive in the second, because
// `_steps` is zeroed just before the deepening loop.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm47.dart' as g47;

void main() {
  final cases = <(String, String, List<String>)>[
    ("S <- !'x' A;\nA <- 'x' / \"yy\";\n", 'S', ['q', 'x', 'y', '', 'xy', 'yy']),
    ("S <- !'x' A B;\nA <- 'a'?;\nB <- 'b' / 'x';\n", 'S', ['x', 'xx', 'ax']),
    ("S <- !'x' 'b';\n", 'S', ['x', 'b', '']),
    ("S <- 'a' 'b';\n", 'S', ['a', 'ab', 'q']),
  ];
  for (final (grammar, top, inputs) in cases) {
    final rules = MetaGrammar.parseGrammar(grammar);
    print('\n${grammar.replaceAll('\n', ' ')}');
    for (final s in inputs) {
      final e = g47.SuperDot3(rules: rules, topRuleName: top);
      final cost = e.recoverCost(s);
      print('  "${s}" -> cost $cost, steps ${e.lastSteps}'
          '${cost < 0 && e.lastSteps == 0 ? "   <== CEILING SAID NO" : ""}');
    }
  }
}
