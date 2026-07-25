// LEFT RECURSION. The pure parser handles left recursion; the question is
// whether the RECOVERY layer does, because its memo carries a reentrancy guard
// that returns an empty in-progress placeholder. If recovery silently
// under-approximates on a left-recursive grammar, that is a far more serious
// defect than any line count, since left recursion is the parser's headline
// feature.
//
// Reported per input: the pure parser's verdict, then each engine's repair cost
// and whether the recovered tree covers the input.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/recovery/dot_recovery.dart';
import 'm16.dart' as g16;
import 'm22.dart' as g22;

// Directly left-recursive, plus an indirectly left-recursive pair.
const lrGrammar = '''
E <- E '+' T / T;
T <- T '*' F / F;
F <- [0-9];
''';

bool covers(MatchResult root, int len) {
  var pos = 0;
  var ok = true;
  void walk(MatchResult m) {
    if (!ok) return;
    if (m is SyntaxError || m.subClauseMatches.isEmpty) {
      if (m.len == 0) return;
      if (m.pos != pos) ok = false;
      pos = m.pos + m.len;
      return;
    }
    m.subClauseMatches.forEach(walk);
  }

  walk(root);
  return ok && pos == len;
}

void main() {
  final rules = MetaGrammar.parseGrammar(lrGrammar);
  final inputs = [
    '1+2', // clean, exercises left recursion
    '1+2*3', // clean, both left-recursive rules
    '1++2', // one spurious '+'
    '1+', // missing operand
    '+1', // leading operator
    '1*', // missing operand, inner LR rule
    '1+2+3+4', // deep left recursion, clean
    '1+2++3+4', // deep left recursion plus one edit
    '1 + 2', // spaces are not in this grammar: two skips
  ];
  final d = DotRecovery(rules: rules, topRuleName: 'E');
  final r16 = g16.SuperDot3(rules: rules, topRuleName: 'E');
  final r22 = g22.SuperDot3(rules: rules, topRuleName: 'E');

  print('${'input'.padRight(10)}${'pure'.padLeft(7)}'
      '${'dot'.padLeft(14)}${'m16'.padLeft(14)}${'m22'.padLeft(14)}');
  for (final s in inputs) {
    final pure = Parser(rules: rules, topRuleName: 'E', input: s).parse();
    final cells = <String>[];
    for (final run in <MatchResult? Function()>[
      () => d.recover(s).root,
      () => r16.recover(s).root,
      () => r22.recover(s).root,
    ]) {
      try {
        final root = run();
        cells.add(root == null
            ? 'no repair'
            : '${covers(root, s.length) ? "cover" : "NOCOVER"}'
                ':len=${root.len}');
      } catch (e) {
        cells.add('CRASH(${e.runtimeType})');
      }
    }
    print('${s.padRight(10)}${(pure.hasSyntaxErrors ? "bad" : "ok").padLeft(7)}'
        '${cells[0].padLeft(14)}${cells[1].padLeft(14)}${cells[2].padLeft(14)}');
  }
}
