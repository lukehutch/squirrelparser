// _seeded_fast.dart -- first 150 cases only; see _seeded.dart.
// _seeded.dart -- does the demand-driven top-down search already reach the
// fixed point a chart would?
//
// m144 is m143 plus a SEEDED right-to-left re-relaxation over exactly the cells
// the top-down pass demanded. If that sweep never improves a cell, the chart is
// not merely slower than the search (m141 measured 17.8x) -- it is redundant,
// because the search already computes the same fixed point.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'm144.dart';

void main() {
  final rulesOf = {
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final seen = <String>{};
  var cases = 0, rounds = 0, grew = 0, changed = 0, withGrowth = 0;
  final examples = <String>[];
  for (final k in weighted(buildBattery())) {
    if (!seen.add('${k.grammar}\x00${k.category}\x00${k.mutant}')) continue;
    if (cases >= 150) break;
    final p = SuperDot3(
        rules: rulesOf[k.grammar]!,
        topRuleName: corpora.firstWhere((c) => c.name == k.grammar).top);
    try {
      p.recover(k.mutant);
    } catch (_) {
      continue;
    }
    cases++;
    rounds += p.sweepRounds;
    grew += p.sweepGrew;
    changed += p.sweepChangedBest;
    if (p.sweepGrew > 0) {
      withGrowth++;
      if (examples.length < 10) {
        examples.add('  ${k.grammar.padRight(5)} ${k.category.padRight(15)} '
            '${p.sweepGrew} cell(s), best changed ${p.sweepChangedBest}x  '
            '${k.mutant}');
      }
    }
  }
  print('$cases distinct cases, $rounds seeded sweeps run');
  print('');
  print('cells the sweep improved      : $grew');
  print('cases where any cell improved : $withGrowth / $cases');
  print('rounds where the WINNER changed: $changed');
  if (examples.isNotEmpty) {
    print('');
    print('examples:');
    examples.forEach(print);
  }
  print('');
  print(grew == 0
      ? 'The top-down search ALREADY reaches the chart fixed point.\n'
          'A chart cannot find a reading it misses -- it is redundant, not just slower.'
      : 'The sweep found $grew improvable cell(s): the search does NOT reach the\n'
          'global fixed point, and the chart buys something real.');
}
