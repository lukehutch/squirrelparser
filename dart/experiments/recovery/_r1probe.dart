// What does r1 actually do to damaged input? Shows the repaired tree so the
// frontier/widening decisions are visible, not just their cost.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'r1.dart';

const cases = <(String, String)>[
  // The two acceptance cases.
  ('json', '[1,3true]'),
  ('json', '[,2,3]'),
  // Truncations: the short-parse walk is the only frontier source here.
  ('json', '[1,[2,'),
  ('json', '{"a":'),
  ('json', '[1,2'),
  // Junk in the middle: the mismatch walk.
  ('json', '[1,@,3]'),
  ('json', '{"a":1,,"b":2}'),
  ('json', '[1 2,3]'),
  ('expr', 'a+*b'),
  ('expr', '1+(2+3'),
  ('stmt', 'x=1; y@=2; z=3;'),
  ('stmt', '{ a=1; b=2;'),
  ('stmt', 'if (a) { b=1;'),
];

void main(List<String> argv) {
  final want = argv.isEmpty ? null : argv.first;
  for (final (g, input) in cases) {
    if (want != null && g != want) continue;
    final c = corpora.firstWhere((x) => x.name == g);
    final e = Squirrel(
        rules: MetaGrammar.parseGrammar(c.grammar), topRuleName: c.top);
    final sw = Stopwatch()..start();
    MatchResult m;
    try {
      m = e.recover(input);
    } catch (x) {
      print('$g  ${input.padRight(18)}  THREW $x');
      continue;
    }
    sw.stop();
    print('$g  ${input.padRight(18)}  cost=${e.lastCost} '
        'len=${m.len}/${input.length}  ${sw.elapsedMicroseconds}us');
    print(m.toPrettyString(input).trimRight().split('\n').map((l) => '    $l').join('\n'));
    print('');
  }
}
