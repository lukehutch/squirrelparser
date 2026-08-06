// Is the engine exploring parses that PEG semantics FORBID?
//
// This matters twice over. Correctness: A1 defines the objective as the minimum
// edit distance to the nearest member of L(G), and for a PEG, L(G) is defined by
// DETERMINISTIC parsing -- `*` is greedy and possessive, `/` commits to the first
// alternative that succeeds. A string a CFG would derive is often not in the PEG
// language at all. If the engine scores such a string as cost 0, it is repairing
// toward the wrong language.
//
// Complexity: `_chain` lets a Repetition finish at ANY iteration boundary
// (`if (_done(c, dot)) out[pos] = 0`) and lets a First take any alternative. Under
// true PEG semantics, once s' is fixed the stopping point and the chosen
// alternative are both FORCED. That freedom is a prime suspect for why the end-maps
// are O(n) wide -- which is the entire source of the n^3.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm26.dart' as g26;

/// PEG membership: parses with no errors AND consumes everything.
bool inLanguage(Map<String, Clause> rules, String top, String s) {
  final p = Parser(rules: rules, topRuleName: top, input: s).parse();
  return !p.hasSyntaxErrors && p.root != null && p.root!.len == s.length;
}

void main() {
  // Each case: (name, grammar, top, input, why the input is NOT in the PEG
  // language). A CFG reading of each grammar WOULD derive the input.
  final cases = <(String, String, String, String, String)>[
    (
      'possessive star',
      "S <- 'a'* \"ab\";\n",
      'S',
      'aab',
      "'a'* eats both a's, then 'ab' has only 'b' left; PEG never gives a char back",
    ),
    (
      'possessive star, longer',
      "S <- 'a'* \"ab\";\n",
      'S',
      'aaaab',
      'same, with more to give back',
    ),
    (
      'committed choice',
      "S <- ('a' / \"ab\") 'b';\n",
      'S',
      'abb',
      "'/' commits to 'a'; 'b' then matches, leaving 'b' unconsumed",
    ),
    (
      'committed choice, nested',
      "S <- A 'c';\nA <- 'a' / \"ab\";\n",
      'S',
      'abc',
      "A commits to 'a', so 'c' faces 'b'",
    ),
    (
      'greedy optional',
      "S <- 'a'? \"ab\";\n",
      'S',
      'aab',
      "'a'? takes the first a possessively",
    ),
  ];

  print('For each: is the input in the PEG language, and what cost does the');
  print('engine assign? A cost of 0 for a NON-member means the engine is');
  print('optimising against the CFG language, not the PEG one.\n');
  print('${'case'.padRight(24)}${'input'.padRight(8)}${'inPEG'.padLeft(6)}'
      '${'m26cost'.padLeft(9)}   verdict');

  var bad = 0;
  for (final (name, g, top, s, why) in cases) {
    final rules = MetaGrammar.parseGrammar(g);
    final member = inLanguage(rules, top, s);
    String cost;
    try {
      cost = g26.SuperDot3(rules: rules, topRuleName: top).recoverCost(s).toString();
    } catch (e) {
      cost = 'X(${e.runtimeType})';
    }
    // A non-member must cost >= 1: it needs at least one edit to enter L(G).
    final wrong = !member && cost == '0';
    if (wrong) bad++;
    print('${name.padRight(24)}${s.padRight(8)}${(member ? "yes" : "NO").padLeft(6)}'
        '${cost.padLeft(9)}   ${wrong ? "*** NON-PEG PARSE ACCEPTED ***" : "ok"}');
    if (wrong) print('      why not in L(G): $why');
  }
  print('\nnon-PEG parses accepted: $bad/${cases.length}');

  // If the engine is sound, the repaired string it produces must itself be in
  // L(G). That is the end-to-end version of the same check, and it holds the
  // engine to A1's actual definition rather than to its internal bookkeeping.
  print('\n--- does the reported cost match brute-force distance to the PEG language? ---');
  for (final (name, g, top, s, _) in cases) {
    final rules = MetaGrammar.parseGrammar(g);
    // Tiny BFS over the 3 edit primitives, alphabet {a,b,c}.
    var frontier = {s};
    final seen = {s};
    int? truth;
    for (var k = 0; k <= 3 && truth == null; k++) {
      for (final c in frontier) {
        if (inLanguage(rules, top, c)) {
          truth = k;
          break;
        }
      }
      if (truth != null) break;
      final next = <String>{};
      for (final c in frontier) {
        for (var i = 0; i < c.length; i++) {
          final d = c.substring(0, i) + c.substring(i + 1);
          if (seen.add(d)) next.add(d);
        }
        for (var i = 0; i <= c.length; i++) {
          for (final ch in ['a', 'b', 'c']) {
            final ins = c.substring(0, i) + ch + c.substring(i);
            if (seen.add(ins)) next.add(ins);
            if (i < c.length) {
              final sub = c.substring(0, i) + ch + c.substring(i + 1);
              if (seen.add(sub)) next.add(sub);
            }
          }
        }
      }
      frontier = next;
    }
    String got;
    try {
      got = g26.SuperDot3(rules: rules, topRuleName: top).recoverCost(s).toString();
    } catch (e) {
      got = 'X(${e.runtimeType})';
    }
    final want = truth?.toString() ?? '>3';
    print('${name.padRight(24)}${s.padRight(8)}true=${want.padLeft(3)}  '
        'm26=${got.padLeft(3)}   ${want == got ? "ok" : "MISMATCH"}');
  }
}
