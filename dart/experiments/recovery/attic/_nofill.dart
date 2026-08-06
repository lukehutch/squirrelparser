// Scratch: is the total-failure fallback in r9.recover reachable, and is it
// coherent when it fires? It is guarded by `ceiling = -1`, which happens when
// the top rule's _minFill is _never -- a rule that can never match nothing
// however much is supplied. Probe it rather than reason about it.
//
//   dart run _nofill.dart

import 'dart:io';

import 'package:squirrel_parser/squirrel_parser.dart';
import 'r9.dart' as r9;

void main() {
  final cases = <String, String>{
    'unproductive left recursion': "A <- A 'x';",
    'productive, has a base': "A <- 'x' A / 'x';",
    'plain': "A <- 'x'+;",
  };
  for (final e in cases.entries) {
    final rules = MetaGrammar.parseGrammar(e.value);
    final eng = r9.Squirrel(rules: rules, topRuleName: 'A');
    stdout.write('${e.key.padRight(30)} ${e.value.padRight(20)} ');
    try {
      final t = eng.recover('xxy');
      final kids = t.subClauseMatches.length;
      final errs = t.runtimeType.toString();
      print('-> $errs @${t.pos}+${t.len} kids=$kids cost=${eng.lastCost}');
    } catch (err) {
      print('-> threw: $err');
    }
  }
}
