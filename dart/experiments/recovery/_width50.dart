// END-MAP WIDTH -- the open item from LESSONS 5g, and the number that decides
// m50's mechanism.
//
// Removing the native recursion means recomputing a cell when a dependency
// settles instead of after all of them have. A cons cell has 1 + w dependencies,
// where w is its head's end-map width, so the mean w is the recompute factor a
// position-ordered worklist pays against the descent's measured 1.13 computes per
// cell. Small mean w => the worklist is affordable and the ceiling can be lifted
// to the oracle's own k~2100. Large mean w => it is not.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm49.dart' as g49;

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

const rr = "E <- T '+' E / T;\nT <- F '*' T / F;\nF <- [0-9] / '(' E ')';\n";
const lr = "E <- E '+' T / T;\nT <- T '*' F / F;\nF <- [0-9] / '(' E ')';\n";

const doc = '{"a":1,"b":[2,3],"c":{"d":"x"},"e":true,"f":null}';

void report(String label, g49.SuperDot3 eng, List<String> inputs) {
  final total = <int, int>{};
  for (final s in inputs) {
    if (eng.recoverCost(s) <= 0) continue;
    eng.lastWidths.forEach((w, c) => total[w] = (total[w] ?? 0) + c);
  }
  var cells = 0, sum = 0, maxW = 0, wide = 0;
  total.forEach((w, c) {
    cells += c;
    sum += w * c;
    if (w > maxW) maxW = w;
    if (w > 4) wide += c;
  });
  final keys = total.keys.toList()..sort();
  print('$label: $cells cells, mean width ${(sum / cells).toStringAsFixed(2)}, '
      'max $maxW, ${(wide / cells * 100).toStringAsFixed(1)}% wider than 4');
  print('  ${keys.take(12).map((w) => '$w:${total[w]}').join('  ')}'
      '${keys.length > 12 ? '  ...' : ''}');
}

void main() {
  final jsonRules = MetaGrammar.parseGrammar(jsonGrammar);
  final mutants = <String>[];
  for (var i = 0; i < doc.length; i++) {
    mutants.add(doc.substring(0, i) + doc.substring(i + 1));
    mutants.add('${doc.substring(0, i)}Q${doc.substring(i + 1)}');
    mutants.add('${doc.substring(0, i)}Q${doc.substring(i)}');
  }
  report('JSON  ', g49.SuperDot3(rules: jsonRules, topRuleName: 'JSON'), mutants);

  for (final (label, g) in [('RR    ', rr), ('LR    ', lr)]) {
    final rules = MetaGrammar.parseGrammar(g);
    final eng = g49.SuperDot3(rules: rules, topRuleName: 'E');
    final inputs = <String>[];
    for (final k in [32, 64, 128]) {
      final c = List.generate(k, (i) => '${i % 10}').join('+');
      final mid = c.length ~/ 2;
      inputs.add('${c.substring(0, mid)}+${c.substring(mid)}');
    }
    report(label, eng, inputs);
  }
}
