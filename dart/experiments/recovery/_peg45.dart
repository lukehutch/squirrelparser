// Scratch: the 5 peg_conformance cases, for m45 against m44 and m26. The
// PEG-vs-CFG reading is a documented flaw of the whole line (LESSONS 5b); this
// gate only has to establish that m45 adds no conformance regression.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm26.dart' as g26;
import 'm44.dart' as g44;
import 'm45.dart' as g45;

final cases = <(String, String, String, String, int?)>[
  ('possessive star', "S <- 'a'* \"ab\";\n", 'S', 'aab', null),
  ('possessive star+', "S <- 'a'* \"ab\";\n", 'S', 'aaaab', null),
  ('committed choice', "S <- ('a' / \"ab\") 'b';\n", 'S', 'abb', 1),
  ('committed nested', "S <- A 'c';\nA <- 'a' / \"ab\";\n", 'S', 'abc', 1),
  ('greedy optional', "S <- 'a'? \"ab\";\n", 'S', 'aab', 0),
];

void main() {
  print('case                truth    m26    m44    m45');
  var diff = 0;
  for (final (name, g, top, s, truth) in cases) {
    final r = MetaGrammar.parseGrammar(g);
    String run(int Function() f) {
      try {
        return f().toString();
      } catch (_) {
        return 'X';
      }
    }

    final a = run(() => g26.SuperDot3(rules: r, topRuleName: top).recoverCost(s));
    final b = run(() => g44.SuperDot3(rules: r, topRuleName: top).recoverCost(s));
    final c = run(() => g45.SuperDot3(rules: r, topRuleName: top).recoverCost(s));
    if (a != c) diff++;
    print('${name.padRight(18)} ${(truth?.toString() ?? '>3').padLeft(5)} '
        '${a.padLeft(6)}${b.padLeft(7)}${c.padLeft(7)}'
        '${a == c ? '' : '  <-- DIFFERS from m26'}');
  }
  print('\nm44 vs m26 differences: $diff');
}
