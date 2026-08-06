// Scratch: fast smoke for m42 against m41 -- agreement on cost, tree and cover.
// Timing is NOT measured here (one engine per process is required for that).
import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/parser/combinators.dart';
import 'package:squirrel_parser/src/parser/match_result.dart';
import 'm41.dart' as g41;
import 'm42.dart' as g42;

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

  var costDiff = 0, shapeDiff = 0, shapeOk42 = 0, shapeOk41 = 0, coverBad = 0;
  var spanDiff = 0;
  final hist42 = <int, int>{}, hist41 = <int, int>{};
  for (final s in cases) {
    final e41 = g41.SuperDot3(rules: rules, topRuleName: 'JSON');
    final e42 = g42.SuperDot3(rules: rules, topRuleName: 'JSON');
    late int c41, c42, n41, n42;
    late MatchResult r41, r42;
    try {
      final a = e41.recover(s);
      c41 = e41.lastCost;
      r41 = a.root;
      n41 = a.errorSpans.length + a.missing.length;
    } catch (e) {
      print('m41 THREW on "$s": $e');
      rethrow;
    }
    try {
      final b = e42.recover(s);
      c42 = e42.lastCost;
      r42 = b.root;
      n42 = b.errorSpans.length + b.missing.length;
    } catch (e) {
      print('m42 THREW on "$s": $e');
      rethrow;
    }
    if (c41 != c42) {
      costDiff++;
      if (costDiff <= 8) print('COST  "$s"  m41=$c41 m42=$c42');
    }
    if (n41 != n42) {
      spanDiff++;
      if (spanDiff <= 8) print('SPANS "$s"  m41=$n41 m42=$n42');
    }
    hist41[c41] = (hist41[c41] ?? 0) + 1;
    hist42[c42] = (hist42[c42] ?? 0) + 1;
    if (!covers(r42, s.length)) {
      coverBad++;
      if (coverBad <= 4) print('COVER "$s"');
    }
    final t41 = treeShape(r41), t42 = treeShape(r42);
    if (t41 == want) shapeOk41++;
    if (t42 == want) shapeOk42++;
    if (t41 != t42) {
      shapeDiff++;
      if (shapeDiff <= 4) print('SHAPE "$s"\n  41: $t41\n  42: $t42');
    }
  }
  print('cases=${cases.length} costDiff=$costDiff shapeDiff=$shapeDiff '
      'spanDiff=$spanDiff coverBad=$coverBad '
      'shapeOk41=$shapeOk41 shapeOk42=$shapeOk42');
  print('hist41=$hist41');
  print('hist42=$hist42');
}
