// How big is the frontier the lower-bound argument says is irreducible?
// Per-cell value-set sizes (triples per cell) on the 519-mutant battery and
// on an adversarial many-ends grammar, measured on the standing engine.
import 'package:squirrel_parser/squirrel_parser.dart';
import '_m62p.dart' as g;

void main() {
  final rules = MetaGrammar.parseGrammar('''
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
''');
  const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';
  bool parses(String s) =>
      !Parser(rules: rules, topRuleName: 'JSON', input: s).parse().hasSyntaxErrors;
  final mutants = <String>[];
  for (var j = 0; j < base.length; j++) {
    mutants.add(base.substring(0, j) + base.substring(j + 1));
    if (j + 1 < base.length && base[j] != base[j + 1]) {
      mutants.add(
          base.substring(0, j) + base[j + 1] + base[j] + base.substring(j + 2));
    }
  }
  for (var j = 0; j <= base.length; j++) {
    for (final c in ['Q', 'z', '}', '"', ',', '5']) {
      mutants.add(base.substring(0, j) + c + base.substring(j));
      if (j < base.length && base[j] != c) {
        mutants.add(base.substring(0, j) + c + base.substring(j + 1));
      }
    }
  }
  final battery = mutants.where((m) => !parses(m)).toList();

  final e = g.SuperDot3(rules: rules, topRuleName: 'JSON');
  var mx = 0;
  var meanSum = 0.0;
  for (final s in battery) {
    e.recoverCost(s);
    if (e.maxFrontier > mx) mx = e.maxFrontier;
    meanSum += e.meanFrontier;
  }
  print('battery n=${battery.length}: max frontier=$mx  '
      'mean-of-means=${(meanSum / battery.length).toStringAsFixed(2)}');

  // Adversarial many-ends grammar: A can end at every even offset; scattered
  // errors give the ends distinct costs, so the head frontier must hold them.
  final adv = MetaGrammar.parseGrammar('''
S <- A B !.;
A <- ('x' 'x')*;
B <- 'y' 'y' 'y';
''');
  for (final n in [20, 40, 60]) {
    final chars = List.filled(n, 'x');
    for (var i = 5; i < n; i += 7) {
      chars[i] = 'q'; // scattered corruption
    }
    final s = chars.join() + 'yy'; // tail also short one 'y'
    final ea = g.SuperDot3(rules: adv, topRuleName: 'S');
    final cost = ea.recoverCost(s);
    print('adversarial n=${s.length}: cost=$cost  max frontier=${ea.maxFrontier}  '
        'mean=${ea.meanFrontier.toStringAsFixed(2)}  cells=${ea.lastCells}');
  }
}
