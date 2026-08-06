// Scratch: does m44's "a gap attaches to the next terminal" rule lose repairs
// that need a gap in front of a SYNTACTIC PREDICATE? A predicate consumes
// nothing but its outcome depends on WHERE it is evaluated, so pushing a gap
// past it is not free. Ground truth is brute force, as in bf_check.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm43.dart' as g43;
import 'm44.dart' as g44;

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

final cases = <(String, String, String, String, List<String>)>[
  (
    'leading not-predicate',
    "S <- !'x' 'b';\n",
    'S',
    'xb',
    ['b', 'xb', 'xxb', 'x', 'xbb'],
  ),
  (
    'not-predicate inside a sequence',
    "S <- 'a' !'x' 'b';\n",
    'S',
    'abx',
    ['ab', 'axb', 'axxb', 'ax', 'xab'],
  ),
  (
    'and-predicate',
    "S <- &'b' 'b' 'c';\n",
    'S',
    'bcx',
    ['bc', 'xbc', 'bxc', 'xxbc'],
  ),
  (
    'keyword boundary (the common real use)',
    "S <- K W;\nK <- \"if\" !L;\nW <- ' ' L;\nL <- [a-z];\n",
    'S',
    'ifq ',
    ['if q', 'ifq q', 'iff q', 'if  q', 'ifq'],
  ),
];

void main() {
  var bad43 = 0, bad44 = 0, n = 0;
  for (final (title, grammar, top, alphabet, inputs) in cases) {
    final rules = MetaGrammar.parseGrammar(grammar);
    final r43 = g43.SuperDot3(rules: rules, topRuleName: top);
    final r44 = g44.SuperDot3(rules: rules, topRuleName: top);
    print('\n$title   $grammar'.trim());
    print('${'input'.padRight(10)}${'true'.padLeft(6)}${'m43'.padLeft(6)}'
        '${'m44'.padLeft(6)}');
    for (final s in inputs) {
      n++;
      final t = trueDistance(rules, top, s, alphabet, 3);
      String cell(int Function(String) f) {
        try {
          return f(s).toString();
        } catch (e) {
          return 'X(${e.runtimeType})';
        }
      }

      final c43 = cell(r43.recoverCost);
      final c44 = cell(r44.recoverCost);
      final want = t?.toString() ?? '>3';
      if (c43 != want) bad43++;
      if (c44 != want) bad44++;
      print('${(s.isEmpty ? '<empty>' : s).padRight(10)}${want.padLeft(6)}'
          '${c43.padLeft(6)}${c44.padLeft(6)}'
          '  ${c43 == want && c44 == want ? '' : 'MISMATCH'}');
    }
  }
  print('\nwrong: m43=$bad43/$n  m44=$bad44/$n');
}
