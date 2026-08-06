// _core2gate.dart -- does the frontier-carrying core in `_core2.dart` still
// parse exactly like the frozen library, and is the frontier it computes worth
// what it costs?
//
// Five claims, three of them pass/fail and two of them measurements. The split
// matters: a measurement that is allowed to fail the gate becomes a target, and
// the frontier's precision limit is a fact to be reported, not a bar to clear.
//
//   A. EQUIVALENCE (pass/fail). For every (grammar, input), `_core2`'s parse
//      agrees with `lib/src/parser`'s on hasSyntaxErrors, matched length, and
//      full tree shape. This is the whole risk of the change: mismatches now
//      carry real lengths, and the left recursion fixed point test used to read
//      those lengths. If A fails, the sentinel rewrite was wrong.
//
//   B. REUSE SOUNDNESS (pass/fail). `retarget(s2, e)` then re-parse equals a
//      fresh parse of `s2`. Inherited from `_coregate.dart`; re-run because
//      `Mismatch` objects now sit in the memo table and could be stale.
//
//   C. NO MISMATCH INSIDE A MATCH (pass/fail). `Match` recomputes its span from
//      its children, so a `Mismatch` child -- whose span is deliberately shorter
//      than its children's extent -- would silently corrupt the parent. The
//      construction never does it; this is the check that it never starts.
//
//   D. THE FRONTIER IS THE WATERMARK (pass/fail). `frontier(root)` must EQUAL
//      `parser.reach`, the watermark of everything any terminal ever agreed
//      with, computed independently as the parse runs and never consulted by the
//      tree. Equality in both directions is the claim: over is unsound, and
//      under means the tree forgot something.
//
//      This started as a census rather than a gate, because the first version of
//      `_core2.dart` was short on 1031 of 3990 cases -- a clause that SUCCEEDS
//      discards the attempts it made on the way, and `(Member ...)?` discarding
//      a Member that parsed a whole String is how `{"a:1,...` reported a
//      frontier of 1 against a true 7. Folding discarded reach into the parent
//      is what closed it, and keeping this as pass/fail is what stops it from
//      quietly reopening.
//
//   E. AGAINST THE OLD PROXY (measurement). Every engine today locates the error
//      with `syntaxErrorPosition()`: the largest memo-table position holding a
//      mismatch. That is a rule-granular lower bound -- it cannot see inside a
//      rule, and it cannot see a terminal at all. How far apart the two are is
//      the payoff, and it is the reason to pay for the allocation.
//
// Plus a cost run, because one object per failure replaces one singleton and
// that is the objection to the whole design.
import 'dart:io';

import 'package:squirrel_parser/squirrel_parser.dart';
import '_core.dart' as core;
import '_core2.dart' as c2;

const String jsonGrammar = '''
JSON <- WS Value WS;
Value <- Object / Array / String / Number / Boolean / Null;
Object <- '{' WS (Member (WS ',' WS Member)*)? WS '}';
Member <- String WS ':' WS Value;
Array <- '[' WS (Value (WS ',' WS Value)*)? WS ']';
String <- '"' Character* '"';
Character <- [^"\\\\] / ('\\\\' Escape);
Escape <- '"' / '\\\\' / '/' / 'b' / 'f' / 'n' / 'r' / 't' / ('u' [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F]);
Number <- Integer Fraction? Exponent?;
Integer <- '-'? (([1-9] [0-9]+) / [0-9]);
Fraction <- '.' [0-9]+;
Exponent <- ("e" / "E") ("+" / "-")? [0-9]+;
Boolean <- "true" / "false";
Null <- "null";
~WS <- [ \\t\\n\\r]*;
''';

/// `_coregate.dart`'s list, plus three grammars chosen because they are where
/// the frontier is expected to fall short of the watermark: a `First` whose
/// earlier arm reaches further than the arm that wins, a repetition whose last
/// iteration reaches past where it stops, and a multi-character literal, which
/// is the only terminal that can partly agree.
final grammars = <(String, String, String, List<String>)>[
  ('json', jsonGrammar, 'JSON', ['{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}']),
  ('leftrec', "E <- E '+' T / T;\nT <- [0-9]+;\n", 'E', ['1+22+333', '1+', '+1']),
  ('leftrec2', "E <- E '+' E / E '*' E / [0-9];\n", 'E', ['1+2*3', '1++2']),
  ('lookahead', "S <- &[a-z] [a-z0-9]+;\n", 'S', ['ab9', 'Z9', '9ab']),
  ('lookahead2', "S <- &[a-z] [0-9m-q];\n", 'S', ['m', 'a', 'Z', '']),
  ('neglook', "S <- (![,] .)* ',';\n", 'S', ['abc,', 'abc', ',']),
  ('possessive', "S <- 'a'* \"ab\";\n", 'S', ['aab', 'ab', 'aaab']),
  ('nested', "S <- '(' S ')' / 'x';\n", 'S', ['((x))', '((x)', 'x']),
  ('str', "S <- \"abc\" \"de\";\n", 'S', ['abcde', 'abcd', 'abXde']),
  ('opt', "S <- 'a'? 'b'* 'c'+;\n", 'S', ['abbc', 'c', 'ab']),
  ('losingarm', "S <- (\"abcd\" / \"ab\") 'z';\n", 'S', ['abz', 'abcX', 'abcdz']),
  ('reptail', "S <- (\"ab\")* 'z';\n", 'S', ['ababz', 'ababaX', 'abaz']),
  ('deepstr', "S <- A 'z';\nA <- \"hello\" / \"hi\";\n", 'S', ['hiz', 'helXo', 'hellz']),
];

