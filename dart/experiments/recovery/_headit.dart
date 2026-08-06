// _headit.dart -- is m72's head-walk RESTART the battery gap?
//
// m72:970-974 resets `f.pc = 1` every time the head list grows, because I30's
// ordered insert can land a new split BEHIND the frame's cursor where an
// appended one was always ahead of it. m62 appends and so never restarts
// (m62.dart:628, the same loop with the block absent). `_steps` counts frame
// steps, so a quadratic re-walk INSIDE one frame is invisible to it.
//
// Counts, not clocks -- these copies are instrumented and must never be timed.
import 'dart:io';

import 'final_table.dart' show buildSetup;
import '_m62it.dart' as e62;
import '_m72it.dart' as e72;

void main(List<String> argv) {
  final (rules, battery, _, _, latCases, _, _, _) = buildSetup();

  for (final (name, inputs) in [('BATTERY', battery), ('LATENCY', latCases)]) {
    final a = e62.SuperDot3(rules: rules, topRuleName: 'JSON');
    final b = e72.SuperDot3(rules: rules, topRuleName: 'JSON');
    e62.SuperDot3.nHeadIt = e62.SuperDot3.nTailIt = 0;
    e72.SuperDot3.nHeadIt = e72.SuperDot3.nTailIt = e72.SuperDot3.nRestart = 0;
    for (final s in inputs) {
      a.recoverCost(s);
      b.recoverCost(s);
    }
    final h62 = e62.SuperDot3.nHeadIt, t62 = e62.SuperDot3.nTailIt;
    final h72 = e72.SuperDot3.nHeadIt, t72 = e72.SuperDot3.nTailIt;
    stdout.writeln('=== $name (${inputs.length} inputs) ===');
    stdout.writeln('  head-loop iterations   m62 $h62   m72 $h72'
        '   ratio ${(h72 / h62).toStringAsFixed(4)}');
    stdout.writeln('  tail-value iterations  m62 $t62   m72 $t72'
        '   ratio ${(t72 / t62).toStringAsFixed(4)}');
    stdout.writeln('  m72 restarts           ${e72.SuperDot3.nRestart}');
  }
}
