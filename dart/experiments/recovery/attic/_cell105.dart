// _cell105.dart -- how much of a repair round only re-derives the pure parse?
//
// The best-first ceiling is 1.54x (_bf105.dart), so the deepening schedule is
// not where the 3x latency gap to m78 lives. What is left is the size of the
// cost<=optimum search. m62 avoids it structurally: parse once, then run a
// delta schedule that only touches cells near the damage. m105 re-derives every
// cell at every budget round -- and repairs are localised, which is the whole
// premise of `site`, `doubt` and `echo`.
//
// So: what fraction of the cells a repair round computes end up holding nothing
// but cost-0 ways, i.e. exactly what `_pc` already holds from round 0?
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_m105cell.dart' as cell;

void main() {
  final cases = weighted(buildBattery());
  final rules = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final made = <String, MatchResult? Function(String)>{
    for (final c in corpora)
      c.name: cell.SuperDot3(rules: rules[c.name]!, topRuleName: c.top).recover
  };

  for (final k in cases) {
    try {
      made[k.grammar]!(k.mutant);
    } catch (_) {}
  }

  final run = cell.cellsRun;
  final pure = cell.cellsPureOnly, empty = cell.cellsEmpty;
  final free = cell.offersFree, paid = cell.offersPaid;
  String pct(int a, int b) => '${(a / b * 100).toStringAsFixed(1)}%';

  print('-- memo cells, repair rounds only --');
  print('bodies executed        $run');
  print('memo hits              ${cell.cellsHit}'
      '  (${(cell.cellsHit / (run + cell.cellsHit) * 100).toStringAsFixed(1)}% of probes)');
  print('  all ways cost 0      $pure  (${pct(pure, run)})');
  print('  empty (no way)       $empty  (${pct(empty, run)})');
  print('  contain a repair     ${run - pure - empty}'
      '  (${pct(run - pure - empty, run)})');
  print('');
  print('-- offered ways, repair rounds only --');
  print('cost 0 (pure)          $free  (${pct(free, free + paid)})');
  print('cost > 0 (repairing)   $paid  (${pct(paid, free + paid)})');
  print('');
  print('ceiling if every pure-only cell came from _pc instead of re-deriving:');
  print('  ${(run / (run - pure)).toStringAsFixed(2)}x on cell bodies');
}
