// _abrun.dart -- which ordering is right? Measured on the 519-mutant battery
// plus the owner's acceptance cases, one variable changed at a time.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show jsonGrammar, treeShape, covers, batteryTruth;
import '_ab79.dart' as ab;

const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';

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

String render(MatchResult m, String input) {
  final sb = StringBuffer();
  void walk(MatchResult n) {
    if (n is ab.Filled) {
      sb.write('‹${n.text}›');
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
  final battery = buildBattery(rules);
  final truth = batteryTruth(rules, battery);
  final origShape =
      treeShape(Parser(rules: rules, topRuleName: 'JSON', input: base).parse().root);

  const acc = ['[2,33,true]', '[2,33true]', '[,2,]', '[,2,3]', '[2,,3]', '[,2,'];

  print('mode  shape   cov   cost=T  cost<T  cost>T   fail   ms');
  for (final mode in [0, 1, 2, 3, 4]) {
    ab.abMode = mode;
    var shape = 0, cov = 0, eq = 0, lo = 0, hi = 0, bad = 0;
    final sw = Stopwatch()..start();
    for (var i = 0; i < battery.length; i++) {
      final s = battery[i];
      final e = ab.SuperDot3(rules: rules, topRuleName: 'JSON');
      MatchResult r;
      try {
        r = e.recover(s);
      } catch (_) {
        bad++;
        continue;
      }
      final c = e.lastCost;
      if (c < 0) {
        bad++;
        continue;
      }
      if (covers(r, s.length)) cov++;
      if (treeShape(r) == origShape) shape++;
      if (c == truth[i]) {
        eq++;
      } else if (c < truth[i]) {
        lo++;
      } else {
        hi++;
      }
    }
    sw.stop();
    print('${mode.toString().padLeft(4)}  '
        '${shape.toString().padLeft(5)} '
        '${cov.toString().padLeft(5)} '
        '${eq.toString().padLeft(7)} '
        '${lo.toString().padLeft(7)} '
        '${hi.toString().padLeft(7)} '
        '${bad.toString().padLeft(6)} '
        '${sw.elapsedMilliseconds.toString().padLeft(5)}   (n=${battery.length})');
  }

  print('\nacceptance cases');
  for (final mode in [0, 1, 2, 3, 4]) {
    ab.abMode = mode;
    final out = <String>[];
    for (final s in acc) {
      final e = ab.SuperDot3(rules: rules, topRuleName: 'JSON');
      final r = e.recover(s);
      out.add('${e.lastCost} ${render(r, s)}');
    }
    print('  mode $mode: ${out.join('   |   ')}');
  }
}
