// _s80.dart -- the same three questions as _p79/_s79, asked of m80: does it
// still parse clean input exactly, does it settle the acceptance cases, and what
// is left when it loses the original shape?
import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show jsonGrammar, treeShape, covers;
import 'm80.dart' as e80;

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
    if (n is e80.Filled) {
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

String cause(String rendered) {
  final fills = RegExp('‹(.*?)›').allMatches(rendered).map((m) => m[1]!).toList();
  final skips = RegExp('«(.*?)»').allMatches(rendered).map((m) => m[1]!).toList();
  String kind(List<String> l) =>
      l.map((s) => s.length > 3 ? '${s.length}c' : s).join('+');
  return 'fill[${kind(fills)}] skip[${kind(skips)}]';
}

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final pure = Parser(rules: rules, topRuleName: 'JSON', input: base).parse();
  final origShape = treeShape(pure.root);

  final eng = e80.SuperDot3(rules: rules, topRuleName: 'JSON');
  final got = eng.recover(base);
  print('=== clean input ===');
  print('  cost          ${eng.lastCost}   (must be 0)');
  print('  shape equal   ${treeShape(got) == origShape}');
  print('  covers input  ${covers(got, base.length)}');

  print('\n=== acceptance cases ===');
  for (final s in ['[2,33,true]', '[2,33true]', '[,2,]', '[,2,3]', '[2,,3]', '[,2,']) {
    final e = e80.SuperDot3(rules: rules, topRuleName: 'JSON');
    final r = e.recover(s);
    print('  ${'"$s"'.padRight(14)} cost ${e.lastCost.toString().padLeft(2)}  '
        '${render(r, s)}');
  }

  final battery = buildBattery(rules);
  final buckets = <String, List<String>>{};
  var shape = 0, cov = 0, bad = 0;
  final sw = Stopwatch()..start();
  for (final s in battery) {
    final e = e80.SuperDot3(rules: rules, topRuleName: 'JSON');
    final r = e.recover(s);
    if (e.lastCost < 0) {
      bad++;
      continue;
    }
    if (covers(r, s.length)) cov++;
    if (treeShape(r) == origShape) {
      shape++;
      continue;
    }
    buckets
        .putIfAbsent(cause(render(r, s)), () => [])
        .add('${e.lastCost}  $s\n      ${render(r, s)}');
  }
  sw.stop();
  print('\n=== battery (n=${battery.length}) ===');
  print('  shape-identical $shape   covered $cov   fail $bad   '
      '${sw.elapsedMilliseconds} ms');
  final keys = buckets.keys.toList()
    ..sort((a, b) => buckets[b]!.length.compareTo(buckets[a]!.length));
  for (final k in keys) {
    print('${buckets[k]!.length.toString().padLeft(4)}  $k');
    for (final ex in buckets[k]!.take(2)) {
      print('      $ex');
    }
  }
}
