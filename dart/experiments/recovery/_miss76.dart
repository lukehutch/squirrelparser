// _miss76.dart -- why does the replay refuse a cost the search found?
//
// `_chosenEmission` returns null when no character in the emitted range reaches
// the obligation state the search recorded, and the replay then fails closed.
// `_advance` treats `_free` as absorbing, so an emission can never ACQUIRE an
// obligation -- if the recorded target is non-free while the carried state is
// free, no character can ever match and the refusal is structural, not a
// property of this input.  This prints the carried state, the target, and every
// state actually reachable, so the two can be told apart.
import 'package:squirrel_parser/squirrel_parser.dart';

import '_m76fix.dart' as efix;

const probes = [
  ("S <- A 'b';\nA <- 'a' &'b' / 'c';\n", 'S', ['a', 'axb', 'aab']),
  ("S <- (A / 'a') 'b';\nA <- 'a' &(\"bb\");\n", 'S', ['bbb', 'aabb', 'abb']),
];

void main() {
  for (final (g, top, inputs) in probes) {
    print('--- ${g.replaceAll('\n', ' ').trim()}');
    final r = MetaGrammar.parseGrammar(g);
    for (final s in inputs) {
      efix.SuperDot3.misses.clear();
      efix.SuperDot3.exit = '(chase succeeded)';
      final e = efix.SuperDot3(rules: r, topRuleName: top);
      final v = e.recoverCost(s);
      print('  "$s" -> $v   (${efix.SuperDot3.misses.length} emission misses)'
          '  last chase exit: ${efix.SuperDot3.exit}');
      for (final m in efix.SuperDot3.misses.toSet().take(6)) {
        print('        $m');
      }
    }
  }
}
