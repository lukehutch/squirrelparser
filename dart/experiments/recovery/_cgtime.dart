// Battery timing + hist for cgfr1 beside m68, and a bounded case-8 probe.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'cgfr1.dart' as cg;
import 'm68.dart' as std;

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

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';
  bool parses(String x) =>
      !Parser(rules: rules, topRuleName: 'JSON', input: x).parse().hasSyntaxErrors;
  final mutants = <String>[];
  for (var j = 0; j < base.length; j++) {
    mutants.add(base.substring(0, j) + base.substring(j + 1));
    if (j + 1 < base.length && base[j] != base[j + 1]) {
      mutants.add(base.substring(0, j) + base[j + 1] + base[j] + base.substring(j + 2));
    }
  }
  for (var j = 0; j <= base.length; j++) {
    for (final c in ['Q', 'z', '}', '"', ',', '5']) {
      mutants.add(base.substring(0, j) + c + base.substring(j));
      if (j < base.length && base[j] != c) {
        mutants.add(base.substring(0, j) + c + base.substring(j + 1));
      }
    }
  }
  final battery = mutants.where((m) => !parses(m)).toList();

  final e = cg.SuperDot3(rules: rules, topRuleName: 'JSON');
  final s = std.SuperDot3(rules: rules, topRuleName: 'JSON');
  final hist = <int, int>{};
  var fell = 0;
  final sw = Stopwatch()..start();
  for (final x in battery) {
    final c = e.recoverCost(x);
    hist[c] = (hist[c] ?? 0) + 1;
    if (e.lastFellBack) fell++;
  }
  sw.stop();
  final tCg = sw.elapsedMilliseconds;
  sw..reset()..start();
  for (final x in battery) {
    s.recoverCost(x);
  }
  sw.stop();
  print('battery=${battery.length} cgfr1=${tCg}ms (fallbacks=$fell) '
      'm68=${sw.elapsedMilliseconds}ms  cgfr1 hist=$hist');

  // bounded case-8 probe: the 64-char scramble, cost 10
  final big = '{"users":[{"id":1,"name":"ann","tags":["x","y"]},'
      '{"id":2,"name":"bob","tags":["z"]},{"id":3,"name":"cyd","tags":[]}],'
      '"total":3,"ok":true}';
  final ch = big.substring(30, 94).split('');
  // deterministic scramble matching final_table's seed behavior is not
  // needed; any 64-char scramble at 30 is the same cost class
  ch.shuffle();
  final case8 = big.substring(0, 30) + ch.join() + big.substring(94);
  final swx = Stopwatch()..start();
  final c8 = s.recoverCost(case8);
  print('m68 case8-class: cost=$c8 in ${swx.elapsedMilliseconds}ms');
}
