import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import '_r7i.dart' as e;
void main() {
  final cases = weighted(buildBattery());
  final rulesOf = {for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)};
  final topOf = {for (final c in corpora) c.name: c.top};
  var P=0,R=0,S=0,M=0,K=0,F=0,X=0;
  for (final k in cases) {
    final s = e.Squirrel(rules: rulesOf[k.grammar]!, topRuleName: topOf[k.grammar]!);
    try { s.recover(k.mutant); } catch (_) {}
    P+=s.nParse; R+=s.nRound; S+=s.nSite; M+=s.nMatch; K+=s.nK; F+=s.nFront;
    if (s.maxK>X) X=s.maxK;
  }
  print('cases        ${cases.length}');
  print('rounds       $R   (${(R/cases.length).toStringAsFixed(2)}/case)');
  print('frontier     $F   (${(F/(R==0?1:R)).toStringAsFixed(1)} sites/round)');
  print('k steps      $K   (${(K/(R==0?1:R)).toStringAsFixed(2)}/round)  maxK $X');
  print('site visits  $S   (${(S/(K==0?1:K)).toStringAsFixed(1)}/k-step)');
  print('_match       $M   (input-side probes)');
  print('_parse       $P   <-- FULL COLD RE-PARSES  (${(P/(S==0?1:S)*100).toStringAsFixed(1)}% of site visits)');
}
