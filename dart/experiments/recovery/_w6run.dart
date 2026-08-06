// Scratch: did deferring construction actually stop the building? Same battery,
// same node accounting as _w2run, over v20.
//
//   dart run _w6run.dart

import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_w6.dart' as w;

int _nodes(MatchResult m) {
  var n = 1;
  for (final s in m.subClauseMatches) {
    n += _nodes(s);
  }
  return n;
}

void main() {
  final cases = weighted(buildBattery());
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final eng = <String, w.Squirrel>{
    for (final c in corpora)
      c.name: w.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top)
  };
  w.resetCounters();
  var used = 0;
  for (final k in cases) {
    try {
      used += _nodes(eng[k.grammar]!.recover(k.mutant));
    } catch (_) {}
  }
  String pc(num a, num b) =>
      '${(a / (b == 0 ? 1 : b) * 100).toStringAsFixed(1)}%';
  print('cases                 ${cases.length}');
  print('_wrap (nodes BUILT)   ${w.nWrap}');
  print('  nodes in answers    $used  (${pc(used, w.nWrap)})  <-- kept');
  print('_build calls          ${w.nBuild}');
  print('  chain steps walked  ${w.nBuildSteps}  '
      '(${(w.nBuildSteps / (w.nBuild == 0 ? 1 : w.nBuild)).toStringAsFixed(2)} per build)');
}
