// Scratch: the json extreme-truncation family, across engines, by name.
//
// The question this answers: is `{"alpha"` -> `Value ( String ( ) )` an
// r-series gap, or does the m-series standing engine do the same? Both series
// price a deletion at 1 and an object completion at 3, so the prediction is
// that BOTH collapse -- but predicting is not measuring.
//
//   dart run _jt.dart <engine> [<engine> ...]

import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import '_score1.dart' show resolve;

const _probes = [
  '{"',
  '{"a',
  '{"alph',
  '{"alpha"',
  '{"k"',
  '[{"x',
  '{"k":[{"a',
];

void main(List<String> argv) {
  final c = corpora.firstWhere((x) => x.name == 'json');
  final rules = MetaGrammar.parseGrammar(c.grammar);
  for (final name in argv) {
    final build = resolve(name);
    if (build == null) {
      print('$name UNKNOWN');
      continue;
    }
    final run = build(rules, c.top);
    print('=== $name');
    for (final p in _probes) {
      String out;
      try {
        final t = run(p);
        out = t == null ? '<null>' : skeleton(t, c.named).join(' ');
      } catch (e) {
        out = '<threw: $e>';
      }
      print('  ${p.padRight(12)} -> $out');
    }
  }
}
