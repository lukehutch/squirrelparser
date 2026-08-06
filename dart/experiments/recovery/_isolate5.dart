import 'dart:io';
import 'package:squirrel_parser/squirrel_parser.dart';
import 'cgfr5.dart' as t5;
void main(List<String> args) {
  final cases = <(String, String)>[
    ('S <- &[a-z] [0-9m-q];\n', ''),
    ('S <- ![a-l] [a-z];\n', ''),
    ('S <- &[a-c] [x-z];\n', ''),
    ("S <- 'a'* \"ab\";\n", 'aab'),
    ("S <- ('a' / \"ab\") 'b';\n", 'abb'),
  ];
  final (g, x) = cases[int.parse(args[0])];
  final r = MetaGrammar.parseGrammar(g);
  final e = t5.SuperDot3(rules: r, topRuleName: 'S');
  stderr.writeln('grammar ${g.trim()} input "$x"');
  stderr.writeln('  wideG=${e.debugWide} reps=${e.debugReps.length} '
      'massG=${e.debugMass}');
  final sw = Stopwatch()..start();
  stderr.writeln('  relaxed("")=${e.debugRelaxedCost('')} @${sw.elapsedMilliseconds}ms');
  final c = e.recoverCost(x);
  stderr.writeln('  cost=$c horizon=${e.lastHorizon} steps=${e.lastSteps} '
      '@${sw.elapsedMilliseconds}ms');
}
