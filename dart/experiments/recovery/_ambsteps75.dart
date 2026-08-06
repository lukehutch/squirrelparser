// _ambsteps.dart -- does the corrected FAB price change the amount of WORK?
//
// Clock-free, so it is safe to run beside another job. `lastSteps` counts
// relaxations, which is what a timing sweep would be measuring anyway; if the
// counts are identical the price cannot have moved latency, because regret is
// lexicographically below cost and so can never redirect the search, only the
// value that survives a tie.
import 'dart:io';

import 'final_table.dart' show buildSetup;
import 'm74.dart' as e74;
import '_m74amb.dart' as eamb;

void main() {
  final (rules, battery, _, __, ___, ____, _____, ______) = buildSetup();
  final a74 = e74.SuperDot3(rules: rules, topRuleName: 'JSON');
  final aamb = eamb.SuperDot3(rules: rules, topRuleName: 'JSON');
  var s74 = 0, samb = 0, differ = 0, costDiff = 0;
  for (final s in battery) {
    final c74 = a74.recoverCost(s);
    final camb = aamb.recoverCost(s);
    s74 += a74.lastSteps;
    samb += aamb.lastSteps;
    if (a74.lastSteps != aamb.lastSteps) differ++;
    if (c74 != camb) costDiff++;
  }
  stdout.writeln('battery ${battery.length}');
  stdout.writeln('relaxations  m74 $s74   amb $samb   '
      '(${(100 * (samb - s74) / s74).toStringAsFixed(2)}%)');
  stdout.writeln('inputs where the step count differs: $differ');
  stdout.writeln('inputs where the COST differs:       $costDiff');
}
