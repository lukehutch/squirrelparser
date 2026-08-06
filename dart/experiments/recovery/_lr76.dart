// _lr76.dart -- m76 on left recursion: what exactly is thrown?
//
// `measureOne` swallows truth-case throws in a bare `catch (_) {}`, so they cost
// an exactness point and never reach the `crsh` column, which counts battery
// crashes only.  Three left-recursive grammars account for 18 of m76's 20 lost
// cases; this prints the exception instead of hiding it.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'm76.dart' as e76;
import 'm77.dart' as e77;

const cases = [
  ("E <- E '+' T / T;\nT <- T '*' F / F;\nF <- [0-9];\n", 'E', ['1+2', '1++2', '1+']),
  ("E <- A / F;\nA <- B '+' F;\nB <- E;\nF <- [0-9];\n", 'E', ['1+2', '1++2']),
  ("E <- E N / F;\nN <- '-'?;\nF <- [0-9];\n", 'E', ['1', '11']),
];

void main() {
  for (final (g, top, inputs) in cases) {
    print('--- ${g.replaceAll('\n', ' ').trim()}');
    final r = MetaGrammar.parseGrammar(g);
    for (final s in inputs) {
      for (final (name, fn) in [
        ('m76', () => e76.SuperDot3(rules: r, topRuleName: top).recoverCost(s)),
        ('m77', () => e77.SuperDot3(rules: r, topRuleName: top).recoverCost(s)),
      ]) {
        try {
          print('  $name "$s" -> ${fn()}');
        } catch (err, st) {
          final frame = st.toString().split('\n').firstWhere(
              (l) => l.contains('m76.dart') || l.contains('m77.dart'),
              orElse: () => st.toString().split('\n').first);
          print('  $name "$s" -> THREW ${err.runtimeType}: $err');
          print('        at ${frame.trim()}');
        }
      }
    }
  }
}
