// _s79.dart -- WHY does m79 lose the original shape? Group the failures by what
// the repair actually did, so the answer is a small number of causes and not 288
// anecdotes.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show jsonGrammar, treeShape, covers;
import 'm79.dart' as e79;
import '_p79.dart' show render;

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

/// A coarse cause: what did the repair fabricate or destroy at the top level?
String cause(String rendered) {
  final fills = RegExp('‹(.*?)›').allMatches(rendered).map((m) => m[1]!).toList();
  final skips = RegExp('«(.*?)»').allMatches(rendered).map((m) => m[1]!).toList();
  String kind(List<String> l) =>
      l.map((s) => s.length > 3 ? '${s.length}c' : s).join('+');
  return 'fill[${kind(fills)}] skip[${kind(skips)}]';
}

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final battery = buildBattery(rules);
  final origShape =
      treeShape(Parser(rules: rules, topRuleName: 'JSON', input: base).parse().root);

  final buckets = <String, List<String>>{};
  var shape = 0;
  for (final s in battery) {
    final e = e79.SuperDot3(rules: rules, topRuleName: 'JSON');
    final r = e.recover(s);
    if (treeShape(r) == origShape) {
      shape++;
      continue;
    }
    final rd = render(r, s);
    buckets.putIfAbsent(cause(rd), () => []).add('${e.lastCost}  $s\n      $rd');
  }
  print('shape-identical $shape / ${battery.length}\n');
  final keys = buckets.keys.toList()
    ..sort((a, b) => buckets[b]!.length.compareTo(buckets[a]!.length));
  for (final k in keys) {
    print('${buckets[k]!.length.toString().padLeft(4)}  $k');
    for (final ex in buckets[k]!.take(3)) {
      print('      $ex');
    }
  }
}
