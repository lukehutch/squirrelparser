// WHERE DOES THE REMAINING LATENCY GAP LIVE? m53 is 1.68x m49 on `latms`, and the
// twelfth occasion measured 1.97 relaxations per cell against the descent's 1.13 --
// a ratio of 1.74. If the time ratio and the STEP ratio agree, then m53's
// per-relaxation constant is already at parity with the descent, and the entire
// residual gap is the relaxation FLOOR, not the constant. That is a different
// conclusion from "the worklist is slower", and it says where work must go next.
//
//   dart ... _lat53.dart <m49|m51|m52|m53|m56>
//
// One engine per process. Prints per-case steps and min-of-5 wall clock over the
// same 12 latency cases `final_table.dart` uses, so the totals are comparable.
import 'dart:math';

import 'package:squirrel_parser/squirrel_parser.dart';
import 'm49.dart' as g49;
import 'm51.dart' as g51;
import 'm52.dart' as g52;
import 'm53.dart' as g53;
import '_m56.dart' as g56;
import 'm57.dart' as g57;
import 'm58.dart' as g58;
import 'm60.dart' as g60;
import 'm61.dart' as g61;
import 'm62.dart' as g62;

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

void main(List<String> args) {
  final which = args.isEmpty ? 'm53' : args[0];
  final rules = MetaGrammar.parseGrammar(jsonGrammar);

  // The 12 cases, copied verbatim from `final_table.dart` so the numbers line up.
  final big = '{"users":[{"id":1,"name":"ann","tags":["x","y"]},'
      '{"id":2,"name":"bob","tags":["z"]},{"id":3,"name":"cyd","tags":[]}],'
      '"total":3,"ok":true}';
  final latCases = <String>[];
  for (final k in [4, 16, 64]) {
    latCases.add(big.substring(0, 30) + big.substring(30 + k));
    latCases.add(big.substring(0, 30) + ('@' * k) + big.substring(30));
    final ch = big.substring(30, 30 + k).split('')..shuffle(Random(12345 + k));
    latCases.add(big.substring(0, 30) + ch.join() + big.substring(30 + k));
  }
  for (final k in [4, 16, 64]) {
    final it = [for (var i = 0; i < k; i++) '{"id":$i,"name":"n$i","ok":true}'];
    final d = '{"items":[${it.join(',')}],"total":$k}';
    final mid = d.length ~/ 2;
    latCases.add('${d.substring(0, mid)}Q${d.substring(mid + 1)}');
  }

  late int Function(String) cost;
  late int Function() steps;
  switch (which) {
    case 'm49':
      final e = g49.SuperDot3(rules: rules, topRuleName: 'JSON');
      cost = e.recoverCost;
      steps = () => e.lastSteps;
    case 'm51':
      final e = g51.SuperDot3(rules: rules, topRuleName: 'JSON');
      cost = e.recoverCost;
      steps = () => e.lastSteps;
    case 'm52':
      final e = g52.SuperDot3(rules: rules, topRuleName: 'JSON');
      cost = e.recoverCost;
      steps = () => e.lastSteps;
    case 'm53':
      final e = g53.SuperDot3(rules: rules, topRuleName: 'JSON');
      cost = e.recoverCost;
      steps = () => e.lastSteps;
    case 'm56':
      final e = g56.SuperDot3(rules: rules, topRuleName: 'JSON');
      cost = e.recoverCost;
      steps = () => e.lastSteps;
    case 'm57':
      final e = g57.SuperDot3(rules: rules, topRuleName: 'JSON');
      cost = e.recoverCost;
      steps = () => e.lastSteps;
    case 'm58':
      final e = g58.SuperDot3(rules: rules, topRuleName: 'JSON');
      cost = e.recoverCost;
      steps = () => e.lastSteps;
    case 'm60':
      final e = g60.SuperDot3(rules: rules, topRuleName: 'JSON');
      cost = e.recoverCost;
      steps = () => e.lastSteps;
    case 'm62':
      final e = g62.SuperDot3(rules: rules, topRuleName: 'JSON');
      cost = e.recoverCost;
      steps = () => e.lastSteps;
    case 'm61':
      final e = g61.SuperDot3(rules: rules, topRuleName: 'JSON');
      cost = e.recoverCost;
      steps = () => e.lastSteps;
    default:
      throw ArgumentError(which);
  }

  var totUs = 0, totSteps = 0;
  print('$which: case len cost steps us');
  for (var i = 0; i < latCases.length; i++) {
    final s = latCases[i];
    var bestUs = 1 << 62, c = 0, st = 0;
    for (var r = 0; r < 5; r++) {
      final sw = Stopwatch()..start();
      c = cost(s);
      sw.stop();
      st = steps();
      if (sw.elapsedMicroseconds < bestUs) bestUs = sw.elapsedMicroseconds;
    }
    totUs += bestUs;
    totSteps += st;
    print('  $i ${s.length} $c $st $bestUs');
  }
  print('$which TOTAL steps=$totSteps us=$totUs (${totUs / 1000} ms)');
}
