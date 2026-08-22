// _latsplit.dart -- paired, interleaved c9 / c10 / c12 / c13 timing, split by
// input kind: clean documents (the plain-parse path) vs the damaged
// battery cases. A blended full-battery median hides the difference --
// c10 costs 1.13x on damaged input but 2.4-2.6x on clean input, because
// the damaged battery dominates the wall clock (LESSONS_LEARNED lesson
// 21). Prints medians and each engine's ratio against c9.
//
//   dart run _latsplit.dart [rounds]
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_convert.dart';
import '../../experiments/recovery/c12.dart' as c12x;
import '../../experiments/recovery/c13.dart' as c13x;

void main(List<String> argv) {
  final rounds = argv.isEmpty ? 21 : int.parse(argv[0]);
  final cases = weighted(buildBattery());
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final c9 = <String, MatchResult? Function(String)>{
    for (final c in corpora) c.name: convertC9(rulesOf[c.name]!, c.top).recover
  };
  final c10 = <String, MatchResult? Function(String)>{
    for (final c in corpora) c.name: convertC10(rulesOf[c.name]!, c.top).recover
  };
  final c12 = <String, MatchResult? Function(String)>{
    for (final c in corpora)
      c.name: c12x.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top).recover
  };
  final c13 = <String, MatchResult? Function(String)>{
    for (final c in corpora)
      c.name: c13x.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top).recover
  };

  // (grammar, input) lists: clean = every corpus document; damaged = battery.
  final clean = <(String, String)>[
    for (final c in corpora)
      for (final d in c.documents) (c.name, d)
  ];
  final damaged = <(String, String)>[
    for (final k in cases) (k.grammar, k.mutant)
  ];

  int run(Map<String, MatchResult? Function(String)> eng,
      List<(String, String)> inputs, int reps) {
    final sw = Stopwatch()..start();
    for (var r = 0; r < reps; r++) {
      for (final (g, s) in inputs) {
        eng[g]!(s);
      }
    }
    return sw.elapsedMicroseconds;
  }

  // Warmup both engines on both input kinds.
  for (var w = 0; w < 3; w++) {
    run(c9, clean, 5);
    run(c10, clean, 5);
    run(c12, clean, 5);
    run(c13, clean, 5);
    run(c9, damaged, 1);
    run(c10, damaged, 1);
    run(c12, damaged, 1);
    run(c13, damaged, 1);
  }

  final t9c = <int>[], t10c = <int>[], t12c = <int>[], t13c = <int>[];
  final t9d = <int>[], t10d = <int>[], t12d = <int>[], t13d = <int>[];
  for (var r = 0; r < rounds; r++) {
    t9c.add(run(c9, clean, 20));
    t10c.add(run(c10, clean, 20));
    t12c.add(run(c12, clean, 20));
    t13c.add(run(c13, clean, 20));
    t9d.add(run(c9, damaged, 1));
    t10d.add(run(c10, damaged, 1));
    t12d.add(run(c12, damaged, 1));
    t13d.add(run(c13, damaged, 1));
  }
  int med(List<int> xs) {
    final s = [...xs]..sort();
    return s[s.length ~/ 2];
  }

  String r(List<int> x, List<int> b) => (med(x) / med(b)).toStringAsFixed(3);
  print('clean   c9=${med(t9c)}us c10=${med(t10c)}us c12=${med(t12c)}us '
      'c13=${med(t13c)}us '
      'c10/c9=${r(t10c, t9c)} c12/c9=${r(t12c, t9c)} c13/c9=${r(t13c, t9c)}');
  print('damaged c9=${med(t9d)}us c10=${med(t10d)}us c12=${med(t12d)}us '
      'c13=${med(t13d)}us '
      'c10/c9=${r(t10d, t9d)} c12/c9=${r(t12d, t9d)} c13/c9=${r(t13d, t9d)}');
}
