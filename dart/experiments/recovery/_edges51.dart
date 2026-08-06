// Does I10 (a wake CONSUMES the reverse edge) matter, and where? The battery's
// repairs cost 1-2, so two or three deepening rounds; the effect it predicts is
// quadratic in ROUNDS, so it can only show on a case with many. Deleting k
// characters costs about k.
//
//   dart ... _edges51.dart <m50|m51|noclear> [k]
//
// One engine per process. Reports the median of five wall clocks for `recoverCost`
// on the k-character deletion alone.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm50.dart' as g50;
import 'm51.dart' as g51;
import '_noclear51.dart' as gnc;

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

void main(List<String> args) {
  final which = args.isEmpty ? 'm51' : args[0];
  final k = args.length > 1 ? int.parse(args[1]) : 64;
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  // A CONTIGUOUS run of junk costs ONE skip (A1's unit edge), so deleting or
  // inserting k characters costs 1-2 however large k is -- which is why no latency
  // case in `final_table` reaches a third deepening round. SCATTER the damage
  // instead: k junk characters at k different places is k separate repairs, and
  // that is the only workload in the file that exercises the K axis.
  final buf = StringBuffer();
  final stride = big.length ~/ (k + 1);
  for (var i = 0; i < big.length; i++) {
    buf.write(big[i]);
    if (stride > 0 && i % stride == stride - 1 && buf.length < big.length + k) {
      buf.write('@');
    }
  }
  final s = buf.toString();
  int Function(String) run;
  int Function() steps;
  int Function() edges = () => -1;
  switch (which) {
    case 'm50':
      final e = g50.SuperDot3(rules: rules, topRuleName: 'JSON');
      run = e.recoverCost;
      steps = () => e.lastSteps;
    case 'noclear':
      final e = gnc.SuperDot3(rules: rules, topRuleName: 'JSON');
      run = e.recoverCost;
      steps = () => e.lastSteps;
      edges = () => e.lastEdges;
    default:
      final e = g51.SuperDot3(rules: rules, topRuleName: 'JSON');
      run = e.recoverCost;
      steps = () => e.lastSteps;
      edges = () => e.lastEdges;
  }
  final ms = <int>[];
  var cost = -2, st = 0;
  for (var i = 0; i < 5; i++) {
    final t = Stopwatch()..start();
    cost = run(s);
    ms.add(t.elapsedMilliseconds);
    st = steps();
  }
  ms.sort();
  print('$which  k=$k  cost=$cost  steps=$st  edges=${edges()}  '
      'median=${ms[2]}ms  all=$ms');
}
