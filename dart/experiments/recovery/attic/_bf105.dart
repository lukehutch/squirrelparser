// _bf105.dart -- the ceiling on replacing deepening with a cost-ordered search.
//
// m105's budget doubles, so the round that succeeds may allow up to twice the
// cost it ends up paying, and every reading it explores above that cost is one
// a cost-ordered search would never have settled. Together with the 26.2% of
// the search spent in rounds that fail (_prof105.dart), that is the whole of
// what Knuth's hypergraph Dijkstra could return.
//
//   ceiling = all offered ways / (final-round offers with cost <= optimum)
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_m105bf.dart' as bf;

void main() {
  final cases = weighted(buildBattery());
  final rules = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final made = <String, MatchResult? Function(String)>{
    for (final c in corpora)
      c.name: bf.SuperDot3(rules: rules[c.name]!, topRuleName: c.top).recover
  };

  for (final k in cases) {
    try {
      made[k.grammar]!(k.mutant);
    } catch (_) {}
  }

  final all = bf.allOffers, keep = bf.underOpt, over = bf.overOpt;
  print('offered ways, all rounds        $all');
  print('  final round, cost <= optimum  $keep'
      '  (${(keep / all * 100).toStringAsFixed(1)}%)');
  print('  final round, cost >  optimum  $over'
      '  (${(over / all * 100).toStringAsFixed(1)}%)');
  print('  earlier rounds (re-derived)   ${all - keep - over}'
      '  (${((all - keep - over) / all * 100).toStringAsFixed(1)}%)');
  print('');
  print('best-first ceiling              '
      '${(all / keep).toStringAsFixed(2)}x');
}
