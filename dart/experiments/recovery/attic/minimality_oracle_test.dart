// Verifies that RepairSearch achieves the true minimum edit cost, by
// comparing against a brute-force breadth-first search over the Damerau-
// Levenshtein edit ball (using the pure parser as recognizer).

import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/recovery/recovery.dart';
import 'package:test/test.dart';

import 'oracle.dart';

/// Deterministic pseudo-random generator (LCG) so tests are reproducible.
class Lcg {
  int state;
  Lcg(this.state);
  int next(int bound) {
    state = (state * 1103515245 + 12345) & 0x7fffffff;
    return state % bound;
  }
}

void checkAgainstOracle(String name, String grammarSpec, String top, List<String> inputs) {
  final rules = MetaGrammar.parseGrammar(grammarSpec);
  final search = RepairSearch(rules: rules, topRuleName: top);
  for (final input in inputs) {
    final result = search.repair(input);
    final oracleCost = bruteForceMinRepairCost(rules, top, input, maxCost: 3);
    if (oracleCost == null) {
      // Oracle couldn't determine (cost > 3 or state blowup); only require
      // that the search found *some* repair costing more than the oracle
      // horizon, or found one at all.
      expect(result, isNotNull, reason: '$name: search failed on "$input"');
      expect(result!.cost > 3, isTrue,
          reason: '$name: search found cost ${result.cost} on "$input" but oracle found none <= 3');
      continue;
    }
    expect(result, isNotNull, reason: '$name: no repair found for "$input" (oracle: $oracleCost)');
    expect(result!.cost, equals(oracleCost),
        reason: '$name: non-minimal repair for "$input": got cost ${result.cost} '
            '("${result.repaired}"), oracle min is $oracleCost');
    // The repaired string must actually be in L(G).
    expect(parsesFully(rules, top, result.repaired), isTrue,
        reason: '$name: repaired string "${result.repaired}" does not parse');
  }
}

/// Generate all single mutations of [s] (delete, transpose, substitute,
/// insert) using [chars] as the mutation alphabet.
List<String> singleMutations(String s, String chars, Lcg rng, {int limit = 40}) {
  final out = <String>{};
  for (var j = 0; j < s.length; j++) {
    out.add(s.substring(0, j) + s.substring(j + 1));
    if (j + 1 < s.length && s[j] != s[j + 1]) {
      out.add(s.substring(0, j) + s[j + 1] + s[j] + s.substring(j + 2));
    }
  }
  for (var k = 0; k < limit; k++) {
    final j = rng.next(s.length + 1);
    final c = chars[rng.next(chars.length)];
    out.add(s.substring(0, j) + c + s.substring(j));
    if (j < s.length) out.add(s.substring(0, j) + c + s.substring(j + 1));
  }
  return out.toList();
}

void main() {
  test('oracle agreement: tiny Seq grammar', () {
    checkAgainstOracle('seq', 'S <- "a" "b" "c" ;', 'S',
        ['abc', 'ab', 'ac', 'bc', 'abcd', 'aXbc', 'acb', 'bac', 'a', '', 'Xabc', 'abX', 'aXbYc']);
  });

  test('oracle agreement: choice grammar', () {
    checkAgainstOracle('choice', 'S <- "ab" "c" / "b" "d" ;', 'S',
        ['abc', 'bd', 'bc', 'ad', 'abd', 'ab', 'b', 'Xbd', 'aXbc']);
  });

  test('oracle agreement: bracketed list', () {
    const g = 'S <- "[" (N ("," N)*)? "]" ;\nN <- [0-9] ;';
    checkAgainstOracle('list', g, 'S',
        ['[]', '[1]', '[1,2]', '[12]', '[1,]', '[,1]', '1,2]', '[1,2', '[1;2]', '[[1]', '[1 2]']);
  });

  test('oracle agreement: left-recursive expressions', () {
    const g = '''
      E <- E "+" T / T ;
      T <- T "*" F / F ;
      F <- "(" E ")" / [0-9] ;
    ''';
    checkAgainstOracle('expr', g, 'E',
        ['1+2', '1+', '+2', '1++2', '12+3', '(1+2', '1+2)', '1*+2', '1Q2', '(1+2)*3', '((1)', '*']);
  });

  test('oracle agreement: lookahead grammar', () {
    // NotFollowedBy makes repairs subtle: a repair may need to *break* an
    // unwanted match rather than complete a wanted one.
    const g = 'S <- ("a" !"x" [a-z])+ ;';
    checkAgainstOracle('lookahead', g, 'S', ['ab', 'ax', 'abab', 'axab', 'aab', 'a', 'abX']);
  });

  test('oracle agreement: randomized mutations of valid inputs', () {
    final rng = Lcg(42);
    const g = 'S <- "[" (N ("," N)*)? "]" ;\nN <- [0-9] ;';
    for (final valid in ['[1,2,3]', '[7]', '[]']) {
      final mutants = singleMutations(valid, '[],019Q', rng, limit: 20);
      checkAgainstOracle('rand-list', g, 'S', mutants);
    }
    final rulesE = MetaGrammar.parseGrammar('''
      E <- E "+" T / T ;
      T <- T "*" F / F ;
      F <- "(" E ")" / [0-9] ;
    ''');
    final searchE = RepairSearch(rules: rulesE, topRuleName: 'E');
    for (final valid in ['1+2*3', '(1+2)']) {
      for (final m in singleMutations(valid, '+*()19Q', rng, limit: 20)) {
        final r = searchE.repair(m);
        final oracle = bruteForceMinRepairCost(rulesE, 'E', m, maxCost: 2);
        if (oracle != null) {
          expect(r, isNotNull, reason: 'no repair for "$m"');
          expect(r!.cost, equals(oracle), reason: 'non-minimal for "$m": ${r.cost} vs $oracle');
        }
      }
    }
  });
}
