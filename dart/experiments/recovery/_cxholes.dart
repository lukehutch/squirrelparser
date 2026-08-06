// Scratch: Codex's soundness counterexample, both trees side by side, so the
// r6 -> r8 delta can be read rather than inferred from a count whose definition
// I do not have.
//
//   dart run _cxholes.dart

import 'package:squirrel_parser/squirrel_parser.dart';
import '_score1.dart' show resolve;

void show(MatchResult m, [String ind = '  ']) {
  final lbl = m is SyntaxError
      ? 'ERR'
      : (m.clause == null
          ? 'ROOT'
          : (m.clause is Ref
              ? (m.clause as Ref).ruleName
              : m.clause.runtimeType.toString()));
  print('$ind$lbl @${m.pos}+${m.len}');
  for (final s in m.subClauseMatches) {
    show(s, '$ind  ');
  }
}

void main() {
  const g = "S <- A B; A <- 'a' / 'b'; B <- 'c' / 'd';";
  final rules = MetaGrammar.parseGrammar(g);
  print('grammar: $g\n');
  for (final inp in ['', 'x', 'xx', 'a', 'ax']) {
    print('########## input "$inp"');
    for (final name in ['r6', 'r9']) {
      final run = resolve(name)!(rules, 'S');
      print('=== $name');
      try {
        final t = run(inp);
        if (t == null) {
          print('  <null>');
        } else {
          show(t);
        }
      } catch (e) {
        print('  threw: $e');
      }
    }
  }
}
