// _score1.dart -- the battery runner for the kept engines (the rest live in
// attic/). One engine per invocation:
//
//   dart run _score1.dart <engineName> [dump]
//
// Prints one machine-readable line -- name, aggregate, perfect%, crashed,
// uncovered, ms, then category=mean pairs -- and with `dump`, one line per
// imperfect case sorted worst-first.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'c1.dart' as c1;
import 'c2.dart' as c2;
import 'c3.dart' as c3;
import 'c4.dart' as c4;
import 'm132.dart' as g132;
import 'm143.dart' as g143;
import 'r9.dart' as r9;
import 's1.dart' as s1;
import 's4.dart' as s4;
import 't1.dart' as t1;

typedef Build = MatchResult? Function(String) Function(
    Map<String, Clause>, String);

const Map<String, Build> engines = {
  'c4': _c4,
  'c3': _c3,
  'c2': _c2,
  'c1': _c1,
  's1': _s1,
  's4': _s4,
  'r9': _r9,
  'm143': _m143,
  'm132': _m132,
  't1': _t1,
};

MatchResult? Function(String) _c4(Map<String, Clause> r, String t) =>
    c4.Squirrel(rules: r, topRuleName: t).recover;
MatchResult? Function(String) _c3(Map<String, Clause> r, String t) =>
    c3.Squirrel(rules: r, topRuleName: t).recover;
MatchResult? Function(String) _c2(Map<String, Clause> r, String t) =>
    c2.Squirrel(rules: r, topRuleName: t).recover;
MatchResult? Function(String) _c1(Map<String, Clause> r, String t) =>
    c1.Squirrel(rules: r, topRuleName: t).recover;
MatchResult? Function(String) _s1(Map<String, Clause> r, String t) =>
    s1.Squirrel(rules: r, topRuleName: t).recover;
MatchResult? Function(String) _s4(Map<String, Clause> r, String t) =>
    s4.Squirrel(rules: r, topRuleName: t).recover;
MatchResult? Function(String) _r9(Map<String, Clause> r, String t) =>
    r9.Squirrel(rules: r, topRuleName: t).recover;
MatchResult? Function(String) _m143(Map<String, Clause> r, String t) =>
    g143.SuperDot3(rules: r, topRuleName: t).recover;
MatchResult? Function(String) _m132(Map<String, Clause> r, String t) =>
    g132.SuperDot3(rules: r, topRuleName: t).recover;
MatchResult? Function(String) _t1(Map<String, Clause> r, String t) =>
    t1.Squirrel(rules: r, topRuleName: t).recover;

Build? resolve(String name) => engines[name];

void main(List<String> argv) {
  if (argv.isEmpty) {
    print('usage: dart run _score1.dart <engineName> [dump]');
    return;
  }
  final name = argv[0];
  final dump = argv.contains('dump');
  final build = resolve(name);
  if (build == null) {
    print('$name UNKNOWN');
    return;
  }

  final cases = weighted(buildBattery());
  final byCorpus = <String, Corpus>{for (final c in corpora) c.name: c};
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };

  // Expectations come from the FROZEN parser reading the UNDAMAGED document,
  // so no engine can be tuned toward them; [expectedFor] adjusts them for
  // truncation, where the damage removes text outright.
  final original = <String, MatchResult>{};
  for (final c in corpora) {
    for (final doc in c.documents) {
      final r = Parser(rules: rulesOf[c.name]!, topRuleName: c.top, input: doc)
          .parse();
      if (r.hasSyntaxErrors) {
        throw StateError('corpus ${c.name}: document does not parse: $doc');
      }
      original['${c.name} $doc'] = r.root;
    }
  }

  // One engine per grammar, reused across that grammar's cases.
  final made = <String, MatchResult? Function(String)>{};
  for (final c in corpora) {
    made[c.name] = build(rulesOf[c.name]!, c.top);
  }

  final catScore = <String, double>{};
  final catN = <String, int>{};
  var crashed = 0, uncovered = 0, perfect = 0;
  double total = 0;
  final rows = <(double, String)>[];

  // The clock covers the engine and nothing else.
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
    if (dump && s.score < 1.0) {
      rows.add((
        s.score,
        '${s.score.toStringAsFixed(3)} ${k.grammar.padRight(4)} '
            '${k.category.padRight(14)} i=$i ${k.mutant.replaceAll('\n', r'\n')}'
      ));
    }
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
  if (dump) {
    rows.sort((x, y) => x.$1.compareTo(y.$1));
    for (final r in rows) {
      print(r.$2);
    }
  }
}
