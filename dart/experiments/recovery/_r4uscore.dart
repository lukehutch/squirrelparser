// Scratch: is _r4u.dart (the unified form) the same engine as r4.dart?
//
// Two checks, the second much stronger than the first:
//   1. the battery line, so the headline numbers can be compared directly;
//   2. TREE IDENTITY -- both engines run over all 1824 cases and their emitted
//      trees are serialized and compared node for node, along with `lastCost`.
//
// A refactor that merges two fields into one is only safe if it changes nothing
// at all, and four matching decimals do not prove that: two engines can differ
// on a case and score the same. Serialized trees do prove it.

import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'r4.dart' as r4;
import '_r4u.dart' as r4u;

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

void main(List<String> argv) {
  final cases = weighted(buildBattery());
  final byCorpus = <String, Corpus>{for (final c in corpora) c.name: c};
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };

  final original = <String, MatchResult>{};
  for (final c in corpora) {
    for (final doc in c.documents) {
      final r = Parser(rules: rulesOf[c.name]!, topRuleName: c.top, input: doc)
          .parse();
      original['${c.name} $doc'] = r.root;
    }
  }

  // -- tree identity ---------------------------------------------------------
  final a = <String, r4.Squirrel>{};
  final b = <String, r4u.Squirrel>{};
  for (final c in corpora) {
    a[c.name] = r4.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top);
    b[c.name] = r4u.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top);
  }
  if (argv.contains('time')) {
    // ALTERNATING REPEATS ON ONE CLOCK. Two processes would price two JIT
    // warmups as though the engines had spent them, and running each once in
    // order would hand the second one the first one's warm library code.
    for (var round = 0; round < 3; round++) {
      for (final name in ['r4', 'r4u']) {
        final made = <String, MatchResult Function(String)>{};
        for (final c in corpora) {
          made[c.name] = name == 'r4'
              ? r4.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top).recover
              : r4u.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top)
                  .recover;
        }
        final sw = Stopwatch()..start();
        for (final k in cases) {
          try {
            made[k.grammar]!(k.mutant);
          } catch (_) {}
        }
        sw.stop();
        print('round $round $name ${sw.elapsedMilliseconds} ms');
      }
    }
    return;
  }

  var same = 0, diffTree = 0, diffCost = 0, bothThrew = 0, oneThrew = 0;
  final examples = <String>[];
  for (final k in cases) {
    String? sa, sb;
    int ca = -1, cb = -1;
    try {
      final t = a[k.grammar]!.recover(k.mutant);
      sa = ser(t);
      ca = a[k.grammar]!.lastCost;
    } catch (_) {}
    try {
      final t = b[k.grammar]!.recover(k.mutant);
      sb = ser(t);
      cb = b[k.grammar]!.lastCost;
    } catch (_) {}
    if (sa == null && sb == null) {
      bothThrew++;
      continue;
    }
    if (sa == null || sb == null) {
      oneThrew++;
      if (examples.length < 5) examples.add('THREW ${k.grammar} ${k.mutant}');
      continue;
    }
    if (sa != sb) {
      diffTree++;
      if (examples.length < 5) examples.add('TREE  ${k.grammar} ${k.mutant}');
      continue;
    }
    if (ca != cb) {
      diffCost++;
      if (examples.length < 5) {
        examples.add('COST  ${k.grammar} ${k.mutant} $ca vs $cb');
      }
      continue;
    }
    same++;
  }
  print('identity: same=$same diffTree=$diffTree diffCost=$diffCost '
      'bothThrew=$bothThrew oneThrew=$oneThrew  of ${cases.length}');
  for (final e in examples) {
    print('  $e');
  }

  // -- the battery line for each -------------------------------------------
  for (final name in ['r4', 'r4u']) {
    final made = <String, MatchResult Function(String)>{};
    for (final c in corpora) {
      made[c.name] = name == 'r4'
          ? r4.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top).recover
          : r4u.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top).recover;
    }
    final catScore = <String, double>{};
    final catN = <String, int>{};
    var crashed = 0, uncovered = 0, perfect = 0;
    double total = 0;
    final sw = Stopwatch();
    for (final k in cases) {
      final c = byCorpus[k.grammar]!;
      MatchResult? produced;
      sw.start();
      try {
        produced = made[k.grammar]!(k.mutant);
      } catch (_) {
        produced = null;
      }
      sw.stop();
      final s = scoreCase(
        produced: produced,
        expected:
            expectedFor(k, original['${k.grammar} ${k.original}']!, c.named),
        inputLen: k.mutant.length,
        named: c.named,
      );
      if (s.crashed) crashed++;
      if (!s.covered) uncovered++;
      if (s.score == 1.0) perfect++;
      total += s.score;
      catScore[k.category] = (catScore[k.category] ?? 0) + s.score;
      catN[k.category] = (catN[k.category] ?? 0) + 1;
    }
    final cats = catN.keys.toList()
      ..sort((x, y) => categoryWeight[y]!.compareTo(categoryWeight[x]!));
    print([
      name,
      (total / cases.length).toStringAsFixed(4),
      (perfect / cases.length * 100).toStringAsFixed(1),
      '$crashed',
      '$uncovered',
      '${sw.elapsedMilliseconds}',
      for (final k in cats) '$k=${(catScore[k]! / catN[k]!).toStringAsFixed(3)}',
    ].join(' '));
  }
}
