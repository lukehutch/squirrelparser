// _first105.dart -- how much of `_first`'s work is built and thrown away?
//
// LESSONS_LEARNED attributes the whole latency gap to three additions (I51 +701,
// I52 +1200, I53 +1753 ms) and records I54's finding that the same rule costs
// +396 ms as an ordering and -175 ms as a prune. I53 is written as an addition:
// `_first` builds the repair-opened list on every call and consults it only when
// the evidence-opened list comes back empty.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_m105first.dart' as f;

void main() {
  final cases = weighted(buildBattery());
  final rules = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final made = <String, MatchResult? Function(String)>{
    for (final c in corpora)
      c.name: f.SuperDot3(rules: rules[c.name]!, topRuleName: c.top).recover
  };

  for (final k in cases) {
    try {
      made[k.grammar]!(k.mutant);
    } catch (_) {}
  }

  String pct(int a, int b) =>
      b == 0 ? 'n/a' : '${(a / b * 100).toStringAsFixed(1)}%';

  print('_first calls              ${f.firstCalls}');
  print('  alternatives scanned    ${f.altsScanned}'
      '  (${(f.altsScanned / f.firstCalls).toStringAsFixed(2)} per call)');
  print('  full-budget evaluations ${f.altsFullEval}'
      '  (${(f.altsFullEval / f.firstCalls).toStringAsFixed(2)} per call)  <- I51');
  print('  answered from `opened`  ${f.firstRepairPass}'
      '  (${pct(f.firstRepairPass, f.firstCalls)})  <- I53 actually firing');
  print('');
  print('ways offered inside _first');
  print('  to `out`   (kept)       ${f.outPuts}');
  print('  to `opened`             ${f.openedPuts}');
  print('    of those, discarded   ${f.openedWasted}'
      '  (${pct(f.openedWasted, f.openedPuts)} of `opened`)');
  print('');
  print('all _put calls, engine-wide ${f.allPuts}');
  print('  wasted on `opened`        ${f.openedWasted}'
      '  (${pct(f.openedWasted, f.allPuts)} of the whole search)');
}
