// The five true-PEG conformance cases used for m75 and earlier engines.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm76.dart' as e;

final cases = <(String, String, String, int)>[
  ('possessive star', "S <- 'a'* \"ab\";\n", 'aab', -1),
  ('possessive star+', "S <- 'a'* \"ab\";\n", 'aaaab', -1),
  ('committed choice', "S <- ('a' / \"ab\") 'b';\n", 'abb', 1),
  ('committed nested', "S <- A 'c';\nA <- 'a' / \"ab\";\n", 'abc', 1),
  ('greedy optional', "S <- 'a'? \"ab\";\n", 'aab', 0),
];

void main() {
  var passed = 0;
  for (final (name, grammar, input, expected) in cases) {
    final rules = MetaGrammar.parseGrammar(grammar);
    final got = e.SuperDot3(rules: rules, topRuleName: 'S').recoverCost(input);
    final ok = got == expected;
    if (ok) passed++;
    print('$name expected=$expected got=$got ${ok ? "PASS" : "FAIL"}');
  }
  print('conformance=$passed/${cases.length}');
}
