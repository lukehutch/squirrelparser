import 'dart:io';
import 'package:squirrel_parser/squirrel_parser.dart';
import 'cgfr5.dart' as t5;
void main(List<String> args) {
  final cases = <(String, String)>[
    ('S <- [a-z];\n', ''),          // 0: no lookahead, empty input
    ('S <- [a-z];\n', 'Q'),         // 1: no lookahead, non-empty
    ('S <- &[a-z] [a-z];\n', 'a'),  // 2: lookahead, non-empty, already valid
    ('S <- &[a-z] [a-z];\n', 'Q'),  // 3: lookahead, non-empty, invalid
    ('S <- &[a-z] [a-z];\n', ''),   // 4: lookahead, empty input
    ('S <- ![a-l] [a-z];\n', 'Q'),  // 5: negative lookahead, non-empty
  ];
  final (g, x) = cases[int.parse(args[0])];
  final r = MetaGrammar.parseGrammar(g);
  final e = t5.SuperDot3(rules: r, topRuleName: 'S');
  stderr.writeln('${g.trim()}  input "$x"');
  final sw = Stopwatch()..start();
  final c = e.recoverCost(x);
  stderr.writeln('  cost=$c wide=${e.debugWide} reps=${e.debugReps.length} '
      'horizon=${e.lastHorizon} @${sw.elapsedMilliseconds}ms');
}
