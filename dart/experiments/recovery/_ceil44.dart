// Scratch: the gate for m44's derived deepening ceiling. m43 and everything
// before it stop at `maxCost = 40` and report -1 -- the whole input as one error
// span -- for any repair that costs more. m44 derives the ceiling as
// "discard the whole input and fabricate the goal", which is a repair that
// always exists, so it can never stop short of a real minimum.
//
// Both cases below have a true minimum cost above 40, and neither is exotic:
// one is a long broken document, the other a long literal.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm26.dart' as g26;
import 'm42.dart' as g42;
import 'm43.dart' as g43;
import 'm44.dart' as g44;

void main() {
  final cases = <(String, String, String, String, int)>[
    (
      'skip a long run: L(S) = {"x"}, so 59 deletions and one substitution',
      "S <- 'x';\n",
      'S',
      'z' * 60,
      60,
    ),
    (
      'fabricate a long literal: 46 characters, none of them present',
      "S <- \"0123456789012345678901234567890123456789012345\";\n",
      'S',
      '',
      46,
    ),
    (
      'just under the old ceiling, where every engine still agrees',
      "S <- 'x';\n",
      'S',
      'z' * 30,
      30,
    ),
  ];

  print('${'case'.padRight(58)} truth  m26  m42  m43  m44');
  var bad = 0;
  for (final (title, grammar, top, input, truth) in cases) {
    final rules = MetaGrammar.parseGrammar(grammar);
    String run(int Function() f) {
      try {
        return f().toString();
      } catch (e) {
        return 'X(${e.runtimeType})';
      }
    }

    final a = run(() =>
        g26.SuperDot3(rules: rules, topRuleName: top).recoverCost(input));
    final b = run(() =>
        g42.SuperDot3(rules: rules, topRuleName: top).recoverCost(input));
    final c = run(() =>
        g43.SuperDot3(rules: rules, topRuleName: top).recoverCost(input));
    final d = run(() =>
        g44.SuperDot3(rules: rules, topRuleName: top).recoverCost(input));
    if (d != truth.toString()) bad++;
    print('${title.padRight(58)} ${truth.toString().padLeft(5)}'
        '${a.padLeft(5)}${b.padLeft(5)}${c.padLeft(5)}${d.padLeft(5)}');

    // The witness tree must still cover the input, not just the cost.
    if (d == truth.toString()) {
      final r = g44.SuperDot3(rules: rules, topRuleName: top).recover(input);
      final spans = r.errorSpans.fold(0, (s, e) => s + e.len);
      print('${" " * 58}   m44 tree: root len ${r.root.len}/${input.length}, '
          '${r.errorSpans.length} span(s) covering $spans char(s), '
          '${r.missing.length} fabricated, forced=${r.forced}');
    }
  }
  print(bad == 0 ? '\nm44: all correct' : '\nm44: $bad WRONG');
}
