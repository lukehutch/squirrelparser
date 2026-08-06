import 'package:squirrel_parser/squirrel_parser.dart';
import 'cgfr2.dart' as a;
void main() {
  final cases = <(String, String, String)>[
    ('committed choice', "S <- ('a' / \"ab\") 'b';\n", 'abb'),
    ('possessive star', "S <- 'a'* \"ab\";\n", 'aab'),
  ];
  for (final (name, g, s) in cases) {
    final r = MetaGrammar.parseGrammar(g);
    print('--- $name on "$s"');
    try {
      final c = a.SuperDot3(rules: r, topRuleName: 'S').recoverCost(s);
      print('   cost=$c');
    } catch (e, st) {
      print('   THREW: ${e.runtimeType}: ${e.toString().split("\n").first}');
      print('   ${st.toString().split("\n").take(3).join("\n   ")}');
    }
  }
}