String libShape(MatchResult m) {
  final sb = StringBuffer();
  void walk(MatchResult n) {
    sb.write(n.clause?.toString() ?? '_');
    sb.write('@${n.pos}:${n.len}(');
    for (final k in n.subClauseMatches) {
      walk(k);
    }
    sb.write(')');
  }

  walk(m);
  return sb.toString();
}

String c2Shape(c2.MatchResult m) {
  final sb = StringBuffer();
  void walk(c2.MatchResult n) {
    sb.write(n.clause?.toString() ?? '_');
    sb.write('@${n.pos}:${n.len}(');
    for (final k in n.subClauseMatches) {
      walk(k);
    }
    sb.write(')');
  }

  walk(m);
  return sb.toString();
}

/// Every single-character edit of [s], paired with the position it happens at.
List<(String, int)> edits(String s) {
  final out = <(String, int)>[];
  const alpha = 'a1{}[]",:x ';
  for (var i = 0; i <= s.length; i++) {
    if (i < s.length) out.add((s.substring(0, i) + s.substring(i + 1), i)); // delete
    for (final c in alpha.split('')) {
      out.add((s.substring(0, i) + c + s.substring(i), i)); // insert
      if (i < s.length) {
        out.add((s.substring(0, i) + c + s.substring(i + 1), i)); // substitute
      }
    }
  }
  return out;
}

int memoCount(c2.Parser p) {
  var n = 0;
  for (final byPos in p.memoTable.values) {
    n += byPos.length;
  }
  return n;
}

/// C: the clause kind of the first `Match` found holding a `Mismatch` child.
String? mismatchInsideMatch(c2.MatchResult m) {
  if (!m.isMismatch) {
    for (final k in m.subClauseMatches) {
      if (k.isMismatch) return '${m.clause} holds ${k.clause}';
    }
  }
  for (final k in m.subClauseMatches) {
    final hit = mismatchInsideMatch(k);
    if (hit != null) return hit;
  }
  return null;
}

