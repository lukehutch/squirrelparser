// _lr80.dart -- does m80 survive LEFT RECURSION under repair? Smallest inputs
// first, printed unbuffered, so a hang names itself.
import 'dart:io';

import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart' show exprGrammar;
import 'm80.dart' as e80;

void main() {
  final rules = MetaGrammar.parseGrammar(exprGrammar);
  for (final s in ['1', 'a', '1+2', '1+', '1++2', 'a+b', 'a+', '(1', '1*2+3', '1*+3']) {
    stdout.write('${s.padRight(8)} ');
    final eng = e80.SuperDot3(rules: rules, topRuleName: 'Expr');
    final sw = Stopwatch()..start();
    try {
      eng.recover(s);
      sw.stop();
      stdout.writeln('cost ${eng.lastCost}  ${(sw.elapsedMicroseconds / 1000).toStringAsFixed(1)} ms');
    } catch (e) {
      sw.stop();
      stdout.writeln('THREW after ${(sw.elapsedMicroseconds / 1000).toStringAsFixed(1)} ms: $e');
    }
  }
}
