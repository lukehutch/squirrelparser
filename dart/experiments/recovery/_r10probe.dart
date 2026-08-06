import 'package:squirrel_parser/squirrel_parser.dart' as sp;
import 'r10.dart' as r10;

void main() {
  final cases = <(String, String, List<String>)>[
    ("S <- Item+;\nItem <- 'a' 'b';\n", 'S', ['abab', 'abXab', 'abaXb', 'ab', 'XXab']),
    ("S <- '[' N (',' N)* ']';\nN <- [0-9]+;\n", 'S', ['[1,2]', '[1,,2]', '[1;2]', '[1,2', 'X[1,2]']),
  ];
  for (final (g, top, inputs) in cases) {
    final rules = sp.MetaGrammar.parseGrammar(g);
    final eng = r10.Squirrel(rules: rules, topRuleName: top);
    for (final s in inputs) {
      print('=== "$s" ===');
      try {
        print(eng.recover(s).toPrettyString(s));
      } catch (e) {
        print('THREW: $e');
      }
    }
  }
}
