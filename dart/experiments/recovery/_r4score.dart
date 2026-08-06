// _r4score.dart -- score one r4 candidate on the same battery `_score1` uses,
// without touching the tracked gate. Same protocol: one engine per grammar, and
// the clock covers the engine only.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'r3.dart' as r3;
import 'r4.dart' as r4;
import '_r4slow.dart' as slow;
import '_r4nb.dart' as nb;
import '_r4v1.dart' as v1;
import '_r4v5.dart' as v5;
import '_r4v15.dart' as v15;
import '_r4v156.dart' as v156;
import '_r4v16.dart' as v16;
import '_r4v156s.dart' as v156s;
import '_r4v156t.dart' as v156t;
import '_r4v17.dart' as v17;
import '_r4v1t.dart' as v1t;
import '_r4v1s.dart' as v1s;
import '_r4v17t.dart' as v17t;
import '_r4v17s.dart' as v17s;
import '_r4v157t.dart' as v157t;
import '_r4v15t.dart' as v15t;
import '_r4v1u.dart' as v1u;
import '_r4v1ub.dart' as v1ub;
import '_r4v17u.dart' as v17u;
import '_r4v157u.dart' as v157u;
import '_r4v1uw.dart' as v1uw;
import '_r4v17ub.dart' as v17ub;
import '_r4v1un.dart' as v1un;
import '_r4v1tn.dart' as v1tn;
import '_r4v1ubn.dart' as v1ubn;
import '_r4v15un.dart' as v15un;
import '_r4v17un.dart' as v17un;
import '_r4v1unw.dart' as v1unw;
import '_r4v157un.dart' as v157un;
import '_r4v17tn.dart' as v17tn;
import '_r4v157tn.dart' as v157tn;
import '_r4v157tnx.dart' as v157tnx;
import '_r4v157tnq.dart' as v157tnq;
import '_r4v157tne.dart' as v157tne;
import '_r4v1x.dart' as v1x;
import '_r4v1q.dart' as v1q;
import '_r4v1e.dart' as v1e;
import '_r4v15x.dart' as v15x;
import '_r4v17x.dart' as v17x;
import '_r4v1tnx.dart' as v1tnx;
import '_r4v157x.dart' as v157x;
import '_r4v15tnx.dart' as v15tnx;
import '_r4v17tnx.dart' as v17tnx;
import '_r4v1f.dart' as v1f;
import '_r4v1Hf.dart' as v1Hf;
import '_r4v1ftn.dart' as v1ftn;
import '_r4v1h.dart' as v1h;
import '_r4v1hf.dart' as v1hf;
import '_r4v1hftn.dart' as v1hftn;
import '_r4v1fx.dart' as v1fx;
import '_r4v1hftnx.dart' as v1hftnx;

typedef Build = MatchResult? Function(String) Function(
    Map<String, Clause>, String);

