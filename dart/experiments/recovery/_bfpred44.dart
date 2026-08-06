// Scratch: PRED against BRUTE-FORCE ground truth, not against hand-computed
// expectations. `_bf44.dart` has no predicate in any of its five grammars, and
// `_pred44.dart` compares to truths I wrote down myself -- so the PRED tag's
// claim ("reports a cost that is too HIGH") has never actually been tested.
//
// Two predictions this gate is built to settle:
//
//   * `S <- &'x' 'x' &'y' 'y';` on "zz" is repairable: L(S) = {"xy"}, so the
//     truth is 2. The engine evaluates predicates on the ORIGINAL input, where
//     &'x' can never pass, so it should report -1 -- a REPAIRABLE input declared
//     unrepairable, which is a far worse failure than "too high".
//
//   * `S <- !'x' A; A <- 'x' / "yy";` on "q": the oracle says !'x' passes on the
//     original input, and the cheapest continuation SUBs q -> x, which makes the
//     predicate false on the REPAIRED string. If the engine reports 1 it has
//     UNDER-reported and its repair does not parse; the truth is 2 ("yy").
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm43.dart' as g43;
import 'm44.dart' as g44;

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

void main() {
  const kw = "S <- Kw !Alpha;\nKw <- \"if\";\nAlpha <- [a-z];\n";
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
      kw,
      'S',
      'ifq',
      ['if', 'ifq', 'iff', 'i', 'if '],
    ),
  ];

  var totalBad = 0, total = 0;
  final worse = <String>[];
  for (final (title, grammar, top, alphabet, inputs) in cases) {
    final rules = MetaGrammar.parseGrammar(grammar);
    print('\n$title   alphabet="$alphabet"');
    print('${'input'.padRight(9)}${'true'.padLeft(6)}${'m43'.padLeft(6)}'
        '${'m44'.padLeft(6)}   verdict');
    for (final s in inputs) {
      total++;
      final t = trueDistance(rules, top, s, alphabet, 3);
      String cell(int Function(String) f) {
        try {
          return f(s).toString();
        } catch (e) {
          return 'X(${e.runtimeType})';
        }
      }

      final c43 =
          cell(g43.SuperDot3(rules: rules, topRuleName: top).recoverCost);
      final c44 =
          cell(g44.SuperDot3(rules: rules, topRuleName: top).recoverCost);
      final want = t?.toString() ?? '>3';
      final ok = c43 == want && c44 == want;
      if (!ok) totalBad++;
      // Which DIRECTION is the error? Under-reporting means the returned repair
      // cannot parse; -1 on a repairable input means a lost repair.
      var kind = '';
      final n44 = int.tryParse(c44);
      if (!ok && t != null && n44 != null) {
        if (n44 < 0) {
          kind = '  LOST (repairable, reported -1)';
        } else if (n44 < t) {
          kind = '  UNDER-REPORT (repair cannot parse)';
        } else {
          kind = '  too high';
        }
      }
      if (kind.contains('LOST') || kind.contains('UNDER')) {
        worse.add('$title / "$s": true $want, m44 $c44 --$kind');
      }
      print('${(s.isEmpty ? '<empty>' : s).padRight(9)}${want.padLeft(6)}'
          '${c43.padLeft(6)}${c44.padLeft(6)}'
          '   ${ok ? "ok" : "MISMATCH"}$kind');
    }
  }
  print('\nTOTAL: ${total - totalBad}/$total');
  if (worse.isEmpty) {
    print('no case worse than "too high"');
  } else {
    print('BEYOND THE PRED TAG (${worse.length}):');
    for (final w in worse) {
      print('  $w');
    }
  }
}
