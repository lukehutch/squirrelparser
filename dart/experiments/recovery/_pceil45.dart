// Scratch: does m45's DERIVED ceiling ever come up SHORT of a repair that m44
// (ceiling 40) still finds? The ceiling prices the trivial repair "discard the
// whole input, fabricate the goal", and it prices a syntactic predicate at 0 --
// "assumed to pass". A predicate that FAILS on the fabricated derivation makes
// that price a lie, and a lie in this direction loses repairs.
//
// Case 1 is built to make the lie maximal: the cheap branch is blocked by a
// predicate that cannot pass anywhere, so the real trivial repair is the
// expensive branch, and the ceiling is computed from the cheap one.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm44.dart' as g44;
import 'm45.dart' as g45;

void main() {
  final cases = <(String, String, String, String)>[
    (
      'cheap branch blocked by a predicate, empty input',
      "S <- &'x' 'x' / 'y' 'y' 'y' 'y';\n",
      'S',
      '',
    ),
    (
      'cheap branch blocked by a predicate, one junk char',
      "S <- &'x' 'x' / 'y' 'y' 'y' 'y';\n",
      'S',
      'z',
    ),
    (
      'predicates that pass, clean input (must stay 0)',
      "S <- &'x' 'x' &'y' 'y';\n",
      'S',
      'xy',
    ),
    (
      'predicates the INPUT refuses -- repairable at 2, and m44 says -1',
      "S <- &'x' 'x' &'y' 'y';\n",
      'S',
      'zz',
    ),
    (
      'negative predicate, repairable',
      "S <- !'x' 'a' 'b';\n",
      'S',
      'aq',
    ),
    (
      'empty language: no finite derivation of the goal',
      "S <- S 'a';\n",
      'S',
      'aaaa',
    ),
  ];

  print('${'case'.padRight(46)}${'input'.padRight(6)} m44  m45'
      '   m43ms  m44ms');
  for (final (title, grammar, top, input) in cases) {
    final rules = MetaGrammar.parseGrammar(grammar);
    String run(int Function() f) {
      try {
        return f().toString();
      } catch (e) {
        return 'X(${e.runtimeType})';
      }
    }

    final w1 = Stopwatch()..start();
    final a = run(
        () => g44.SuperDot3(rules: rules, topRuleName: top).recoverCost(input));
    w1.stop();
    final w2 = Stopwatch()..start();
    final b = run(
        () => g45.SuperDot3(rules: rules, topRuleName: top).recoverCost(input));
    w2.stop();
    final flag = a == b ? '' : '   <-- DIFFERS';
    print('${title.padRight(46)}${'"$input"'.padRight(6)}'
        '${a.padLeft(4)}${b.padLeft(5)}'
        '${w1.elapsedMilliseconds.toString().padLeft(7)}'
        '${w2.elapsedMilliseconds.toString().padLeft(7)}$flag');
  }
}
