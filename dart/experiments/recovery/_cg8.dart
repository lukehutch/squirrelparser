import 'package:squirrel_parser/squirrel_parser.dart';
import 'cgfr1.dart' as cg;
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
void main() {
  // final_table's exact case 8: seed 12345+64 scramble of 64 chars at pos 30

  final big = '{"users":[{"id":1,"name":"ann","tags":["x","y"]},'
      '{"id":2,"name":"bob","tags":["z"]},{"id":3,"name":"cyd","tags":[]}],'
      '"total":3,"ok":true}';
  final ch = big.substring(30, 94).split('')..shuffle();
  final case8 = big.substring(0, 30) + ch.join() + big.substring(94);
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final e = cg.SuperDot3(rules: rules, topRuleName: 'JSON');
  final sw = Stopwatch()..start();
  final c = e.recoverCost(case8);
  print('cgfr1 case8-class: cost=$c in ${sw.elapsedMilliseconds}ms');
}
