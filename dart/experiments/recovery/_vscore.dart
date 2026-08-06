// Scratch: score the chart variants against r5, saying WHERE each differs.
//   dart run _vscore.dart          identity-vs-r5 + battery line for each
//   dart run _vscore.dart time N   N alternating rounds on one clock
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'r5.dart' as r5;
import '_v1.dart' as v1;
import '_v2.dart' as v2;
import '_v3.dart' as v3;
import '_v4.dart' as v4;
import '_v5.dart' as v5;
import '_v6.dart' as v6;
import '_v7.dart' as v7;
import '_v8.dart' as v8;
import '_v9.dart' as v9;
import '_v10.dart' as v10;
import '_v11.dart' as v11;
import '_v12.dart' as v12;
import '_v13.dart' as v13;
import '_v14.dart' as v14;
import '_v15.dart' as v15;
import '_v16.dart' as v16;
import '_v19.dart' as v19;
import '_v20.dart' as v20;
import '_v21.dart' as v21;
import '_v22.dart' as v22;
import '_v23.dart' as v23;
import '_v24.dart' as v24;
import '_v18.dart' as v18;
import '_v17.dart' as v17;

typedef Make = MatchResult Function(String) Function(Map<String, Clause>, String);

final variants = <String, Make>{
  'r5-BASE': (r, t) => r5.Squirrel(rules: r, topRuleName: t).recover,
  'v1-ref-noprune': (r, t) => v1.Squirrel(rules: r, topRuleName: t).recover,
  'v2-afford-prefix': (r, t) => v2.Squirrel(rules: r, topRuleName: t).recover,
  'v3-seq-break': (r, t) => v3.Squirrel(rules: r, topRuleName: t).recover,
  'v4-rep-preprune': (r, t) => v4.Squirrel(rules: r, topRuleName: t).recover,
  'v5-rep-worklist': (r, t) => v5.Squirrel(rules: r, topRuleName: t).recover,
  'v6-v1+v2+v3': (r, t) => v6.Squirrel(rules: r, topRuleName: t).recover,
  'v7-v6+v4': (r, t) => v7.Squirrel(rules: r, topRuleName: t).recover,
  'v8-v7+v5': (r, t) => v8.Squirrel(rules: r, topRuleName: t).recover,
  'v9-v8+memoarray': (r, t) => v9.Squirrel(rules: r, topRuleName: t).recover,
  'v10-v8+prune2': (r, t) => v10.Squirrel(rules: r, topRuleName: t).recover,
  'v11-v8+both': (r, t) => v11.Squirrel(rules: r, topRuleName: t).recover,
  'v12-all-lean': (r, t) => v12.Squirrel(rules: r, topRuleName: t).recover,
  'v13-v12+improved': (r, t) => v13.Squirrel(rules: r, topRuleName: t).recover,
  'v14-improved-only': (r, t) => v14.Squirrel(rules: r, topRuleName: t).recover,
  'v15-v13-noprune2': (r, t) => v15.Squirrel(rules: r, topRuleName: t).recover,
  'v16-settled+seqclose': (r, t) => v16.Squirrel(rules: r, topRuleName: t).recover,
  'v19-settled+seqclose': (r, t) => v19.Squirrel(rules: r, topRuleName: t).recover,
  'v20-deferbuild': (r, t) => v20.Squirrel(rules: r, topRuleName: t).recover,
  'v21-budget0ispeg': (r, t) => v21.Squirrel(rules: r, topRuleName: t).recover,
  'v22-round0ispeg': (r, t) => v22.Squirrel(rules: r, topRuleName: t).recover,
  'v23-round0ispeg-fast': (r, t) => v23.Squirrel(rules: r, topRuleName: t).recover,
  'v24-seqfold-peg': (r, t) => v24.Squirrel(rules: r, topRuleName: t).recover,
  'v18-settled-only': (r, t) => v18.Squirrel(rules: r, topRuleName: t).recover,
  'v17-seqclose-only': (r, t) => v17.Squirrel(rules: r, topRuleName: t).recover,
};

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
      original['${c.name} $doc'] =
          Parser(rules: rulesOf[c.name]!, topRuleName: c.top, input: doc)
              .parse()
              .root;
    }
  }

  if (argv.isNotEmpty && argv.first == 'time') {
    final rounds = argv.length > 1 ? int.parse(argv[1]) : 5;
    final only = argv.length > 2 ? argv.sublist(2).toSet() : variants.keys.toSet();
    final got = <String, List<int>>{};
    for (var round = 0; round < rounds; round++) {
      for (final e in variants.entries) {
        if (!only.contains(e.key)) continue;
        final made = {
          for (final c in corpora) c.name: e.value(rulesOf[c.name]!, c.top)
        };
        final sw = Stopwatch()..start();
        for (final k in cases) {
          try {
            made[k.grammar]!(k.mutant);
          } catch (_) {}
        }
        sw.stop();
        (got[e.key] ??= []).add(sw.elapsedMilliseconds);
      }
    }
    for (final e in got.entries) {
      final v = e.value.toList()..sort();
      print('${e.key.padRight(18)} median ${v[v.length ~/ 2].toString().padLeft(5)}'
          '  range ${v.first}-${v.last}  ${e.value}');
    }
    return;
  }

  final ref = <String>[];
  final refScore = <double>[];
  final base = {
    for (final c in corpora) c.name: variants['r5-BASE']!(rulesOf[c.name]!, c.top)
  };
  for (final k in cases) {
    final c = byCorpus[k.grammar]!;
    final t = base[k.grammar]!(k.mutant);
    ref.add(ser(t));
    refScore.add(scoreCase(
      produced: t,
      expected: expectedFor(k, original['${k.grammar} ${k.original}']!, c.named),
      inputLen: k.mutant.length,
      named: c.named,
    ).score);
  }

  for (final e in variants.entries) {
    final made = {
      for (final c in corpora) c.name: e.value(rulesOf[c.name]!, c.top)
    };
    final catScore = <String, double>{};
    final catN = <String, int>{};
    var crashed = 0, uncovered = 0, perfect = 0;
    var differs = 0, better = 0, worse = 0;
    double total = 0, delta = 0;
    final sw = Stopwatch();
    for (var i = 0; i < cases.length; i++) {
      final k = cases[i];
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
      if (produced == null || ser(produced) != ref[i]) {
        differs++;
        if (s.score > refScore[i] + 1e-12) better++;
        if (s.score < refScore[i] - 1e-12) worse++;
        delta += s.score - refScore[i];
      }
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
      e.key.padRight(18),
      (total / cases.length).toStringAsFixed(4),
      (perfect / cases.length * 100).toStringAsFixed(1),
      'x$crashed',
      'u$uncovered',
      '${sw.elapsedMilliseconds}ms',
      'diff=$differs(+$better/-$worse ${delta >= 0 ? '+' : ''}'
          '${delta.toStringAsFixed(2)})',
      for (final k in cats) '$k=${(catScore[k]! / catN[k]!).toStringAsFixed(3)}',
    ].join(' '));
  }
}
