// _work62.dart -- is m72's BATTERY gap more work, or the same work done slower?
//
// `_certcost` decomposes the 56.4 ms battery gap against m62 into 39.7 ms of
// relaxed pass, 17.8 ms of reconstruct+emit, and -1.1 ms of re-parse -- so the
// certificate is NOT where the gap lives, and the re-parse that looked like the
// obvious suspect is free (3/11 paired, a tie). 70% of the gap is the pass
// itself, which is exactly what I27 was predicted to cost: the obligation rides
// in the memo key, `_key(end, owed)`, so narrowing it FRAGMENTS the memo into
// more cells. Steps and cells are exact and identical run to run, so unlike the
// clock they can say whether this is more work or slower work.
import 'final_table.dart' show buildSetup;
import '_m62cells.dart' as e62;
import '_m72cnt.dart' as e72;

void main() {
  final (rules, battery, _, _, latCases, _, _, _) = buildSetup();
  for (final (name, inputs) in [('battery', battery), ('latency', latCases)]) {
    var s1 = 0, s2 = 0, c1 = 0, c2 = 0, n1 = 0, n2 = 0;
    for (final s in inputs) {
      final a = e62.SuperDot3(rules: rules, topRuleName: 'JSON');
      final b = e72.SuperDot3(rules: rules, topRuleName: 'JSON');
      a.recoverCost(s);
      b.recoverCost(s);
      s1 += a.lastSteps;
      s2 += b.lastSteps;
      c1 += a.lastCells;
      c2 += b.lastCells;
      n1 += a.lastEntries;
      n2 += b.lastEntries;
    }
    print('$name (${inputs.length} inputs)');
    print('  steps  m62 $s1  m72 $s2   ratio ${(s2 / s1).toStringAsFixed(4)}');
    print('  cells  m62 $c1  m72 $c2   ratio ${(c2 / c1).toStringAsFixed(4)}');
    print('  entries m62 $n1  m72 $n2  ratio ${(n2 / n1).toStringAsFixed(4)}');
  }
}
