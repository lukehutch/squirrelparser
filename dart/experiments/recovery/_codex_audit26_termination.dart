// Termination pressure for the exact-list left-recursion improvement test.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'r5.dart' as r5;
import '_v14.dart' as v14;

void main() {
  final grammars = <String>[
    'S <- S;',
    "S <- S / 'a';",
    "S <- S 'a'? / 'b';",
    "S <- S S / 'a';",
    "S <- S* / 'a';",
    "S <- S? 'a'? / 'b';",
    "S <- A / 'a'; A <- S;",
    "S <- A / 'a'; A <- B; B <- S 'b'?;",
    "S <- S A / A*; A <- .;",
    "S <- S A? / A*; A <- .;",
    "S <- S (A / B) / (A / B)*; A <- .; B <- [^x];",
    "S <- S ('a' / .) / ('a' / .)*;",
    "S <- A; A <- A 'a' / \"ab\"*;",
    "S <- A; A <- B / (\"ab\" .); B <- A 'b';",
    "S <- (A / B)*; A <- A 'a' / .; B <- [^x];",
  ];
  final inputs = ['', 'a', 'b', 'x', 'aa', 'ab', 'ba', 'aaa', 'baa', 'abab', 'aaaaaa'];
  var runs = 0;
  var maxUs = 0;
  String slow = '';
  for (var i = 0; i < grammars.length; i++) {
    final rules = MetaGrammar.parseGrammar(grammars[i]);
    for (final input in inputs) {
      for (final e in <dynamic>[
        r5.Squirrel(rules: rules, topRuleName: 'S'),
        v14.Squirrel(rules: rules, topRuleName: 'S'),
      ]) {
        final sw = Stopwatch()..start();
        e.recover(input);
        sw.stop();
        runs++;
        if (sw.elapsedMicroseconds > maxUs) {
          maxUs = sw.elapsedMicroseconds;
          slow = 'grammar#$i input="$input" engine=${e.runtimeType}';
        }
      }
    }
  }
  print('termination runs=$runs completed; slowest_us=$maxUs $slow');
}
