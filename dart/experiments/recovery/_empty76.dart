import 'package:squirrel_parser/squirrel_parser.dart';
import 'm76.dart' as e;

void main() {
  final g1 = MetaGrammar.parseGrammar("S <- (\"ab\")* \"abc\";\n");
  final a = e.SuperDot3(rules: g1, topRuleName: 'S');
  final five = ['', 'c', 'abc', 'ababc', 'abab'];
  final got = [for (final s in five) a.recoverCost(s)];
  final g2 = MetaGrammar.parseGrammar("S <- 'a'* \"ab\";\n");
  final b = e.SuperDot3(rules: g2, topRuleName: 'S');
  final xs = <String>[''];
  for (var n = 1; n <= 4; n++) {
    for (final p in xs.where((x) => x.length == n - 1).toList()) {
      xs..add('${p}a')..add('${p}b');
    }
  }
  final rejected = xs.where((s) => b.recoverCost(s) == -1).length;
  print('("ab")* "abc": ${five.indexed.map((x) => '"${x.$2}"=${got[x.$1]}').join(' ')} '
      'rejected=${got.where((x) => x == -1).length}/${five.length}');
  print("'a'* \"ab\": rejected=$rejected/${xs.length}");
}
