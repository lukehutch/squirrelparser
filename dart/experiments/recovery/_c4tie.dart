import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import 'c4.dart' as c4;

void main() {
  final cases = weighted(buildBattery());
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final made = <String, c4.Squirrel>{};
  for (final c in corpora) {
    made[c.name] = c4.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top);
  }
  c4.Squirrel.tieSpy = 60;
  for (var i = 0; i < cases.length; i++) {
    final k = cases[i];
    try {
      made[k.grammar]!.recover(k.mutant);
    } catch (_) {}
  }
  print('ties=${c4.Squirrel.ties} fieldDiff=${c4.Squirrel.tiesDiff} '
      '(${(c4.Squirrel.tiesDiff * 100 / c4.Squirrel.ties).toStringAsFixed(1)}%)');
}
