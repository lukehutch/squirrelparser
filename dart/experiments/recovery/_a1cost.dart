// What does a CONTIGUOUS run cost? m51.dart:614 says j characters are j unit
// steps; I had written into LESSONS that a run of any length costs 1. One of those
// is wrong. Inserted junk is the clean probe: a deletion can be repaired by
// fabricating a couple of closing tokens instead of restoring what was removed, so
// deletion cost says nothing about the skip price.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm51.dart' as g51;

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

final big = '{"users":[{"id":1,"name":"ann","tags":["x","y"]},'
    '{"id":2,"name":"bob","tags":["z"]},{"id":3,"name":"cyd","tags":[]}],'
    '"total":3,"ok":true}';

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final e = g51.SuperDot3(rules: rules, topRuleName: 'JSON');
  // Insert a contiguous run of j junk characters between two members, outside any
  // string literal, so nothing in the grammar can accept them.
  final at = big.indexOf('},{');
  print(' j  insert-cost  delete-cost  steps(insert)');
  for (final j in [1, 2, 3, 4, 8, 16]) {
    final ins = big.substring(0, at + 1) + '@' * j + big.substring(at + 1);
    final r = e.recover(ins);
    final ci = e.lastCost;
    final si = e.lastSteps;
    print('  j=$j skipped=${r.errorSpans.map((x) => "${x.pos}+${x.len}").toList()} '
        'missing=${r.missing.map((m) => m.toString()).toList()}');
    final del = big.substring(0, at + 1) + big.substring(at + 1 + j);
    final cd = e.recoverCost(del);
    print('${j.toString().padLeft(2)}  ${ci.toString().padLeft(11)}  '
        '${cd.toString().padLeft(11)}  ${si.toString().padLeft(14)}');
  }
}
