// m71 battery throughput, measured as an adjacent pair with m53 in one
// process. The final_table latency protocol is unviable for m59 -- latency
// case 8 exceeds ~10 minutes per call, and min-of-5 ran to 58 CPU-minutes
// before being killed -- so the battery pair is measured alone, with
// final_table's own corpus construction replicated verbatim.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm70.dart' as a;
import 'm62.dart' as b;

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
  bool parses(String s) => !Parser(rules: rules, topRuleName: 'JSON', input: s)
      .parse()
      .hasSyntaxErrors;
  final mutants = <String>[];
  for (var j = 0; j < base.length; j++) {
    mutants.add(base.substring(0, j) + base.substring(j + 1));
    if (j + 1 < base.length && base[j] != base[j + 1]) {
      mutants.add(
          base.substring(0, j) + base[j + 1] + base[j] + base.substring(j + 2));
    }
  }
  for (var j = 0; j <= base.length; j++) {
    for (final ch in ['Q', 'z', '}', '"', ',', '5']) {
      mutants.add(base.substring(0, j) + ch + base.substring(j));
      if (j < base.length) {
        mutants.add(base.substring(0, j) + ch + base.substring(j + 1));
      }
    }
  }
  final battery = [
    for (final m in mutants)
      if (!parses(m)) m
  ];
  print('battery=${battery.length}');
  for (final (name, recover) in [
    ('m70', a.SuperDot3(rules: rules, topRuleName: 'JSON').recover),
    ('m62', b.SuperDot3(rules: rules, topRuleName: 'JSON').recover),
  ]) {
    final sw = Stopwatch()..start();
    for (final m in battery) {
      recover(m);
    }
    print('$name battms=${sw.elapsedMilliseconds}');
  }
}
