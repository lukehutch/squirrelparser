// TEMP: where does I29's pointer chase stop?
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm72.dart' as e72;

final cases = <(String, String, List<String>)>[
  ("S <- ('a' / \"ab\") 'b';\n", 'S', ['', 'a', 'b', 'aa']),
  ("S <- 'a'* \"ab\";\n", 'S', ['a', 'b', 'ab']),
  ("S <- A B;\nA <- 'a' 'a' / 'a';\nB <- 'a' 'b' / 'b';\n", 'S', ['a', 'aa']),
];

void main() {
  final tally = <String, int>{};
  for (final (g, top, ss) in cases) {
    final r = MetaGrammar.parseGrammar(g);
    final e = e72.SuperDot3(rules: r, topRuleName: top);
    for (final s in ss) {
      final c = e.recoverCost(s);
      print('${g.replaceAll('\n', ' ').trim()}  s="$s" cost=$c '
          'verified=${e.lastVerified}');
      if (!e.lastVerified) {
        print('    FAIL: ${e.lastFail}');
        final k = (e.lastFail ?? '?').split(' ').first;
        tally[k] = (tally[k] ?? 0) + 1;
      }
    }
  }
  print('');
  print('failure kinds: $tally');
}
