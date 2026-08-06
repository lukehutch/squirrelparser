// The four load-bearing checks on cgfr1: swap metric, alphabet size,
// battery timing vs m68, and the case-8 latency behavior (bounded probe).
import 'package:squirrel_parser/squirrel_parser.dart';
import 'cgfr1.dart' as cg;
import 'm68.dart' as std;

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
  const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';
  final e = cg.SuperDot3(rules: rules, topRuleName: 'JSON');
  final s = std.SuperDot3(rules: rules, topRuleName: 'JSON');

  // 1) swap metric: adjacent transposition of the base doc (battery swap
  //    mutant class; the line's brute-force truth prices these at 2)
  var swaps = 0, cheap = 0;
  for (var j = 0; j + 1 < base.length; j++) {
    if (base[j] == base[j + 1]) continue;
    final mut = base.substring(0, j) + base[j + 1] + base[j] + base.substring(j + 2);
    final truth = s.recoverCost(mut); // m68 = gate-verified truth on battery
    if (truth != 2) continue;
    swaps++;
    final c = e.recoverCost(mut);
    if (c < truth) cheap++;
  }
  print('swap mutants with truth 2: $swaps   cgfr1 cheaper-than-truth: $cheap');

  // 2) alphabet size
  print('alphabet size for JSON: ${e.debugAlphabetSize}');
}
