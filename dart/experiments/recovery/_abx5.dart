// _ab81.dart -- m80 vs m81 on the same battery, under the OFFICIAL protocol
// (one engine built once and reused, exactly as final_table.dart does). Shape,
// coverage, failures and the COST SUM must be identical: m81 changes the data
// structure, not the algorithm, so any difference in the cost sum is a bug.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show jsonGrammar, treeShape, covers;
import 'm81.dart' as e80;
import '_x5.dart' as e81;

const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';
const accept = ['[2,33,true]', '[2,33true]', '[,2,]', '[,2,3]', '[2,,3]', '[,2,'];

List<String> buildBattery(Map<String, Clause> rules) {
  bool parses(String s) => !Parser(rules: rules, topRuleName: 'JSON', input: s)
      .parse()
      .hasSyntaxErrors;
  final mutants = <String>[];
  for (var j = 0; j < base.length; j++) {
    mutants.add(base.substring(0, j) + base.substring(j + 1));
    if (j + 1 < base.length && base[j] != base[j + 1]) {
      mutants.add(
          base.substring(0, j) + base[j + 1] + base[j] + base.substring(j + 2));
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
  return mutants.where((m) => !parses(m)).toList();
}

String render(MatchResult m, String input, bool Function(MatchResult) isFill,
    String Function(MatchResult) fillText) {
  final sb = StringBuffer();
  void walk(MatchResult n) {
    if (isFill(n)) {
      sb.write('‹${fillText(n)}›');
      return;
    }
    if (n is SyntaxError) {
      sb.write('«${input.substring(n.pos, n.pos + n.len)}»');
      return;
    }
    if (n.subClauseMatches.isEmpty) {
      if (n.len > 0) sb.write(input.substring(n.pos, n.pos + n.len));
      return;
    }
    n.subClauseMatches.forEach(walk);
  }

  walk(m);
  return sb.toString();
}

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final pure = Parser(rules: rules, topRuleName: 'JSON', input: base).parse();
  final origShape = treeShape(pure.root);
  final battery = buildBattery(rules);

  final e0 = e80.SuperDot3(rules: rules, topRuleName: 'JSON');
  final e1 = e81.SuperDot3(rules: rules, topRuleName: 'JSON');

  String r0(MatchResult m, String s) =>
      render(m, s, (n) => n is e80.Filled, (n) => (n as e80.Filled).text);
  String r1(MatchResult m, String s) =>
      render(m, s, (n) => n is e81.Filled, (n) => (n as e81.Filled).text);

  print('=== clean input ===');
  print('  m80 cost ${e0.recoverCost(base)}  shape ok '
      '${treeShape(e0.recover(base)) == origShape}');
  print('  m81 cost ${e1.recoverCost(base)}  shape ok '
      '${treeShape(e1.recover(base)) == origShape}');

  print('\n=== acceptance cases ===');
  for (final s in accept) {
    final a = e0.recover(s), ac = e0.lastCost;
    final b = e1.recover(s), bc = e1.lastCost;
    final ra = r0(a, s), rb = r1(b, s);
    print('  ${'"$s"'.padRight(14)} m80 $ac ${ra.padRight(20)} '
        'm81 $bc ${rb.padRight(20)} ${ra == rb && ac == bc ? "" : "  <-- DIFFER"}');
  }

  // Each engine gets a cold pass and a warm pass, so JIT order cannot
  // decide the comparison.
  for (final pass in [0, 1, 0, 1]) {
    var shape = 0, cov = 0, bad = 0, costSum = 0;
    final sw = Stopwatch()..start();
    for (final s in battery) {
      final r = pass == 0 ? e0.recover(s) : e1.recover(s);
      final c = pass == 0 ? e0.lastCost : e1.lastCost;
      if (c < 0) {
        bad++;
        continue;
      }
      costSum += c;
      if (covers(r, s.length)) cov++;
      if (treeShape(r) == origShape) shape++;
    }
    sw.stop();
    print('\n=== ${pass == 0 ? "m81" : "x5 (one way per cell)"} battery (n=${battery.length}) ===');
    print('  shape $shape   covered $cov   fail $bad   costSum $costSum   '
        '${sw.elapsedMilliseconds} ms');
  }
}
