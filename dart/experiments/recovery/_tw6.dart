// Scratch: r6 vs r8 INTERLEAVED over the whole battery, median of 7 rounds.
//   dart run _t8.dart
import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import '_w6.dart' as e6;
import 'r8.dart' as e8;

const _reps = 7;
typedef Make = MatchResult Function(String) Function(Map<String, Clause>, String);
final _engines = <String, Make>{
  'r8': (r, t) => e8.Squirrel(rules: r, topRuleName: t).recover,
  'w6': (r, t) => e6.Squirrel(rules: r, topRuleName: t).recover,
};
void main() {
  final cases = weighted(buildBattery());
  final rulesOf = {for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)};
  final topOf = {for (final c in corpora) c.name: c.top};
  final times = {for (final k in _engines.keys) k: <double>[]};
  for (final e in _engines.entries) {
    for (final k in cases) {
      try { e.value(rulesOf[k.grammar]!, topOf[k.grammar]!)(k.mutant); } catch (_) {}
    }
  }
  for (var r = 0; r < _reps; r++) {
    for (final e in _engines.entries) {
      final sw = Stopwatch()..start();
      for (final k in cases) {
        try { e.value(rulesOf[k.grammar]!, topOf[k.grammar]!)(k.mutant); } catch (_) {}
      }
      sw.stop();
      times[e.key]!.add(sw.elapsedMicroseconds / 1000);
    }
  }
  print('battery ${cases.length} cases, $_reps interleaved rounds');
  double? base;
  for (final k in _engines.keys) {
    final t = times[k]!..sort();
    final med = t[t.length ~/ 2];
    base ??= med;
    print('$k  median ${med.toStringAsFixed(0).padLeft(5)} ms   '
        'x${(med / base!).toStringAsFixed(3)}   min ${t.first.toStringAsFixed(0)}  max ${t.last.toStringAsFixed(0)}');
  }
}
