import 'package:squirrel_parser/squirrel_parser.dart';
import '_cr70.dart' as ecr;

String oneErr(int k) {
  final c = List.generate(k, (i) => '${i % 10}').join('+');
  return '${c.substring(0, c.length ~/ 2)}+${c.substring(c.length ~/ 2)}';
}

void main() {
  final gLR = MetaGrammar.parseGrammar(
      "E <- E '+' T / T;\nT <- T '*' F / F;\nF <- [0-9] / '(' E ')';\n");
  final gRR = MetaGrammar.parseGrammar(
      "E <- T '+' E / T;\nT <- F '*' T / F;\nF <- [0-9] / '(' E ')';\n");
  for (final (tag, g) in [('LR', gLR), ('RR', gRR)]) {
    for (final k in [256, 512, 1024]) {
      final s = oneErr(k);
      final e = ecr.SuperDot3(rules: g, topRuleName: 'E');
      try {
        final c = e.recoverCost(s);
        print('$tag k=$k len=${s.length} cost=$c  maxWitnessDepth=${e.recMax}');
      } on StackOverflowError {
        print('$tag k=$k len=${s.length} SO at depth ${e.recMax}');
      }
    }
  }
}
