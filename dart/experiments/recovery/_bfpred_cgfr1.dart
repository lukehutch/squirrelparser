// Scratch: cgfr1 against BRUTE-FORCE ground truth, next to m46.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm46.dart' as g46;
import 'cgfr1.dart' as g49;

bool inLanguage(Map<String, Clause> rules, String top, String s) {
  final p = Parser(rules: rules, topRuleName: top, input: s).parse();
  return !p.hasSyntaxErrors && p.root != null && p.root!.len == s.length;
}

const maxEdits = 2;

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

bool agreesWith(int? truth, String got) {
  if (truth != null) return got == truth.toString();
  final n = int.tryParse(got);
  return n == null || n < 0 || n > maxEdits;
}

String cell(int Function(String) costFn, String input) {
  final c = costFn(input);
  return c < 0 || c > maxEdits ? '>$maxEdits' : c.toString();
}

void block(String title, String src, String top, String alphabet,
    List<String> inputs) {
  print('\n$title');
  final rules = MetaGrammar.parseGrammar(src);
  final e46 = g46.SuperDot3(rules: rules, topRuleName: top);
  final e49 = g49.SuperDot3(rules: rules, topRuleName: top);
  print('${'input'.padRight(9)}${'true'.padLeft(6)}'
      '${'m46'.padLeft(6)}${'m49'.padLeft(6)}   verdict');
  var bad = 0;
  for (final s in inputs) {
    final t = trueDistance(rules, top, s, alphabet, maxEdits);
    final want = t?.toString() ?? '>$maxEdits';
    final r46 = cell(e46.recoverCost, s);
    final r49 = cell(e49.recoverCost, s);
    final ok = agreesWith(t, r49);
    if (!ok) bad++;
    print('${(s.isEmpty ? '<empty>' : s).padRight(9)}${want.padLeft(6)}'
        '${r46.padLeft(6)}${r49.padLeft(6)}   ${!ok ? "MISMATCH" : "ok"}');
  }
  print(bad == 0
      ? 'm49: 100% agreement with brute force'
      : '$bad of ${inputs.length} disagree');
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

void main() {
  block(
      "1. S <- !'x' A; A <- 'x' / \"yy\";",
      "S <- !'x' A;\nA <- 'x' / \"yy\";\n",
      'S',
      'xy',
      ['', 'x', 'y', 'yy', 'xyy', 'q']);

  block("2. S <- Kw; Kw <- \"if\" !Alpha; Alpha <- [a-z];",
      "S <- Kw;\nKw <- \"if\" !Alpha;\nAlpha <- [a-z];\n", 'S', 'afiq', [
    'if',
    'ifa',
    'if1',
    'i',
    'f',
    'q',
  ]);

  block("3. S <- A 'b'; A <- 'a' &'b' / 'c';",
      "S <- A 'b';\nA <- 'a' &'b' / 'c';\n", 'S', 'abcx', [
    'ab',
    'cb',
    'a',
    'c',
    'axb',
    'abx',
  ]);

  block("4. S <- (!'\"' .)* '\"';", "S <- (!'\"' .)* '\"';\n", 'S', 'x"a', [
    '"',
    'x"',
    '""',
    'x',
    'ab"',
  ]);

  block("5. S <- &'x' 'x' / 'y' 'y' 'y' 'y';",
      "S <- &'x' 'x' / 'y' 'y' 'y' 'y';\n", 'S', 'xy', [
    'x',
    'yyyy',
    '',
    'y',
    'yy',
    'yyy',
    'yx',
  ]);

  block("6. S <- !'x' A B; A <- 'a'?; B <- 'b' / 'x';",
      "S <- !'x' A B;\nA <- 'a'?;\nB <- 'b' / 'x';\n", 'S', 'abx', [
    'b',
    'ab',
    'ax',
    'x',
    '',
    'a',
  ]);

  block("7. S <- (&[a-z] !'q' .)*;", "S <- (&[a-z] !'q' .)*;\n", 'S', 'abq', [
    '',
    'a',
    'ab',
    'q',
    'aq',
    'abq',
  ]);

  block(
      "8. S <- !('a' 'b') . . .;",
      "S <- !('a' 'b') . . .;\n",
      'S',
      'abc',
      ['ccc', 'abc', 'ab', 'a', '']);

  block("9. S <- (!'x' .)* 'x';", "S <- (!'x' .)* 'x';\n", 'S', 'axb', [
    'x',
    'ax',
    'aax',
    '',
    'a',
    'aa',
    'xb',
  ]);

  spelling(
    'CharSet inverted vs negative lookahead',
    "S <- [^x] [^x];\n",
    "S <- !'x' . !'x' .;\n",
    'xyz',
    ['yy', 'xy', 'yx', 'xx', 'y', 'x', ''],
  );

  spelling(
    'Optional-chain character class vs negative lookahead',
    "S <- [^x]? [^x]?;\n",
    "S <- (!'x' .)? (!'x' .)?;\n",
    'xyz',
    ['yy', 'y', '', 'xy', 'yx', 'xx', 'x'],
  );
}
