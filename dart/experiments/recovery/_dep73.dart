// _dep73.dart -- the LRmax/RRmax ladders for one engine, in its own cold
// process, because the RRmax cell reads >=4096 only when nothing warmed the VM
// first (LESSONS occasion 31).  `depthLimit` calls recoverCost, so an engine
// that reconstructs on the cost path is measured here and not in `recover`.
//
//   for e in m62 m72 m73; do dart _dep73.dart $e; done
import 'dart:io';

import 'package:squirrel_parser/squirrel_parser.dart';

import 'm62.dart' as e62;
import 'm72.dart' as e72;
import 'm73.dart' as e73;

typedef Cost = int Function(String);

Cost build(String which, Map<String, Clause> g) => switch (which) {
      'm62' => e62.SuperDot3(rules: g, topRuleName: 'E').recoverCost,
      'm72' => e72.SuperDot3(rules: g, topRuleName: 'E').recoverCost,
      _ => e73.SuperDot3(rules: g, topRuleName: 'E').recoverCost,
    };

String oneErr(int k) {
  final c = List.generate(k, (i) => '${i % 10}').join('+');
  return '${c.substring(0, c.length ~/ 2)}+${c.substring(c.length ~/ 2)}';
}

String ladder(String which, Map<String, Clause> g, List<int> sizes) {
  var last = 'none';
  for (final k in sizes) {
    final s = oneErr(k);
    try {
      build(which, g)(s);
      last = '${s.length}';
    } on StackOverflowError catch (_, st) {
      final fr = st.toString().split('\n');
      final seen = <String>{};
      final names = <String>[];
      for (final x in fr) {
        final mm = RegExp(r'#\d+\s+(\S+)').firstMatch(x);
        if (mm != null && seen.add(mm.group(1)!)) names.add(mm.group(1)!);
      }
      stdout.writeln('    [diag] len=${s.length} SO, ${fr.length} frames, '
          '${names.take(10).join(" <- ")}');
      return last == 'none' ? '<${s.length}' : last;
    }
  }
  return '>=$last';
}

void main(List<String> argv) {
  final which = argv.isEmpty ? 'm73' : argv[0];
  final lr = MetaGrammar.parseGrammar(
      "E <- E '+' T / T;\nT <- T '*' F / F;\nF <- [0-9] / '(' E ')';\n");
  final rr = MetaGrammar.parseGrammar(
      "E <- T '+' E / T;\nT <- F '*' T / F;\nF <- [0-9] / '(' E ')';\n");
  const sizes = [256, 512, 1024, 2048, 4096];
  final a = ladder(which, lr, sizes);
  final b = ladder(which, rr, sizes);
  stdout.writeln('$which  LRmax $a  RRmax $b');
}
