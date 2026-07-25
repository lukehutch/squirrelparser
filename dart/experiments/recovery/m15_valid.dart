// Robustness floor: a VALID document must come back untouched, cost 0, with the
// pure parser's own tree. An objective that can be bribed into editing valid
// input is worthless no matter how good its repairs are.
import 'package:squirrel_parser/squirrel_parser.dart';
import "m15.dart";

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
  final sd = SuperDot3(rules: rules, topRuleName: 'JSON');
  const docs = [
    '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}',
    '[]',
    '{}',
    '  [1, 2, [3, {"x": -4.5e+6}], false, null]  ',
    '{"s":"a\\\\u00ffb\\\\n\\\\t","n":-0.5,"deep":{"a":{"b":{"c":[[[1]]]}}}}',
    '"just a string"',
    '0',
  ];
  var bad = 0;
  for (final d in docs) {
    final pure = Parser(rules: rules, topRuleName: 'JSON', input: d).parse();
    if (pure.hasSyntaxErrors) {
      print('SKIP (not valid to begin with): $d');
      continue;
    }
    final r = sd.recover(d);
    final clean = sd.lastCost == 0 && r.errorSpans.isEmpty && r.missing.isEmpty;
    if (!clean) {
      bad++;
      print('CORRUPTED "$d" -> cost=${sd.lastCost} spans=${r.errorSpans} '
          'missing=${r.missing}');
    }
  }
  print('valid documents left untouched: ${docs.length - bad}/${docs.length}'
      '  regret of clean parse is reported, cost is 0');
}
