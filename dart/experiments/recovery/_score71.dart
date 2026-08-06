// Copy of _score69.dart with the engine import switched to m70.
// m59's quality columns for the 5j row, scored with final_table's OWN
// functions (imported, so no second copy can drift): the 519-battery group
// (shape / cover / crsh / cost hist), the 7 valid documents, and pred/unsnd
// over predCases. The timing columns come from `_batt59.dart` (the latency
// protocol is unviable for m59) and the stack ceiling from `_ceil50b.dart`.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'final_table.dart'
    show jsonGrammar, treeShape, covers, truth, verdictOf, predCases, predMaxK;
import 'm71.dart' as e;

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';
  bool parses(String s) => !Parser(rules: rules, topRuleName: 'JSON', input: s)
      .parse()
      .hasSyntaxErrors;
  final want = treeShape(
      Parser(rules: rules, topRuleName: 'JSON', input: base).parse().root);
  final mutants = <String>[];
  for (var j = 0; j < base.length; j++) {
    mutants.add(base.substring(0, j) + base.substring(j + 1));
    if (j + 1 < base.length && base[j] != base[j + 1]) {
      mutants.add(
          base.substring(0, j) + base[j + 1] + base[j] + base.substring(j + 2));
    }
  }
  for (var j = 0; j <= base.length; j++) {
    for (final ch in ['Q', 'z', '}', '"', ',', '5']) {
      mutants.add(base.substring(0, j) + ch + base.substring(j));
      if (j < base.length) {
        mutants.add(base.substring(0, j) + ch + base.substring(j + 1));
      }
    }
  }
  final battery = [
    for (final m in mutants)
      if (!parses(m)) m
  ];
  final eng = e.SuperDot3(rules: rules, topRuleName: 'JSON');
  var shape = 0, cover = 0, crsh = 0;
  final hist = <int, int>{};
  for (final m in battery) {
    try {
      final r = eng.recover(m);
      if (treeShape(r.root) == want) shape++;
      if (covers(r.root, m.length)) cover++;
      hist[eng.lastCost] = (hist[eng.lastCost] ?? 0) + 1;
    } catch (_) {
      crsh++;
    }
  }
  print('shape=$shape/${battery.length} cover=$cover/${battery.length} '
      'crsh=$crsh hist=$hist');
  const valids = [
    base,
    '{}',
    '[]',
    '"x"',
    '[1,2,3]',
    '{"a":[{"b":null}],"c":false}',
    '3.5e-2',
  ];
  var valid = 0;
  for (final v in valids) {
    final r = eng.recover(v);
    if (eng.lastCost == 0 && r.recoveryEvents == 0) valid++;
  }
  print('valid=$valid/7');
  var pTot = 0, pOk = 0, unsnd = 0;
  for (final (g, top, alpha, inputs) in predCases) {
    final rules2 = MetaGrammar.parseGrammar(g);
    final eng2 = e.SuperDot3(rules: rules2, topRuleName: top);
    for (final s in inputs) {
      final w = truth(rules2, top, g, s, alpha, predMaxK);
      if (w != null) pTot++;
      final got = eng2.recoverCost(s);
      final v = verdictOf(w, got, predMaxK);
      if (v == 'ok') pOk++;
      if (v == 'under') {
        unsnd++;
        print('  UNDER: $g ${s.isEmpty ? "<empty>" : s}');
      }
    }
  }
  print('pred=$pOk/$pTot unsnd=$unsnd');
}
