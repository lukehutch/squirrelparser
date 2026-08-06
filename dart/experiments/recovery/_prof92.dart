// _prof92.dart -- run one engine over the whole battery, once, and nothing else.
//
// A driver thin enough that a sampling profiler attributes essentially every
// sample to the engine. Counting cell bodies said 40.4% of them are terminals
// and 35.7% are in rounds 2+, and acting on the second of those bought nothing
// measurable, so the counts are not tracking the time. This is for asking the
// VM where the time actually goes.
//
// Usage: dart run _prof92.dart [engine]   (engine: m92 | m62)
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'm92.dart' as g92;
import 'm62.dart' as g62;

void main(List<String> argv) {
  final which = argv.isEmpty ? 'm92' : argv[0];
  final cases = weighted(buildBattery());
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final made = <String, Object? Function(String)>{
    for (final c in corpora)
      c.name: which == 'm62'
          ? g62.SuperDot3(rules: rulesOf[c.name]!, topRuleName: c.top).recover
          : g92.SuperDot3(rules: rulesOf[c.name]!, topRuleName: c.top).recover
  };
  final sw = Stopwatch()..start();
  for (final k in cases) {
    try {
      made[k.grammar]!(k.mutant);
    } catch (_) {}
  }
  print('$which  ${sw.elapsedMilliseconds} ms over ${cases.length} cases');
}
