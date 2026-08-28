// Scratch: two-engine A/B of the CLEAN paths only (bit-identical code there).
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '../../experiments/recovery/c12.dart' as c12x;
import '../../experiments/recovery/c13.dart' as c13x;

void main() {
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  Map<String, MatchResult? Function(String)> c12() =>
      <String, MatchResult? Function(String)>{
        for (final c in corpora)
          c.name:
              c12x.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top).recover
      };
  Map<String, MatchResult? Function(String)> c13() =>
      <String, MatchResult? Function(String)>{
        for (final c in corpora)
          c.name:
              c13x.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top).recover
      };

  final a = c12(), b = c13();
  final clean = <(String, String)>[
    for (final c in corpora)
      for (final d in c.documents) (c.name, d)
  ];
  int run(Map<String, MatchResult? Function(String)> eng, int reps) {
    final sw = Stopwatch()..start();
    for (var r = 0; r < reps; r++) {
      for (final (g, s) in clean) {
        eng[g]!(s);
      }
    }
    return sw.elapsedMicroseconds;
  }

  for (var w = 0; w < 5; w++) {
    run(a, 5);
    run(b, 5);
  }
  final ta = <int>[], tb = <int>[];
  for (var r = 0; r < 31; r++) {
    ta.add(run(a, 20));
    tb.add(run(b, 20));
  }
  int med(List<int> xs) {
    final s = [...xs]..sort();
    return s[s.length ~/ 2];
  }

  print('clean c12=${med(ta)}us c13=${med(tb)}us '
      'c13/c12=${(med(tb) / med(ta)).toStringAsFixed(3)}');
}
