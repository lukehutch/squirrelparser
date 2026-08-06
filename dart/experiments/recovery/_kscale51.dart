// THE K AXIS, WHICH NOTHING ELSE IN THE FILE EXERCISES. Every latency case in
// `final_table` damages a CONTIGUOUS run, and a contiguous run of junk is ONE skip
// by A1's unit edge -- so those cases cost 1 or 2 and never reach a third deepening
// round. Scattering the damage costs one repair per site, so k really is k.
//
// Steps only, and both engines in one process: relaxation counts are deterministic,
// so nothing here is a timing.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm49.dart' as g49;
import 'm51.dart' as g51;

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

String scatter(int k) {
  final buf = StringBuffer();
  final stride = big.length ~/ (k + 1);
  for (var i = 0; i < big.length; i++) {
    buf.write(big[i]);
    if (i % stride == stride - 1 && buf.length < big.length + k) buf.write('@');
  }
  return buf.toString();
}

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final a = g49.SuperDot3(rules: rules, topRuleName: 'JSON');
  final b = g51.SuperDot3(rules: rules, topRuleName: 'JSON');
  print('  k  cost  m49 steps  m51 steps  ratio  cells  perCell');
  for (final k in [1, 2, 3, 4, 5, 6, 8]) {
    final s = scatter(k);
    final ca = a.recoverCost(s);
    final sa = a.lastSteps;
    final cb = b.recoverCost(s);
    print('${k.toString().padLeft(3)}  ${cb.toString().padLeft(4)}  '
        '${sa.toString().padLeft(9)}  ${b.lastSteps.toString().padLeft(9)}  '
        '${(b.lastSteps / sa).toStringAsFixed(2).padLeft(5)}x  '
        '${b.lastCells.toString().padLeft(5)}  '
        '${b.lastPerCell.toStringAsFixed(2)}${ca == cb ? '' : '  COST DIFFERS $ca'}');
  }
}
