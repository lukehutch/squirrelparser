// _u80.dart -- how big is the SLOP FLOOR? Slop is characters matched by a
// terminal that constrains nothing, and it is present even in a perfect parse
// (every string body is `.`-matched). If the floor is large, the deepening bound
// has to climb past it before anything succeeds, and a one-character error ends
// up searching at a bound of 16. Measure it instead of guessing.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show jsonGrammar;
import 'm80.dart' as e80;

const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';

/// Characters the tree matched with `.` or an inverted set.
int slopOf(MatchResult m) {
  var n = 0;
  void walk(MatchResult x) {
    if (x is e80.Filled) return;
    if (x.subClauseMatches.isEmpty) {
      final c = x.clause;
      if (c is AnyChar || (c is CharSet && c.inverted)) n += x.len;
      return;
    }
    x.subClauseMatches.forEach(walk);
  }

  walk(m);
  return n;
}

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);

  final clean = e80.SuperDot3(rules: rules, topRuleName: 'JSON');
  final cleanTree = clean.recover(base);
  print('clean document: cost ${clean.lastCost}  slop ${slopOf(cleanTree)}');
  print('  -> a perfect parse already spends this much, so the bound must');
  print('     climb past it before ANY reading succeeds.\n');

  for (final s in [
    '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"',
    '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}}',
    '{"a":1,"bc":[2,33true],"d":{"e":null},"f":"gh"}',
    '[1,2,3]',
    '[1,2,3',
  ]) {
    final e = e80.SuperDot3(rules: rules, topRuleName: 'JSON');
    final sw = Stopwatch()..start();
    final t = e.recover(s);
    sw.stop();
    final sl = slopOf(t);
    print('cost ${e.lastCost.toString().padLeft(2)}  slop ${sl.toString().padLeft(2)}  '
        'total ${(e.lastCost + sl).toString().padLeft(2)}  '
        '${(sw.elapsedMicroseconds / 1000).toStringAsFixed(1).padLeft(7)} ms  $s');
  }
}
