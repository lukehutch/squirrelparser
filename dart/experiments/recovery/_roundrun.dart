// _roundrun.dart -- PROBE. Where does the deepening loop spend its cell bodies?
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_rounds.dart' as g;

void main() {
  final cases = weighted(buildBattery());
  final byCorpus = <String, Corpus>{for (final c in corpora) c.name: c};
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final made = <String, MatchResult? Function(String)>{
    for (final c in corpora)
      c.name: g.SuperDot3(rules: rulesOf[c.name]!, topRuleName: c.top).recover
  };
  for (final k in cases) {
    byCorpus[k.grammar]!;
    try {
      made[k.grammar]!(k.mutant);
    } catch (_) {}
  }
  var tot = 0;
  for (final n in g.cellsByRound) {
    tot += n;
  }
  print('cell bodies by round index (budget 0, 1, 2, 4, 8, ...):');
  for (var i = 0; i < g.cellsByRound.length; i++) {
    final n = g.cellsByRound[i];
    print('  round $i  ${n.toString().padLeft(10)}  '
        '${(n / tot * 100).toStringAsFixed(1)}%');
  }
  print('  total   ${tot.toString().padLeft(10)}');
  print('');
  print('cases finishing after N rounds:');
  var cs = 0;
  for (final n in g.casesByRounds) {
    cs += n;
  }
  for (var i = 0; i < g.casesByRounds.length; i++) {
    if (g.casesByRounds[i] == 0) continue;
    print('  $i rounds  ${g.casesByRounds[i]}  '
        '${(g.casesByRounds[i] / cs * 100).toStringAsFixed(1)}%');
  }
  print('  cases solved $cs of ${cases.length}');
  breakdown();
}

// appended by the probe: the breakdown inside a round
void breakdown() {
  print('');
  print('cell bodies by table:  _mc ${g.nMc}   _me ${g.nMe}   terminals ${g.nTerm}');
  print('_repair calls          ${g.nElem}');
  print('  free short-circuit   ${g.nElemFree}');
  print('  _pure short-circuit  ${g.nElemPure}');
  print('  full repair search   ${g.nElemSearch}');
}
