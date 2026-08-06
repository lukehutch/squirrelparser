// Scratch: fast smoke for m43 against m42 -- agreement on cost, tree and cover.
// Timing is NOT measured here (one engine per process is required for that).
import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/parser/combinators.dart';
import 'package:squirrel_parser/src/parser/match_result.dart';
import 'm42.dart' as g42;
import 'm43.dart' as g43;

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

  var costDiff = 0, shapeDiff = 0, shapeOk43 = 0, shapeOk42 = 0, coverBad = 0;
  var spanDiff = 0;
  final hist43 = <int, int>{}, hist42 = <int, int>{};
  for (final s in cases) {
    final e42 = g42.SuperDot3(rules: rules, topRuleName: 'JSON');
    final e43 = g43.SuperDot3(rules: rules, topRuleName: 'JSON');
    late int c42, c43, n42, n43;
    late MatchResult r42, r43;
    try {
      final a = e42.recover(s);
      c42 = e42.lastCost;
      r42 = a.root;
      n42 = a.errorSpans.length + a.missing.length;
    } catch (e) {
      print('m42 THREW on "$s": $e');
      rethrow;
    }
    try {
      final b = e43.recover(s);
      c43 = e43.lastCost;
      r43 = b.root;
      n43 = b.errorSpans.length + b.missing.length;
    } catch (e) {
      print('m43 THREW on "$s": $e');
      rethrow;
    }
    if (c42 != c43) {
      costDiff++;
      if (costDiff <= 8) print('COST  "$s"  m42=$c42 m43=$c43');
    }
    if (n42 != n43) {
      spanDiff++;
      if (spanDiff <= 8) print('SPANS "$s"  m42=$n42 m43=$n43');
    }
    hist42[c42] = (hist42[c42] ?? 0) + 1;
    hist43[c43] = (hist43[c43] ?? 0) + 1;
    if (!covers(r43, s.length)) {
      coverBad++;
      if (coverBad <= 4) print('COVER "$s"');
    }
    final t42 = treeShape(r42), t43 = treeShape(r43);
    if (t42 == want) shapeOk42++;
    if (t43 == want) shapeOk43++;
    if (t42 != t43) {
      shapeDiff++;
      if (shapeDiff <= 4) print('SHAPE "$s"\n  42: $t42\n  43: $t43');
    }
  }
  print('cases=${cases.length} costDiff=$costDiff shapeDiff=$shapeDiff '
      'spanDiff=$spanDiff coverBad=$coverBad '
      'shapeOk42=$shapeOk42 shapeOk43=$shapeOk43');
  print('hist42=$hist42');
  print('hist43=$hist43');
}
