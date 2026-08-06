// _pair93.dart -- m92 vs m93 on the whole battery, interleaved within each case.
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
// Usage: dart run _pair93.dart [reps]
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'm92.dart' as g92;
import 'm93.dart' as g93;
import '_m93b.dart' as g93b;

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
      c.name: g93.SuperDot3(rules: rulesOf[c.name]!, topRuleName: c.top).recover
  };
  final d = <String, MatchResult? Function(String)>{
    for (final c in corpora)
      c.name: g93b.SuperDot3(rules: rulesOf[c.name]!, topRuleName: c.top).recover
  };

  final ta = <double>[], tb = <double>[], td = <double>[];
  for (var r = 0; r <= reps; r++) {
    final sa = Stopwatch(), sb = Stopwatch(), sd = Stopwatch();
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
      sd.start();
      try {
        d[k.grammar]!(k.mutant);
      } catch (_) {}
      sd.stop();
    }
    final x = sa.elapsedMicroseconds / 1000, y = sb.elapsedMicroseconds / 1000;
    final z = sd.elapsedMicroseconds / 1000;
    // Pass 0 is the warm-up: it pays for JIT on both arms and is not counted.
    if (r > 0) {
      ta.add(x);
      tb.add(y);
      td.add(z);
    }
    print('pass $r${r == 0 ? ' (warm-up)' : ''}  m92 ${x.toStringAsFixed(0)} ms'
        '   m93 ${y.toStringAsFixed(0)} ms'
        '   m93b ${z.toStringAsFixed(0)} ms');
  }

  final ma = median(ta), mb = median(tb), md = median(td);
  print('');
  print('median of $reps passes');
  print('  m92  (no flag, tables cleared)   ${ma.toStringAsFixed(0)} ms');
  print('  m93  (flag, tables kept)         ${mb.toStringAsFixed(0)} ms'
      '   ${(mb / ma).toStringAsFixed(3)}x');
  print('  m93b (flag, tables cleared)      ${md.toStringAsFixed(0)} ms'
      '   ${(md / ma).toStringAsFixed(3)}x');
  print('');
  print('  price of the flag alone          '
      '${(md - ma).toStringAsFixed(0)} ms  ${((md - ma) / ma * 100).toStringAsFixed(1)}%');
  print('  worth of the reuse it buys       '
      '${(md - mb).toStringAsFixed(0)} ms  ${((md - mb) / ma * 100).toStringAsFixed(1)}%');
}
