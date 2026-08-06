// The PEG-conformance gate for cgfr2.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm62.dart' as a;
import 'cgfr2.dart' as b;

final cases = <(String, String, String, String, int?)>[
  ('possessive star', "S <- 'a'* \"ab\";\n", 'S', 'aab', null),
  ('possessive star+', "S <- 'a'* \"ab\";\n", 'S', 'aaaab', null),
  ('committed choice', "S <- ('a' / \"ab\") 'b';\n", 'S', 'abb', 1),
  ('committed nested', "S <- A 'c';\nA <- 'a' / \"ab\";\n", 'S', 'abc', 1),
  ('greedy optional', "S <- 'a'? \"ab\";\n", 'S', 'aab', 0),
];

void main() {
  var ok = 0;
  print('case                truth   m62   cgfr2  verdict');
  for (final (name, g, top, s, truth) in cases) {
    final r = MetaGrammar.parseGrammar(g);
    final c62 = a.SuperDot3(rules: r, topRuleName: top).recoverCost(s);
    final e63 = b.SuperDot3(rules: r, topRuleName: top);
    final c63 = e63.recoverCost(s);
    final good = truth == null ? c63 == -1 : c63 == truth;
    if (good) ok++;
    print('${name.padRight(18)} ${(truth?.toString() ?? 'none').padLeft(5)} '
        '${c62.toString().padLeft(5)} ${c63.toString().padLeft(5)}  '
        '${good ? 'ok' : 'WRONG'}');
  }
  print('\ncgfr2 conformance: $ok/5');
}
