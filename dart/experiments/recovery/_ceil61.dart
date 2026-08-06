// m57's ceiling-free completeness: the three _ceil44 cases (truths 60/46/30),
// the empty language (instant -1), and the _pceil44 predicate-ceiling cases.
// m53 runs beside it as the reference.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm53.dart' as a;
import 'm61.dart' as b;

void one(String label, String g, String top, String input, String want) {
  final ea = a.SuperDot3(rules: MetaGrammar.parseGrammar(g), topRuleName: top);
  final eb = b.SuperDot3(rules: MetaGrammar.parseGrammar(g), topRuleName: top);
  final sw = Stopwatch()..start();
  final ca = ea.recoverCost(input);
  final ta = sw.elapsedMilliseconds;
  sw.reset();
  final cb = eb.recoverCost(input);
  final tb = sw.elapsedMilliseconds;
  print('${label.padRight(46)} want=$want  m53=$ca (${ta}ms)  m61=$cb (${tb}ms)');
}

void main() {
  one('skip 59 + sub 1', "S <- 'x';\n", 'S', 'z' * 60, '60');
  one('fabricate 46-char literal from empty',
      "S <- \"0123456789012345678901234567890123456789012345\";\n", 'S', '', '46');
  one('skip 29 + sub 1', "S <- 'x';\n", 'S', 'z' * 30, '30');
  one('empty language: no search', "S <- S 'a';", 'S', 'aaa', '-1');
  one('pceil: pred blocks cheap branch',
      "S <- &'x' 'x' / 'y' 'y' 'y' 'y';", 'S', '', '1');
  one('pceil: lookahead-only rule', "S <- &'x' 'y';", 'S', 'x', '-1');
}
