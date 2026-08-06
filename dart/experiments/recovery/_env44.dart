// Scratch: what does COMPLETENESS cost? m43 stops deepening at 40 and reports
// -1; m44 deepens to the derived ceiling `n + fabricate(goal)`. Where the true
// repair is expensive, m43 gives up cheaply and m44 pays for the answer. This
// measures that price, honestly, on two grammars:
//
//   * `S <- 'x';` -- no escape hatch. A run of k junk characters costs k.
//   * JSON on a run of quotes -- a REAL grammar whose cheapest repair is still
//     linear in the damage, because "" is the only thing a quote run can become.
//
// Printed as it goes, because the point of the measurement is where it stops
// being affordable. One engine per process is not needed here: nothing is being
// compared at the few-percent level.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm43.dart' as g43;
import 'm44.dart' as g44;

const String jsonGrammar = '''
JSON <- WS Value WS;
Value <- Object / Array / String / Number / Boolean / Null;
Object <- '{' WS (Member (WS ',' WS Member)*)? WS '}';
Member <- String WS ':' WS Value;
Array <- '[' WS (Value (WS ',' WS Value)*)? WS ']';
String <- '"' Character* '"';
Character <- [^"\\\\] / ('\\\\' Escape);
Escape <- '"' / '\\\\' / '/' / 'b' / 'f' / 'n' / 'r' / 't' / ('u' [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F]);
Number <- Integer Fraction? Exponent?;
Integer <- '-'? (([1-9] [0-9]+) / [0-9]);
Fraction <- '.' [0-9]+;
Exponent <- ("e" / "E") ("+" / "-")? [0-9]+;
Boolean <- "true" / "false";
Null <- "null";
~WS <- [ \\t\\n\\r]*;
''';

void bench(String label, String grammar, String top, List<String> inputs) {
  final rules = MetaGrammar.parseGrammar(grammar);
  print('\n$label');
  print('${'n'.padLeft(5)}${'m43'.padLeft(7)}${'ms'.padLeft(9)}'
      '${'m44'.padLeft(7)}${'ms'.padLeft(9)}');
  for (final input in inputs) {
    final w1 = Stopwatch()..start();
    final a = g43.SuperDot3(rules: rules, topRuleName: top).recoverCost(input);
    w1.stop();
    final w2 = Stopwatch()..start();
    final b = g44.SuperDot3(rules: rules, topRuleName: top).recoverCost(input);
    w2.stop();
    print('${input.length.toString().padLeft(5)}${a.toString().padLeft(7)}'
        '${w1.elapsedMilliseconds.toString().padLeft(9)}'
        '${b.toString().padLeft(7)}'
        '${w2.elapsedMilliseconds.toString().padLeft(9)}');
  }
}

void main() {
  bench('no escape hatch: S <- \'x\'; on a run of z', "S <- 'x';\n", 'S', [
    for (final k in [30, 60, 80, 120, 160, 240, 320, 480, 640]) 'z' * k
  ]);
  bench('real grammar: JSON on a run of quotes', jsonGrammar, 'JSON',
      [for (final k in [16, 32, 48, 100, 150, 200]) '"' * k]);
}
