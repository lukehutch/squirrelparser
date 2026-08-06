// Is the (cell, slot) -> dependency-cell mapping INVARIANT across relaxations?
// If it is, every read after the first on a given slot is a `_cells` map lookup
// that could have been a field load -- which is exactly the per-relaxation constant
// that m50/m51 pay over m49's descent.
import 'package:squirrel_parser/squirrel_parser.dart';
import '_dep52.dart' as gp;

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
~WS <- [ \t\n\r]*;
''';

const String lrGrammar = '''
E <- E '+' T / T;
T <- T '*' F / F;
F <- [0-9]+ / '(' E ')';
''';
const String rrGrammar = '''
S <- 'a' S / 'a';
''';
const String predGrammar = '''
S <- Kw / Id;
Kw <- "if" !Alpha;
Id <- Alpha+;
Alpha <- [a-zA-Z];
''';

final big = '{"users":[{"id":1,"name":"ann","tags":["x","y"]},'
    '{"id":2,"name":"bob","tags":["z"]},{"id":3,"name":"cyd","tags":[]}],'
    '"total":3,"ok":true}';

void probe(String label, String grammar, String top, List<String> inputs) {
  final rules = MetaGrammar.parseGrammar(grammar);
  final e = gp.SuperDot3(rules: rules, topRuleName: top);
  for (final s in inputs) {
    e.recoverCost(s);
  }
  print('$label reads=${e.probeReads} stable=${e.probeStable} '
      'violations=${e.probeViolations}');
}

void main() {
  final at = big.indexOf('},{');
  probe('JSON  ', jsonGrammar, 'JSON', [
    big.substring(0, 10) + big.substring(11),
    big.substring(0, at + 1) + '@@@' + big.substring(at + 1),
    '{"a":1,"b":[2,3}',
  ]);
  probe('LR    ', lrGrammar, 'E', ['1+2++3', '1*(2+3', '((1+2)*3']);
  probe('RR    ', rrGrammar, 'S', ['aaaa?aaaa', 'aa!aa']);
  probe('PRED  ', predGrammar, 'S', ['ifx', 'i', 'if?']);
}
