// Scratch: run both engines over the whole battery with every structural claim
// checked on every way the chart stores.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_invA.dart' as a;
import '_invE.dart' as b;

void main() {
  final cases = weighted(buildBattery());
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  for (final which in ['r4u (exact merge)', 'u11b FINAL']) {
    final ea = <String, a.Squirrel>{}, eb = <String, b.Squirrel>{};
    for (final c in corpora) {
      ea[c.name] = a.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top);
      eb[c.name] = b.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top);
    }
    a.Squirrel.viol.clear();
    b.Squirrel.viol.clear();
    for (final k in cases) {
      try {
        if (which.startsWith('r4u')) {
          ea[k.grammar]!.recover(k.mutant);
        } else {
          eb[k.grammar]!.recover(k.mutant);
        }
      } catch (_) {}
    }
    final v = which.startsWith('r4u') ? a.Squirrel.viol : b.Squirrel.viol;
    print(which);
    final keys = v.keys.toList()..sort();
    for (final key in keys) {
      print('  ${v[key].toString().padLeft(10)}  $key');
    }
    print('');
  }
}