void main() {
  var aCases = 0, aFail = 0;
  var bCases = 0, bFail = 0, retained = 0, retainedNonZero = 0;
  var cFail = 0;
  var dCases = 0, dUnsound = 0, dShort = 0, dShortTotal = 0;
  var eCases = 0, eSame = 0, eAhead = 0, eAheadTotal = 0, eBehind = 0;
  final failures = <String>[];
  final shortEg = <String>[];
  final aheadEg = <String>[];

  for (final (name, g, top, bases) in grammars) {
    final libRules = MetaGrammar.parseGrammar(g);
    final back = <c2.Clause, Clause>{};
    final c2Rules = c2.rulesToCore(libRules, back);

    final inputs = <String>{};
    for (final b in bases) {
      inputs.add(b);
      for (final (s, _) in edits(b)) {
        inputs.add(s);
      }
    }

    for (final s in inputs) {
      aCases++;
      final lib = Parser(rules: libRules, topRuleName: top, input: s).parse();
      final p = c2.Parser(rules: c2Rules, topRuleName: top, input: s);
      final cor = p.parse();
      if (lib.hasSyntaxErrors != cor.hasSyntaxErrors ||
          lib.root.len != cor.root.len ||
          libShape(lib.root) != c2Shape(cor.root)) {
        aFail++;
        if (failures.length < 8) {
          failures.add('A $name "$s": lib err=${lib.hasSyntaxErrors} len=${lib.root.len} '
              '| core2 err=${cor.hasSyntaxErrors} len=${cor.root.len}');
        }
      }

      // D and E need the RAW result, not `parse()`'s -- `parse()` replaces a
      // failed root with a SyntaxError over the whole input, throwing away the
      // very tree the frontier is computed from.
      final p2 = c2.Parser(rules: c2Rules, topRuleName: top, input: s);
      final raw = p2.matchRule(top, 0);
      final f = c2.frontier(raw);

      dCases++;
      if (f > p2.reach) {
        dUnsound++;
        if (failures.length < 16) {
          failures.add('D $name "$s": frontier $f > watermark ${p2.reach}');
        }
      } else if (f < p2.reach) {
        dShort++;
        dShortTotal += p2.reach - f;
        if (shortEg.length < 10) {
          shortEg.add('$name "$s": frontier $f, watermark ${p2.reach} '
              '(root ${raw.isMismatch ? "MISMATCH" : "match len ${raw.len}"})');
        }
      }

      // E: against the proxy every engine uses today.
      final proxy = p2.syntaxErrorPosition();
      eCases++;
      if (proxy == f) {
        eSame++;
      } else if (f > proxy) {
        eAhead++;
        eAheadTotal += f - proxy;
        if (aheadEg.length < 10) {
          aheadEg.add('$name "$s": frontier $f vs syntaxErrorPosition $proxy');
        }
      } else {
        eBehind++;
      }
    }

    for (final b in bases) {
      for (final (s2, e) in edits(b)) {
        bCases++;
        final reused = c2.Parser(rules: c2Rules, topRuleName: top, input: b);
        reused.parse();
        reused.retarget(s2, e);
        final kept = memoCount(reused);
        retained += kept;
        if (kept > 0) retainedNonZero++;
        final got = reused.parse();
        final fresh = c2.Parser(rules: c2Rules, topRuleName: top, input: s2).parse();
        if (got.hasSyntaxErrors != fresh.hasSyntaxErrors ||
            got.root.len != fresh.root.len ||
            c2Shape(got.root) != c2Shape(fresh.root)) {
          bFail++;
          if (failures.length < 24) {
            failures.add('B $name "$b" -> "$s2" @$e (kept $kept): '
                'reused err=${got.hasSyntaxErrors} len=${got.root.len} '
                '| fresh err=${fresh.hasSyntaxErrors} len=${fresh.root.len}');
          }
        }

        final hit = mismatchInsideMatch(
            c2.Parser(rules: c2Rules, topRuleName: top, input: s2).matchRule(top, 0));
        if (hit != null) {
          cFail++;
          if (failures.length < 32) failures.add('C $name "$s2": $hit');
        }
      }
    }
  }

  // Cost: one object per failure instead of one singleton, on a parse that fails
  // a lot. Same grammar, same inputs, same machine, alternating.
  final libRules = MetaGrammar.parseGrammar(jsonGrammar);
  final b1 = <core.Clause, Clause>{};
  final b2 = <c2.Clause, Clause>{};
  final r1 = core.rulesToCore(libRules, b1);
  final r2 = c2.rulesToCore(libRules, b2);
  final costInputs = <String>[
    '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}',
    '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"',
    '{"p":[1,2,3],"q',
    '[[[[[[[[1,2,3]]]]]]]]',
    '{"x":{"y":{"z":[1,2,{"w":"v"}]}}}',
  ];
  void runCore() {
    for (var i = 0; i < 400; i++) {
      for (final s in costInputs) {
        core.Parser(rules: r1, topRuleName: 'JSON', input: s).parse();
      }
    }
  }

  void runCore2() {
    for (var i = 0; i < 400; i++) {
      for (final s in costInputs) {
        c2.Parser(rules: r2, topRuleName: 'JSON', input: s).parse();
      }
    }
  }

  // Warm both, then ALTERNATE THE ORDER. Whichever arm runs first pays for the
  // JIT, and running `_core` first every round is how the first version of this
  // gate reported the extra allocation as a 10% SPEEDUP.
  runCore();
  runCore2();
  var t1 = 0, t2 = 0;
  for (var round = 0; round < 6; round++) {
    if (round.isEven) {
      final s1 = Stopwatch()..start();
      runCore();
      t1 += s1.elapsedMicroseconds;
      final s2 = Stopwatch()..start();
      runCore2();
      t2 += s2.elapsedMicroseconds;
    } else {
      final s2 = Stopwatch()..start();
      runCore2();
      t2 += s2.elapsedMicroseconds;
      final s1 = Stopwatch()..start();
      runCore();
      t1 += s1.elapsedMicroseconds;
    }
  }

  for (final f in failures) {
    print('  FAIL $f');
  }
  print('A equivalence vs frozen lib : ${aCases - aFail}/$aCases');
  print('B reuse == fresh parse      : ${bCases - bFail}/$bCases');
  print('  retained memo entries     : $retained total, '
      '$retainedNonZero/$bCases cases retained >0');
  print('C no Mismatch inside a Match: ${cFail == 0 ? "clean" : "$cFail VIOLATIONS"}');
  print('D frontier == watermark     : ${dCases - dShort - dUnsound}/$dCases'
      '${dUnsound > 0 ? " ($dUnsound OVER, unsound)" : ""}'
      '${dShort > 0 ? " ($dShort short, by $dShortTotal chars)" : ""}');
  print('E vs syntaxErrorPosition()  : same $eSame, frontier ahead $eAhead '
      '(by $eAheadTotal chars), behind $eBehind, of $eCases');
  print('cost: _core ${t1 ~/ 1000} ms, _core2 ${t2 ~/ 1000} ms '
      '(${(t2 / t1).toStringAsFixed(3)}x)');
  if (shortEg.isNotEmpty) {
    print('  where the frontier falls short of the watermark:');
    for (final e in shortEg) {
      print('    $e');
    }
  }
  if (aheadEg.isNotEmpty) {
    print('  where the frontier beats the proxy:');
    for (final e in aheadEg) {
      print('    $e');
    }
  }
  final pass =
      aFail == 0 && bFail == 0 && cFail == 0 && dUnsound == 0 && dShort == 0;
  print(pass ? 'CORE2 GATE PASS' : 'CORE2 GATE FAIL');
  if (!pass) exitCode = 1;
}
