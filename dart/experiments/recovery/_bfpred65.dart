// Scratch: I6 (m49) against BRUTE-FORCE ground truth, next to m46.
//
// The nine grammars are `_bfpred46.dart`'s, unchanged, so the totals are directly
// comparable with the 42/45 recorded for m45 and m46. I6 claims the residual:
// a lookahead whose reader is behind a rule reference (`!'x' A`), which no static
// rewrite can reach because which clause reads the constrained character is not
// decided until run time.
//
// The second block is NEW and is not counted in the 45: the nullable-sequence
// family `_nullseq45.dart` isolates with the pure parser alone, where no static
// placement of the constraint is the right language in either direction.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm46.dart' as g46;
import 'm65.dart' as g49;

bool inLanguage(Map<String, Clause> rules, String top, String s) {
  final p = Parser(rules: rules, topRuleName: top, input: s).parse();
  return !p.hasSyntaxErrors && p.root != null && p.root!.len == s.length;
}

/// BFS over single-character SKIP/FAB/SUB, the pure parser deciding membership.
/// Returns null if nothing within `maxK` edits is in the language.
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

/// Brute force stops at `maxK`, so "no repair within reach" is agreed with by
/// -1 AND by any cost above the horizon: neither contradicts it. A cost within
/// reach where brute force found none is an under-report -- it names a repair
/// that does not exist.
bool agreesWith(int? truth, String got) {
  if (truth != null) return got == truth.toString();
  final n = int.tryParse(got);
  return n == null || n < 0 || n > maxEdits;
}

const int maxEdits = 3;

String cell(int Function(String) f, String s) {
  try {
    return f(s).toString();
  } catch (e) {
    return 'X(${e.runtimeType})';
  }
}

const cases = <(String, String, String, String, List<String>)>[
  (
    'positive predicate, both branches',
    "S <- &'x' 'x' &'y' 'y';\n",
    'S',
    'xyz',
    ['xy', 'zz', 'z', '', 'xz', 'zy', 'xyy'],
  ),
  (
    'negative predicate in front of a choice',
    "S <- !'x' A;\nA <- 'x' / \"yy\";\n",
    'S',
    'xyq',
    ['q', 'x', 'yy', 'y', '', 'xy'],
  ),
  (
    'negative predicate, single terminal',
    "S <- !'x' 'b';\n",
    'S',
    'xb',
    ['x', 'b', '', 'xb', 'bb'],
  ),
  (
    'negative predicate mid-sequence',
    "S <- 'a' !'x' 'b';\n",
    'S',
    'abx',
    ['ax', 'ab', 'a', 'axb', ''],
  ),
  (
    'keyword boundary',
    "S <- Kw !Alpha;\nKw <- \"if\";\nAlpha <- [a-z];\n",
    'S',
    'ifq',
    ['if', 'ifq', 'iff', 'i', 'if '],
  ),
  (
    'empty class: L(S) is empty',
    "S <- &'x' 'y';\n",
    'S',
    'xy',
    ['x', 'y', '', 'xy'],
  ),
  (
    'empty class beside a live branch',
    "S <- (&'x' 'y') / 'a' 'a';\n",
    'S',
    'xya',
    ['aa', 'x', '', 'ay'],
  ),
  (
    'a run of lookaheads',
    "S <- &'x' &[a-y] 'x';\n",
    'S',
    'xz',
    ['x', 'z', '', 'xx'],
  ),
  (
    'lookahead where a skip cannot stand in for a sub',
    "S <- '(' C C ')';\nC <- !')' .;\n",
    'S',
    '()x',
    ['()', '(x)', '(xx)', '(', '(x'],
  ),
];

/// NOT counted in the 45: the family where WHICH clause reads the constrained
/// character is not decided until run time.
const nullable = <(String, String, String, String, List<String>)>[
  (
    'nullable prefix under a lookahead (G0)',
    "S <- !'x' A B;\nA <- 'a'?;\nB <- 'b' / 'x';\n",
    'S',
    'abx',
    ['x', 'xx', 'ax', 'b', '', 'xb'],
  ),
  (
    'nullable prefix, two of them',
    "S <- !'x' A A B;\nA <- 'a'?;\nB <- 'b' / 'x';\n",
    'S',
    'abx',
    ['x', 'xx', 'aax', 'ab'],
  ),
  (
    'repetition under a lookahead',
    "S <- !'x' 'a'* B;\nB <- 'b' / 'x';\n",
    'S',
    'abx',
    ['x', 'aax', 'b', ''],
  ),
];

