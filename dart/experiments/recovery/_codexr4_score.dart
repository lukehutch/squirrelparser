import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'r4.dart' as base;
import '_codexr4_fixpeg.dart' as fixpeg;
import '_codexr4_fixstop.dart' as fixstop;
import '_codexr4_fixtop.dart' as fixtop;
import '_codexr4_fixceiling.dart' as fixceiling;
import '_codexr4_nomemoterm.dart' as nomemoterm;
import '_codexr4_predpure.dart' as predpure;
import '_codexr4_fast.dart' as fast;
import '_codexr4_residualguard.dart' as residualguard;
import '_codexr4_nomemoref.dart' as nomemoref;
import '_codexr4_fast2.dart' as fast2;
import '_codexr4_termref.dart' as termref;
import '_codexr4_termrefguard.dart' as termrefguard;
import '_codexr4_termrefpred.dart' as termrefpred;
import '_codexr4_candidate.dart' as candidate;
import '_codexr4_fixpeg2.dart' as fixpeg2;
import '_codexr4_fixtopzero.dart' as fixtopzero;
import '_codexr4_ablate_under400.dart' as under400;
import '_codexr4_under397.dart' as under397;
import '_codexr4_ablate_fix.dart' as nofix;
import '_codexr4_ablate_f.dart' as nof;
import '_codexr4_ablate_h.dart' as noh;
import '_codexr4_ablate_literal.dart' as nolit;
import '_codexr4_ablate_plus.dart' as noplus;
import '_codexr4_ablate_determined.dart' as nodetermined;

typedef Build = MatchResult? Function(String) Function(
    Map<String, Clause>, String);

final builds = <String, Build>{
  'base': (r, t) => base.Squirrel(rules: r, topRuleName: t).recover,
  'fixpeg': (r, t) => fixpeg.Squirrel(rules: r, topRuleName: t).recover,
  'fixstop': (r, t) => fixstop.Squirrel(rules: r, topRuleName: t).recover,
  'fixtop': (r, t) => fixtop.Squirrel(rules: r, topRuleName: t).recover,
  'fixceiling': (r, t) =>
      fixceiling.Squirrel(rules: r, topRuleName: t).recover,
  'nomemoterm': (r, t) =>
      nomemoterm.Squirrel(rules: r, topRuleName: t).recover,
  'predpure': (r, t) => predpure.Squirrel(rules: r, topRuleName: t).recover,
  'fast': (r, t) => fast.Squirrel(rules: r, topRuleName: t).recover,
  'residualguard': (r, t) =>
      residualguard.Squirrel(rules: r, topRuleName: t).recover,
  'nomemoref': (r, t) =>
      nomemoref.Squirrel(rules: r, topRuleName: t).recover,
  'fast2': (r, t) => fast2.Squirrel(rules: r, topRuleName: t).recover,
  'termref': (r, t) => termref.Squirrel(rules: r, topRuleName: t).recover,
  'termrefguard': (r, t) =>
      termrefguard.Squirrel(rules: r, topRuleName: t).recover,
  'termrefpred': (r, t) =>
      termrefpred.Squirrel(rules: r, topRuleName: t).recover,
  'candidate': (r, t) =>
      candidate.Squirrel(rules: r, topRuleName: t).recover,
  'fixpeg2': (r, t) => fixpeg2.Squirrel(rules: r, topRuleName: t).recover,
  'fixtopzero': (r, t) =>
      fixtopzero.Squirrel(rules: r, topRuleName: t).recover,
  'under400': (r, t) =>
      under400.Squirrel(rules: r, topRuleName: t).recover,
  'under397': (r, t) =>
      under397.Squirrel(rules: r, topRuleName: t).recover,
  'nofix': (r, t) => nofix.Squirrel(rules: r, topRuleName: t).recover,
  'nof': (r, t) => nof.Squirrel(rules: r, topRuleName: t).recover,
  'noh': (r, t) => noh.Squirrel(rules: r, topRuleName: t).recover,
  'nolit': (r, t) => nolit.Squirrel(rules: r, topRuleName: t).recover,
  'noplus': (r, t) => noplus.Squirrel(rules: r, topRuleName: t).recover,
  'nodetermined': (r, t) =>
      nodetermined.Squirrel(rules: r, topRuleName: t).recover,
};

void main(List<String> argv) {
  final name = argv.single;
  final build = builds[name];
  if (build == null) throw ArgumentError('unknown variant $name');
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
  final made = <String, MatchResult? Function(String)>{
    for (final c in corpora) c.name: build(rulesOf[c.name]!, c.top)
  };

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
    final score = scoreCase(
      produced: produced,
      expected: expectedFor(
          k, original['${k.grammar} ${k.original}']!, c.named),
      inputLen: k.mutant.length,
      named: c.named,
    );
    if (score.crashed) crashed++;
    if (!score.covered) uncovered++;
    if (score.score == 1.0) perfect++;
    total += score.score;
    catScore[k.category] = (catScore[k.category] ?? 0) + score.score;
    catN[k.category] = (catN[k.category] ?? 0) + 1;
  }
  final cats = catN.keys.toList()
    ..sort((a, b) => categoryWeight[b]!.compareTo(categoryWeight[a]!));
  print([
    name,
    (total / cases.length).toStringAsFixed(4),
    (perfect / cases.length * 100).toStringAsFixed(1),
    '$crashed',
    '$uncovered',
    '${sw.elapsedMilliseconds}',
    for (final k in cats)
      '$k=${(catScore[k]! / catN[k]!).toStringAsFixed(3)}',
  ].join(' '));
}
