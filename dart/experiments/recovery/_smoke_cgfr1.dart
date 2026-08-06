// cgfr1 against m53, answer for answer. The gate is BIT-IDENTICAL COSTS AND TREES.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm53.dart' as g49;
import 'cgfr1.dart' as g50;

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

const doc = '{"a":1,"b":[2,3],"c":{"d":"x"},"e":true,"f":null}';

/// A canonical string for a witness tree, so two trees compare as text.
String shape(MatchResult m) {
  final kids = m.subClauseMatches;
  final label = m is SyntaxError ? 'ERR' : '${m.clause}';
  return kids.isEmpty
      ? '$label@${m.pos}+${m.len}'
      : '$label@${m.pos}+${m.len}(${kids.map(shape).join(',')})';
}

void block(String label, Map<String, Clause> rules, String top,
    List<String> inputs) {
  final a = g49.SuperDot3(rules: rules, topRuleName: top);
  final b = g50.SuperDot3(rules: rules, topRuleName: top);
  var n = 0, costDiff = 0, shapeDiff = 0, spanDiff = 0, verDiff = 0;
  var s49 = 0, s50 = 0, cheaper = 0, dearer = 0;
  for (final s in inputs) {
    n++;
    final ra = a.recover(s);
    final rb = b.recover(s);
    s49 += a.lastSteps;
    s50 += b.lastSteps;
    if (a.lastCost != b.lastCost) {
      costDiff++;
      if (b.lastCost >= 0 && (a.lastCost < 0 || b.lastCost < a.lastCost)) {
        cheaper++;
      } else {
        dearer++;
      }
      if (costDiff <= 4) {
        print('    cost ${a.lastCost} -> ${b.lastCost} on ${jsonEncode(s)}');
      }
    }
    if (shape(ra.root) != shape(rb.root)) {
      shapeDiff++;
      if (shapeDiff <= 2) print('    shape differs on ${jsonEncode(s)}');
    }
    if (ra.recoveryEvents != rb.recoveryEvents ||
        ra.charsSkipped != rb.charsSkipped) spanDiff++;
    if (a.lastVerified != b.lastVerified) verDiff++;
  }
  print('$label  n=$n  costDiff=$costDiff (cheaper $cheaper, dearer $dearer)  '
      'shapeDiff=$shapeDiff  spanDiff=$spanDiff  verDiff=$verDiff');
  print('      steps m49=$s49  m50=$s50  ratio '
      '${s49 == 0 ? '-' : (s50 / s49).toStringAsFixed(2)}x'
      '  cells=${b.lastCells}');
}

String jsonEncode(String s) => '"${s.replaceAll('\n', '\\n')}"';

void main() {
  final jsonRules = MetaGrammar.parseGrammar(jsonGrammar);
  final mutants = <String>[];
  for (var i = 0; i < doc.length; i++) {
    mutants.add(doc.substring(0, i) + doc.substring(i + 1));
    mutants.add('${doc.substring(0, i)}Q${doc.substring(i + 1)}');
    mutants.add('${doc.substring(0, i)}Q${doc.substring(i)}');
    mutants.add(doc.substring(0, i) +
        (i + 1 < doc.length ? doc[i + 1] + doc[i] : '') +
        doc.substring(i + 2 > doc.length ? doc.length : i + 2));
  }
  block('JSON ', jsonRules, 'JSON', mutants);

  const pred = [
    ("S <- !'x' A; A <- 'x' / \"yy\";", ['', 'x', 'yy', 'xyy', 'q']),
    ("S <- Kw; Kw <- \"if\" !Alpha; Alpha <- [a-z];", ['ifa', 'if', 'i', 'ifq']),
    ("S <- A 'b'; A <- 'a' &'b' / 'c';", ['ab', 'cb', 'a', 'c', 'axb']),
    ("S <- (!'\"' .)* '\"';", ['x', '"x', '', 'ab"']),
    ("S <- &'x' 'x' / 'y' 'y' 'y' 'y';", ['', 'x', 'y', 'yy']),
    ("S <- !'x' A B; A <- 'a'?; B <- 'x' / 'b';", ['x', 'ax', 'ab', 'b', '']),
    ("S <- (&[a-z] !'q' .)*;", ['q', 'aq', 'ab']),
    ("S <- !('a' 'b') . . .;", ['ccc', 'abc', 'ab', 'a', '']),
    ("S <- (!'x' .)* 'x';", ['x', 'ax', 'aax', '', 'a', 'aa', 'xb']),
  ];

  for (final (g, inputs) in pred) {
    final rules = MetaGrammar.parseGrammar(g);
    block('PRED ', rules, 'S', inputs);
  }

  const rec = [
    ("E <- E '+' T / T;\nT <- T '*' F / F;\nF <- [0-9];\n",
        ['1+2', '1++2', '1+', '+1', '1*', '1+2++3']),
    ("E <- T '+' E / T;\nT <- F '*' T / F;\nF <- [0-9];\n",
        ['1+2', '1++2', '1+', '+1', '1*', '1+2++3']),
    ("E <- A / F;\nA <- B '+' F;\nB <- E;\nF <- [0-9];\n",
        ['1+2', '1++2', '1+', '+1', '1+2+3', '']),
    ("E <- E N / F;\nN <- '-'?;\nF <- [0-9];\n", ['1', '1-', 'x', '1--']),
    ("V <- O / A / N;\nO <- '{' (M (',' M)*)? '}';\nM <- N ':' V;\n"
        "A <- '[' (V (',' V)*)? ']';\nN <- [0-9];\n", ['0', '{0:0}', '{0:0', '{0:}']),
  ];

  for (final (g, inputs) in rec) {
    final rules = MetaGrammar.parseGrammar(g);
    block('REC  ', rules, rules.keys.first, inputs);
  }
}
