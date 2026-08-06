// _slowcase.dart -- four engines cannot finish the 1824-case battery in 1200s
// ALONE on an idle machine (m63, m65, m69, m70), where m71..m78 and m105..m113
// all finish in single-digit seconds. "Did not finish" is not yet a table
// entry, because it does not say WHICH failure it is: an engine that is merely
// slow everywhere is a different claim about the algorithm from one that hangs
// on a particular shape of damage.
//
// So run the cases one at a time with a per-case clock and report the first few
// that blow past a threshold, plus which corpus and category they belong to.
// Bounded by the caller's own timeout: the point is the FIRST offender, not the
// total.
//
// Usage: dart run _slowcase.dart <engineName> [thresholdMs] [maxReport]
import 'astdiff.dart';
import 'package:squirrel_parser/squirrel_parser.dart';

import '_score1.dart' show resolve;

void main(List<String> argv) {
  final name = argv.isEmpty ? 'm69' : argv[0];
  final limit = argv.length > 1 ? int.parse(argv[1]) : 2000;
  final maxReport = argv.length > 2 ? int.parse(argv[2]) : 6;

  final build = resolve(name);
  if (build == null) {
    print('$name UNKNOWN');
    return;
  }

  final cases = weighted(buildBattery());
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final made = <String, MatchResult? Function(String)>{
    for (final c in corpora) c.name: build(rulesOf[c.name]!, c.top)
  };

  print('$name: threshold ${limit}ms over ${cases.length} weighted cases');
  final sw = Stopwatch();
  var reported = 0, done = 0, totalMs = 0;
  for (final k in cases) {
    sw.reset();
    sw.start();
    try {
      made[k.grammar]!(k.mutant);
    } catch (e) {
      sw.stop();
      print('  CRASH  #$done  ${k.grammar}/${k.category}  '
          '${k.mutant.length} chars  ${e.runtimeType}');
      if (++reported >= maxReport) return;
      done++;
      continue;
    }
    sw.stop();
    totalMs += sw.elapsedMilliseconds;
    if (sw.elapsedMilliseconds >= limit) {
      print('  SLOW   #$done  ${k.grammar}/${k.category}  '
          '${k.mutant.length} chars  ${sw.elapsedMilliseconds}ms');
      print('         mutant: ${_show(k.mutant)}');
      if (++reported >= maxReport) return;
    }
    done++;
    if (done % 200 == 0) {
      print('  ...$done cases, ${totalMs}ms cumulative');
    }
  }
  print('$name FINISHED all $done cases in ${totalMs}ms');
}

String _show(String s) {
  final t = s.length <= 70 ? s : '${s.substring(0, 67)}...';
  return t.replaceAll('\n', '\\n');
}
