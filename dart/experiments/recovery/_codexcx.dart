// _codexcx.dart -- verify Codex's two executable counterexamples against m105
// and m112 myself, rather than taking the report's word for either.
//
// CX1 (span is not prefix-optimal, and it costs a real answer). `span = echo -
// doubt` is level 6 of `_better`, but it is the one key whose value can REVERSE
// when a way is extended: a later repair moves `echo` for both candidates, so
// the one with the LATER first repair ends up with the narrower window. m105
// keeps one way per ending, so the loser is gone before the extension happens.
//
//   S <- P '!';
//   P <- A / B;
//   A <- 'p' 'y' 'a' 'b' 'c' 'd' 'e' 'f' ';';
//   B <- 'p' 'x' 'a' 'Z' 'b' 'c' 'd' 'e' ';';
//   input: pxabcdef;?
//
// Both alternatives cost 2 to reach the end of P, so I43 is not involved --
// each matches real evidence first (`p`). A repairs only at 1 (span 0); B
// repairs at 3 and 7 (span 4). A wins there. The common suffix then repairs at
// 9 for both, and the windows become A [1,9] = 8 against B [3,9] = 6, so B is
// strictly better under the COMPLETE key. The claim is that m105 has already
// discarded it.
//
// The test does not need to force B. Scoring the two alternatives ALONE gives
// each one's final key, and the full grammar says which m105 actually chose --
// together that is the whole claim.
//
// CX2 (I54 suppresses a globally cheaper reading).
//
//   S <- A 'x' 'a';
//   A <- [ab];
//   input: xa
//
// `A` cannot match `x`. The undetermined zero-width `A` at 0 costs 1 and lets
// the real `x` and `a` satisfy the rest for nothing -- total 1. But skipping `x`
// also costs 1, so `minSkip == need == 1`, and I54's `need < minSkip` gate at
// m105.dart:1124 suppresses the fill. The claim is that m105 returns 3.
//
// m113 is the third column: m112 with `span` DELETED. It should fix CX1 by
// construction -- with level 6 gone the whole key is prefix-optimal, so a way
// that wins locally cannot be overtaken by one that was discarded. It is not
// expected to touch CX2, which is a generation prune, not an ordering.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'm105.dart' as e105;
import 'm113.dart' as e113;
import 'm112.dart' as e112;

const full = '''
S <- P '!';
P <- A / B;
A <- 'p' 'y' 'a' 'b' 'c' 'd' 'e' 'f' ';';
B <- 'p' 'x' 'a' 'Z' 'b' 'c' 'd' 'e' ';';
''';

const onlyA = '''
S <- P '!';
P <- A;
A <- 'p' 'y' 'a' 'b' 'c' 'd' 'e' 'f' ';';
''';

const onlyB = '''
S <- P '!';
P <- B;
B <- 'p' 'x' 'a' 'Z' 'b' 'c' 'd' 'e' ';';
''';

const cx2 = '''
S <- A 'x' 'a';
A <- [ab];
''';

/// Which named rules does the tree actually contain? That is the answer to
/// "which alternative did the engine choose".
Set<String> labels(MatchResult r) {
  final out = <String>{};
  void walk(MatchResult m) {
    final c = m.clause;
    if (c is Ref) out.add(c.ruleName);
    m.subClauseMatches.forEach(walk);
  }

  walk(r);
  return out;
}

/// Every repair the tree carries, and the doubt/echo/span they imply. `doubt` is
/// the FIRST repair position and `echo` the LAST, so both are readable off the
/// tree without reaching into the engine's private key.
(String, int, int, int) marks(MatchResult r, String input, bool Function(MatchResult) isFill) {
  final out = <String>[];
  final at = <int>[];
  void walk(MatchResult m) {
    if (m is SyntaxError) {
      out.add(m.len == 0 ? 'missing@${m.pos}' : 'skip "${input.substring(m.pos, m.pos + m.len)}"@${m.pos}');
      at.add(m.pos);
    } else if (isFill(m)) {
      out.add('fill@${m.pos}');
      at.add(m.pos);
    }
    m.subClauseMatches.forEach(walk);
  }

  walk(r);
  if (at.isEmpty) return ('(none)', -1, -1, 0);
  at.sort();
  return (out.join(' '), at.first, at.last, at.last - at.first);
}

void row(String label, String grammar, String input) {
  final rules = MetaGrammar.parseGrammar(grammar);
  final peg = !Parser(rules: rules, topRuleName: 'S', input: input)
      .parse()
      .hasSyntaxErrors;
  final a = e105.SuperDot3(rules: rules, topRuleName: 'S');
  final b = e113.SuperDot3(rules: rules, topRuleName: 'S');
  final c = e112.SuperDot3(rules: rules, topRuleName: 'S');
  final ca = a.recoverCost(input);
  final cb = b.recoverCost(input);
  final cc = c.recoverCost(input);
  final ta = a.recover(input);
  final tb = b.recover(input);
  final tc = c.recover(input);
  final (ma, da, ea, sa) = marks(ta, input, (n) => n is e105.Filled);
  final (mb, db, eb, sb) = marks(tb, input, (n) => n is e113.Filled);
  final (mc, dc, ec, sc) = marks(tc, input, (n) => n is e112.Filled);
  print('  $label   frozen PEG ${peg ? 'accepts' : 'REJECTS'}');
  void line(String n, int cost, int d, int e, int s, MatchResult t, String m) =>
      print('    $n cost $cost  doubt $d echo $e span $s  '
          'chose {${(labels(t)..removeAll({'S', 'P'})).join(',')}}  $m');
  line('m105', ca, da, ea, sa, ta, ma);
  line('m112', cc, dc, ec, sc, tc, mc);
  line('m113', cb, db, eb, sb, tb, mb);
}

void main() {
  print('CX1 -- span reverses under extension, and one way per ending loses B');
  print('     input: pxabcdef;?  (A repairs at 1; B repairs at 3 and 7;');
  print('     the common suffix then repairs at 9 for both)');
  row('A alone ', onlyA, 'pxabcdef;?');
  row('B alone ', onlyB, 'pxabcdef;?');
  row('A / B   ', full, 'pxabcdef;?');
  print('');
  print('  VERDICT: if `A alone` and `B alone` tie on cost and B ends with the');
  print('  SMALLER span, but `A / B` chose A, the prune discarded the winner.');
  print('');
  print('CX2 -- I54 suppresses the cost-1 reading at need == minSkip');
  print('     input: xa   cost 1 exists: undetermined A at 0, then real x and a');
  row('S <- A \'x\' \'a\'', cx2, 'xa');
  print('');
  print('  VERDICT: if m105 and m112 both report 3, I54 costs a global optimum.');
  print('  m113 deletes an ORDERING key, and I54 is a GENERATION prune, so');
  print('  m113 is expected to report 3 as well -- CX2 is a separate defect.');
}
