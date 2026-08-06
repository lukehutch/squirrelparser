// Scratch: fast smoke for m45 against m44 -- agreement on cost, tree and cover.
// Timing is NOT measured here (one engine per process is required for that).
import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/parser/combinators.dart';
import 'package:squirrel_parser/src/parser/match_result.dart';
import 'm44.dart' as g44;
import 'm45.dart' as g45;

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

  var costDiff = 0, shapeDiff = 0, shapeOk44 = 0, shapeOk43 = 0, coverBad = 0;
  var spanDiff = 0;
  final hist44 = <int, int>{}, hist43 = <int, int>{};
  for (final s in cases) {
    final e43 = g44.SuperDot3(rules: rules, topRuleName: 'JSON');
    final e44 = g45.SuperDot3(rules: rules, topRuleName: 'JSON');
    late int c43, c44, n43, n44;
    late MatchResult r43, r44;
    try {
      final a = e43.recover(s);
      c43 = e43.lastCost;
      r43 = a.root;
      n43 = a.errorSpans.length + a.missing.length;
    } catch (e) {
      print('m44 THREW on "$s": $e');
      rethrow;
    }
    try {
      final b = e44.recover(s);
      c44 = e44.lastCost;
      r44 = b.root;
      n44 = b.errorSpans.length + b.missing.length;
    } catch (e) {
      print('m45 THREW on "$s": $e');
      rethrow;
    }
    if (c43 != c44) {
      costDiff++;
      if (costDiff <= 8) print('COST  "$s"  m44=$c43 m45=$c44');
    }
    if (n43 != n44) {
      spanDiff++;
      if (spanDiff <= 8) print('SPANS "$s"  m44=$n43 m45=$n44');
    }
    hist43[c43] = (hist43[c43] ?? 0) + 1;
    hist44[c44] = (hist44[c44] ?? 0) + 1;
    if (!covers(r44, s.length)) {
      coverBad++;
      if (coverBad <= 4) print('COVER "$s"');
    }
    final t43 = treeShape(r43), t44 = treeShape(r44);
    if (t43 == want) shapeOk43++;
    if (t44 == want) shapeOk44++;
    if (t43 != t44) {
      shapeDiff++;
      if (shapeDiff <= 4) print('SHAPE "$s"\n  43: $t43\n  44: $t44');
    }
  }
  print('cases=${cases.length} costDiff=$costDiff shapeDiff=$shapeDiff '
      'spanDiff=$spanDiff coverBad=$coverBad '
      'shapeOk43=$shapeOk43 shapeOk44=$shapeOk44');
  print('hist43=$hist43');
  print('hist44=$hist44');
}
