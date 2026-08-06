// _tc76.dart -- which of the table's truth/pred cases does m76 lose, and is it
// one mechanism or several?
//
// `cost` fell 44/44 -> 26/44 between m77 and m76.  A count does not say whether
// that is one defect with wide reach or several small ones, and the answer
// decides whether the engine is one fix away from correct.  Uses the table's own
// `truthCases`, `predCases` and `truth`, so this cannot disagree with the column
// it is explaining.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show truthCases, predCases, truth, engines;

void main() {
  for (final name in ['m76', 'm77']) {
    final e = engines.firstWhere((x) => x.name == name);
    print('=== $name ===');
    var ok = 0, tot = 0;
    final byGrammar = <String, List<String>>{};
    for (final (g, top, alpha, inputs) in [...truthCases, ...predCases]) {
      final gr = MetaGrammar.parseGrammar(g);
      final (_, _, c3) = e.make(gr, top);
      for (final s in inputs) {
        final want = truth(gr, top, g, s, alpha, 3);
        if (want == null) continue; // beyond brute force: not this column's claim
        tot++;
        int got;
        try {
          got = c3(s);
        } catch (_) {
          got = -999;
        }
        if (got == want) {
          ok++;
        } else {
          byGrammar
              .putIfAbsent(g.replaceAll('\n', ' ').trim(), () => [])
              .add('"$s" want $want got $got');
        }
      }
    }
    print('exact: $ok / $tot');
    for (final entry in byGrammar.entries) {
      print('  ${entry.key}');
      for (final f in entry.value) {
        print('      $f');
      }
    }
  }
}
