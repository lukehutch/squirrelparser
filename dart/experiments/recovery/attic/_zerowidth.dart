// _zerowidth.dart -- how often does an engine emit a NAMED node that covers no
// character of the input?
//
// The brief forbids inventing terminals of a class that are not there. A named
// node of width 0 is exactly that: a `Number` where the document ended, an
// `Expr` conjured to close a dangling `Member`. The AST-diff battery charges it
// only indirectly -- via the edit distance to the expected skeleton -- so an
// engine can carry the habit at a cost of a few thousandths and never be named
// for it.
//
// `astdiff.dart` records that no named node in any corpus is zero-width
// (0 of 667), so every hit here is invention, not a grammar artifact.
//
// Usage: dart run _zerowidth.dart [engine ...]
import 'package:squirrel_parser/squirrel_parser.dart';

import '_score1.dart' show resolve;
import 'astdiff.dart';

int zeros(MatchResult m, Set<String> named) {
  var n = 0;
  void walk(MatchResult k) {
    final c = k.clause;
    if (c is Ref && named.contains(c.ruleName) && k.len == 0) n++;
    k.subClauseMatches.forEach(walk);
  }

  walk(m);
  return n;
}

void main(List<String> argv) {
  final names = argv.isEmpty
      ? const ['m121', 'm126', 'm127', 'm132', 'm136']
      : argv;
  final byCorpus = {for (final c in corpora) c.name: c};
  final rulesOf = {
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };

  // Distinct cases only: the battery repeats each one once per unit of weight.
  final seen = <String>{};
  final cases = <Case>[];
  for (final k in weighted(buildBattery())) {
    if (seen.add('${k.grammar}\x00${k.category}\x00${k.mutant}')) cases.add(k);
  }

  print('${'engine'.padRight(8)}${'cases hit'.padLeft(11)}'
      '${'nodes'.padLeft(8)}${'worst'.padLeft(7)}   by category');
  for (final e in names) {
    final b = resolve(e);
    if (b == null) {
      print('$e UNKNOWN');
      continue;
    }
    final made = {
      for (final c in corpora) c.name: b(rulesOf[c.name]!, c.top)
    };
    var hit = 0, total = 0, worst = 0;
    final byCat = <String, int>{};
    for (final k in cases) {
      MatchResult? p;
      try {
        p = made[k.grammar]!(k.mutant);
      } catch (_) {
        continue;
      }
      if (p == null) continue;
      final n = zeros(p, byCorpus[k.grammar]!.named);
      if (n == 0) continue;
      hit++;
      total += n;
      if (n > worst) worst = n;
      byCat[k.category] = (byCat[k.category] ?? 0) + 1;
    }
    final top = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    print('${e.padRight(8)}${'$hit/${cases.length}'.padLeft(11)}'
        '${total.toString().padLeft(8)}${worst.toString().padLeft(7)}   '
        '${top.take(4).map((x) => '${x.key} ${x.value}').join(', ')}');
  }
}
