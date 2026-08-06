// _incr70.dart -- how much does an incremental re-parse actually save?
//
// This is the number the whole "delete the relaxed DP" question turns on. The
// tape classifies one emitted string per search node by parsing it. If parsing
// a node given its PARENT's parse is much cheaper than parsing it from nothing,
// the tape gets cheap enough to be the only engine and ~750 lines disappear. If
// it is not, the relaxed DP has to stay and the floor stays where it is.
//
// Three walks, because they cost different amounts and the tape does all three:
//
//   APPEND   y -> y+c            (retarget at |y|: descend one trie level)
//   SIBLING  y+c1 -> y+c2        (retarget at |y|: try another atom, same node)
//   JUMP     y1 -> y2 unrelated  (retarget at their longest common prefix)
//
// Each is timed against parsing the same string with a fresh parser, on inputs
// at the scale the latency protocol actually uses -- Codex measured 2.32x on
// short strings, and length is exactly what the claim is sensitive to.
import 'dart:math';

import '_core.dart';
import 'package:squirrel_parser/squirrel_parser.dart' as sp;

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

String doc(int n) {
  final sb = StringBuffer('{"a":[');
  for (var i = 0; i < n; i++) {
    if (i > 0) sb.write(',');
    sb.write('{"k$i":"v$i","n":$i,"b":true}');
  }
  sb.write('],"z":null}');
  return sb.toString();
}

int memoCount(Parser p) {
  var n = 0;
  for (final byPos in p.memoTable.values) {
    n += byPos.length;
  }
  return n;
}

/// Entries created by one clean parse, for the retention denominator.
int fullMemo(Map<String, Clause> rules, String s) {
  final p = Parser(rules: rules, topRuleName: 'JSON', input: s);
  p.parse();
  return memoCount(p);
}

void main() {
  final libRules = sp.MetaGrammar.parseGrammar(jsonGrammar);
  final back = <Clause, sp.Clause>{};
  final rules = rulesToCore(libRules, back);

  print('walk      len   reuse_us   fresh_us  reuse/fresh  kept/parse  '
      'kept%  parses');

  for (final n in [1, 4, 16, 64]) {
    final s = doc(n);
    final denom = fullMemo(rules, s);

    // The tape never parses strings longer than the emitted candidate, and the
    // candidates are prefixes of what it is building. Walk the last `steps`
    // characters so short and long documents do the same amount of work and
    // only the PREFIX ALREADY PARSED differs -- that is the variable under test.
    final steps = min(64, s.length - 1);
    final from = s.length - steps;

    for (final walk in ['APPEND', 'SIBLING', 'JUMP']) {
      // ---- warm both paths (JIT) --------------------------------------------
      for (var w = 0; w < 2; w++) {
        final p = Parser(rules: rules, topRuleName: 'JSON', input: s);
        p.parse();
        Parser(rules: rules, topRuleName: 'JSON', input: s).parse();
      }

      var kept = 0, parses = 0;
      final reuse = Stopwatch();
      final fresh = Stopwatch();

      final p = Parser(rules: rules, topRuleName: 'JSON', input: s.substring(0, from));
      p.parse();

      for (var i = from; i < s.length; i++) {
        late String y;
        late int edit;
        switch (walk) {
          case 'APPEND': // one more character of the document
            y = s.substring(0, i + 1);
            edit = i;
          case 'SIBLING': // same node, a different atom in its place
            y = '${s.substring(0, i)}x';
            edit = i;
          case 'JUMP': // back to a shallow node, then out to a deep one
            y = i.isEven ? s.substring(0, from ~/ 2) : s.substring(0, i + 1);
            edit = i.isEven ? from ~/ 2 : from ~/ 2;
        }

        reuse.start();
        p.retarget(y, edit);
        kept += memoCount(p);
        p.parse();
        reuse.stop();

        fresh.start();
        Parser(rules: rules, topRuleName: 'JSON', input: y).parse();
        fresh.stop();
        parses++;
      }

      final r = reuse.elapsedMicroseconds, f = fresh.elapsedMicroseconds;
      print('${walk.padRight(8)} ${s.length.toString().padLeft(5)} '
          '${r.toString().padLeft(10)} ${f.toString().padLeft(10)} '
          '${(r / f).toStringAsFixed(3).padLeft(12)} '
          '${(kept / parses).toStringAsFixed(1).padLeft(11)} '
          '${(100 * kept / parses / denom).toStringAsFixed(0).padLeft(5)}% '
          '${parses.toString().padLeft(7)}');
    }
    print('  (a clean parse of this document creates $denom memo entries)');
  }
}
