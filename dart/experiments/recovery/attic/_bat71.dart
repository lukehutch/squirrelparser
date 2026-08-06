// _bat71.dart -- the battery column is 1.40x, the warm battery is 1.05x, and the
// difference is not the engine doing more work.
//
// final_table gives each engine a COLD isolate and times ONE pass, so battms
// includes JIT-compiling that engine's own code. m71 has 1028 lines to m62's
// 789 -- an _RFrame driver, three explicit walks and a certificate path that m62
// does not have -- so it has strictly more code to compile before the same
// battery can run.
//
// Three numbers separate compilation from work: the cold pass (what battms
// measures), the warm min-of-N (what a served process actually costs), and the
// memo cell count (whether the search itself grew). Shared library code is
// warmed first with the pure parser so neither engine pays for the other's
// dependencies.
import 'dart:math';

import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show jsonGrammar;
import '_m62cells.dart' as e62;
import 'm71.dart' as e71;

List<String> makeBattery(Map<String, Clause> rules) {
  const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';
  bool parses(String s) =>
      !Parser(rules: rules, topRuleName: 'JSON', input: s).parse().hasSyntaxErrors;
  final mutants = <String>[];
  for (var j = 0; j < base.length; j++) {
    mutants.add(base.substring(0, j) + base.substring(j + 1));
    if (j + 1 < base.length && base[j] != base[j + 1]) {
      mutants.add(
          base.substring(0, j) + base[j + 1] + base[j] + base.substring(j + 2));
    }
  }
  for (var j = 0; j <= base.length; j++) {
    for (final c in ['Q', 'z', '}', '"', ',', '5']) {
      mutants.add(base.substring(0, j) + c + base.substring(j));
      if (j < base.length && base[j] != c) {
        mutants.add(base.substring(0, j) + c + base.substring(j + 1));
      }
    }
  }
  return mutants.where((m) => !parses(m)).toList();
}

double time(void Function() f) {
  final sw = Stopwatch()..start();
  f();
  return sw.elapsedMicroseconds / 1000;
}

double best(void Function() f, int reps) {
  var t = double.infinity;
  for (var i = 0; i < reps; i++) {
    t = min(t, time(f));
  }
  return t;
}

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final bat = makeBattery(rules);
  // Warm the SHARED library so neither engine is charged for the other's deps.
  for (final m in bat) {
    Parser(rules: rules, topRuleName: 'JSON', input: m).parse();
  }

  final a = e62.SuperDot3(rules: rules, topRuleName: 'JSON');
  final b = e71.SuperDot3(rules: rules, topRuleName: 'JSON');
  final cold62 = time(() {
    for (final m in bat) {
      a.recover(m);
    }
  });
  final cold71 = time(() {
    for (final m in bat) {
      b.recover(m);
    }
  });
  final warm62 = best(() {
    for (final m in bat) {
      a.recover(m);
    }
  }, 7);
  final warm71 = best(() {
    for (final m in bat) {
      b.recover(m);
    }
  }, 7);

  // Did the SEARCH grow, or only the code? One fresh engine per mutant so the
  // cell counts are the work done for that mutant alone, summed.
  var cells62 = 0, cells71 = 0;
  for (final m in bat) {
    final p = e62.SuperDot3(rules: rules, topRuleName: 'JSON')..recoverCost(m);
    final q = e71.SuperDot3(rules: rules, topRuleName: 'JSON')..recoverCost(m);
    cells62 += p.cellCount;
    cells71 += q.cellCount;
  }

  void row(String n, num x, num y) => print('${n.padRight(30)}'
      '${x.toStringAsFixed(1).padLeft(11)}${y.toStringAsFixed(1).padLeft(11)}'
      '${(y / x).toStringAsFixed(2).padLeft(9)}');
  print('battery=${bat.length}');
  print('measurement                          m62        m71    ratio');
  row('cold pass  (= battms)', cold62, cold71);
  row('warm min-of-7', warm62, warm71);
  row('memo cells over battery', cells62, cells71);
}
