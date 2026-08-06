import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import '_pimp.dart' as p;

void main() {
  final cases = weighted(buildBattery());
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final made = <String, MatchResult Function(String)>{
    for (final c in corpora)
      c.name: p.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top).recover
  };
  for (final k in cases) {
    try {
      made[k.grammar]!(k.mutant);
    } catch (_) {}
  }
  print('LR loop body runs      ${p.nLoopIter}');
  print('cells still growing    ${p.nLR}   (foundLR true at the stop check)');
  print('_improved OLD says yes ${p.nImpOldTrue}');
  print('_improved NEW says yes ${p.nImpNewTrue}');
  print('THEY DISAGREE          ${p.nImpDiff}'
      '  <- every one is a fixed point the old test stopped early');
}
