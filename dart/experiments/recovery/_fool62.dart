// The cut-frontier lower bound, as a checked construction: with head
// A <- ('x' 'x')* and tail B <- 'y'^j !., the tail forces A to end at
// len(head)+... precisely, so cost(head + 'y'^j) reads off ONE entry of the
// head's frontier. If every entry is read off by some tail, an exact
// algorithm's state at the cut must determine every entry: Omega(frontier).
import 'package:squirrel_parser/squirrel_parser.dart';
import '_m62p.dart' as g;

String headGrammar() => "S <- ('x' 'x')* !.;\n";
String fullGrammar(int j) => "S <- ('x' 'x')* T !.;\nT <- ${"'y' " * j};\n";

void main() {
  // Head: n=14 with corruptions at 3 and 8 -> ends have distinct costs.
  final chars = List.filled(14, 'x');
  chars[3] = 'q';
  chars[8] = 'q';
  final head = chars.join();

  // Frontier of the head alone, read as cost of repairing head[0..] so that
  // ('x''x')* ends exactly at len-j... we instead read it THROUGH tails:
  // for each tail length j, the full input is head + 'y'*j and the grammar
  // demands exactly j 'y's after the stars, so the star must account for all
  // of `head` (with deletions/subs) and the j tail chars are fixed.
  // Vary instead the SPLIT: corrupt tail chars so B repairs are constant and
  // the head's contribution shifts. Simpler direct read-off: for each j, ask
  // the cost of `head.substring(0, 14 - j) + 'y'*j` under fullGrammar(j):
  // the star spans [0, 14-j) -- one frontier entry per j.
  final costs = <int, int>{};
  for (var j = 0; j <= 6; j++) {
    final input = head.substring(0, 14 - j) + ('y' * j);
    final e = g.SuperDot3(
        rules: MetaGrammar.parseGrammar(j == 0 ? headGrammar() : fullGrammar(j)),
        topRuleName: 'S');
    costs[j] = e.recoverCost(input);
  }
  print('per-tail read-off costs (j -> cost): $costs');

  // Cross-check each against brute-force expectation computed by the head
  // grammar on the head prefix alone (star must consume the whole prefix).
  final expect = <int, int>{};
  for (var j = 0; j <= 6; j++) {
    final prefix = head.substring(0, 14 - j);
    final e = g.SuperDot3(
        rules: MetaGrammar.parseGrammar(headGrammar()), topRuleName: 'S');
    expect[j] = e.recoverCost(prefix);
  }
  print('head-prefix-alone costs   (j -> cost): $expect');
  final agree = [for (var j = 0; j <= 6; j++) costs[j] == expect[j]];
  print('read-off matches per-entry values: $agree');
  final distinct = costs.values.toSet().length;
  print('distinct frontier values observed through tails: $distinct of ${costs.length}');

  // Fooling-set size: over adversary corruption patterns (subsets of block
  // starts), how many DISTINCT frontier vectors (cost per readable end) are
  // achievable? log2 of this is the bits any exact algorithm must carry
  // across the cut, since each entry is readable by a tail (checked above).
  final vectors = <String>{};
  for (var mask = 0; mask < 16; mask++) {
    final cs = List.filled(14, 'x');
    final spots = [2, 5, 8, 11];
    for (var b = 0; b < 4; b++) {
      if (mask & (1 << b) != 0) cs[spots[b]] = 'q';
    }
    final h = cs.join();
    final vec = <int>[];
    for (var j = 0; j <= 6; j++) {
      final e = g.SuperDot3(
          rules: MetaGrammar.parseGrammar(headGrammar()), topRuleName: 'S');
      vec.add(e.recoverCost(h.substring(0, 14 - j)));
    }
    vectors.add(vec.join(','));
  }
  print('achievable frontier vectors over 16 corruption patterns: '
      '${vectors.length} distinct');
}
