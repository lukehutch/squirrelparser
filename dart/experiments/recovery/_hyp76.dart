// _hyp76.dart -- can an obligation be discharged by a character the repair
// invents, or only by one already in the input?
//
// After the opaque-obligation fix, 15 failures remain: 12 false -1 on gate A and
// 3 too-high on gate B.  Both sets involve a lookahead reached through a choice.
// One mechanism would explain all of them: the guard is checked against the
// original characters, so a repair whose lookahead lands on inserted or
// substituted text cannot discharge it.
//
// The probe pairs inputs by where the lookahead lands, holding the grammar and
// the true cost fixed.  If "original" passes and "invented" fails, the split is
// the mechanism; if both pass or both fail, it is not.
import 'package:squirrel_parser/squirrel_parser.dart';

import '_subset75.dart' show trueDist;
import '_m76fix.dart' as efix;

// (grammar, top, alphabet, [(input, where the lookahead lands)])
const probes = [
  (
    "S <- A 'b';\nA <- 'a' &'b' / 'c';\n",
    'S',
    'abcx',
    [
      ('ab', 'clean, no repair'),
      ('a', 'INVENTED: the b that satisfies &\'b\' must be inserted'),
      ('aab', 'original: delete the extra a, &\'b\' sees input b'),
      ('xab', 'original: delete x, &\'b\' sees input b'),
      ('cb', 'clean, second alternative'),
      ('axb', 'original-ish: substitute x->b? or delete x'),
    ]
  ),
  (
    "S <- (A / 'a') 'b';\nA <- 'a' &(\"bb\");\n",
    'S',
    'ab',
    [
      ('ab', 'clean'),
      ('abb', 'original: delete trailing b, guard reads input'),
      ('bbb', 'INVENTED: repair to ab, guard reads repaired text'),
      ('aabb', 'INVENTED'),
      ('bb', 'original-ish'),
    ]
  ),
];

void main() {
  for (final (g, top, alpha, inputs) in probes) {
    print('--- ${g.replaceAll('\n', ' ').trim()}');
    final r = MetaGrammar.parseGrammar(g);
    final e = efix.SuperDot3(rules: r, topRuleName: top);
    for (final (s, note) in inputs) {
      final want = trueDist(r, top, s, alpha, 3);
      int got;
      try {
        got = e.recoverCost(s);
      } catch (err) {
        print('  "$s" THREW $err');
        continue;
      }
      final ok = want == null ? (got > 3 || got == -1) : got == want;
      print('  ${'"$s"'.padRight(7)} want ${(want == null ? ">3" : "$want").padRight(3)} '
          'got ${got.toString().padRight(4)} ${ok ? "ok  " : "WRONG"}  $note');
    }
  }
}
