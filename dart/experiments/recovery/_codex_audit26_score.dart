// Battery identity/score and alternating latency for audit scratch variants.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'r5.dart' as r5;
import '_v13.dart' as v13;
import '_codex_audit26_safe.dart' as safe;
import '_codex_audit26_prefix.dart' as prefix;
import '_codex_audit26_prune4.dart' as prune4;
import '_codex_audit26_denseprune.dart' as dense;
import '_codex_audit26_lencache.dart' as lencache;
import '_codex_audit26_deferred.dart' as lazy;
import '_codex_audit26_compact.dart' as compact;
import '_codex_audit26_cellmerge.dart' as cellmerge;
import '_codex_audit26_compactpeg.dart' as compactpeg;

typedef Make = dynamic Function(Map<String, Clause>, String);

final variants = <String, Make>{
  'r5': (r, t) => r5.Squirrel(rules: r, topRuleName: t),
  'v13': (r, t) => v13.Squirrel(rules: r, topRuleName: t),
  'safe2': (r, t) => safe.Squirrel(rules: r, topRuleName: t),
  'prefix': (r, t) => prefix.Squirrel(rules: r, topRuleName: t),
  'prune4': (r, t) => prune4.Squirrel(rules: r, topRuleName: t),
  'dense': (r, t) => dense.Squirrel(rules: r, topRuleName: t),
  'lencache': (r, t) => lencache.Squirrel(rules: r, topRuleName: t),
  'deferred': (r, t) => lazy.Squirrel(rules: r, topRuleName: t),
  'compact394': (r, t) => compact.Squirrel(rules: r, topRuleName: t),
  'cellmerge': (r, t) => cellmerge.Squirrel(rules: r, topRuleName: t),
  'compactpeg': (r, t) => compactpeg.Squirrel(rules: r, topRuleName: t),
};

String ser(MatchResult m) {
  final b = StringBuffer();
  void walk(MatchResult n) {
    b.write('${n.runtimeType}:${n.clause}:${n.pos}:${n.len}(');
    for (final child in n.subClauseMatches) walk(child);
    b.write(')');
  }

  walk(m);
  return b.toString();
}

void main(List<String> args) {
  final cases = weighted(buildBattery());
  final byCorpus = <String, Corpus>{for (final c in corpora) c.name: c};
  final rules = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  if (args.isNotEmpty && args.first == 'time') {
    final rounds = args.length > 1 ? int.parse(args[1]) : 7;
    final only =
        args.length > 2 ? args.sublist(2).toSet() : variants.keys.toSet();
    final times = <String, List<int>>{};
    for (var round = 0; round < rounds; round++) {
      for (final e in variants.entries) {
        if (!only.contains(e.key)) continue;
        final engines = {
          for (final c in corpora) c.name: e.value(rules[c.name]!, c.top)
        };
        final sw = Stopwatch()..start();
        for (final k in cases) engines[k.grammar]!.recover(k.mutant);
        sw.stop();
        (times[e.key] ??= []).add(sw.elapsedMilliseconds);
      }
    }
    for (final e in times.entries) {
      final sorted = e.value.toList()..sort();
      print('${e.key.padRight(12)} median=${sorted[sorted.length ~/ 2]} '
          'range=${sorted.first}-${sorted.last} rounds=${e.value}');
    }
    return;
  }
  final originals = <String, MatchResult>{};
  for (final c in corpora) {
    for (final input in c.documents) {
      originals['${c.name} $input'] =
          Parser(rules: rules[c.name]!, topRuleName: c.top, input: input)
              .parse()
              .root;
    }
  }
  final baseEngines = {
    for (final c in corpora) c.name: variants['r5']!(rules[c.name]!, c.top)
  };
  final baseTrees = <String>[];
  final baseScores = <double>[];
  for (final k in cases) {
    final tree = baseEngines[k.grammar]!.recover(k.mutant) as MatchResult;
    baseTrees.add(ser(tree));
    final corpus = byCorpus[k.grammar]!;
    baseScores.add(scoreCase(
      produced: tree,
      expected: expectedFor(
          k, originals['${k.grammar} ${k.original}']!, corpus.named),
      inputLen: k.mutant.length,
      named: corpus.named,
    ).score);
  }
  for (final e in variants.entries) {
    final engines = {
      for (final c in corpora) c.name: e.value(rules[c.name]!, c.top)
    };
    var diff = 0, better = 0, worse = 0, perfect = 0, crashed = 0;
    var total = 0.0;
    for (var i = 0; i < cases.length; i++) {
      final k = cases[i], corpus = byCorpus[k.grammar]!;
      MatchResult? tree;
      try {
        tree = engines[k.grammar]!.recover(k.mutant) as MatchResult;
      } catch (_) {
        crashed++;
      }
      final score = scoreCase(
        produced: tree,
        expected: expectedFor(
            k, originals['${k.grammar} ${k.original}']!, corpus.named),
        inputLen: k.mutant.length,
        named: corpus.named,
      ).score;
      total += score;
      if (score == 1) perfect++;
      if (tree == null || ser(tree) != baseTrees[i]) {
        diff++;
        if (score > baseScores[i] + 1e-12) better++;
        if (score < baseScores[i] - 1e-12) worse++;
      }
    }
    print(
        '${e.key.padRight(12)} score=${(total / cases.length).toStringAsFixed(4)} '
        'perfect=${(100 * perfect / cases.length).toStringAsFixed(1)}% '
        'diff=$diff(+$better/-$worse) crash=$crashed');
  }
}
