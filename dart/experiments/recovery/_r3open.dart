// _r3open.dart -- the dominant r2 failure: damage at position 0.
//
// Hypothesis: when the OPENING delimiter is missing, a shorter wrong parse
// (`Value <- String` reading just `"a"`) succeeds at 0, so `held[0]` is true,
// so the l=1 fill is refused by the `!held[p]` guard and the deletion is
// refused by `destroys`. Both repairs at position 0 are unreachable.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'r2.dart' as r2;

void main() {
  final json = corpora.firstWhere((c) => c.name == 'json');
  final rules = MetaGrammar.parseGrammar(json.grammar);

  const probes = [
    '"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}', // leading { deleted
    '1,[2,[3,[4]]],5]', // leading [ deleted
    '"{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}', // quote inserted at 0
    'Q[1,[2,[3,[4]]],5]', // junk at 0
    '[1,[2,', // the _recommit case the guard exists for
  ];

  for (final s in probes) {
    print('--- `$s`');
    // What the PURE parser does: how far does it get, and what shape?
    final pure = Parser(rules: rules, topRuleName: json.top, input: s).parse();
    print('   pure: len=${pure.root.len} of ${s.length}  '
        'skeleton=${skeleton(pure.root, json.named)}');

    final e = r2.Squirrel(rules: rules, topRuleName: json.top);
    final got = e.recover(s);
    print('   r2  : cost=${e.lastCost} skeleton=${skeleton(got, json.named)}');
  }
}
