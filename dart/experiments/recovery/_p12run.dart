import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import '_p12.dart' as p;

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
  void r(String k, num v, [String n = '']) =>
      print('  ${k.padRight(20)} ${v.toString().padLeft(11)}  $n');
  r('_ways calls', p.nWays);
  r('_prune calls', p.nPr, 'items ${p.nPrIn}');
  r('  len 2 (fast path)', p.nPr2);
  r('  len 3+ (map+sort)', p.nPrBig);
  r('_close', p.nClose, 'was 1,680,646 in r5');
  r('_wrap', p.nWrap, 'was 4,997,633 in r5');
  r('_terminal', p.nTerm, 'clean ${p.nTermClean} '
      '(${(p.nTermClean / p.nTerm * 100).toStringAsFixed(1)}%)');
  r('_seq slots done', p.nSeqSlots);
  r('  next built', p.nSeqNextIn);
  r('  next kept', p.nSeqNextOut,
      'thrown away ${(100 - p.nSeqNextOut / p.nSeqNextIn * 100).toStringAsFixed(1)}%');
  r('_first calls', p.nFirstIn, 'ways out ${p.nFirstOut}');
  r('_rep ways kept', p.nRepAll, 'was 1,136,271 built in r5');
}
