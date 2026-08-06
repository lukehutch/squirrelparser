// Scratch: r5 vs v13 vs v17 vs v20, INTERLEAVED over the whole battery.
//
// _vscore runs each engine once, in order, so a 10% engine difference and a 10%
// machine difference read the same. This runs all four within each round and
// reports the median round, so any drift hits all four equally.
//
//   dart run _v20t.dart

import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'r5.dart' as e5;
import '_v20.dart' as e20;
import '_v22.dart' as e22;
import '_v23.dart' as e23;
import '_v25.dart' as e25;
import '_v24.dart' as e24;

const _reps = 7;

typedef Make = MatchResult Function(String) Function(
    Map<String, Clause>, String);

final _engines = <String, Make>{
  'r5 ': (r, t) => e5.Squirrel(rules: r, topRuleName: t).recover,
  'v20': (r, t) => e20.Squirrel(rules: r, topRuleName: t).recover,
  'v22': (r, t) => e22.Squirrel(rules: r, topRuleName: t).recover,
  'v23': (r, t) => e23.Squirrel(rules: r, topRuleName: t).recover,
  'v24': (r, t) => e24.Squirrel(rules: r, topRuleName: t).recover,
  'v25': (r, t) => e25.Squirrel(rules: r, topRuleName: t).recover,
};

void main() {
  final cases = weighted(buildBattery());
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final topOf = {for (final c in corpora) c.name: c.top};

  final times = {for (final k in _engines.keys) k: <double>[]};
  // Warm every engine once before any clock starts.
  for (final e in _engines.entries) {
    for (final k in cases) {
      try {
        e.value(rulesOf[k.grammar]!, topOf[k.grammar]!)(k.mutant);
      } catch (_) {}
    }
  }
  for (var r = 0; r < _reps; r++) {
    for (final e in _engines.entries) {
      final sw = Stopwatch()..start();
      for (final k in cases) {
        try {
          e.value(rulesOf[k.grammar]!, topOf[k.grammar]!)(k.mutant);
        } catch (_) {}
      }
      sw.stop();
      times[e.key]!.add(sw.elapsedMicroseconds / 1000);
    }
  }
  print('battery ${cases.length} cases, $_reps interleaved rounds\n');
  double? base;
  for (final k in _engines.keys) {
    final t = times[k]!..sort();
    final med = t[t.length ~/ 2];
    base ??= med;
    print('$k  median ${med.toStringAsFixed(0).padLeft(5)} ms   '
        'x${(med / base!).toStringAsFixed(3)}   '
        'min ${t.first.toStringAsFixed(0)}  max ${t.last.toStringAsFixed(0)}');
  }
}
