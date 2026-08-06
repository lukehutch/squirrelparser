// Scratch: where does r5's chart actually spend? Totals over the whole battery.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_p5.dart' as p;

void main() {
  final cases = weighted(buildBattery());
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final made = <String, MatchResult Function(String)>{
    for (final c in corpora)
      c.name: p.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top).recover
  };
  final sw = Stopwatch()..start();
  for (final k in cases) {
    try {
      made[k.grammar]!(k.mutant);
    } catch (_) {}
  }
  sw.stop();
  final n = cases.length;
  void row(String k, num v, [String note = '']) => print(
      '  ${k.padRight(16)} ${v.toString().padLeft(12)} '
      '${(v / n).toStringAsFixed(1).padLeft(9)}/case  $note');
  print('${n} cases, ${sw.elapsedMilliseconds} ms (instrumented)');
  print('-- _ways dispatch');
  row('_ways calls', p.nWays);
  row('  Ref', p.nWaysRef, '${(p.nWaysRef / p.nWays * 100).toStringAsFixed(1)}%');
  row('  terminal', p.nWaysTerm,
      '${(p.nWaysTerm / p.nWays * 100).toStringAsFixed(1)}%');
  row('  cell', p.nWaysCell,
      '${(p.nWaysCell / p.nWays * 100).toStringAsFixed(1)}%');
  row('  cell memo hit', p.nHit,
      '${(p.nHit / (p.nWaysCell == 0 ? 1 : p.nWaysCell) * 100).toStringAsFixed(1)}% of cell');
  row('  hit+filtered', p.nHitFiltered);
  row('  expand loops', p.nLoop);
  print('-- _prune');
  row('calls', p.nPr);
  row('  items in', p.nPrIn, 'avg ${(p.nPrIn / p.nPr).toStringAsFixed(2)}');
  row('  items out', p.nPrOut);
  row('  NO-OP calls', p.nPrNoop,
      '${(p.nPrNoop / p.nPr * 100).toStringAsFixed(1)}% changed nothing');
  row('  OUTPUT not sorted', p.nPrOutUnsorted, 'must be 0');
  row('  from Ref', p.nRefPr,
      '${(p.nRefPr / p.nPr * 100).toStringAsFixed(1)}% of all prunes');
  row('  Ref NO-OP', p.nRefPrNoop,
      '${(p.nRefPrNoop / (p.nRefPr == 0 ? 1 : p.nRefPr) * 100).toStringAsFixed(2)}% of Ref prunes');
  print('-- _afford');
  row('calls', p.nAff);
  row('  items in', p.nAffIn, 'avg ${(p.nAffIn / (p.nAff == 0 ? 1 : p.nAff)).toStringAsFixed(2)}');
  row('  items out', p.nAffOut);
  row('  input NOT sorted', p.nAffUnsorted, 'prefix rule would be WRONG');
  row('  NO-OP calls', p.nAffNoop,
      '${(p.nAffNoop / (p.nAff == 0 ? 1 : p.nAff) * 100).toStringAsFixed(1)}% dropped nothing');
  print('-- node building');
  row('_close', p.nClose);
  row('_wrap', p.nWrap);
  row('_terminal', p.nTerm);
  row('_lift in', p.nLiftIn);
  row('_lift out', p.nLiftOut);
  print('-- _rep');
  row('ways in all', p.nRepAll);
  row('distinct ends', p.nRepEnds,
      'waste ${(100 - p.nRepEnds / (p.nRepAll == 0 ? 1 : p.nRepAll) * 100).toStringAsFixed(1)}%');
  print('-- _seq');
  row('prefixes seen', p.nSeqPre);
  row('  over budget', p.nSeqOver,
      '${(p.nSeqOver / (p.nSeqPre == 0 ? 1 : p.nSeqPre) * 100).toStringAsFixed(1)}%');
  row('  cur NOT sorted', p.nSeqUnsorted, 'break would be WRONG this often');
  row('resync k steps', p.nSkipK);
  row('moved k steps', p.nMoveK);
  row('moved chain items', p.nMoveChain);
  print('-- _prune input length histogram');
  for (var i = 0; i < 12; i++) {
    if (p.prHist[i] == 0) continue;
    print('  len ${i == 11 ? '11+' : i.toString().padLeft(3)} '
        '${p.prHist[i].toString().padLeft(12)}  '
        '${(p.prHist[i] / p.nPr * 100).toStringAsFixed(1)}%');
  }
}
