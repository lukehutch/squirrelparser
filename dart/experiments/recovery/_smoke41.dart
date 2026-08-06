// Scratch: fast smoke for m41 against m39, one engine per process not needed --
// this only checks agreement on cost and tree, not timing.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/parser/combinators.dart';
import 'package:squirrel_parser/src/parser/match_result.dart';
import 'm39.dart' as g39;
import 'm41.dart' as g41;

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

  var costDiff = 0, shapeDiff = 0, shapeOk41 = 0, shapeOk39 = 0, coverBad = 0;
  final hist41 = <int, int>{}, hist39 = <int, int>{};
  for (final s in cases) {
    final e39 = g39.SuperDot3(rules: rules, topRuleName: 'JSON');
    final e41 = g41.SuperDot3(rules: rules, topRuleName: 'JSON');
    late int c39, c41;
    late SkipResultLike r39, r41;
    try {
      final a = e39.recover(s);
      c39 = e39.lastCost;
      r39 = SkipResultLike(a.root, a.errorSpans.length + a.missing.length);
    } catch (e) {
      print('m39 THREW on "$s": $e');
      rethrow;
    }
    try {
      final b = e41.recover(s);
      c41 = e41.lastCost;
      r41 = SkipResultLike(b.root, b.errorSpans.length + b.missing.length);
    } catch (e) {
      print('m41 THREW on "$s": $e');
      rethrow;
    }
    if (c39 != c41) {
      costDiff++;
      if (costDiff <= 6) print('COST  "$s"  m39=$c39 m41=$c41');
    }
    hist39[c39] = (hist39[c39] ?? 0) + 1;
    hist41[c41] = (hist41[c41] ?? 0) + 1;
    if (!covers(r41.root, s.length)) {
      coverBad++;
      if (coverBad <= 4) print('COVER "$s"');
    }
    final t39 = treeShape(r39.root), t41 = treeShape(r41.root);
    if (t39 == want) shapeOk39++;
    if (t41 == want) shapeOk41++;
    if (t39 != t41) {
      shapeDiff++;
      if (shapeDiff <= 4) print('SHAPE "$s"\n  39: $t39\n  41: $t41');
    }
  }
  print('cases=${cases.length} costDiff=$costDiff shapeDiff=$shapeDiff '
      'coverBad=$coverBad shapeOk39=$shapeOk39 shapeOk41=$shapeOk41');
  print('hist39=$hist39');
  print('hist41=$hist41');
}

class SkipResultLike {
  SkipResultLike(this.root, this.n);
  final MatchResult root;
  final int n;
}
