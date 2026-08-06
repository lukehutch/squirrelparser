// _resid.dart -- size the two WITHIN-round savings, before building either.
//
// Occasion 54 refuted the semi-naive plan by measuring its ceiling: cross-round
// re-derivation is 28.9% of the deepening loop, and the gap to m78 needs 53%.
// That number is silent about the round that WINS, which is the other 71%.
//
// Two candidates live there, both visible in m121's source, and the lesson from
// Occasion 54 is to price them before writing either:
//
//   A. The residual budget. `_seq`/`_rep` ask for a full-budget search and then
//      discard every way that does not fit what the prefix left. Where the
//      prefix already spent the budget, only cost-0 ways can survive, so a pure
//      lookup would have answered the call.
//   B. The ordered-choice fan-out. At budget 0 an alternative with no pure
//      reading costs one `continue`; at budget >= 1 it costs a complete repair
//      search. This is the visible candidate for the 35x step from round 0.
//
// Usage: dart run _resid.dart
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_r121b.dart' as g;

void main() {
  final cases = weighted(buildBattery());
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final made = <String, MatchResult? Function(String)>{
    for (final c in corpora)
      c.name: g.SuperDot3(rules: rulesOf[c.name]!, topRuleName: c.top).recover
  };

  g.kResetProbe();
  final sw = Stopwatch()..start();
  for (final k in cases) {
    try {
      made[k.grammar]!(k.mutant);
    } catch (_) {}
  }
  sw.stop();
  final totalUs = sw.elapsedMicroseconds;
  pct(int us) => (100 * us / totalUs).toStringAsFixed(1).padLeft(5);

  print('m121 over ${cases.length} weighted cases: '
      '${(totalUs / 1000).round()} ms wall\n');

  print('A. RESIDUAL BUDGET AT THE FOLD');
  print('   residual   calls');
  var shown = 0;
  for (var i = 0; i < g.kResidCalls.length && shown < 8; i++) {
    if (g.kResidCalls[i] == 0) continue;
    shown++;
    print('   ${i.toString().padLeft(8)}   ${g.kResidCalls[i]}');
  }
  final folds = g.kResidCalls.fold<int>(0, (a, b) => a + b);
  print('   total fold calls: $folds');
  print('   of which residual 0 while budget > 0: ${g.kZeroCalls} '
      '(${(100 * g.kZeroCalls / folds).toStringAsFixed(1)}%)');
  print('   ways those returned: ${g.kZeroWays}, '
      'discarded unread by the cost filter: ${g.kZeroCut} '
      '(${g.kZeroWays == 0 ? "-" : (100 * g.kZeroCut / g.kZeroWays).toStringAsFixed(1)}%)');
  print('   wall time of the subtrees under them (outermost only, '
      'non-overlapping):');
  print('      ${(g.kZeroUs / 1000).round()} ms = ${pct(g.kZeroUs)}% '
      'of the run    <-- CEILING A');

  print('\nB. ORDERED-CHOICE FAN-OUT');
  print('   alternatives given a full repair search (no pure reading, '
      'budget >= 1): ${g.kAltCalls}');
  print('   ways they produced: ${g.kAltWays}');
  print('   wall time of those searches (outermost only, non-overlapping):');
  print('      ${(g.kAltUs / 1000).round()} ms = ${pct(g.kAltUs)}% '
      'of the run    <-- CEILING B');

  print('\nA and B OVERLAP -- a choice search can sit inside a residual-0 '
      'subtree and vice versa, so they are not additive.');
  print('Both are UPPER bounds: the real call is memoised at the full budget, '
      'so part of this work is genuinely reused by a later caller that needs '
      'the full-budget answer.');
}
