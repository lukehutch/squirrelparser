// Direct stack probe for m59: one right-recursive 1-error input per size, no
// ladder, no bisect. Completing without StackOverflowError at size n confirms
// the ceiling is >= n.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm59.dart' as e;

const rr = "E <- T '+' E / T;\nT <- F '*' T / F;\nF <- [0-9] / '(' E ')';\n";

String mk(int k) {
  final c = List.generate(k, (i) => '${i % 10}').join('+');
  final mid = c.length ~/ 2;
  return '${c.substring(0, mid)}+${c.substring(mid)}';
}

void main() {
  final rules = MetaGrammar.parseGrammar(rr);
  for (final k in [512, 1024, 2048]) {
    final sw = Stopwatch()..start();
    try {
      final eng = e.SuperDot3(rules: rules, topRuleName: 'E');
      final c = eng.recoverCost(mk(k));
      print('k=$k cost=$c ms=${sw.elapsedMilliseconds} ok');
    } on StackOverflowError {
      print('k=$k OVERFLOW ms=${sw.elapsedMilliseconds}');
    }
  }
}
