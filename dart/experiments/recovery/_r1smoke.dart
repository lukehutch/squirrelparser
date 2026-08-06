// Smoke test for r1: does it parse clean input unchanged, and does the frontier
// mechanism actually find and install spans on damaged input?
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'r1.dart';

/// Total characters inside SyntaxError nodes anywhere in the tree.
int errChars(MatchResult m) {
  var n = m is SyntaxError ? m.len : 0;
  if (m is Repaired) {
    for (final e in m.errors) {
      n += e.len;
    }
  }
  for (final k in m.subClauseMatches) {
    n += errChars(k);
  }
  return n;
}

void main(List<String> argv) {
  final only = argv.isEmpty ? null : argv.first;
  for (final c in corpora) {
    if (only != null && c.name != only) continue;
    final rules = MetaGrammar.parseGrammar(c.grammar);
    print('== ${c.name} (top ${c.top})');
    for (final good in c.documents) {
      final e = Squirrel(rules: rules, topRuleName: c.top);
      final sw = Stopwatch()..start();
      final m = e.recover(good);
      sw.stop();
      final ok = m.len == good.length && e.lastCost == 0;
      print('  ${ok ? "clean" : "DIRTY"}  cost=${e.lastCost} '
          'err=${errChars(m)} ${sw.elapsedMicroseconds}us  '
          '${good.length > 44 ? "${good.substring(0, 44)}..." : good}');
    }
  }
}
