// _r3ab.dart -- ablate the two suspected causes of the r2/m143 gap, separately
// and together, on the cases that expose them.
//
//   xa = summed cost with a fewer-deletions tie-break (replaces the
//        lexicographic (del, gap) order, under which ANY number of gaps beats
//        ONE deletion)
//   xb = the l=1 fill offered even at a position the current tree explains
//        (removes `!held[p]`)
//   x  = both
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_r3x.dart' as x;
import '_r3xa.dart' as xa;
import '_r3xb.dart' as xb;
import '_r3xc.dart' as xc;
import 'm143.dart' as g143;
import 'r2.dart' as r2;

typedef Run = (MatchResult, int) Function(Map<String, Clause>, String, String);

final engines = <String, Run>{
  'r2': (r, t, s) {
    final e = r2.Squirrel(rules: r, topRuleName: t);
    return (e.recover(s), e.lastCost);
  },
  'xa': (r, t, s) {
    final e = xa.Squirrel(rules: r, topRuleName: t);
    return (e.recover(s), e.lastCost);
  },
  'xb': (r, t, s) {
    final e = xb.Squirrel(rules: r, topRuleName: t);
    return (e.recover(s), e.lastCost);
  },
  'x': (r, t, s) {
    final e = x.Squirrel(rules: r, topRuleName: t);
    return (e.recover(s), e.lastCost);
  },
  'xc': (r, t, s) {
    final e = xc.Squirrel(rules: r, topRuleName: t);
    return (e.recover(s), e.lastCost);
  },
  'm143': (r, t, s) {
    final e = g143.SuperDot3(rules: r, topRuleName: t);
    return (e.recover(s), -1);
  },
};

void main() {
  final json = corpora.firstWhere((c) => c.name == 'json');
  final rules = MetaGrammar.parseGrammar(json.grammar);

  // (input, undamaged original) -- the score is against the ORIGINAL's shape.
  const probes = [
    ('"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}',
        '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}'),
    ('1,[2,[3,[4]]],5]', '[1,[2,[3,[4]]],5]'),
    ('"{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}',
        '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}'),
    ('Q[1,[2,[3,[4]]],5]', '[1,[2,[3,[4]]],5]'),
    ('[1,[2,', '[1,[2,[3,[4]]],5]'), // truncation: expectation trimmed below
  ];

  for (final (mutant, orig) in probes) {
    final origTree =
        Parser(rules: rules, topRuleName: json.top, input: orig).parse().root;
    // Truncation expectation: only nodes starting before the cut.
    final isTrunc = orig.startsWith(mutant);
    final expected = expectedFor(
        Case('json', orig, mutant, isTrunc ? 'truncate' : 'delim-delete'),
        origTree,
        json.named);
    print('--- `$mutant`');
    for (final e in engines.entries) {
      MatchResult got;
      int cost;
      try {
        (got, cost) = e.value(rules, json.top, mutant);
      } catch (err) {
        print('   ${e.key.padRight(5)} CRASH $err');
        continue;
      }
      final s = scoreCase(
          produced: got,
          expected: expected,
          inputLen: mutant.length,
          named: json.named);
      print('   ${e.key.padRight(5)} score=${s.score.toStringAsFixed(3)} '
          'cost=$cost cover=${s.covered} ${skeleton(got, json.named).where((t) => t != '(' && t != ')').join(' ')}');
    }
  }
}
