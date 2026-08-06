// Scratch: two questions.
//
// (1) What does the oracle return when asked at an INTERIOR clause of a left
//     recursive rule, rather than at the Ref that memoizes it? m43's veto reads
//     `node.orig.match(parser, pos)` at a First node, which is a rule body.
//     `Clause.match` is the raw combinator: no memo entry, so no grow loop.
//
// (2) Does that already break m42, whose budget-0 fast path asks the same
//     question? It should, whenever the whole budget is spent BEFORE reaching a
//     left recursive subtree, since then the subtree is asked at budget 0.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm26.dart' as g26;
import 'm41.dart' as g41;
import 'm42.dart' as g42;

void main() {
  const g = "E <- E '+' T / T;\nT <- T '*' F / F;\nF <- [0-9];\n";
  const s = '1+2++3';
  final rules = MetaGrammar.parseGrammar(g);
  final body = rules['E']!;
  final ref = Ref('E');

  String show(MatchResult m) => m.isMismatch ? 'MISMATCH' : 'len=${m.len}';

  print('--- (1) raw combinator vs memoized entry, input "$s"');
  for (var i = 0; i <= s.length; i++) {
    final p1 = Parser(rules: rules, topRuleName: 'E', input: s);
    final p2 = Parser(rules: rules, topRuleName: 'E', input: s);
    final p3 = Parser(rules: rules, topRuleName: 'E', input: s);
    print('pos $i:  ref.match ${show(ref.match(p1, i)).padRight(9)}'
        'body.match ${show(body.match(p2, i)).padRight(9)}'
        'parser.match(body) ${show(p3.match(body, i))}');
  }

  print('\n--- (2) budget spent before a left recursive subtree');
  // "z" then E. One SUB or one FAB exhausts the budget, and E is then asked at
  // budget 0, where every engine in the line settles it with the raw oracle.
  const g2 = "S <- 'z' E;\nE <- E '+' T / T;\nT <- T '*' F / F;\nF <- [0-9];\n";
  final r2 = MetaGrammar.parseGrammar(g2);
  final cases = <(String, int)>[
    ('y1+2', 1), // SUB y->z, then E must parse "1+2" at budget 0
    ('1+2', 1), // FAB z, then E must parse "1+2" at budget 0
    ('z1+2', 0), // clean, for reference
    ('y1', 1), // SUB, then E parses "1" -- the seed, so this one should pass
  ];
  print('input     truth   m26   m41   m42');
  for (final (input, truth) in cases) {
    String run(int Function(String) f) {
      try {
        return f(input).toString();
      } catch (e) {
        return 'X';
      }
    }

    final a = run(g26.SuperDot3(rules: r2, topRuleName: 'S').recoverCost);
    final b = run(g41.SuperDot3(rules: r2, topRuleName: 'S').recoverCost);
    final c = run(g42.SuperDot3(rules: r2, topRuleName: 'S').recoverCost);
    final bad = [a, b, c].any((x) => x != truth.toString());
    print('${input.padRight(9)} ${truth.toString().padLeft(5)} '
        '${a.padLeft(5)}${b.padLeft(6)}${c.padLeft(6)}'
        '${bad ? "   <-- WRONG" : ""}');
  }
}
