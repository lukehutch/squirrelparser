// WHERE THE 4x LATENCY GOES. m50 does 2.10x m49's relaxations on the JSON
// battery, whose repairs cost 1 or 2 -- but `latms` is 3.9x, and its worst cases
// are 64-character edits, i.e. ~64 deepening rounds. If the step ratio GROWS with
// the budget then the cost is in I8's folding of iterative deepening (a budget
// raise dirties a cell, whose readers cascade), not in late-discovered tails.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm49.dart' as g49;
import 'm50.dart' as g50;

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

final big = '{"users":[{"id":1,"name":"ann","tags":["x","y"]},'
    '{"id":2,"name":"bob","tags":["z"]},{"id":3,"name":"cyd","tags":[]}],'
    '"total":3,"ok":true}';

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final a = g49.SuperDot3(rules: rules, topRuleName: 'JSON');
  final b = g50.SuperDot3(rules: rules, topRuleName: 'JSON');
  print('kind        k   cost  m49 steps  m50 steps  ratio  cells  perCell');
  for (final (kind, mk) in <(String, String Function(int))>[
    ('insert @', (k) => big.substring(0, 30) + ('@' * k) + big.substring(30)),
    ('delete  ', (k) => big.substring(0, 30) + big.substring(30 + k)),
  ]) {
    for (final k in [1, 2, 4, 8, 16, 32, 64]) {
      final s = mk(k);
      final ca = a.recoverCost(s);
      final sa = a.lastSteps;
      final cb = b.recoverCost(s);
      print('$kind ${k.toString().padLeft(3)}  ${cb.toString().padLeft(5)}  '
          '${sa.toString().padLeft(9)}  ${b.lastSteps.toString().padLeft(9)}  '
          '${(b.lastSteps / sa).toStringAsFixed(2).padLeft(5)}x  '
          '${b.lastCells.toString().padLeft(5)}  '
          '${b.lastPerCell.toStringAsFixed(2)}${ca == cb ? '' : '   COST DIFFERS $ca'}');
    }
  }
}
