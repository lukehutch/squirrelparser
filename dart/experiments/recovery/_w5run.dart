import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import '_w5.dart' as w;

void main() {
  final cases = weighted(buildBattery());
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final eng = <String, w.Squirrel>{
    for (final c in corpora)
      c.name: w.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top)
  };
  w.resetInv();
  for (final k in cases) {
    try {
      eng[k.grammar]!.recover(k.mutant);
    } catch (_) {}
  }
  print(
      'ways handed out of a cell: prev==null ${w.okPrev}   prev!=null ${w.badPrev}   node==null ${w.noNode}');
}
