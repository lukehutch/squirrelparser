// Exhaustive small-string gate: the same 14 grammars and 2,387 inputs as
// _subset75.dart, with truth obtained by pure-parser edit-ball enumeration.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm75.dart' as old;
import 'm76.dart' as now;

bool inLang(Map<String, Clause> r, String t, String s) {
  final p = Parser(rules: r, topRuleName: t, input: s).parse();
  return !p.hasSyntaxErrors && p.root.len == s.length;
}

int? trueDist(Map<String, Clause> r, String t, String s, String alpha) {
  var frontier = {s};
  final seen = {s};
  for (var k = 0; k <= 3; k++) {
    if (frontier.any((x) => inLang(r, t, x))) return k;
    final next = <String>{};
    for (final x in frontier) {
      for (var i = 0; i < x.length; i++) {
        final y = x.substring(0, i) + x.substring(i + 1);
        if (seen.add(y)) next.add(y);
      }
      for (var i = 0; i <= x.length; i++) {
        for (final ch in alpha.split('')) {
          final ins = x.substring(0, i) + ch + x.substring(i);
          if (seen.add(ins)) next.add(ins);
          if (i < x.length) {
            final sub = x.substring(0, i) + ch + x.substring(i + 1);
            if (seen.add(sub)) next.add(sub);
          }
        }
      }
    }
    frontier = next;
  }
  return null;
}

final grammars = <(String, String, String)>[
  ("S <- 'a'* \"ab\";\n", 'S', 'ab'),
  ("S <- ('a' / \"ab\") 'b';\n", 'S', 'ab'),
  ("S <- A 'c';\nA <- 'a' / \"ab\";\n", 'S', 'abc'),
  ("S <- 'a'? \"ab\";\n", 'S', 'ab'),
  ("S <- (A / B) T;\nA <- 'a' &'x';\nB <- 'a';\nT <- 'x' / 'y';\n", 'S', 'axy'),
  ("S <- (A / 'a') 'b' 'x';\nA <- 'a' &('b' 'x');\n", 'S', 'abx'),
  ("S <- !'x' ('a' / 'x') 'b';\n", 'S', 'abx'),
  ("S <- ('a' &'b' / 'a' / 'b')* !.;\n", 'S', 'ab'),
  ("S <- A B;\nA <- 'a' 'a' / 'a';\nB <- 'a' 'b' / 'b';\n", 'S', 'ab'),
  ("S <- ('a' 'b')* 'a' !.;\n", 'S', 'ab'),
  ("S <- &(A 'b') A 'b' 'x';\nA <- 'a'*;\n", 'S', 'abx'),
  ("S <- ('a' / 'b' 'a')* \"bb\";\n", 'S', 'ab'),
  ("S <- A2 A2;\nA2 <- A1 A1;\nA1 <- B B;\nB <- 'a'? \"ab\";\n", 'S', 'ab'),
  ("S <- [a-z] / 'a' / '0';\n", 'S', 'a0'),
];

void main() {
  var checked = 0, wrong75 = 0, wrong76 = 0, differences = 0, uncertified = 0;
  for (final (grammar, top, alpha) in grammars) {
    final rules = MetaGrammar.parseGrammar(grammar);
    final a = old.SuperDot3(rules: rules, topRuleName: top);
    final b = now.SuperDot3(rules: rules, topRuleName: top);
    final strings = <String>[''];
    for (var len = 1; len <= 5; len++) {
      for (final prefix
          in strings.where((s) => s.length == len - 1).toList()) {
        for (final ch in alpha.split('')) strings.add(prefix + ch);
      }
    }
    var gw75 = 0, gw76 = 0;
    for (final s in strings) {
      final truth = trueDist(rules, top, s, alpha);
      bool ok(int c) => truth == null ? c == -1 || c > 3 : c == truth;
      final c75 = a.recoverCost(s), c76 = b.recoverCost(s);
      if (c76 >= 0 && !b.lastVerified) uncertified++;
      checked++;
      if (!ok(c75)) { wrong75++; gw75++; }
      if (!ok(c76)) {
        wrong76++; gw76++;
        if (wrong76 <= 20) {
          print('WRONG s="$s" truth=${truth ?? ">3"} m76=$c76  '
              '${grammar.replaceAll('\n', ' ').trim()}');
        }
      }
      if (c75 != c76) differences++;
    }
    print('$gw75/$gw76 wrong m75/m76  ${grammar.replaceAll('\n', ' ').trim()}');
  }
  print('checked=$checked m75wrong=$wrong75 m76wrong=$wrong76 '
      'costDifferences=$differences uncertifiedFinite=$uncertified');
}
