// Scratch: what does I4's static fusion still BUY, once I7 carries the same
// constraint at run time? The four gates cannot tell the two configurations
// apart -- every cost, every witness, every brute-force verdict is identical --
// so the only thing left to measure is work: `lastSteps`, the number of
// `_compute` calls, on the grammars where `_fuseLookaheads` actually fires.
//
// Run once with the fusion line live and once with it commented out, and diff.
import 'package:squirrel_parser/squirrel_parser.dart';
import '_m49nofuse.dart' as g49;

const cases = <(String, String, List<String>)>[
  // I4's home turf: the lookahead's reader is the very next terminal.
  ('!\'"\' . (fusable)', "S <- '\"' (!'\"' .)* '\"';\n", ['"x"', 'x', '"x', '']),
  ('[^\"] (already a class)', "S <- '\"' [^\"]* '\"';\n", ['"x"', 'x', '"x', '']),
  ('two lookaheads, one reader', "S <- (&[a-z] !'q' .)* ;\n", ['ab', 'q', '']),
  // Not fusable: the reader is behind a name, or there is no reader at all.
  ('reader behind a name', "S <- !'x' A;\nA <- 'a'?;\n", ['', 'a', 'x', 'ax']),
  (
    'keyword boundary',
    "S <- Kw Rest;\nKw <- \"if\" !Alpha;\nRest <- ' ' Alpha;\nAlpha <- [a-z];\n",
    ['if a', 'ifa', 'if ', 'iff a'],
  ),
];

void main() {
  var totalSteps = 0;
  for (final (title, grammar, inputs) in cases) {
    final rules = MetaGrammar.parseGrammar(grammar);
    print('\n$title   ${grammar.replaceAll('\n', ' ')}');
    for (final s in inputs) {
      final e = g49.SuperDot3(rules: rules, topRuleName: 'S');
      final cost = e.recoverCost(s);
      totalSteps += e.lastSteps;
      print('  ${(s.isEmpty ? '<empty>' : s).padRight(9)}'
          'cost=${cost.toString().padLeft(3)}  steps=${e.lastSteps}');
    }
  }
  print('\nTOTAL STEPS: $totalSteps');
}
