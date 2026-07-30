// _coregate.dart -- does the portable core in `_core.dart` behave exactly like
// the frozen library, and is its read extent actually sound?
//
// Two independent claims, because they fail in different ways:
//
//   A. EQUIVALENCE. For every (grammar, input), the core's parse agrees with
//      `lib/src/parser`'s parse on hasSyntaxErrors, matched length, and full
//      tree shape. If this fails the copy is not a copy and every gate that
//      compares against the oracle silently shifts.
//
//   B. REUSE SOUNDNESS. `Parser.retarget(s2, e)` keeps exactly those memo
//      entries with `pos < e` and `readEnd < e`, then re-parses. The claim is
//      that this yields the same parse as a parser built fresh on `s2`. This is
//      the claim the whole standalone-core direction rests on: if read extents
//      are wrong, a retained entry answers a question about text that changed
//      and the engine silently reports a repair that is not one.
//
// B is checked against a FRESH parse, not against itself, and the number of
// entries actually retained is reported -- a reuse test that retains nothing
// passes vacuously.
import 'package:squirrel_parser/squirrel_parser.dart';
import '_core.dart' as core;

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

/// Grammars chosen to exercise every clause kind that can read input, plus the
/// two that historically break: left recursion (memoVersion) and lookahead
/// (reads past what it consumes).
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

String coreShape(core.MatchResult m) {
  final sb = StringBuffer();
  void walk(core.MatchResult n) {
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

int memoCount(core.Parser p) {
  var n = 0;
  for (final byPos in p.memoTable.values) {
    n += byPos.length;
  }
  return n;
}

void main() {
  var aCases = 0, aFail = 0;
  var bCases = 0, bFail = 0, retained = 0, retainedNonZero = 0;
  final failures = <String>[];

  for (final (name, g, top, bases) in grammars) {
    final libRules = MetaGrammar.parseGrammar(g);
    final back = <core.Clause, Clause>{};
    final coreRules = core.rulesToCore(libRules, back);

    // Every base plus every single-character edit of it is an equivalence case.
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
      final cor = core.Parser(rules: coreRules, topRuleName: top, input: s).parse();
      if (lib.hasSyntaxErrors != cor.hasSyntaxErrors ||
          lib.root.len != cor.root.len ||
          libShape(lib.root) != coreShape(cor.root)) {
        aFail++;
        if (failures.length < 8) {
          failures.add('A $name "$s": lib err=${lib.hasSyntaxErrors} len=${lib.root.len} '
              '| core err=${cor.hasSyntaxErrors} len=${cor.root.len}');
        }
      }
    }

    // B: retarget a used parser and compare against a fresh one.
    for (final b in bases) {
      for (final (s2, e) in edits(b)) {
        bCases++;
        final reused = core.Parser(rules: coreRules, topRuleName: top, input: b);
        reused.parse();
        reused.retarget(s2, e);
        final kept = memoCount(reused);
        retained += kept;
        if (kept > 0) retainedNonZero++;
        final got = reused.parse();
        final fresh = core.Parser(rules: coreRules, topRuleName: top, input: s2).parse();
        if (got.hasSyntaxErrors != fresh.hasSyntaxErrors ||
            got.root.len != fresh.root.len ||
            coreShape(got.root) != coreShape(fresh.root)) {
          bFail++;
          if (failures.length < 16) {
            failures.add('B $name "$b" -> "$s2" @$e (kept $kept): '
                'reused err=${got.hasSyntaxErrors} len=${got.root.len} '
                '| fresh err=${fresh.hasSyntaxErrors} len=${fresh.root.len}');
          }
        }
      }
    }
  }

  for (final f in failures) {
    print('  FAIL $f');
  }
  print('A equivalence vs frozen lib : ${aCases - aFail}/$aCases');
  print('B reuse == fresh parse      : ${bCases - bFail}/$bCases');
  print('  retained memo entries     : $retained total, '
      '$retainedNonZero/$bCases cases retained >0');
  print(aFail == 0 && bFail == 0 ? 'CORE GATE PASS' : 'CORE GATE FAIL');
}
