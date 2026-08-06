// Scratch: I4 (m45) against BRUTE-FORCE ground truth, next to m44.
//
// `_bfpred44.dart` established that PRED is not "reports a cost that is too
// high": it LOSES repairs (-1 on repairable input) and UNDER-REPORTS (a cost for
// a repair that cannot parse). This gate keeps those five grammars and adds the
// three things I4 claims:
//
//   * SPELLING INVARIANCE. `[^"]` and `!'"' .` are the same language, so an
//     engine that prices them differently is pricing the spelling. m44 does.
//   * THE EMPTY CLASS. `&'x' 'y'` accepts no character, so L(S) is empty and no
//     input is repairable at any cost. It must not become a cheap edit.
//   * A RUN OF LOOKAHEADS. `&'x' &[a-y] 'x'` collapses one pair at a time.
//
// The residual is expected to be the family I4 does not reach: a lookahead whose
// reader is behind a rule reference, or wider than one character.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm44.dart' as g44;
import 'm45.dart' as g45;

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

void main() {
  final cases = <(String, String, String, String, List<String>)>[
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

  var totalBad44 = 0, totalBad45 = 0, total = 0;
  final worse = <String>[];
  for (final (title, grammar, top, alphabet, inputs) in cases) {
    final rules = MetaGrammar.parseGrammar(grammar);
    print('\n$title   alphabet="$alphabet"');
    print('${'input'.padRight(9)}${'true'.padLeft(6)}${'m44'.padLeft(6)}'
        '${'m45'.padLeft(6)}   verdict');
    for (final s in inputs) {
      total++;
      final t = trueDistance(rules, top, s, alphabet, maxEdits);
      final c44 =
          cell(g44.SuperDot3(rules: rules, topRuleName: top).recoverCost, s);
      final c45 =
          cell(g45.SuperDot3(rules: rules, topRuleName: top).recoverCost, s);
      final want = t?.toString() ?? '>$maxEdits';
      // Brute force stops at maxK, so ">3" means "no repair within reach" and an
      // engine's -1 agrees with it. A NUMBER within reach where brute force found
      // none is an under-report: it names a repair that does not exist.
      bool agrees(String got) => agreesWith(t, got);
      if (!agrees(c44)) totalBad44++;
      if (!agrees(c45)) totalBad45++;
      var kind = '';
      final n45 = int.tryParse(c45);
      if (!agrees(c45) && n45 != null) {
        kind = n45 < 0
            ? '  LOST'
            : (t == null || n45 < t)
                ? '  UNDER-REPORT'
                : '  too high';
        worse.add('$title / "$s": true $want, m45 $c45 --$kind');
      }
      final mark = agrees(c45)
          ? (agrees(c44) ? 'ok' : 'FIXED by I4')
          : (agrees(c44) ? 'REGRESSED' : 'still wrong');
      print('${(s.isEmpty ? '<empty>' : s).padRight(9)}${want.padLeft(6)}'
          '${c44.padLeft(6)}${c45.padLeft(6)}   $mark$kind');
    }
  }
  print('\nm44: ${total - totalBad44}/$total     m45: ${total - totalBad45}/$total');
  if (worse.isEmpty) {
    print('m45 matches brute force everywhere above');
  } else {
    print('m45 residual (${worse.length}):');
    for (final w in worse) {
      print('  $w');
    }
  }

  // SPELLING INVARIANCE. The same language, written two ways. An engine that is
  // pricing the language rather than the spelling gives one column.
  //
  // The content is a FIXED COUNT of characters, which is what makes the two
  // spellings separable at all: where content is a repetition, discarding a
  // character and substituting one both cost 1 and the difference cancels.
  spelling('[^)] vs !\')\' .', "S <- '(' C C ')';\nC <- [^)];\n",
      "S <- '(' C C ')';\nC <- !')' .;\n", '()x',
      ['()', '(x)', '(xx)', '(', 'xx', '', '()x']);
  spelling('[^"] vs !\'"\' .', "S <- '\"' C* '\"';\nC <- [^\"];\n",
      "S <- '\"' C* '\"';\nC <- !'\"' .;\n", '"x',
      ['"x"', 'x', '""', '', '"x', 'xx', '"xx"', '"']);

  // The two spellings I4 must look THROUGH rather than merely at: a rule NAME,
  // and an ordered CHOICE of single characters -- which is how this project's own
  // metagrammar writes the body of a string literal (`!('"' / '\\') .`). Both are
  // the same language as the class beside them, so both must be the same price.
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
  print('${'input'.padRight(9)}${'true'.padLeft(6)}${'m44[^]'.padLeft(8)}'
      '${'m44!'.padLeft(6)}${'m45[^]'.padLeft(8)}${'m45!'.padLeft(6)}   verdict');
  var bad = 0;
  for (final s in inputs) {
    final t = trueDistance(classSpelling, 'S', s, alphabet, maxEdits);
    final want = t?.toString() ?? '>$maxEdits';
    final a =
        cell(g44.SuperDot3(rules: classSpelling, topRuleName: 'S').recoverCost, s);
    final b =
        cell(g44.SuperDot3(rules: predSpelling, topRuleName: 'S').recoverCost, s);
    final c =
        cell(g45.SuperDot3(rules: classSpelling, topRuleName: 'S').recoverCost, s);
    final d =
        cell(g45.SuperDot3(rules: predSpelling, topRuleName: 'S').recoverCost, s);
    final ok = c == d && agreesWith(t, c);
    if (!ok) bad++;
    print('${(s.isEmpty ? '<empty>' : s).padRight(9)}${want.padLeft(6)}'
        '${a.padLeft(8)}${b.padLeft(6)}${c.padLeft(8)}${d.padLeft(6)}'
        '   ${!ok ? "MISMATCH" : a != b ? "ok -- m44 PRICES THE SPELLING" : "ok"}');
  }
  print(bad == 0
      ? 'm45: both spellings agree, and agree with brute force'
      : '$bad of ${inputs.length} disagree');
}
