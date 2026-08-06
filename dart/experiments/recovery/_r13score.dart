// Score the instrumented r13 with and without the (position, price) collapse.
// Official protocol: one engine per grammar, reused across that grammar's cases;
// the clock covers the engine and nothing else.
import 'package:squirrel_parser/squirrel_parser.dart';

import '_r13p.dart' as e;
import 'astdiff.dart';

void run(String label, bool collapse) {
  e.Prof.collapse = collapse;
  e.Prof.give = e.Prof.deny = e.Prof.cases = 0;
  final battery = buildBattery();
  final cases = weighted(battery);
  final rulesOf = <String, Map<String, Clause>>{};
  final original = <String, MatchResult>{};
  for (final c in corpora) {
    rulesOf[c.name] = MetaGrammar.parseGrammar(c.grammar);
  }
  for (final c in corpora) {
    for (final doc in c.documents) {
      final r = Parser(rules: rulesOf[c.name]!, topRuleName: c.top, input: doc).parse();
      if (r.hasSyntaxErrors) throw StateError('corpus ${c.name}: does not parse');
      original['${c.name} $doc'] = r.root;
    }
  }
  final made = <String, MatchResult? Function(String)>{};
  for (final c in corpora) {
    made[c.name] = e.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top).recover;
  }
  double total = 0;
  var perfect = 0, crashed = 0;
  final sw = Stopwatch();
  for (final k in cases) {
    final c = corpora.firstWhere((x) => x.name == k.grammar);
    MatchResult? produced;
    sw.start();
    try {
      produced = made[k.grammar]!(k.mutant);
    } catch (_) {
      produced = null;
    }
    sw.stop();
    e.Prof.cases++;
    final s = scoreCase(
      produced: produced,
      expected: expectedFor(k, original['${k.grammar} ${k.original}']!, c.named),
      inputLen: k.mutant.length,
      named: c.named,
    );
    if (s.crashed) crashed++;
    if (s.score == 1.0) perfect++;
    total += s.score;
  }
  final tot = e.Prof.give + e.Prof.deny;
  print('$label  score ${(total / cases.length).toStringAsFixed(4)}  '
      'perfect ${(perfect / cases.length * 100).toStringAsFixed(1)}%  '
      'crashed $crashed  ${sw.elapsedMilliseconds} ms  '
      'trials ${(tot / e.Prof.cases).toStringAsFixed(1)}/case');
}

void main() {
  run('r13 as shipped        ', false);
  run('r13 + collapse give-up', true);
}
