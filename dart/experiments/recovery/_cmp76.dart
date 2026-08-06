// _cmp76.dart -- m75 / m76 / m77 on the gate that can see D-A.
//
// Codex built m76 against D-A and D-B while I built m77 against D-C, so the two
// are complementary rather than competing and the interesting question is not
// "which wins" but "does m76 actually close the 390". This scores all three on
// _gate77's 23 grammars, since a D-A fix scored on the OLD gate would be scored
// by an instrument that reports `low 0` whether the defect is present or not.
//
// The comparison is on MY instrument deliberately: a fix should be measured by
// something written before the fix existed and without knowledge of its design.
import 'package:squirrel_parser/squirrel_parser.dart';

import '_gate77.dart' show extra, Tally, enumerate;
import '_subset75.dart' show grammars, trueDist;
import 'm75.dart' as e75;
import 'm76.dart' as e76;
import 'm77.dart' as e77;

void main() {
  final all = <(String, String, String, bool)>[
    for (final (g, t, a) in grammars) (g, t, a, false),
    for (final (g, t, a, _) in extra) (g, t, a, true),
  ];

  final t = {'m75': Tally('m75'), 'm76': Tally('m76'), 'm77': Tally('m77')};
  final x = {'m75': Tally('m75+'), 'm76': Tally('m76+'), 'm77': Tally('m77+')};
  final rows = <String>[];
  // Where m76 and m77 disagree at all -- the merge surface.
  var disagree = 0;
  final examples = <String>[];

  for (final (g, top, alpha, isNew) in all) {
    final r = MetaGrammar.parseGrammar(g);
    final a = e75.SuperDot3(rules: r, topRuleName: top);
    final b = e76.SuperDot3(rules: r, topRuleName: top);
    final c = e77.SuperDot3(rules: r, topRuleName: top);
    final per = {'m75': Tally('m75'), 'm76': Tally('m76'), 'm77': Tally('m77')};
    // The three engines are unrelated classes, so there is no supertype to hold
    // them in one list; bind their entry points as closures instead.
    final arms = <(String, int Function(String))>[
      ('m75', a.recoverCost),
      ('m76', b.recoverCost),
      ('m77', c.recoverCost),
    ];
    var n = 0;
    for (final s in enumerate(alpha, 5)) {
      final truth = trueDist(r, top, s, alpha, 3);
      final got = <String, int>{};
      // Each engine is constructed once outside this loop; a throw from one arm
      // must not be reported as the others' result, so it is caught per arm.
      for (final (name, fn) in arms) {
        int v;
        try {
          v = fn(s);
        } catch (_) {
          v = -999; // scored as wrong, and visible as such
        }
        got[name] = v;
        t[name]!.score(truth, v);
        per[name]!.score(truth, v);
        if (isNew) x[name]!.score(truth, v);
      }
      n++;
      if (got['m76'] != got['m77']) {
        disagree++;
        if (examples.length < 12) {
          examples.add('"$s"  true=${truth ?? ">3"}  '
              'm76=${got['m76']}  m77=${got['m77']}   '
              '${g.replaceAll('\n', ' ').trim()}');
        }
      }
    }
    if (per.values.any((p) => p.wrong > 0)) {
      rows.add('${isNew ? "NEW " : "    "}'
          '${g.replaceAll('\n', ' ').trim().padRight(46)}  '
          'm75 ${per['m75']!.wrong.toString().padLeft(4)}'
          '/L${per['m75']!.tooLow.toString().padLeft(3)}   '
          'm76 ${per['m76']!.wrong.toString().padLeft(4)}'
          '/L${per['m76']!.tooLow.toString().padLeft(3)}   '
          'm77 ${per['m77']!.wrong.toString().padLeft(4)}'
          '/L${per['m77']!.tooLow.toString().padLeft(3)}   of $n');
    }
  }

  print('=== all ${all.length} grammars ===');
  for (final k in ['m75', 'm76', 'm77']) {
    print(t[k]!.row);
  }
  print('\n=== the ${extra.length} added grammars only ===');
  for (final k in ['m75', 'm76', 'm77']) {
    print(x[k]!.row);
  }
  print('\nper-grammar (wrong/LOW):');
  for (final r in rows) {
    print('  $r');
  }
  print('\nm76 vs m77 disagreements: $disagree');
  for (final e in examples) {
    print('  $e');
  }
}
