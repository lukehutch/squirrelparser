// Scratch: does the prefix scan in _afford ever disagree with the filter it
// replaced? The claim is structural (_afford's argument is always a _prune
// result, and _prune sorts by _rank, whose first key is del+gap), so this
// measures the claim rather than trusting it.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import '_ord.dart' as e;

void main() {
  final cases = weighted(buildBattery());
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final made = <String, e.Squirrel>{
    for (final c in corpora)
      c.name: e.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top)
  };
  for (final k in cases) {
    try {
      made[k.grammar]!.recover(k.mutant);
    } catch (_) {}
  }
  print('_afford calls that dropped anything: ${e.Squirrel.dropped}');
  print('prefix disagreed with filter:        ${e.Squirrel.viol}');
}
