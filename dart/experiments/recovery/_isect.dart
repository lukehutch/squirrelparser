// Codex round-five counterexample: an atom set built one-representative-per-
// terminal cannot express a lookahead INTERSECTION. Truth by exhaustive
// enumeration of every string of length <= 3 over printable ASCII.
import 'dart:math' as math;
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm65.dart' as t65;
import 'm68.dart' as t68;

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

/// Every string of length <= 3 over printable ASCII; min edit distance to x
/// among the members. Sound for grammars whose members are short.
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

void main() {
  final cases = <(String, String, String)>[
    ('lookahead intersection', "S <- &[a-z] [0-9m-q];\n", ''),
    ('intersection, 1 char in', "S <- &[a-z] [0-9m-q];\n", 'z'),
    ('disjoint lookahead', "S <- &[a-c] [x-z];\n", ''),
    ('negative lookahead cut', "S <- ![a-l] [a-z];\n", ''),
  ];
  print('case                       truth  wit   m65   m68  verdict');
  for (final (name, g, x) in cases) {
    final r = MetaGrammar.parseGrammar(g);
    final (tr, wit) = truth(r, 'S', x);
    final c65 = t65.SuperDot3(rules: r, topRuleName: 'S').recoverCost(x);
    final e68 = t68.SuperDot3(rules: r, topRuleName: 'S');
    final c68 = e68.recoverCost(x);
    final ok = c65 == tr && c68 == tr;
    print('${name.padRight(24)} ${tr.toString().padLeft(5)} '
        '${('"$wit"').padLeft(5)} ${c65.toString().padLeft(5)} '
        '${c68.toString().padLeft(5)}  ${ok ? 'ok' : 'WRONG'} '
        ' horizon=${e68.lastHorizon}');
  }
}
