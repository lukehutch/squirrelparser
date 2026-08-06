// _pair100.dart -- m98 vs m102 (the swept repetition) interleaved within each case.
//
// The official `ms` column comes from one cold pass per engine in its own
// process, which cannot separate a real engine difference from machine drift
// when something else is running. This runs both engines back to back on the
// SAME case, repeats the whole battery, and reports the median pass, so drift
// hits both arms equally and the ratio is the thing being measured.
//
// The protocol is otherwise _score1's: one engine per grammar reused across that
// grammar's cases, and the clock covers the engine call and nothing else.
//
// Usage: dart run _pair100.dart [reps]
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'm98.dart' as g92;
import 'm102.dart' as g100;

double median(List<double> xs) {
  final v = [...xs]..sort();
  return v.length.isOdd
      ? v[v.length ~/ 2]
      : (v[v.length ~/ 2 - 1] + v[v.length ~/ 2]) / 2;
}

void main(List<String> argv) {
  final reps = argv.isEmpty ? 5 : int.parse(argv[0]);

  final cases = weighted(buildBattery());
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final a = <String, MatchResult? Function(String)>{
    for (final c in corpora)
      c.name: g92.SuperDot3(rules: rulesOf[c.name]!, topRuleName: c.top).recover
  };
  final b = <String, MatchResult? Function(String)>{
    for (final c in corpora)
      c.name: g100.SuperDot3(rules: rulesOf[c.name]!, topRuleName: c.top).recover
  };

  final ta = <double>[], tb = <double>[];
  for (var r = 0; r <= reps; r++) {
    final sa = Stopwatch(), sb = Stopwatch();
    for (final k in cases) {
      sa.start();
      try {
        a[k.grammar]!(k.mutant);
      } catch (_) {}
      sa.stop();
      sb.start();
      try {
        b[k.grammar]!(k.mutant);
      } catch (_) {}
      sb.stop();
    }
    final x = sa.elapsedMicroseconds / 1000, y = sb.elapsedMicroseconds / 1000;
    // Pass 0 is the warm-up: it pays for JIT on both arms and is not counted.
    if (r > 0) {
      ta.add(x);
      tb.add(y);
    }
    print('pass $r${r == 0 ? ' (warm-up)' : ''}  m98 ${x.toStringAsFixed(0)} ms'
        '   m102 ${y.toStringAsFixed(0)} ms');
  }

  final ma = median(ta), mb = median(tb);
  print('');
  print('median of $reps passes');
  print('  m98  (site = runs, no echo)     ${ma.toStringAsFixed(0)} ms');
  print('  m102  (sweep: one visit per end)   ${mb.toStringAsFixed(0)} ms'
      '   ${(mb / ma).toStringAsFixed(3)}x');
}
