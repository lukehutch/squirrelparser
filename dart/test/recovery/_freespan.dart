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

import '../../experiments/recovery/c11.dart' as c11;
import '../../experiments/recovery/c12.dart' as c12;
import '_convert.dart';

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
      'c8' => convertC8(rules, top).recoverCost(s),
      'c9' => convertC9(rules, top).recoverCost(s),
      'c10' => convertC10(rules, top).recoverCost(s),
      'c11' => c11.C11(rules, top).recoverCost(s),
      'c12' => c12.Squirrel(rules: rules, topRuleName: top).recoverCost(s),
      _ => null,
    };

const engines = [
  'c9',
  'c10',
  'c11',
  'c12',
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
