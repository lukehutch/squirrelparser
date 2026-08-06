// lr_scale2 overflowed m26 on a left-recursive 1-error input at n=2048; lr_depth
// returned 1 for the identical input at the same size, and m26.recoverCost fully
// clears _entries/_verAtPos/_scores per call, so it is not memo pollution. The
// remaining explanation is that the overflow is MARGINAL at that size -- recovery's
// native recursion depth grows with n, so the crash point drifts with process
// state. This pins down both thresholds and repeats each one to expose the drift.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm26.dart' as g26;

const lr = "E <- E '+' T / T;\nT <- T '*' F / F;\nF <- [0-9] / '(' E ')';\n";
const rr = "E <- T '+' E / T;\nT <- F '*' T / F;\nF <- [0-9] / '(' E ')';\n";

String oneErr(int k) {
  final c = List.generate(k, (i) => '${i % 10}').join('+');
  final mid = c.length ~/ 2;
  return '${c.substring(0, mid)}+${c.substring(mid)}';
}

String probe(Map<String, Clause> r, String s) {
  try {
    return g26.SuperDot3(rules: r, topRuleName: 'E').recoverCost(s).toString();
  } on StackOverflowError {
    return 'STACK';
  } catch (e) {
    return 'X(${e.runtimeType})';
  }
}

void main() {
  final rulesLR = MetaGrammar.parseGrammar(lr);
  final rulesRR = MetaGrammar.parseGrammar(rr);
  print('m26, 1-error input, 3 independent attempts per size.');
  print('${'n'.padLeft(7)}${'LR x3'.padLeft(22)}${'RR x3'.padLeft(22)}   ms(LR)');
  for (final k in [1024, 1536, 2048, 3072, 4096, 6144, 8192]) {
    final s = oneErr(k);
    final l = [for (var i = 0; i < 3; i++) probe(rulesLR, s)];
    final r = [for (var i = 0; i < 3; i++) probe(rulesRR, s)];
    final sw = Stopwatch()..start();
    probe(rulesLR, s);
    print('${s.length.toString().padLeft(7)}${l.join(',').padLeft(22)}'
        '${r.join(',').padLeft(22)}   ${sw.elapsedMilliseconds}');
  }
}
