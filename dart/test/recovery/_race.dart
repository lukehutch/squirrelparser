// _race.dart -- scratch: paired in-process timing of c8 vs the c9
// candidate. Alternates full-battery runs A,B,A,B,... on one warmed VM and
// prints per-engine medians and the ratio, so machine noise hits both
// equally and JIT warmup is shared.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_convert.dart';

void main(List<String> argv) {
  final reps = argv.isEmpty ? 6 : int.parse(argv[0]);
  final cases = weighted(buildBattery());
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final a = {
    for (final c in corpora) c.name: convertC8(rulesOf[c.name]!, c.top).recover
  };
  final b = {
    for (final c in corpora) c.name: convertC9(rulesOf[c.name]!, c.top).recover
  };
  int runOne(Map<String, dynamic> eng) {
    final sw = Stopwatch()..start();
    for (final k in cases) {
      try {
        eng[k.grammar]!(k.mutant);
      } catch (_) {}
    }
    return sw.elapsedMilliseconds;
  }

  // Shared warmup, one run each.
  runOne(a);
  runOne(b);
  final ta = <int>[], tb = <int>[];
  for (var i = 0; i < reps; i++) {
    ta.add(runOne(a));
    tb.add(runOne(b));
  }
  ta.sort();
  tb.sort();
  final ma = ta[ta.length ~/ 2], mb = tb[tb.length ~/ 2];
  print('c8  $ta  median $ma');
  print('c9  $tb  median $mb');
  print('ratio ${(mb / ma).toStringAsFixed(3)}');
}
