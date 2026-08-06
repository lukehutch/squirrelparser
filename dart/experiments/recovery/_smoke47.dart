// Scratch: m47 against m46 on JSON -- a grammar with NO lookahead anywhere.
//
// I6's claim is that the constraint dimension is inert where nothing constrains:
// `c` never leaves `_free`, so every memo key and every branch is m46's. That is
// checkable as bit-for-bit agreement on cost, tree shape, span count and cover.
// Timing is NOT measured here (one engine per process is required for that).
import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/parser/match_result.dart';
import 'm46.dart' as g46;
import 'm47.dart' as g47;

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

const structural = <String>{
  'Object', 'Array', 'Member', 'String', 'Number', 'Boolean', 'Null', 'Value',
};

String treeShape(MatchResult r) {
  final sb = StringBuffer();
  void walk(MatchResult m) {
    final c = m.clause;
    if (c is Ref && structural.contains(c.ruleName)) {
      sb.write('${c.ruleName}(');
      m.subClauseMatches.forEach(walk);
      sb.write(')');
    } else {
      m.subClauseMatches.forEach(walk);
    }
  }

  walk(r);
  return sb.toString();
}

bool covers(MatchResult root, int len) {
  var pos = 0;
  var ok = true;
  void walk(MatchResult m) {
    if (!ok) return;
    if (m is SyntaxError || m.subClauseMatches.isEmpty) {
      if (m.len == 0) return;
      if (m.pos != pos) ok = false;
      pos = m.pos + m.len;
      return;
    }
    m.subClauseMatches.forEach(walk);
  }

  walk(root);
  return ok && pos == len;
}

const doc = '{"a":1,"b":[2,3],"c":{"d":"x"},"e":true,"f":null}';

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final want = treeShape(
      Parser(rules: rules, topRuleName: 'JSON', input: doc).parse().root!);

  final cases = <String>[doc];
  for (var i = 0; i < doc.length; i++) {
    cases.add(doc.substring(0, i) + doc.substring(i + 1)); // delete
    cases.add('${doc.substring(0, i)}Q${doc.substring(i + 1)}'); // substitute
    cases.add('${doc.substring(0, i)}Q${doc.substring(i)}'); // insert
  }
  cases.addAll(['', '{', '}', '[', 'null', '{"a"1}', '{"a:1}', '   ']);

  var costDiff = 0, shapeDiff = 0, spanDiff = 0, coverBad = 0;
  var shapeOk46 = 0, shapeOk47 = 0, stepDiff = 0;
  final hist46 = <int, int>{}, hist47 = <int, int>{};
  for (final s in cases) {
    final e46 = g46.SuperDot3(rules: rules, topRuleName: 'JSON');
    final e47 = g47.SuperDot3(rules: rules, topRuleName: 'JSON');
    late int cost46, cost47, spans46, spans47, steps46, steps47;
    late MatchResult root46, root47;
    try {
      final a = e46.recover(s);
      cost46 = e46.lastCost;
      root46 = a.root;
      spans46 = a.errorSpans.length + a.missing.length;
      steps46 = e46.lastSteps;
    } catch (e) {
      print('m46 THREW on "$s": $e');
      rethrow;
    }
    try {
      final b = e47.recover(s);
      cost47 = e47.lastCost;
      root47 = b.root;
      spans47 = b.errorSpans.length + b.missing.length;
      steps47 = e47.lastSteps;
    } catch (e) {
      print('m47 THREW on "$s": $e');
      rethrow;
    }
    if (cost46 != cost47) {
      costDiff++;
      if (costDiff <= 8) print('COST  "$s"  m46=$cost46 m47=$cost47');
    }
    if (spans46 != spans47) {
      spanDiff++;
      if (spanDiff <= 8) print('SPANS "$s"  m46=$spans46 m47=$spans47');
    }
    // The strongest form of the zero-cost claim: not merely the same answer, the
    // same number of `_compute` calls to reach it.
    if (steps46 != steps47) {
      stepDiff++;
      if (stepDiff <= 8) print('STEPS "$s"  m46=$steps46 m47=$steps47');
    }
    hist46[cost46] = (hist46[cost46] ?? 0) + 1;
    hist47[cost47] = (hist47[cost47] ?? 0) + 1;
    if (!covers(root47, s.length)) {
      coverBad++;
      if (coverBad <= 4) print('COVER "$s"');
    }
    final t46 = treeShape(root46), t47 = treeShape(root47);
    if (t46 == want) shapeOk46++;
    if (t47 == want) shapeOk47++;
    if (t46 != t47) {
      shapeDiff++;
      if (shapeDiff <= 4) print('SHAPE "$s"\n  46: $t46\n  47: $t47');
    }
  }
  print('cases=${cases.length} costDiff=$costDiff shapeDiff=$shapeDiff '
      'spanDiff=$spanDiff stepDiff=$stepDiff coverBad=$coverBad '
      'shapeOk46=$shapeOk46 shapeOk47=$shapeOk47');
  print('hist46=$hist46');
  print('hist47=$hist47');
}
