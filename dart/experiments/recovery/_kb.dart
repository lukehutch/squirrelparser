// _kb.dart -- prices `_keepBest`, the one hot-path member the two engines do
// NOT share. m62 scans linearly and APPENDS; m72 bisects (an `_endOf` per
// probe) and inserts IN ORDER, which shifts every slot above the insertion
// point. `_headit` showed m72 does FEWER inner-loop iterations than m62 and is
// still slower, so the cost has to be per-operation, and this is the operation.
//
// Counts, not clocks.
import 'dart:io';

import 'final_table.dart' show buildSetup;
import '_m62kb.dart' as e62;
import '_m72kb.dart' as e72;

void main(List<String> argv) {
  final (rules, battery, _, _, latCases, _, _, _) = buildSetup();

  for (final (name, inputs) in [('BATTERY', battery), ('LATENCY', latCases)]) {
    final a = e62.SuperDot3(rules: rules, topRuleName: 'JSON');
    final b = e72.SuperDot3(rules: rules, topRuleName: 'JSON');
    e62.SuperDot3.nCall = e62.SuperDot3.nProbe = e62.SuperDot3.nUpdate = 0;
    e62.SuperDot3.nAppend = e62.SuperDot3.nLenSum = e62.SuperDot3.nLenMax = 0;
    e72.SuperDot3.nCall = e72.SuperDot3.nProbe = e72.SuperDot3.nUpdate = 0;
    e72.SuperDot3.nAppend = e72.SuperDot3.nLenSum = e72.SuperDot3.nLenMax = 0;
    e72.SuperDot3.nShift = e72.SuperDot3.nInterior = 0;
    for (final s in inputs) {
      a.recoverCost(s);
      b.recoverCost(s);
    }
    String r(int x, int y) => y == 0 ? '-' : (x / y).toStringAsFixed(4);
    stdout.writeln('=== $name (${inputs.length} inputs) ===');
    stdout.writeln('           calls      probes     updates    appends'
        '    interior   ints-shifted  meanLen  maxLen');
    for (final (n, c, p, u, ap, iv, sh, ls, mx) in [
      (
        'm62',
        e62.SuperDot3.nCall,
        e62.SuperDot3.nProbe,
        e62.SuperDot3.nUpdate,
        e62.SuperDot3.nAppend,
        0,
        0,
        e62.SuperDot3.nLenSum,
        e62.SuperDot3.nLenMax
      ),
      (
        'm72',
        e72.SuperDot3.nCall,
        e72.SuperDot3.nProbe,
        e72.SuperDot3.nUpdate,
        e72.SuperDot3.nAppend,
        e72.SuperDot3.nInterior,
        e72.SuperDot3.nShift,
        e72.SuperDot3.nLenSum,
        e72.SuperDot3.nLenMax
      ),
    ]) {
      stdout.writeln('  $n  ${c.toString().padLeft(9)}'
          ' ${p.toString().padLeft(11)} ${u.toString().padLeft(10)}'
          ' ${ap.toString().padLeft(10)} ${iv.toString().padLeft(10)}'
          ' ${sh.toString().padLeft(13)}'
          '  ${c == 0 ? 0 : (ls / c).toStringAsFixed(2)}'
          '   $mx');
    }
    stdout.writeln('  probes m72/m62 = '
        '${r(e72.SuperDot3.nProbe, e62.SuperDot3.nProbe)}');
  }
}
