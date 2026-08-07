/// Brute-force minimality oracle for the repair search.
///
/// Computes the true minimum Damerau-Levenshtein distance from an input to
/// L(G) by breadth-first search over the edit ball, using the pure parser as
/// a recognizer. Exponential: only usable for tiny inputs/grammars, as a
/// ground-truth check that RepairSearch achieves minimal cost.
library;

import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/recovery/observed_grammar.dart' show expectedCharOf;

/// Collect a candidate insertion alphabet: every character mentioned by any
/// terminal of the grammar, plus representatives of char sets, plus the
/// characters of the input.
Set<String> grammarAlphabet(Map<String, Clause> rules, String input) {
  final alphabet = <String>{};
  final seen = <Clause>{};
  void walk(Clause c) {
    if (!seen.add(c)) return;
    if (c is Char) alphabet.add(c.char);
    if (c is Str) alphabet.addAll(c.text.split(''));
    if (c is CharSet) {
      final rep = expectedCharOf(c, '', 0);
      if (rep != null) alphabet.add(rep.char);
      // Also add both endpoints of each range for better coverage.
      if (!c.inverted) {
        for (final (lo, hi) in c.ranges) {
          alphabet.add(String.fromCharCode(lo));
          alphabet.add(String.fromCharCode(hi));
        }
      }
    }
    if (c is HasOneSubClause) walk(c.subClause);
    if (c is HasMultipleSubClauses) c.subClauses.forEach(walk);
  }

  for (final clause in rules.values) {
    walk(clause);
  }
  alphabet.addAll(input.split(''));
  return alphabet;
}

bool parsesFully(Map<String, Clause> rules, String top, String s) {
  final result = Parser(rules: rules, topRuleName: top, input: s).parse();
  return !result.hasSyntaxErrors;
}

/// True minimum Damerau-Levenshtein distance from [input] to L(G), or null
/// if none found within [maxCost].
int? bruteForceMinRepairCost(Map<String, Clause> rules, String top, String input,
    {int maxCost = 3, int maxStates = 2000000}) {
  final alphabet = grammarAlphabet(rules, input);
  var frontier = <String>{input};
  final visited = <String>{input};
  var states = 0;
  for (var cost = 0; cost <= maxCost; cost++) {
    for (final s in frontier) {
      if (parsesFully(rules, top, s)) return cost;
    }
    if (cost == maxCost) break;
    final next = <String>{};
    for (final s in frontier) {
      // Deletions
      for (var j = 0; j < s.length; j++) {
        final t = s.substring(0, j) + s.substring(j + 1);
        if (visited.add(t)) next.add(t);
      }
      // Transpositions
      for (var j = 0; j + 1 < s.length; j++) {
        if (s[j] == s[j + 1]) continue;
        final t = s.substring(0, j) + s[j + 1] + s[j] + s.substring(j + 2);
        if (visited.add(t)) next.add(t);
      }
      // Insertions and substitutions
      for (var j = 0; j <= s.length; j++) {
        for (final c in alphabet) {
          final ins = s.substring(0, j) + c + s.substring(j);
          if (visited.add(ins)) next.add(ins);
          if (j < s.length && s[j] != c) {
            final sub = s.substring(0, j) + c + s.substring(j + 1);
            if (visited.add(sub)) next.add(sub);
          }
        }
      }
      states += next.length;
      if (states > maxStates) return null;
    }
    frontier = next;
  }
  return null;
}
