// Scratch: bf_check.dart's ground-truth gate, run for m42 and m43.
// Brute-force BFS over single-character edits; the pure parser decides
// membership. Slow and stupid, and therefore trustworthy.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm42.dart' as g42;
import 'm43.dart' as g43;

bool covers(MatchResult root, int len) {
  var pos = 0;
  var ok = true;
  void walk(MatchResult m) {
    if (!ok) return;
    if (m is SyntaxError || m.subClauseMatches.isEmpty) {
      if (m.len == 0) return;
      if (m.pos != pos) ok = false;
      pos = m.pos + m.len;
      return;
    }
    m.subClauseMatches.forEach(walk);
  }

  walk(root);
  return ok && pos == len;
}

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
        final del = c.substring(0, i) + c.substring(i + 1); // SKIP
        if (seen.add(del)) next.add(del);
      }
      for (var i = 0; i <= c.length; i++) {
        for (final ch in alphabet.split('')) {
          final ins = c.substring(0, i) + ch + c.substring(i); // FAB
          if (seen.add(ins)) next.add(ins);
          if (i < c.length) {
            final sub = c.substring(0, i) + ch + c.substring(i + 1); // SUB
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
  final cases = <(String, String, String, String, List<String>)>[
    (
      'left-recursive expr',
      "E <- E '+' T / T;\nT <- T '*' F / F;\nF <- [0-9];\n",
      'E',
      '0+*',
      ['1+2', '1++2', '1+', '+1', '1*', '1+2++3', '1 + 2', '', '++', '1+2*'],
    ),
    (
      'right-recursive expr (same language)',
      "E <- T '+' E / T;\nT <- F '*' T / F;\nF <- [0-9];\n",
      'E',
      '0+*',
      ['1+2', '1++2', '1+', '+1', '1*', '1+2++3', '1 + 2', '', '++', '1+2*'],
    ),
    (
      'indirectly left-recursive',
      "E <- A / F;\nA <- B '+' F;\nB <- E;\nF <- [0-9];\n",
      'E',
      '0+',
      ['1+2', '1++2', '1+', '+1', '1+2+3', '', '++', '1+2+'],
    ),
    (
      'nullable left recursion',
      "E <- E N / F;\nN <- '-'?;\nF <- [0-9];\n",
      'E',
      '0-',
      ['1', '1-', 'x', '1--', '', '11'],
    ),
    (
      'tiny json',
      "V <- O / A / N;\nO <- '{' (M (',' M)*)? '}';\nM <- N ':' V;\n"
          "A <- '[' (V (',' V)*)? ']';\nN <- [0-9];\n",
      'V',
      '0{}[],:',
      ['0', '{0:0}', '{0:0', '{0:}', '[0,]', '[0 0]', '{}}', '', '[[0]', '{0:0,}'],
    ),
  ];

  var totalBad = 0, total = 0;
  for (final (title, grammar, top, alphabet, inputs) in cases) {
    final rules = MetaGrammar.parseGrammar(grammar);
    final r42 = g42.SuperDot3(rules: rules, topRuleName: top);
    final r43 = g43.SuperDot3(rules: rules, topRuleName: top);
    print('\n$title   alphabet="$alphabet"');
    print('${'input'.padRight(9)}${'true'.padLeft(6)}${'m42'.padLeft(6)}'
        '${'m43'.padLeft(6)}   verdict');
    var bad = 0;
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

      final c42 = cell(r42.recoverCost);
      final c43 = cell(r43.recoverCost);
      final want = t?.toString() ?? '>3';
      var tree = '';
      try {
        final root = r43.recover(s).root;
        if (!covers(root, s.length)) tree = ' m43-NOCOVER';
      } catch (e) {
        tree = ' m43-BUILD(${e.runtimeType})';
      }
      final ok = c42 == want && c43 == want && tree.isEmpty;
      if (!ok) {
        bad++;
        totalBad++;
      }
      print('${(s.isEmpty ? '<empty>' : s).padRight(9)}${want.padLeft(6)}'
          '${c42.padLeft(6)}${c43.padLeft(6)}'
          '   ${ok ? "ok" : "MISMATCH"}$tree');
    }
    print('$title: ${inputs.length - bad}/${inputs.length}');
  }
  print('\nTOTAL: ${total - totalBad}/$total');
}
