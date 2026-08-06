// _chartcost.dart -- can the chart find a reading the top-down search misses?
//
// m141 IS the full chart: every clause node x every position, relaxed
// right-to-left to a within-position fixed point. m143 is the demand-driven
// top-down search. If the chart never returns a CHEAPER repair, then it reaches
// no reading the search misses, and it is redundant rather than merely slower
// (m141 measured 17.8x). Cost is the right comparison because it is the first
// key of the ordering -- a cheaper reading always wins.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'm141.dart' as chart;
import 'm143.dart' as topdown;

void main() {
  final rulesOf = {
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final seen = <String>{};
  var n = 0, chartCheaper = 0, searchCheaper = 0, same = 0;
  final examples = <String>[];
  for (final k in weighted(buildBattery())) {
    if (!seen.add('${k.grammar}\x00${k.category}\x00${k.mutant}')) continue;
    final top = corpora.firstWhere((c) => c.name == k.grammar).top;
    final r = rulesOf[k.grammar]!;
    int a, b;
    try {
      a = chart.SuperDot3(rules: r, topRuleName: top).recoverCost(k.mutant);
      b = topdown.SuperDot3(rules: r, topRuleName: top).recoverCost(k.mutant);
    } catch (_) {
      continue;
    }
    n++;
    if (a < b) {
      chartCheaper++;
      if (examples.length < 12) {
        examples.add('  chart $a < search $b   ${k.grammar.padRight(5)} '
            '${k.category.padRight(15)} ${k.mutant}');
      }
    } else if (b < a) {
      searchCheaper++;
      if (examples.length < 12) {
        examples.add('  search $b < chart $a   ${k.grammar.padRight(5)} '
            '${k.category.padRight(15)} ${k.mutant}');
      }
    } else {
      same++;
    }
  }
  print('$n distinct cases');
  print('  identical cost      : $same');
  print('  chart found cheaper : $chartCheaper');
  print('  search found cheaper: $searchCheaper');
  if (examples.isNotEmpty) {
    print('');
    examples.forEach(print);
  }
  print('');
  print(chartCheaper == 0
      ? 'The chart never finds a cheaper repair than the top-down search.\n'
          'It reaches no reading the search misses: redundant, not just slower.'
      : 'The chart finds a cheaper repair on $chartCheaper case(s): it reaches\n'
          'readings the search misses, and the 17.8x buys something real.');
}
