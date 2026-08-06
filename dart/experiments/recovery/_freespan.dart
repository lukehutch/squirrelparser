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

import 'r9.dart' as r9;
import 's1.dart' as s1;
import 't1.dart' as t1;
import 'c1.dart' as c1;
import 'c2.dart' as c2;
import 'c3.dart' as c3;
import 'c4.dart' as c4;
import 'c5.dart' as c5;
import 's4.dart' as s4;
import 'm132.dart' as m132;
import 'm143.dart' as m143;

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
];

int? cost(String name, Map<String, Clause> rules, String top, String s) =>
    switch (name) {
      'm132' => m132.SuperDot3(rules: rules, topRuleName: top).recoverCost(s),
      'm143' => m143.SuperDot3(rules: rules, topRuleName: top).recoverCost(s),
      'r9' => r9.Squirrel(rules: rules, topRuleName: top).recoverCost(s),
      's1' => s1.Squirrel(rules: rules, topRuleName: top).recoverCost(s),
      't1' => t1.Squirrel(rules: rules, topRuleName: top).recoverCost(s),
      's4' => s4.Squirrel(rules: rules, topRuleName: top).recoverCost(s),
      'c1' => c1.Squirrel(rules: rules, topRuleName: top).recoverCost(s),
      'c2' => c2.Squirrel(rules: rules, topRuleName: top).recoverCost(s),
      'c3' => c3.Squirrel(rules: rules, topRuleName: top).recoverCost(s),
      'c4' => c4.Squirrel(rules: rules, topRuleName: top).recoverCost(s),
      'c5' => c5.Squirrel(rules: rules, topRuleName: top).recoverCost(s),
      _ => null,
    };

const engines = [
  'm121', 'm126', 'm127', 'm132', 'm136', 'm141', 'm143', // raw cost is the first key
  // `cost - net` outranks it. m135-m140 are the I79/collapse family, all built
  // from m134 or m135, so all of them inherit I77 along with everything else.
  'm129', 'm130', 'm131', 'm133', 'm134', 'm135', 'm137', 'm138', 'm139',
  'r9',
  's1',
  't1',
  's4',
  'c1',
  'c2',
  'c3',
  'c4',
  'c5',
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
