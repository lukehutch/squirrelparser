// Scratch: does the chart rework change ANY answer outside the battery?
// Left-recursive grammars (where the fixed-point loop is the whole point),
// the known conformance probes, and the grammars that used to hang.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'r5.dart' as r5;
import '_v20.dart' as v12;
import '_v13.dart' as v13;

String ser(MatchResult m) {
  final b = StringBuffer();
  void walk(MatchResult k) {
    b.write('${k.runtimeType}:${k.clause}:${k.pos}:${k.len}(');
    for (final s in k.subClauseMatches) {
      walk(s);
    }
    b.write(')');
  }

  walk(m);
  return b.toString();
}

final probes = <(String, String, String, List<String>)>[
  // -- left recursion: direct
  ('LR-direct', "E <- E '+' T / T; T <- [0-9];", 'E',
      ['1+2+3', '1++3', '1+2+', '+2+3', '1 2 3', '1+2*3', '']),
  // -- left recursion: indirect through a rule
  ('LR-indirect', "E <- A / T; A <- E '-' T; T <- [0-9];", 'E',
      ['1-2-3', '1--3', '1-2-', '-2', '12']),
  // -- left recursion inside a repetition
  ('LR-in-rep', "S <- L; L <- L ',' I / I; I <- [a-z]+;", 'S',
      ['a,b,c', 'a,,c', 'a,b,', ',b', 'a b c']),
  // -- left recursion under an optional
  ('LR-opt', "S <- S 'x'? 'y' / 'y';", 'S', ['y', 'yxy', 'yxxy', 'yx', 'xy']),
  // -- the known conformance probes
  ('C1a', "S <- 'a'* \"ab\";", 'S', ['aab', 'ab', 'aaab']),
  ('C1b', "S <- ('a' / \"ab\") 'b';", 'S', ['abb', 'ab', 'b']),
  ('C1c', "S <- A 'c'; A <- 'a' / \"ab\";", 'S', ['abc', 'ac', 'c']),
  // -- lever f's known overcharge
  ('lever-f', "S <- 'a'+ 'z';", 'S', ['xazaaaaaz', 'az', 'xaz']),
  // -- the grammars that used to deepen forever
  ('nonproductive', 'S <- S;', 'S', ['', 'a']),
  ('nonproductive2', "S <- 'a' S;", 'S', ['', 'a', 'aa']),
  // -- repetition shapes the worklist rewrote
  ('rep-nested', "S <- ('a'* 'b')*;", 'S', ['aab', 'aabab', 'aa', 'b', '']),
  ('rep-plus-zero', "S <- ('a'?)+ 'z';", 'S', ['z', 'aaz', 'aa']),
  ('rep-optional', 'S <- ("ab" / \'a\')+;', 'S', ['aba', 'ab', 'aab', 'b', '']),
  ('rep-lr-body', "L <- L S / S; S <- ('a' / 'b')+;", 'L',
      ['abab', 'ab c ab', 'c', '', 'aXb']),
  ('rep-two-ends', 'S <- ("ab" / \'a\')* "bc";', 'S',
      ['ababc', 'aabc', 'abc', 'ab', 'aabX c']),
  ('rep-deep', "S <- (A / 'z')*; A <- 'x' S 'y';", 'S',
      ['xzyz', 'xzy', 'xz', 'zzz', 'xxzyy', 'xy']),
];

void main() {
  var diff = 0, ran = 0;
  for (final (name, g, top, inputs) in probes) {
    final rules = MetaGrammar.parseGrammar(g);
    final a = r5.Squirrel(rules: rules, topRuleName: top);
    final b = v12.Squirrel(rules: rules, topRuleName: top);
    final c = v13.Squirrel(rules: rules, topRuleName: top);
    for (final s in inputs) {
      ran++;
      String run(dynamic e) {
        try {
          final t = e.recover(s) as MatchResult;
          return '${e.lastCost}|${ser(t)}';
        } catch (x) {
          return 'THREW $x';
        }
      }

      final ra = run(a), rb = run(b), rc = run(c);
      final tag = ra == rb && rb == rc
          ? 'same'
          : ra == rb
              ? 'v13 DIFFERS'
              : rb == rc
                  ? 'v12+v13 DIFFER'
                  : 'ALL DIFFER';
      if (tag != 'same') diff++;
      print('${name.padRight(16)} ${('"$s"').padRight(12)} '
          'r5=${ra.split('|').first.padLeft(3)} '
          'v12=${rb.split('|').first.padLeft(3)} '
          'v13=${rc.split('|').first.padLeft(3)}  $tag');
    }
  }
  print('');
  print('$ran probes, $diff differ');
}
