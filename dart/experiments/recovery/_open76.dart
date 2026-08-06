// _open76.dart -- does discharging an inexpressible obligation fix the throw
// without buying it back somewhere else?
//
// m76 throws `UnsupportedError: left-recursive obligation` from `_norm` on every
// damaged input under a left-recursive grammar, losing 18 of the table's 113
// ground-truth cases.  The patched copy replaces both throws with an `_opaque`
// residual that absorbs through every constructor and is discharged at `_settle`,
// the one place a residual meets its polarity.
//
// A fix has to be measured on BOTH gates, because each one is blind where the
// other sees: the 23-grammar gate has no left-recursive grammar (it reported m77
// perfect), and the table's truth cases have no empty-language star (they
// reported m76 perfect).  Passing one proves nothing about the other.
import 'package:squirrel_parser/squirrel_parser.dart';

import '_gate77.dart' show extra, Tally, enumerate;
import '_subset75.dart' show grammars, trueDist;
import 'final_table.dart' show truthCases, predCases, truth;
import 'm76.dart' as e76;
import 'm78.dart' as efix;
import 'm77.dart' as e77;

typedef Arm = (String, int Function(String));

void main() {
  // ---- gate A: 23 grammars, the one that can see D-A -------------------------
  final all = <(String, String, String)>[
    for (final (g, t, a) in grammars) (g, t, a),
    for (final (g, t, a, _) in extra) (g, t, a),
  ];
  final tally = {'m76': Tally('m76'), 'm78': Tally('m78')};
  var changed = 0;
  final examples = <String>[];

  for (final (g, top, alpha) in all) {
    final r = MetaGrammar.parseGrammar(g);
    final a = e76.SuperDot3(rules: r, topRuleName: top);
    final b = efix.SuperDot3(rules: r, topRuleName: top);
    final arms = <Arm>[('m76', a.recoverCost), ('m78', b.recoverCost)];
    for (final s in enumerate(alpha, 5)) {
      final want = trueDist(r, top, s, alpha, 3);
      final got = <String, int>{};
      for (final (name, fn) in arms) {
        int v;
        try {
          v = fn(s);
        } catch (_) {
          v = -999; // a throw is a lost case, not a missing measurement
        }
        got[name] = v;
        tally[name]!.score(want, v);
      }
      if (got['m76'] != got['m78']) {
        changed++;
        if (examples.length < 6) {
          examples.add('  ${g.replaceAll('\n', ' ').trim()}  "$s" '
              'true ${want ?? ">3"}: m76 ${got['m76']} -> fix ${got['m78']}');
        }
      }
    }
  }
  print('=== gate A: ${all.length} grammars (D-A visible) ===');
  for (final t in tally.values) {
    print(t.row);
  }
  print('answers changed by the fix: $changed');
  for (final e in examples) {
    print(e);
  }

  // ---- gate B: the table's own ground truth, where the throws live -----------
  print('\n=== gate B: table truth+pred cases (left recursion visible) ===');
  for (final (name, make)
      in <(String, int Function(String) Function(Map<String, Clause>, String))>[
    ('m76', (r, t) => e76.SuperDot3(rules: r, topRuleName: t).recoverCost),
    ('m78', (r, t) => efix.SuperDot3(rules: r, topRuleName: t).recoverCost),
    ('m77', (r, t) => e77.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ]) {
    var ok = 0, tot = 0, threw = 0;
    final lost = <String>[];
    for (final (g, top, alpha, inputs) in [...truthCases, ...predCases]) {
      final r = MetaGrammar.parseGrammar(g);
      final fn = make(r, top);
      for (final s in inputs) {
        final want = truth(r, top, g, s, alpha, 3);
        if (want == null) continue;
        tot++;
        int got;
        try {
          got = fn(s);
        } catch (_) {
          got = -999;
          threw++;
        }
        if (got == want) {
          ok++;
        } else {
          lost.add('${g.replaceAll('\n', ' ').trim()}  "$s" want $want got $got');
        }
      }
    }
    print('$name: exact $ok / $tot   (threw $threw)');
    for (final l in lost) {
      print('    $l');
    }
  }
}
