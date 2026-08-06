// Scratch: does cgfr1's obligation channel close block C and block D WITHOUT reopening m47's leak?
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm46.dart' as g46;
import 'm48.dart' as g48;
import 'cgfr1.dart' as g49;

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
  final c = f(s);
  return c < 0 || c > maxEdits ? '>$maxEdits' : c.toString();
}

bool agreesWith(int? truth, String got) {
  if (truth != null) return got == truth.toString();
  final n = int.tryParse(got);
  return n == null || n < 0 || n > maxEdits;
}

void block(String title, String src, String top, String alphabet,
    List<String> inputs,
    {required bool disallowUnderReport}) {
  print('\n$title');
  final rules = MetaGrammar.parseGrammar(src);
  final e46 = g46.SuperDot3(rules: rules, topRuleName: top);
  final e48 = g48.SuperDot3(rules: rules, topRuleName: top);
  final e49 = g49.SuperDot3(rules: rules, topRuleName: top);
  print('${'input'.padRight(12)}${'true'.padLeft(6)}${'m46'.padLeft(6)}'
      '${'m48'.padLeft(6)}${'m49'.padLeft(6)}   verdict');
  var bad = 0;
  for (final s in inputs) {
    final t = trueDistance(rules, top, s, alphabet, maxEdits);
    final want = t?.toString() ?? '>$maxEdits';
    final r46 = cell(e46.recoverCost, s);
    final r48 = cell(e48.recoverCost, s);
    final r49 = cell(e49.recoverCost, s);

    bool ok;
    if (disallowUnderReport) {
      if (t != null) {
        final c = int.tryParse(r49);
        ok = c != null && c >= t && c <= maxEdits;
      } else {
        ok = r49 == '>$maxEdits';
      }
    } else {
      ok = agreesWith(t, r49);
    }
    if (!ok) bad++;
    print('${(s.isEmpty ? '<empty>' : s).padRight(12)}${want.padLeft(6)}'
        '${r46.padLeft(6)}${r48.padLeft(6)}${r49.padLeft(6)}   '
        '${!ok ? "MISMATCH" : "ok"}');
  }
  print(bad == 0
      ? 'm49: 100% compliant'
      : '$bad of ${inputs.length} non-compliant');
}

void main() {
  print('=== BLOCK A: m47 leak sanity check (must NOT under-report) ===');
  block(
      "A1. S <- &'x' A B; A <- 'y'?; B <- 'x';",
      "S <- &'x' A B;\nA <- 'y'?;\nB <- 'x';\n",
      'S',
      'xy',
      ['x', 'yx', 'y', 'xx', ''],
      disallowUnderReport: true);

  block(
      "A2. S <- &'x' A; A <- 'y'?;",
      "S <- &'x' A;\nA <- 'y'?;\n",
      'S',
      'xy',
      ['x', 'y', ''],
      disallowUnderReport: true);

  block(
      "A3. S <- &'x' A 'x'; A <- 'y'?;",
      "S <- &'x' A 'x';\nA <- 'y'?;\n",
      'S',
      'xy',
      ['x', 'yx', 'y', ''],
      disallowUnderReport: true);

  print('\n=== BLOCK B: lookahead reader behind rule ref ===');
  block(
      "B1. S <- !'x' R; R <- A; A <- 'x' / \"yy\";",
      "S <- !'x' R;\nR <- A;\nA <- 'x' / \"yy\";\n",
      'S',
      'xy',
      ['', 'x', 'y', 'yy', 'xyy', 'q'],
      disallowUnderReport: false);

  print('\n=== BLOCK C: lookahead across rule boundary (I7 target) ===');
  block(
      "C1. S <- R 'x'; R <- &'x';",
      "S <- R 'x';\nR <- &'x';\n",
      'S',
      'x',
      ['x', '', 'xx'],
      disallowUnderReport: false);

  block(
      "C2. S <- R A; R <- !'y'; A <- 'y' / \"xx\";",
      "S <- R A;\nR <- !'y';\nA <- 'y' / \"xx\";\n",
      'S',
      'xy',
      ['xx', 'y', 'yy', 'x', ''],
      disallowUnderReport: false);

  print('\n=== BLOCK D: practical grammars with inter-rule lookaheads ===');
  block(
      "D1. S <- Kw [a-z]+; Kw <- \"if\" !Alpha; Alpha <- [a-z];",
      "S <- Kw Tail;\nKw <- \"if\" !Alpha;\nAlpha <- [a-z];\nTail <- [a-z]+;\n",
      'S',
      'ifab',
      ['if', 'ifa', 'ifab', 'i', 'q'],
      disallowUnderReport: false);

  block(
      "D2. S <- Top; Top <- Head Tail; Head <- 'a' &'b'; Tail <- 'b' 'c';",
      "S <- Top;\nTop <- Head Tail;\nHead <- 'a' &'b';\nTail <- 'b' 'c';\n",
      'S',
      'abc',
      ['abc', 'ab', 'ac', 'a', 'bc'],
      disallowUnderReport: false);
}
