import 'package:squirrel_parser/squirrel_parser.dart';
import 'm76.dart' as e;

void main() {
  for (final g in [
    ("S <- &(A 'b') A 'b' 'x';\nA <- 'a'*;\n", ['', 'a', 'ab', 'abx']),
    ("S <- ('a' / \"ab\") 'b';\n", ['', 'ab', 'abb']),
    ("S <- 'a'? \"ab\";\n", ['', 'ab', 'aab']),
    ("S <- (\"ab\")* \"abc\";\n", ['', 'c', 'abc', 'ababc', 'abab']),
    ("S <- 'a'* \"ab\";\n", ['', 'a', 'b', 'ab', 'aab']),
  ]) {
    final rules = MetaGrammar.parseGrammar(g.$1);
    final x = e.SuperDot3(rules: rules, topRuleName: 'S');
    print('${g.$1.trim()} fabricate=${x.fabricationBound}');
    for (final s in g.$2) {
      print('  "$s" => ${x.recoverCost(s)} verified=${x.lastVerified}');
    }
  }
}
