// m50 against m49, answer for answer. The gate is BIT-IDENTICAL COSTS AND TREES:
// I8 changes only the SCHEDULE of the same relaxations, so any difference in a
// reported cost or a witness span is a defect in the schedule, not a design
// choice. `steps` is allowed to differ -- it is the whole thing being traded.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm53.dart' as g49;
import '_m56.dart' as g50;

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
      '  cells=${b.lastCells}  perCell=${b.lastPerCell.toStringAsFixed(2)}');
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

  // The grammars with lookahead in them -- where I7's obligation channel is live
  // and the cell space has more than one class slab.
  const pred = [
    ("S <- !'x' A; A <- 'x' / \"yy\";", ['', 'x', 'yy', 'xyy', 'q']),
    ("S <- Kw; Kw <- \"if\" !Alpha; Alpha <- [a-z];", ['ifa', 'if', 'i', 'ifq']),
    ("S <- A 'b'; A <- 'a' &'b' / 'c';", ['ab', 'cb', 'a', 'c', 'axb']),
    ("S <- (!'\"' .)* '\"';", ['x', '"x', '', 'ab"']),
    ("S <- &'x' 'x' / 'y' 'y' 'y' 'y';", ['', 'x', 'y', 'yy']),
    ("S <- !'x' A B; A <- 'a'?; B <- 'b' / 'x';", ['x', 'ax', 'ab', 'b', '']),
    ("S <- (&[a-z] !'q' .)*;", ['q', 'aq', 'ab']),
    ("S <- &'x' !'x' 'y';", ['y', 'x', '']),
  ];
  for (final (g, inputs) in pred) {
    block('PRED ', MetaGrammar.parseGrammar(g), 'S', inputs);
  }

  // Left recursion, right recursion, and the empty-language grammars: the three
  // shapes I8's fixed point has to reproduce.
  const rec = [
    ("E <- E '+' T / T;\nT <- T '*' F / F;\nF <- [0-9] / '(' E ')';\n",
        ['1+2++3', '1++2', '1*', '(1+2', '1+2*3', '((1']),
    ("E <- T '+' E / T;\nT <- F '*' T / F;\nF <- [0-9] / '(' E ')';\n",
        ['1+2++3', '1++2', '1*', '(1+2', '1+2*3', '((1']),
    ("S <- S 'a';", ['a', 'aa', '']),
    ("S <- 'a'* 'b' 'a';", ['aa', 'ab', 'aba', 'a']),
    ("S <- A; A <- A 'x' / 'y';", ['yxx', 'yx', 'y', 'xx']),
  ];
  for (final (g, inputs) in rec) {
    block('REC  ', MetaGrammar.parseGrammar(g), g.startsWith('E') ? 'E' : 'S',
        inputs);
  }
}
