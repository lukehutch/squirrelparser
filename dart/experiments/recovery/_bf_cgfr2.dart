// Brute-force BFS ground-truth gate for cgfr2.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm46.dart' as g46;
import 'cgfr2.dart' as g49;

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

  var total = 0, totalOk = 0;
  for (final (label, src, top, alphabet, inputs) in cases) {
    final rules = MetaGrammar.parseGrammar(src);
    final e46 = g46.SuperDot3(rules: rules, topRuleName: top);
    final e49 = g49.SuperDot3(rules: rules, topRuleName: top);
    print('$label   alphabet="$alphabet"');
    print('input      true   m46   m49   verdict');
    var blockOk = 0;
    for (final s in inputs) {
      total++;
      final t = trueDistance(rules, top, s, alphabet, 2);
      final r46 = e46.recoverCost(s);
      final r49 = e49.recoverCost(s);
      final res49 = e49.recover(s);
      final cov49 = covers(res49.root, s.length);
      final ok = t == r49 && cov49;
      if (ok) blockOk++;
      print('${s.padRight(10)} ${(t?.toString() ?? '>2').padLeft(4)} '
          '${r46.toString().padLeft(5)} ${r49.toString().padLeft(5)}   '
          '${ok ? "ok" : "MISMATCH (true=$t m49=$r49 cov=$cov49)"}');
    }
    print('$label: $blockOk/${inputs.length}\n');
    totalOk += blockOk;
  }
  print('TOTAL: $totalOk/$total');
}
