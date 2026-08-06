// Scratch: WHICH SITE builds the nodes that get thrown away?
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_w4.dart' as w;

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
  w.resetW();
  var used = 0;
  for (final k in cases) {
    try {
      used += _nodes(eng[k.grammar]!.recover(k.mutant));
    } catch (_) {}
  }
  final total = w.wLift + w.wFirst + w.wOpt + w.wClose + w.wTerm + w.wTermFill;
  void row(String n, int v) => print('  ${n.padRight(22)} ${v.toString().padLeft(9)}'
      '  ${(v / total * 100).toStringAsFixed(1).padLeft(5)}%');
  print('nodes BUILT $total, nodes KEPT $used '
      '(${(used / total * 100).toStringAsFixed(1)}%)');
  row('_lift  (Ref)', w.wLift);
  row('_first (arm)', w.wFirst);
  row('_opt', w.wOpt);
  row('_close (Seq+Rep)', w.wClose);
  row('_terminal clean', w.wTerm);
  row('_terminal fill', w.wTermFill);
  print('');
  print('ways in -> ways out of each builder (the prune that follows):');
  void r2(String n, int i, int o) => print('  ${n.padRight(10)} in ${i.toString().padLeft(9)}'
      '  out ${o.toString().padLeft(9)}  kept ${(o / (i == 0 ? 1 : i) * 100).toStringAsFixed(1)}%');
  r2('_lift', w.inLift, w.outLift);
  r2('_first', w.inFirst, w.outFirst);
  r2('_seq', w.inSeq, w.outSeq);
  r2('_rep', w.inRep, w.outRep);
}
