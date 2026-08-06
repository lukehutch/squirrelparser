// _tierun.dart -- what do the surviving order-dependent ties differ in?
//
// m95 and m96 hold the same five keys and still disagree on 3 transpose cases.
// Either some way ties on all five, or the pruning is dropping a way that would
// have extended better -- which happens when the transition reads a field the
// comparison does not. `_runs` reads `tail`. This prints every top-level
// candidate's full key vector from both engines on one case.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_t95.dart' as a;
import '_t96.dart' as b;

void main() {
  final c = corpora.firstWhere((c) => c.name == 'stmt');
  final rules = MetaGrammar.parseGrammar(c.grammar);
  const mutant = 'if (a) { b=1; } if (c) { d=2; } e=;3';
  print('mutant: $mutant\n');
  a.tieProbe.clear();
  a.SuperDot3(rules: rules, topRuleName: c.top).recover(mutant);
  print('m95 (wave order):');
  for (final l in a.tieProbe) {
    print(l);
  }
  b.tieProbe.clear();
  b.SuperDot3(rules: rules, topRuleName: c.top).recover(mutant);
  print('\nm96 (sweep order):');
  for (final l in b.tieProbe) {
    print(l);
  }
}
