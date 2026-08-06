// Clean corpus + crash sweep for _r1b: every undamaged document must come back
// at cost 0 with a tree identical in shape to the frozen parser's.
import 'package:squirrel_parser/squirrel_parser.dart';

import '_r1b.dart';
import 'astdiff.dart';

void main() {
  var n = 0, dirty = 0, bad = 0;
  for (final c in corpora) {
    final rules = MetaGrammar.parseGrammar(c.grammar);
    for (final doc in c.documents) {
      n++;
      final e = Squirrel(rules: rules, topRuleName: c.top);
      final t = e.recover(doc);
      final want = Parser(rules: rules, topRuleName: c.top, input: doc).parse();
      if (e.lastCost != 0) {
        dirty++;
        print('DIRTY cost=${e.lastCost} ${c.name} $doc');
      }
      // `skeleton` returns a List, and Dart's `List ==` is identity, so this
      // must compare contents or it reports every document as changed.
      if ('${skeleton(t, c.named)}' != '${skeleton(want.root, c.named)}') {
        bad++;
        print('SHAPE ${c.name} $doc');
      }
    }
  }
  print('$n clean documents: $dirty at nonzero cost, $bad with a changed shape');

  var threw = 0, cases = 0;
  final seen = <String>{};
  final rulesOf = {
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final topOf = {for (final c in corpora) c.name: c.top};
  for (final k in weighted(buildBattery())) {
    if (!seen.add('${k.grammar}\x00${k.category}\x00${k.mutant}')) continue;
    cases++;
    try {
      Squirrel(rules: rulesOf[k.grammar]!, topRuleName: topOf[k.grammar]!)
          .recover(k.mutant);
    } catch (x) {
      threw++;
      if (threw <= 3) print('THREW ${x.runtimeType} on ${k.grammar} ${k.mutant}');
    }
  }
  print('$cases battery cases: $threw threw');
}
