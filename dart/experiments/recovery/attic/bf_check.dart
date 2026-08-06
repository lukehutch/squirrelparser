// GROUND TRUTH. Every engine so far has been checked against every OTHER
// engine, which cannot catch an error they share -- and the reentrancy guard in
// the memo is exactly the kind of thing they all share. This gate computes the
// true minimum edit distance from the input to the language by brute force:
// breadth-first over single-character edits, asking the pure parser whether each
// candidate is in L(G). Slow and stupid, and therefore trustworthy.
//
// A1 says a repair is a string s' in L(G) plus an alignment, with SUB/FAB/SKIP
// each costing 1 -- so the min-cost repair is precisely the Levenshtein distance
// from s to the nearest member of L(G). That is a claim about the objective, and
// this is the only test that verifies it independently of the engines.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm16.dart' as g16;
import 'm22.dart' as g22;
import 'm24.dart' as g24;
import 'm25.dart' as g25;
import 'm26.dart' as g26;

/// Do the recovered tree's leaves tile [0, len) exactly?
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

/// Is `s` in L(G) -- parsed with no syntax errors AND fully consumed? A prefix
/// parse is not membership.
bool inLanguage(Map<String, Clause> rules, String top, String s) {
  final p = Parser(rules: rules, topRuleName: top, input: s).parse();
  return !p.hasSyntaxErrors && p.root != null && p.root!.len == s.length;
}

/// True minimum number of SUB/FAB/SKIP edits taking `s` into L(G), or null if
/// no member is within `maxK`. BFS by distance, so the first hit is minimal.
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
      // The torture case for reconstruction: N is nullable, so E can re-derive
      // itself over the SAME extent at zero extra cost. A forward descent that
      // matches on exact Delta could take that cycle forever.
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

  for (final (title, grammar, top, alphabet, inputs) in cases) {
    final rules = MetaGrammar.parseGrammar(grammar);
    final r16 = g16.SuperDot3(rules: rules, topRuleName: top);
    final r22 = g22.SuperDot3(rules: rules, topRuleName: top);
    final r24 = g24.SuperDot3(rules: rules, topRuleName: top);
    final r25 = g25.SuperDot3(rules: rules, topRuleName: top);
    final r26 = g26.SuperDot3(rules: rules, topRuleName: top);
    print('\n$title   alphabet="$alphabet"');
    print('${'input'.padRight(9)}${'true'.padLeft(6)}${'m16'.padLeft(6)}'
        '${'m22'.padLeft(6)}${'m24'.padLeft(6)}${'m25'.padLeft(6)}${'m26'.padLeft(6)}   verdict');
    var bad = 0;
    for (final s in inputs) {
      final t = trueDistance(rules, top, s, alphabet, 3);
      String cell(int Function(String) f) {
        try {
          return f(s).toString();
        } catch (e) {
          return 'X(${e.runtimeType})';
        }
      }

      final a = cell(r16.recoverCost);
      final b = cell(r22.recoverCost);
      final c = cell(r24.recoverCost);
      final c25 = cell(r25.recoverCost);
      final c26 = cell(r26.recoverCost);
      final want = t?.toString() ?? '>3';
      // The cost is only half the claim: the witness must also be
      // reconstructible, and a left-recursive cycle is exactly what could make a
      // forward descent loop or fail.
      var tree = '';
      try {
        final root = r26.recover(s).root;
        if (!covers(root, s.length)) tree = ' m26-NOCOVER';
      } catch (e) {
        tree = ' m26-BUILD(${e.runtimeType})';
      }
      final ok = c == want && c25 == want && c26 == want && tree.isEmpty;
      if (!ok) bad++;
      print('${(s.isEmpty ? '<empty>' : s).padRight(9)}${want.padLeft(6)}'
          '${a.padLeft(6)}${b.padLeft(6)}${c.padLeft(6)}${c25.padLeft(6)}${c26.padLeft(6)}'
          '   ${ok ? "ok" : "MISMATCH"}$tree');
    }
    print('$title: m26 agrees with brute-force ground truth and rebuilds a '
        'covering tree on ${inputs.length - bad}/${inputs.length}');
  }
}
