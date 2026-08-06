// _finrun.dart -- how often is a cell actually final across rounds?
//
// I59 says a cell that never consulted the cap is good at every larger budget.
// m93 implements it and is 2.3% SLOWER, which is either "the bookkeeping costs
// more than the reuse" or "nothing is ever final". Those need different answers,
// so count them.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_fin93.dart' as g;

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

  final bodies = g.nBody;
  final done = g.nFinSet + g.nFinNot;
  String pc(int x, int of) => '${(x / of * 100).toStringAsFixed(2)}%';
  print('cell bodies run at budget > 0      ${g.nBody}');
  print('  completed, marked final          ${g.nFinSet}  ${pc(g.nFinSet, done)}');
  print('  completed, cap-dependent         ${g.nFinNot}  ${pc(g.nFinNot, done)}');
  print('final-cell hits, EARLIER round     ${g.nHitCross}'
      '  ${pc(g.nHitCross, bodies)} of bodies  <- the only real saving');
  print('final-cell hits, same round        ${g.nHitSame}'
      '  ${pc(g.nHitSame, bodies)} of bodies  <- m92 already caught these');
}
