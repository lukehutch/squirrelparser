// Time of gap recovery (Parser.parse(recover: true)) on generated JSON with k deleted delimiters.
import 'dart:math';
import 'package:squirrel_parser/squirrel_parser.dart';
import '../../test/recovery/astdiff.dart';

String makeDoc(int members, int k, Random rnd) {
  final sb = StringBuffer('{');
  for (var i = 0; i < members; i++) {
    if (i > 0) sb.write(',');
    sb.write('"key$i":');
    switch (i % 4) {
      case 0: sb.write('${rnd.nextInt(1000)}');
      case 1: sb.write('"value ${rnd.nextInt(100)}"');
      case 2: sb.write('[1,2,{"a":true,"b":null}]');
      default: sb.write('{"x":{"y":[${rnd.nextInt(9)},${rnd.nextInt(9)}]}}');
    }
  }
  sb.write('}');
  final chars = sb.toString().split('');
  final positions = <int>{};
  while (positions.length < k) {
    final p = rnd.nextInt(chars.length);
    if (',:[]{}"'.contains(chars[p])) positions.add(p);
  }
  for (final p in positions.toList()..sort((a, b) => b - a)) chars.removeAt(p);
  return chars.join();
}

void main(List<String> args) {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  for (final a in args) {
    final [m, k] = a.split('/').map(int.parse).toList();
    final doc = makeDoc(m, k, Random(7));
    final sw = Stopwatch()..start();
    final p = Parser(rules: rules, topRuleName: 'JSON', input: doc);
    final r = p.parse(recover: true);
    final errs = r.root.subClauseMatches.isEmpty && r.root is SyntaxError ? -1 : p.gaps.length;
    print('members=$m k=$k chars=${doc.length} gaps=$errs whole=${r.root is SyntaxError} ms=${sw.elapsedMilliseconds}');
  }
}
