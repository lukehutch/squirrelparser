// _freespan.dart -- THE CONTROL THE BATTERY CANNOT BE: may a repair DELETE real
// input that already matched?
//
// Every case in the AST-diff battery is a mutant that genuinely needs repair
// (`astdiff.dart` keeps a mutant only `if (m.isNotEmpty && !parses(m))`), so no
// case in it ever presents a span that is ALREADY FINE next to a costlier
// reading of the same span. The battery is therefore blind, by construction, to
// an engine that throws real characters away to reach a reading it scores
// higher -- and it rewarded exactly that: I77 scored +0.0020 on the battery
// while deleting real input here.
//
// THE SHAPE OF THE TRAP. `C <- E / W` where `W <- . . . .` matches any four
// characters for free and `E <- . 'a' 'b'` matches three, two of them by precise
// literals. On `xxab` the input IS four arbitrary characters, so W is a free,
// exact reading and the answer is "no repair in C at all". The suffix `'q' 'r'
// 's'` is absent and must be filled whatever C does, so the fills are a constant
// and the only question this asks is whether C stayed free.
//
// An engine whose first comparison key is raw `cost` cannot fail: a free way at
// an ending beats a repaired one there, full stop. An engine that lets a way
// with HIGHER raw cost win the ending -- I77's `cost - net` -- takes the E
// reading, because deleting one real character raises the FRACTION of the span
// explained by constraining terminals even though it lowers the AMOUNT. That is
// the failure this file exists to name: `net` is a good tie-breaker among ways
// that cost the same and a bad objective when it may outrank cost.
//
// Usage: dart run _freespan.dart
import 'package:squirrel_parser/squirrel_parser.dart';

import 'm121.dart' as m121;
import 'r1.dart' as r1;
import 'r2.dart' as r2;
import 'r3.dart' as r3;
import 'r4.dart' as r4;
import 'r5.dart' as r5;
import 'r6.dart' as r6;
import 'r7.dart' as r7;
import 'r8.dart' as r8;
import 'r9.dart' as r9;
import 's1.dart' as s1;
import 't1.dart' as t1;
import 's2.dart' as s2;
import 'm126.dart' as m126;
import 'm127.dart' as m127;
import 'm129.dart' as m129;
import 'm130.dart' as m130;
import 'm131.dart' as m131;
import 'm132.dart' as m132;
import 'm141.dart' as m141;
import 'm143.dart' as m143;
import 'm133.dart' as m133;
import 'm134.dart' as m134;
import 'm135.dart' as m135;
import 'm136.dart' as m136;
import 'm137.dart' as m137;
import 'm138.dart' as m138;
import 'm139.dart' as m139;
import 'm140.dart' as m140;

/// The suffix is unmatchable, so every engine must fill it; only what happens
/// inside `C` is under test. `want` is the cost of those fills alone, which is
/// what an engine that leaves the free span alone reports.
const g4 = '''
Top <- C 'q' 'r' 's';
C <- E / W;
E <- . 'a' 'b';
W <- . . . .;
''';

const g5 = '''
Top <- C 'q' 'r' 's' 't';
C <- E / W;
E <- . 'a' 'b';
W <- . . . .;
''';

/// A repetition rather than a choice, so the trap is not an artifact of `First`:
/// `[a-z]*` already covers `zzz` for free, and quoting it is the costlier,
/// more-constrained reading.
const g6 = '''
Top <- V ';';
V <- Str / Word;
Word <- [a-z]*;
Str <- '"' [a-z]* '"';
''';

typedef Probe = (String, String, String, int);

const probes = <Probe>[
  ('g4', g4, 'xxab', 3),
  ('g4', g4, 'xyab', 3),
  ('g5', g5, 'xxab', 4),
  ('g5', g5, 'xyab', 4),
  ('g6', g6, 'zzz', 1),
];

