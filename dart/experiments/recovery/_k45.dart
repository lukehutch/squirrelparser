// Scratch: how does each engine scale in K, on a REAL grammar with no lookahead
// in it? I4 rewrites nothing in JSON, so every number here must reproduce m44's
// exactly -- this is the gate for "the fix costs nothing where it does not
// apply". Same document and damage as _k39.dart so the numbers stay comparable.
// One engine per process, name on the command line.
import 'dart:math';
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm26.dart' as g26;
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

String doc(int k) {
  final it = [for (var i = 0; i < k; i++) '{"id":$i,"nm":"n$i","ok":true}'];
  return '{"items":[${it.join(',')}],"total":$k}';
}

String damage(String d, int k) {
  final colons = <int>[];
  for (var i = 0; i < d.length; i++) {
    if (d[i] == ':') colons.add(i);
  }
  final b = d.split('');
  final step = colons.length / (k + 1);
  for (var i = 1; i <= k; i++) {
    b[colons[min(colons.length - 1, (step * i).floor())]] = 'Q';
  }
  return b.join();
}

void main(List<String> args) {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final name = args.first;
  int Function(String) make() => switch (name) {
        'm26' => g26.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
        'm44' => g44.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
        _ => g45.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost,
      };
  final d = doc(16);
  final out = <String>[];
  for (final k in [1, 2, 4, 8]) {
    final s = damage(d, k);
    var t = double.infinity;
    var cost = -1;
    for (var i = 0; i < 5; i++) {
      final f = make();
      final sw = Stopwatch()..start();
      cost = f(s);
      t = min(t, sw.elapsedMicroseconds / 1000);
    }
    out.add('K=$k c=$cost ${t.toStringAsFixed(1)}ms');
  }
  print('$name n=${d.length}  ${out.join('  ')}');
}
