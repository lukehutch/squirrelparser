// _where.dart -- WHERE DOES THE TIME GO, BY CATEGORY?
//
// The aggregate latency number says an engine is 3.9x slower. It does not say
// on WHICH inputs, and the two possibilities have completely different fixes:
// uniformly slower is an implementation problem, while slow on one category is
// an algorithmic one.
//
// The hypothesis under test: m82's deepening ladder runs `budget = 0,1,2,4,...`
// up to `cap = 2*len + witness + 1`, and it only stops early when a whole-input
// tree is FOUND. An input where no cheap whole-input tree exists therefore pays
// every rung of the ladder, and the rungs near the top allow skips of up to
// `budget` characters at every position. Truncated input is exactly that case --
// and `truncate` is both the highest-weight category (3.0) and the worst-scoring
// one for both engine generations. If it is also the slowest, then the quality
// hole and the latency hole are the same hole.
//
// Reports per category: mean score, total ms, ms per case, and share of total
// time -- so a category that is 5% of the cases but 60% of the clock is visible.
//
// Usage: dart run _where.dart <engineName> [...]
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'final_table.dart' show engines;
import 'm79.dart' as g79;
import 'm80.dart' as g80;
import 'm81.dart' as g81;
import 'm82.dart' as g82;
import 'm83.dart' as g83;
import 'm84.dart' as g84;
import 'm85.dart' as g85;
import 'm86.dart' as g86;
import 'm87.dart' as g87;
import 'm88.dart' as g88;
import 'm89.dart' as g89;
import 'm90.dart' as g90;
import 'm92.dart' as g92;

typedef Build = MatchResult? Function(String) Function(
    Map<String, Clause>, String);

final Map<String, Build> extra = {
  'm79': (r, t) => g79.SuperDot3(rules: r, topRuleName: t).recover,
  'm80': (r, t) => g80.SuperDot3(rules: r, topRuleName: t).recover,
  'm81': (r, t) => g81.SuperDot3(rules: r, topRuleName: t).recover,
  'm82': (r, t) => g82.SuperDot3(rules: r, topRuleName: t).recover,
  'm83': (r, t) => g83.SuperDot3(rules: r, topRuleName: t).recover,
  'm84': (r, t) => g84.SuperDot3(rules: r, topRuleName: t).recover,
  'm85': (r, t) => g85.SuperDot3(rules: r, topRuleName: t).recover,
  'm86': (r, t) => g86.SuperDot3(rules: r, topRuleName: t).recover,
  'm87': (r, t) => g87.SuperDot3(rules: r, topRuleName: t).recover,
  'm88': (r, t) => g88.SuperDot3(rules: r, topRuleName: t).recover,
  'm89': (r, t) => g89.SuperDot3(rules: r, topRuleName: t).recover,
  'm90': (r, t) => g90.SuperDot3(rules: r, topRuleName: t).recover,
  'm92': (r, t) => g92.SuperDot3(rules: r, topRuleName: t).recover,
};

Build? resolve(String name) {
  if (extra.containsKey(name)) return extra[name];
  for (final e in engines) {
    if (e.name == name) {
      return (r, t) {
        final made = e.make(r, t);
        return (String s) => made.$1(s).root;
      };
    }
  }
  return null;
}

void main(List<String> argv) {
  final cases = weighted(buildBattery());
  final byCorpus = <String, Corpus>{for (final c in corpora) c.name: c};
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final original = <String, MatchResult>{};
  for (final c in corpora) {
    for (final doc in c.documents) {
      final r =
          Parser(rules: rulesOf[c.name]!, topRuleName: c.top, input: doc).parse();
      original['${c.name} $doc'] = r.root;
    }
  }

  for (final name in argv) {
    final build = resolve(name);
    if (build == null) {
      print('$name UNKNOWN');
      continue;
    }
    final made = <String, MatchResult? Function(String)>{
      for (final c in corpora) c.name: build(rulesOf[c.name]!, c.top)
    };
    final catUs = <String, int>{};
    final catN = <String, int>{};
    final catScore = <String, double>{};
    final sw = Stopwatch();
    for (final k in cases) {
      final c = byCorpus[k.grammar]!;
      MatchResult? produced;
      sw.reset();
      sw.start();
      try {
        produced = made[k.grammar]!(k.mutant);
      } catch (_) {
        produced = null;
      }
      sw.stop();
      catUs[k.category] = (catUs[k.category] ?? 0) + sw.elapsedMicroseconds;
      catN[k.category] = (catN[k.category] ?? 0) + 1;
      catScore[k.category] = (catScore[k.category] ?? 0) +
          scoreCase(
            produced: produced,
            expected: expectedFor(k, original['${k.grammar} ${k.original}']!, c.named),
            inputLen: k.mutant.length,
            named: c.named,
          ).score;
    }
    final totalUs = catUs.values.fold(0, (a, b) => a + b);
    print('=== $name   total ${(totalUs / 1000).toStringAsFixed(0)} ms ===');
    print('category            n   score      ms    us/case   share');
    final cats = catUs.keys.toList()
      ..sort((a, b) => catUs[b]!.compareTo(catUs[a]!));
    for (final k in cats) {
      print('${k.padRight(16)}${catN[k].toString().padLeft(5)}'
          '${(catScore[k]! / catN[k]!).toStringAsFixed(3).padLeft(8)}'
          '${(catUs[k]! / 1000).toStringAsFixed(0).padLeft(8)}'
          '${(catUs[k]! / catN[k]!).toStringAsFixed(0).padLeft(11)}'
          '${(catUs[k]! / totalUs * 100).toStringAsFixed(1).padLeft(7)}%');
    }
    print('');
  }
}
