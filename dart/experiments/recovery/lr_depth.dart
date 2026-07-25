// lr_scale2 crashed m26 with Stack Overflow on a 1-error left-recursive input at
// n=2048 (n=1024 was fine at 133ms). Two questions this answers:
//   (1) Is the depth limit specific to recovery, or does the PURE parser share it?
//       If the pure parser also dies, recovery inherited a property of the core and
//       the finding is about the parser, not about A5.
//   (2) Is it specific to LEFT recursion, or does the equivalent right-recursive
//       grammar die too? And do the pre-A5 engines (m16, m22) survive?
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm16.dart' as g16;
import 'm22.dart' as g22;
import 'm26.dart' as g26;

const lr = "E <- E '+' T / T;\nT <- T '*' F / F;\nF <- [0-9] / '(' E ')';\n";
const rr = "E <- T '+' E / T;\nT <- F '*' T / F;\nF <- [0-9] / '(' E ')';\n";

String chain(int k) => List.generate(k, (i) => '${i % 10}').join('+');
String oneErr(int k) {
  final c = chain(k);
  final mid = c.length ~/ 2;
  return '${c.substring(0, mid)}+${c.substring(mid)}';
}

/// Run `f`, reporting the result or the failure class -- never let one case's
/// crash hide the rest of the table.
String probe(int Function() f) {
  try {
    return f().toString();
  } on StackOverflowError {
    return 'STACK';
  } catch (e) {
    return 'X(${e.runtimeType})';
  }
}

void main() {
  final rulesLR = MetaGrammar.parseGrammar(lr);
  final rulesRR = MetaGrammar.parseGrammar(rr);

  print('=== (1) does the PURE parser survive the same depths? ===');
  print('${'n'.padLeft(7)}${'LR-clean'.padLeft(12)}${'RR-clean'.padLeft(12)}');
  for (final k in [512, 1024, 2048, 4096, 8192]) {
    final s = chain(k);
    String pure(Map<String, Clause> r) => probe(() {
          final p = Parser(rules: r, topRuleName: 'E', input: s).parse();
          return p.hasSyntaxErrors ? -1 : p.root!.len;
        });
    print('${s.length.toString().padLeft(7)}${pure(rulesLR).padLeft(12)}'
        '${pure(rulesRR).padLeft(12)}');
  }

  print('\n=== (2) recovery, 1-error input: is STACK specific to m26 or to LR? ===');
  print('${'n'.padLeft(7)}${'m16-LR'.padLeft(9)}${'m22-LR'.padLeft(9)}'
      '${'m26-LR'.padLeft(9)}${'m16-RR'.padLeft(9)}${'m22-RR'.padLeft(9)}'
      '${'m26-RR'.padLeft(9)}');
  for (final k in [256, 512, 1024, 1536, 2048]) {
    final s = oneErr(k);
    // Fresh engines each row: a crashed engine's memo must not pollute the next.
    String cell(Map<String, Clause> r, int which) => probe(() => switch (which) {
          0 => g16.SuperDot3(rules: r, topRuleName: 'E').recoverCost(s),
          1 => g22.SuperDot3(rules: r, topRuleName: 'E').recoverCost(s),
          _ => g26.SuperDot3(rules: r, topRuleName: 'E').recoverCost(s),
        });
    print('${s.length.toString().padLeft(7)}'
        '${cell(rulesLR, 0).padLeft(9)}${cell(rulesLR, 1).padLeft(9)}'
        '${cell(rulesLR, 2).padLeft(9)}${cell(rulesRR, 0).padLeft(9)}'
        '${cell(rulesRR, 1).padLeft(9)}${cell(rulesRR, 2).padLeft(9)}');
  }
}
