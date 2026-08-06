// _isectall.dart -- the intersection gate across every candidate in the m70
// study, not just the three _isect69 happened to carry.
//
// The table has no column for this. Codex's round-five counterexample is that a
// proposal alphabet built one-representative-per-terminal cannot express a
// lookahead INTERSECTION: `&[a-z] [0-9m-q]` accepts only `[m-q]`, and no single
// representative of `[a-z]` chosen without consulting `[0-9m-q]` need land
// there. I25 replaces the alphabet with the Boolean interval partition, which
// closes it. Truth is by exhaustive enumeration of every string of length <= 2
// over printable ASCII, so the expected answers are facts, not predictions.
import 'dart:math' as math;

import 'package:squirrel_parser/squirrel_parser.dart';

import 'cgfr5.dart' as e_cgfr5;
import 'm50.dart' as e50;
import 'm51.dart' as e51;
import 'm52.dart' as e52;
import 'm53.dart' as e53;
import 'm57.dart' as e57;
import 'm60.dart' as e60;
import 'm62.dart' as e62;
import 'm64.dart' as e64;
import 'm65.dart' as e65;
import 'm66.dart' as e66;
import 'm67.dart' as e67;
import 'm68.dart' as e68;
import 'm69.dart' as e69;
import 'm70.dart' as e70;

bool member(Map<String, Clause> r, String top, String s) {
  final p = Parser(rules: r, topRuleName: top, input: s).parse();
  return !p.hasSyntaxErrors && p.root.len == s.length;
}

int lev(String a, String b) {
  var prev = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0);
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      cur[j] = math.min(
          math.min(prev[j] + 1, cur[j - 1] + 1),
          prev[j - 1] + (a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1));
    }
    prev = cur;
  }
  return prev[b.length];
}

(int, String) truth(Map<String, Clause> r, String top, String x) {
  var best = -1;
  var witness = '';
  void test(String s) {
    if (!member(r, top, s)) return;
    final d = lev(x, s);
    if (best < 0 || d < best) {
      best = d;
      witness = s;
    }
  }

  test('');
  for (var a = 32; a <= 126; a++) {
    test(String.fromCharCode(a));
    for (var b = 32; b <= 126; b++) {
      test(String.fromCharCode(a) + String.fromCharCode(b));
    }
  }
  return (best, witness);
}

typedef Run = int Function(Map<String, Clause>, String, String);

final engines = <(String, Run)>[
  ('m50', (r, t, s) => e50.SuperDot3(rules: r, topRuleName: t).recoverCost(s)),
  ('m51', (r, t, s) => e51.SuperDot3(rules: r, topRuleName: t).recoverCost(s)),
  ('m52', (r, t, s) => e52.SuperDot3(rules: r, topRuleName: t).recoverCost(s)),
  ('m53', (r, t, s) => e53.SuperDot3(rules: r, topRuleName: t).recoverCost(s)),
  ('m57', (r, t, s) => e57.SuperDot3(rules: r, topRuleName: t).recoverCost(s)),
  ('m60', (r, t, s) => e60.SuperDot3(rules: r, topRuleName: t).recoverCost(s)),
  ('m62', (r, t, s) => e62.SuperDot3(rules: r, topRuleName: t).recoverCost(s)),
  ('m64', (r, t, s) => e64.SuperDot3(rules: r, topRuleName: t).recoverCost(s)),
  ('m65', (r, t, s) => e65.SuperDot3(rules: r, topRuleName: t).recoverCost(s)),
  ('m66', (r, t, s) => e66.SuperDot3(rules: r, topRuleName: t).recoverCost(s)),
  ('m67', (r, t, s) => e67.SuperDot3(rules: r, topRuleName: t).recoverCost(s)),
  ('m68', (r, t, s) => e68.SuperDot3(rules: r, topRuleName: t).recoverCost(s)),
  ('m69', (r, t, s) => e69.SuperDot3(rules: r, topRuleName: t).recoverCost(s)),
  (
    'cgfr5',
    (r, t, s) => e_cgfr5.SuperDot3(rules: r, topRuleName: t).recoverCost(s)
  ),
  ('m70', (r, t, s) => e70.SuperDot3(rules: r, topRuleName: t).recoverCost(s)),
];

void main() {
  final cases = <(String, String, String)>[
    ('lookahead intersection', "S <- &[a-z] [0-9m-q];\n", ''),
    ('intersection, 1 char in', "S <- &[a-z] [0-9m-q];\n", 'z'),
    ('disjoint lookahead', "S <- &[a-c] [x-z];\n", ''),
    ('negative lookahead cut', "S <- ![a-l] [a-z];\n", ''),
  ];
  final truths = <int>[];
  print('truth by exhaustive enumeration, |s| <= 2 over printable ASCII');
  for (final (name, g, x) in cases) {
    final r = MetaGrammar.parseGrammar(g);
    final (tr, wit) = truth(r, 'S', x);
    truths.add(tr);
    print('  ${name.padRight(24)} ${tr.toString().padLeft(3)}  "$wit"');
  }
  print('');
  final hdr = StringBuffer('engine ');
  for (var i = 0; i < cases.length; i++) {
    hdr.write('  c$i');
  }
  hdr.write('  isect');
  print(hdr);
  for (final (name, run) in engines) {
    final row = StringBuffer(name.padRight(7));
    var ok = 0;
    for (var i = 0; i < cases.length; i++) {
      final r = MetaGrammar.parseGrammar(cases[i].$2);
      final int c;
      try {
        c = run(r, 'S', cases[i].$3);
      } catch (e) {
        row.write(' ERR');
        continue;
      }
      if (c == truths[i]) ok++;
      row.write(c.toString().padLeft(4));
    }
    row.write('   $ok/${cases.length}');
    print(row);
  }
}
