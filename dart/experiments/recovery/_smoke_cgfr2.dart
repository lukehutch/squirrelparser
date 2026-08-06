// Smoke test suite for cgfr2.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'cgfr2.dart' as candidate;

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
WS <- [ \\t\\n\\r]*;
''';

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final eng = candidate.SuperDot3(rules: rules, topRuleName: 'JSON');

  final validCases = ['"a"', '1', 'true', 'false', 'null', '{"a":1}', '[1,2]'];
  for (final s in validCases) {
    final res = eng.recover(s);
    assert(eng.lastCost == 0, 'Failed valid case $s: cost=${eng.lastCost}');
  }

  final invalidCases = ['{"a":}', '[1,]', '{"a"', '[1'];
  for (final s in invalidCases) {
    final res = eng.recover(s);
    assert(eng.lastCost > 0, 'Failed invalid case $s: cost=${eng.lastCost}');
  }

  print('cgfr2 smoke tests passed!');
}
