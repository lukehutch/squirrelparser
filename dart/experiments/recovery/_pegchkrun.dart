// Scratch: the claim [_first1] rests on -- after [_prune], a cell holds AT MOST
// ONE way that is still PEG's reading. If that is ever false, taking the first
// one is a choice, and D2 forbids choices the ranking did not make.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_pegchk.dart' as e;

void main() {
  final cases = weighted(buildBattery());
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  for (final k in cases) {
    try {
      e.Squirrel(rules: rulesOf[k.grammar]!, topRuleName: corpora.firstWhere((c) => c.name == k.grammar).top)
          .recover(k.mutant);
    } catch (_) {}
  }
  print('_prune outputs checked : ${e.nPruneOut}');
  print('with >1 PEG way        : ${e.nPegMulti}   '
      '${e.nPegMulti == 0 ? "<-- invariant holds" : "<-- VIOLATED"}');
}
