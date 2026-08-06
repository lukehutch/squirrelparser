// _tight72.dart -- how often does I28's certificate demand force a SECOND pass?
//
// `recoverCost` runs `_pass` relaxed, and when `_certified` does not come back
// true it sets `_guarded` and runs `_pass` AGAIN. Each pass builds a fresh
// oracle `Parser` and parses it, then runs the whole relaxed DP. So a tightened
// input costs 2x everything. m62 has no such path.
//
// Measured construct-once, one engine per process: m72's battery is 26.4%
// slower than m62's (0 of 15 paired rounds) while its latency is only 4.3%
// slower. That split says a per-call fixed cost the tiny battery inputs cannot
// amortise -- and a doubled pass is exactly that shape. This counts it.
import 'dart:io';

import 'final_table.dart' show buildSetup;
import '_m72cnt.dart' as cnt;

void main() {
  final (rules, battery, _, _, latCases, _, _, _) = buildSetup();
  final e = cnt.SuperDot3(rules: rules, topRuleName: 'JSON');

  cnt.SuperDot3.nTight = cnt.SuperDot3.nPass = 0;
  for (final s in battery) {
    e.recoverCost(s);
  }
  final bt = cnt.SuperDot3.nTight, bp = cnt.SuperDot3.nPass;
  stdout.writeln('battery  inputs ${battery.length}  passes $bp  tightened $bt'
      '  (${(100 * bt / battery.length).toStringAsFixed(1)}% of inputs,'
      ' ${(bp / battery.length).toStringAsFixed(3)} passes/input)');

  cnt.SuperDot3.nTight = cnt.SuperDot3.nPass = 0;
  for (final s in latCases) {
    e.recoverCost(s);
  }
  final lt = cnt.SuperDot3.nTight, lp = cnt.SuperDot3.nPass;
  stdout.writeln('latency  inputs ${latCases.length}  passes $lp  tightened $lt'
      '  (${(100 * lt / latCases.length).toStringAsFixed(1)}% of inputs,'
      ' ${(lp / latCases.length).toStringAsFixed(3)} passes/input)');
}