int run(List<(String, String, String, String, List<String>)> block,
    List<String> worse) {
  var bad46 = 0, bad47 = 0, total = 0;
  for (final (title, grammar, top, alphabet, inputs) in block) {
    final rules = MetaGrammar.parseGrammar(grammar);
    print('\n$title   alphabet="$alphabet"');
    print('${'input'.padRight(9)}${'true'.padLeft(6)}${'m46'.padLeft(6)}'
        '${'m49'.padLeft(6)}   verdict');
    for (final s in inputs) {
      total++;
      final t = trueDistance(rules, top, s, alphabet, maxEdits);
      final c46 =
          cell(g46.SuperDot3(rules: rules, topRuleName: top).recoverCost, s);
      final c47 =
          cell(g49.SuperDot3(rules: rules, topRuleName: top).recoverCost, s);
      final want = t?.toString() ?? '>$maxEdits';
      if (!agreesWith(t, c46)) bad46++;
      var kind = '';
      if (!agreesWith(t, c47)) {
        bad47++;
        final n = int.tryParse(c47);
        kind = n == null
            ? '  THREW'
            : n < 0
                ? '  LOST'
                : (t == null || n < t)
                    ? '  UNDER-REPORT'
                    : '  too high';
        worse.add('$title / "$s": true $want, m49 $c47 --$kind');
      }
      final mark = agreesWith(t, c47)
          ? (agreesWith(t, c46) ? 'ok' : 'FIXED by I6')
          : (agreesWith(t, c46) ? 'REGRESSED' : 'still wrong');
      print('${(s.isEmpty ? '<empty>' : s).padRight(9)}${want.padLeft(6)}'
          '${c46.padLeft(6)}${c47.padLeft(6)}   $mark$kind');
    }
  }
  print('  block total: m46 ${total - bad46}/$total, m49 ${total - bad47}/$total');
  return total - bad47;
}

void main() {
  final worse = <String>[];
  print('=== the nine grammars of _bfpred46, unchanged ===');
  final ok = run(cases, worse);
  print('\n=== nullable sequences: no static placement is the right language ===');
  final okNull = run(nullable, worse);

  print('\nm49: $ok/45 on the comparable block, $okNull/14 on the nullable block');
  if (worse.isEmpty) {
    print('m49 matches brute force everywhere above');
  } else {
    print('m49 residual (${worse.length}):');
    for (final w in worse) {
      print('  $w');
    }
  }

  // SPELLING INVARIANCE. The same language, written two ways. An engine that is
  // pricing the language rather than the spelling gives one column.
  spelling('[^)] vs !\')\' .', "S <- '(' C C ')';\nC <- [^)];\n",
      "S <- '(' C C ')';\nC <- !')' .;\n", '()x',
      ['()', '(x)', '(xx)', '(', 'xx', '', '()x']);
  spelling('[^"] vs !\'"\' .', "S <- '\"' C* '\"';\nC <- [^\"];\n",
      "S <- '\"' C* '\"';\nC <- !'\"' .;\n", '"x',
      ['"x"', 'x', '""', '', '"x', 'xx', '"xx"', '"']);
  spelling('[^)] vs !R . (a NAME in the lookahead)',
      "S <- '(' C C ')';\nC <- [^)];\n",
      "S <- '(' C C ')';\nR <- ')';\nC <- !R .;\n", '()x',
      ['()', '(x)', '(xx)', '(', 'xx', '', '()x']);
  spelling('[^)#] vs !(\')\' / \'#\') . (a CHOICE in the lookahead)',
      "S <- '(' C C ')';\nC <- [^)#];\n",
      "S <- '(' C C ')';\nC <- !(')' / '#') .;\n", '()x#',
      ['()', '(x)', '(xx)', '(#)', '(', 'xx', '', '()x']);
}

void spelling(String title, String asClass, String asPredicate, String alphabet,
    List<String> inputs) {
  print('\nspelling invariance: $title');
  final classSpelling = MetaGrammar.parseGrammar(asClass);
  final predSpelling = MetaGrammar.parseGrammar(asPredicate);
  print('${'input'.padRight(9)}${'true'.padLeft(6)}${'m46[^]'.padLeft(8)}'
      '${'m46!'.padLeft(6)}${'m49[^]'.padLeft(8)}${'m49!'.padLeft(6)}   verdict');
  var bad = 0;
  for (final s in inputs) {
    final t = trueDistance(classSpelling, 'S', s, alphabet, maxEdits);
    final want = t?.toString() ?? '>$maxEdits';
    final a = cell(
        g46.SuperDot3(rules: classSpelling, topRuleName: 'S').recoverCost, s);
    final b = cell(
        g46.SuperDot3(rules: predSpelling, topRuleName: 'S').recoverCost, s);
    final c = cell(
        g49.SuperDot3(rules: classSpelling, topRuleName: 'S').recoverCost, s);
    final d = cell(
        g49.SuperDot3(rules: predSpelling, topRuleName: 'S').recoverCost, s);
    final ok = c == d && agreesWith(t, c);
    if (!ok) bad++;
    print('${(s.isEmpty ? '<empty>' : s).padRight(9)}${want.padLeft(6)}'
        '${a.padLeft(8)}${b.padLeft(6)}${c.padLeft(8)}${d.padLeft(6)}'
        '   ${!ok ? "MISMATCH" : "ok"}');
  }
  print(bad == 0
      ? 'm49: both spellings agree, and agree with brute force'
      : '$bad of ${inputs.length} disagree');
}
