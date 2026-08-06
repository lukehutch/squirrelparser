// _r3score.dart -- score a scratch r3 candidate on the same battery _score1
// uses, without touching the tracked gate. Same protocol: one engine per
// grammar, clock covers the engine only.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_r3x.dart' as x;
import '_r3xa.dart' as xa;
import '_r3xb.dart' as xb;
import '_r3xc.dart' as xc;
import '_r3xd.dart' as xd;
import 'r2.dart' as r2;
import '_r3t5.dart' as t5;
import '_r3t2.dart' as t2;
import '_r3t4.dart' as t4;
import '_r3t24.dart' as t24;
import 'r3.dart' as r3;
import '_r3a.dart' as r3a;
import '_r3a2.dart' as r3a2;
import '_r3a3.dart' as r3a3;
import '_r3b2.dart' as r3b2;
import '_r3ab3.dart' as r3ab3;
import '_r3ab4.dart' as r3ab4;
import '_r3b.dart' as r3b;
import '_r3ab2.dart' as r3ab2;
import '_r3cap4.dart' as cap4;
import '_r3cap6.dart' as cap6;
import '_r3cap8.dart' as cap8;
import '_r3cap12.dart' as cap12;
import '_r3cap20.dart' as cap20;

typedef Build = MatchResult? Function(String) Function(
    Map<String, Clause>, String);

final builds = <String, Build>{
  'r2': (r, t) => r2.Squirrel(rules: r, topRuleName: t).recover,
  'xa': (r, t) => xa.Squirrel(rules: r, topRuleName: t).recover,
  'xb': (r, t) => xb.Squirrel(rules: r, topRuleName: t).recover,
  'x': (r, t) => x.Squirrel(rules: r, topRuleName: t).recover,
  'xc': (r, t) => xc.Squirrel(rules: r, topRuleName: t).recover,
  'xd': (r, t) => xd.Squirrel(rules: r, topRuleName: t).recover,
  'r3': (r, t) => r3.Squirrel(rules: r, topRuleName: t).recover,
  't5': (r, t) => t5.Squirrel(rules: r, topRuleName: t).recover,
  't2': (r, t) => t2.Squirrel(rules: r, topRuleName: t).recover,
  't4': (r, t) => t4.Squirrel(rules: r, topRuleName: t).recover,
  't24': (r, t) => t24.Squirrel(rules: r, topRuleName: t).recover,
  'r3a': (r, t) => r3a.Squirrel(rules: r, topRuleName: t).recover,
  'r3a2': (r, t) => r3a2.Squirrel(rules: r, topRuleName: t).recover,
  'r3a3': (r, t) => r3a3.Squirrel(rules: r, topRuleName: t).recover,
  'r3b2': (r, t) => r3b2.Squirrel(rules: r, topRuleName: t).recover,
  'r3ab3': (r, t) => r3ab3.Squirrel(rules: r, topRuleName: t).recover,
  'r3ab4': (r, t) => r3ab4.Squirrel(rules: r, topRuleName: t).recover,
  'r3b': (r, t) => r3b.Squirrel(rules: r, topRuleName: t).recover,
  'r3ab': (r, t) => r3ab2.Squirrel(rules: r, topRuleName: t).recover,
  'cap4': (r, t) => cap4.Squirrel(rules: r, topRuleName: t).recover,
  'cap6': (r, t) => cap6.Squirrel(rules: r, topRuleName: t).recover,
  'cap8': (r, t) => cap8.Squirrel(rules: r, topRuleName: t).recover,
  'cap12': (r, t) => cap12.Squirrel(rules: r, topRuleName: t).recover,
  'cap20': (r, t) => cap20.Squirrel(rules: r, topRuleName: t).recover,
};

void main(List<String> argv) {
  final name = argv[0];
  final build = builds[name];
  if (build == null) {
    print('$name UNKNOWN');
    return;
  }
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
  final made = <String, MatchResult? Function(String)>{};
  for (final c in corpora) {
    made[c.name] = build(rulesOf[c.name]!, c.top);
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
      expected: expectedFor(k, original['${k.grammar} ${k.original}']!, c.named),
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
    ..sort((a, b) => categoryWeight[b]!.compareTo(categoryWeight[a]!));
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
