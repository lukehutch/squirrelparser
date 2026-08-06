// Scratch: the same waste counters, over the REAL battery rather than the
// synthetic shapes -- this is the workload latency is measured on.
//
//   dart run _w2run.dart

import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_w2.dart' as w;

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
  print('deepening rounds      ${w.nRounds}');
  print('');
  print('_ways calls           ${w.nWays}');
  print('  memo hits           ${w.nHit}  (${pc(w.nHit, w.nWays)})');
  print('  computed            ${w.nMiss}');
  print('');
  print('cell RE-computations  ${w.nRecompute}   '
      '(a cell asked again in a LATER round)');
  print('  found NOTHING new   ${w.nRecomputeIdle}  '
      '(${pc(w.nRecomputeIdle, w.nRecompute)})  <-- wasted');
  print('');
  print('_afford calls         ${w.nClipped + w.nUnclipped}');
  print('  actually clipped    ${w.nClipped}  '
      '(${pc(w.nClipped, w.nClipped + w.nUnclipped)})');
  print('');
  print('_wrap (nodes BUILT)   ${w.nWrap}');
  print('  nodes in answers    $used  (${pc(used, w.nWrap)})  <-- kept');
  print('_close calls          ${w.nClose}');
  print('  chain steps walked  ${w.nCloseSteps}  '
      '(${(w.nCloseSteps / (w.nClose == 0 ? 1 : w.nClose)).toStringAsFixed(2)} per close)');
  print('');
  print('_prune calls          ${w.nPrune}   items ${w.nPruneItems}');
  print('_seq slot ways        ${w.nSeqSlotWays}   kept ${w.nSeqKept}');
  print('_rep expansions       ${w.nRepExpand}   kept ${w.nRepKept}');
  print('probes move/resync    ${w.nMoveProbe} / ${w.nResyncProbe}');
  print('LR cells iterating>1  ${w.nLRmulti}   version bumps ${w.nBump}');
}
