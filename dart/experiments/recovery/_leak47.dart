// Scratch: does m47's `_end` LEAK a pending constraint?
//
// `_end@c` returns {pos: 0} for every c, so a chain all of whose elements are
// silent satisfies a NONEMPTY constraint vacuously. `_chain`'s branch 1
// (h@c x t@free) is supposed to admit only derivations where h EMITS; the leak
// would let a silent h in, with the constraint never applied to anything.
//
// To fire it the nullable run must end a SUB-chain, i.e. sit at the end of a
// rule body, so the constraint falls off that body's `_end` instead of being
// handed to the next element by the split.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm46.dart' as g46;
import 'm47.dart' as g47;

bool inLanguage(Map<String, Clause> rules, String top, String s) {
  final p = Parser(rules: rules, topRuleName: top, input: s).parse();
  return !p.hasSyntaxErrors && p.root != null && p.root!.len == s.length;
}

int? trueDistance(
    Map<String, Clause> rules, String top, String s, String alphabet, int maxK) {
  var frontier = {s};
  final seen = {s};
  for (var k = 0; k <= maxK; k++) {
    for (final c in frontier) {
      if (inLanguage(rules, top, c)) return k;
    }
    final next = <String>{};
    for (final c in frontier) {
      for (var i = 0; i < c.length; i++) {
        final del = c.substring(0, i) + c.substring(i + 1);
        if (seen.add(del)) next.add(del);
      }
      for (var i = 0; i <= c.length; i++) {
        for (final ch in alphabet.split('')) {
          final ins = c.substring(0, i) + ch + c.substring(i);
          if (seen.add(ins)) next.add(ins);
          if (i < c.length) {
            final sub = c.substring(0, i) + ch + c.substring(i + 1);
            if (seen.add(sub)) next.add(sub);
          }
        }
      }
    }
    frontier = next;
  }
  return null;
}

const int maxEdits = 3;

String cell(int Function(String) f, String s) {
  try {
    return f(s).toString();
  } catch (e) {
    return 'X(${e.runtimeType})';
  }
}

const cases = <(String, String, String, List<String>)>[
  // The predicted leak: A's body is a sequence of two nullables, so `!'x'`
  // reaches A's own `_end` with nothing left in A to constrain.
  (
    'nullable run ENDING a rule body',
    "S <- !'x' A D;\nA <- 'a'? 'c'?;\nD <- 'd' / 'x';\n",
    'acdx',
    ['x', 'ax', 'acx', 'd', 'ad', ''],
  ),
  // Control: the same nullables INLINE in S's chain, where the split hands the
  // constraint to D and no `_end` is involved. This one m47 already gets right.
  (
    'the same nullables INLINE (control)',
    "S <- !'x' 'a'? 'c'? D;\nD <- 'd' / 'x';\n",
    'acdx',
    ['x', 'ax', 'acx', 'd', 'ad', ''],
  ),
  // One nullable ending a rule body -- the shortest form of the leak.
  (
    'one nullable ending a rule body',
    "S <- !'x' A D;\nA <- 'a'?;\nD <- 'd' / 'x';\n",
    'adx',
    ['x', 'ax', 'd', 'ad', ''],
  ),
  // A rule body that is a sequence of two rule references, both nullable.
  (
    'nullable refs ending a rule body',
    "S <- !'x' A D;\nA <- B C;\nB <- 'b'?;\nC <- 'c'?;\nD <- 'd' / 'x';\n",
    'bcdx',
    ['x', 'bx', 'd', 'bd', ''],
  ),
];

void main() {
  var bad46 = 0, bad47 = 0, total = 0;
  for (final (title, grammar, alphabet, inputs) in cases) {
    final rules = MetaGrammar.parseGrammar(grammar);
    print('\n$title\n  ${grammar.replaceAll('\n', ' ')}');
    print('  ${'input'.padRight(9)}${'true'.padLeft(6)}${'m46'.padLeft(6)}'
        '${'m47'.padLeft(6)}   verdict');
    for (final s in inputs) {
      total++;
      final t = trueDistance(rules, 'S', s, alphabet, maxEdits);
      final want = t?.toString() ?? '>$maxEdits';
      final c46 =
          cell(g46.SuperDot3(rules: rules, topRuleName: 'S').recoverCost, s);
      final c47 =
          cell(g47.SuperDot3(rules: rules, topRuleName: 'S').recoverCost, s);
      String verdict(String got) {
        if (t != null) return got == '$t' ? 'ok' : (int.tryParse(got) ?? 99) < t
            ? 'UNDER-REPORT'
            : 'too high';
        final n = int.tryParse(got);
        return (n == null || n < 0 || n > maxEdits) ? 'ok' : 'UNDER-REPORT';
      }

      final v46 = verdict(c46), v47 = verdict(c47);
      if (v46 != 'ok') bad46++;
      if (v47 != 'ok') bad47++;
      print('  ${(s.isEmpty ? '<empty>' : s).padRight(9)}${want.padLeft(6)}'
          '${c46.padLeft(6)}${c47.padLeft(6)}   m46 $v46 / m47 $v47');
    }
  }
  print('\nwrong: m46 $bad46/$total, m47 $bad47/$total');
}
