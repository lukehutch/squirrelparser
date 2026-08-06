// THE m50 FORK, MEASURED. dot's search has no native recursion (so its stack
// ceiling is the best in the table) but it seeds EVERY terminal at EVERY position
// and EVERY Seq at dot 0 at EVERY position -- `_axioms` has no prediction at all,
// and once edits are allowed prediction cannot prune, because every node can
// derive every span. m49's descent is demand-driven instead.
//
// So: what FRACTION of the cell space does m49's descent actually touch? If it is
// near 1, dot's eager seeding costs nothing and m50 can take dot's architecture
// whole. If it is small, an agenda is strictly more work and the ceiling has to be
// fixed some other way.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm49.dart' as g49;

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

const doc = '{"a":1,"b":[2,3],"c":{"d":"x"},"e":true,"f":null}';

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final eng = g49.SuperDot3(rules: rules, topRuleName: 'JSON');

  final cases = <String>[];
  for (var i = 0; i < doc.length; i++) {
    cases.add(doc.substring(0, i) + doc.substring(i + 1));
    cases.add('${doc.substring(0, i)}Q${doc.substring(i + 1)}');
    cases.add('${doc.substring(0, i)}Q${doc.substring(i)}');
  }
  cases.addAll(['{', '}', '[', '{"a"1}', '{"a:1}']);

  var cells = 0, space = 0, steps = 0, worstNum = 0, worstDen = 1;
  var solved = 0;
  for (final s in cases) {
    final cost = eng.recoverCost(s);
    if (cost <= 0) continue; // clean or unrepairable: no search to measure
    solved++;
    cells += eng.lastCells;
    space += eng.lastSpace;
    steps += eng.lastSteps;
    if (eng.lastCells * worstDen > worstNum * eng.lastSpace) {
      worstNum = eng.lastCells;
      worstDen = eng.lastSpace;
    }
  }
  print('m49 on $solved repaired JSON mutants (n~${doc.length})');
  print('  cells demanded  $cells');
  print('  cell space      $space');
  print('  density         ${(cells / space * 100).toStringAsFixed(3)}%');
  print('  worst single    ${(worstNum / worstDen * 100).toStringAsFixed(3)}%');
  print('  _compute calls  $steps  (${(steps / cells).toStringAsFixed(2)} per cell)');

  // And how the density scales with n: an agenda's cost is the space, so the
  // interesting quantity is whether the touched fraction shrinks as n grows.
  print('\nscaling: one deletion at the midpoint of k repeats of the document');
  print('${'n'.padLeft(7)}${'cells'.padLeft(10)}${'space'.padLeft(12)}'
      '${'density'.padLeft(10)}${'steps'.padLeft(10)}');
  for (final k in [1, 2, 4, 8, 16]) {
    final body = List.filled(k, doc).join(',');
    final s0 = '[$body]';
    final mid = s0.length ~/ 2;
    final s = s0.substring(0, mid) + s0.substring(mid + 1);
    final cost = eng.recoverCost(s);
    if (cost < 0) {
      print('${s.length.toString().padLeft(7)}   unrepairable');
      continue;
    }
    print('${s.length.toString().padLeft(7)}${eng.lastCells.toString().padLeft(10)}'
        '${eng.lastSpace.toString().padLeft(12)}'
        '${(eng.lastCells / eng.lastSpace * 100).toStringAsFixed(3).padLeft(9)}%'
        '${eng.lastSteps.toString().padLeft(10)}');
  }
}
