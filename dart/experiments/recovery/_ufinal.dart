// Scratch: score the unification candidates against r4, and say WHERE each one
// differs rather than only by how much.
//
//   dart run _uscore.dart          identity-vs-r4 + battery line for each
//   dart run _uscore.dart time     alternating repeats, one clock

import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'r4.dart' as r4;
import '_r4u.dart' as u0;
import '_u3.dart' as u3;
import '_u9.dart' as u9;
import '_u10.dart' as u10;
import '_u10b.dart' as u10b;
import '_u11b.dart' as u11b;

typedef Make = MatchResult Function(String) Function(Map<String, Clause>, String);

final variants = <String, Make>{
  'r4': (r, t) => r4.Squirrel(rules: r, topRuleName: t).recover,
  'r4u': (r, t) => u0.Squirrel(rules: r, topRuleName: t).recover,
  'u3-no-del-break': (r, t) => u3.Squirrel(rules: r, topRuleName: t).recover,
  'u9-u8+onealloc': (r, t) => u9.Squirrel(rules: r, topRuleName: t).recover,
  'u10-pegGate+ceil': (r, t) => u10.Squirrel(rules: r, topRuleName: t).recover,
  'u10b-rootgate+ceil': (r, t) => u10b.Squirrel(rules: r, topRuleName: t).recover,
  'u11b-FINAL': (r, t) => u11b.Squirrel(rules: r, topRuleName: t).recover,
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

  if (argv.contains('time')) {
    for (var round = 0; round < 3; round++) {
      for (final e in variants.entries) {
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
        print('round $round ${e.key} ${sw.elapsedMilliseconds} ms');
      }
    }
    return;
  }

  // r4's answers are the reference: every variant is measured against them.
  final ref = <String>[];
  final refScore = <double>[];
  final base = {
    for (final c in corpora) c.name: variants['r4']!(rulesOf[c.name]!, c.top)
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
      e.key.padRight(20),
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
