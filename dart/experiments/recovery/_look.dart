// Positive-lookahead behaviour across the m-line. Truth by exhaustive
// enumeration of every string of length <= 2 over printable ASCII.
import 'dart:math' as math;
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm62.dart' as t62;
import 'm65.dart' as t65;
import 'm68.dart' as t68;

bool member(Map<String, Clause> r, String s) {
  final p = Parser(rules: r, topRuleName: 'S', input: s).parse();
  return !p.hasSyntaxErrors && p.root.len == s.length;
}

int lev(String a, String b) {
  var prev = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0);
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      cur[j] = math.min(math.min(prev[j] + 1, cur[j - 1] + 1),
          prev[j - 1] + (a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1));
    }
    prev = cur;
  }
  return prev[b.length];
}

(int, String) truth(Map<String, Clause> r, String x) {
  var best = -1;
  var wit = '';
  void test(String s) {
    if (!member(r, s)) return;
    final d = lev(x, s);
    if (best < 0 || d < best) { best = d; wit = s; }
  }
  test('');
  for (var a = 32; a <= 126; a++) {
    test(String.fromCharCode(a));
    for (var b = 32; b <= 126; b++) {
      test(String.fromCharCode(a) + String.fromCharCode(b));
    }
  }
  return (best, wit);
}

void main() {
  final cases = <(String, String)>[
    ('S <- &[a-z] [a-z];\n', 'Q'),
    ('S <- &[a-z] [a-z];\n', ''),
    ('S <- &[a-z] [0-9m-q];\n', ''),
    ('S <- ![a-l] [a-z];\n', ''),
    ('S <- &[a-c] [x-z];\n', ''),
    ("S <- &'a' 'a' 'b';\n", 'xb'),
  ];
  var bad = 0;
  print('grammar                    input truth  wit   m62   m65   m68 answered');
  for (final (g, x) in cases) {
    final r = MetaGrammar.parseGrammar(g);
    final (tr, wit) = truth(r, x);
    final c62 = t62.SuperDot3(rules: r, topRuleName: 'S').recoverCost(x);
    final c65 = t65.SuperDot3(rules: r, topRuleName: 'S').recoverCost(x);
    final e68 = t68.SuperDot3(rules: r, topRuleName: 'S');
    final c68 = e68.recoverCost(x);
    final tag = e68.lastFellBack ? 'tape' : 'relaxed';
    if (c68 != tr) bad++;
    print('${g.trim().padRight(26)} ${('"$x"').padLeft(4)} '
        '${tr.toString().padLeft(5)} ${('"$wit"').padLeft(5)} '
        '${c62.toString().padLeft(5)} ${c65.toString().padLeft(5)} '
        '${c68.toString().padLeft(5)}  ${c68 == tr ? '' : '<-- m68 WRONG'}');
  }
  print('\nm68 wrong on $bad/${cases.length}');
}
