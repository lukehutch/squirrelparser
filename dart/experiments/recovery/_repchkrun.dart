// _repchkrun.dart -- is the swept repetition the SAME ANSWER as the waved one,
// or only a differently ordered one? Runs both inside a single engine on every
// case and compares the ways as a sorted multiset, so list order cannot mask or
// manufacture a difference.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_repchk.dart' as g;

void main() {
  final cases = weighted(buildBattery());
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final made = <String, MatchResult? Function(String)>{
    for (final c in corpora)
      c.name: g.SuperDot3(rules: rulesOf[c.name]!, topRuleName: c.top).recover
  };
  for (final k in cases) {
    try {
      made[k.grammar]!(k.mutant);
    } catch (_) {}
  }
  print('_rep calls        ${g.nRep}');
  print('content differs   ${g.nRepDiff}'
      '  (${(g.nRepDiff / g.nRep * 100).toStringAsFixed(4)}%)');
  for (final d in g.repDiffs) {
    print('--- $d');
  }
}