final builds = <String, Build>{
  'r3': (r, t) => r3.Squirrel(rules: r, topRuleName: t).recover,
  'r4': (r, t) => r4.Squirrel(rules: r, topRuleName: t).recover,
  'nb': (r, t) => nb.Squirrel(rules: r, topRuleName: t).recover,
  'slow': (r, t) => slow.Squirrel(rules: r, topRuleName: t).recover,
  'v1': (r, t) => v1.Squirrel(rules: r, topRuleName: t).recover,
  'v5': (r, t) => v5.Squirrel(rules: r, topRuleName: t).recover,
  'v15': (r, t) => v15.Squirrel(rules: r, topRuleName: t).recover,
  'v16': (r, t) => v16.Squirrel(rules: r, topRuleName: t).recover,
  'v156': (r, t) => v156.Squirrel(rules: r, topRuleName: t).recover,
  'v156s': (r, t) => v156s.Squirrel(rules: r, topRuleName: t).recover,
  'v156t': (r, t) => v156t.Squirrel(rules: r, topRuleName: t).recover,
  'v17': (r, t) => v17.Squirrel(rules: r, topRuleName: t).recover,
  'v1t': (r, t) => v1t.Squirrel(rules: r, topRuleName: t).recover,
  'v1s': (r, t) => v1s.Squirrel(rules: r, topRuleName: t).recover,
  'v17t': (r, t) => v17t.Squirrel(rules: r, topRuleName: t).recover,
  'v17s': (r, t) => v17s.Squirrel(rules: r, topRuleName: t).recover,
  'v157t': (r, t) => v157t.Squirrel(rules: r, topRuleName: t).recover,
  'v15t': (r, t) => v15t.Squirrel(rules: r, topRuleName: t).recover,
  'v1u': (r, t) => v1u.Squirrel(rules: r, topRuleName: t).recover,
  'v1ub': (r, t) => v1ub.Squirrel(rules: r, topRuleName: t).recover,
  'v17u': (r, t) => v17u.Squirrel(rules: r, topRuleName: t).recover,
  'v157u': (r, t) => v157u.Squirrel(rules: r, topRuleName: t).recover,
  'v1uw': (r, t) => v1uw.Squirrel(rules: r, topRuleName: t).recover,
  'v17ub': (r, t) => v17ub.Squirrel(rules: r, topRuleName: t).recover,
  'v1un': (r, t) => v1un.Squirrel(rules: r, topRuleName: t).recover,
  'v1tn': (r, t) => v1tn.Squirrel(rules: r, topRuleName: t).recover,
  'v1ubn': (r, t) => v1ubn.Squirrel(rules: r, topRuleName: t).recover,
  'v15un': (r, t) => v15un.Squirrel(rules: r, topRuleName: t).recover,
  'v17un': (r, t) => v17un.Squirrel(rules: r, topRuleName: t).recover,
  'v1unw': (r, t) => v1unw.Squirrel(rules: r, topRuleName: t).recover,
  'v157un': (r, t) => v157un.Squirrel(rules: r, topRuleName: t).recover,
  'v17tn': (r, t) => v17tn.Squirrel(rules: r, topRuleName: t).recover,
  'v157tn': (r, t) => v157tn.Squirrel(rules: r, topRuleName: t).recover,
  'v157tnx': (r, t) => v157tnx.Squirrel(rules: r, topRuleName: t).recover,
  'v157tnq': (r, t) => v157tnq.Squirrel(rules: r, topRuleName: t).recover,
  'v157tne': (r, t) => v157tne.Squirrel(rules: r, topRuleName: t).recover,
  'v1x': (r, t) => v1x.Squirrel(rules: r, topRuleName: t).recover,
  'v1q': (r, t) => v1q.Squirrel(rules: r, topRuleName: t).recover,
  'v1e': (r, t) => v1e.Squirrel(rules: r, topRuleName: t).recover,
  'v15x': (r, t) => v15x.Squirrel(rules: r, topRuleName: t).recover,
  'v17x': (r, t) => v17x.Squirrel(rules: r, topRuleName: t).recover,
  'v1tnx': (r, t) => v1tnx.Squirrel(rules: r, topRuleName: t).recover,
  'v157x': (r, t) => v157x.Squirrel(rules: r, topRuleName: t).recover,
  'v15tnx': (r, t) => v15tnx.Squirrel(rules: r, topRuleName: t).recover,
  'v17tnx': (r, t) => v17tnx.Squirrel(rules: r, topRuleName: t).recover,
  'v1f': (r, t) => v1f.Squirrel(rules: r, topRuleName: t).recover,
  'v1Hf': (r, t) => v1Hf.Squirrel(rules: r, topRuleName: t).recover,
  'v1ftn': (r, t) => v1ftn.Squirrel(rules: r, topRuleName: t).recover,
  'v1h': (r, t) => v1h.Squirrel(rules: r, topRuleName: t).recover,
  'v1hf': (r, t) => v1hf.Squirrel(rules: r, topRuleName: t).recover,
  'v1hftn': (r, t) => v1hftn.Squirrel(rules: r, topRuleName: t).recover,
  'v1fx': (r, t) => v1fx.Squirrel(rules: r, topRuleName: t).recover,
  'v1hftnx': (r, t) => v1hftnx.Squirrel(rules: r, topRuleName: t).recover,
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
