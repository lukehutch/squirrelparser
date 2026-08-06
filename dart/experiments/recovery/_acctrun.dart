// Scratch: THE CHARGE MUST EQUAL THE ROUND. The deepening loop breaks at the
// first budget that answers, and a way found under a smaller budget is still a
// way, so the winner's cost is the minimum cost -- which is the round. Any case
// where the cost read off the tree is BELOW the round is a repair the tree does
// not show.
//   dart run _acctrun.dart <r8|w5>
import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import '_acctr8.dart' as a8;
import '_acctw5.dart' as aw5;
import '_acctw6.dart' as aw6;
void main(List<String> argv) {
  final which = argv.isEmpty ? 'r8' : argv[0];
  final cases = weighted(buildBattery());
  final rulesOf = {for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)};
  final topOf = {for (final c in corpora) c.name: c.top};
  var bad = 0, worst = 0;
  final show = <String>[];
  for (final k in cases) {
    final rules = rulesOf[k.grammar]!, top = topOf[k.grammar]!;
    int cost, round;
    try {
      if (which == 'r8') {
        final e = a8.Squirrel(rules: rules, topRuleName: top);
        e.recover(k.mutant); cost = e.lastCost; round = e.lastRound;
      } else if (which == 'w5') {
        final e = aw5.Squirrel(rules: rules, topRuleName: top);
        e.recover(k.mutant); cost = e.lastCost; round = e.lastRound;
      } else {
        final e = aw6.Squirrel(rules: rules, topRuleName: top);
        e.recover(k.mutant); cost = e.lastCost; round = e.lastRound;
      }
    } catch (_) { continue; }
    if (cost != round) {
      bad++;
      if (round - cost > worst) worst = round - cost;
      if (show.length < 6) {
        show.add('  ${k.grammar.padRight(5)} round=$round cost=$cost  ${k.mutant}');
      }
    }
  }
  print('$which: ${cases.length} cases, $bad where the tree UNDER-REPORTS the charge, worst gap $worst');
  show.forEach(print);
}
