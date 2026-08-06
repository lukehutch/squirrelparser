// Scratch: WHY does making the first round PEG cost battery time when it does
// strictly less work in that round? Counts cell lookups, misses, fixed-point
// iterations and expansions for both, over the real battery.
//
//   dart run _crun.dart
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_c20.dart' as a;
import '_c23.dart' as b;

void main() {
  final cases = weighted(buildBattery());
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final topOf = {for (final c in corpora) c.name: c.top};
  a.resetCounters();
  for (final k in cases) {
    try {
      a.Squirrel(rules: rulesOf[k.grammar]!, topRuleName: topOf[k.grammar]!)
          .recover(k.mutant);
    } catch (_) {}
  }
  final av = [a.nWays, a.nHit, a.nMiss, a.nLoop, a.nExpand, a.nWrap];
  b.resetCounters();
  for (final k in cases) {
    try {
      b.Squirrel(rules: rulesOf[k.grammar]!, topRuleName: topOf[k.grammar]!)
          .recover(k.mutant);
    } catch (_) {}
  }
  final bv = [b.nWays, b.nHit, b.nMiss, b.nLoop, b.nExpand, b.nWrap];
  const names = ['_ways calls', '  memo hits', '  misses', 'fixpoint iters',
      '_expand calls', '_wrap (built)'];
  print('${'counter'.padRight(16)}${'v20'.padLeft(12)}${'v23'.padLeft(12)}   ratio');
  for (var i = 0; i < names.length; i++) {
    print('${names[i].padRight(16)}${av[i].toString().padLeft(12)}'
        '${bv[i].toString().padLeft(12)}   '
        '${(bv[i] / (av[i] == 0 ? 1 : av[i])).toStringAsFixed(3)}');
  }
}
