import 'dart:math';
import 'package:squirrel_parser/squirrel_parser.dart';
import '_prof58.dart' as e;

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
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final big = '{"users":[{"id":1,"name":"ann","tags":["x","y"]},'
      '{"id":2,"name":"bob","tags":["z"]},{"id":3,"name":"cyd","tags":[]}],'
      '"total":3,"ok":true}';
  final ch = big.substring(30, 30 + 64).split('')..shuffle(Random(12345 + 64));
  final case8 = big.substring(0, 30) + ch.join() + big.substring(30 + 64);
  final eng = e.SuperDot3(rules: rules, topRuleName: 'JSON');
  final sw = Stopwatch()..start();
  final c = eng.recoverCost(case8);
  print('cost=$c ms=${sw.elapsedMilliseconds} steps=${eng.lastSteps} '
      'cells=${eng.lastCells}');
  print('headIters=${eng.dbgHeadIters} combos=${eng.dbgCombos} '
      'dirties=${eng.dbgDirties} pushes=${eng.dbgPushes} edges=${eng.lastEdges}');
}