int? cost(String name, Map<String, Clause> rules, String top, String s) =>
    switch (name) {
      'm121' => m121.SuperDot3(rules: rules, topRuleName: top).recoverCost(s),
      'm126' => m126.SuperDot3(rules: rules, topRuleName: top).recoverCost(s),
      'm127' => m127.SuperDot3(rules: rules, topRuleName: top).recoverCost(s),
      'm129' => m129.SuperDot3(rules: rules, topRuleName: top).recoverCost(s),
      'm130' => m130.SuperDot3(rules: rules, topRuleName: top).recoverCost(s),
      'm131' => m131.SuperDot3(rules: rules, topRuleName: top).recoverCost(s),
      'm132' => m132.SuperDot3(rules: rules, topRuleName: top).recoverCost(s),
      'm141' => m141.SuperDot3(rules: rules, topRuleName: top).recoverCost(s),
      'm143' => m143.SuperDot3(rules: rules, topRuleName: top).recoverCost(s),
      'm133' => m133.SuperDot3(rules: rules, topRuleName: top).recoverCost(s),
      'm134' => m134.SuperDot3(rules: rules, topRuleName: top).recoverCost(s),
      'm135' => m135.SuperDot3(rules: rules, topRuleName: top).recoverCost(s),
      'm136' => m136.SuperDot3(rules: rules, topRuleName: top).recoverCost(s),
      'm137' => m137.SuperDot3(rules: rules, topRuleName: top).recoverCost(s),
      'm138' => m138.SuperDot3(rules: rules, topRuleName: top).recoverCost(s),
      'm139' => m139.SuperDot3(rules: rules, topRuleName: top).recoverCost(s),
      'm140' => m140.SuperDot3(rules: rules, topRuleName: top).recoverCost(s),
      'r1' => r1.Squirrel(rules: rules, topRuleName: top).recoverCost(s),
      'r2' => r2.Squirrel(rules: rules, topRuleName: top).recoverCost(s),
      'r3' => r3.Squirrel(rules: rules, topRuleName: top).recoverCost(s),
      'r4' => r4.Squirrel(rules: rules, topRuleName: top).recoverCost(s),
      'r5' => r5.Squirrel(rules: rules, topRuleName: top).recoverCost(s),
      'r6' => r6.Squirrel(rules: rules, topRuleName: top).recoverCost(s),
      'r7' => r7.Squirrel(rules: rules, topRuleName: top).recoverCost(s),
      'r8' => r8.Squirrel(rules: rules, topRuleName: top).recoverCost(s),
      'r9' => r9.Squirrel(rules: rules, topRuleName: top).recoverCost(s),
      's1' => s1.Squirrel(rules: rules, topRuleName: top).recoverCost(s),
      't1' => t1.Squirrel(rules: rules, topRuleName: top).recoverCost(s),
      's2' => s2.Squirrel(rules: rules, topRuleName: top).recoverCost(s),
      _ => null,
    };

const engines = [
  'm121', 'm126', 'm127', 'm132', 'm136', 'm141', 'm143', // raw cost is the first key
  // `cost - net` outranks it. m135-m140 are the I79/collapse family, all built
  // from m134 or m135, so all of them inherit I77 along with everything else.
  'm129', 'm130', 'm131', 'm133', 'm134', 'm135', 'm137', 'm138', 'm139',
  'm140',
  'r1',
  'r2',
  'r3',
  'r4',
  'r5',
  'r6',
  'r7',
  'r8',
  'r9',
  's1',
  't1',
  's2',
];

void main() {
  final rules = {
    for (final (g, src, _, _) in probes) g: MetaGrammar.parseGrammar(src),
  };
  final fails = <String, int>{};

  print('${'input'.padRight(14)}${'want'.padLeft(5)}'
      '${engines.map((e) => e.padLeft(6)).join()}');
  for (final (g, _, s, want) in probes) {
    final row = <String>[];
    for (final e in engines) {
      int? c;
      try {
        c = cost(e, rules[g]!, 'Top', s);
      } catch (_) {
        c = null;
      }
      if (c != want) fails[e] = (fails[e] ?? 0) + 1;
      row.add('${c ?? 'ERR'}${c == want ? ' ' : '!'}'.padLeft(6));
    }
    print('${'$g $s'.padRight(14)}${want.toString().padLeft(5)}${row.join()}');
  }

  print('');
  var bad = 0;
  for (final e in engines) {
    final n = fails[e] ?? 0;
    if (n > 0) bad++;
    print('  $e  ${n == 0 ? 'PASS' : 'FAIL ($n/${probes.length} deleted real '
        'input from a span that already matched)'}');
  }
  print('');
  print(bad == 0
      ? 'all clear'
      : '$bad of ${engines.length} engines repair what was not broken');
}
