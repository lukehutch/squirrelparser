// _so70.dart -- WHERE does the tape engine's stack overflow come from?
//
// The table says m62 reaches >=4096 on both ladders and m68 reaches 1024/2048.
// The ladder grammars are lookahead-free, so by I24 m68 should never route to
// the tape on them, and its relaxed core is m62's frame stack verbatim. So the
// two extra rungs are being lost somewhere OUTSIDE the search. Print the top
// frames of the actual StackOverflowError instead of guessing which half.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'm62.dart' as e62;
import 'm68.dart' as e68;
import 'm69.dart' as e69;

String oneErr(int k) {
  final c = List.generate(k, (i) => '${i % 10}').join('+');
  return '${c.substring(0, c.length ~/ 2)}+${c.substring(c.length ~/ 2)}';
}

final gLR = MetaGrammar.parseGrammar(
    "E <- E '+' T / T;\nT <- T '*' F / F;\nF <- [0-9] / '(' E ')';\n");
final gRR = MetaGrammar.parseGrammar(
    "E <- T '+' E / T;\nT <- F '*' T / F;\nF <- [0-9] / '(' E ')';\n");

void probe(String name, int Function(Map<String, Clause>, String) cost,
    Map<String, Clause> g, String tag, int k) {
  final s = oneErr(k);
  try {
    final c = cost(g, s);
    print('$name $tag k=$k len=${s.length}  cost=$c');
  } on StackOverflowError catch (e, st) {
    final frames = st.toString().split('\n');
    // The deepest distinct frames name the recursion that blew up.
    final seen = <String>{};
    final top = <String>[];
    for (final f in frames) {
      final m = RegExp(r'#\d+\s+(\S+)').firstMatch(f);
      if (m == null) continue;
      final fn = m.group(1)!;
      if (seen.add(fn)) top.add(fn);
      if (top.length >= 6) break;
    }
    print('$name $tag k=$k len=${s.length}  STACK OVERFLOW in: '
        '${top.join(' <- ')}');
  } catch (e) {
    print('$name $tag k=$k len=${s.length}  other: '
        '${e.toString().split('\n').first}');
  }
}

void main() {
  final es = <String, int Function(Map<String, Clause>, String)>{
    'm62': (g, s) => e62.SuperDot3(rules: g, topRuleName: 'E').recoverCost(s),
    'm68': (g, s) => e68.SuperDot3(rules: g, topRuleName: 'E').recoverCost(s),
    'm69': (g, s) => e69.SuperDot3(rules: g, topRuleName: 'E').recoverCost(s),
  };
  for (final k in [512, 1024]) {
    for (final e in es.entries) {
      probe(e.key, e.value, gLR, 'LR', k);
    }
  }
  print('');
  // And the bare oracle: the frozen library's own parser on the same input,
  // with no recovery at all. If IT overflows at the same rung, the ceiling
  // belongs to the parser, not to any engine.
  for (final k in [512, 1024, 2048]) {
    final s = oneErr(k);
    try {
      final p = Parser(rules: gLR, topRuleName: 'E', input: s);
      final r = p.parse();
      print('pure  LR k=$k len=${s.length}  '
          'syntaxErrors=${r.hasSyntaxErrors}');
    } on StackOverflowError {
      print('pure  LR k=$k len=${s.length}  STACK OVERFLOW (frozen parser)');
    }
  }
}
